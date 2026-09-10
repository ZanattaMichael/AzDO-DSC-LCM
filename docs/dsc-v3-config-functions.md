# DSC v3 configuration functions — plan

This is a design plan, not yet implemented. It covers two related questions raised against
the DSC v3 work in `docs/DECOUPLING_PLAN.md` (§5):

1. How should `Dsc.PipelineRunner` parse and handle **DSC v3 configuration functions**
   (`[functionName(arg1, arg2)]`) that appear inside a compiled configuration's `properties`?
   Should the runner evaluate them itself, or hand them to `dsc.exe` to evaluate natively?
2. Can a combined (multi-resource) configuration be **applied as a unit** under DSC v2 or DSC
   v3, and how does that interact with question 1?

## 1. Where the runner already has its own function language

The runner already has a configuration-function mechanism — it predates DSC v3 support and is
unrelated to it. `Start-DscRunner.ps1` resolves each resource's `properties` in two passes
(`Expand-Parameters` then `Expand-HashTable`, `Start-DscRunner.ps1:296`):

- `Expand-Parameters` does whole-scalar substitution of `<params=Name>` tokens
  (`Expand-Parameters.ps1:60`), preserving the parameter's native type.
- `Expand-HashTable` then runs `$ExecutionContext.InvokeCommand.ExpandString(...)` over every
  remaining string (`Expand-HashTable.ps1:68`), which expands `$variable` references and
  `$(...)` sub-expressions.

Five PowerShell functions with aliases are the runner's function surface, callable from inside
a `$(...)` sub-expression or a resource `condition`:

| Alias | File | Purpose |
|---|---|---|
| `parameters('Name')` | `source/Private/Runner/parameters.ps1` | reads `$parameters` (throws if undefined) |
| `variables('Name')` | `source/Private/Runner/variables.ps1` | reads `$variables` |
| `reference('Name')` | `source/Private/Runner/reference.ps1` | reads a prior resource's `Get` output from `$references` |
| `equals Left Right` | `source/Private/Runner/equals.ps1` | string equality |
| `not($Statement)` | `source/Private/Runner/not.ps1` | boolean negation |

`condition` is evaluated separately, as a `[scriptblock]`, gated by
`Assert-SafeConditionExpression` (`Assert-SafeConditionExpression.ps1`) so it stays a
side-effect-free predicate — no command invocation, assignment, or method call.

This is the runner's own ARM-Template-like function language: property values look like
`$(parameters('DriveLetter'))`, `$(reference('Disk1'))`, or a `condition` of
`$(equals (parameters 'Environment') 'Prod')`. These are ordinary PowerShell commands, so a
multi-argument call takes space-separated arguments, not `equals(a, b)` — the comma-in-parens
form parses as a single array argument and silently mis-binds.

## 2. DSC v3's own configuration function language

DSC v3 configuration *documents* (the `dsc config get|test|set --file` input, not the
per-resource `dsc resource test|set|get` input) have an independent, native function language
— see Microsoft's [DSC configuration functions](https://learn.microsoft.com/powershell/dsc/concepts/enhanced-authoring)
reference. Syntax and collision points that matter here:

- **Bracket syntax**: `[functionName(arg1, arg2)]`, nestable (`[envvar(concat('A','B'))]`), with
  `[[` as the escape for a literal leading `[`.
- **Document-scoped `parameters()` / `variables()`** — DSC v3 configuration documents can declare
  their own top-level `parameters:` and `variables:` sections, and `[parameters('Name')]` /
  `[variables('Name')]` read them. **These are the same function names the runner already owns**,
  but they read a different, document-scoped store that only exists inside a `dsc config`
  invocation — not the runner's `$parameters`/`$variables`.
- **`[resourceId('type','name')]`** and DSC v3's own `reference()` (which resolves against a
  prior resource's state inside the same document) — again name-adjacent to the runner's
  `reference()`, but resolved by `dsc.exe`'s document-scoped resolver, not `$references`.
- Other built-ins with no runner equivalent today: `envvar()`, `base64()`/`base64ToString()`,
  `concat()`, `createArray()`, `path()`, `add`/`div`/`mul`/`sub`/`mod`, `min`/`max`,
  `coalesce()`, `and`/`or`/`greater`/`less`, `systemRoot()`, `mount()`.

Two consequences:

- The two languages are **not interchangeable syntax** — `$(...)` PowerShell sub-expressions vs.
  `[...]` bracket functions — so today a `[envvar('X')]` string in `properties` passes through
  `Expand-HashTable` completely untouched (it isn't a `$(...)` expression, so
  `ExpandString` is a no-op on it) and is handed to the engine **literally**, as the string
  `"[envvar('X')]"`. For the `DscV2` engine that is simply wrong (the literal string reaches
  `Invoke-DscResource`). For the `DscV3` engine, `dsc resource test|set|get --input <json>`
  does **not** evaluate configuration functions either — that resolver only runs inside
  `dsc config ...`, which the runner does not currently call (see §4). So today, DSC v3
  functions in a compiled configuration silently do nothing useful under either engine. This is
  the gap this plan closes.
- `parameters()`/`variables()`/`reference()` mean different things depending on which language
  is in play. The plan below must not let a `[parameters('X')]` token be silently misread as the
  runner's own `parameters` function (or vice versa) — the bracket syntax is unambiguous enough
  to key off directly (see §3), but it is worth flagging explicitly since a maintainer skimming a
  compiled config could otherwise assume they're the same thing.

## 3. Handling plan — who evaluates a DSC v3 function

### Detection

Add `Test-DscV3FunctionExpression` (new private helper, alongside `Assert-SafeConditionExpression`
under `source/Private/Runner/`): given a string value, return whether it is (or contains) a
top-level `[identifier(...)]` expression, distinguishing it from:

- a literal string that happens to start with `[` (rare in YAML/JSON scalar values, since a
  leading `[` in YAML flow-sequence position is already parsed into an array before this code
  runs — by the time `Expand-HashTable` sees a scalar string, a genuine `[` prefix is either
  this function syntax or an intentional literal),
- the `[[` escape for a literal leading bracket (pass through as `[...` with the escape removed,
  never treated as a function).

A regex anchor is sufficient (`^\[(?<escaped>\[)|^\[(?<fn>[A-Za-z][A-Za-z0-9]*)\(`) — DSC v3's own
grammar is simple enough not to need a full parser, matching the level of rigor already used for
`<params=Name>` token detection in `Expand-Parameters`.

### Two evaluation modes, selected explicitly

Add a `PipelineRunnerSettings.ConfigFunctionMode` key (consistent with the existing `Engine` /
`Source` / `Connect` selection keys), with two values:

- **`Runner`** (default — preserves today's behavior for everything that isn't DSC v3 function
  syntax). A value matching DSC v3 function syntax is *rejected with a clear error* at property
  expansion time rather than silently passed through literally — turning today's silent no-op
  gap into a fail-fast one, until `Native` mode is opted into. This is a deliberate compatibility
  choice: it would be worse to keep shipping a value that looks evaluated but isn't.
- **`Native`** — a value matching DSC v3 function syntax is left completely untouched by
  `Expand-HashTable` (skip the `ExpandString` call for it) and carried verbatim into the
  document handed to `dsc.exe`, which evaluates it itself. This mode requires the whole-document
  apply path in §4, because `dsc resource <verb>` does not run the function resolver — only
  `dsc config <verb>` does.

`Auto` is deliberately **not** offered as a third mode: whether a `[...]` value can be evaluated
depends on which apply path runs it (§4), and guessing that per-property would hide a
configuration bug (a `[resourceId(...)]` left in a per-resource `DscV2` run) behind
mode-detection magic instead of surfacing it as the config/engine mismatch it is.

### What the runner still owns either way

Regardless of `ConfigFunctionMode`, the runner keeps evaluating, before any engine call:

- `<params=Name>` whole-scalar substitution (`Expand-Parameters`),
- `condition` (`Assert-SafeConditionExpression` + scriptblock),
- `postExecutionScript`,
- `dependsOn` ordering (`Sort-DependsOn`).

These are pipeline-only concepts DSC v3 has no notion of (`docs/dsc-v3.md` §"Compiled
configuration vs. a DSC v3 configuration document" already documents this split for the
document-conversion path); `Native` mode does not change that boundary, it only changes who
evaluates bracket-syntax values inside `properties`.

## 4. Whole-document apply — the missing engine path

`ConvertTo-DscV3ConfigurationDocument` (public, shipped) already builds a schema-valid DSC v3
document from compiled resources, and `scripts/Test-DscV3ConfigDocument.ps1` proves it against a
real `dsc config get` in CI. But `Start-DscRunner` never calls `dsc config` — the `DscV3` engine
(`Actions/Engine/DscV3.ps1`) only calls `dsc resource test|set|get` **once per resource**, with
that resource's `properties` as `--input`. That path cannot run DSC v3's function resolver, and
it cannot resolve `[resourceId(...)]` / native `reference()` against sibling resources, because
`dsc resource` has no document context — it only ever sees one resource in isolation.

To support `Native` mode, add a second, opt-in engine variant:

- **`Actions/Engine/DscV3Document.ps1`** (name tentative) — instead of dispatching Test/Set/Get
  per resource, it is invoked **once per file** (a different shape than the existing per-resource
  engine contract, so it cannot be a drop-in `Actions/Engine/*` file under the current typed
  seam without extending that seam — see open question below). It:
  1. builds the full document via `ConvertTo-DscV3ConfigurationDocument` from the resources that
     survived the runner's own `condition`/`dependsOn` pre-processing (§3's "what the runner
     still owns"),
  2. writes it to a temp file and calls `dsc config test|set|get --file <path>`,
  3. parses the per-resource results out of `dsc config`'s JSON response and maps each back onto
     the runner's existing per-resource report record (`ConfigurationFile`/`ResourceType`/
     `InstanceName`/`Status`), preserving today's reporting shape.

Trade-offs to call out explicitly in the eventual implementation PR:

- **Per-resource `condition` still has to be evaluated by the runner before building the
  document** (dsc.exe has no equivalent of the runner's `condition`), so a conditionally-skipped
  resource must be filtered out of the document, not left in with a false condition — DSC v3 has
  no per-resource skip semantics to map onto.
- **`postExecutionScript` cannot run between resources inside a single `dsc config set`** the way
  it can today between two `Invoke-EngineAction` calls in the per-resource loop — a document
  apply is one atomic external process invocation. A configuration that relies on
  `postExecutionScript` running between specific resources is incompatible with whole-document
  apply and must stay on the per-resource `DscV3` engine.
- **`$references` population**: today `Start-DscRunner` records each resource's `Get` output into
  `$references` as it goes, so a *later* resource's runner-level `reference()` call
  (§1 — the runner's own function, distinct from DSC v3's) can see an *earlier* resource's state
  within the same file. A whole-document apply produces all results at once, after the fact —
  fine for DSC v3's own native `[reference(...)]`/`[resourceId(...)]`, which resolve inside
  `dsc.exe`'s own pass, but it means the runner's own `reference()` function is unavailable to a
  property that is being evaluated in `Native` mode for that resource (there is no per-resource
  runner pass left to call it from). This is an acceptable, documented restriction:
  `Native` mode replaces the runner's `reference()`/`parameters()`/`variables()` for a given
  resource's properties with DSC v3's own equivalents — mixing the two within one resource's
  `properties` is unsupported and should be rejected at expansion time.

## 5. Research: applying a combined (multi-resource) configuration under v2 vs. v3

This is the second half of the question, and it explains why §4 only makes sense for DSC v3.

**DSC v2** — `Invoke-DscResource` (`PSDesiredStateConfiguration`) is a per-resource cmdlet; it has
no "apply this whole document" entry point. The only DSC v2 mechanism that applies a *combined*
configuration is the classic MOF pipeline — compile a `Configuration` block to a `.mof` and run
it through `Start-DscConfiguration` against the Local Configuration Manager (LCM). That is
precisely the surface `docs/DECOUPLING_PLAN.md` §1/§6 eliminates as a project goal ("No LCM" —
the term and the MOF/LCM apply path are explicitly out of scope, and a CI grep-guard enforces
zero "LCM" occurrences). **Conclusion: under this project's architecture, DSC v2 has no combined-
apply path and is not expected to gain one.** It stays resource-by-resource via
`Actions/Engine/DscV2.ps1`, exactly as today; DSC v3 native configuration functions are therefore
never evaluable under the `DscV2` engine, and `Native` mode should refuse to run against it
(fail fast with "DSC v3 configuration functions require the DscV3 engine and whole-document
apply" rather than silently emitting the un-evaluated bracket string, which is today's gap).

**DSC v3** — `dsc config get|test|set --file <path>` *is* the combined-apply path, and it is the
only place DSC v3's own configuration functions are evaluated. §4 is exactly the work needed to
reach it from the runner. It is additive to, not a replacement for, the existing per-resource
`DscV3` engine: per-resource `dsc resource <verb>` stays the default/simple path (fine-grained
per-resource reporting, full support for the runner's own `condition`/`postExecutionScript`/
`reference()`), and whole-document apply is the opt-in path a configuration reaches for only when
it actually uses DSC v3 native functions.

## 6. Recommended sequencing

This slots into `docs/DECOUPLING_PLAN.md` as a follow-on to the already-delivered Phase 2 (DSC v3
engine + `ConvertTo-DscV3ConfigurationDocument`), not a rework of it:

1. `Test-DscV3FunctionExpression` + fail-fast detection in `Expand-HashTable`/`Expand-Parameters`
   for `Runner` mode (closes the silent-no-op gap in §2 first, with no new engine work — this is
   the safe, low-risk increment and should ship alone).
2. `PipelineRunnerSettings.ConfigFunctionMode` plumbing (`Runner` default / `Native`), rejecting
   `Native` up front when the resolved engine isn't `DscV3`.
3. Extend the engine seam to accommodate a once-per-file engine shape (or introduce
   `Actions/Engine/DscV3Document.ps1` as a distinct, explicitly-selected engine name rather than a
   mode flag on `DscV3` — keeps the existing per-resource `DscV3` engine and its contract test
   completely unchanged). Needs a design decision, not just an implementation, because it doesn't
   fit today's one-call-per-resource `[DscMethodResult]` contract (§3B of the decoupling plan) —
   see open questions below.
4. `Actions/Engine/DscV3Document.ps1`: build filtered document, call `dsc config`, map results
   back to the runner's report shape.
5. Docs: extend `docs/dsc-v3.md` with a "Configuration functions" section covering `Native` mode,
   its restrictions (§4's trade-offs), and a worked example; CI proof analogous to
   `scripts/Test-DscV3ConfigDocument.ps1` but exercising a document that actually contains a
   native function (`envvar()` is the easiest to prove deterministically in CI).

## 7. Open questions for the maintainer

- **Engine contract shape for whole-document apply.** The existing typed engine contract
  (§3B of `docs/DECOUPLING_PLAN.md`) is `{Method, ModuleName, Name, Property} → [DscMethodResult]`,
  called once per resource per method. A whole-document engine is called once per *file* per
  method and returns *N* results. Cleanest options: (a) keep `Actions/Engine/*` exclusively
  per-resource and have `Start-DscRunner` special-case a `DscV3Document`-selected engine with an
  entirely separate call path (simplest, but the once-per-file behavior lives outside the
  `Actions/` loader, breaking the "every engine is a drop-in action" property this repo has
  otherwise held to); (b) widen the typed contract so an engine can declare
  `-SupportsDocumentApply` and receive `{Method, Resources[]}` instead, returning
  `[DscMethodResult[]]` (keeps everything inside the loader, but is a breaking change to the
  seam every existing/custom engine relies on). Recommend (a) for a first cut, with (b) revisited
  only if a second whole-document engine shows up and the duplication becomes real.
- **Should `Native` mode support DSC v2 at all**, e.g. by having the runner itself implement
  PowerShell equivalents of `envvar()`, `concat()`, etc. so a `[...]`-syntax value could be
  evaluated by the runner (not `dsc.exe`) and handed to `Invoke-DscResource`? This plan
  recommends **no** — it would mean maintaining a second, parallel implementation of DSC v3's
  function semantics that could drift from Microsoft's, for a combination (DSC v3 syntax +
  DSC v2 execution) that has no real-world motivation (anyone targeting DSC v3 functions is
  already on DSC v3 resource types). Worth confirming with whoever raised the original ask,
  since "handled by the parser" in the task description could be read either way.
- **Escaping (`[[`) round-trip through YAML.** Datum/YAML already treats a leading `[` specially
  in flow-sequence position; needs a concrete test fixture (`Tests/Fixtures`) proving a scalar
  string value of exactly `"[[literal]"` survives `ConvertFrom-Yaml` as a string and is
  unescaped correctly, before relying on the detection regex in §3.

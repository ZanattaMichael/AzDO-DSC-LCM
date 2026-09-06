# Trust model and security boundary

> This page is the canonical, longer-form version of the "Trust model" section in
> [SECURITY.md](../SECURITY.md). It is intended to be mirrored to the project Wiki
> (issue #37); the repository copy is authoritative.

## The one thing to remember

**`Dsc.PipelineRunner` runs your configuration repository as trusted code.** If you would
not run a script from a source on your build agent as an administrator, do not point the
runner at it.

## Why the configuration is code, not data

Datum merges YAML into per-node configuration, but the runner does not stop at data:

1. `Build-DatumConfiguration` executes a compile step (`DatumConfigurationScriptBlock`)
   that turns the merged configuration into a DSC `Configuration` block and runs it. A
   `Configuration` block is PowerShell — any statement valid in PowerShell is valid inside
   it.
2. Each resource may carry a `condition` and a `postExecutionScript`. Both are compiled to
   script blocks and evaluated:
   - **`condition`** is validated as a *side-effect-free predicate* before it runs
     (`Assert-SafeConditionExpression`, issue #35). It may read variables and properties
     and compare them, but it may not invoke commands, assign variables, or call methods.
     It is also run with the call operator (`&`) in a child scope, so it cannot rewrite the
     runner's own state.
   - **`postExecutionScript`** is imperative by design (it exists to call control verbs
     such as `Stop-TaskProcessing`) and is **not** constrained. It runs in a child scope,
     so it cannot silently rewrite the runner's locals, but it can execute arbitrary code.
3. The resources themselves are applied by the DSC engine (DSC v2 `Invoke-DscResource` or
   DSC v3 `dsc`), which runs whatever the resource implementation does.

## The boundary

| Boundary | Trusted side | Untrusted side |
|---|---|---|
| Configuration repository | Everything in it runs as code | — there is no untrusted side |
| Clone transport | HTTPS/SSH to a verified host | Plaintext HTTP — refused, not merely discouraged |
| Runner process | Runs configuration + resources | — |

There is deliberately no "untrusted configuration" mode. Treat the configuration
repository as part of the trusted computing base.

## What the runner enforces

The clone is the one edge of this boundary the runner can defend on its own, and it does so
unconditionally — there is no setting that relaxes any of it:

| Control | Behaviour |
|---|---|
| Transport | `https`, `ssh` and SCP-style `git@host:path` only. A plain `http://` URL throws a terminating error naming the scheme. |
| Revision pinning | `-ConfigurationRevision` checks out a branch, tag or commit. A full 40-character SHA is verified against the clone's resolved `HEAD`; a mismatch fails the run. |
| Provenance in the log | The resolved `HEAD` SHA is written to the information stream on every clone, so the pipeline log records the commit that actually ran. |
| Credential handling | Tokens are held as `[SecureString]` and injected as an HTTP `Authorization` header through git's environment-based configuration, never on the process command line, and redacted from error text. |
| Temporary directories | Clones and fallback cache directories are created owner-only (`0700` on Unix, a single full-control ACE on Windows) and removed in a `finally`, so they do not survive a failed run. Only directories the runner created are removed — a caller-supplied path is never deleted. `-KeepTemporaryDirectory` opts out for debugging. |

This narrows the *transport*, not the boundary itself: a configuration delivered intact over
a verified channel still runs as fully-trusted code.

## Operational controls

- **Branch protection & required reviews** on the configuration repository, matching (or
  exceeding) the controls on the runner's own source.
- **Signed commits** where your platform supports enforcing them.
- **Scoped pipeline triggers** — restrict who can run the pipeline and from which branches.
- **Verified clone transport** — HTTPS or SSH with known-host verification. The runner
  already refuses anything else; keep host verification configured on the agent so the
  remote's identity is checked as well as its scheme.
- **Pin the revision** — pass `-ConfigurationRevision`, ideally a full commit SHA, so a push
  to the tracked branch cannot change what a run applies between review and execution.
- **Least privilege** on the agent identity and on any managed-node credentials.

When the configuration source is a remote URL, `Build-DatumConfiguration` emits a
`Write-Warning` at the start of compilation restating this requirement, so it is visible in
the pipeline log.

## Future hardening (tracked)

- AST-based allow-listing of permitted DSC resource types.
- Executing the compile step under
  `[System.Management.Automation.SessionState]::LanguageMode = 'ConstrainedLanguage'`.

These would narrow the boundary but cannot remove it: a configuration that is allowed to
declare resources is, by construction, allowed to change the state those resources manage.

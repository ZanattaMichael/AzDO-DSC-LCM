# Security Policy

## Reporting a vulnerability

Please report suspected vulnerabilities privately to the repository owner via a
[GitHub security advisory](https://github.com/ZanattaMichael/Dsc.PipelineRunner/security/advisories/new)
rather than opening a public issue. Include the affected version, a description of the
issue, and a reproduction if you have one.

## Trust model

**The configuration repository is executed as fully-trusted code.**

`Dsc.PipelineRunner` compiles a Datum/DSC configuration by executing it as PowerShell.
A DSC `Configuration` block is *code*, not merely data: it can contain arbitrary
PowerShell in addition to resource declarations, and it runs in the same process and
security context as the runner. The runner does **not** sandbox, allow-list, or otherwise
validate the content of a configuration before running it.

Concretely:

- `Build-DatumConfiguration` retrieves and invokes the `DatumConfigurationScriptBlock`
  compile step, which executes the configuration.
- `Invoke-DscPipelineRunner` and `Invoke-DscRunner` accept a **remote URL** as the
  configuration source, clone it, and compile it — so code from the remote repository
  runs on the build agent and, through the applied resources, on every managed node.
- Resource `condition` and `postExecutionScript` fields are also evaluated as PowerShell.
  Conditions are constrained to side-effect-free predicates (they may not invoke commands,
  assign variables, or call methods — see issue #35), but `postExecutionScript` is
  imperative by design and is **not** constrained.

### What this means for operators

Anyone who can push to the configuration repository can execute arbitrary code on the
build agent and on the managed nodes. This is inherent to running DSC configurations and
cannot be patched away inside `Dsc.PipelineRunner`; it must be mitigated
**operationally**:

- Protect the configuration repository with the **same controls as the runner's own
  source**: branch protection, required reviews, and — where available — signed commits.
- Restrict who can trigger the pipeline and which branches it runs from.
- Pin the configuration to a reviewed revision with `-ConfigurationRevision`, ideally a full
  commit SHA, so a push to the tracked branch cannot change what a run applies.
- Run the agent with the least privilege the target resources require.

When the configuration source is a remote URL, the runner emits a `Write-Warning` at the
start of compilation restating this trust requirement.

### What the runner enforces

Fetching the configuration is the one part of this the runner *can* protect, and it does so
unconditionally:

- **Transport.** Only `https`, `ssh` and SCP-style `git@host:path` remotes are accepted. A
  plain `http://` URL is rejected with a terminating error naming the scheme, because a
  configuration fetched over a transport an attacker can rewrite is a remote code-execution
  path into the runner's own security context.
- **Revision pinning.** `-ConfigurationRevision` checks out a branch, tag or commit after the
  clone; a full 40-character SHA is verified against the clone's resolved `HEAD` and a
  mismatch fails the run. The resolved `HEAD` SHA is always written to the information
  stream, so the pipeline log records the exact commit that ran.
- **Credential handling.** Clone tokens are held as `[SecureString]` and injected as an HTTP
  `Authorization` header through git's environment-based configuration — never on the
  process command line — and redacted from error text.
- **Temporary directories.** Clones and fallback cache directories are created owner-only
  (`0700` on Unix, a single full-control ACE on Windows) and removed when the run ends,
  including when it ends by throwing. Only directories the runner created are removed; a
  caller-supplied path is never deleted.

None of this makes an untrusted configuration safe to run. It removes the ways the
*transport* could be turned against a configuration you have already decided to trust.

### Future hardening

Constrained-language execution and AST-based allow-listing of permitted resource types
are tracked as follow-on work. They would narrow, but not eliminate, the trust boundary
described here.

See the companion page [docs/trust-model.md](docs/trust-model.md) for a longer discussion.

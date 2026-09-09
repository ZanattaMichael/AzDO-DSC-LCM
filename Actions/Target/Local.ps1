<#
.SYNOPSIS
Default Target action: evaluate resources against the local machine (#57 §4).

.DESCRIPTION
No-op target. Returns a session descriptor with no CimSession/PSSession, so the engine
actions fall back to their existing local-execution path unchanged. This is the runner's
default today and stays the default when a configuration/PipelineRunnerSettings does not
name a Target.

.PARAMETER Context
Hashtable built by Start-DscRunner. Unused by Local - present for signature consistency
with the other Target actions.

.OUTPUTS
[hashtable] @{ ComputerName = 'localhost'; IsRemote = $false; CimSession = $null; PSSession = $null }
#>
param(
    [hashtable]$Context = @{}
)

return @{
    ComputerName = 'localhost'
    IsRemote     = $false
    CimSession   = $null
    PSSession    = $null
}

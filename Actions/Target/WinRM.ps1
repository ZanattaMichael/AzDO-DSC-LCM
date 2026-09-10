<#
.SYNOPSIS
Target action: evaluate resources against a remote computer over WinRM (#57 §4).

.DESCRIPTION
Builds both a CimSession (consumed by the DscV2 engine action, Invoke-DscResource -CimSession)
and a PSSession (consumed by the DscV3 engine action, which runs dsc.exe on the far side via
Invoke-Command) for the same remote computer, so either engine can use whichever session shape
it needs without the caller having to know which one in advance. Only unit-tested with New-CimSession
/New-PSSession mocked (#57 scope note) - this module cannot open a live WinRM connection in this
environment; validating a real connection needs a reachable Windows remote target.

.PARAMETER Context
Hashtable with:
  ComputerName [string]        - required, the remote computer name or IP.
  Credential   [PSCredential]  - optional, resolved beforehand via the Credential hook (#57 §5).

.OUTPUTS
[hashtable] @{ ComputerName; IsRemote = $true; CimSession; PSSession }
#>
param(
    [hashtable]$Context = @{}
)

if ([string]::IsNullOrWhiteSpace([string]$Context.ComputerName)) {
    throw "[Actions/Target/WinRM] 'ComputerName' is required in the Target context."
}

$sessionParams = @{ ComputerName = [string]$Context.ComputerName }
if ($Context.Credential) {
    $sessionParams.Credential = $Context.Credential
}

$cimSession = New-CimSession @sessionParams
$psSession  = New-PSSession @sessionParams

return @{
    ComputerName = [string]$Context.ComputerName
    IsRemote     = $true
    CimSession   = $cimSession
    PSSession    = $psSession
}

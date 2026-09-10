<#
.SYNOPSIS
Gates preExecutionScript/postExecutionScript behind PipelineRunnerSettings.AllowExecutionScripts (#57 §2).

.DESCRIPTION
preExecutionScript and postExecutionScript run arbitrary PowerShell in the runner's own
process. Unlike condition/preCondition/postCondition (which Assert-SafeConditionExpression
restricts to a side-effect-free predicate), an execution script is deliberately unrestricted,
so a configuration that carries one is opting in to running code the runner does not sandbox.
That opt-in must be explicit at the configuration level, not merely "the resource happened to
carry the property" - otherwise a configuration author who did not intend to grant script
execution (or a compromised/third-party configuration source) could smuggle one in silently.

This rule collects every resource that sets preExecutionScript or postExecutionScript and, if
PipelineRunnerSettings.AllowExecutionScripts is not explicitly true, fails the run once, naming
every offending resource - following the same collect-all-then-throw-once pattern as
Test-ResourcesForIncorrectProperties.ps1, so an operator sees every offender in one pass.

.PARAMETER PipelineResources
An array of pipeline resources to be tested.

.PARAMETER Settings
The resolved PipelineRunnerSettings hashtable (from the Datum.yml PipelineRunnerSettings
block). AllowExecutionScripts defaults to $false when absent or not a recognizable boolean -
lifecycle scripts are opt-in, not opt-out.

.EXAMPLE
Test-ExecutionScriptsAllowed -PipelineResources $resources -Settings @{ AllowExecutionScripts = $true }
#>
param(
    [Object[]]$PipelineResources,
    [hashtable]$Settings
)

$allowExecutionScripts = $false
if ($Settings -and $Settings.ContainsKey('AllowExecutionScripts')) {
    $allowExecutionScripts = [bool]$Settings['AllowExecutionScripts']
}

if ($allowExecutionScripts) {
    Write-Verbose "[Test-ExecutionScriptsAllowed] PipelineRunnerSettings.AllowExecutionScripts is enabled; preExecutionScript/postExecutionScript are permitted."
    return
}

$offenders = [System.Collections.Generic.List[string]]::new()
foreach ($task in $PipelineResources) {
    if ($null -ne $task.preExecutionScript -or $null -ne $task.postExecutionScript) {
        $offenders.Add("[$($task.type)/$($task.name)]")
    }
}

if ($offenders.Count -gt 0) {
    throw "[Test-ExecutionScriptsAllowed] preExecutionScript/postExecutionScript are used by $($offenders.Count) resource(s) ($($offenders -join ', ')) but PipelineRunnerSettings.AllowExecutionScripts is not enabled. Add 'AllowExecutionScripts: true' to the PipelineRunnerSettings block in Datum.yml to allow lifecycle scripts, or remove preExecutionScript/postExecutionScript from these resources."
}

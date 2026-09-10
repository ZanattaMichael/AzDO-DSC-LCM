<#
.SYNOPSIS
Requests that the remaining resources in the current file be skipped, from a postCondition (#57 §2).

.DESCRIPTION
The `stopProcessing` function-language accessor is the postCondition-only counterpart of the
public Stop-TaskProcessing cmdlet: it sets the same $script:StopTaskProcessing flag that
Start-DscRunner checks before each resource. It exists as a separate, narrowly-scoped
accessor (rather than allow-listing Stop-TaskProcessing itself in every condition) because a
plain `condition` predicate must stay side-effect-free (#35) - only `postCondition`, evaluated
with Assert-SafeConditionExpression's -AllowStopProcessing switch, may call it.

Unlike parameters()/variables()/reference()/result(), this accessor DOES have a side effect
by design (it is the one deliberate escape hatch), which is exactly why it is excluded from a
plain preCondition/condition's allow-list and only reachable from postCondition.

.EXAMPLE
PS> stopProcessing()
Skips every remaining resource in the current configuration file, starting with the next one.
#>
function invoke-stopprocessing {
    [CmdletBinding()]
    [Alias('stopProcessing')]
    param ()

    Write-Verbose "[stopProcessing] postCondition requested that remaining resource processing be stopped."
    $script:StopTaskProcessing = $true
    return $true
}

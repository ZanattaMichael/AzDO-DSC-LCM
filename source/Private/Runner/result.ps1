<#
.SYNOPSIS
Returns the current resource's engine result inside a postCondition expression (#57 §2).

.DESCRIPTION
The `result` function-language accessor exposes the [DscMethodResult] produced by the
resource's Test/Set evaluation to a `postCondition` expression, so a postCondition can make
its pass/fail decision based on the engine outcome (for example `result().InDesiredState` or
`result().Message`) rather than only on parameters/variables/reference. It is meaningful only
inside postCondition - Start-DscRunner sets $script:currentResourceResult immediately before
evaluating postCondition and the value is otherwise $null.

Like the other accessors (parameters/variables/reference), this is a pure read: it returns the
already-computed result and never re-runs the engine or mutates state.

.EXAMPLE
PS> result().InDesiredState
Returns whether the resource's most recent engine evaluation reported the desired state.
#>
function invoke-result {
    [CmdletBinding()]
    [Alias('result')]
    param ()

    return $script:currentResourceResult
}

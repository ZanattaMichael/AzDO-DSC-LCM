<#
.SYNOPSIS
Rewrites the documented `result()` / `stopProcessing()` call syntax into PowerShell that
actually parses.

.DESCRIPTION
PowerShell cannot parse a truly empty-argument call written as `identifier()` — `()` alone is
not a valid sub-expression, so `stopProcessing()` and `result()` both fail with a parser error
("An expression was expected after '('.") no matter where they appear, including inside a
larger expression like `result().InDesiredState`. That is true even though the same
`identifier('arg')` shape (with content between the parens) parses and works fine, which is
why `parameters()`/`variables()`/`reference()`/`equals()`/`not()` never hit this — every one of
them always takes at least one argument.

`result` and `stopProcessing` are the first two zero-argument accessors (#57 §2), so their
documented `()` call syntax needs to be rewritten into an equivalent, parseable form before the
expression reaches the parser or the real script block:

  - `result()`         -> `(result)`         (still supports member access: `(result).InDesiredState`)
  - `stopProcessing()` -> `stopProcessing`    (a bare command invocation)

Both Assert-SafeConditionExpression and Start-DscRunner's script-block creation call this on the
same postCondition text, so the AST that gets validated is exactly the AST that gets executed.
Applying it unconditionally (not only when -AllowStopProcessing would be passed downstream) is
safe: a preCondition that writes `stopProcessing()` still ends up rejected as a disallowed
command invocation, just via the normalized `stopProcessing` spelling instead of a raw parse
error - the same outcome, a clearer message.

.PARAMETER Expression
The raw condition/preCondition/postCondition string as authored in the configuration.

.EXAMPLE
ConvertTo-NormalizedConditionExpression -Expression 'result().InDesiredState'
Returns '(result).InDesiredState'.

.EXAMPLE
ConvertTo-NormalizedConditionExpression -Expression 'stopProcessing()'
Returns 'stopProcessing'.
#>
function ConvertTo-NormalizedConditionExpression {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Expression
    )

    $normalized = $Expression -replace '\bresult\(\)', '(result)'
    $normalized = $normalized -replace '\bstopProcessing\(\)', 'stopProcessing'

    return $normalized
}

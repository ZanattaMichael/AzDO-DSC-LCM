<#
.SYNOPSIS
Retrieves the value of a specified parameter from the $parameters hashtable.

.DESCRIPTION
Backs the `parameters('Name')` syntax available inside a configuration's conditions and
string expressions. An undefined parameter is a terminating error: returning $null silently,
as this function used to, meant the value landed in a resource property and the run applied
the wrong configuration rather than reporting the mistake.

.PARAMETER Name
The name of the parameter whose value is to be retrieved.

.RETURNS
The value of the specified parameter.

.EXAMPLE
$paramValue = parameters -Name 'ParameterName'
#>

function invoke-parameters {
    [CmdletBinding()]
    [Alias('parameters')]
    param ([string] $Name)

    # IDictionary.Contains covers both the plain hashtable used by the module and the ordered
    # dictionary a JSON-loaded configuration can produce. A parameter defined as an empty
    # string is defined, so presence is a key lookup rather than a test of the value.
    if (($null -eq $parameters) -or -not ($parameters -is [System.Collections.IDictionary]) -or
        -not $parameters.Contains($Name)) {

        throw "[parameters] Parameter '$Name' not found in the parameters hashtable."
    }

    return $parameters[$Name]
}

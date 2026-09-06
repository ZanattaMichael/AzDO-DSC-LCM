<#
.SYNOPSIS
    Builds the parameter table from a configuration's `parameters` section.

.DESCRIPTION
    Takes the configuration's `parameters` section and returns a hashtable mapping each
    declared parameter name to its default value.

    Only a parameter whose declaration actually carries a `defaultValue` is included. A
    declaration without one is skipped with a warning rather than added with a $null value:
    the parameter table is what Resolve-PipelineParameter and `parameters('Name')` test for
    presence, so an entry that is present-but-$null makes a `<params=Name>` token resolve to
    $null instead of throwing - the silent wrong value the throw on an undeclared parameter
    exists to prevent. Skipping keeps the two cases indistinguishable to a caller: a
    parameter with no usable value fails loudly, however it came to have none.

    A parameter legitimately declared as an empty string, or explicitly as null, still has a
    `defaultValue` key and is therefore kept.

.PARAMETER Source
    The configuration's `parameters` section: parameter name -> declaration, where a
    declaration is a dictionary carrying a `defaultValue` key.

.RETURNS
    [hashtable] Parameter name -> default value, for every parameter that declares one.

.EXAMPLE
    $source = @{
        Key1 = @{ defaultValue = 'Value1' }
        Key2 = @{ defaultValue = 'Value2' }
    }
    $defaultValues = GetDefaultValues -Source $source
    # $defaultValues will be @{ Key1 = 'Value1'; Key2 = 'Value2' }

.EXAMPLE
    $source = @{ Key1 = @{ description = 'no default' } }
    $defaultValues = GetDefaultValues -Source $source
    # Warns and returns an empty hashtable, so `<params=Key1>` throws rather than
    # resolving to $null.
#>

function Get-DefaultValues {
    [CmdletBinding()]
    [Alias('GetDefaultValues')]
    param (
        [hashtable] $Source
    )

    $values = @{}
    foreach ($key in $Source.Keys) {
        $declaration = $Source[$key]

        # IDictionary.Contains covers the hashtable the YAML loader produces and the ordered
        # dictionary a JSON configuration normalizes to. Contains, not a test of the value,
        # so an empty string or an explicit null is still a declared default.
        if (($declaration -is [System.Collections.IDictionary]) -and $declaration.Contains('defaultValue')) {
            $values.Add($key, $declaration['defaultValue'])
            continue
        }

        $message = "[Get-DefaultValues] Parameter '$key' declares no 'defaultValue' and is ignored. " +
            "A '<params=$key>' token or a parameters('$key') call will fail until one is added."
        Write-Warning $message
    }

    return $values
}

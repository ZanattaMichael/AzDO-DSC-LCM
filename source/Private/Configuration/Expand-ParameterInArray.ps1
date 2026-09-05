<#
.SYNOPSIS
Expands parameters within an array.

.DESCRIPTION
The `Expand-ParameterInArray` function processes each element in the input array and expands any parameters found within the array. 
It handles boolean values, strings that match a specific pattern, and hashtables.

.PARAMETER InputArray
The array of input elements to be processed and expanded.

.EXAMPLE
$input = @('<params=example>', $true, @{ key = 'value' })
$expanded = Expand-ParameterInArray -InputArray $input
# This will expand the parameters within the input array.

.NOTES
If a parameter within the array is not found in the `$Script:parameters` hashtable, an error will be thrown.
#>
# Function to Expand the Parameters in the Array
function Expand-ParameterInArray {
    param (
        [Parameter(Mandatory=$true)]
        [array]$InputArray
    )

    # Process each element in the array
    $expandedArray = @()
    foreach ($item in $InputArray) {
        if ($item -is [bool]) {
            # Keep the boolean value as is
            $expandedArray += $item
        }       
        elseif (($item -is [string]) -and ($item -match '^\<params\=(?<name>.+)\>$')) {

            # Substitute the parameter with the parameter value. Presence is a key lookup, so
            # a parameter defined as an empty string resolves rather than being reported
            # missing (see Resolve-PipelineParameter).
            $expandedArray += Resolve-PipelineParameter -Name $Matches['name']
        }
        elseif ($item -is [hashtable]) {
            $expandedArray += Expand-Parameters -InputHashTable $item
        } 
        else {
            $expandedArray += $item
        }
    }

    return $expandedArray
}

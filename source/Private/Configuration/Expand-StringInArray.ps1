
<#
.SYNOPSIS
Expands strings in an array by performing expansion logic (e.g., expanding environment variables).

.DESCRIPTION
The Expand-StringInArray function takes an array of strings as input and expands each string by performing expansion logic. If an element in the array is a string, it will be expanded using the ExpandString method of the ExecutionContext object. If an element is not a string, it will be added to the expanded array as is.

.PARAMETER InputArray
The array of strings to be expanded.

.EXAMPLE
$strings = @("Hello, $env:USERNAME!", "Today is $((Get-Date).ToString('dddd'))")
$expandedStrings = Expand-StringInArray -InputArray $strings
$expandedStrings
# Output:
# Hello, John!
# Today is Monday

.NOTES
This function is useful when you need to expand strings in an array, such as when working with configuration files or templates.
#>
function Expand-StringInArray {
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
        elseif ($item -is [string]) {
            # Perform expansion logic here (example: expanding environment variables)
            $expandedItem = $ExecutionContext.InvokeCommand.ExpandString($item)
            $expandedArray += $expandedItem
        }
        elseif ($item -is [hashtable]) {
            $expandedArray += Expand-HashTable -InputHashTable $item
        } 
        else {
            $expandedArray += $item
        }
    }

    return $expandedArray
}
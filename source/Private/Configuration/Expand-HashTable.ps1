<#
.SYNOPSIS
Expands the values in a hashtable, processing nested hashtables, lists, and strings.

.DESCRIPTION
The Expand-HashTable function takes a hashtable as input and processes each key-value pair. 
It handles boolean values, lists, nested hashtables, and strings, expanding them as necessary. 
For lists, it calls the Expand-StringInArray function. For nested hashtables, it recursively calls itself. 
For strings, it uses the ExecutionContext object to expand the string.

.PARAMETER InputHashTable
The hashtable to be expanded. This parameter is mandatory.

.RETURNS
A hashtable with expanded values.

.EXAMPLE
$input = @{
    Key1 = "Value1"
    Key2 = $true
    Key3 = @{ NestedKey = "NestedValue" }
    Key4 = [System.Collections.Generic.List[string]]@("Item1", "Item2")
}
$expanded = Expand-HashTable -InputHashTable $input
# The $expanded variable will contain the expanded hashtable.

.NOTES
This function is designed to handle various types of values within a hashtable, including booleans, lists, nested hashtables, and strings.
#>

Function Expand-HashTable {
    param(
        [Parameter(Mandatory=$true)]
        [HashTable]$InputHashTable
    )

    $Property = @{}

    # Iterate through each key in the hashtable
    foreach ($key in $InputHashTable.Keys) {
        
        if ($InputHashTable[$key] -is [Bool]) {
            # Keep the boolean value as is
            $inputValue = $InputHashTable[$key]
        } 
        # Test if the property is a list
        elseif ($InputHashTable[$key].GetType().Name -eq 'List`1') {
            # Expand the string in the list
            $inputValue = Expand-StringInArray $task.properties[$key]
        } 
        elseif ($InputHashTable[$key] -is [hashtable]) {
            # Recursively expand the hashtable
            $inputValue = Expand-HashTable -InputHashTable $InputHashTable[$key]
        }
        else {
            # Expand the string using the ExecutionContext object
            $inputValue = $ExecutionContext.InvokeCommand.ExpandString($InputHashTable[$key])
        } 
    
        # Add the property to the hashtable
        $Property[$key] = $inputValue
    }

    return $Property

}

<#
.SYNOPSIS
Detects circular dependencies between resources.

.DESCRIPTION
This script detects circular dependencies between resources by iterating through each resource and checking if there are any circular references in the dependencies.

.PARAMETER PipelineResources
An array of pipeline resources.

.EXAMPLE
$PipelineResources = @(
    [PSCustomObject]@{
        Type = "ResourceType1"
        Name = "ResourceName1"
        DependsOn = @("ResourceType2/ResourceName2")
    },
    [PSCustomObject]@{
        Type = "ResourceType2"
        Name = "ResourceName2"
        DependsOn = @("ResourceType1/ResourceName1")
    }
)

Detect-CircularDependency -PipelineResources $PipelineResources

.NOTES
This script assumes that the pipeline resources are provided as an array of objects with the following properties:
- Type: The type of the resource.
- Name: The name of the resource.
- DependsOn: An array of dependencies for the resource in the format "Type/Name".
#>
param(
    [Object[]]$PipelineResources
)

# Function to detect circular dependencies
function Detect-CircularDependency
{
    param (
        [Hashtable]$Resource,
        [System.Collections.ArrayList]$Visited,
        [System.Collections.ArrayList]$Stack
    )

    if ($Stack.Contains($Resource)) {
        $ResourceStack = ($Stack | ForEach-Object { "{0}/{1} -> " -f $_.Type, $_.Name }) -join ''
        throw "Circular dependency detected with Resource: $ResourceStack$("{0}/{1}" -f $Resource.Type, $Resource.Name)"
    }

    if (-not $Visited.Contains($Resource)) {
        $Stack.Add($Resource)
        foreach ($Dep in $Resource.DependsOn) {
            # Locate the Resource within ResourceConfiguration

            $Split = $Dep.Split("/")
            $Name = $Split[2..$Split.Length] -join "/"
            $Type = "{0}/{1}" -f $Split[0], $Split[1]

            $DepResource = $PipelineResources | Where-Object { $_.Type -eq $Type -and $_.Name -eq $Name }
            Detect-CircularDependency -Resource $DepResource -Visited $Visited -Stack $Stack
        }
        $Stack.Remove($Resource)
        $Visited.Add($Resource)
    }
}

#
# Iterate through each resource and detect circular dependencies

ForEach ($ResourceObject in $ResourcesWithDependsOn) {

    $params = @{
        Resource = $ResourceObject
        Visited = @()
        Stack = @()
    }
    
    # Detect circular dependencies
    try {
        $null = Detect-CircularDependency @params
    } catch {
        Write-Error $_.Exception.Message
        return
    }

}
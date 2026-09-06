<#
.SYNOPSIS
Detects circular dependencies between resources.

.DESCRIPTION
Walks the dependency graph described by each resource's DependsOn list and throws when a
resource is reachable from itself. The walk is a depth-first search that pushes a resource
onto the current path before recursing and pops it again afterwards, so only a resource that
is still on the path counts as a cycle. A resource reached twice by two different branches -
the shared tail of a diamond, for example - is a perfectly valid graph and is explored once.

Resources whose DependsOn names a resource that is not present in the configuration are
skipped with a verbose message: an unresolved dependency is a different problem, reported by
the dependency-ordering rules rather than here.

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

.\Test-CircularReferences.ps1 -PipelineResources $PipelineResources

Throws, naming the cycle in path order.

.NOTES
This script assumes that the pipeline resources are provided as an array of objects with the
following properties:
- Type: The type of the resource.
- Name: The name of the resource.
- DependsOn: An array of dependencies for the resource in the format "Type/Name".
#>
[CmdletBinding()]
param(
    [Object[]]$PipelineResources
)

if (-not $PipelineResources) {
    Write-Verbose "[Test-CircularReferences] No resources supplied; nothing to check."
    return
}

# Index the resources once by their "Type/Name" key. The previous implementation re-scanned
# the whole resource array with Where-Object for every dependency of every resource, which is
# quadratic and, worse, resolved nothing consistently when two resources shared a name in
# different cases.
$resourceIndex = [System.Collections.Generic.Dictionary[string, object]]::new(
    [System.StringComparer]::OrdinalIgnoreCase)

foreach ($resource in $PipelineResources) {
    $key = '{0}/{1}' -f $resource.Type, $resource.Name
    if (-not $resourceIndex.ContainsKey($key)) {
        $resourceIndex[$key] = $resource
    }
}

# Nodes whose entire sub-graph has been walked and found acyclic. Re-walking them is pure
# waste, and on a wide diamond it is exponential waste.
$explored = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

# The resources on the current depth-first path, in order, with a companion set for O(1)
# membership tests. A node on this list is an ancestor of the node being visited, which is
# exactly the definition of a cycle.
$path = [System.Collections.Generic.List[string]]::new()
$onPath = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

function Test-ResourceDependencyPath {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ResourceKey,

        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.Dictionary[string, object]]$ResourceIndex,

        # AllowEmptyCollection: these accumulators are empty on the first call, and a
        # mandatory parameter otherwise refuses to bind an empty collection.
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.HashSet[string]]$Explored,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[string]]$Path,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.HashSet[string]]$OnPath
    )

    if ($Explored.Contains($ResourceKey)) {
        Write-Verbose "[Test-CircularReferences] Already explored: $ResourceKey"
        return
    }

    if ($OnPath.Contains($ResourceKey)) {
        # Report the cycle only, not the walk that led to it: trim the path back to the first
        # occurrence of the repeated node so the message names the loop members in order.
        $cycleStart = $Path.IndexOf($ResourceKey)
        if ($cycleStart -lt 0) { $cycleStart = 0 }
        $cycle = $Path.GetRange($cycleStart, $Path.Count - $cycleStart)
        $cycle.Add($ResourceKey)

        throw ("[Test-CircularReferences] Circular dependency detected with Resource: {0}" -f ($cycle -join ' -> '))
    }

    $null = $OnPath.Add($ResourceKey)
    $Path.Add($ResourceKey)

    Write-Verbose "[Test-CircularReferences] Visiting: $ResourceKey"

    foreach ($dependency in $ResourceIndex[$ResourceKey].DependsOn) {

        if ([string]::IsNullOrWhiteSpace($dependency)) { continue }

        $dependencyKey = "$dependency".Trim()

        if (-not $ResourceIndex.ContainsKey($dependencyKey)) {
            Write-Verbose "[Test-CircularReferences] Dependency not found in this configuration: $dependencyKey"
            continue
        }

        Test-ResourceDependencyPath -ResourceKey $dependencyKey -ResourceIndex $ResourceIndex `
            -Explored $Explored -Path $Path -OnPath $OnPath
    }

    # Pop. The missing pop is what made a diamond (two branches meeting at a shared
    # dependency) look like a cycle: the first branch left its nodes on the stack, and the
    # second branch then found them there.
    $Path.RemoveAt($Path.Count - 1)
    $null = $OnPath.Remove($ResourceKey)
    $null = $Explored.Add($ResourceKey)
}

foreach ($resourceKey in $resourceIndex.Keys) {
    Write-Verbose "[Test-CircularReferences] Starting detection for resource: $resourceKey"

    Test-ResourceDependencyPath -ResourceKey $resourceKey -ResourceIndex $resourceIndex `
        -Explored $explored -Path $path -OnPath $onPath
}

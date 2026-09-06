
<#
.SYNOPSIS
Tracks the temporary directories this runner created so they can be cleaned up safely.

.DESCRIPTION
Cleanup must never delete a directory the caller owns: -ConfigurationSourcePath may point
at a working copy on disk, and -CacheDirectory may be a long-lived agent folder. The runner
therefore records the directories it creates itself, and Remove-RunnerTemporaryDirectory
deletes only what appears in that record (#32).

The registry is a module-scoped, case-insensitive set of full paths. It is created on first
use so that dot-sourcing these functions individually (as the test suite does) works the
same way as loading the built module.

.PARAMETER Path
The directory path to record, test, or forget.

.EXAMPLE
Register-RunnerTemporaryDirectory -Path $dir
Test-RunnerTemporaryDirectory -Path $dir      # -> $true

.OUTPUTS
Register/Unregister: none. Test-RunnerTemporaryDirectory: [bool].
#>
function Register-RunnerTemporaryDirectory {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $registry = Get-RunnerTemporaryDirectoryRegistry
    $null = $registry.Add((ConvertTo-RunnerTemporaryDirectoryKey -Path $Path))
}

<#
.SYNOPSIS
Tests whether a directory was created by this runner.

.PARAMETER Path
The directory path to test.

.OUTPUTS
[bool] $true when the path is in the runner's temporary-directory registry.
#>
function Test-RunnerTemporaryDirectory {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }

    $registry = Get-RunnerTemporaryDirectoryRegistry
    return $registry.Contains((ConvertTo-RunnerTemporaryDirectoryKey -Path $Path))
}

<#
.SYNOPSIS
Forgets a directory previously recorded by Register-RunnerTemporaryDirectory.

.PARAMETER Path
The directory path to forget.

.OUTPUTS
None.
#>
function Unregister-RunnerTemporaryDirectory {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $registry = Get-RunnerTemporaryDirectoryRegistry
    $null = $registry.Remove((ConvertTo-RunnerTemporaryDirectoryKey -Path $Path))
}

<#
.SYNOPSIS
Returns the module-scoped registry of runner-created temporary directories.

.OUTPUTS
[System.Collections.Generic.HashSet[string]]
#>
function Get-RunnerTemporaryDirectoryRegistry {
    [CmdletBinding()]
    # Object[] as well as the set itself: the return below wraps the set in a single-element
    # array (see the comment there), which is the static return type the analyzer sees.
    [OutputType([System.Collections.Generic.HashSet[string]], [System.Object[]])]
    param()

    if (-not $script:RunnerTemporaryDirectoryRegistry) {
        $script:RunnerTemporaryDirectoryRegistry =
            [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    }

    # Wrap in a single-element array: PowerShell enumerates a collection on output, so
    # returning the set directly emits nothing at all while it is empty.
    return , $script:RunnerTemporaryDirectoryRegistry
}

<#
.SYNOPSIS
Normalises a path into the key form used by the temporary-directory registry.

.DESCRIPTION
Paths are compared after trimming any trailing directory separator so that
'/tmp/abc' and '/tmp/abc/' are the same entry. The path is not resolved on disk, because
the registry must still recognise a directory after it has been deleted.

.PARAMETER Path
The path to normalise.

.OUTPUTS
[string]
#>
function ConvertTo-RunnerTemporaryDirectoryKey {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    return $Path.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
}

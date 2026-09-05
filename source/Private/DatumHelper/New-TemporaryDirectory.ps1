
<#
.SYNOPSIS
Creates a new, private temporary directory and returns its path.

.DESCRIPTION
The New-TemporaryDirectory function creates a uniquely-named directory and returns its
full path as a [string].

The directory is created with restrictive permissions so that the configuration cloned
into it (which may carry credentials, connection strings, or other sensitive data) is not
world-readable while the run is in progress (#32):

  * On Linux/macOS the mode is set to 0700 (owner read/write/execute only).
  * On Windows the inherited ACL is replaced with a single access rule granting the
    current identity full control.

The directory is recorded in the runner's temporary-directory registry so that
Remove-RunnerTemporaryDirectory can later delete it, while leaving caller-owned
directories alone.

By default the directory is created under the resolved cache directory
(see Resolve-CacheDirectory), keeping run scratch space alongside the rest of the
runner's working files; when no cache directory is configured the system temporary
path is used instead.

.PARAMETER Root
The parent directory to create the temporary directory in. Defaults to the resolved
cache directory, falling back to the system temporary path.

.EXAMPLE
PS C:\> New-TemporaryDirectory

Creates a new temporary directory and returns its full path.

.EXAMPLE
PS C:\> New-TemporaryDirectory -Root 'D:\scratch'

Creates the temporary directory under an explicit parent.

.OUTPUTS
[string] The full path of the newly created directory.

.NOTES
Returns a [string], not a [System.IO.DirectoryInfo]. Callers previously read a `.Path`
property off the returned object; [System.IO.DirectoryInfo] has no such property, so
those call sites silently received $null (#9).
#>
function New-TemporaryDirectory
{
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [string]$Root
    )

    # Prefer the caller's root, then the configured cache directory, then system temp.
    if ([string]::IsNullOrWhiteSpace($Root)) {
        $Root = Resolve-CacheDirectory
    }
    if ([string]::IsNullOrWhiteSpace($Root) -or -not (Test-Path -LiteralPath $Root -PathType Container)) {
        $Root = [System.IO.Path]::GetTempPath()
    }

    $name = [System.IO.Path]::GetRandomFileName()
    $directory = New-Item -ItemType Directory -Path (Join-Path $Root $name)

    # Resolve the path from whichever property the provider surfaced. Tests mock New-Item
    # with a hashtable, so fall back through the usual shapes rather than assuming a type.
    $directoryPath = if ($directory -is [string]) { $directory }
                     elseif ($directory.FullName)  { [string]$directory.FullName }
                     else                          { [string]$directory }

    Set-PrivateDirectoryPermission -Path $directoryPath

    # Record it so Remove-RunnerTemporaryDirectory is able to clean it up later without any
    # risk of deleting a directory the caller owns (#32).
    Register-RunnerTemporaryDirectory -Path $directoryPath

    return $directoryPath
}


<#
.SYNOPSIS
Clones a Git repository to a specified destination path.

.DESCRIPTION
The Clone-Repository function clones a Git repository from a specified URL to a temporary directory.

.PARAMETER DatumURLConfigu
The URL of the Git repository to clone.

.PARAMETER DestinationPath
The path where the repository should be cloned to.

.EXAMPLE
Clone-Repository -DatumURLConfigu "https://github.com/example/repo.git" -DestinationPath "C:\Repositories\Repo"

.NOTES
This function requires Git to be installed and available in the system's PATH.
#>
function Clone-Repository
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$DatumURLConfig
    )

    $tempDirectory = New-TemporaryDirectory
    $GitURL = [System.Uri]::IsWellFormedUriString($DatumURLConfig, [System.UriKind]::Absolute)

    if (-not $GitURL) {
        Throw "[Clone-Repository] The specified Git URL is invalid."
    }

    # Clone the repository into the temporary directory
    $null = git clone $GitURL $tempDirectory

    return $tempDirectory.Path

}

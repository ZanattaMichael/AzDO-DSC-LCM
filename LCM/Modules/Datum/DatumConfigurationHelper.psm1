

function New-TemporaryDirectory
{
    $parent = [System.IO.Path]::GetTempPath()
    $name = [System.IO.Path]::GetRandomFileName()
    New-Item -ItemType Directory -Path (Join-Path $parent $name)
}

function git {
    # Call git with splatting
    try {   
        & (Get-Command git -commandType Application) @args http.extraHeader="Authorization: Basic $JITToken"  2>&1
    } catch {
        $_
    }
}

function Clone-Repository
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$DatumURLConfigu,

        [Parameter(Mandatory=$true)]
        [string]$DestinationPath
    )

    $tempDirectory = New-TemporaryDirectory

    # Clone the repository into the temporary directory
    git clone $GitURL $tempDirectory

}

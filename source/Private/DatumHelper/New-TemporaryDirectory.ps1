
<#
.SYNOPSIS
Creates a new temporary directory.

.DESCRIPTION
The New-TemporaryDirectory function generates a new temporary directory in the system's temporary file path. 
It uses the GetTempPath method to get the path of the temporary folder and GetRandomFileName method to generate a unique directory name.

.EXAMPLE
PS C:\> New-TemporaryDirectory

This command creates a new temporary directory and returns the directory information.

.NOTES
The function does not take any parameters and returns the directory information of the newly created temporary directory.
#>
function New-TemporaryDirectory
{
    $parent = [System.IO.Path]::GetTempPath()
    $name = [System.IO.Path]::GetRandomFileName()
    New-Item -ItemType Directory -Path (Join-Path $parent $name)
}


<#
.SYNOPSIS
    Executes the git command with additional arguments and error handling.

.DESCRIPTION
    This function wraps the git command, allowing it to be called with additional arguments using splatting.
    It also includes error handling to catch and return any errors that occur during execution.

.PARAMETER args
    The arguments to pass to the git command.

.PARAMETER JITToken
    The token used for authorization, passed as an extra header to the git command.

.EXAMPLE
    git clone https://example.com/repo.git

.NOTES
    Ensure that the git executable is available in the system's PATH.
#>
function git {
    # Call git with splatting
    try {   
        & (Get-Command git -commandType Application) @args http.extraHeader="Authorization: Basic $JITToken"  2>&1
    } catch {
        $_
    }
}

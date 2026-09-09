<#
.SYNOPSIS
Credential action: build a PSCredential from environment variables (#57 §5).

.DESCRIPTION
Reads a username and password from two named environment variables and returns a
[PSCredential]. Intended as the default, CI/CD-friendly credential source - a pipeline
already has a mechanism for injecting secrets as environment variables (Azure DevOps secret
variables, GitHub Actions secrets, etc.) without them ever being written to a configuration
file.

.PARAMETER Context
Hashtable with:
  UserNameVariable [string] - required, name of the environment variable holding the username.
  PasswordVariable [string] - required, name of the environment variable holding the password.

.OUTPUTS
[PSCredential]
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '',
    Justification = 'The password genuinely arrives as plaintext from a pipeline-provided environment variable (the whole point of this action); SecureString conversion is required to build the PSCredential, and the plaintext is never written to any output stream.')]
param(
    [hashtable]$Context = @{}
)

$userNameVariable = [string]$Context.UserNameVariable
$passwordVariable = [string]$Context.PasswordVariable

if ([string]::IsNullOrWhiteSpace($userNameVariable) -or [string]::IsNullOrWhiteSpace($passwordVariable)) {
    throw "[Actions/Credential/Environment] 'UserNameVariable' and 'PasswordVariable' are both required in the Credential context."
}

$userName = [System.Environment]::GetEnvironmentVariable($userNameVariable)
$password = [System.Environment]::GetEnvironmentVariable($passwordVariable)

if ([string]::IsNullOrEmpty($userName) -or [string]::IsNullOrEmpty($password)) {
    throw "[Actions/Credential/Environment] Environment variable(s) '$userNameVariable'/'$passwordVariable' are not set."
}

$securePassword = ConvertTo-SecureString -String $password -AsPlainText -Force
return [System.Management.Automation.PSCredential]::new($userName, $securePassword)

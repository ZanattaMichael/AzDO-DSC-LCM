<#
.SYNOPSIS
Credential action: build a PSCredential from a value already present in the context (#57 §5).

.DESCRIPTION
Wraps a username/password supplied directly in the Credential context into a [PSCredential].
This is the escape hatch for local development and testing, not a recommended production
path - a Static credential means the secret already exists in plain form somewhere the
runner could read it directly (a variable, an already-decrypted context), so it emits a
warning on every use as a nudge toward Environment or SecretManagement.

.PARAMETER Context
Hashtable with:
  UserName [string]                     - required.
  Password [string] or [securestring]   - required.

.OUTPUTS
[PSCredential]
#>
param(
    [hashtable]$Context = @{}
)

if ([string]::IsNullOrWhiteSpace([string]$Context.UserName) -or $null -eq $Context.Password) {
    throw "[Actions/Credential/Static] 'UserName' and 'Password' are both required in the Credential context."
}

Write-Warning "[Actions/Credential/Static] Using a statically-configured credential. Prefer the 'Environment' or 'SecretManagement' Credential actions in production."

$securePassword = if ($Context.Password -is [securestring]) {
    $Context.Password
}
else {
    ConvertTo-SecureString -String ([string]$Context.Password) -AsPlainText -Force
}

return [System.Management.Automation.PSCredential]::new([string]$Context.UserName, $securePassword)

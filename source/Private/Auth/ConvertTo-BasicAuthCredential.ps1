
<#
.SYNOPSIS
Normalises a token into a base64-encoded HTTP Basic credential.

.DESCRIPTION
HTTP Basic authentication carries a base64 encoding of "user:password". Azure DevOps and
GitHub both accept an empty (or arbitrary) user with the token as the password, so a PAT
is used as `:<token>` / `x-access-token:<token>`.

Callers hand this function whichever form they happen to hold:

  * A raw PAT or $env:SYSTEM_ACCESSTOKEN - encoded here as "x-access-token:<token>".
  * An already base64-encoded "user:password" pair - returned unchanged, so existing
    pipelines that pre-encode their credential keep working.

The already-encoded case is detected by base64-decoding the input and checking that the
result is printable ASCII containing a colon. That is the shape of a Basic credential and
is not the shape of a PAT, which is why the heuristic is safe: a raw Azure DevOps or
GitHub token either fails to base64-decode at all or decodes to bytes that are not
printable text.

.PARAMETER Token
The credential to normalise.

.EXAMPLE
ConvertTo-BasicAuthCredential -Token 'abc123'
Returns the base64 encoding of 'x-access-token:abc123'.

.EXAMPLE
ConvertTo-BasicAuthCredential -Token ([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(':abc123')))
Returns its input unchanged - it is already a Basic credential.

.OUTPUTS
[string] A base64-encoded "user:password" pair.
#>
function ConvertTo-BasicAuthCredential {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Token
    )

    if ([string]::IsNullOrWhiteSpace($Token)) {
        return $Token
    }

    if (Test-BasicAuthCredential -Value $Token) {
        # Already a "user:password" pair - pass it through untouched.
        return $Token
    }

    return [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("x-access-token:$Token"))
}

<#
.SYNOPSIS
Tests whether a string is already a base64-encoded HTTP Basic credential.

.DESCRIPTION
Returns $true when the supplied value base64-decodes to printable ASCII that contains a
colon - the "user:password" shape of a Basic credential. Any other input (including a raw
PAT) returns $false.

.PARAMETER Value
The string to test.

.OUTPUTS
[bool]
#>
function Test-BasicAuthCredential {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }

    # Base64 length is always a multiple of four; bail out early otherwise.
    if (($Value.Length % 4) -ne 0) { return $false }
    if ($Value -notmatch '^[A-Za-z0-9+/]+={0,2}$') { return $false }

    try {
        $bytes = [Convert]::FromBase64String($Value)
    }
    catch {
        return $false
    }

    if ($bytes.Length -eq 0) { return $false }

    # Printable ASCII (plus tab) only - a decoded PAT is almost always binary noise.
    foreach ($byte in $bytes) {
        if ($byte -ne 9 -and ($byte -lt 32 -or $byte -gt 126)) { return $false }
    }

    $decoded = [System.Text.Encoding]::ASCII.GetString($bytes)
    return $decoded.Contains(':')
}

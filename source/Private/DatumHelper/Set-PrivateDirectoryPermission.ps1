
<#
.SYNOPSIS
Restricts a directory's permissions to the current identity.

.DESCRIPTION
Cloned configuration and compiled Datum output can contain sensitive material, so the
scratch directories the runner creates must not be readable by other users on a shared
build agent (#32). This helper applies the platform's equivalent of "owner only":

  * Linux/macOS - sets the Unix file mode to 0700 via [System.IO.File]::SetUnixFileMode.
  * Windows     - disables ACL inheritance, removes the inherited rules, and adds a single
                  FullControl rule for the current Windows identity.

Failures are reported as warnings rather than terminating errors: a directory that could
not be locked down is a hardening gap, not a reason to abort a pipeline run that is
otherwise able to proceed.

.PARAMETER Path
The directory to restrict. Must already exist.

.EXAMPLE
PS C:\> Set-PrivateDirectoryPermission -Path '/tmp/abc123'

.NOTES
[System.IO.File]::SetUnixFileMode is available from .NET 7 (PowerShell 7.3) onward; on
older hosts the call is skipped and a warning is emitted.
#>
function Set-PrivateDirectoryPermission {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not $PSCmdlet.ShouldProcess($Path, 'Restrict directory permissions to the current identity')) {
        return
    }

    try {
        if ($IsWindows -or $env:OS -eq 'Windows_NT') {
            $acl = Get-Acl -LiteralPath $Path

            # Break inheritance and drop the inherited rules, then grant only this identity.
            $acl.SetAccessRuleProtection($true, $false)
            foreach ($rule in @($acl.Access)) {
                $null = $acl.RemoveAccessRule($rule)
            }

            $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $identity,
                [System.Security.AccessControl.FileSystemRights]::FullControl,
                @([System.Security.AccessControl.InheritanceFlags]::ContainerInherit,
                  [System.Security.AccessControl.InheritanceFlags]::ObjectInherit),
                [System.Security.AccessControl.PropagationFlags]::None,
                [System.Security.AccessControl.AccessControlType]::Allow)
            $acl.AddAccessRule($rule)

            Set-Acl -LiteralPath $Path -AclObject $acl
        }
        else {
            $setUnixFileMode = [System.IO.File].GetMethod('SetUnixFileMode', [type[]]@([string], [System.IO.UnixFileMode]))
            if ($null -eq $setUnixFileMode) {
                Write-Warning "[Set-PrivateDirectoryPermission] This host does not support setting Unix file modes; '$Path' keeps its default permissions."
                return
            }

            # 0700 - owner read/write/execute, nothing for group or other.
            $mode = [System.IO.UnixFileMode]::UserRead -bor
                    [System.IO.UnixFileMode]::UserWrite -bor
                    [System.IO.UnixFileMode]::UserExecute
            $null = $setUnixFileMode.Invoke($null, @($Path, $mode))
        }
    }
    catch {
        Write-Warning "[Set-PrivateDirectoryPermission] Could not restrict permissions on '$Path': $($_.Exception.Message)"
    }
}

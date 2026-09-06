
<#
.SYNOPSIS
Deletes a temporary directory the runner created, and only such a directory.

.DESCRIPTION
Clones and compile scratch directories used to be left on disk for the lifetime of the
build agent, leaking configuration (and anything sensitive inside it) between runs (#32).
This helper is the cleanup half of that lifecycle.

It deliberately refuses to delete anything the runner did not create. New-TemporaryDirectory
records every directory it makes in a module-scoped registry, and Remove-RunnerTemporaryDirectory
removes a path only if it is in that registry. A caller-supplied configuration directory or
cache directory therefore survives untouched even when it is passed in here, which is what
makes it safe to call this unconditionally from a finally block.

Removal failures are warnings, not errors: a locked file in scratch space must not turn an
otherwise successful run into a failed one.

.PARAMETER Path
The directory to remove. Ignored unless the runner created it.

.EXAMPLE
$dir = New-TemporaryDirectory
try     { Build-DatumConfiguration -ConfigurationPath $dir -OutputPath $out }
finally { Remove-RunnerTemporaryDirectory -Path $dir }

.OUTPUTS
None.
#>
function Remove-RunnerTemporaryDirectory {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param(
        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) { return }

    if (-not (Test-RunnerTemporaryDirectory -Path $Path)) {
        Write-Verbose "[Remove-RunnerTemporaryDirectory] '$Path' was not created by this runner; leaving it in place."
        return
    }

    if (-not (Test-Path -LiteralPath $Path)) {
        $null = Unregister-RunnerTemporaryDirectory -Path $Path
        return
    }

    if (-not $PSCmdlet.ShouldProcess($Path, 'Remove temporary directory')) { return }

    try {
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
        Write-Verbose "[Remove-RunnerTemporaryDirectory] Removed '$Path'."
        $null = Unregister-RunnerTemporaryDirectory -Path $Path
    }
    catch {
        # Scratch that could not be cleaned up is a hygiene problem, not a run failure.
        Write-Warning "[Remove-RunnerTemporaryDirectory] Could not remove '$Path': $($_.Exception.Message)"
    }
}

Describe 'Set-PrivateDirectoryPermission Function Tests' {

    BeforeAll {
        . (Get-FunctionPath 'Set-PrivateDirectoryPermission.ps1').FullName
    }

    Context 'On a Unix host' -Skip:($IsWindows -or $env:OS -eq 'Windows_NT') {

        It 'Should restrict the directory to mode 0700' {
            # Arrange
            $directory = Join-Path $TestDrive ([System.IO.Path]::GetRandomFileName())
            $null = New-Item -ItemType Directory -Path $directory

            # Act
            Set-PrivateDirectoryPermission -Path $directory

            # Assert
            $mode = [System.IO.File]::GetUnixFileMode($directory)
            $mode | Should -Be ([System.IO.UnixFileMode]::UserRead -bor
                                [System.IO.UnixFileMode]::UserWrite -bor
                                [System.IO.UnixFileMode]::UserExecute)
        }

        It 'Should leave the directory usable by the current process' {
            # Arrange
            $directory = Join-Path $TestDrive ([System.IO.Path]::GetRandomFileName())
            $null = New-Item -ItemType Directory -Path $directory

            # Act
            Set-PrivateDirectoryPermission -Path $directory
            $file = Join-Path $directory 'probe.txt'
            Set-Content -LiteralPath $file -Value 'probe'

            # Assert
            Get-Content -LiteralPath $file | Should -Be 'probe'
        }
    }

    Context 'When the directory cannot be secured' {

        It 'Should warn rather than throw' {
            $missing = Join-Path $TestDrive 'no-such-directory'

            { Set-PrivateDirectoryPermission -Path $missing -WarningAction SilentlyContinue } | Should -Not -Throw
        }
    }
}

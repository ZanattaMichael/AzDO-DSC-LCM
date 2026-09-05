Describe 'Runner temporary directory lifecycle Tests' {

    BeforeAll {
        . (Get-FunctionPath 'Register-RunnerTemporaryDirectory.ps1').FullName
        . (Get-FunctionPath 'Remove-RunnerTemporaryDirectory.ps1').FullName

        function New-TestDirectory {
            $path = Join-Path $TestDrive ([System.IO.Path]::GetRandomFileName())
            $null = New-Item -ItemType Directory -Path $path
            return $path
        }
    }

    Context 'Registry' {

        It 'Should report a registered directory as runner-created' {
            $path = New-TestDirectory
            Register-RunnerTemporaryDirectory -Path $path

            Test-RunnerTemporaryDirectory -Path $path | Should -BeTrue
        }

        It 'Should report an unregistered directory as caller-owned' {
            Test-RunnerTemporaryDirectory -Path (New-TestDirectory) | Should -BeFalse
        }

        It 'Should ignore a trailing directory separator' {
            $path = New-TestDirectory
            Register-RunnerTemporaryDirectory -Path $path

            Test-RunnerTemporaryDirectory -Path ($path + [System.IO.Path]::DirectorySeparatorChar) | Should -BeTrue
        }

        It 'Should report an empty path as caller-owned' {
            Test-RunnerTemporaryDirectory -Path '' | Should -BeFalse
        }

        It 'Should forget a directory once unregistered' {
            $path = New-TestDirectory
            Register-RunnerTemporaryDirectory -Path $path
            Unregister-RunnerTemporaryDirectory -Path $path

            Test-RunnerTemporaryDirectory -Path $path | Should -BeFalse
        }
    }

    Context 'Removal' {

        It 'Should delete a directory the runner created' {
            $path = New-TestDirectory
            Set-Content -LiteralPath (Join-Path $path 'file.txt') -Value 'content'
            Register-RunnerTemporaryDirectory -Path $path

            Remove-RunnerTemporaryDirectory -Path $path

            Test-Path -LiteralPath $path | Should -BeFalse
        }

        It 'Should never delete a caller-owned directory' {
            # The safety property that makes it valid to call this unconditionally from a
            # finally block: -ConfigurationSourcePath may be the user's working copy (#32).
            $path = New-TestDirectory

            Remove-RunnerTemporaryDirectory -Path $path

            Test-Path -LiteralPath $path | Should -BeTrue
        }

        It 'Should forget the directory after deleting it' {
            $path = New-TestDirectory
            Register-RunnerTemporaryDirectory -Path $path

            Remove-RunnerTemporaryDirectory -Path $path

            Test-RunnerTemporaryDirectory -Path $path | Should -BeFalse
        }

        It 'Should tolerate a registered directory that is already gone' {
            $path = New-TestDirectory
            Register-RunnerTemporaryDirectory -Path $path
            Remove-Item -LiteralPath $path -Recurse -Force

            { Remove-RunnerTemporaryDirectory -Path $path } | Should -Not -Throw
        }

        It 'Should tolerate a null or empty path' {
            { Remove-RunnerTemporaryDirectory -Path $null } | Should -Not -Throw
            { Remove-RunnerTemporaryDirectory -Path '' } | Should -Not -Throw
        }

        It 'Should warn rather than throw when removal fails' {
            $path = New-TestDirectory
            Register-RunnerTemporaryDirectory -Path $path
            Mock Remove-Item { throw 'in use' }

            { Remove-RunnerTemporaryDirectory -Path $path -WarningAction SilentlyContinue } | Should -Not -Throw
        }
    }

    Context 'Integration with New-TemporaryDirectory' {

        BeforeAll {
            . (Get-FunctionPath 'Resolve-CacheDirectory.ps1').FullName
            . (Get-FunctionPath 'Set-PrivateDirectoryPermission.ps1').FullName
            . (Get-FunctionPath 'New-TemporaryDirectory.ps1').FullName
        }

        It 'Should register and then clean up a directory it created' {
            $path = New-TemporaryDirectory -Root $TestDrive

            Test-Path -LiteralPath $path | Should -BeTrue
            Test-RunnerTemporaryDirectory -Path $path | Should -BeTrue

            Remove-RunnerTemporaryDirectory -Path $path

            Test-Path -LiteralPath $path | Should -BeFalse
        }
    }
}

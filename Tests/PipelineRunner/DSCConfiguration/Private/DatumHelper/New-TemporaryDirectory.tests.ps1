Describe 'New-TemporaryDirectory Function Tests' {

    BeforeAll {

        # Load the functions to test. New-TemporaryDirectory resolves its default root via
        # Resolve-CacheDirectory and hardens the result via Set-PrivateDirectoryPermission,
        # so both are dot-sourced alongside it.
        . (Get-FunctionPath 'Resolve-CacheDirectory.ps1').FullName
        . (Get-FunctionPath 'Set-PrivateDirectoryPermission.ps1').FullName
        . (Get-FunctionPath 'Register-RunnerTemporaryDirectory.ps1').FullName
        . (Get-FunctionPath 'New-TemporaryDirectory.ps1').FullName

        Mock -CommandName New-Item -MockWith {
            param($ItemType, $Path)
            return [pscustomobject]@{
                PSIsContainer = $true
                Name          = Split-Path -Path $Path -Leaf
                FullName      = $Path
            }
        }

        Mock -CommandName Set-PrivateDirectoryPermission -MockWith { }
    }

    AfterEach {
        Remove-Item -Path Env:PIPELINERUNNER_CACHE_DIRECTORY, Env:AZDODSC_CACHE_DIRECTORY -ErrorAction SilentlyContinue
    }

    Context 'When creating a new temporary directory' {

        It 'Should return the directory path as a string, not a DirectoryInfo' {
            # Act
            $result = New-TemporaryDirectory

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [string]
            Assert-MockCalled New-Item -Exactly 1 -Scope It
        }

        It 'Should create the directory under the system temp path when no cache directory is set' {
            # Act
            $result = New-TemporaryDirectory

            # Assert
            $tempPath = [System.IO.Path]::GetTempPath().TrimEnd([System.IO.Path]::DirectorySeparatorChar)
            (Split-Path -Path $result -Parent) | Should -Be $tempPath
        }

        It 'Should restrict the new directory to the current identity' {
            # Act
            $null = New-TemporaryDirectory

            # Assert
            Assert-MockCalled Set-PrivateDirectoryPermission -Exactly 1 -Scope It
        }
    }

    Context 'When a root is supplied' {

        It 'Should create the directory under the explicit -Root' {
            # Arrange
            $root = $TestDrive

            # Act
            $result = New-TemporaryDirectory -Root $root

            # Assert
            (Split-Path -Path $result -Parent) | Should -Be $root
        }

        It 'Should fall back to the system temp path when -Root does not exist' {
            # Arrange
            $missing = Join-Path $TestDrive 'does-not-exist'

            # Act
            $result = New-TemporaryDirectory -Root $missing

            # Assert
            $tempPath = [System.IO.Path]::GetTempPath().TrimEnd([System.IO.Path]::DirectorySeparatorChar)
            (Split-Path -Path $result -Parent) | Should -Be $tempPath
        }

        It 'Should use the configured cache directory when no -Root is supplied' {
            # Arrange
            $env:PIPELINERUNNER_CACHE_DIRECTORY = $TestDrive

            # Act
            $result = New-TemporaryDirectory

            # Assert
            (Split-Path -Path $result -Parent) | Should -Be $TestDrive
        }
    }
}

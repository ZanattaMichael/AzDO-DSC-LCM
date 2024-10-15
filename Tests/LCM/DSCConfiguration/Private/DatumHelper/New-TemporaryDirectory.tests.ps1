
Describe 'New-TemporaryDirectory Function Tests' {

    BeforeAll {

        # Load the functions to test
        $preParseFilePath = (Get-FunctionPath 'New-TemporaryDirectory.ps1').FullName
        . $preParseFilePath

        Mock -CommandName New-Item -MockWith {
            param($ItemType, $Path)
            return @{
                PSPath = "Microsoft.PowerShell.Core\FileSystem::C:\Temp\SomeRandomDir"
                PSParentPath = "Microsoft.PowerShell.Core\FileSystem::C:\Temp"
                PSChildName = "SomeRandomDir"
                PSDrive = @{ Name = "C" }
                PSProvider = @{ Name = "FileSystem" }
                PSIsContainer = $true
                BaseName = "SomeRandomDir"
                Mode = "d----"
                Name = "SomeRandomDir"
                FullName = "C:\Temp\SomeRandomDir"
                Parent = "C:\Temp"
            }
        }

    }

    Context 'When creating a new temporary directory' {
        It 'Should create a directory in the temp path' {
            # Arrange
            $tempPath = [System.IO.Path]::GetTempPath()

            # Act
            $result = New-TemporaryDirectory

            # Assert
            $result | Should -Not -BeNullOrEmpty
            Assert-MockCalled New-Item -Exactly 1 -Scope It
        }
    }

}

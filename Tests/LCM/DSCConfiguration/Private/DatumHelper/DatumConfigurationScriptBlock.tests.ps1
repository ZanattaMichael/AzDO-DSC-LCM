Describe 'DatumConfigurationScriptBlock Function Tests' {

    BeforeAll {

        # Load the functions to test
        $preParseFilePath = (Get-FunctionPath 'DatumConfigurationScriptBlock.ps1').FullName
        $testDatumConfigurationFilePath = (Get-FunctionPath 'Test-DatumConfiguration.ps1').FullName
        $resolveAzDoDatumProjectFilePath = (Get-FunctionPath 'Resolve-AzDoDatumProject.ps1').FullName

        . $preParseFilePath
        . $testDatumConfigurationFilePath
        . $resolveAzDoDatumProjectFilePath

        # Mock necessary commands to isolate the function's behavior
        Mock -CommandName New-DatumStructure -MockWith { @{Projects = @{}} }
        Mock -CommandName Test-DatumConfiguration
        Mock -CommandName Resolve-AzDoDatumProject
        Mock -CommandName Set-Location
        Mock -CommandName Import-Module

    }

    Context "Function Invocation Check" {

        It "Should throw an error when executed directly" {
            # Simulate direct execution
            $MyInvocation = [PSCustomObject]@{ MyCommand = [PSCustomObject]@{ Name = 'DatumConfigurationScriptBlock' } }
            
            { DatumConfigurationScriptBlock -OutputPath "C:\Output" -ConfigurationPath "C:\Configuration" } | Should -Throw  "This function is intended to be used as a script block in a separate thread using the Build-DatumConfiguration function."

        }
    }

    Context "Module Import Verification" {

        It "Should import all necessary modules" {
            # Execute the function in a simulated environment
            DatumConfigurationScriptBlock -OutputPath "C:\Output" -configurationPath "C:\Configuration" -isTest

            # Verify that Import-Module was called with expected parameters
            Assert-MockCalled -CommandName Import-Module -Exactly 1 -Scope It -ParameterFilter { 
                ($Name -eq 'azdo-dsc-lcm') -or 
                ($Name -eq 'powershell-yaml') -or
                ($Name -eq 'datum') -or
                ($Name -eq 'datum.invokecommand')
            }
        }
    }

    Context "Directory Change Verification" {

        It "Should change the current directory to the specified configuration path" {
            DatumConfigurationScriptBlock -OutputPath "C:\Output" -ConfigurationPath "C:\Configuration" -isTest

            Assert-MockCalled -CommandName Set-Location -Exactly 1 -ParameterFilter { $Path -eq 'C:\Configuration' }
        }
    }

    Context "Datum Structure Creation" {

        It "Should create a new Datum structure from the definition file" {
            DatumConfigurationScriptBlock -OutputPath "C:\Output" -ConfigurationPath "C:\Configuration" -isTest

            Assert-MockCalled -CommandName New-DatumStructure -Times 1
        }
    }

    Context "Configuration Testing" {

        It "Should test the Datum configuration" {
            DatumConfigurationScriptBlock -OutputPath "C:\Output" -ConfigurationPath "C:\Configuration" -isTest

            Assert-MockCalled -CommandName Test-DatumConfiguration -Exactly 1
        }
    }

    Context "Project Node Resolution" {

        It "Should resolve each project node correctly" {
            # Mock the return value of New-DatumStructure to simulate projects
            Mock -CommandName New-DatumStructure -MockWith {
                @{
                    Projects = [PSCustomObject]@{
                        ProjectType1 = [PSCustomObject]@{
                            ProjectNode1 = @{ Name = 'Node1' }
                            ProjectNode2 = @{ Name = 'Node2' }
                        }
                    }
                }
            }

            DatumConfigurationScriptBlock -OutputPath "C:\Output" -ConfigurationPath "C:\Configuration" -isTest

            Assert-MockCalled -CommandName Resolve-AzDoDatumProject -Exactly 2 -Scope It
        }
    }

}
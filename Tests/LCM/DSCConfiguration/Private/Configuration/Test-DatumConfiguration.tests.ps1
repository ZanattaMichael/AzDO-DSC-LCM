Describe "Test-DatumConfiguration Function Tests" -Tag Unit, LCM, Configuration {

    BeforeAll {

        # Load the functions to test
        $preParseFilePath = (Get-FunctionPath 'Test-DatumConfiguration.ps1').FullName
        
        . $preParseFilePath


        # Mocking Get-Module to return controlled version information
        Mock -CommandName Get-Module -MockWith {
            param($name)
            switch ($name) {
                'PSDesiredStateConfiguration' { @{ Version = [version]"2.0.0" } }
                'azdo-dsc-lcm' { @{ Version = [version]"1.0.0" } }
                default { $null }
            }
        }

        
        Mock -CommandName Write-Warning

    }

    Context "When Datum Configuration is Valid" {
        It "should pass without errors" {
            $datumConfig = @{
                '__Definition' = @{
                    LCMConfigSettings = @{
                        ConfigurationVersion = "1.0.0"
                        AZDOLCMVersion = "1.0.0"
                        DSCResourceVersion = "1.0.0"
                    }
                }
            }

            $ModuleConfigurationData = @{
                YAMLConfigurationMinimumVersion = "0.9.0"
                YAMLConfigurationMaximumVersion = "2.0.0"
                PSDesiredStateConfigurationMinimumVersion = "1.0.0"
                PSDesiredStateConfigurationMaximumVersion = "2.0.0"
                DSCResourceMinimumVersion = "1.0.0"
                DSCResourceMaximumVersion = "2.0.0"
            }

            { Test-DatumConfiguration -Datum $datumConfig } | Should -Not -Throw
            Assert-MockCalled Write-Warning -Exactly 0
        }
    }
 
    Context "When LCMConfigSettings is Missing" {
        It "should throw an error" {
            $datumConfig = @{}
            { Test-DatumConfiguration -Datum $datumConfig } | Should -Throw -ErrorId "*LCMConfigSettings*"
            Assert-MockCalled Write-Warning -Exactly 0
        }
    }

    Context "When Versions are Invalid" {
        It "should throw an error if version fields are not valid" {
            $datumConfig = @{
                '__Definition' = @{
                    LCMConfigSettings = @{
                        ConfigurationVersion = "invalid"
                        AZDOLCMVersion = "1.0.0"
                        DSCResourceVersion = "1.0.0"
                    }
                }
            }
            $ModuleConfigurationData = @{
                YAMLConfigurationMinimumVersion = "0.9.0"
                YAMLConfigurationMaximumVersion = "2.0.0"
            }
            { Test-DatumConfiguration -Datum $datumConfig } | Should -Throw -ErrorId "*valid version*"
            Assert-MockCalled Write-Warning -Exactly 0
        }
    }

    Context "When Datum Configuration Version is Out of Range" {
        It "should throw an error if version is outside the valid range" {
            $datumConfig = @{
                '__Definition' = @{
                    LCMConfigSettings = @{
                        ConfigurationVersion = "3.0.0"
                        AZDOLCMVersion = "1.0.0"
                        DSCResourceVersion = "1.0.0"
                    }
                }
            }

            $ModuleConfigurationData = @{
                YAMLConfigurationMinimumVersion = "0.9.0"
                YAMLConfigurationMaximumVersion = "2.0.0"
            }
            { Test-DatumConfiguration -Datum $datumConfig } | Should -Throw -ErrorId "*outside the valid range*"
            Assert-MockCalled Write-Warning -Exactly 0
        }
    }

    Context "When Datum Configuration Version is Outdated" {
        It "should issue a warning if two or more minor versions behind" {


            $datumConfig = @{
                '__Definition' = @{
                    LCMConfigSettings = @{
                        ConfigurationVersion = "1.8.0"
                        AZDOLCMVersion = "1.0.0"
                        DSCResourceVersion = "1.0.0"
                    }
                }
            }

            $ModuleConfigurationData = @{
                YAMLConfigurationMinimumVersion = "0.9.0"
                YAMLConfigurationMaximumVersion = "2.0.0"
                PSDesiredStateConfigurationMinimumVersion = "1.0.0"
                PSDesiredStateConfigurationMaximumVersion = "2.0.0"
                DSCResourceMinimumVersion = "1.0.0"
                DSCResourceMaximumVersion = "2.0.0"
            }

            Test-DatumConfiguration -Datum $datumConfig
            Assert-MockCalled Write-Warning -Exactly 1

        }
    }

    Context "When the PSDesiredStateConfiguration is Outdated" {

        it "Should throw an error if outside the valid range" {

            Mock Get-Command 

            $datumConfig = @{
                '__Definition' = @{
                    LCMConfigSettings = @{
                        ConfigurationVersion = "1.0.0"
                        AZDOLCMVersion = "1.0.0"
                        DSCResourceVersion = "1.0.0"
                    }
                }
            }

            $ModuleConfigurationData = @{
                YAMLConfigurationMinimumVersion = "0.9.0"
                YAMLConfigurationMaximumVersion = "2.0.0"
                PSDesiredStateConfigurationMinimumVersion = "1.0.0"
                PSDesiredStateConfigurationMaximumVersion = "2.0.0"
                DSCResourceMinimumVersion = "1.0.0"
                DSCResourceMaximumVersion = "2.0.0"
            }

            Test-DatumConfiguration -Datum $datumConfig
            Assert-MockCalled Write-Warning -Exactly 0
        }

    }
}

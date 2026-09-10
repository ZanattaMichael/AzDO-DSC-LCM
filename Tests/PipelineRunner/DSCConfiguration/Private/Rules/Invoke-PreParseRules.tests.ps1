Describe "Invoke-PreParseRules Function Tests" -Tag Unit, Runner, Configuration {


    BeforeAll {

        # Load the functions to test
        $preParseFilePath = (Get-FunctionPath 'Invoke-PreParseRules.ps1').FullName
        . $preParseFilePath

        # Setup a temp powershell file to be dot sourced
        $rulePath = Join-Path $TestDrive '\Pipeline Rules\PreParse\MyCustomRule.ps1'
        $rulePath2 = Join-Path $TestDrive '\Pipeline Rules\PreParse\MyCustomRule2.ps1'

        # Create the folderpath
        $null = New-Item -Path (Split-Path $rulePath) -ItemType Directory -Force
        
        $file = '
        param(
            [Object[]]$PipelineResources
        )
        '
        
        $file | Set-Content -Path $rulePath
        $file | Set-Content -Path $rulePath2

        Mock -CommandName Get-Module -MockWith { return (
            @{
                moduleBase = $TestDrive 
            })
        } -Verifiable
        
        
    }

    It "Should trigger the custom task scripts" {
        $tasks = @("Task1", "Task2")

        $result = Invoke-PreParseRules -Tasks $tasks
        Assert-MockCalled -CommandName Get-Module
        
    }

    It "Should throw an error if the custom task script does not exist" {
        Mock -CommandName Get-Module -MockWith { return (
            @{
                moduleBase = 'fakepath' 
            })
        }

        $tasks = @("Task1", "Task2")
        $customTaskName = "NonExistentTask"

        { Invoke-PreParseRules -Tasks $tasks } | Should -Throw '*No Tasks to Process in Directory*'
    }

    AfterAll {
        # Remove the temp powershell file
        Remove-Item -Path $rulePath -Force
    }

    Context "-Settings forwarding (#57 §2)" {

        BeforeAll {
            Mock -CommandName Get-Module -MockWith { return @{ moduleBase = $TestDrive } }
        }

        It "forwards -Settings to a rule script that declares it" {
            $settingsAwareRulePath = Join-Path $TestDrive '\Pipeline Rules\PreParse\SettingsAwareRule.ps1'
            $null = New-Item -Path (Split-Path $settingsAwareRulePath) -ItemType Directory -Force
            @'
param(
    [Object[]]$PipelineResources,
    [hashtable]$Settings
)
if ($Settings.ContainsKey('Marker')) {
    $Global:InvokePreParseRulesCapturedMarker = $Settings['Marker']
}
'@ | Set-Content -Path $settingsAwareRulePath

            $Global:InvokePreParseRulesCapturedMarker = $null
            Invoke-PreParseRules -Tasks @('Task1') -Settings @{ Marker = 'seen' }

            $Global:InvokePreParseRulesCapturedMarker | Should -Be 'seen'
            Remove-Item -Path $settingsAwareRulePath -Force
            Remove-Variable -Name InvokePreParseRulesCapturedMarker -Scope Global -ErrorAction SilentlyContinue
        }

        It "does not pass -Settings to a rule script that only declares -PipelineResources (back-compat)" {
            $legacyRulePath = Join-Path $TestDrive '\Pipeline Rules\PreParse\LegacyRule.ps1'
            $null = New-Item -Path (Split-Path $legacyRulePath) -ItemType Directory -Force
            @'
param(
    [Object[]]$PipelineResources
)
'@ | Set-Content -Path $legacyRulePath

            { Invoke-PreParseRules -Tasks @('Task1') -Settings @{ Marker = 'seen' } } | Should -Not -Throw
            Remove-Item -Path $legacyRulePath -Force
        }
    }

}
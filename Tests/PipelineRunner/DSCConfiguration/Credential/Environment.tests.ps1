Describe "Actions/Credential/Environment Tests" -Tag Unit, Credential {

    BeforeAll {
        $script:EnvironmentPath = (Get-FunctionPath 'Environment.ps1').FullName
    }

    AfterEach {
        Remove-Item Env:\DscPipelineRunnerTestUser -ErrorAction SilentlyContinue
        Remove-Item Env:\DscPipelineRunnerTestPass -ErrorAction SilentlyContinue
    }

    It "Throws when UserNameVariable or PasswordVariable is missing from the context" {
        { & $script:EnvironmentPath -Context @{} } | Should -Throw "*required*"
        { & $script:EnvironmentPath -Context @{ UserNameVariable = 'X' } } | Should -Throw "*required*"
    }

    It "Throws when the named environment variables are not set" {
        { & $script:EnvironmentPath -Context @{ UserNameVariable = 'DscPipelineRunnerTestUser'; PasswordVariable = 'DscPipelineRunnerTestPass' } } |
            Should -Throw "*not set*"
    }

    It "Builds a PSCredential from the named environment variables" {
        $env:DscPipelineRunnerTestUser = 'svc-account'
        $env:DscPipelineRunnerTestPass = 'super-secret'

        $result = & $script:EnvironmentPath -Context @{ UserNameVariable = 'DscPipelineRunnerTestUser'; PasswordVariable = 'DscPipelineRunnerTestPass' }

        $result | Should -BeOfType ([System.Management.Automation.PSCredential])
        $result.UserName | Should -Be 'svc-account'
        $result.GetNetworkCredential().Password | Should -Be 'super-secret'
    }
}

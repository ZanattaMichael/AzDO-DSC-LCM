Describe "result Function Tests" -Tag Unit, Runner {

    BeforeAll {
        . (Get-FunctionPath 'result.ps1').FullName
    }

    It "returns the module-scope currentResourceResult" {
        $script:currentResourceResult = [pscustomobject]@{ InDesiredState = $true; Message = 'ok' }

        $value = result

        $value.InDesiredState | Should -BeTrue
        $value.Message | Should -Be 'ok'
    }

    It "returns `$null when no resource result has been set" {
        $script:currentResourceResult = $null

        result | Should -BeNullOrEmpty
    }
}

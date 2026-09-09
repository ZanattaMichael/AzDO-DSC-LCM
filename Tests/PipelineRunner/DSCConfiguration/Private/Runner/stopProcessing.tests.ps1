Describe "stopProcessing Function Tests" -Tag Unit, Runner {

    BeforeAll {
        . (Get-FunctionPath 'stopProcessing.ps1').FullName
    }

    BeforeEach {
        $script:StopTaskProcessing = $false
    }

    It "sets the module-scope StopTaskProcessing flag" {
        stopProcessing

        $script:StopTaskProcessing | Should -BeTrue
    }

    It "returns a truthy value" {
        $result = stopProcessing
        $result | Should -BeTrue
    }
}

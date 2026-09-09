Describe "Actions/Target/Local Tests" -Tag Unit, Target {

    BeforeAll {
        $script:LocalPath = (Get-FunctionPath 'Local.ps1').FullName
    }

    It "Returns a non-remote session descriptor with no CimSession/PSSession" {
        $result = & $script:LocalPath -Context @{}

        $result.IsRemote | Should -BeFalse
        $result.CimSession | Should -BeNullOrEmpty
        $result.PSSession | Should -BeNullOrEmpty
        $result.ComputerName | Should -Be 'localhost'
    }
}

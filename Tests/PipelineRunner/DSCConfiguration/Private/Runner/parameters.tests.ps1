
Describe "parameters Function Tests" -Tag Unit, Runner, Configuration {

    BeforeAll {

        # Load the functions to test
        $preParseFilePath = (Get-FunctionPath 'parameters.ps1').FullName

        . $preParseFilePath

        $parameters = @{
            Key1 = "Value1"
            Key2 = "Value2"
            Key3 = "Value3"
        }

    }
    
    It "should return 'Value1' for input 'Key1'" {
        $result = parameters -Name "Key1"
        $result | Should -Be "Value1"
    }

    It "should return 'Value2' for input 'Key2'" {
        $result = parameters -Name "Key2"
        $result | Should -Be "Value2"
    }

    It "should return 'Value3' for input 'Key3'" {
        $result = parameters -Name "Key3"
        $result | Should -Be "Value3"
    }

    It "should throw for a non-existent key, naming the parameter" {
        # Returning $null silently meant the missing value landed in a resource property and
        # the run applied the wrong configuration instead of reporting the mistake (#5).
        { parameters -Name "NonExistentKey" } | Should -Throw "*Parameter 'NonExistentKey' not found*"
    }

    It "should return an empty string for a parameter defined as one" {
        $parameters['EmptyKey'] = ''

        parameters -Name "EmptyKey" | Should -Be ''
    }
}

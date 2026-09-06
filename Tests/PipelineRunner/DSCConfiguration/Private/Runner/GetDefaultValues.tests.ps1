
Describe "GetDefaultValues Function Tests" -Tag Unit, Runner, Configuration {

    BeforeAll {

        # Load the functions to test
        $preParseFilePath = (Get-FunctionPath 'GetDefaultValues.ps1').FullName

        . $preParseFilePath

    }

    It "should return an empty hashtable when given an empty source" {
        $source = @{}
        $result = GetDefaultValues -Source $source
        $result.Count | Should -Be 0
    }

    It "should extract default values from the source hashtable" {
        $source = @{
            Key1 = @{ defaultValue = "Value1" }
            Key2 = @{ defaultValue = "Value2" }
            Key3 = @{ defaultValue = "Value3" }
        }

        $result = GetDefaultValues -Source $source

        $result.Key1 | Should -Be "Value1"
        $result.Key2 | Should -Be "Value2"
        $result.Key3 | Should -Be "Value3"

    }

    # A declaration without a defaultValue must be omitted, not added with a $null value.
    # Adding it makes Resolve-PipelineParameter's presence check succeed, so a <params=Name>
    # token resolves to $null instead of throwing - the silent wrong value the throw exists
    # to prevent.
    It "should omit a parameter that declares no defaultValue, keeping the ones that do" {
        $source = @{
            Key1 = @{ otherProperty = "Other1" }
            Key2 = @{ defaultValue = "Value2" }
        }

        $result = GetDefaultValues -Source $source -WarningAction SilentlyContinue

        $result.ContainsKey('Key1') | Should -BeFalse
        $result.ContainsKey('Key2') | Should -BeTrue
        $result.Key2 | Should -Be "Value2"
    }

    It "should warn when a parameter declares no defaultValue" {
        $source = @{
            Key1 = @{ anotherProperty = "SomeValue" }
        }

        $warnings = @()
        $result = GetDefaultValues -Source $source -WarningVariable warnings -WarningAction SilentlyContinue

        $result.Count | Should -Be 0
        $warnings.Count | Should -Be 1
        $warnings[0].Message | Should -BeLike "*Key1*defaultValue*"
    }

    # An empty string and an explicit null are both *declared* defaults: the key is present,
    # so the parameter resolves rather than failing as undeclared.
    It "should keep a parameter whose defaultValue is an empty string" {
        $source = @{ Key1 = @{ defaultValue = '' } }

        $result = GetDefaultValues -Source $source

        $result.ContainsKey('Key1') | Should -BeTrue
        $result.Key1 | Should -Be ''
    }

    It "should keep a parameter whose defaultValue is explicitly null" {
        $source = @{ Key1 = @{ defaultValue = $null } }

        $result = GetDefaultValues -Source $source

        $result.ContainsKey('Key1') | Should -BeTrue
        $result.Key1 | Should -Be $null
    }

    # A JSON configuration is normalized to an ordered dictionary rather than a hashtable.
    It "should read a declaration held in an ordered dictionary" {
        $declaration = [ordered]@{ defaultValue = 'Value1' }
        $source = @{ Key1 = $declaration }

        $result = GetDefaultValues -Source $source

        $result.Key1 | Should -Be 'Value1'
    }

    # A malformed declaration (a bare scalar rather than a mapping) has no defaultValue key
    # and must not resolve to $null either.
    It "should omit a declaration that is not a dictionary" {
        $source = @{ Key1 = 'NotADeclaration' }

        $result = GetDefaultValues -Source $source -WarningAction SilentlyContinue

        $result.ContainsKey('Key1') | Should -BeFalse
    }

    It "should work with nested hashtables" {
        $source = @{
            Key1 = @{ defaultValue = @{ NestedKey = "NestedValue" } }
        }

        $result = GetDefaultValues -Source $source
        $result.Key1.NestedKey | Should -Be "NestedValue"

    }
}    
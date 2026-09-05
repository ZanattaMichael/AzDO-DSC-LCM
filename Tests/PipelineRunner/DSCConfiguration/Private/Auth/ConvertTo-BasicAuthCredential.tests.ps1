Describe 'ConvertTo-BasicAuthCredential Function Tests' {

    BeforeAll {
        . (Get-FunctionPath 'ConvertTo-BasicAuthCredential.ps1').FullName

        function ConvertFrom-Base64 {
            param([string]$Value)
            [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Value))
        }
    }

    Context 'When given a raw token' {

        It 'Should base64-encode it as an x-access-token credential' {
            $result = ConvertTo-BasicAuthCredential -Token 'abc123'

            ConvertFrom-Base64 $result | Should -Be 'x-access-token:abc123'
        }

        It 'Should produce a credential containing a colon separator' {
            $result = ConvertTo-BasicAuthCredential -Token 'p9zqk4ltvxn2mwc7hrjb5df8'

            (ConvertFrom-Base64 $result) | Should -Match ':'
        }

        It 'Should handle a token whose length happens to be a multiple of four' {
            # A raw token can look base64-shaped by accident; the decode check must still
            # classify it as a raw token because it does not decode to printable text
            # containing a colon.
            $result = ConvertTo-BasicAuthCredential -Token 'abcd'

            ConvertFrom-Base64 $result | Should -Be 'x-access-token:abcd'
        }
    }

    Context 'When given an already-encoded credential' {

        It 'Should return it unchanged' {
            $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('username:password'))

            ConvertTo-BasicAuthCredential -Token $encoded | Should -Be $encoded
        }

        It 'Should return an empty-user credential unchanged' {
            $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(':a-personal-access-token'))

            ConvertTo-BasicAuthCredential -Token $encoded | Should -Be $encoded
        }
    }

    Context 'When given an empty token' {

        It 'Should return it unchanged' {
            ConvertTo-BasicAuthCredential -Token '' | Should -Be ''
        }
    }

    Context 'Test-BasicAuthCredential' {

        It 'Should return false for a raw token' {
            Test-BasicAuthCredential -Value 'abc123' | Should -BeFalse
        }

        It 'Should return false for base64 that decodes without a colon' {
            $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('nocolonhere'))

            Test-BasicAuthCredential -Value $encoded | Should -BeFalse
        }

        It 'Should return true for a well-formed credential' {
            $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('u:p'))

            Test-BasicAuthCredential -Value $encoded | Should -BeTrue
        }

        It 'Should return false for an empty value' {
            Test-BasicAuthCredential -Value '' | Should -BeFalse
        }
    }
}

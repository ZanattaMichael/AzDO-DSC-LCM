Describe 'Assert-SecureGitUrl Function Tests' {

    BeforeAll {
        . (Get-FunctionPath 'Assert-SecureGitUrl.ps1').FullName
    }

    Context 'Accepted transports' {

        It 'Should accept <Url>' -TestCases @(
            @{ Url = 'https://github.com/example/repo.git' }
            @{ Url = 'https://dev.azure.com/org/project/_git/repo' }
            @{ Url = 'ssh://git@github.com/example/repo.git' }
            @{ Url = 'git@github.com:example/repo.git' }
            @{ Url = 'user.name@host.example.com:path/to/repo.git' }
        ) {
            { Assert-SecureGitUrl -Url $Url } | Should -Not -Throw
        }

        It 'Should tolerate surrounding whitespace' {
            { Assert-SecureGitUrl -Url '  https://github.com/example/repo.git  ' } | Should -Not -Throw
        }
    }

    Context 'Rejected transports' {

        It 'Should reject <Url>' -TestCases @(
            @{ Url = 'http://github.com/example/repo.git' }
            @{ Url = 'git://github.com/example/repo.git' }
            @{ Url = 'ftp://example.com/repo.git' }
            @{ Url = 'file:///etc/passwd' }
        ) {
            { Assert-SecureGitUrl -Url $Url } | Should -Throw -ExpectedMessage '*not permitted*'
        }

        It 'Should name the offending scheme in the error' {
            { Assert-SecureGitUrl -Url 'http://github.com/example/repo.git' } |
                Should -Throw -ExpectedMessage "*'http' scheme*"
        }

        It 'Should reject a malformed URL' {
            { Assert-SecureGitUrl -Url 'not-a-url' } | Should -Throw -ExpectedMessage '*invalid*'
        }

        It 'Should reject an empty URL' {
            { Assert-SecureGitUrl -Url '' } | Should -Throw -ExpectedMessage '*No repository URL*'
        }
    }
}

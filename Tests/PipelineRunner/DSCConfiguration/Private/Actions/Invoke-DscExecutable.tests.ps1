Describe "Invoke-DscExecutable Function Tests" -Tag Unit, Actions, Engine {

    BeforeAll {
        . (Get-FunctionPath 'Invoke-DscExecutable.ps1').FullName
    }

    Context "Local execution (default, today's behavior)" {

        It "Runs the executable locally and returns its exit code and output" {
            # 'dsc' will not exist on the test runner; use a real, always-present executable
            # so the local (non-remote) code path is exercised end to end.
            $result = Invoke-DscExecutable -Arguments @('--version') -Executable (Get-Process -Id $PID).Path

            $result.ExitCode | Should -BeOfType [int]
            $result.Output | Should -Not -BeNullOrEmpty
        }

        It "Does not call Invoke-Command when -Session is not supplied" {
            Mock -CommandName Invoke-Command
            $null = Invoke-DscExecutable -Arguments @('--version') -Executable (Get-Process -Id $PID).Path
            Assert-MockCalled -CommandName Invoke-Command -Exactly 0 -Scope It
        }
    }

    Context "Remote-target execution (#57 §4)" {

        It "Invokes the executable through Invoke-Command when -Session is supplied" {
            Mock -CommandName Invoke-Command -MockWith {
                param($Session, $ScriptBlock, $ArgumentList)
                return @{ ExitCode = 0; Output = 'remote-output' }
            }

            $fakeSession = [pscustomobject]@{ Marker = 'fake-remote-session' }
            $result = Invoke-DscExecutable -Arguments @('resource', 'test') -Session $fakeSession

            $result.ExitCode | Should -Be 0
            $result.Output | Should -Be 'remote-output'
            Assert-MockCalled -CommandName Invoke-Command -Exactly 1 -Scope It -ParameterFilter {
                $Session -eq $fakeSession
            }
        }

        It "Passes the executable and arguments through to the remote scriptblock" {
            $Global:InvokeDscExecutableCapturedArgList = $null
            Mock -CommandName Invoke-Command -MockWith {
                param($Session, $ScriptBlock, $ArgumentList)
                $Global:InvokeDscExecutableCapturedArgList = $ArgumentList
                return @{ ExitCode = 0; Output = 'ok' }
            }

            $fakeSession = [pscustomobject]@{ Marker = 'fake-remote-session' }
            $null = Invoke-DscExecutable -Arguments @('resource', 'test', '--input', '{}') -Executable 'dsc' -Session $fakeSession

            $Global:InvokeDscExecutableCapturedArgList[0] | Should -Be 'dsc'
            $Global:InvokeDscExecutableCapturedArgList[1] | Should -Contain 'resource'
            Remove-Variable -Name InvokeDscExecutableCapturedArgList -Scope Global -ErrorAction SilentlyContinue
        }
    }
}

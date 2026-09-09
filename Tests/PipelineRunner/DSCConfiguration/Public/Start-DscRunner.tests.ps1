Describe "Start-DscRunner Function Tests" -Tag Unit {

    BeforeAll {

        # Load the functions to test
        $preParseFilePath = (Get-FunctionPath 'Start-DscRunner.ps1').FullName
        $getDefaultValuesPath = (Get-FunctionPath 'GetDefaultValues.ps1').FullName
        $SetVariablesPath = (Get-FunctionPath 'SetVariables.ps1').FullName
        $InvokeCustomTaskPath = (Get-FunctionPath 'Invoke-CustomTask.ps1').FullName
        $InvokePreParseRulesPath = (Get-FunctionPath 'Invoke-PreParseRules.ps1').FullName
        $InvokeFormatTasksPath = (Get-FunctionPath 'Invoke-FormatTasks.ps1').FullName
        $InvokeExpandHashTablePath = (Get-FunctionPath 'Expand-HashTable.ps1').FullName
        # Resource properties now resolve <params=Name> tokens before string interpolation,
        # so the parameter-expansion chain is loaded alongside Expand-HashTable (#5).
        $InvokeExpandParametersPath = (Get-FunctionPath 'Expand-Parameters.ps1').FullName
        $InvokeExpandParameterInArrayPath = (Get-FunctionPath 'Expand-ParameterInArray.ps1').FullName
        $ResolvePipelineParameterPath = (Get-FunctionPath 'Resolve-PipelineParameter.ps1').FullName
        $StopTaskProcessingPath = (Get-FunctionPath 'Stop-TaskProcessing.ps1').FullName
        # #35: conditions are validated as side-effect-free predicates before they run.
        $AssertSafeConditionPath = (Get-FunctionPath 'Assert-SafeConditionExpression.ps1').FullName
        # #57 §2: both Assert-SafeConditionExpression and Start-DscRunner itself normalize
        # result()/stopProcessing() syntax through this helper before parsing/executing a
        # condition; load it before either so the real call inside them resolves.
        $ConvertToNormalizedConditionExpressionPath = (Get-FunctionPath 'ConvertTo-NormalizedConditionExpression.ps1').FullName
        # #57: the condition allow-list permits these function-language accessors, so a
        # condition that calls them needs the real implementations loaded to execute.
        $ParametersFnPath = (Get-FunctionPath 'parameters.ps1').FullName
        $VariablesFnPath  = (Get-FunctionPath 'variables.ps1').FullName
        $ReferenceFnPath  = (Get-FunctionPath 'reference.ps1').FullName
        $EqualsFnPath     = (Get-FunctionPath 'equals.ps1').FullName
        $NotFnPath        = (Get-FunctionPath 'not.ps1').FullName
        # Engine seam: Start-DscRunner now routes Test/Set/Get through Invoke-EngineAction,
        # which dispatches to Actions/Engine/DscV2.ps1 (the default engine that wraps
        # Invoke-DscResource). Load the loader, the wrapper, the normalizer and the
        # DscMethodResult class so the real engine path runs against the mocks below.
        . (Get-FunctionPath 'DscMethodResult.ps1').FullName
        . (Get-FunctionPath 'Invoke-Action.ps1').FullName
        . (Get-FunctionPath 'ConvertTo-DscMethodResult.ps1').FullName
        . (Get-FunctionPath 'Invoke-EngineAction.ps1').FullName

        . $ConvertToNormalizedConditionExpressionPath
        . $preParseFilePath
        . $getDefaultValuesPath
        . $SetVariablesPath
        . $InvokeCustomTaskPath
        . $InvokePreParseRulesPath
        . $InvokeFormatTasksPath
        . $InvokeExpandHashTablePath
        . $InvokeExpandParametersPath
        . $InvokeExpandParameterInArrayPath
        . $ResolvePipelineParameterPath
        . $StopTaskProcessingPath
        . $AssertSafeConditionPath
        . $ParametersFnPath
        . $VariablesFnPath
        . $ReferenceFnPath
        . $EqualsFnPath
        . $NotFnPath

        # Start-DscRunner normalizes JSON-loaded configs through this helper so a
        # case-sensitive OrderedHashtable (ConvertFrom-Json -AsHashtable on PS 7.3+) does
        # not break the runner's mixed-case member access; load it for the JSON-path tests.
        . (Get-FunctionPath 'ConvertTo-CaseInsensitiveHashtable.ps1').FullName

        $references = @{}
        $variables = @{}
        $parameters = @{}

        # Invoke-Action resolves Actions/<Hook>/<Name>.ps1 from the module base; in the
        # test there is no imported module, so point it at the repository root where the
        # real Actions/ tree lives.
        Mock -CommandName Get-Module -MockWith { return @{ moduleBase = $Global:RepositoryRoot } }

        # #30: the runner must not use Write-Host at all; all human-readable output goes
        # through Write-Information (tag 'Dsc.PipelineRunner'). Mock both so we can assert
        # Write-Host never fires and the information stream carries the expected tag.
        Mock -CommandName Write-Host
        Mock -CommandName Write-Information

        Mock -CommandName ConvertFrom-Yaml -MockWith {
            param ($content)
            return @{
                parameters = @{
                    param1 = @{ defaultValue = "value1" }
                }
                variables = @{
                    var1 = "value1"
                }
                resources = @(
                    @{
                        type = "Module/Resource"
                        name = "Resource1"
                        properties = @{
                            prop1 = "value1"
                        }
                    }
                )
            }
        }

        Mock -CommandName ConvertFrom-Json -MockWith {
            param ($content)
            return @{
                parameters = @{
                    param1 = @{ defaultValue = "value1" }
                }
                variables = @{
                    var1 = "value1"
                }
                resources = @(
                    @{
                        type = "Module/Resource"
                        name = "Resource1"
                        properties = @{
                            prop1 = "value1"
                        }
                    }
                )
            }
        }

        Mock -CommandName Invoke-DscResource -MockWith {
            param ($Name, $ModuleName, $Method, $Property)
            return @{
                InDesiredState = $Method -eq "Test"
                Message = "Mocked message"
            }
        }

        Mock -CommandName Invoke-CustomTask -MockWith {
            param(
                [Parameter(Mandatory=$true)]
                [Object[]]$Tasks,
                [Parameter(Mandatory=$true)]
                [String]$CustomTaskName
            )

            return $pipeline.resources

        }

        Mock -CommandName Invoke-PreParseRules -MockWith {
            param(
                [Parameter(Mandatory=$true)]
                [Object[]]$Tasks,
                [hashtable]$Settings
            )

        }

        Mock -CommandName Invoke-FormatTasks -MockWith {
            param(
                [Parameter(Mandatory=$true)]
                [Object[]]$Tasks
            )

            return $Tasks
        }

        Mock -CommandName Expand-HashTable -MockWith {
            param(
                [Parameter(Mandatory=$true)]
                [Hashtable]$InputHashTable
            )

            return $InputHashTable
        }

        Mock -CommandName Export-Csv
        Mock -CommandName Set-Content

        # Start-DscRunner now rejects a path that does not exist (#15), so the suite works
        # against real (empty) files on the test drive and lets the mocked Get-Content
        # supply the content. The names keep the original .json/.yaml extensions so the
        # loader branch under test is unchanged.
        $script:testJsonPath = Join-Path $TestDrive 'test.json'
        $script:testYamlPath = Join-Path $TestDrive 'test.yaml'
        $script:testTextPath = Join-Path $TestDrive 'test.txt'
        foreach ($fixture in $script:testJsonPath, $script:testYamlPath, $script:testTextPath) {
            Set-Content -LiteralPath $fixture -Value 'placeholder' -ErrorAction SilentlyContinue
            if (-not (Test-Path -LiteralPath $fixture)) {
                # Set-Content is mocked above; fall back to the .NET API for the fixtures.
                [System.IO.File]::WriteAllText($fixture, 'placeholder')
            }
        }

    }

    BeforeEach {
        # Reset the script-scoped variable before each test
        $script:StopTaskProcessing = $false
    }

    Context "when processing configuration files" {

        It "should correctly load YAML configuration" {
            Mock -CommandName Get-Content -MockWith { "---\nparameters: {}\nvariables: {}\nresources: []" }
            Start-DscRunner -FilePath $script:testYamlPath
            Assert-MockCalled -CommandName ConvertFrom-Yaml -Exactly 1
        }

        It "should correctly load JSON configuration" {
            Mock -CommandName Get-Content -MockWith { '{"parameters": {}, "variables": {}, "resources": []}' }
            Start-DscRunner -FilePath $script:testJsonPath
            Assert-MockCalled -CommandName ConvertFrom-Json -Exactly 1
        }

        It "should throw error for unsupported file extension" {
            { Start-DscRunner -FilePath $script:testTextPath } | Should -Throw
        }
    }

    Context "output stream hygiene (#30)" {

        BeforeAll {
            Mock -CommandName Get-Content -MockWith { '{"parameters": {}, "variables": {}, "resources": []}' }
        }

        It "should never call Write-Host" {
            Start-DscRunner -FilePath $script:testJsonPath | Out-Null
            Assert-MockCalled -CommandName Write-Host -Exactly 0
        }

        It "should emit informational output tagged 'Dsc.PipelineRunner'" {
            Start-DscRunner -FilePath $script:testJsonPath | Out-Null
            Assert-MockCalled -CommandName Write-Information -ParameterFilter { $Tags -contains 'Dsc.PipelineRunner' } -Times 1
        }
    }

    Context "structured run result (#19, #29)" {

        It "should return a structured result object describing the run" {
            Mock -CommandName Get-Content -MockWith { '{"parameters": {}, "variables": {}, "resources": []}' }

            $result = Start-DscRunner -FilePath $script:testJsonPath

            $result | Should -Not -BeNullOrEmpty
            $result.Status | Should -Be 'Completed'
            $result.ConfigurationFile | Should -Be $script:testJsonPath
            $result.PSObject.Properties.Name | Should -Contain 'PassCount'
            $result.PSObject.Properties.Name | Should -Contain 'FailCount'
            $result.PSObject.Properties.Name | Should -Contain 'SkipCount'
            $result.PSObject.Properties.Name | Should -Contain 'FailedResources'
        }

        It "should report a single passing resource in Test mode" {
            Mock -CommandName Get-Content -MockWith { '{"parameters": {}, "variables": {}, "resources": []}' }
            Mock -CommandName Invoke-DscResource -MockWith {
                [PSCustomObject]@{ InDesiredState = $true; Message = "Tested successfully." }
            }

            $result = Start-DscRunner -FilePath $script:testJsonPath

            $result.PassCount | Should -Be 1
            $result.FailCount | Should -Be 0
            $result.TotalResources | Should -Be 1
        }

        It "should mark a resource FAIL and record it when drift is detected in Test mode" {
            Mock -CommandName Get-Content -MockWith { '{"parameters": {}, "variables": {}, "resources": []}' }
            Mock -CommandName Invoke-DscResource -MockWith {
                [PSCustomObject]@{ InDesiredState = $false; Message = "Not in desired state." }
            }

            $result = Start-DscRunner -FilePath $script:testJsonPath

            $result.FailCount | Should -Be 1
            $result.FailedResources.Count | Should -Be 1
            $result.FailedResources[0].InstanceName | Should -Be 'Resource1'
        }
    }

    Context "when operating in different modes" {

        BeforeAll {
            Mock -CommandName Get-Content -MockWith { '{"parameters": {}, "variables": {}, "resources": []}' }
        }

        It "should operate in 'Test' mode by default" {
            Mock -CommandName Invoke-DscResource -MockWith {
                [PSCustomObject]@{ InDesiredState = $true; Message = "Tested successfully." }
            }

            Start-DscRunner -FilePath $script:testJsonPath | Out-Null

            Assert-MockCalled -CommandName Invoke-DscResource -ParameterFilter { $Method -eq "Test" } -Exactly 1
        }

        It "should apply changes in 'Set' mode" {
            Mock -CommandName Invoke-DscResource -MockWith {
                [PSCustomObject]@{ InDesiredState = $false; Message = "Not in desired state." }
            }

            Start-DscRunner -FilePath $script:testJsonPath -Mode "Set" | Out-Null

            Assert-MockCalled -CommandName Invoke-DscResource -ParameterFilter { $Method -eq "Test" } -Exactly 1
            Assert-MockCalled -CommandName Invoke-DscResource -ParameterFilter { $Method -eq "Set" } -Exactly 1
        }

        It "should skip tasks when StopTaskProcessing is true" {

            Mock -CommandName ConvertFrom-Json -MockWith {
                param ($content)
                return @{
                    parameters = @{
                        param1 = @{ defaultValue = "value1" }
                    }
                    variables = @{
                        var1 = "value1"
                    }
                    resources = @(
                        @{
                            type = "Module/Resource"
                            name = "Resource1"
                            postExecutionScript = 'Stop-TaskProcessing'
                            properties = @{
                                prop1 = "value1"
                            }
                        }
                        @{
                            type = "Module/Resource"
                            name = "Resource2"
                            properties = @{
                                prop1 = "value1"
                            }
                        }
                    )
                }
            }

            $result = Start-DscRunner -FilePath $script:testJsonPath

            Assert-MockCalled -CommandName Invoke-DscResource -ParameterFilter { $Method -eq "Test" } -Exactly 1
            Assert-MockCalled -CommandName Invoke-DscResource -ParameterFilter { $Method -eq "Get" } -Exactly 1
            $result.SkipCount | Should -Be 1
            $result.Status | Should -Be 'StoppedByRequest'

        }

        It "should skip resources if the condition is met" {

            Mock -CommandName ConvertFrom-Json -MockWith {
                param ($content)
                return @{
                    parameters = @{
                        param1 = @{ defaultValue = "value1" }
                    }
                    variables = @{
                        var1 = "value1"
                    }
                    resources = @(
                        @{
                            type = "Module/Resource"
                            name = "Resource1"
                            properties = @{
                                prop1 = "value1"
                            }
                            condition = '1 -ne 1'
                        }
                        @{
                            type = "Module/Resource"
                            name = "Resource2"
                            properties = @{
                                prop2 = "value2"
                            }
                            condition = '1 -eq 1'
                        }
                    )
                }
            }

            Start-DscRunner -FilePath $script:testJsonPath | Out-Null

            Assert-MockCalled -CommandName Invoke-DscResource -ParameterFilter { $Property.prop1 -eq "value1" } -Exactly 0
            Assert-MockCalled -CommandName Invoke-DscResource -ParameterFilter { $Property.prop2 -eq "value2" } -Exactly 2

        }

    }

    Context "pipeline parameter defaults" {

        # Regression guard: a prior refactor bound GetDefaultValues to an unused local and fed
        # $null to $parameters, so pipeline parameter defaults never took effect. The default
        # values must be resolved from each parameter's 'defaultValue' and loaded into the
        # runner's $parameters table so property/variable expansion and conditions can read them.
        It "loads each parameter's defaultValue into the runner's parameters table" {

            Mock -CommandName Get-Content -MockWith { '{"parameters": {}, "variables": {}, "resources": []}' }
            Mock -CommandName ConvertFrom-Json -MockWith {
                param ($content)
                return @{
                    parameters = @{
                        environmentName = @{ defaultValue = 'Production' }
                        retryCount      = @{ defaultValue = 3 }
                    }
                    variables  = @{}
                    # A single resource keeps the mocked task pipeline non-empty (its
                    # mandatory [Object[]] parameters reject an empty array); the assertion
                    # below is about the parameter table, populated before the resource loop.
                    resources  = @(
                        @{
                            type = "Module/Resource"
                            name = "Resource1"
                            properties = @{ prop1 = "value1" }
                        }
                    )
                }
            }

            Start-DscRunner -FilePath $script:testJsonPath | Out-Null

            $parameters['environmentName'] | Should -Be 'Production'
            $parameters['retryCount'] | Should -Be 3
        }
    }

    Context "configuration script sandboxing (#35)" {

        BeforeAll {
            Mock -CommandName Get-Content -MockWith { '{"parameters": {}, "variables": {}, "resources": []}' }
        }

        It "rejects a condition that invokes a command, failing only that resource" {

            Mock -CommandName ConvertFrom-Json -MockWith {
                @{
                    parameters = @{}
                    variables  = @{}
                    resources  = @(
                        @{
                            type      = "Module/Resource"
                            name      = "Resource1"
                            properties = @{ prop1 = "value1" }
                            # A command invocation is not a predicate; it must be rejected (#35).
                            condition = 'Stop-TaskProcessing'
                        }
                        @{
                            type      = "Module/Resource"
                            name      = "Resource2"
                            properties = @{ prop2 = "value2" }
                        }
                    )
                }
            }

            $result = Start-DscRunner -FilePath $script:testJsonPath

            # A condition that fails Assert-SafeConditionExpression's checks is this resource's
            # failure, not the whole run's: it is caught by the same per-resource try/catch used
            # elsewhere in the loop, so the run completes and later resources still execute.
            $result.Status | Should -Be 'Completed'
            $result.FailCount | Should -Be 1
            ($result.Results | Where-Object { $_.InstanceName -eq 'Resource1' }).Status | Should -Be 'FAIL'
            ($result.Results | Where-Object { $_.InstanceName -eq 'Resource1' }).ErrorMessage | Should -Match 'side-effect-free predicate'
            # The offending resource is never evaluated...
            Assert-MockCalled -CommandName Invoke-DscResource -ParameterFilter { $Method -eq 'Test' -and $Property.prop1 -eq 'value1' } -Exactly 0 -Scope It
            # ...but the run continues with the remaining resources.
            Assert-MockCalled -CommandName Invoke-DscResource -ParameterFilter { $Method -eq 'Test' -and $Property.prop2 -eq 'value2' } -Exactly 1 -Scope It
        }

        It "allows the function-language accessors inside a condition and permits the resource to run" {

            Mock -CommandName ConvertFrom-Json -MockWith {
                @{
                    parameters = @{
                        Environment = @{ defaultValue = 'Prod' }
                    }
                    variables  = @{}
                    resources  = @(
                        @{
                            type      = "Module/Resource"
                            name      = "Resource1"
                            properties = @{ prop1 = "value1" }
                            condition = "(parameters('Environment')) -eq 'Prod'"
                        }
                    )
                }
            }

            Start-DscRunner -FilePath $script:testJsonPath | Out-Null

            Assert-MockCalled -CommandName Invoke-DscResource -ParameterFilter { $Method -eq 'Test' -and $Property.prop1 -eq 'value1' } -Exactly 1 -Scope It
        }

        It "fails only the resource whose condition calls parameters() with an undefined name" {

            Mock -CommandName ConvertFrom-Json -MockWith {
                @{
                    parameters = @{}
                    variables  = @{}
                    resources  = @(
                        @{
                            type      = "Module/Resource"
                            name      = "Resource1"
                            properties = @{ prop1 = "value1" }
                            # parameters() throws on a missing key; the run must survive it (#35 / #57).
                            condition = "parameters('Missing')"
                        }
                        @{
                            type      = "Module/Resource"
                            name      = "Resource2"
                            properties = @{ prop2 = "value2" }
                        }
                    )
                }
            }

            $result = Start-DscRunner -FilePath $script:testJsonPath

            $result.Status | Should -Be 'Completed'
            ($result.Results | Where-Object { $_.InstanceName -eq 'Resource1' }).Status | Should -Be 'FAIL'
            Assert-MockCalled -CommandName Invoke-DscResource -ParameterFilter { $Method -eq 'Test' -and $Property.prop2 -eq 'value2' } -Exactly 1 -Scope It
        }

        It "does not let a postExecutionScript assignment change the mode of later resources" {

            # Every resource reports drift; in Test mode that means no Set is ever invoked.
            Mock -CommandName Invoke-DscResource -MockWith {
                param ($Name, $ModuleName, $Method, $Property)
                @{ InDesiredState = $false; Message = "drift" }
            }

            Mock -CommandName ConvertFrom-Json -MockWith {
                @{
                    parameters = @{}
                    variables  = @{}
                    resources  = @(
                        @{
                            type      = "Module/Resource"
                            name      = "Resource1"
                            properties = @{ prop1 = "value1" }
                            # If this leaked into Start-DscRunner's scope (as dot-sourcing would
                            # allow), Resource2 would run in Set mode and a Set would fire.
                            postExecutionScript = '$Mode = ''Set'''
                        }
                        @{
                            type      = "Module/Resource"
                            name      = "Resource2"
                            properties = @{ prop2 = "value2" }
                        }
                    )
                }
            }

            Start-DscRunner -FilePath $script:testJsonPath | Out-Null

            # The call operator keeps $Mode local to the script block, so the run stays in Test
            # mode throughout and no Set is invoked.
            Assert-MockCalled -CommandName Invoke-DscResource -ParameterFilter { $Method -eq 'Set' } -Exactly 0 -Scope It
        }
    }

    Context "when handling report paths" {

        BeforeAll {
            Mock -CommandName Get-Content -MockWith { '{"parameters": {}, "variables": {}, "resources": []}' }
        }

        It "should generate a CSV and a JSON report if ReportPath is specified" {
            Start-DscRunner -FilePath $script:testJsonPath -ReportPath "C:\Reports" | Out-Null

            Assert-MockCalled -CommandName Export-Csv -Exactly 1
            Assert-MockCalled -CommandName Set-Content -Exactly 1
        }

        It "should not generate a report if ReportPath is not specified" {
            Start-DscRunner -FilePath $script:testJsonPath | Out-Null

            Assert-MockCalled -CommandName Export-Csv -Exactly 0
            Assert-MockCalled -CommandName Set-Content -Exactly 0
        }
    }

    Context "parameter token expansion (#5)" {

        BeforeEach {
            # A configuration that declares a parameter and references it from a resource
            # property with the <params=Name> token. Expand-Parameters had no production
            # caller at all, so the token used to reach the engine verbatim.
            Mock -CommandName Get-Content -MockWith { return '{}' }
            Mock -CommandName ConvertFrom-Json -MockWith {
                return @{
                    parameters = @{
                        ServiceName = @{ defaultValue = 'Spooler' }
                        RetryCount  = @{ defaultValue = 3 }
                    }
                    variables = @{}
                    resources = @(
                        @{
                            type = "Module/Resource"
                            name = "Resource1"
                            properties = @{
                                Name    = '<params=ServiceName>'
                                Retries = '<params=RetryCount>'
                                Literal = 'unchanged'
                            }
                        }
                    )
                }
            }

            Mock -CommandName Invoke-DscResource -MockWith {
                param ($Name, $ModuleName, $Method, $Property)
                return @{ InDesiredState = $true; Message = "Mocked message" }
            }
        }

        It "should resolve a params token before the property reaches the engine" {
            Start-DscRunner -FilePath $script:testJsonPath | Out-Null

            Should -Invoke -CommandName Invoke-DscResource -Scope It -ParameterFilter {
                $Method -eq 'Test' -and $Property.Name -eq 'Spooler'
            }
        }

        It "should preserve the parameter's type rather than stringifying it" {
            Start-DscRunner -FilePath $script:testJsonPath | Out-Null

            Should -Invoke -CommandName Invoke-DscResource -Scope It -ParameterFilter {
                $Method -eq 'Test' -and $Property.Retries -is [int] -and $Property.Retries -eq 3
            }
        }

        It "should leave a property with no token untouched" {
            Start-DscRunner -FilePath $script:testJsonPath | Out-Null

            Should -Invoke -CommandName Invoke-DscResource -Scope It -ParameterFilter {
                $Method -eq 'Test' -and $Property.Literal -eq 'unchanged'
            }
        }

        It "should throw when a property references an undefined parameter" {
            Mock -CommandName ConvertFrom-Json -MockWith {
                return @{
                    parameters = @{}
                    variables = @{}
                    resources = @(
                        @{
                            type = "Module/Resource"
                            name = "Resource1"
                            properties = @{ Name = '<params=NotDeclared>' }
                        }
                    )
                }
            }

            $result = Start-DscRunner -FilePath $script:testJsonPath -ErrorAction SilentlyContinue

            # A single unresolvable property is that resource's failure, not the run's: the
            # remaining tasks still run and the record says which resource failed.
            $result.FailCount | Should -Be 1
            $result.Status | Should -Be 'Completed'
            ($result.Results | Where-Object { $_.Status -eq 'FAIL' }).ErrorMessage |
                Should -Match "'NotDeclared'"
        }
    }

    Context "configuration file validation (#15)" {

        It "should throw a FileNotFoundException when the configuration file does not exist" {
            # A missing file used to be swallowed: Get-Content raised a non-terminating error,
            # $pipeline stayed $null and the run reported 'Completed' with zero resources, so a
            # mistyped path was indistinguishable from a successful no-op run.
            $missing = Join-Path $TestDrive 'no-such-configuration.json'

            { Start-DscRunner -FilePath $missing } |
                Should -Throw -ExpectedMessage "*Configuration file not found*"
        }

        It "should not produce a result record for a missing configuration file" {
            $missing = Join-Path $TestDrive 'no-such-configuration.json'
            $result = $null

            try { $result = Start-DscRunner -FilePath $missing } catch { }

            $result | Should -BeNullOrEmpty
        }

        It "should throw for an unsupported file extension even when the file exists" {
            { Start-DscRunner -FilePath $script:testTextPath } |
                Should -Throw -ExpectedMessage "*Unsupported configuration file extension*"
        }

        It "should throw when the configuration file parses to nothing" {
            Mock -CommandName Get-Content -MockWith { return '' }
            Mock -CommandName ConvertFrom-Json -MockWith { return $null }

            { Start-DscRunner -FilePath $script:testJsonPath } |
                Should -Throw -ExpectedMessage "*empty or contains no readable content*"
        }

        It "should throw when the configuration file parses to an empty document" {
            Mock -CommandName Get-Content -MockWith { return '{}' }
            Mock -CommandName ConvertFrom-Json -MockWith { return @{} }

            { Start-DscRunner -FilePath $script:testJsonPath } |
                Should -Throw -ExpectedMessage "*parsed to an empty document*"
        }

        It "should not produce a result record for an empty configuration file" {
            Mock -CommandName Get-Content -MockWith { return '' }
            Mock -CommandName ConvertFrom-Json -MockWith { return $null }
            $result = $null

            try { $result = Start-DscRunner -FilePath $script:testJsonPath } catch { }

            $result | Should -BeNullOrEmpty
        }
    }

    Context "error handling and edge cases" {

        It "should handle missing FilePath parameter" {
            { Start-DscRunner -Mode "Test" } | Should -Throw
        }

        It "should handle invalid Mode parameter" {
            { Start-DscRunner -FilePath $script:testJsonPath -Mode "Invalid" } | Should -Throw
        }

        It "should print a non-terminating error when the runner fails to set a resource" {

            Mock -CommandName Write-Error -ParameterFilter { $Message -like "*Failed to apply changes with 'Set' method*" } -Verifiable
            Mock -CommandName Invoke-DscResource -ParameterFilter { $Method -eq "Set" } -Verifiable -MockWith {
                throw "mock error"
            }
            Mock -CommandName Invoke-DscResource -ParameterFilter { $Method -eq 'Test' } -MockWith {
                @{
                    InDesiredState = $false
                }
            } -Verifiable
            Mock -CommandName Get-Content -MockWith { "---\nparameters: {}\nvariables: {}\nresources: []" }

            # Assign outside a Should -Throw scriptblock: a scriptblock passed to Should runs
            # in a child scope, so a $result set inside it would not propagate here. A failed
            # 'Set' is caught internally (non-terminating), so calling directly must not throw;
            # if it did, the It would fail, which is the assertion we want.
            $result = Start-DscRunner -FilePath $script:testJsonPath -Mode "Set"
            Should -InvokeVerifiable
            $result.FailCount | Should -Be 1

        }
    }

    Context "postCondition and stopProcessing() (#57 §2)" {

        BeforeAll {
            Mock -CommandName Get-Content -MockWith { '{"parameters": {}, "variables": {}, "resources": []}' }
            . (Get-FunctionPath 'result.ps1').FullName
            . (Get-FunctionPath 'stopProcessing.ps1').FullName
        }

        It "marks the resource FAIL when postCondition returns false, even though the engine reports InDesiredState" {

            Mock -CommandName ConvertFrom-Json -MockWith {
                @{
                    parameters = @{}
                    variables  = @{}
                    resources  = @(
                        @{
                            type          = "Module/Resource"
                            name          = "Resource1"
                            properties    = @{ prop1 = "value1" }
                            postCondition = "result().InDesiredState -and `$false"
                        }
                    )
                }
            }

            $result = Start-DscRunner -FilePath $script:testJsonPath

            ($result.Results | Where-Object { $_.InstanceName -eq 'Resource1' }).Status | Should -Be 'FAIL'
        }

        It "lets postCondition read result() from the engine's Test outcome" {

            Mock -CommandName ConvertFrom-Json -MockWith {
                @{
                    parameters = @{}
                    variables  = @{}
                    resources  = @(
                        @{
                            type          = "Module/Resource"
                            name          = "Resource1"
                            properties    = @{ prop1 = "value1" }
                            postCondition = "result().InDesiredState"
                        }
                    )
                }
            }

            $result = Start-DscRunner -FilePath $script:testJsonPath

            ($result.Results | Where-Object { $_.InstanceName -eq 'Resource1' }).Status | Should -Be 'OK'
        }

        It "rejects a postCondition that calls stopProcessing() indirectly through a disallowed pattern" {
            # A postCondition is still parsed by the same AST allow-list; only 'result' and
            # 'stopProcessing' are added on top of the ordinary condition allow-list, so an
            # arbitrary other command is still rejected.
            Mock -CommandName ConvertFrom-Json -MockWith {
                @{
                    parameters = @{}
                    variables  = @{}
                    resources  = @(
                        @{
                            type          = "Module/Resource"
                            name          = "Resource1"
                            properties    = @{ prop1 = "value1" }
                            postCondition = "Get-Item C:\"
                        }
                    )
                }
            }

            $result = Start-DscRunner -FilePath $script:testJsonPath

            ($result.Results | Where-Object { $_.InstanceName -eq 'Resource1' }).Status | Should -Be 'FAIL'
        }

        It "allows postCondition to call stopProcessing() and skips the remaining resources" {

            Mock -CommandName ConvertFrom-Json -MockWith {
                @{
                    parameters = @{}
                    variables  = @{}
                    resources  = @(
                        @{
                            type          = "Module/Resource"
                            name          = "Resource1"
                            properties    = @{ prop1 = "value1" }
                            postCondition = "stopProcessing()"
                        }
                        @{
                            type       = "Module/Resource"
                            name       = "Resource2"
                            properties = @{ prop2 = "value2" }
                        }
                    )
                }
            }

            $result = Start-DscRunner -FilePath $script:testJsonPath

            $result.Status | Should -Be 'StoppedByRequest'
            ($result.Results | Where-Object { $_.InstanceName -eq 'Resource2' }).Status | Should -Be 'SKIP'
        }
    }

    Context "preExecutionScript (#57 §2)" {

        BeforeAll {
            Mock -CommandName Get-Content -MockWith { '{"parameters": {}, "variables": {}, "resources": []}' }
        }

        It "runs preExecutionScript before the resource's Test evaluation" {

            Mock -CommandName ConvertFrom-Json -MockWith {
                @{
                    parameters = @{}
                    variables  = @{ ranPreExecutionScript = $false }
                    resources  = @(
                        @{
                            type              = "Module/Resource"
                            name              = "Resource1"
                            properties        = @{ prop1 = "value1" }
                            preExecutionScript = '$variables["ranPreExecutionScript"] = $true'
                        }
                    )
                }
            }

            Mock -CommandName Invoke-DscResource -MockWith {
                param ($Name, $ModuleName, $Method, $Property)
                # By the time Test runs, preExecutionScript must already have run.
                $variables['ranPreExecutionScript'] | Should -BeTrue
                return @{ InDesiredState = $true; Message = 'Mocked message' }
            }

            Start-DscRunner -FilePath $script:testJsonPath | Out-Null

            $variables['ranPreExecutionScript'] | Should -BeTrue
        }
    }

    Context "declarative resourceCredential (#57 §7)" {

        BeforeAll {
            Mock -CommandName Get-Content -MockWith { '{"parameters": {}, "variables": {}, "resources": []}' }
            $env:DscPipelineRunnerTestUser = 'svc-account'
            $env:DscPipelineRunnerTestPass = 'super-secret'
        }

        AfterAll {
            Remove-Item Env:\DscPipelineRunnerTestUser -ErrorAction SilentlyContinue
            Remove-Item Env:\DscPipelineRunnerTestPass -ErrorAction SilentlyContinue
        }

        It "resolves resourceCredential via the Credential hook and injects it into the resource properties" {

            Mock -CommandName ConvertFrom-Json -MockWith {
                @{
                    parameters = @{}
                    variables  = @{}
                    resources  = @(
                        @{
                            type              = "Module/Resource"
                            name              = "Resource1"
                            properties        = @{ prop1 = "value1" }
                            resourceCredential = @{
                                action           = 'Environment'
                                UserNameVariable = 'DscPipelineRunnerTestUser'
                                PasswordVariable  = 'DscPipelineRunnerTestPass'
                            }
                        }
                    )
                }
            }

            Start-DscRunner -FilePath $script:testJsonPath | Out-Null

            Assert-MockCalled -CommandName Invoke-DscResource -ParameterFilter {
                $Method -eq 'Test' -and $Property.Credential -is [System.Management.Automation.PSCredential] -and $Property.Credential.UserName -eq 'svc-account'
            } -Exactly 1 -Scope It
        }
    }

    Context "reboot handling (#57 §3)" {

        BeforeAll {
            Mock -CommandName Get-Content -MockWith { '{"parameters": {}, "variables": {}, "resources": []}' }
        }

        It "fails the resource and stops the run when a local Set reports RebootRequired (default policy)" {

            Mock -CommandName ConvertFrom-Json -MockWith {
                @{
                    parameters = @{}
                    variables  = @{}
                    resources  = @(
                        @{ type = "Module/Resource"; name = "Resource1"; properties = @{ prop1 = "value1" } }
                        @{ type = "Module/Resource"; name = "Resource2"; properties = @{ prop2 = "value2" } }
                    )
                }
            }

            Mock -CommandName Invoke-DscResource -MockWith {
                param ($Name, $ModuleName, $Method, $Property)
                if ($Method -eq 'Test') { return @{ InDesiredState = $false } }
                if ($Method -eq 'Set')  { return @{ InDesiredState = $true; RebootRequired = $true } }
                return @{ InDesiredState = $true }
            }

            $result = Start-DscRunner -FilePath $script:testJsonPath -Mode 'Set'

            $result.Status | Should -Be 'StoppedByRequest'
            ($result.Results | Where-Object { $_.InstanceName -eq 'Resource1' }).Status | Should -Be 'FAIL'
            ($result.Results | Where-Object { $_.InstanceName -eq 'Resource1' }).RebootRequired | Should -BeTrue
            ($result.Results | Where-Object { $_.InstanceName -eq 'Resource2' }).Status | Should -Be 'SKIP'
        }

        It "continues without restarting when RunnerSettings.Reboot is 'Ignore'" {

            Mock -CommandName ConvertFrom-Json -MockWith {
                @{
                    parameters = @{}
                    variables  = @{}
                    resources  = @(
                        @{ type = "Module/Resource"; name = "Resource1"; properties = @{ prop1 = "value1" } }
                    )
                }
            }

            Mock -CommandName Invoke-DscResource -MockWith {
                param ($Name, $ModuleName, $Method, $Property)
                if ($Method -eq 'Test') { return @{ InDesiredState = $false } }
                if ($Method -eq 'Set')  { return @{ InDesiredState = $true; RebootRequired = $true } }
                return @{ InDesiredState = $true }
            }

            $result = Start-DscRunner -FilePath $script:testJsonPath -Mode 'Set' -RunnerSettings @{ Reboot = 'Ignore' }

            $result.Status | Should -Be 'Completed'
            ($result.Results | Where-Object { $_.InstanceName -eq 'Resource1' }).Status | Should -Be 'OK'
        }
    }

}

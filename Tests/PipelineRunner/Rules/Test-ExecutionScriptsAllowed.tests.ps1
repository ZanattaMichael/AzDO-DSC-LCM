Describe "Test-ExecutionScriptsAllowed" -Tag Unit, Runner, Rules, PreParse {

    BeforeAll {
        $preParseFilePath = (Get-FunctionPath 'Test-ExecutionScriptsAllowed.ps1').FullName
    }

    It "passes silently when no resource uses preExecutionScript/postExecutionScript" {
        $resources = @(
            [PSCustomObject]@{ type = 'Module/MyResourceType'; name = 'MyResource'; properties = @{} }
        )

        { . $preParseFilePath -PipelineResources $resources -Settings @{} } | Should -Not -Throw
    }

    It "throws naming every offending resource when AllowExecutionScripts is not set" {
        $resources = @(
            [PSCustomObject]@{ type = 'Module/A'; name = 'ResourceA'; properties = @{}; postExecutionScript = 'Write-Host 1' }
            [PSCustomObject]@{ type = 'Module/B'; name = 'ResourceB'; properties = @{}; preExecutionScript = 'Write-Host 2' }
            [PSCustomObject]@{ type = 'Module/C'; name = 'ResourceC'; properties = @{} }
        )

        { . $preParseFilePath -PipelineResources $resources -Settings @{} } | Should -Throw "*ResourceA*ResourceB*"
    }

    It "throws when Settings is `$null (AllowExecutionScripts defaults to false)" {
        $resources = @(
            [PSCustomObject]@{ type = 'Module/A'; name = 'ResourceA'; properties = @{}; postExecutionScript = 'Write-Host 1' }
        )

        { . $preParseFilePath -PipelineResources $resources } | Should -Throw
    }

    It "does not throw when AllowExecutionScripts is explicitly true" {
        $resources = @(
            [PSCustomObject]@{ type = 'Module/A'; name = 'ResourceA'; properties = @{}; postExecutionScript = 'Write-Host 1' }
            [PSCustomObject]@{ type = 'Module/B'; name = 'ResourceB'; properties = @{}; preExecutionScript = 'Write-Host 2' }
        )

        { . $preParseFilePath -PipelineResources $resources -Settings @{ AllowExecutionScripts = $true } } | Should -Not -Throw
    }
}

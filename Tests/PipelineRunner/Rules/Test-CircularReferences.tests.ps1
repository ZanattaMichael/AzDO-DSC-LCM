Describe "Test-CircularReferences" -Tag Unit, Runner, Rules, PreParse {

    BeforeAll {

        # Load the rule under test.
        $preParseFilePath = (Get-FunctionPath 'Test-CircularReferences.ps1').FullName

        Mock -CommandName Write-Host

        # A linear chain: 1 -> 2 -> 3. No cycle.
        $script:linearResources = @(
            [PSCustomObject]@{
                Type = "ResourceType1"
                Name = "ResourceName1"
                DependsOn = @("ResourceType2/ResourceName2")
            },
            [PSCustomObject]@{
                Type = "ResourceType2"
                Name = "ResourceName2"
                DependsOn = @("ResourceType3/ResourceName3")
            },
            [PSCustomObject]@{
                Type = "ResourceType3"
                Name = "ResourceName3"
                DependsOn = @()
            }
        )
    }

    Context "Acyclic graphs" {

        It "Should not throw for a linear dependency chain" {
            { . $preParseFilePath -PipelineResources $script:linearResources } | Should -Not -Throw
        }

        It "Should not throw for two independent chains" {
            $PipelineResources = @(
                [PSCustomObject]@{ Type = "ResourceType1"; Name = "ResourceName1"; DependsOn = @("ResourceType2/ResourceName2") },
                [PSCustomObject]@{ Type = "ResourceType2"; Name = "ResourceName2"; DependsOn = @("ResourceType3/ResourceName3") },
                [PSCustomObject]@{ Type = "ResourceType3"; Name = "ResourceName3"; DependsOn = @() },
                [PSCustomObject]@{ Type = "ResourceType4"; Name = "ResourceName4"; DependsOn = @("ResourceType5/ResourceName5") },
                [PSCustomObject]@{ Type = "ResourceType5"; Name = "ResourceName5"; DependsOn = @() }
            )

            { . $preParseFilePath -PipelineResources $PipelineResources } | Should -Not -Throw
        }

        It "Should not throw for a diamond, where two branches share a dependency" {
            # 1 -> 2 -> 4 and 1 -> 3 -> 4. Resource 4 is reached twice, by two different
            # branches, which is a perfectly ordinary DAG. The previous implementation never
            # popped its stack, so the second branch found the first branch's nodes still on
            # it and reported a cycle that does not exist (#6).
            $PipelineResources = @(
                [PSCustomObject]@{ Type = "ResourceType1"; Name = "ResourceName1"; DependsOn = @("ResourceType2/ResourceName2", "ResourceType3/ResourceName3") },
                [PSCustomObject]@{ Type = "ResourceType2"; Name = "ResourceName2"; DependsOn = @("ResourceType4/ResourceName4") },
                [PSCustomObject]@{ Type = "ResourceType3"; Name = "ResourceName3"; DependsOn = @("ResourceType4/ResourceName4") },
                [PSCustomObject]@{ Type = "ResourceType4"; Name = "ResourceName4"; DependsOn = @() }
            )

            { . $preParseFilePath -PipelineResources $PipelineResources } | Should -Not -Throw
        }

        It "Should not throw for a fully connected acyclic graph" {
            # Every resource depends on every later resource. Cycle-free, and the case the old
            # suite asserted *should* throw.
            $PipelineResources = @(
                [PSCustomObject]@{ Type = "ResourceType1"; Name = "ResourceName1"; DependsOn = @("ResourceType2/ResourceName2") },
                [PSCustomObject]@{
                    Type = "ResourceType2"
                    Name = "ResourceName2"
                    DependsOn = @(
                        "ResourceType3/ResourceName3"
                        "ResourceType4/ResourceName4"
                        "ResourceType5/ResourceName5"
                    )
                },
                [PSCustomObject]@{
                    Type = "ResourceType3"
                    Name = "ResourceName3"
                    DependsOn = @(
                        "ResourceType4/ResourceName4"
                        "ResourceType5/ResourceName5"
                    )
                },
                [PSCustomObject]@{ Type = "ResourceType4"; Name = "ResourceName4"; DependsOn = @("ResourceType5/ResourceName5") },
                [PSCustomObject]@{ Type = "ResourceType5"; Name = "ResourceName5" }
            )

            { . $preParseFilePath -PipelineResources $PipelineResources } | Should -Not -Throw
        }

        It "Should not throw when a dependency is not present in the configuration" {
            # An unresolved dependency is a different problem, reported elsewhere.
            $PipelineResources = @(
                [PSCustomObject]@{ Type = "ResourceType1"; Name = "ResourceName1"; DependsOn = @("ResourceTypeX/ResourceNameX") }
            )

            { . $preParseFilePath -PipelineResources $PipelineResources } | Should -Not -Throw
        }

        It "Should not throw when no resources are supplied" {
            { . $preParseFilePath -PipelineResources @() } | Should -Not -Throw
        }
    }

    Context "Cyclic graphs" {

        It "Should detect a two-resource cycle" {
            $PipelineResources = @(
                [PSCustomObject]@{ Type = "ResourceType1"; Name = "ResourceName1"; DependsOn = @("ResourceType2/ResourceName2") },
                [PSCustomObject]@{ Type = "ResourceType2"; Name = "ResourceName2"; DependsOn = @("ResourceType1/ResourceName1") }
            )

            { . $preParseFilePath -PipelineResources $PipelineResources } |
                Should -Throw "*Circular dependency detected with Resource*"
        }

        It "Should detect a resource that depends on itself" {
            $PipelineResources = @(
                [PSCustomObject]@{ Type = "ResourceType1"; Name = "ResourceName1"; DependsOn = @("ResourceType1/ResourceName1") }
            )

            { . $preParseFilePath -PipelineResources $PipelineResources } |
                Should -Throw "*Circular dependency detected with Resource*"
        }

        It "Should detect a nested cycle" {
            $PipelineResources = @(
                [PSCustomObject]@{ Type = "ResourceType1"; Name = "ResourceName1"; DependsOn = @("ResourceType2/ResourceName2") },
                [PSCustomObject]@{ Type = "ResourceType2"; Name = "ResourceName2"; DependsOn = @("ResourceType3/ResourceName3") },
                [PSCustomObject]@{ Type = "ResourceType3"; Name = "ResourceName3"; DependsOn = @("ResourceType1/ResourceName1") }
            )

            { . $preParseFilePath -PipelineResources $PipelineResources } |
                Should -Throw "*Circular dependency detected with Resource*"
        }

        It "Should detect a smaller loop reached through a longer chain" {
            $PipelineResources = @(
                [PSCustomObject]@{ Type = "ResourceType1"; Name = "ResourceName1"; DependsOn = @("ResourceType2/ResourceName2") },
                [PSCustomObject]@{ Type = "ResourceType2"; Name = "ResourceName2"; DependsOn = @("ResourceType3/ResourceName3") },
                [PSCustomObject]@{ Type = "ResourceType3"; Name = "ResourceName3"; DependsOn = @("ResourceType2/ResourceName2") }
            )

            { . $preParseFilePath -PipelineResources $PipelineResources } |
                Should -Throw "*Circular dependency detected with Resource*"
        }

        It "Should detect a cycle alongside an independent acyclic chain" {
            $PipelineResources = @(
                [PSCustomObject]@{ Type = "ResourceType1"; Name = "ResourceName1"; DependsOn = @("ResourceType2/ResourceName2") },
                [PSCustomObject]@{ Type = "ResourceType2"; Name = "ResourceName2"; DependsOn = @("ResourceType3/ResourceName3") },
                [PSCustomObject]@{ Type = "ResourceType3"; Name = "ResourceName3"; DependsOn = @("ResourceType1/ResourceName1") },
                [PSCustomObject]@{ Type = "ResourceType4"; Name = "ResourceName4"; DependsOn = @("ResourceType5/ResourceName5") },
                [PSCustomObject]@{ Type = "ResourceType5"; Name = "ResourceName5" }
            )

            { . $preParseFilePath -PipelineResources $PipelineResources } |
                Should -Throw "*Circular dependency detected with Resource*"
        }

        It "Should name every member of the cycle in path order" {
            $PipelineResources = @(
                [PSCustomObject]@{ Type = "ResourceType1"; Name = "ResourceName1"; DependsOn = @("ResourceType2/ResourceName2") },
                [PSCustomObject]@{ Type = "ResourceType2"; Name = "ResourceName2"; DependsOn = @("ResourceType3/ResourceName3") },
                [PSCustomObject]@{ Type = "ResourceType3"; Name = "ResourceName3"; DependsOn = @("ResourceType1/ResourceName1") }
            )

            $message = $null
            try { . $preParseFilePath -PipelineResources $PipelineResources } catch { $message = $_.Exception.Message }

            $message | Should -Match 'ResourceType1/ResourceName1 -> ResourceType2/ResourceName2 -> ResourceType3/ResourceName3 -> ResourceType1/ResourceName1'
        }

        It "Should report only the cycle, not the chain that led into it" {
            # 1 -> 2 -> 3 -> 2. Resource 1 is on the walk but not in the loop.
            $PipelineResources = @(
                [PSCustomObject]@{ Type = "ResourceType1"; Name = "ResourceName1"; DependsOn = @("ResourceType2/ResourceName2") },
                [PSCustomObject]@{ Type = "ResourceType2"; Name = "ResourceName2"; DependsOn = @("ResourceType3/ResourceName3") },
                [PSCustomObject]@{ Type = "ResourceType3"; Name = "ResourceName3"; DependsOn = @("ResourceType2/ResourceName2") }
            )

            $message = $null
            try { . $preParseFilePath -PipelineResources $PipelineResources } catch { $message = $_.Exception.Message }

            $message | Should -Match 'ResourceType2/ResourceName2 -> ResourceType3/ResourceName3 -> ResourceType2/ResourceName2'
            $message | Should -Not -Match 'ResourceName1'
        }
    }

    Context "Hashtable resources" {

        It "Should handle resources supplied as hashtables, as the YAML loader produces" {
            $PipelineResources = @(
                @{ Type = "ResourceType1"; Name = "ResourceName1"; DependsOn = @("ResourceType2/ResourceName2") },
                @{ Type = "ResourceType2"; Name = "ResourceName2"; DependsOn = @() }
            )

            { . $preParseFilePath -PipelineResources $PipelineResources } | Should -Not -Throw
        }

        It "Should detect a cycle in hashtable resources" {
            $PipelineResources = @(
                @{ Type = "ResourceType1"; Name = "ResourceName1"; DependsOn = @("ResourceType2/ResourceName2") },
                @{ Type = "ResourceType2"; Name = "ResourceName2"; DependsOn = @("ResourceType1/ResourceName1") }
            )

            { . $preParseFilePath -PipelineResources $PipelineResources } |
                Should -Throw "*Circular dependency detected with Resource*"
        }
    }
}

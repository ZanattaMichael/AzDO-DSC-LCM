Describe "Assert-SafeConditionExpression Function Tests" -Tag Unit, Runner {

    BeforeAll {
        . (Get-FunctionPath 'Assert-SafeConditionExpression.ps1').FullName
    }

    Context "permitted predicates" {

        It "allows a simple comparison" {
            { Assert-SafeConditionExpression -Expression "'a' -eq 'b'" } | Should -Not -Throw
        }

        It "allows a variable comparison" {
            { Assert-SafeConditionExpression -Expression '$ProjectEnsure -eq ''Present''' } | Should -Not -Throw
        }

        It "allows property access on a variable" {
            { Assert-SafeConditionExpression -Expression '$Node.Project -ne $null' } | Should -Not -Throw
        }

        It "allows logical operators and grouping" {
            { Assert-SafeConditionExpression -Expression '(1 -eq 1) -and ($x -ne 2)' } | Should -Not -Throw
        }

        It "allows a bare parameters() call" {
            { Assert-SafeConditionExpression -Expression "parameters('Environment')" } | Should -Not -Throw
        }

        It "allows a bare variables() call" {
            { Assert-SafeConditionExpression -Expression "variables('ProjectWorkBoardsStatus')" } | Should -Not -Throw
        }

        It "allows a bare reference() call" {
            { Assert-SafeConditionExpression -Expression "reference('Configuration Git Repository')" } | Should -Not -Throw
        }

        It "allows equals() combining parameters() and variables()" {
            { Assert-SafeConditionExpression -Expression "equals(parameters('Environment'), variables('ProjectWorkBoardsStatus'))" } | Should -Not -Throw
        }

        It "allows not() wrapping equals()" {
            { Assert-SafeConditionExpression -Expression "not(equals(variables('ProjectWorkBoardsStatus'), 'disabled'))" } | Should -Not -Throw
        }

        It "allows the whitelisted functions mixed with ordinary operators" {
            { Assert-SafeConditionExpression -Expression "(parameters('Environment') -eq 'Prod') -and (variables('ProjectWorkBoardsStatus') -eq 'enabled')" } | Should -Not -Throw
        }
    }

    Context "rejected side effects" {

        It "rejects a bare command invocation" {
            { Assert-SafeConditionExpression -Expression 'Stop-TaskProcessing' } |
                Should -Throw '*command invocation*'
        }

        It "rejects a command invocation nested in an expression" {
            { Assert-SafeConditionExpression -Expression '(Get-Item C:\).Name -eq ''x''' } |
                Should -Throw '*command invocation*'
        }

        It "rejects a non-whitelisted command nested inside an allowed function call" {
            { Assert-SafeConditionExpression -Expression "equals(Get-Item C:\, 'x')" } |
                Should -Throw '*command invocation*'
        }

        It "rejects stopProcessing(), which is not on the condition allow-list" {
            { Assert-SafeConditionExpression -Expression "parameters('X'); stopProcessing" } |
                Should -Throw '*command invocation*'
        }

        It "rejects a variable assignment" {
            { Assert-SafeConditionExpression -Expression '$FailCounter = 0' } |
                Should -Throw '*variable assignment*'
        }

        It "rejects a method call" {
            { Assert-SafeConditionExpression -Expression '$results.Clear()' } |
                Should -Throw '*method call*'
        }

        It "rejects a syntactically invalid expression" {
            { Assert-SafeConditionExpression -Expression '$x -eq' } |
                Should -Throw "*Invalid 'condition' expression*"
        }
    }
}

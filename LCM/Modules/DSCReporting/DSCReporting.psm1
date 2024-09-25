Function Initialize-LogAnalytics {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $WorkspaceId,

        [Parameter(Mandatory = $true)]
        [string]
        $WorkspaceKey,

        [Parameter(Mandatory = $true)]
        [string]
        $LogType
    )

    $global:LogAnalyticsWorkspaceId = $WorkspaceId
    $global:LogAnalyticsWorkspaceKey = $WorkspaceKey
    $global:LogAnalyticsLogType = $LogType
    $global:LogAnalyticsReport = [System.Collections.Generic.List[HashTable]]::new()
}

Function Add-ToReport {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $ResourceName,

        [Parameter(Mandatory = $true)]
        [string]
        $ResourceType,

        [Parameter()]
        [string]
        $dependsOn,

        [Parameter(Mandatory)]
        [Object]
        $Properties,

        [Parameter(Mandatory)]
        [ValidateSet('Audit', 'Enforce')]
        [string]
        $Mode,

        [Parameter(Mandatory)]
        [ValidateSet('Complient', 'NonComplient', 'Error', 'Other')]
        [string]
        $ResultType

    )

    $global:LogAnalyticsReport.Add(@{
        ResourceName = $ResourceName
        ResourceType = $ResourceType
        dependsOn = $dependsOn
        Properties = $Properties
        Mode = $Mode
        ResultType = $ResultType
    })

}

Send-ToLogAnalytics {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $ResourceName,

        [Parameter(Mandatory = $true)]
        [string]
        $ResourceType,

        [Parameter()]
        [string]
        $dependsOn,

        [Parameter(Mandatory)]
        [Object]
        $Properties,

        [Parameter(Mandatory)]
        [ValidateSet('Audit', 'Enforce')]
        [string]
        $Mode,

        [Parameter(Mandatory)]
        [ValidateSet('Complient', 'NonComplient', 'Error', 'Other')]
        [string]
        $ResultType
    )

    $global:LogAnalyticsReport.Add(@{
        ResourceName = $ResourceName
        ResourceType = $ResourceType
        dependsOn = $dependsOn
        Properties = $Properties
        Mode = $Mode
        ResultType = $ResultType
    })

}
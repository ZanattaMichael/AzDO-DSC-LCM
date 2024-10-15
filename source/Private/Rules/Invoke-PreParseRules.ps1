function Invoke-PreParseRules {
    param(
        [Parameter(Mandatory=$true)]
        [Object[]]$Tasks
    )

    # Get the path to the PreParseRules directory
    $currentPath = (Get-Module 'azdo-dsc-lcm').ModuleBase
    $PreParseDirectoryPath = "{0}\LCM Rules\PreParse" -f $currentPath

    #
    # Iterate through each of the PreParse Rules

    if (-not (Test-Path -Path $PreParseDirectoryPath)) {
        Throw "[Invoke-PreParseRules] No Tasks to Process in Directory: $PreParseDirectoryPath"
        return $Tasks
    }

    Write-Verbose "[Invoke-PreParseRules] Processing PreParse Rules in Directory: $PreParseDirectoryPath"

    $PreParseFiles = Get-ChildItem -Path $PreParseDirectoryPath -Filter "*.ps1"

    # Iterate through each of the PreParse Rules
    foreach ($File in $PreParseFiles) {
        Write-Verbose "[Invoke-PreParseRules] Processing PreParse Rule: $($File.FullName)"
        # Execute the PreParse Rule
        . $File.FullName -PipelineResources $Tasks
    }
}
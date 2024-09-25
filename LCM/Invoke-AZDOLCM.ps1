<#
.SYNOPSIS
Invoke-AZDOLCM.ps1 is a PowerShell script that invokes the Azure DevOps DSC (Desired State Configuration) LCM (Local Configuration Manager) for deploying and managing configurations.

.DESCRIPTION
This script is designed to be used with Azure DevOps to deploy and manage configurations using the Azure DevOps DSC LCM. It accepts various parameters such as the Azure DevOps organization name, configuration directory, configuration URL, JIT (Just-In-Time) token, mode, authentication type, PAT (Personal Access Token), and report path. It validates the provided parameters and performs the necessary actions to clone the configuration, compile it, create the authentication provider, and invoke the resources.

.PARAMETER AzureDevopsOrganizationName
Specifies the name of the Azure DevOps organization. This parameter is mandatory.

.PARAMETER ConfigurationDirectory
Specifies the directory where configuration files are located. This parameter is mandatory.

.PARAMETER ConfigurationURL
Specifies the URL for the configuration. This must be a valid URI. This parameter is mandatory.

.PARAMETER JITToken
Specifies a mandatory parameter named JITToken which must be provided when the function is called. This parameter expects a string value, typically representing a "Just-In-Time" access token.

.PARAMETER Mode
Specifies an optional parameter with a ValidateSet attribute to restrict the value to either 'Test' or 'Set'. The default value for this parameter is 'Test'.

.PARAMETER AuthenticationType
Specifies the authentication type to be used. It accepts either 'ManagedIdentity' or 'PAT' (Personal Access Token). The default value for this parameter is 'ManagedIdentity'.

.PARAMETER PATToken
Specifies the Personal Access Token (PAT) when the AuthenticationType parameter is set to 'PAT'. This parameter is mandatory when the AuthenticationType parameter is set to 'PAT'.

.PARAMETER ReportPath
Specifies an optional parameter to specify a report path. It includes a validation script to ensure the provided path points to a file (leaf) and not a directory.

.EXAMPLE
Invoke-AZDOLCM.ps1 -AzureDevopsOrganizationName "MyOrg" -ConfigurationDirectory "C:\Config" -ConfigurationURL "https://example.com/config" -JITToken "abc123" -Mode "Test" -AuthenticationType "ManagedIdentity"

This example demonstrates how to invoke the script with the required parameters.

.EXAMPLE
Invoke-AZDOLCM.ps1 -AzureDevopsOrganizationName "MyOrg" -ConfigurationDirectory "C:\Config" -ConfigurationURL "https://example.com/config" -JITToken "abc123" -Mode "Set" -AuthenticationType "PAT" -PATToken "xyz456" -ReportPath "C:\Reports\output.txt"

This example demonstrates how to invoke the script with all parameters, including an optional report path.

.NOTES
This script requires the following modules to be installed: powershell-yaml, AzureDevOpsDsc.Common, AzureDevOpsDsc, datum, Datum.InvokeCommand. Please ensure that these modules are installed before running this script.

The environment variable AZDODSC_CACHE_DIRECTORY must be set before running this script.

This script is subject to the Microsoft Open Source Code of Conduct. For more information, see https://opensource.microsoft.com/codeofconduct.
#>
# Utilizes the CmdletBinding attribute to enable advanced function features similar to cmdlets.
[CmdletBinding(defaultParameterSetName='Default')]
param(
    # Declares a mandatory parameter that specifies the name of the Azure DevOps organization.
    [Parameter(Mandatory, ParameterSetName='Default')]
    [Parameter(Mandatory, ParameterSetName='PAT')]
    [String]$AzureDevopsOrganizationName,

    # Declares a mandatory parameter that specifies the directory where configuration files are located.
    [Parameter(Mandatory, ParameterSetName='Default')]
    [Parameter(Mandatory, ParameterSetName='PAT')]
    [String]$ConfigurationDirectory,

    # Declares a mandatory parameter that specifies the URL for the configuration.
    # This must be a valid URI.
    [Parameter(Mandatory, ParameterSetName='Default')]
    [Parameter(Mandatory, ParameterSetName='PAT')]
    [Uri]$ConfigurationURL,

    # Declares a mandatory parameter named JITToken which must be provided when the function is called.
    # This parameter expects a string value, typically representing a "Just-In-Time" access token.
    [Parameter(Mandatory, ParameterSetName='Default')]
    [Parameter(Mandatory, ParameterSetName='PAT')]
    [String]$JITToken,

    # Declares an optional parameter with a ValidateSet attribute to restrict the value to either 'Test' or 'Set'.
    # The default value for this parameter is 'Set'.
    [Parameter(Mandatory, ParameterSetName='Default')]
    [Parameter(Mandatory, ParameterSetName='PAT')]
    [ValidateSet('Test', 'Set')]
    [String]$Mode='Test',

    # Declare the AuthenticationType parameter with a ValidateSet attribute to restrict the value to 'ManagedIdentity' or 'PAT'.
    # The default value for this parameter is 'ManagedIdentity'.
    [Parameter(ParameterSetName='Default')]
    [Parameter(ParameterSetName='PAT')]
    [ValidateSet('ManagedIdentity', 'PAT')]
    [String]$AuthenticationType='ManagedIdentity',

    # Declare the PATToken parameter with a ValidateScript attribute to ensure the provided value is a valid Personal Access Token.
    # This parameter is mandatory when the AuthenticationType parameter is set to 'PAT'.
    [Parameter(Mandatory, ParameterSetName='PAT')]
    [ValidateScript({$_ -match '^[a-zA-Z0-9]{52}$'})]
    [String]$PATToken,

    # The following commented-out parameters could be used to specify a report path.
    # It includes a validation script to ensure the provided path points to a file (leaf) and not a directory.
    
    [Parameter()]
    [ValidateScript({Test-Path -Path $_ -PathType Container})]
    [String]$ReportPath

)

# Set the Error Action Preference
$ErrorActionPreference = "Stop"

#
# Get the Execution Path
$ExecutionPath = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent

# Import the Helper Modules
Import-Module -Name (Join-Path -Path $ExecutionPath -ChildPath "Modules\Datum\DatumConfigurationHelper.psm1")
Import-Module -Name (Join-Path -Path $ExecutionPath -ChildPath "Modules\DSCConfiguration\DscConfiguration.psm1")

#
# Test to make sure that modules exist in the path

$modules = @('powershell-yaml', 'AzureDevOpsDsc.Common', 'AzureDevOpsDsc', 'datum', 'Datum.InvokeCommand')
$avaliableModules = Get-Module -ListAvailable | Select-Object -ExpandProperty Name

$modules | ForEach-Object {
    if ($avaliableModules -notcontains $_) {
        throw "Module $_ is not installed. Please install the module before running this script."
    }
}

# Import the modules
$modules | ForEach-Object {
    Import-Module -Name $_
}

#
# Test to make sure that the Enviroment Variable is Set

if (-not $ENV:AZDODSC_CACHE_DIRECTORY) {
    throw "The Environment Variable AZDODSC_CACHE_DIRECTORY is not set. Please set the environment variable before running this script."
}

#
# Clone the Datum Configuration from the Configuration URL

#$ConfigurationPath = Clone-Repository -GitURL $ConfigurationURL -JITToken $JITToken
$ConfigurationPath = 'C:\Temp\AzureDevOpsDSCDatum\Example Configuration'

#
# Compile the Datum Configuration
Build-DatumConfiguration -OutputPath $ConfigurationDirectory -ConfigurationPath $ConfigurationPath

#
# Determine the Authentication Type and create the Authentication Provider

if ($AuthenticationType -eq 'PAT') {
    New-AzDoAuthenticationProvider -OrganizationName $AzureDevopsOrganizationName -PersonalAccessToken $PATToken
} elseif ($AuthenticationType -eq 'ManagedIdentity') {
    New-AzDoAuthenticationProvider -OrganizationName $AzureDevopsOrganizationName -useManagedIdentity
} else {
    throw "The Authentication Type $AuthenticationType is not supported. Please use either 'PAT' or 'ManagedIdentity'."
}

#
# Invoke the Resources

# Create a hashtable to store the parameters
$params = @{
    Mode = $Mode
   # Verbose = $true
}

# If the ReportPath is provided, add it to the parameters
if ($ReportPath) {
    $params.ReportPath = $ReportPath
}

Get-ChildItem -LiteralPath $ConfigurationDirectory -File -Filter "*.yml" | ForEach-Object { 
    Invoke-DscConfiguration -FilePath $_.Fullname @params
}

<#
return

$postExecutionConfiguration = [System.Collections.Generic.List[HashTable]]::new()
# Once Completed, Iterate through the Output Directory and run the post execution tasks.
Get-ChildItem -LiteralPath $ConfigurationDirectory -File -Filter "*.yml" | ForEach-Object {

    # Load the Configuration Files
    $configuration = Get-Content $_.FullName | ConvertFrom-Yaml
    
    # Create a Hash Table to store the Post Execution Tasks.
    # Include the Post Execution Tasks and Variables.
    # The Variables are used to pass the variables to the Post Execution Tasks.

    $hashTable = @{
        postExecution = $configuration.resources
        variables = $configuration.variables
    }

    # Add the Post Execution Tasks to the Configuration Files
    if ($configuration.resources) {
        $postExecutionConfiguration.Add($hashTable)
    }

    # ^\{(.+)\}$

}

<#
postExecutionTask:

  - name: Org Group Members
    type: AzureDevOpsDsc/xAzDoProject
    properties:
      projectName: CON_$ProjectName
      projectDescription: $ProjectDescription
      visibility: private
      SourceControlType: Git
      ProcessTemplate: { scriptblock }     


#

#
# Flatten the Post Execution Tasks By Caculated Property
# Group the Post Execution Tasks by the Name and Type

$Configuration = $postExecutionConfiguration | ForEach-Object {
    $_.postExecution | ForEach-Object {
        $_
    }
} | Group-Object -Property {
    ("{0}/{1}" -f $_.type, $_.Name)
}

# Once the Post Execution Tasks are collected, iterate through the Post Execution Tasks and group them according to the Task Type.
# Iterate thorugh the Grouped Tasks and add the associated variables to the Post Execution Task.

$groupedPostExecutionTasks = [System.Collections.Generic.List[HashTable]]::new()

$Configuration | ForEach-Object {

    $currentObject = $_.Group[0]
    $name = $_.Name
    $obj = @{
        name = $name
        postExecution = $currentObject
        variables = [System.Collections.Generic.List[hashtable]]::new()
    }

    # Test if name exists within the postExecutionConfiguration
    $postExecutionConfiguration | ForEach-Object {
        $currentObj = $_
        $matched = $currentObj.postExecution | Where-Object { "$($_.type)/$($_.name)" -eq $name } 

        if ($matched) {
            $obj.variables.Add($currentObj.variables)
        }

    }

    $groupedPostExecutionTasks.Add($obj)

}

#>
# xAzDoDSCDatum

## Overview

`xAzDoDSCDatum` serves as the Local Configuration Manager (LCM) for the `AzureDevOpsDsc` Desired State Configuration (DSC) module. It simplifies the management of Azure DevOps resources through DSC. This module leverages the [Datum PowerShell Module](https://github.com/gaelcolas/Datum), created by Gael Colas, to enhance its functionality and efficiency.

The sample configuration is located in the `\Example Configuration\` directory. This example features a fictitious organization named Contoso.

### Key Features

- **Automated Management**: Streamline your Azure DevOps resource configuration.
- **Consistency**: Ensure consistent setup across multiple environments.
- **Scalability**: Easily scale configurations as your infrastructure grows.
- **Integration**: Seamlessly integrate with existing Azure DevOps workflows.

### Getting Started [Incomplete]

To start using `xAzDoDSCDatum`, follow these steps:

1. **Install the Module**:
   ```powershell
   Install-Module -Name xAzDoDSCDatum -Force
   ```

2. **Import the Module**:
   ```powershell
   Import-Module -Name xAzDoDSCDatum
   ```

## `Invoke-AZDOLCM.ps1`

This script is designed to be used with Azure DevOps to deploy and manage configurations using the Azure DevOps DSC LCM. It accepts various parameters such as the Azure DevOps organization name, configuration directory, configuration URL, JIT (Just-In-Time) token, mode, authentication type, PAT (Personal Access Token), and report path. It validates the provided parameters and performs the necessary actions to clone the configuration, compile it, create the authentication provider, and invoke the resources.

### `LCM\Rules\Format` Formatting Rules

### `LCM\Rules\PreParse` PreParsing Rules

#### `Test-CircularReferences.ps1`

This script detects circular dependencies between resources by iterating through each resource and checking if there are any circular references in the dependencies. Circular dependencies are found by inspecting the DependsOn property within the YAML configuration.

When a circular dependency is detected, the script logs an error message indicating the specific resources involved in the cycle. This helps developers quickly identify and resolve issues in their configuration files, ensuring a smooth deployment process. Additionally, the script can be integrated into CI/CD pipelines to automatically validate configurations before they are applied.

#### `Test-ResourcesForIncorrectProperties.ps1`

This script tests each resource in the provided pipeline resources for incorrect properties. It checks if the required keys (name, type, and properties) exist for each task and throws an error if any of these keys are missing. It also performs additional checks such as verifying if the resource exists, if the properties are correct, if the property values are of the correct type, if mandatory properties are not null, and if the property values match the selected values.


1. **Module Manifest (`AzureDevOpsDsc.psd1`)**
2. **Root Module (`AzureDevOpsDsc.psm1`)**
3. **Resources Folder**:
    - Each DSC Resource will have its own folder and files.
4. **Examples Folder**:
    - Example configurations demonstrating how to use the module.

## Configuration Merging and Execution Process

1. Datum merges the example configuration based on resolution precedence.
2. Once the YAML file for the project is generated, Datum executes any `[x={ $Node.ProjectPresence }=]` script blocks within the `_variables` property.
3. The Local Configuration Manager (LCM) ingests the configuration, loading and interpolating all variables and parameters into memory.
4. The LCM runs the `Pre-Parse` and `Format` rules.
5. Resources are ordered according to the `dependsOn` property.
6. The LCM iterates through each resource and performs the following steps:
    1. Checks if `Stop-TaskProcessing` has been executed; if so, the resource is skipped.
    2. Checks for the `condition` property and executes the statement. The resource executes on a `$true` response.
    3. Iterates through all properties within the resource and executes any calculated properties. This includes variables such as:
    
        ```yaml
        Ensure: $( if ([string]::IsNullOrEmpty($Project_Ensure)) { 'Present' } else { $Project_Ensure } )
        ```
    4. Executes the resource.
    5. Upon completion (even in case of an error), the LCM checks for the `postExecutionScript` property and invokes the code if present.
    
        ```yaml
        postExecutionScript: $( if ([string]::IsNullOrEmpty($Project_PostScript)) { 'DefaultScript' } else { $Project_PostScript } )
        ```
       

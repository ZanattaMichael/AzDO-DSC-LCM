[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification='Required for output within the DSC Resource')]

$references = @{}
$variables = @{}
$parameters = @{}

function SetVariables {
    param (
        [hashtable] $Source,
        [hashtable] $Target
    )

    foreach ($key in $Source.Keys) {
        $Target.Add($key, $Source[$key])

        $varName = $key.Replace(".", "_")
        New-Variable -Name $varName -Value $Source[$key] -Scope Script -Force | Out-Null
        New-Item -Path env:varName -Value $Source[$key] -ErrorAction SilentlyContinue
    }
}

function GetDefaultValues {
    param (
        [hashtable] $Source
    )

    $values = @{}
    foreach ($key in $Source.Keys) {
        $values.Add($key, $Source[$key].defaultValue)
    }

    return $values
}

function parameters {
    param ([string] $Name)

    $value = $parameters[$Name]
    return $value
}

function variables {
    param ([string] $Name)

    $value = $variables[$Name]
    return $value
}

function reference {
    param ([string] $Name)

    $value = $references[$Name]
    return $value
}

function equals {
    param ([string] $Left, [string] $Right)

    return [System.String]::Equals($Left, $Right)
}

function not {
    param ([Boolean] $Statement)

    return $Statement -ne $true
}
Function Sort-DependsOn {
    [OutputType([System.Collections.ArrayList])]
    param(
        [Object[]]$PipelineResources
    )

    #
    # Order the Tasks according to DependsOn Property

    Write-Verbose "Separating resources with and without DependsOn property"
    $ResourcesWithoutDependsOn, $ResourcesWithDependsOn = $PipelineResources.Where({ $null -eq $_.DependsOn }, 'Split')

    #
    # Format the DependsOn Property by ensuring the Resource parent is before the child.

    Write-Verbose "Initializing task list as an ArrayList"
    $TaskList = [System.Collections.ArrayList]::New()

    #
    # Enumerate the Resources with DependsOn Property

    ForEach ($ResourceObject in $ResourcesWithDependsOn) {

        Write-Verbose "Processing resource with DependsOn: [$($ResourceObject.Type)/$($ResourceObject.Name)]"

        # Get the DependsOn Property and format it into a hashtable.
        [Array]$DependsOn = $ResourceObject.DependsOn | ForEach-Object {
            $split = $_.Split("/")
            @{
                Type = "{0}/{1}" -f $split[0], $split[1]
                Name = $split[2..$split.length] -join "/"
            }
        }

        #
        # Test to see if the Resource DependsOn is the current Resource. If so, throw an error.

        foreach ($dependency in $DependsOn) {
            if (($dependency.Name -eq $ResourceObject.Name) -and ($dependency.Type -eq $ResourceObject.Type)) {
                throw "Resource [$($ResourceObject.Type)/$($ResourceObject.Name)] DependsOn Resource cannot be the same Resource."
            }
        }

        #
        # Dertermine if the Resource exists within ResourcesWithoutDependsOn

        [Array]$ResourceWithoutDependsOnTopIndex = $ResourcesWithoutDependsOn | ForEach-Object {
            $ht = $_
            # Locate the index position of the Resource within DependsOn. 
            0 .. ($DependsOn.Count - 1) | Where-Object {
                ($ht.Type -eq $DependsOn[$_].Type) -and
                ($ht.Name -eq $DependsOn[$_].Name)
            }
        }

        [Array]$ResourceWithDependsOnTopIndex = $ResourceTopIndex | ForEach-Object {
            $ht = $_
            # Locate the index position of the Resource within DependsOn. 
            0 .. ($DependsOn.Count - 1) | Where-Object {
                ($ht.Type -eq $DependsOn[$_].Type) -and
                ($ht.Name -eq $DependsOn[$_].Name)
            } | Sort-Object -Descending | Select-Object -First 1
        }

        $insertIndexPosition = $ResourceWithDependsOnTopIndex + 1

        # If $ResourceWithDependsOnTopIndex is not null and $ResourceWithoutDependsOnTopIndex is null add to the top of the list.
        if (($ResourceWithDependsOnTopIndex.Count -ne 0) -and ($ResourceWithoutDependsOnTopIndex.count -eq 0)) {
            Write-Verbose "Adding resource to the top of the list: [$($ResourceObject.Type)/$($ResourceObject.Name)]"
            $null = $TaskList.Insert(0, $ResourceObject)
            continue
        }
        # If $ResourceWithDependsOnTopIndex is null and $ResourceWithoutDependsOnTopIndex is not null, insert it after the Resource.
        if (($ResourceWithDependsOnTopIndex.Count -eq 0) -and ($ResourceWithoutDependsOnTopIndex.Count -ne 0)) {

            # If insertIndexPosition is greater than the count of the TaskList, add to the end of the list.
            if ($insertIndexPosition -gt $TaskList.Count) {
                Write-Verbose "Adding resource to the end of the list: [$($ResourceObject.Type)/$($ResourceObject.Name)]"
                $null = $TaskList.Add($ResourceObject)
            } else {
                Write-Verbose "Inserting resource before calculated index position: $insertIndexPosition"
                $null = $TaskList.Insert($insertIndexPosition, $ResourceObject)
            }

            continue

        }
        # If both $ResourceWithDependsOnTopIndex and $ResourceWithoutDependsOnTopIndex are null, add to the end of the list.
        if (($ResourceWithDependsOnTopIndex.Count -eq 0) -and ($ResourceWithoutDependsOnTopIndex.count -eq 0)) {
            Write-Verbose "Adding resource to the end of the list: [$($ResourceObject.Type)/$($ResourceObject.Name)]"
            $null = $TaskList.Add($ResourceObject)
            continue
        }
        # If both $ResourceWithDependsOnTopIndex and $ResourceWithoutDependsOnTopIndex are not null, insert it after the ResourceWithDependsOnTopIndex.
        if (($ResourceWithDependsOnTopIndex.Count -ne 0) -and ($ResourceWithoutDependsOnTopIndex.Count -ne 0)) {

            # If insertIndexPosition is greater than the count of the TaskList, add to the end of the list.
            if ($insertIndexPosition -gt $TaskList.Count) {
                Write-Verbose "Adding resource to the end of the list: [$($ResourceObject.Type)/$($ResourceObject.Name)]"
                $null = $TaskList.Add($ResourceObject)
            } else {
                Write-Verbose "Inserting resource before calculated index position: $insertIndexPosition"
                $null = $TaskList.Insert($insertIndexPosition, $ResourceObject)
            }
            
            continue

        }

    }

    #
    # Add ResourcesWithoutDependsOn to the top of the task list.
    Write-Verbose "Adding resources without DependsOn to the top of the task list"
    $ResourcesWithoutDependsOn | ForEach-Object {
        $null = $TaskList.Insert(0, $_)
    }

    $TaskList
}



<#
.SYNOPSIS
Expands strings in an array by performing expansion logic (e.g., expanding environment variables).

.DESCRIPTION
The Expand-StringInArray function takes an array of strings as input and expands each string by performing expansion logic. If an element in the array is a string, it will be expanded using the ExpandString method of the ExecutionContext object. If an element is not a string, it will be added to the expanded array as is.

.PARAMETER InputArray
The array of strings to be expanded.

.EXAMPLE
$strings = @("Hello, $env:USERNAME!", "Today is $((Get-Date).ToString('dddd'))")
$expandedStrings = Expand-StringInArray -InputArray $strings
$expandedStrings
# Output:
# Hello, John!
# Today is Monday

.NOTES
This function is useful when you need to expand strings in an array, such as when working with configuration files or templates.
#>
function Expand-StringInArray {
    param (
        [Parameter(Mandatory=$true)]
        [array]$InputArray
    )

    # Process each element in the array
    $expandedArray = @()
    foreach ($item in $InputArray) {
        if ($item -is [bool]) {
            # Keep the boolean value as is
            $expandedArray += $item
        }       
        elseif ($item -is [string]) {
            # Perform expansion logic here (example: expanding environment variables)
            $expandedItem = $ExecutionContext.InvokeCommand.ExpandString($item)
            $expandedArray += $expandedItem
        }
        elseif ($item -is [hashtable]) {
            $expandedArray += Expand-HashTable -InputHashTable $item
        } 
        else {
            $expandedArray += $item
        }
    }

    return $expandedArray
}

Function Expand-HashTable {
    param(
        [Parameter(Mandatory=$true)]
        [HashTable]$InputHashTable
    )

    $Property = @{}

    # Iterate through each key in the hashtable
    foreach ($key in $InputHashTable.Keys) {
        
        if ($InputHashTable[$key] -is [Bool]) {
            # Keep the boolean value as is
            $inputValue = $InputHashTable[$key]
        } 
        # Test if the property is a list
        elseif ($InputHashTable[$key].GetType().Name -eq 'List`1') {
            # Expand the string in the list
            $inputValue = Expand-StringInArray $task.properties[$key]
        } 
        elseif ($InputHashTable[$key] -is [hashtable]) {
            # Recursively expand the hashtable
            $inputValue = Expand-HashTable -InputHashTable $InputHashTable[$key]
        }
        else {
            # Expand the string using the ExecutionContext object
            $inputValue = $ExecutionContext.InvokeCommand.ExpandString($InputHashTable[$key])
        } 
    
        # Add the property to the hashtable
        $Property[$key] = $inputValue
    }

    return $Property

}

# Function to Expand the Parameters in the Array
function Expand-ParameterInArray {
    param (
        [Parameter(Mandatory=$true)]
        [array]$InputArray
    )

    # Process each element in the array
    $expandedArray = @()
    foreach ($item in $InputArray) {
        if ($item -is [bool]) {
            # Keep the boolean value as is
            $expandedArray += $item
        }       
        elseif (($item -is [string]) -and ($item -match '^\<params\=(?<name>.+)\>$')) {

            # If the parameter is not found, throw an error
            $propertyName = $Matches['name']
            if ([String]::IsNullOrEmpty($Script:parameters."$propertyName")) {
                throw "[Expand-Parameters] Parameter '$propertyName' not found in the parameters hashtable."
            }

            # Substitute the parameter with the parameter value
            $expandedArray += $Script:parameters."$propertyName"
        }
        elseif ($item -is [hashtable]) {
            $expandedArray += Expand-Parameters -InputHashTable $item
        } 
        else {
            $expandedArray += $item
        }
    }

    return $expandedArray
}

# Function to Expand the Parameters in the Hashtable
Function Expand-Parameters {
    param(
        [Parameter(Mandatory=$true)]
        [HashTable]$InputHashTable
    )

    $Property = @{}

    # Iterate through each key in the hashtable
    foreach ($key in $InputHashTable.Keys) {
            
        if ($InputHashTable[$key] -is [hashtable]) {
            # Recursively expand the hashtable
            $inputValue = Expand-HashTable -InputHashTable $InputHashTable[$key]
        }
        elseif ($InputHashTable[$key].GetType().Name -eq 'List`1') {
            # Expand the string in the list
            $inputValue = Expand-ParameterInArray $task.properties[$key]
        }
        elseif ($InputHashTable[$key] -match '^\<params\=(?<name>.+)\>$') {
            # If the parameter is not found, throw an error
            $propertyName = $Matches['name']
            if ([String]::IsNullOrEmpty($Script:parameters."$propertyName")) {
                throw "[Expand-Parameters] Parameter '$propertyName' not found in the parameters hashtable."
            }
            # Replace the Properties with the value
            $InputHashTable[$key] = $Script:parameters."$propertyName"

        }

        # Add the property to the hashtable
        $Property[$key] = $inputValue
    }

    return $Property

}

#
# Function to Invoke the DSC Configuration
function Invoke-DscConfiguration {
    # Declare parameters for the function with default values and validation where needed
    param (
        [string] $FilePath, # The path to the configuration file (.yaml/.yml or .json)
        [ValidateSet("Test", "Set")] # Ensures that Mode can only be 'Test' or 'Set'
        [string] $Mode = "Test", # Default mode is 'Test', can be set to 'Set' for applying changes,
        [String] $ReportPath = $null # Optional parameter for specifying a report path
    )

    # Clear StopTaskProcessing variable
    $script:StopTaskProcessing = $false

    $reporting = [System.Collections.Generic.List[PSCustomObject]]::New()

    # Determine the file extension of the provided FilePath
    $fileExtension = [System.IO.Path]::GetExtension($FilePath)
    Write-Verbose "File extension determined: $fileExtension"

    # Load the configuration from the YAML or JSON file into the $pipeline variable
    if ($fileExtension -eq ".yaml" -or $fileExtension -eq ".yml") {
        $pipeline = Get-Content $FilePath | ConvertFrom-Yaml
        Write-Verbose "Loaded YAML configuration from file: $FilePath"
    }
    elseif ($fileExtension -eq ".json") {
        $pipeline = Get-Content $FilePath | ConvertFrom-Json -AsHashtable
        Write-Verbose "Loaded JSON configuration from file: $FilePath"
    }

    # Clear any existing data in these hashtables before populating them
    $parameters.Clear()
    $variables.Clear()
    $references.Clear()
    Write-Verbose "Cleared existing data in parameters, variables, and references hashtables"

    Write-Host "---------------------------------------------------------------------" -ForegroundColor Green
    Write-Host "Processing configuration file: $FilePath" -ForegroundColor Green
    Write-Host "Mode: $Mode" -ForegroundColor Green
    Write-Host "Report Path: $ReportPath" -ForegroundColor Green
    Write-Host "---------------------------------------------------------------------" -ForegroundColor Green
    Write-Host "--> Setting Variables:" -ForegroundColor Green

    # Retrieve default values for parameters and set variables based on the pipeline's content
    #$defaultValues = GetDefaultValues -Source $pipeline.parameters
    $parameterizedProperties = GetDefaultValues -Source $pipeline.parameters

    SetVariables -Source $pipeline.variables -Target $variables
    SetVariables -Source $defaultValues -Target $parameters

    Write-Verbose "Retrieved default values for parameters and set variables based on pipeline content"
    
    Write-Host "--> Sorting tasks based on dependencies:" -ForegroundColor Green

    # Sort the tasks based on their dependencies to ensure correct execution order
    $tasks = Sort-DependsOn -PipelineResources $pipeline.resources

    Write-Verbose "Sorted tasks based on dependencies"

    # Invoke the PreParse the rules to process the tasks before formatting them
    Write-Host "--> Processing PreParse Rules:" -ForegroundColor Green

    # Invoke the PreParse the rules to process the tasks before formatting them
    Invoke-PreParseRules -Tasks $pipeline.resources
    
    # Invoke the Format Tasks Rules
    Write-Host "--> Processing Formatting Tasks:" -ForegroundColor Green

    # Format the tasks based on the configuration rules
    $tasks = Invoke-FormatTasks -Tasks $tasks

    # Report Task Counter
    $TaskCounter = 0

    # Loop through each task/resource and process it according to its configuration
    foreach ($task in $tasks) {

        # Increment the task counter
        $TaskCounter++

        Write-Verbose "Processing resource: [$($task.type)/$($task.name)]"

        # If the StopTaskProcessing variable is set to true, stop processing the tasks
        if ($Script:StopTaskProcessing) {
            Write-Verbose "Skipping resource due to 'Stop-TaskProcessing' being called:"
            # Add a reporting entry for the skipped resource
            $null = $reporting.Add([PSCustomObject]@{
                Counter = $TaskCounter
                Name = $task.name
                Type = $task.type
                Status = "Skipped"
                Method = 'TEST'
                Result = "SKIPPED"
                Message = "Resource skipped due to 'Stop-TaskProcessing' cmdlet."
            })

            # Skip to the next task
            continue
        }

        # Evaluate the Condition script block if it exists, and skip the task if the condition returns false
        if ($null -ne $task.Condition) {
            
            # Create a script block from th econdition property
            $sbCondition = [scriptblock]::Create($task.Condition)

            if ((. $sbCondition) -eq $false) {

                Write-Verbose "Skipping resource due to condition: [$($task.type)/$($task.name)]"
                # Add a reporting entry for the skipped resource
                $null = $reporting.Add([PSCustomObject]@{
                    Counter = $TaskCounter
                    Name = $task.name
                    Type = $task.type
                    Status = "Skipped"
                    Method = 'TEST'
                    Result = "SKIPPED"
                    Message = "Resource skipped due to condition {$($task.Condition)}."
                })

                # Skip to the next task
                continue

            }
        }

        # Extract the module name and resource type from the task's type property
        $module = $task.type.Split("/")[0]
        $resourceType = $task.type.Split("/")[1]
        Write-Verbose "Extracted module name: $module and resource type: $resourceType"
        
        # Iterate through the properties of the task and interpolate parameterized values
        #$Property = Expand-ParameterInArray -InputArray $task.properties

        # Replace any variables in the properties with their actual values
        $Property = Expand-HashTable -InputHashTable $task.properties

        Write-Verbose "Replaced variables in properties with actual values"

        # Prepare parameters for invoking the DSC resource using the 'Test' method
        $resourceParameters = @{
            Name = $resourceType
            ModuleName = $module
            Method = "Test"
            Property = $Property
        }

        Write-Verbose "Prepared parameters for 'Test' invocation of DSC resource"

        # Execute the 'Test' method to determine if the state is as desired
        $result = Invoke-DscResource @resourceParameters
        Write-Verbose "Executed 'Test' method for DSC resource: [$($task.type)/$($task.name)]"

        # Update the reporting list with the result of the 'Test' operation
        $null = $reporting.Add([PSCustomObject]@{
            Counter = $TaskCounter
            Name    = $task.name
            Type    = $task.type
            Method  = 'TEST'
            Status  = $result.InDesiredState ? "InDesiredState" : "NotInDesiredState"
            Result  = $result.InDesiredState ? "PASS" : "FAIL"
            Message = $result.Message
        })
     
        # If not in the desired state and Mode is 'Set', execute the 'Set' method to apply changes
        if ($result.InDesiredState) {
            Write-Verbose "Resource is in the desired state: [$($task.type)/$($task.name)]"
        }
        elseif ($Mode -eq "Set") {

            $resourceParameters.Method = "Set"

            try {
                $setResult = Invoke-DscResource @resourceParameters
                Write-Verbose "Executed 'Set' method to make changes: [$($task.type)/$($task.name)]"
                $Message = "Resource set to desired state"
                $Result = "PASS"
            }
            catch {
                Write-Error "Failed to apply changes with 'Set' method: [$($task.type)/$($task.name)]"
                $Message = $_.Exception.Message
                $Result = "FAIL"
            }
            finally {
                # Update the reporting list with the result of the 'Set' operation
                $null = $reporting.Add([PSCustomObject]@{
                    Counter     = $TaskCounter
                    Name        = $task.name
                    Type        = $task.type
                    Status      = "Set"
                    Method      = "SET"
                    Result      = $Result
                    Message     = $Message
                })
            
            }
        }
        else {
            Write-Verbose "Change needed, but mode is not set to 'Set': [$($task.type)/$($task.name)]"
        }

        #
        # Test if the postCondition property exists and execute the script block if it does.
        if ($null -ne $task.postExecutionScript) {
            # Create a script block from the postCondition property
            $sbPostExecutionScript = [scriptblock]::Create($task.postExecutionScript)

            # Dot-Source the postCondition script block
            . $sbPostExecutionScript
        }

        # Execute the 'Get' method to retrieve the current state of the resource
        $resourceParameters.Method = 'get'   
        $output_var = Invoke-DscResource @resourceParameters
        Write-Verbose "Retrieved current state with 'Get' method for DSC resource: [$($task.type)/$($task.name)]"

        # Store the output of the 'Get' operation in a reference table for later use
        $references.Add($task.name, $output_var)
        Write-Verbose "Stored output of 'Get' operation in references table for resource: [$($task.type)/$($task.name)]"

    }

    # If the reporting path is specified, print the report to the console and save it to the specified path
    if ($ReportPath) {

        $PassCounter = 0
        $FailCounter = 0
        $SkippedCounter = 0

        # Construct the full path for the report file
        $FilePath = "{0}\{1}.csv" -f $ReportPath, $($FilePath | Split-Path -Leaf).TrimEnd('.yml')
        
        Write-Verbose "[Invoke-DscConfiguration] FilePath $FilePath"
        # Convert the reporting data to CSV format and write it to the specified path
        $reporting | Export-Csv -Path $FilePath -NoTypeInformation

        # Group by the task name and status to provide a summary of the results
        $reportSummary = $reporting | Group-Object -Property Name | Sort-Object -Property {$_.Group.Counter}

        # Print the output of the report to the console.
        
        Write-Host "DSC Configuration Report: $FilePath" -ForegroundColor Green
        Write-Host "Results Summary:" -ForegroundColor Green

        # Iterate through the grouped report data and display the results
        foreach ($GroupReport in $reportSummary) {

            # Test the status of the task and set the colour accordingly

            # If the count is greater than 1, then the task has been executed multiple times meaning it has failed the test
            # but could of passed the set
            $Counter = $GroupReport.Group.Counter | Select-Object -First 1

            if ($GroupReport.Count -gt 1) {

                # Filter the results to see if the task has set the resource to the desired state
                $setResult = $GroupReport.Group | Where-Object { ($_.Method -eq 'SET') }

                if ($setResult.Result -contains "PASS") {
                    $Colour = "Green"
                    $Result = "PASS"
                    $PassCounter++
                } else {
                    $Colour = "Red"
                    $Result = "FAIL"
                    $FailCounter++
                }

            #
            # If the count is less than 1, then the task has only been executed once, meaning the test functionality has been tested.

            } else {
                if ($GroupReport.Group.Result -contains "PASS") {
                    $Colour = "Green"
                    $Result = "PASS"
                    $PassCounter++
                } elseif ($GroupReport.Group.Result -contains "FAIL") {
                    $Colour = "Red"
                    $Result = "FAIL"
                    $FailCounter++
                } elseif ($GroupReport.Group.Result -contains "SKIPPED") {
                    $Colour = "Yellow"
                    $Result = "SKIPPED"
                    $SkippedCounter++
                } else {
                    $Colour = "Magenta"
                    $Result = "UNKNOWN"
                }
            }
           
            # Print the task name and result with the appropriate colour
            Write-Host "[$($Counter)]    Task: $($GroupReport.Name) - Result: [$($Result)]" -ForegroundColor $Colour
        }

        $OutputColour = ($FailCounter -eq 0) ? "Green" : "Red" 

        # Print the total number of tasks executed
        Write-Host "Total Tasks Executed: $($reportSummary.Count)" -ForegroundColor $OutputColour
        Write-Host "Tasks Passed:  $PassCounter" -ForegroundColor $OutputColour
        Write-Host "Tasks Failed:  $FailCounter" -ForegroundColor $OutputColour
        Write-Host "Tasks Skipped: $SkippedCounter" -ForegroundColor $OutputColour
        Write-Host "Total Tasks: $($reportSummary.Count)" -ForegroundColor $OutputColour

    }

}

# Public Function to Stop the Processing of the Script for the current yaml file
Function Stop-TaskProcessing {
    # Check to make sure that Stop-TaskProcessing is being called within Invoke-DscConfiguration
    # Get the call-stack
    $callStack = Get-PSCallStack
    if ($callStack.Command -notcontains 'Invoke-DscConfiguration') {
        Write-Error "[DSCConfiguration\Stop-TaskProcessing] Stop-TaskProcessing can only be called within the Invoke-DscConfiguration function."
        return
    }

    Write-Verbose "Stopping the processing of the script"
    $script:StopTaskProcessing = $true
}


#
# Function to Build the Datum Configuration
Function Build-DatumConfiguration {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ -PathType 'Container' })]
        [String]
        $OutputPath,

        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ -PathType 'Container' })]
        [String]
        $ConfigurationPath

    )

    <#
    .SYNOPSIS
    This script builds the Azure DevOps DSC configuration.

    .DESCRIPTION
    The script imports necessary modules and sets the location to the example configuration folder. It then creates a Datum structure using the definition file Datum.yml. It iterates through each node in the Datum structure and retrieves the node groups. It creates a configuration data hashtable with the node groups and the Datum structure. It resolves the resources, parameters, conditions, and variables using the Resolve-Datum function.

    .PARAMETER None

    .EXAMPLE
    .\build.ps1
    #>

    # Clear the output directory
    Get-ChildItem -LiteralPath $OutputPath -File | Remove-Item -Force -ErrorAction SilentlyContinue
    Write-Verbose "Cleared the output directory at path: $OutputPath"

    $scriptBlock = {
        param($OutputPath, $ConfigurationPath)

        Function Resolve-AzDoDatumProject {
            param(
                [Parameter(Mandatory=$true)]
                [Object]$NodeName,
                [Parameter(Mandatory=$true)]
                [Object]$AllNodes
            )
            Write-Host "Processing node: $($NodeName.Name)"

            # Retrieve the NodeGroups for the current node and store them in an array

            Write-Verbose "Retrieved NodeGroups for node: $($NodeName.Name)"

            # Create a hashtable to hold configuration data, including all nodes and the Datum structure itself
            $ConfigurationData = @{
                AllNodes = $AllNodes
                Datum    = $Datum
            }
            Write-Verbose "Configuration data hashtable created for node: $($NodeName.Name)"

            # Access the AllNodes and Baseline properties from the configuration data
            $Node = @{ 
                Project = $NodeName.Name
                ProjectPresence = $ProjectType.name
            }
            
            $AllNodes.Keys | Where-Object {$_ -notin ('parameters','variables','resources')} | ForEach-Object {
                $Node."$($_)" = $AllNodes[$_]
            }
            $Baseline = $ConfigurationData.Datum.Baselines

            Write-Verbose "Accessed AllNodes and Baseline properties for node: $($NodeName.Name)"

            # Resolve and store the resources, parameters, conditions, and variables using the Resolve-Datum function
            $configuration = @{
                resources   = Resolve-Datum -PropertyPath 'resources'  -DatumStructure $Datum -Variable $Node
                parameters  = Resolve-Datum -PropertyPath 'parameters' -DatumStructure $Datum -Variable $Node
                conditions  = Resolve-Datum -PropertyPath 'conditions' -DatumStructure $Datum -Variable $Node
                variables   = Resolve-Datum -PropertyPath 'variables'  -DatumStructure $Datum -Variable $Node
            }

            Write-Verbose "Resolved resources, parameters, conditions, and variables for node: $($NodeName.Name)"
            
            # Iterate through the top-level node and execute the datum script blocks

            $hashTable = @{}
            # Iterate through each of the variables. If the resource value has a datum script block, execute it.
            $configuration.variables.keys | ForEach-Object {
                
                $variable = $_
                $value = $configuration.variables."$variable"
                
                # Test if the value is a script block and execute it if it is
                if ($Value | Test-InvokeCommandFilter) {
                    $hashTable."$variable" = $Value | Invoke-InvokeCommandAction -Node $Node
                } else {
                    $hashTable."$variable" = $Value
                }

            }
            
            # Set the variables in the configuration
            $configuration.variables = $hashTable

            <#
            $configuration.resources | ForEach-Object {
                $Resource = $_
                $Resource.properties = $Resource.properties | ForEach-Object {
                    if ($_.Value | Test-InvokeCommandFilter) {
                        $_.Value | Invoke-ProtectedDatumAction
                    } else {
                        $_.Value
                    }
                }
            }
            #>
            # Convert the configuration to YAML format and save it to the output file
            $configuration | ConvertTo-Yaml | Out-File "$OutputPath\$($NodeName.Name).yml"
            Write-Verbose "Configuration for node: $($NodeName.Name) has been converted to YAML and saved to file"
            

        }

        # Import the YAML module for handling YAML files
        # Import the Datum module for configuration data management
        Import-Module 'powershell-yaml'
        Import-Module 'datum'
        Import-Module 'datum.invokecommand'

        Write-Verbose "Modules for YAML, Datum and Datum.InvokeCommand have been imported"

        # Change the current directory to the Example Configuration directory
        Set-Location $ConfigurationPath
        Write-Verbose "Changed directory to Example Configuration"

        # Create a new Datum structure based on the provided definition file 'Datum.yml'
        $Datum = New-DatumStructure -DefinitionFile Datum.yml
        Write-Verbose "Datum structure created from definition file 'Datum.yml'"

        # Iterate through each of the Example Configuration projects
        ForEach ($ProjectType in $Datum.Projects.psobject.properties) {
            # Iterate through each of the projects in the current project type
            ForEach ($ProjectNode in $Datum.Projects."$($ProjectType.name)".psobject.properties) {
                # Resolve the project node using the Resolve-AzDoDatumProject function
                Resolve-AzDoDatumProject -NodeName $ProjectNode -AllNodes $Datum.Projects."$($ProjectType.name)"."$($ProjectNode.Name)"
            }
        }

    }

    #
    # Run the following powershell in a seperate thread

    # Create a runspace (thread) for the script block to run in
    $runspace = [runspacefactory]::CreateRunspace()

    # Open the runspace
    $runspace.Open()

    # Create a PowerShell instance and attach the script block and runspace
    $powerShellInstance = [powershell]::Create().AddScript($scriptBlock).AddArgument($OutputPath).AddArgument($ConfigurationPath)

    # Run the PowerShell script asynchronously
    $asyncResult = $powerShellInstance.BeginInvoke()

    # Optionally, you can handle the output of the script after it has completed
    $scriptOutput = $powerShellInstance.EndInvoke($asyncResult)

    # Output the results from the script block
    foreach ($output in $scriptOutput) {
        Write-Output $output
    }

    # Close the runspace when done
    $runspace.Close()

}

function Invoke-PreParseRules {
    param(
        [Parameter(Mandatory=$true)]
        [Object[]]$Tasks
    )

    # Get the path to the PreParseRules directory
    $currentPath = Get-Location
    $PreParseDirectoryPath = "{0}\Rules\PreParse" -f $currentPath

    #
    # Iterate through each of the PreParse Rules

    Write-Verbose "[Invoke-PreParseRules] Processing PreParse Rules in Directory: $PreParseDirectoryPath"

    $PreParseFiles = Get-ChildItem -Path $PreParseDirectoryPath -Filter "*.ps1"

    # Iterate through each of the PreParse Rules
    foreach ($File in $PreParseFiles) {
        Write-Verbose "[Invoke-PreParseRules] Processing PreParse Rule: $($File.FullName)"
        # Execute the PreParse Rule
        . $File.FullName -PipelineResources $Tasks
    }
}

Function Invoke-FormatTasks {
    param(
        [Parameter(Mandatory=$true)]
        [Object[]]$Tasks
    )

    # Get the path to the PreParseRules directory
    $currentPath = Get-Location
    $TasksDirectoryPath = "{0}\Rules\Format" -f $currentPath

    #
    # Iterate through each of the Configuration Tasks 
    
    Write-Verbose "[Format-Tasks] Processing Tasks in Directory: $TasksDirectoryPath"

    $ScriptFiles = Get-ChildItem -Path $TasksDirectoryPath -Filter "*.ps1"

    # Iterate through each of the Script Files
    foreach ($ScriptFile in $ScriptFiles) {
        # Write a Verbose message
        Write-Verbose "[Invoke-ScriptFiles] Processing Script File: $($ScriptFile.FullName)"

        # Execute the Script File
        $Tasks = . $ScriptFile.FullName -Tasks $Tasks
    }

    return $Tasks

}



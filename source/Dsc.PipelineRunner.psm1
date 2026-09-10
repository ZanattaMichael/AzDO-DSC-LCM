[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification='Required for output within the DSC Resource')]

$references = @{}
$variables = @{}
$parameters = @{}

# #57 §2: the DscMethodResult of the most recently evaluated resource, so the result()
# function-language accessor can read it from inside a postCondition expression. Owned by
# Start-DscRunner, which sets it before evaluating each resource's postCondition and never
# reads it back itself.
$currentResourceResult = $null

#REPLACE ME!
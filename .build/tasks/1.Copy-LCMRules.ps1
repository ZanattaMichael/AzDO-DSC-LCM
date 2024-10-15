
task Copy_LCM_Rules {

    $sourcePath = "$PSScriptRoot\..\..\LCM Rules" 
    $destinationPath = "$PSScriptRoot\..\..\Output\azdo-dsc-lcm\"
    $fullVersionPath = Get-ChildItem -Path $destinationPath

    Copy-Item -Path $sourcePath -Destination $fullVersionPath.FullName -Recurse -Force

}
function Set-Pac-Tools-Path {
    param (
        [Parameter(Mandatory)] [string]$agentOS
    )

    if ($agentOS -eq "Linux") {
        $osFolserSplit = "/"
        $pacToolsPath = $env:POWERPLATFORMTOOLS_PACCLIPATH + "/pac/tools"
    }
    else {
        $osFolserSplit = "\"
        $pacToolsPath = $env:POWERPLATFORMTOOLS_PACCLIPATH + "\pac\tools"
    } 

    Write-Host "##vso[task.setvariable variable=pacPath]$pacToolsPath"
    Write-Host "##vso[task.setvariable variable=folderSpliter]$osFolserSplit"
}

function Invoke-Pac-Authenticate {
    param (
        [Parameter(Mandatory = $true)][Alias("p")][string]$pacPath,
        [Parameter(Mandatory = $true)][Alias("t")][string]$tenantId,
        [Parameter(Mandatory = $true)][Alias("c")][string]$clientId,
        [Parameter(Mandatory = $true)][Alias("cs")][string]$clientSecret,
        [Parameter(Mandatory = $true)][Alias("u")][string]$url
    )
    if (Test-Path "$pacPath/pac.exe") {
        $pacexepath = "$pacPath/pac.exe"
        Invoke-Expression -Command "$pacexepath auth create -n almfpdev -u $url -id $clientId -cs $clientSecret -t $tenantId"
    }
    else {
        Write-Host "pac.exe NOT found"
    }

    return $pacexepath
}

function Invoke-Pac-Solution-Online-Version {
    param (
        [Parameter(Mandatory = $true)][Alias("p")][string]$pacPath,
        [Parameter(Mandatory = $true)][Alias("s")][string]$solution,
        [Parameter(Mandatory = $true)][Alias("v")][string]$version
    )

    $pacexepath = "$pacPath/pac.exe"
    Write-Host $pacexepath
    Invoke-Expression -Command "$pacexepath solution online-version -sn $solution -sv $version"
}

function Invoke-Clone-Or-Sync-Solution {
    param (
        [Parameter(Mandatory = $true)][Alias("p")][string]$pacPath,
        [Parameter(Mandatory = $true)][Alias("t")][string]$tenantId,
        [Parameter(Mandatory = $true)][Alias("c")][string]$clientId,
        [Parameter(Mandatory = $true)][Alias("cs")][string]$clientSecret,
        [Parameter(Mandatory = $true)][Alias("u")][string]$url,
        [Parameter(Mandatory = $true)][Alias("f")][string]$solutionFolder,
        [Parameter(Mandatory = $true)][Alias("s")][string]$solution
    )

    $pacexepath = "$pacPath/pac.exe"
    Write-Host $pacexepath

    $legacyFolderPath = "$solutionFolder$solution"
    Write-Host $legacyFolderPath

    $unpackfolderpath = "$solutionFolder$solution/SolutionPackage"
    Write-Host $unpackfolderpath

    if (Test-Path "$pacexepath") {
        $cdsProjPath = "$unpackfolderpath/$solution.cdsproj"
        Write-Host $cdsProjPath
        
        $cdsProjFolderPath = "$unpackfolderpath"
        Write-Host $cdsProjFolderPath

        if (Test-Path $cdsProjPath) {
            Write-Host "Sync"
            $cdsProjfolderPath = [System.IO.Path]::GetDirectoryName("$cdsProjPath")
            Set-Location -Path $cdsProjfolderPath
            Invoke-Expression -Command "$pacexepath solution sync --packagetype Both --async"
        }
        else {
            Write-Host "clone"
            if (Test-Path $legacyFolderPath) {
                Remove-Item $legacyFolderPath -recurse -Force
            }
            Invoke-Expression -Command "$pacexepath solution clone -n $solution --outputDirectory $unpackfolderpath --packagetype Both --async"
        }
        
        # CleanUp
        If (Test-Path "$cdsProjFolderPath\$solution") {
            Get-ChildItem -Path "$cdsProjFolderPath\$solution" | Copy-Item -Destination $cdsProjFolderPath -Recurse -Container
            Remove-Item "$cdsProjFolderPath\$solution" -Recurse
        }
    }
}

function Invoke-Solution-Create-Settings {
    param (
        [Parameter(Mandatory = $true)][Alias("p")][string]$pacPath,
        [Parameter(Mandatory = $true)][Alias("f")][string]$solutionFolder,
        [Parameter(Mandatory = $true)][Alias("s")][string]$solution,
        [Parameter(Mandatory = $false)][Alias("e")][string]$targetEnvironment
    )

    if($null -eq $targetEnvironment) {
        $targetEnvironment = "default"
    }

    $pacexepath = "$pacPath/pac.exe"
    Write-Host $pacexepath

    $cdsProjPath = "$solutionFolder$solution/SolutionPackage/$solution.cdsproj"
    Write-Host $cdsProjPath
    
    if (Test-Path "$pacexepath" -and Test-Path "$cdsProjPath") {

        $settingsFolder = "importSettings/$targetEnvironment"
        Write-Host $settingsFolder

        if (not(Test-Path "$settingsFolder")) {
            New-Item -ItemType Directory -Force -Path $settingsFolder
        }

        $settingsFile = "$settingsFolder/settings.json"
        $settingsTempFile = "$settingsFolder/tempSettings.json"
        Write-Host $settingsTempFile

        if (Test-Path "$settingsFile") {
            # Create Settings (First)
            Invoke-Expression -Command "$pacexepath solution create-settings -f $cdsProjPath -s $settingsTempFile"
        }
        else {
            # Create Settings (Others)
            Invoke-Expression -Command "$pacexepath solution create-settings -f $cdsProjPath -s $settingsFile"

            # Read the JSON files and convert them into PowerShell objects
            $oldJson = Get-Content -Path $settingsTempFile | ConvertFrom-Json
            $newJson = Get-Content -Path "$settingsFolder/settings.json" | ConvertFrom-Json

            # Iterate over the EnvironmentVariables
            for ($i = 0; $i -lt $newJson.EnvironmentVariables.Count; $i++) {
                # Find the corresponding item in the old JSON
                $oldItem = $oldJson.EnvironmentVariables | Where-Object { $_.SchemaName -eq $newJson.EnvironmentVariables[$i].SchemaName }
                # If the old item is not null and its Value is not null, keep the old value
                if ($null -ne $oldItem -and $null -ne $oldItem.Value) {
                    $newJson.EnvironmentVariables[$i].Value = $oldItem.Value
                }
            }

            # Iterate over the ConnectionReferences
            for ($i = 0; $i -lt $newJson.ConnectionReferences.Count; $i++) {
                # Find the corresponding item in the old JSON
                $oldItem = $oldJson.ConnectionReferences | Where-Object { $_.ConnectorId -eq $newJson.ConnectionReferences[$i].ConnectorId }
                # If the old item is not null and its ConnectionId is not null, keep the old value
                if ($null -ne $oldItem -and $null -ne $oldItem.ConnectionId) {
                    $newJson.ConnectionReferences[$i].ConnectionId = $oldItem.ConnectionId
                }
            }

            # Convert the resulting object back into JSON, Write the resulting JSON to a file
            $object | ConvertTo-Json | Set-Content -Path $newJson -Force
        }

        if (Test-Path "$settingsTempFile") {
            # Remove the temporary file
            Remove-Item -Path $settingsTempFile -Force
        }
    }
}

function Invoke-Solution-Export-Data {
    param (
        [Parameter(Mandatory = $true)][Alias("p")][string]$pacPath,
        [Parameter(Mandatory = $true)][Alias("f")][string]$dataSettingsFolder
    )

    $pacexepath = "$pacPath/pac.exe"
    Write-Host $pacexepath

    $schemaFile = $dataSettingsFolder + "schema.xml"
    Write-Host $schemaFile

    $dataFile = $dataSettingsFolder + "data.zip"
    Write-Host $dataFile
    
    if (Test-Path "$pacexepath" -and Test-Path "$schemaFile") {
        Invoke-Expression -Command "$pacexepath data export -sf $schemaFile -df $dataFile -o"
        Write-Host "Generated data.zip file"
    }
    else {
        Write-Host "No schema.xml file found"
    }
}
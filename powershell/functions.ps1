function Invoke-Clone-Or-Sync-Solution {
    param (
        [Parameter(Mandatory)] [String]$pacPath,
        [Parameter(Mandatory)] [String]$tenantId,
        [Parameter(Mandatory)] [String]$clientId,
        [Parameter(Mandatory)] [String]$clientSecret,
        [Parameter(Mandatory)] [String]$url,
        [Parameter(Mandatory)] [String]$solutionFolder,
        [Parameter(Mandatory)] [String]$solution
    )
	
    $legacyFolderPath = "$solutionFolder\$solution"
    $pacexepath = "$pacPath\pac.exe"
    if (Test-Path "$pacexepath") {
        # Trigger Auth
        Invoke-Expression -Command "$pacexepath auth create --url $url --name ppdev --applicationId $clientId --clientSecret $clientSecret --tenant $tenantId"
        $unpackfolderpath = "$solutionFolder\$solution\SolutionPackage"

        # Trigger Clone or Sync
        $cdsProjPath = "$solutionFolder\$solution\SolutionPackage\$solution.cdsproj"
        $cdsProjFolderPath = "$solutionFolder\$solution\SolutionPackage"
        if (Test-Path "$cdsProjPath") {
            $cdsProjfolderPath = [System.IO.Path]::GetDirectoryName("$cdsProjPath")
            Set-Location -Path $cdsProjfolderPath
            $syncCommand = "solution sync --packagetype Both --async"
            Invoke-Expression -Command "$pacexepath $syncCommand"
        }
        else {
            if (Test-Path "$legacyFolderPath") {
                Remove-Item "$legacyFolderPath" -recurse -Force
            }
            $cloneCommand = "solution clone -n $solution --processCanvasApps $processCanvasApps --outputDirectory ""$unpackfolderpath"" --packagetype Both --async"
            Invoke-Expression -Command "$pacexepath $cloneCommand"
        }
        
        # CleanUp
        If (Test-Path "$cdsProjFolderPath\$solution") {
            Get-ChildItem -Path "$cdsProjFolderPath\$solution" | Copy-Item -Destination "$cdsProjFolderPath" -Recurse -Container
            Remove-Item "$cdsProjFolderPath\$solution" -Recurse
        }
    }
}
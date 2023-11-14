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
        # Trigger Auth
        Invoke-Expression -Command "$pacexepath auth create --url $url --name ppdev --applicationId $clientId --clientSecret $clientSecret --tenant $tenantId"

        # Trigger Clone or Sync
        $cdsProjPath = "$unpackfolderpath/$solution.cdsproj"
        Write-Host $cdsProjPath
        
        $cdsProjFolderPath = "$unpackfolderpath"
        Write-Host $cdsProjFolderPath

        if (Test-Path $cdsProjPath) {
            $cdsProjfolderPath = [System.IO.Path]::GetDirectoryName("$cdsProjPath")
            Set-Location -Path $cdsProjfolderPath
            Invoke-Expression -Command "$pacexepath solution sync --packagetype Both --async"
        }
        else {
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
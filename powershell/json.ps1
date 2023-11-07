function JsonHelperMap {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias("json")]
        [string]$jsonPathFolder,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias("jsonConfig")]
        [string]$jsonConfigPathFolder,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(3, 10)]
        [Alias("fn")]
        [string]$friendlyName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias("p")]
        [string]$property,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias("sp")]
        [string]$skipProperties,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Map', 'Erase')]
        [Alias("a")]
        [string]$action
    )

    # Output File Name
    $output = "$jsonConfigPathFolder\json-$friendlyName-$property-$action.json"

    # Hastable Engine Objects
    $hashtable = @{}
    $recursiveValues_ = New-Object System.Collections.ArrayList
    $updateValues_ = New-Object System.Collections.ArrayList
    $updateFiles_ = New-Object System.Collections.ArrayList

    # If file already exist
    if (Test-Path $output) {
        # Load file
        $hashtable = Get-Content -Path $output | ConvertFrom-Json
        $updateValues_.AddRange($hashtable.values)
    }
    else {
        # Build First
        $hashtable.property = $property
        $hashtable.action = $action
        $hashtable.skip = $skipProperties
        $hashtable.values = New-Object System.Collections.ArrayList
        $hashtable.files = New-Object System.Collections.ArrayList
    }

    $jsonFiles = Get-ChildItem $jsonPathFolder -Filter *.json
    foreach ($jsonFile_ in $jsonFiles) {

        # Add file name (just for trace)
        $updateFiles_.Add($jsonFile_.Name)

        # Load file
        $json = Get-Content -Path $jsonFile_ | ConvertFrom-Json

        # Map
        if ("Map" -eq $action) {
            $recursiveValues_ = JSONHelperPropertyRecursive -obj $json -p $property -sp $skipProperties -a $action -e $false
            if ($recursiveValues_.Count -gt 0) {
                foreach ($value_ in $recursiveValues_) {
                    # Check if Value Exist
                    $found = $updateValues_ | Where-Object { $_.s -eq $value_.s }
                    # Found
                    if ($null -eq $found -or 0 -eq $found.Count) {
                        $updateValues_.Add($value_)
                    }
                }
            }
        }
        elseif ("Erase" -eq $action) {
            JSONHelperPropertyRecursive -obj $json -p $property -sp $skipProperties -a $action -v $values_ -e $true
            # Save Changes
            ConvertTo-Json $json -Depth 100 | Set-Content -Path $jsonFile_
        }
    }

    if ("Map" -eq $action) {
        # Update Values
        $hashtable.property = $property
        $hashtable.action = $action
        $hashtable.skip = $skipProperties
        $hashtable.files = $updateFiles_
        $hashtable.values = $updateValues_
        # Save Config File
        $hashtable | ConvertTo-Json | Out-File -FilePath $output
    }
}

function JsonHelperExec {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias("jsonConfig")]
        [string]$jsonConfigPathFolder,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias("json")]
        [string]$jsonPathFolder,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Map', 'Erase')]
        [Alias("a")]
        [string]$action
    )

    # Get Json Files (Produced By JsonHelperMap)
    $jsonConfigFiles = Get-ChildItem $jsonConfigPathFolder -Filter *.json
    # Foreach JSON Config File
    foreach ($jsonConfigFile_ in $jsonConfigFiles) {

        # Load file
        $hashtable = Get-Content -Path $jsonConfigFile_ | ConvertFrom-Json
        # Check if the actions are equals
        if ($hashtable.action = $action) {

            # Get Json Files (Produced By XMLHelper)
            $jsonFiles = Get-ChildItem $jsonPathFolder -Filter *.json
            # Foreach JSON Config File
            foreach ($jsonFile_ in $jsonFiles) {

                # Load file
                $json = Get-Content -Path $jsonFile_ | ConvertFrom-Json
                # Map
                JSONHelperPropertyRecursive -obj $json -p $property -sp $hashtable.s  -a $hashtable.action -v $hashtable.values -e $true
                # Save Changes
                ConvertTo-Json $json -Depth 100 | Set-Content -Path $jsonFile_.Name
            }
        }
    }
}

function JSONHelperPropertyRecursive {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias("obj")]
        [PSCustomObject]$object,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias("p")]
        [string]$property,

        [Parameter(Mandatory = $false)]
        [Alias("sp")]
        [string]$skipProperties,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Map', 'Erase')]
        [Alias("a")]
        [string]$action,
        
        [Parameter(Mandatory = $false)]
        [Alias("v")]
        [System.Collections.ArrayList]$values,

        [Parameter(Mandatory = $true)]
        [Alias("e")]
        [bool]$exec
    )

    if ($null -eq $values) {
        $values = New-Object System.Collections.ArrayList
    }

    $skipProperties_ = New-Object System.Collections.ArrayList
    if ($null -ne $skipProperties -and "" -ne $skipProperties) {
        $skipProperties_ = $skipProperties -split ','
    }

    foreach ($property_ in $object.PSObject.Properties) {
        # Skip
        $skip_ = $skipProperties_ | Where-Object { $_ -eq $property_.Name }
        if ($null -ne $skip_ -and $skip_.Length -gt 0) {
            return , $values 
        }

        # Found
        if ($property_.Name -contains $property -and '' -ne $property_.Value -and $null -ne $property_.Value) {
            $found = $values | Where-Object { $_.s -eq $property_.Value }

            # Map or Erase (Get the property value)
            if ("Map" -eq $action) {
                if ($null -eq $found -or 0 -eq $found.Count) {
                    [void]$values.Add(@{
                            s = $property_.Value
                            t = $null
                        })
                }
            }

            # Exec
            if ($exec -eq $true) {
                if ("Map" -eq $action) {
                    if ($null -ne $found -and $found.Count -eq 1) {
                        $property_.Value = $found.t
                    }
                }
                elseif ("Erase" -eq $action) {
                    $property_.Value = $null
                }
            }
        }
        # Finding
        elseif ($property_.Value -is [PSCustomObject] -and $null -ne $property_.Value ) {
            $v_ = JSONHelperPropertyRecursive -obj $property_.Value -p $property -sp $skipProperties -a $action -v $values -e $exec
            if ($null -ne $v_) {
                $values = $v_
            }
        }
        elseif ($property_.Value -is [Array]) {
            foreach ($i_ in $property_.Value) {
                $v_ = JSONHelperPropertyRecursive -obj $property_.Value -p $i_ -sp $skipProperties -a $action -v $values -e $exec
                if ($null -ne $v_) {
                    $values = $v_
                }
            }
        }
    }
    return , $values 
}
function XmlHelperMap {

    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias("tgt")]
        [string]$target,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias("xml")]
        [string]$xmlPathFolder,

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
        [Alias("n")]
        [string]$nodes,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Map', 'Erase')]
        [Alias("t")]
        [string]$type,

        [Parameter(Mandatory = $false)]
        [Alias("a")]
        [string]$attribute
    )

    # Nodes
    $nodes_ = $nodes -split ','
    if ($nodes_.Length -gt 0) {

        # Search Node
        $searchNode = $nodes_[0]
        $ensureNodes = New-Object System.Collections.ArrayList
        if ($nodes_.Length -gt 1) {
            $ensureNodes.AddRange($nodes_[1..($nodes_.Length - 1)])
        }

        # Ensure Directory
        If(Test-Path($jsonConfigPathFolder)){
            New-Item -Path $jsonConfigPathFolder -ItemType Directory -Force
        }

        # Output File Name
        $output = "$jsonConfigPathFolder\$target-xml-$type-$friendlyName-$searchNode.json"
        
        # Hastable Engine Objects
        $hashtable = @{}
        $values_ = New-Object System.Collections.ArrayList

        # If file already exist
        if (Test-Path $output) {
            # Load file
            $hashtable = Get-Content -Path $output | ConvertFrom-Json
            $values_.AddRange($hashtable.values)
        }
        else {
            # Build First
            $hashtable.node = $searchNode
            $hashtable.ensure = $ensureNodes
            $hashtable.type = $type
            $hashtable.values = New-Object System.Collections.ArrayList
        }

        # Get XML Files
        $xmlFiles = Get-ChildItem $xmlPathFolder -Filter *.xml -Recurse
        #Foreach XML
        foreach ($xmlFile_ in $xmlFiles) {

            # Load XML
            $xmlDoc = New-Object -TypeName System.Xml.XmlDocument
            $xmlDoc.Load($xmlFile_)
            
            # Find Nodes
            $foundNodes = $xmlDoc.SelectNodes("//$searchNode")
            foreach ($foundNode_ in $foundNodes) {
                # Evaluate Node
                $checkNode = $foundNode_
                $verifiedNode = $true

                # Ensure Right Node
                for ($i = 0; $i -lt $ensureNodes.Count; $i++) {
                    $parentNode_ = $ensureNodes[$i]
                    # If Parent is null or Parent is not the same
                    if ($null -ne $checkNode.ParentNode -and $parentNode_ -eq $checkNode.ParentNode.Name) {
                        $checkNode = $checkNode.ParentNode
                    }
                    else {
                        $verifiedNode = $false
                        #throw ("'" + $parentNode_ + "' not found on '" + $nodes + "' hierarchy")
                    }
                }

                if ($verifiedNode) {
                    # Value
                    $value = $null
                    if ("Map" -eq $type) {
                        #$value = $foundNode_.InnerText
                        $value = $foundNode_.OuterXml.ToString()
                    }
                    elseif ("Erase" -eq $type) {
                        #$value = "ignore"
                        $value = $foundNode_.OuterXml.ToString()
                    }
                    #elseif ("Map-AttributeValue" -eq $type) {
                    #    # Attribute Required
                    #    if ($null -ne $attribute) {
                    #        # Has Attribute and Contains the Attribute
                    #        if ($true -eq $foundNode_.HasAttributes -and "" -ne $foundNode_.GetAttribute($attribute)) {
                    #            #$value = $foundNode_.PropertyValue
                    #            $value = $foundNode_.OuterXml.ToString()
                    #        }
                    #        else {
                    #            throw ("Attribute '" + $attribute + "' is blank")
                    #        }
                    #    } 
                    #    else {
                    #        throw ("'attribute' parameters is required for 'type': AttributeValue")
                    #    }
                    #}

                    # Has Value
                    if ($null -ne $value) {
                        $found = $null
                        if ($values_.Count -gt 0) {
                            $found = $values_ | Where-Object { $_.s -eq $value }
                        }

                        # If Not Found Add Value
                        if ($null -eq $found) {
                            $values_.Add(@{
                                    s = $value
                                    t = $null
                                })
                        }
                    }
                }
            }
        }

        $hashtable.values = $values_
        $hashtable | ConvertTo-Json | Out-File -FilePath $output
    }
}

function XmlHelperExec() {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias("xml")]
        [string]$xmlPathFolder,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias("json")]
        [string]$jsonPathFolder,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Map', 'Erase')]
        [Alias("t")]
        [string]$type
    )

    # Get Json Files (Produced By XMLHelper)
    $jsonFiles = Get-ChildItem $jsonPathFolder -Filter *.json
    # Foreach JSON 
    foreach ($jsonFile_ in $jsonFiles) {

        # Load file
        $hashtable = Get-Content -Path $jsonFile_ | ConvertFrom-Json
        # Check if the types are equals
        if ($hashtable.type = $type) {
            # Get XML Files
            $xmlFiles = Get-ChildItem $xmlPathFolder -Filter *.xml -Recurse
            #Foreach XML
            foreach ($xmlFile_ in $xmlFiles) {

                # Changes
                $xmlChanges = 0
            
                # XML
                $xmlDoc = New-Object -TypeName System.Xml.XmlDocument
                $xmlDoc.Load($xmlFile_.FullName)
                $xmlContent = Get-Content -Path $xmlFile_.FullName -Raw

                # Foreach json.values Nodes
                foreach ($value_ in $hashtable.values) { 
                    # Node
                    $node = $hashtable.node

                    # Find Nodes
                    $nodes = $xmlDoc.SelectNodes("//$node")
                    foreach ($node_ in $nodes) {

                        # Evaluate Node
                        $checkNode = $node_
                        $verifiedNode = $true

                        # Ensure Right Node
                        for ($i = 0; $i -lt $ensureNodes.Count; $i++) {
                            $parentNode_ = $ensureNodes[$i]
                            # If Parent is null or Parent is not the same
                            if ($null -ne $checkNode.ParentNode -and $parentNode_ -eq $checkNode.ParentNode.Name) {
                                $checkNode = $checkNode.ParentNode
                            }
                            else {
                                $verifiedNode = $false
                                #throw ("'" + $parentNode_ + "' not found on '" + $nodes + "' hierarchy")
                            }
                        }

                        if ($verifiedNode) {
                            if ("Map" -eq $type) {
                                $xmlContent = $xmlContent.Replace($value_.s, $value_.t)
                                $xmlChanges++
                            }
                            elseif ("Erase" -eq $type) {
                                $xmlContent = $xmlContent.Replace($value_.s, "")
                                $xmlChanges++
                            }
                        }
                    }
                }

                if ($xmlChanges -gt 0) {
                    $xmlContent | Set-Content -Path $xmlFile_.FullName
                }
            }
        }
    }
}
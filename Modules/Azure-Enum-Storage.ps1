# Storage Account deep dive enumeration module

function Invoke-StorageDeepDive {
    Write-Host "`n`n=== STORAGE ACCOUNT DEEP DIVE ===" -ForegroundColor Cyan
    
    if (@($Global:StorageAccounts).Count -eq 0) {
        Write-Host "[-] No Storage Accounts available" -ForegroundColor Red
        return
    }
    
    # Check if Storage Token is available
    $hasStorageToken = -not [string]::IsNullOrWhiteSpace($Global:StorageToken)
    
    if ($hasStorageToken) {
        Write-Host "[+] Storage Access Token detected - Will use REST API calls" -ForegroundColor Green
    } else {
        Write-Host "[!] No Storage Access Token provided - Using standard PowerShell methods" -ForegroundColor Yellow
    }
    
    try {
        Write-ExecutedCommand "Get-AzStorageAccount"
        $storageAccountDetails = Get-AzStorageAccount -ErrorAction Stop
        
        if ($storageAccountDetails) {
            foreach ($sa in $storageAccountDetails) {
                Write-Host "`n--- Storage Account: $($sa.StorageAccountName) ---" -ForegroundColor Cyan
                Write-Host "  Resource Group     : $($sa.ResourceGroupName)" -ForegroundColor White
                Write-Host "  Location           : $($sa.PrimaryLocation)" -ForegroundColor White
                Write-Host "  SKU                : $($sa.SkuName)" -ForegroundColor White
                Write-Host "  Kind               : $($sa.Kind)" -ForegroundColor White
                Write-Host "  Access Tier        : $($sa.AccessTier)" -ForegroundColor White
                Write-Host "  Creation Time      : $($sa.CreationTime)" -ForegroundColor White
                Write-Host "  Provisioning State : $($sa.ProvisioningState)" -ForegroundColor White
                Write-Host "  HTTPS Only         : $($sa.EnableHttpsTrafficOnly)" -ForegroundColor White
                
                # Enumerate blob containers
                Write-Host "`n[*] Enumerating blob containers..." -ForegroundColor Yellow
                
                if ($hasStorageToken) {
                    # Use REST API with Storage Token
                    try {
                        $URL = "https://$($sa.StorageAccountName).blob.core.windows.net/?comp=list"
                        Write-ExecutedCommand "Invoke-RestMethod -Uri `"$URL`" -Method GET -Headers @{Authorization=`"Bearer `$StorageToken`"; `"x-ms-version`"=`"2017-11-09`"}"
                        
                        $Params = @{
                            "URI" = $URL
                            "Method" = "GET"
                            "Headers" = @{
                                "Content-Type" = "application/json"
                                "Authorization" = "Bearer $($Global:StorageToken)"
                                "x-ms-version" = "2017-11-09"
                                "accept-encoding" = "gzip, deflate"
                            }
                        }
                        
                        $ResultRaw = Invoke-RestMethod @Params -UseBasicParsing -ErrorAction Stop
                        
                        # Remove BOM (Byte Order Mark) if present
                        $ResultClean = $ResultRaw -replace '^\xEF\xBB\xBF', '' -replace '^ï»¿', ''
                        
                        # Parse XML response
                        [xml]$Result = $ResultClean
                        
                        if ($Result.EnumerationResults.Containers.Container) {
                            $containers = $Result.EnumerationResults.Containers.Container
                            
                            # Handle single container vs array
                            if ($containers -isnot [array]) {
                                $containers = @($containers)
                            }
                            
                            Write-Host "[+] Found $($containers.Count) container(s) via REST API" -ForegroundColor Green
                            
                            foreach ($container in $containers) {
                                Write-Host "`n  Container: $($container.Name)" -ForegroundColor Yellow
                                Write-Host "    Last Modified : $($container.Properties.'Last-Modified')" -ForegroundColor White
                                Write-Host "    Lease State   : $($container.Properties.LeaseState)" -ForegroundColor White
                                
                                # Check for PublicAccess property
                                if ($container.Properties.PublicAccess) {
                                    Write-Host "    Public Access : $($container.Properties.PublicAccess)" -ForegroundColor White
                                    
                                    if ($container.Properties.PublicAccess -ne "Off") {
                                        Write-Host "    [!] WARNING: Public access enabled!" -ForegroundColor Red
                                    }
                                } else {
                                    Write-Host "    Public Access : Off" -ForegroundColor White
                                }
                                
                                # Enumerate blobs in container
                                Write-Host "`n    [*] Enumerating blobs in container..." -ForegroundColor Yellow
                                try {
                                    $BlobURL = "https://$($sa.StorageAccountName).blob.core.windows.net/$($container.Name)?restype=container&comp=list"
                                    Write-ExecutedCommand "Invoke-RestMethod -Uri `"$BlobURL`" -Method GET -Headers @{Authorization=`"Bearer `$StorageToken`"; `"x-ms-version`"=`"2017-11-09`"}"
                                    
                                    $BlobParams = @{
                                        "URI" = $BlobURL
                                        "Method" = "GET"
                                        "Headers" = @{
                                            "Content-Type" = "application/json"
                                            "Authorization" = "Bearer $($Global:StorageToken)"
                                            "x-ms-version" = "2017-11-09"
                                            "accept-encoding" = "gzip, deflate"
                                        }
                                    }
                                    
                                    $BlobResultRaw = Invoke-RestMethod @BlobParams -UseBasicParsing -ErrorAction Stop
                                    
                                    # Remove BOM if present
                                    $BlobResultClean = $BlobResultRaw -replace '^\xEF\xBB\xBF', '' -replace '^ï»¿', ''
                                    
                                    [xml]$BlobResult = $BlobResultClean
                                    
                                    if ($BlobResult.EnumerationResults.Blobs.Blob) {
                                        $blobs = $BlobResult.EnumerationResults.Blobs.Blob
                                        
                                        # Handle single blob vs array
                                        if ($blobs -isnot [array]) {
                                            $blobs = @($blobs)
                                        }
                                        
                                        Write-Host "    [+] Found $($blobs.Count) blob(s)" -ForegroundColor Green
                                        
                                        # Display all blobs with index
                                        $blobList = @()
                                        for ($i = 0; $i -lt $blobs.Count; $i++) {
                                            $blob = $blobs[$i]
                                            $blobSize = $blob.Properties.'Content-Length'
                                            $blobUrl = "https://$($sa.StorageAccountName).blob.core.windows.net/$($container.Name)/$($blob.Name)"
                                            
                                            Write-Host "      [$i] $($blob.Name) ($blobSize bytes)" -ForegroundColor Gray
                                            
                                            $blobList += @{
                                                Index = $i
                                                Name = $blob.Name
                                                Size = $blobSize
                                                Url = $blobUrl
                                                Container = $container.Name
                                            }
                                        }
                                        
                                        # Prompt for download
                                        Write-Host "`n    [?] Download options:" -ForegroundColor Yellow
                                        Write-Host "      [A] Download all blobs" -ForegroundColor White
                                        Write-Host "      [S] Select specific blobs (comma-separated indexes, e.g., 0,2,4)" -ForegroundColor White
                                        Write-Host "      [N] Skip download" -ForegroundColor White
                                        
                                        $downloadChoice = Read-Host "`n    Select option"
                                        
                                        if ($downloadChoice -eq 'A' -or $downloadChoice -eq 'a') {
                                            # Download all blobs
                                            Write-Host "`n    [*] Downloading all blobs..." -ForegroundColor Yellow
                                            
                                            $downloadPath = Join-Path $env:USERPROFILE "Downloads\AzureBlobs\$($sa.StorageAccountName)\$($container.Name)"
                                            New-Item -ItemType Directory -Path $downloadPath -Force | Out-Null
                                            
                                            foreach ($blobItem in $blobList) {
                                                $downloadFile = Join-Path $downloadPath $blobItem.Name
                                                
                                                try {
                                                    Write-ExecutedCommand "Invoke-RestMethod -Uri `"$($blobItem.Url)`" -Method GET -Headers @{Authorization=`"Bearer `$StorageToken`"; `"x-ms-version`"=`"2017-11-09`"} -OutFile `"$downloadFile`""
                                                    
                                                    $downloadParams = @{
                                                        "URI" = $blobItem.Url
                                                        "Method" = "GET"
                                                        "Headers" = @{
                                                            "Authorization" = "Bearer $($Global:StorageToken)"
                                                            "x-ms-version" = "2017-11-09"
                                                        }
                                                        "OutFile" = $downloadFile
                                                    }
                                                    
                                                    Invoke-RestMethod @downloadParams -UseBasicParsing -ErrorAction Stop
                                                    Write-Host "      [+] Downloaded: $($blobItem.Name)" -ForegroundColor Green
                                                } catch {
                                                    Write-Host "      [-] Failed to download $($blobItem.Name): $_" -ForegroundColor Red
                                                }
                                            }
                                            
                                            Write-Host "`n    [+] Download complete! Files saved to: $downloadPath" -ForegroundColor Green
                                            
                                        } elseif ($downloadChoice -eq 'S' -or $downloadChoice -eq 's') {
                                            # Download specific blobs
                                            $indexes = Read-Host "    Enter blob indexes (comma-separated)"
                                            $selectedIndexes = $indexes -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }
                                            
                                            if ($selectedIndexes.Count -gt 0) {
                                                Write-Host "`n    [*] Downloading selected blobs..." -ForegroundColor Yellow
                                                
                                                $downloadPath = Join-Path $env:USERPROFILE "Downloads\AzureBlobs\$($sa.StorageAccountName)\$($container.Name)"
                                                New-Item -ItemType Directory -Path $downloadPath -Force | Out-Null
                                                
                                                foreach ($idx in $selectedIndexes) {
                                                    if ($idx -ge 0 -and $idx -lt $blobList.Count) {
                                                        $blobItem = $blobList[$idx]
                                                        $downloadFile = Join-Path $downloadPath $blobItem.Name
                                                        
                                                        try {
                                                            Write-ExecutedCommand "Invoke-RestMethod -Uri `"$($blobItem.Url)`" -Method GET -Headers @{Authorization=`"Bearer `$StorageToken`"; `"x-ms-version`"=`"2017-11-09`"} -OutFile `"$downloadFile`""
                                                            
                                                            $downloadParams = @{
                                                                "URI" = $blobItem.Url
                                                                "Method" = "GET"
                                                                "Headers" = @{
                                                                    "Authorization" = "Bearer $($Global:StorageToken)"
                                                                    "x-ms-version" = "2017-11-09"
                                                                }
                                                                "OutFile" = $downloadFile
                                                            }
                                                            
                                                            Invoke-RestMethod @downloadParams -UseBasicParsing -ErrorAction Stop
                                                            Write-Host "      [+] Downloaded: $($blobItem.Name)" -ForegroundColor Green
                                                        } catch {
                                                            Write-Host "      [-] Failed to download $($blobItem.Name): $_" -ForegroundColor Red
                                                        }
                                                    } else {
                                                        Write-Host "      [-] Invalid index: $idx" -ForegroundColor Red
                                                    }
                                                }
                                                
                                                Write-Host "`n    [+] Download complete! Files saved to: $downloadPath" -ForegroundColor Green
                                            } else {
                                                Write-Host "    [-] No valid indexes provided" -ForegroundColor Red
                                            }
                                        } else {
                                            Write-Host "    [*] Skipping download" -ForegroundColor Yellow
                                        }
                                        
                                    } else {
                                        Write-Host "    [-] No blobs found in container" -ForegroundColor Yellow
                                    }
                                } catch {
                                    Write-Host "    [-] Error enumerating blobs: $_" -ForegroundColor Red
                                }
                            }
                        } else {
                            Write-Host "[-] No containers found" -ForegroundColor Yellow
                        }
                    } catch {
                        Write-Host "[-] Error enumerating containers via REST API: $_" -ForegroundColor Red
                        Write-Host "[!] Falling back to PowerShell methods..." -ForegroundColor Yellow
                        
                        # Fallback to standard method
                        try {
                            $context = $sa.Context
                            Write-ExecutedCommand "Get-AzStorageContainer -Context `$context"
                            $containers = Get-AzStorageContainer -Context $context -ErrorAction Stop
                            
                            if ($containers) {
                                Write-Host "[+] Found $($containers.Count) container(s)" -ForegroundColor Green
                                foreach ($container in $containers) {
                                    Write-Host "`n  Container: $($container.Name)" -ForegroundColor Yellow
                                    Write-Host "    Public Access : $($container.PublicAccess)" -ForegroundColor White
                                    Write-Host "    Last Modified : $($container.LastModified)" -ForegroundColor White
                                }
                            }
                        } catch {
                            Write-Host "[-] Error with fallback method: $_" -ForegroundColor Red
                        }
                    }
                } else {
                    # Standard PowerShell method
                    try {
                        $context = $sa.Context
                        Write-ExecutedCommand "Get-AzStorageContainer -Context `$context"
                        $containers = Get-AzStorageContainer -Context $context -ErrorAction Stop
                        
                        if ($containers) {
                            Write-Host "[+] Found $($containers.Count) container(s)" -ForegroundColor Green
                            foreach ($container in $containers) {
                                Write-Host "`n  Container: $($container.Name)" -ForegroundColor Yellow
                                Write-Host "    Public Access : $($container.PublicAccess)" -ForegroundColor White
                                Write-Host "    Last Modified : $($container.LastModified)" -ForegroundColor White
                                
                                if ($container.PublicAccess -ne "Off" -and $container.PublicAccess -ne $null) {
                                    Write-Host "    [!] WARNING: Public access enabled!" -ForegroundColor Red
                                }
                                
                                # Enumerate blobs in container
                                try {
                                    Write-ExecutedCommand "Get-AzStorageBlob -Container $($container.Name) -Context `$context"
                                    $blobs = Get-AzStorageBlob -Container $container.Name -Context $context -ErrorAction Stop
                                    if ($blobs) {
                                        Write-Host "    Blobs: $($blobs.Count)" -ForegroundColor White
                                        
                                        # Display all blobs with index
                                        $blobList = @()
                                        for ($i = 0; $i -lt $blobs.Count; $i++) {
                                            $blob = $blobs[$i]
                                            Write-Host "      [$i] $($blob.Name) ($($blob.Length) bytes)" -ForegroundColor Gray
                                            
                                            $blobList += @{
                                                Index = $i
                                                Name = $blob.Name
                                                Size = $blob.Length
                                                BlobObject = $blob
                                                Container = $container.Name
                                            }
                                        }
                                        
                                        # Prompt for download
                                        Write-Host "`n    [?] Download options:" -ForegroundColor Yellow
                                        Write-Host "      [A] Download all blobs" -ForegroundColor White
                                        Write-Host "      [S] Select specific blobs (comma-separated indexes, e.g., 0,2,4)" -ForegroundColor White
                                        Write-Host "      [N] Skip download" -ForegroundColor White
                                        
                                        $downloadChoice = Read-Host "`n    Select option"
                                        
                                        if ($downloadChoice -eq 'A' -or $downloadChoice -eq 'a') {
                                            # Download all blobs
                                            Write-Host "`n    [*] Downloading all blobs..." -ForegroundColor Yellow
                                            
                                            $downloadPath = Join-Path $env:USERPROFILE "Downloads\AzureBlobs\$($sa.StorageAccountName)\$($container.Name)"
                                            New-Item -ItemType Directory -Path $downloadPath -Force | Out-Null
                                            
                                            foreach ($blobItem in $blobList) {
                                                $downloadFile = Join-Path $downloadPath $blobItem.Name
                                                
                                                try {
                                                    Write-ExecutedCommand "Get-AzStorageBlobContent -Container $($container.Name) -Blob $($blobItem.Name) -Destination `"$downloadFile`" -Context `$context -Force"
                                                    Get-AzStorageBlobContent -Container $container.Name -Blob $blobItem.Name -Destination $downloadFile -Context $context -Force -ErrorAction Stop | Out-Null
                                                    Write-Host "      [+] Downloaded: $($blobItem.Name)" -ForegroundColor Green
                                                } catch {
                                                    Write-Host "      [-] Failed to download $($blobItem.Name): $_" -ForegroundColor Red
                                                }
                                            }
                                            
                                            Write-Host "`n    [+] Download complete! Files saved to: $downloadPath" -ForegroundColor Green
                                            
                                        } elseif ($downloadChoice -eq 'S' -or $downloadChoice -eq 's') {
                                            # Download specific blobs
                                            $indexes = Read-Host "    Enter blob indexes (comma-separated)"
                                            $selectedIndexes = $indexes -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }
                                            
                                            if ($selectedIndexes.Count -gt 0) {
                                                Write-Host "`n    [*] Downloading selected blobs..." -ForegroundColor Yellow
                                                
                                                $downloadPath = Join-Path $env:USERPROFILE "Downloads\AzureBlobs\$($sa.StorageAccountName)\$($container.Name)"
                                                New-Item -ItemType Directory -Path $downloadPath -Force | Out-Null
                                                
                                                foreach ($idx in $selectedIndexes) {
                                                    if ($idx -ge 0 -and $idx -lt $blobList.Count) {
                                                        $blobItem = $blobList[$idx]
                                                        $downloadFile = Join-Path $downloadPath $blobItem.Name
                                                        
                                                        try {
                                                            Write-ExecutedCommand "Get-AzStorageBlobContent -Container $($container.Name) -Blob $($blobItem.Name) -Destination `"$downloadFile`" -Context `$context -Force"
                                                            Get-AzStorageBlobContent -Container $container.Name -Blob $blobItem.Name -Destination $downloadFile -Context $context -Force -ErrorAction Stop | Out-Null
                                                            Write-Host "      [+] Downloaded: $($blobItem.Name)" -ForegroundColor Green
                                                        } catch {
                                                            Write-Host "      [-] Failed to download $($blobItem.Name): $_" -ForegroundColor Red
                                                        }
                                                    } else {
                                                        Write-Host "      [-] Invalid index: $idx" -ForegroundColor Red
                                                    }
                                                }
                                                
                                                Write-Host "`n    [+] Download complete! Files saved to: $downloadPath" -ForegroundColor Green
                                            } else {
                                                Write-Host "    [-] No valid indexes provided" -ForegroundColor Red
                                            }
                                        } else {
                                            Write-Host "    [*] Skipping download" -ForegroundColor Yellow
                                        }
                                    }
                                } catch {
                                    Write-Host "    [-] Cannot list blobs" -ForegroundColor Red
                                }
                            }
                        } else {
                            Write-Host "[-] No containers found" -ForegroundColor Red
                        }
                    } catch {
                        Write-Host "[-] Error enumerating containers: $_" -ForegroundColor Red
                    }
                }
                
                # Enumerate file shares
                Write-Host "`n[*] Enumerating file shares..." -ForegroundColor Yellow
                try {
                    $context = $sa.Context
                    Write-ExecutedCommand "Get-AzStorageShare -Context `$context"
                    $shares = Get-AzStorageShare -Context $context -ErrorAction Stop
                    
                    if ($shares) {
                        Write-Host "[+] Found $($shares.Count) file share(s)" -ForegroundColor Green
                        foreach ($share in $shares) {
                            Write-Host "`n  Share: $($share.Name)" -ForegroundColor Yellow
                            Write-Host "    Quota (GiB)   : $($share.QuotaGiB)" -ForegroundColor White
                            Write-Host "    Last Modified : $($share.LastModified)" -ForegroundColor White
                        }
                    } else {
                        Write-Host "[-] No file shares found" -ForegroundColor Red
                    }
                } catch {
                    Write-Host "[-] Error enumerating file shares: $_" -ForegroundColor Red
                }
                
                # Enumerate tables
                Write-Host "`n[*] Enumerating tables..." -ForegroundColor Yellow
                try {
                    $context = $sa.Context
                    Write-ExecutedCommand "Get-AzStorageTable -Context `$context"
                    $tables = Get-AzStorageTable -Context $context -ErrorAction Stop
                    
                    if ($tables) {
                        Write-Host "[+] Found $($tables.Count) table(s)" -ForegroundColor Green
                        $tables | Format-Table Name -AutoSize
                    } else {
                        Write-Host "[-] No tables found" -ForegroundColor Red
                    }
                } catch {
                    Write-Host "[-] Error enumerating tables: $_" -ForegroundColor Red
                }
                
                # Enumerate queues
                Write-Host "`n[*] Enumerating queues..." -ForegroundColor Yellow
                try {
                    $context = $sa.Context
                    Write-ExecutedCommand "Get-AzStorageQueue -Context `$context"
                    $queues = Get-AzStorageQueue -Context $context -ErrorAction Stop
                    
                    if ($queues) {
                        Write-Host "[+] Found $($queues.Count) queue(s)" -ForegroundColor Green
                        $queues | Format-Table Name -AutoSize
                    } else {
                        Write-Host "[-] No queues found" -ForegroundColor Red
                    }
                } catch {
                    Write-Host "[-] Error enumerating queues: $_" -ForegroundColor Red
                }
            }
        } else {
            Write-Host "[-] No storage accounts found" -ForegroundColor Red
        }
    } catch {
        Write-Host "[-] Error retrieving storage accounts: $_" -ForegroundColor Red
    }
    
    Write-Host "`n[*] Press any key to return to main menu..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Helper function to display executed commands
function Write-ExecutedCommand {
    param(
        [string]$Command
    )
    Write-Host "`n[CMD] " -ForegroundColor Magenta -NoNewline
    Write-Host $Command -ForegroundColor Gray
}

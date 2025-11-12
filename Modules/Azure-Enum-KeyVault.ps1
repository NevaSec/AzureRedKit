# Key Vault deep dive enumeration module

function Invoke-KeyVaultDeepDive {
    Write-Host "`n`n=== KEY VAULT DEEP DIVE ===" -ForegroundColor Cyan
    
    if (@($Global:KeyVaults).Count -eq 0) {
        Write-Host "[-] No Key Vaults available" -ForegroundColor Red
        return
    }
    
    if ([string]::IsNullOrWhiteSpace($Global:KeyVaultToken)) {
        Write-Host "[!] KeyVaultAccessToken not provided during initial connection." -ForegroundColor Yellow
        Write-Host "[!] Secret enumeration will be limited or may fail." -ForegroundColor Yellow
    }
    
    foreach ($kv in $Global:KeyVaults) {
        Write-Host "`n--- Key Vault: $($kv.Name) ---" -ForegroundColor Cyan
        Write-Host "  Resource Group : $($kv.ResourceGroupName)" -ForegroundColor White
        Write-Host "  Location       : $($kv.Location)" -ForegroundColor White
        
        # Enumerate secrets
        Write-Host "`n[*] Enumerating secrets in $($kv.Name)..." -ForegroundColor Yellow
        try {
            Write-ExecutedCommand "Get-AzKeyVaultSecret -VaultName $($kv.Name)"
            $secrets = Get-AzKeyVaultSecret -VaultName $kv.Name -ErrorAction Stop
            
            if ($secrets) {
                Write-Host "[+] Found $($secrets.Count) secret(s)" -ForegroundColor Green
                
                foreach ($secret in $secrets) {
                    Write-Host "`n  Secret: $($secret.Name)" -ForegroundColor Yellow
                    Write-Host "    Enabled    : $($secret.Enabled)" -ForegroundColor White
                    Write-Host "    Created    : $($secret.Created)" -ForegroundColor White
                    Write-Host "    Updated    : $($secret.Updated)" -ForegroundColor White
                    
                    # Attempt to retrieve secret value
                    Write-Host "`n    [*] Retrieving secret value..." -ForegroundColor Yellow
                    try {
                        Write-ExecutedCommand "Get-AzKeyVaultSecret -VaultName $($kv.Name) -Name $($secret.Name) -AsPlainText"
                        $secretValue = Get-AzKeyVaultSecret -VaultName $kv.Name -Name $secret.Name -AsPlainText -ErrorAction Stop
                        Write-Host "    [+] Secret Value:" -ForegroundColor Green
                        Write-Host "    $secretValue" -ForegroundColor Red
                    } catch {
                        Write-Host "    [-] Failed to retrieve secret value: $_" -ForegroundColor Red
                    }
                }
            } else {
                Write-Host "[-] No secrets found in $($kv.Name)" -ForegroundColor Red
            }
        } catch {
            Write-Host "[-] Error enumerating secrets: $_" -ForegroundColor Red
        }
        
        # Enumerate keys
        Write-Host "`n[*] Enumerating keys in $($kv.Name)..." -ForegroundColor Yellow
        try {
            Write-ExecutedCommand "Get-AzKeyVaultKey -VaultName $($kv.Name)"
            $keys = Get-AzKeyVaultKey -VaultName $kv.Name -ErrorAction Stop
            
            if ($keys) {
                Write-Host "[+] Found $($keys.Count) key(s)" -ForegroundColor Green
                $keys | Format-Table Name, Enabled, Created, Updated -AutoSize
            } else {
                Write-Host "[-] No keys found in $($kv.Name)" -ForegroundColor Red
            }
        } catch {
            Write-Host "[-] Error enumerating keys: $_" -ForegroundColor Red
        }
        
        # Enumerate certificates
        Write-Host "`n[*] Enumerating certificates in $($kv.Name)..." -ForegroundColor Yellow
        try {
            Write-ExecutedCommand "Get-AzKeyVaultCertificate -VaultName $($kv.Name)"
            $certificates = Get-AzKeyVaultCertificate -VaultName $kv.Name -ErrorAction Stop
            
            if ($certificates) {
                Write-Host "[+] Found $($certificates.Count) certificate(s)" -ForegroundColor Green
                $certificates | Format-Table Name, Enabled, Created, Updated -AutoSize
            } else {
                Write-Host "[-] No certificates found in $($kv.Name)" -ForegroundColor Red
            }
        } catch {
            Write-Host "[-] Error enumerating certificates: $_" -ForegroundColor Red
        }
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

# AzureRedKit - Main enumeration and exploitation script
# Author: NevaSec
# Description: Modular script for Azure enumeration and exploitation

Write-Host "`n=== AzureRedKit - Enumeration & Exploitation Framework ===`n" -ForegroundColor Cyan

# Global variables
$Global:AzContext = $null
$Global:MgContext = $null
$Global:AccessToken = $null
$Global:GraphToken = $null
$Global:KeyVaultToken = $null
$Global:StorageToken = $null
$Global:AccountId = $null

# Enumeration results
$Global:Resources = $null
$Global:VirtualMachines = @()
$Global:AutomationAccounts = @()
$Global:KeyVaults = @()
$Global:StorageAccounts = @()
$Global:VMExtensions = @()

# Helper function to display executed commands
function Write-ExecutedCommand {
    param(
        [string]$Command
    )
    Write-Host "`n[CMD] " -ForegroundColor Magenta -NoNewline
    Write-Host $Command -ForegroundColor Gray
}

# Function to check for existing session
function Test-ExistingSession {
    Write-Host "`n[*] Checking for existing Azure session..." -ForegroundColor Yellow
    
    $hasAzSession = $false
    $hasMgSession = $false
    
    # Check Azure PowerShell session
    try {
        Write-ExecutedCommand "Get-AzContext"
        $azCtx = Get-AzContext -ErrorAction Stop
        if ($azCtx) {
            $hasAzSession = $true
            Write-Host "`n[+] Existing Azure PowerShell session found:" -ForegroundColor Green
            Write-Host "  Subscription : $($azCtx.Subscription.Name)" -ForegroundColor White
            Write-Host "  Account      : $($azCtx.Account.Id)" -ForegroundColor White
            Write-Host "  Tenant       : $($azCtx.Tenant.Id)" -ForegroundColor White
        }
    } catch {
        # No Azure session
    }
    
    # Check Microsoft Graph session
    try {
        Write-ExecutedCommand "Get-MgContext"
        $mgCtx = Get-MgContext -ErrorAction Stop
        if ($mgCtx) {
            $hasMgSession = $true
            Write-Host "`n[+] Existing Microsoft Graph session found:" -ForegroundColor Green
            Write-Host "  ClientId     : $($mgCtx.ClientId)" -ForegroundColor White
            Write-Host "  TenantId     : $($mgCtx.TenantId)" -ForegroundColor White
            Write-Host "  Scopes       : $($mgCtx.Scopes -join ', ')" -ForegroundColor White
        }
    } catch {
        # No Graph session
    }
    
    if ($hasAzSession -or $hasMgSession) {
        Write-Host "`n[?] Do you want to use the existing session? (y/n): " -ForegroundColor Yellow -NoNewline
        $response = Read-Host
        
        if ($response -eq 'y' -or $response -eq 'Y') {
            Write-Host "[+] Using existing session" -ForegroundColor Green
            
            # Save contexts
            if ($hasAzSession) {
                $Global:AzContext = Get-AzContext
            }
            if ($hasMgSession) {
                $Global:MgContext = Get-MgContext
            }
            
            return $true
        } else {
            Write-Host "[*] Disconnecting existing sessions..." -ForegroundColor Yellow
            
            if ($hasAzSession) {
                try {
                    Write-ExecutedCommand "Disconnect-AzAccount"
                    Disconnect-AzAccount -ErrorAction SilentlyContinue | Out-Null
                    Write-Host "[+] Disconnected from Azure PowerShell" -ForegroundColor Green
                } catch {
                    # Silent
                }
            }
            
            if ($hasMgSession) {
                try {
                    Write-ExecutedCommand "Disconnect-MgGraph"
                    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
                    Write-Host "[+] Disconnected from Microsoft Graph" -ForegroundColor Green
                } catch {
                    # Silent
                }
            }
            
            return $false
        }
    }
    
    Write-Host "[-] No existing session found" -ForegroundColor Yellow
    return $false
}

# Connection function
function Connect-AzureEnvironment {
    Write-Host "`n=== Azure Authentication ===`n" -ForegroundColor Cyan
    
    $Global:AccessToken = Read-Host -Prompt "Enter AccessToken"
    $Global:GraphToken = Read-Host -Prompt "Enter GraphToken (leave empty to skip)"
    $Global:KeyVaultToken = Read-Host -Prompt "Enter KeyVaultAccessToken (leave empty to skip)"
    $Global:StorageToken = Read-Host -Prompt "Enter StorageAccessToken (leave empty to skip)"
    $Global:AccountId = Read-Host -Prompt "Enter AccountId"
    
    Write-Host "`n[*] Connecting to Azure..." -ForegroundColor Yellow
    try {
        if ([string]::IsNullOrWhiteSpace($Global:GraphToken) -and [string]::IsNullOrWhiteSpace($Global:KeyVaultToken)) {
            Write-ExecutedCommand "Connect-AzAccount -AccessToken `$AccessToken -AccountId `$AccountId"
            Connect-AzAccount -AccessToken $Global:AccessToken -AccountId $Global:AccountId -ErrorAction Stop | Out-Null
        } elseif ([string]::IsNullOrWhiteSpace($Global:GraphToken)) {
            Write-ExecutedCommand "Connect-AzAccount -AccessToken `$AccessToken -KeyVaultAccessToken `$KeyVaultToken -AccountId `$AccountId"
            Connect-AzAccount -AccessToken $Global:AccessToken -KeyVaultAccessToken $Global:KeyVaultToken -AccountId $Global:AccountId -ErrorAction Stop | Out-Null
        } elseif ([string]::IsNullOrWhiteSpace($Global:KeyVaultToken)) {
            Write-ExecutedCommand "Connect-AzAccount -AccessToken `$AccessToken -MicrosoftGraphAccessToken `$GraphToken -AccountId `$AccountId"
            Connect-AzAccount -AccessToken $Global:AccessToken -MicrosoftGraphAccessToken $Global:GraphToken -AccountId $Global:AccountId -ErrorAction Stop | Out-Null
        } else {
            Write-ExecutedCommand "Connect-AzAccount -AccessToken `$AccessToken -MicrosoftGraphAccessToken `$GraphToken -KeyVaultAccessToken `$KeyVaultToken -AccountId `$AccountId"
            Connect-AzAccount -AccessToken $Global:AccessToken -MicrosoftGraphAccessToken $Global:GraphToken -KeyVaultAccessToken $Global:KeyVaultToken -AccountId $Global:AccountId -ErrorAction Stop | Out-Null
        }
        
        Write-ExecutedCommand "Get-AzContext"
        $Global:AzContext = Get-AzContext
        Write-Host "[+] Successfully connected to Azure" -ForegroundColor Green
        Write-Host "  Subscription : $($Global:AzContext.Subscription.Name)" -ForegroundColor White
        Write-Host "  Account      : $($Global:AzContext.Account.Id)" -ForegroundColor White
        Write-Host "  Tenant       : $($Global:AzContext.Tenant.Id)" -ForegroundColor White
        
        if (-not [string]::IsNullOrWhiteSpace($Global:GraphToken)) {
            try {
                Write-ExecutedCommand "Connect-MgGraph -AccessToken (ConvertTo-SecureString -AsPlainText -Force)"
                Connect-MgGraph -AccessToken ($Global:GraphToken | ConvertTo-SecureString -AsPlainText -Force) -NoWelcome -ErrorAction Stop
                
                Write-ExecutedCommand "Get-MgContext"
                $Global:MgContext = Get-MgContext
                Write-Host "[+] Successfully connected to Microsoft Graph" -ForegroundColor Green
            } catch {
                Write-Host "[-] Failed to connect to Microsoft Graph" -ForegroundColor Red
            }
        }
        
        # Display if StorageToken provided
        if (-not [string]::IsNullOrWhiteSpace($Global:StorageToken)) {
            Write-Host "[+] Storage Access Token provided" -ForegroundColor Green
        }
        
        return $true
    } catch {
        Write-Host "[-] Failed to connect to Azure: $_" -ForegroundColor Red
        return $false
    }
}

# Full enumeration function
function Invoke-FullEnumeration {
    Write-Host "`n[*] Starting full enumeration..." -ForegroundColor Yellow
    
    $modulePath = Join-Path $PSScriptRoot "Modules\Azure-Enum-Core.ps1"
    if (Test-Path $modulePath) {
        . $modulePath
        Invoke-CoreEnumeration
    } else {
        Write-Host "[-] Module not found: $modulePath" -ForegroundColor Red
    }
}

# Main menu
function Show-MainMenu {
    while ($true) {
        Write-Host "`n`n=== MAIN MENU ===" -ForegroundColor Cyan
        Write-Host "[1] Run Full Enumeration" -ForegroundColor White
        Write-Host "[2] Exploit Automation Account" -ForegroundColor Yellow
        Write-Host "[3] Exploit VM Extension" -ForegroundColor Yellow
        Write-Host "[4] Deep Dive - Key Vaults" -ForegroundColor White
        Write-Host "[5] Deep Dive - Storage Accounts" -ForegroundColor White
        Write-Host "[6] Show Current Context" -ForegroundColor White
        Write-Host "[0] Exit" -ForegroundColor Red
        
        $choice = Read-Host "`nSelect option"
        
        switch ($choice) {
            "1" {
                Invoke-FullEnumeration
            }
            "2" {
                if (@($Global:AutomationAccounts).Count -eq 0) {
                    Write-Host "`n[-] No Automation Accounts found. Run enumeration first." -ForegroundColor Red
                } else {
                    $modulePath = Join-Path $PSScriptRoot "Modules\Azure-Exploit-Automation.ps1"
                    if (Test-Path $modulePath) {
                        . $modulePath
                        Invoke-AutomationExploit
                    } else {
                        Write-Host "[-] Module not found: $modulePath" -ForegroundColor Red
                    }
                }
            }
            "3" {
                if (@($Global:VirtualMachines).Count -eq 0) {
                    Write-Host "`n[-] No Virtual Machines found. Run enumeration first." -ForegroundColor Red
                } else {
                    $modulePath = Join-Path $PSScriptRoot "Modules\Azure-Exploit-VMExtension.ps1"
                    if (Test-Path $modulePath) {
                        . $modulePath
                        Invoke-VMExtensionExploit
                    } else {
                        Write-Host "[-] Module not found: $modulePath" -ForegroundColor Red
                    }
                }
            }
            "4" {
                if (@($Global:KeyVaults).Count -eq 0) {
                    Write-Host "`n[-] No Key Vaults found. Run enumeration first." -ForegroundColor Red
                } else {
                    $modulePath = Join-Path $PSScriptRoot "Modules\Azure-Enum-KeyVault.ps1"
                    if (Test-Path $modulePath) {
                        . $modulePath
                        Invoke-KeyVaultDeepDive
                    } else {
                        Write-Host "[-] Module not found: $modulePath" -ForegroundColor Red
                    }
                }
            }
            "5" {
                if (@($Global:StorageAccounts).Count -eq 0) {
                    Write-Host "`n[-] No Storage Accounts found. Run enumeration first." -ForegroundColor Red
                } else {
                    $modulePath = Join-Path $PSScriptRoot "Modules\Azure-Enum-Storage.ps1"
                    if (Test-Path $modulePath) {
                        . $modulePath
                        Invoke-StorageDeepDive
                    } else {
                        Write-Host "[-] Module not found: $modulePath" -ForegroundColor Red
                    }
                }
            }
            "6" {
                Write-Host "`n=== Current Context ===" -ForegroundColor Cyan
                if ($Global:AzContext) {
                    Write-Host "Azure Context:" -ForegroundColor Yellow
                    Write-Host "  Subscription : $($Global:AzContext.Subscription.Name)" -ForegroundColor White
                    Write-Host "  Account      : $($Global:AzContext.Account.Id)" -ForegroundColor White
                    Write-Host "  Tenant       : $($Global:AzContext.Tenant.Id)" -ForegroundColor White
                }
                if ($Global:MgContext) {
                    Write-Host "`nMicrosoft Graph Context:" -ForegroundColor Yellow
                    Write-Host "  ClientId     : $($Global:MgContext.ClientId)" -ForegroundColor White
                    Write-Host "  TenantId     : $($Global:MgContext.TenantId)" -ForegroundColor White
                }
                Write-Host "`nTokens Status:" -ForegroundColor Yellow
                Write-Host "  KeyVault Token : $(if ([string]::IsNullOrWhiteSpace($Global:KeyVaultToken)) { 'Not provided' } else { 'Provided' })" -ForegroundColor White
                Write-Host "  Storage Token  : $(if ([string]::IsNullOrWhiteSpace($Global:StorageToken)) { 'Not provided' } else { 'Provided' })" -ForegroundColor White
                Write-Host "`nEnumeration Results:" -ForegroundColor Yellow
                Write-Host "  Virtual Machines    : $(@($Global:VirtualMachines).Count)" -ForegroundColor White
                Write-Host "  Automation Accounts : $(@($Global:AutomationAccounts).Count)" -ForegroundColor White
                Write-Host "  Key Vaults          : $(@($Global:KeyVaults).Count)" -ForegroundColor White
                Write-Host "  Storage Accounts    : $(@($Global:StorageAccounts).Count)" -ForegroundColor White
                Write-Host "  VM Extensions       : $(@($Global:VMExtensions).Count)" -ForegroundColor White
            }
            "0" {
                Write-Host "`n[*] Exiting..." -ForegroundColor Yellow
                return
            }
            default {
                Write-Host "`n[-] Invalid option. Please try again." -ForegroundColor Red
            }
        }
    }
}

# Main entry point
$useExistingSession = Test-ExistingSession

if ($useExistingSession) {
    Show-MainMenu
} else {
    if (Connect-AzureEnvironment) {
        Show-MainMenu
    } else {
        Write-Host "`n[-] Failed to authenticate. Exiting..." -ForegroundColor Red
    }
}

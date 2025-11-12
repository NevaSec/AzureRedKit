# Core enumeration module

function Invoke-CoreEnumeration {
    Write-Host "`n`n=== FULL AZURE ENUMERATION ===" -ForegroundColor Cyan
    
    # Check if subscription is available
    $hasSubscription = $false
    try {
        Write-ExecutedCommand "Get-AzContext"
        $currentContext = Get-AzContext -ErrorAction Stop
        if ($currentContext.Subscription.Id) {
            $hasSubscription = $true
            Write-Host "[+] Subscription detected: $($currentContext.Subscription.Name)" -ForegroundColor Green
        } else {
            Write-Host "[!] No subscription found in current context" -ForegroundColor Yellow
            Write-Host "[!] Some enumeration features will be limited" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "[!] Could not determine subscription status" -ForegroundColor Yellow
    }
    
    # Enumerate Azure Resources (requires subscription)
    if ($hasSubscription) {
        Write-Host "`n`n=== Azure Resources ===" -ForegroundColor Cyan
        try {
            Write-ExecutedCommand "Get-AzResource"
            $Global:Resources = Get-AzResource -ErrorAction Stop
            
            if ($Global:Resources) {
                # Display all resources in table format
                $Global:Resources | Format-Table Name, ResourceType, Location, ResourceGroupName -AutoSize
                
                Write-Host "[+] Found $($Global:Resources.Count) resource(s)" -ForegroundColor Green
                
                # Extract specific resource types for later use
                $Global:VirtualMachines = $Global:Resources | Where-Object { $_.ResourceType -eq "Microsoft.Compute/virtualMachines" }
                $Global:AutomationAccounts = $Global:Resources | Where-Object { $_.ResourceType -eq "Microsoft.Automation/automationAccounts" }
                $Global:KeyVaults = $Global:Resources | Where-Object { $_.ResourceType -eq "Microsoft.KeyVault/vaults" }
                $Global:StorageAccounts = $Global:Resources | Where-Object { $_.ResourceType -eq "Microsoft.Storage/storageAccounts" }
                $Global:VMExtensions = $Global:Resources | Where-Object { $_.ResourceType -eq "Microsoft.Compute/virtualMachines/extensions" }
                
                # Display count of key resources
                if (@($Global:VirtualMachines).Count -gt 0) {
                    Write-Host "[!] Found $(@($Global:VirtualMachines).Count) Virtual Machine(s)" -ForegroundColor Red
                }
                if (@($Global:AutomationAccounts).Count -gt 0) {
                    Write-Host "[!] Found $(@($Global:AutomationAccounts).Count) Automation Account(s)" -ForegroundColor Red
                }
                if (@($Global:KeyVaults).Count -gt 0) {
                    Write-Host "[!] Found $(@($Global:KeyVaults).Count) Key Vault(s)" -ForegroundColor Red
                }
                if (@($Global:StorageAccounts).Count -gt 0) {
                    Write-Host "[!] Found $(@($Global:StorageAccounts).Count) Storage Account(s)" -ForegroundColor Red
                }
                if (@($Global:VMExtensions).Count -gt 0) {
                    Write-Host "[!] Found $(@($Global:VMExtensions).Count) VM Extension(s)" -ForegroundColor Red
                }
            } else {
                Write-Host "[-] No resources found" -ForegroundColor Red
            }
        } catch {
            Write-Host "[-] Error retrieving resources: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "`n`n=== Azure Resources ===" -ForegroundColor Cyan
        Write-Host "[!] Skipped - Requires subscription context" -ForegroundColor Yellow
        
        # Initialize empty arrays
        $Global:Resources = @()
        $Global:VirtualMachines = @()
        $Global:AutomationAccounts = @()
        $Global:KeyVaults = @()
        $Global:StorageAccounts = @()
        $Global:VMExtensions = @()
    }
    
    # Enumerate Role Assignments (requires subscription)
    if ($hasSubscription) {
        Write-Host "`n`n=== Azure Role Assignments ===" -ForegroundColor Cyan
        try {
            Write-ExecutedCommand "Get-AzRoleAssignment"
            $roleAssignments = Get-AzRoleAssignment -ErrorAction Stop
            
            if ($roleAssignments) {
                # Display all role assignments in table format
                $roleAssignments | Format-Table DisplayName, RoleDefinitionName, Scope -AutoSize
                
                Write-Host "[+] Found $($roleAssignments.Count) role assignment(s)" -ForegroundColor Green
            } else {
                Write-Host "[-] No role assignments found" -ForegroundColor Red
            }
        } catch {
            Write-Host "[-] Error retrieving role assignments: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "`n`n=== Azure Role Assignments ===" -ForegroundColor Cyan
        Write-Host "[!] Skipped - Requires subscription context" -ForegroundColor Yellow
    }
    
    # Enumerate Resource Groups (requires subscription)
    if ($hasSubscription) {
        Write-Host "`n`n=== Azure Resource Groups ===" -ForegroundColor Cyan
        try {
            Write-ExecutedCommand "Get-AzResourceGroup"
            $resourceGroups = Get-AzResourceGroup -ErrorAction Stop
            if ($resourceGroups) {
                $resourceGroups | Format-Table ResourceGroupName, Location, ProvisioningState -AutoSize
                Write-Host "[+] Found $($resourceGroups.Count) resource group(s)" -ForegroundColor Green
            } else {
                Write-Host "[-] No resource groups found" -ForegroundColor Red
            }
        } catch {
            Write-Host "[-] Error retrieving resource groups: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "`n`n=== Azure Resource Groups ===" -ForegroundColor Cyan
        Write-Host "[!] Skipped - Requires subscription context" -ForegroundColor Yellow
    }
    
    # Enumerate Azure AD Applications (does NOT require subscription)
    Write-Host "`n`n=== Azure AD Applications ===" -ForegroundColor Cyan
    try {
        Write-ExecutedCommand "Get-AzADApplication"
        $applications = Get-AzADApplication -ErrorAction Stop
        
        if ($applications) {
            Write-Host "[+] Found $($applications.Count) application(s)" -ForegroundColor Green
            $applications | Format-Table DisplayName, AppId, Id -AutoSize
        } else {
            Write-Host "[-] No applications found or no permissions" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "[-] Error retrieving applications: $_" -ForegroundColor Red
    }
    
    # Enumerate Automation Accounts with Hybrid Worker Groups (requires subscription)
    if ($hasSubscription -and @($Global:AutomationAccounts).Count -gt 0) {
        Write-Host "`n`n=== Automation Accounts - Hybrid Worker Groups ===" -ForegroundColor Cyan
        
        foreach ($automationAccount in $Global:AutomationAccounts) {
            Write-Host "`n[*] Checking Automation Account: $($automationAccount.Name)" -ForegroundColor Yellow
            
            try {
                Write-ExecutedCommand "Get-AzAutomationHybridWorkerGroup -AutomationAccountName $($automationAccount.Name) -ResourceGroupName $($automationAccount.ResourceGroupName)"
                $workerGroups = Get-AzAutomationHybridWorkerGroup -AutomationAccountName $automationAccount.Name -ResourceGroupName $automationAccount.ResourceGroupName -ErrorAction Stop
                
                if ($workerGroups) {
                    Write-Host "[+] Found $($workerGroups.Count) Hybrid Worker Group(s)" -ForegroundColor Green
                    $workerGroups | Format-Table Name, GroupType -AutoSize
                } else {
                    Write-Host "[-] No Hybrid Worker Groups found" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "[-] Error retrieving Hybrid Worker Groups: $_" -ForegroundColor Red
            }
        }
    }
    
    # Try to enumerate using Microsoft Graph (if connected)
    if ($Global:MgContext) {
        Write-Host "`n`n=== Microsoft Graph Enumeration ===" -ForegroundColor Cyan
        
        # Enumerate users
        Write-Host "`n[*] Enumerating users..." -ForegroundColor Yellow
        try {
            Write-ExecutedCommand "Get-MgUser -All"
            $users = Get-MgUser -All -ErrorAction Stop
            if ($users) {
                Write-Host "[+] Found $($users.Count) user(s)" -ForegroundColor Green
                $users | Select-Object -First 10 | Format-Table DisplayName, UserPrincipalName, Id -AutoSize
                if ($users.Count -gt 10) {
                    Write-Host "... and $($users.Count - 10) more users" -ForegroundColor Gray
                }
            }
        } catch {
            Write-Host "[-] Error retrieving users: $_" -ForegroundColor Red
        }
        
        # Enumerate groups
        Write-Host "`n[*] Enumerating groups..." -ForegroundColor Yellow
        try {
            Write-ExecutedCommand "Get-MgGroup -All"
            $groups = Get-MgGroup -All -ErrorAction Stop
            if ($groups) {
                Write-Host "[+] Found $($groups.Count) group(s)" -ForegroundColor Green
                $groups | Select-Object -First 10 | Format-Table DisplayName, Id -AutoSize
                if ($groups.Count -gt 10) {
                    Write-Host "... and $($groups.Count - 10) more groups" -ForegroundColor Gray
                }
            }
        } catch {
            Write-Host "[-] Error retrieving groups: $_" -ForegroundColor Red
        }
        
        # Enumerate service principals
        Write-Host "`n[*] Enumerating service principals..." -ForegroundColor Yellow
        try {
            Write-ExecutedCommand "Get-MgServicePrincipal -All"
            $servicePrincipals = Get-MgServicePrincipal -All -ErrorAction Stop
            if ($servicePrincipals) {
                Write-Host "[+] Found $($servicePrincipals.Count) service principal(s)" -ForegroundColor Green
                $servicePrincipals | Select-Object -First 10 | Format-Table DisplayName, AppId, Id -AutoSize
                if ($servicePrincipals.Count -gt 10) {
                    Write-Host "... and $($servicePrincipals.Count - 10) more service principals" -ForegroundColor Gray
                }
            }
        } catch {
            Write-Host "[-] Error retrieving service principals: $_" -ForegroundColor Red
        }
    }
    
    Write-Host "`n[*] Enumeration complete!" -ForegroundColor Green
    Write-Host "[*] Press any key to return to main menu..." -ForegroundColor Yellow
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

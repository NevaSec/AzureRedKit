# AzureRedKit

**AzureRedKit** is a PowerShell-based enumeration and exploitation framework for Azure and Azure AD environments. It streamlines common offensive security workflows by automating reconnaissance, resource enumeration, and classic exploitation techniques.

## 🎯 Purpose

AzureRedKit is primarily designed for:
- **CTF** - Quickly enumerate and exploit Azure resources
- **Training & Certification** - Ideal for courses like CARTP (Certified Azure Red Team Professional)
- **Lab environments** - Practice Azure offensive techniques in controlled settings

While it can be used in penetration testing engagements, **this is not an OPSEC-safe tool**. It prioritizes speed and automation over stealth, making it perfect for time-limited exams and training scenarios where you need to move fast.

> ⚠️ **Disclaimer**: AzureRedKit is designed for educational purposes and authorized security assessments only. Always ensure you have proper authorization before testing any Azure environment.

## ✨ Features

### 🔍 **Enumeration Modules**

#### **1. Core Azure Enumeration**
Comprehensive enumeration of Azure resources including:
- Azure resources (VMs, Automation Accounts, Key Vaults, Storage Accounts)
- Role assignments and permissions (RBAC)
- and more...

#### **2. Key Vault Deep Dive**
In-depth enumeration of Azure Key Vaults:
- Lists all secrets, keys, and certificates
- Attempts to retrieve secret values (requires appropriate permissions)

#### **3. Storage Account Deep Dive**
Advanced Storage Account enumeration with dual-mode support:
- **REST API mode** (with Storage Token): Direct API calls for maximum compatibility
- **PowerShell mode** (standard): Uses Az.Storage cmdlets
- Enumerates blob containers, file shares, tables, and queues
- **Interactive blob download** - Select and download specific blobs or entire containers

### ⚡ **Exploitation Modules**

#### **4. Automation Account Exploitation**
Automated exploitation of Azure Automation Accounts via Hybrid Worker Groups:
- **Pre-flight checks**: Validates XAMPP, Invoke-PowerShellTcp.ps1, netcat availability
- **Automated runbook creation**: Generates PowerShell reverse shell payloads
- **One-click exploitation**: Imports, publishes, and executes malicious runbooks

#### **5. VM Extension Exploitation**
Abuse VM extensions to gain local admin access:
- **Extension enumeration**: Lists existing VM extensions and their configurations
- **Local admin creation**: Deploys CustomScriptExtension to create privileged users
- **RDP info extraction**: Automatically retrieves public IP for RDP access

### 🛠️ **Core Features**

- **Command logging**: Every PowerShell command executed is displayed in magenta `[CMD]` blocks
- **Session detection**: Automatically detects and reuses existing Azure/Graph sessions
- **Token-based auth**: Supports AccessToken, GraphToken, KeyVaultToken, StorageToken

## 📥 Installation

1. **Download the repository**
```powershell
   # Clone via Git
   git clone https://github.com/NevaSec/AzureRedKit.git
   cd AzureRedKit
   
   # OR download ZIP from GitHub
   # Extract to your preferred location
```

2. **Unblock the files** (if downloaded as ZIP)
```powershell
   # Unblock the entire directory
   Get-ChildItem -Path . -Recurse | Unblock-File
```

3. **Verify structure**
```
   AzureRedKit/
   ├── Invoke-AzureRedKit.ps1
   └── Modules/
       ├── Azure-Enum-Core.ps1
       ├── Azure-Enum-KeyVault.ps1
       ├── Azure-Enum-Storage.ps1
       ├── Azure-Exploit-Automation.ps1
       └── Azure-Exploit-VMExtension.ps1
```

## 🚀 Usage

### **Launch AzureRedKit**

1. **Navigate to the folder**
```powershell
   cd C:\Path\To\AzureRedKit
```

2. **Run with execution policy bypass**
```powershell
   powershell -ExecutionPolicy Bypass
```

3. **Launch the main script**
```powershell
   .\Invoke-AzureRedKit.ps1
```

### **Authentication Options**

#### **Option 1: Token-based authentication** (recommended for exams/CTFs)
The script will prompt for:
- `AccessToken` (required)
- `GraphToken` (optional - for Microsoft Graph enumeration)
- `KeyVaultAccessToken` (optional - for Key Vault secret retrieval)
- `StorageAccessToken` (optional - for REST API-based storage enumeration)
- `AccountId` (required - typically the Application/Service Principal ID)

#### **Option 2: Pre-authenticated session**
If you already have an active Azure session, AzureRedKit can detect and reuse it:
```powershell
# Connect manually first
Connect-AzAccount -AccessToken $AccessToken -AccountId $AppId

# OR for user authentication
Connect-AzAccount

# Then launch AzureRedKit
.\Invoke-AzureRedKit.ps1
# Select "y" to use existing session
```

### **Main Menu Overview**
```
=== MAIN MENU ===
[1] Run Full Enumeration           - Complete Azure resource discovery
[2] Exploit Automation Account     - Reverse shell via Hybrid Workers
[3] Exploit VM Extension           - Create local admin on target VMs
[4] Deep Dive - Key Vaults         - Extract secrets, keys, certificates
[5] Deep Dive - Storage Accounts   - Enumerate and download blobs
[6] Show Current Context           - Display tokens and enumeration results
[0] Exit
```

## 📝 Command Logging

AzureRedKit displays every executed PowerShell command in **magenta** `[CMD]` blocks:
```
[CMD] Get-AzResource
[CMD] Get-AzKeyVaultSecret -VaultName credentialz
...
```

**Why?** This allows you to:
- Understand what the script is doing under the hood
- Copy commands for manual execution
- Include individual commands in exam reports (see disclaimer below)
- Learn Azure PowerShell syntax through practical examples

## ⚠️ Exam & Report Disclaimer

While AzureRedKit significantly accelerates Azure assessments, **it is not a replacement for understanding the underlying techniques**.

### **For CARTP and similar exams:**

✅ **DO:**
- Use AzureRedKit to speed up enumeration and save time
- Copy the displayed `[CMD]` commands into your report
- Manually re-execute key commands to verify functionality
- Explain what each command does in your writeup
- Use the tool to learn PowerShell syntax and Azure concepts

❌ **DON'T:**
- Submit raw script output as your entire report
- Skip learning the manual techniques
- Rely solely on automation without understanding the methodology
- Copy/paste logs without context or explanation

**Recommendation**: Use AzureRedKit as a **teaching tool** and **time-saver**, not a black box. Examiners expect you to demonstrate understanding of Azure security concepts.

## 🔧 Requirements

- **PowerShell 5.1+**
- **Azure PowerShell modules**:
```powershell
  Install-Module -Name Az -Scope CurrentUser -Force
  Install-Module -Name Microsoft.Graph -Scope CurrentUser -Force
```
- **For Automation Account exploitation**:
  - XAMPP (or any web server on port 80/82)
  - [Invoke-PowerShellTcp.ps1](https://github.com/samratashok/nishang/blob/master/Shells/Invoke-PowerShellTcp.ps1) from Nishang
  - Netcat (nc.exe, nc64.exe, or ncat.exe)

## 🫡 Credits

- **Nishang** - Invoke-PowerShellTcp.ps1 reverse shell
- **Altered Security** - CARTP certification and training content
- **Microsoft** - Azure PowerShell and Graph modules

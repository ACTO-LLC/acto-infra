#Requires -RunAsAdministrator

param(
    [switch]$Quiet
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Azure AVD Dev Box Setup Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

function Install-WinGetPackage {
    param(
        [string]$Id,
        [string]$Name
    )
    
    Write-Host "Installing $Name..." -ForegroundColor Yellow
    try {
        winget install --id $Id --accept-source-agreements --accept-package-agreements -h --silent
        Write-Host "  ✓ $Name installed successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "  ✗ Failed to install $Name" -ForegroundColor Red
        Write-Host "    Error: $_" -ForegroundColor Red
    }
}

function Install-VSCodeExtension {
    param([string]$Id)
    
    Write-Host "  Installing VS Code extension: $Id..." -ForegroundColor Gray
    try {
        code --install-extension $Id --force 2>&1 | Out-Null
        Write-Host "    ✓ Installed $Id" -ForegroundColor Green
    }
    catch {
        Write-Host "    ✗ Failed to install $Id" -ForegroundColor Red
    }
}

# Core Development Tools
Write-Host "`n--- Core Development Tools ---" -ForegroundColor Cyan
Install-WinGetPackage "Microsoft.VisualStudioCode" "Visual Studio Code"
Install-WinGetPackage "Git.Git" "Git"
Install-WinGetPackage "Microsoft.PowerShell" "PowerShell 7"
Install-WinGetPackage "GitHub.cli" "GitHub CLI"
Install-WinGetPackage "7zip.7zip" "7-Zip"

# Runtime & SDKs
Write-Host "`n--- Runtime & SDKs ---" -ForegroundColor Cyan
Install-WinGetPackage "Microsoft.DotNet.SDK.8" ".NET 8 SDK"
Install-WinGetPackage "OpenJS.NodeJS.LTS" "Node.js LTS"
Install-WinGetPackage "Python.Python.3.12" "Python 3.12"

# Cloud & Container Tools
Write-Host "`n--- Cloud & Container Tools ---" -ForegroundColor Cyan
Install-WinGetPackage "Microsoft.AzureCLI" "Azure CLI"
Install-WinGetPackage "Docker.DockerDesktop" "Docker Desktop"

# Database & Data Tools
Write-Host "`n--- Database & Data Tools ---" -ForegroundColor Cyan
Install-WinGetPackage "Microsoft.AzureDataStudio" "Azure Data Studio"
Install-WinGetPackage "Microsoft.SQLServerManagementStudio" "SQL Server Management Studio"
Install-WinGetPackage "Microsoft.PowerBI" "Power BI Desktop"
Install-WinGetPackage "Microsoft.PowerBIReportBuilder" "Power BI Report Builder"

# API & Development Tools
Write-Host "`n--- API & Development Tools ---" -ForegroundColor Cyan
Install-WinGetPackage "Postman.Postman" "Postman"

# VS Code Extensions
Write-Host "`n--- VS Code Extensions ---" -ForegroundColor Cyan
if (Get-Command code -ErrorAction SilentlyContinue) {
    Install-VSCodeExtension "ms-azuretools.vscode-docker"
    Install-VSCodeExtension "ms-dotnettools.csharp"
    Install-VSCodeExtension "ms-vscode.vscode-typescript-next"
    Install-VSCodeExtension "esbenp.prettier-vscode"
    Install-VSCodeExtension "dbaeumer.vscode-eslint"
    Install-VSCodeExtension "ms-azuretools.vscode-bicep"
    Install-VSCodeExtension "ms-vscode.powershell"
    Install-VSCodeExtension "ms-python.python"
    Install-VSCodeExtension "GitHub.copilot"
    Install-VSCodeExtension "ms-azuretools.vscode-azurefunctions"
} else {
    Write-Host "  VS Code not found in PATH. Extensions will need to be installed after restart." -ForegroundColor Yellow
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Installation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "`nPlease restart your computer to complete the installation.`n" -ForegroundColor Yellow

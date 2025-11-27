# Deploy Azure AVD Dev Box VM
# This script deploys the development workstation VM to Azure

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName = "rg-dev-avd-workstation",
    
    [Parameter(Mandatory=$true)]
    [string]$AdminUsername,
    
    [Parameter(Mandatory=$true)]
    [SecureString]$AdminPassword,
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "westus2",
    
    [Parameter(Mandatory=$false)]
    [string]$VmName = "dev-avd-01"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Azure AVD Dev Box Deployment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Convert SecureString to plain text for Azure CLI
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($AdminPassword)
$PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

Write-Host "Deploying VM to Resource Group: $ResourceGroupName" -ForegroundColor Yellow
Write-Host "Location: $Location" -ForegroundColor Yellow
Write-Host "VM Name: $VmName" -ForegroundColor Yellow
Write-Host "Admin Username: $AdminUsername" -ForegroundColor Yellow
Write-Host ""

# Deploy using Azure CLI
Write-Host "Starting deployment..." -ForegroundColor Green

az deployment group create `
    --resource-group $ResourceGroupName `
    --template-file "$PSScriptRoot\main.bicep" `
    --parameters adminUsername=$AdminUsername `
    --parameters adminPassword=$PlainPassword `
    --parameters vmName=$VmName `
    --parameters location=$Location

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  Deployment Successful!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Get the public IP address:" -ForegroundColor White
    Write-Host "   az vm show -d -g $ResourceGroupName -n $VmName --query publicIps -o tsv" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Connect via RDP to the public IP using:" -ForegroundColor White
    Write-Host "   Username: $AdminUsername" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. Run the dev tools installation script on the VM:" -ForegroundColor White
    Write-Host "   From the VM, clone the repo and run:" -ForegroundColor Gray
    Write-Host "   .\azure-avd-devbox\scripts\install-dev-tools.ps1" -ForegroundColor Gray
} else {
    Write-Host ""
    Write-Host "Deployment failed. Please check the error messages above." -ForegroundColor Red
}

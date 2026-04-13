# Deploy Ubuntu Dev VM
# Usage:
#   .\deploy.ps1 -SshPublicKeyFile ~/.ssh/id_ed25519.pub
#   .\deploy.ps1 -SshPublicKeyFile ~/.ssh/id_ed25519.pub -VmName "dev02-vm" -VmSize "Standard_D8s_v5"

param(
    [Parameter(Mandatory=$true)]
    [string]$SshPublicKeyFile,

    [string]$ResourceGroupName = "EHALSEY-DEV01-RG",
    [string]$Location = "westus2",
    [string]$VmName = "ehalsey-dev01-vm",
    [string]$AdminUsername = "ehalsey",
    [string]$VmSize = "Standard_D16s_v5",
    [string]$Subscription = "d487e16b-c758-4893-b0e9-a77c6e02e5f3"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Ubuntu Dev VM Deployment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Subscription:   $Subscription" -ForegroundColor Yellow
Write-Host "  Resource Group:  $ResourceGroupName" -ForegroundColor Yellow
Write-Host "  Location:        $Location" -ForegroundColor Yellow
Write-Host "  VM Name:         $VmName" -ForegroundColor Yellow
Write-Host "  VM Size:         $VmSize" -ForegroundColor Yellow
Write-Host "  Admin User:      $AdminUsername" -ForegroundColor Yellow
Write-Host ""

# Read SSH public key
if (-not (Test-Path $SshPublicKeyFile)) {
    Write-Error "SSH public key file not found: $SshPublicKeyFile"
    exit 1
}
$sshPublicKey = Get-Content $SshPublicKeyFile -Raw
$sshPublicKey = $sshPublicKey.Trim()
Write-Host "  SSH Key:         $SshPublicKeyFile" -ForegroundColor Yellow
Write-Host ""

# Ensure resource group exists
Write-Host "Ensuring resource group exists..." -ForegroundColor Green
az group create `
    --name $ResourceGroupName `
    --location $Location `
    --subscription $Subscription `
    --tags client=acto environment=production `
    --output none

# Deploy
Write-Host "Starting Bicep deployment..." -ForegroundColor Green
$result = az deployment group create `
    --resource-group $ResourceGroupName `
    --subscription $Subscription `
    --template-file "$PSScriptRoot\main.bicep" `
    --parameters vmName=$VmName `
    --parameters adminUsername=$AdminUsername `
    --parameters vmSize=$VmSize `
    --parameters sshPublicKey=$sshPublicKey `
    --output json | ConvertFrom-Json

if ($LASTEXITCODE -eq 0) {
    $outputs = $result.properties.outputs

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  Deployment Successful!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Public IP:  $($outputs.vmPublicIp.value)" -ForegroundColor White
    Write-Host "  SSH:        $($outputs.sshCommand.value)" -ForegroundColor White
    Write-Host ""
    Write-Host "Post-deploy steps:" -ForegroundColor Cyan
    Write-Host "  1. SSH in and run the setup script:" -ForegroundColor White
    Write-Host "     $($outputs.sshCommand.value)" -ForegroundColor Gray
    Write-Host "     curl -fsSL https://raw.githubusercontent.com/<org>/acto-infra/main/azure-dev-vm/scripts/setup-vm.sh | bash" -ForegroundColor Gray
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "Deployment failed. Check errors above." -ForegroundColor Red
    exit 1
}

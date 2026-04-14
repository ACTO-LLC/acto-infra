# Upgrade dev VM disks back to Premium SSD and start the VM.
# Inverse of stop-and-downgrade-disks.ps1.
#
# Usage:  .\start-and-upgrade-disks.ps1
#         .\start-and-upgrade-disks.ps1 -VmName "other-vm" -ResourceGroup "OTHER-RG"

param(
    [string]$ResourceGroup = "EHALSEY-DEV01-RG",
    [string]$VmName = "ehalsey-dev01-vm",
    [string]$Subscription = "d487e16b-c758-4893-b0e9-a77c6e02e5f3",
    [string]$OsDiskTargetSku = "Premium_LRS",
    [string]$DataDiskTargetSku = "Premium_LRS"
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Upgrade Disks and Start VM" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  VM:   $VmName" -ForegroundColor Yellow
Write-Host "  RG:   $ResourceGroup" -ForegroundColor Yellow
Write-Host ""

# 1. Get attached disk names (VM should be deallocated)
Write-Host "[1/3] Looking up attached disks..." -ForegroundColor Green
$vm = az vm show `
    --resource-group $ResourceGroup `
    --name $VmName `
    --subscription $Subscription `
    --output json | ConvertFrom-Json

$osDiskName = $vm.storageProfile.osDisk.name
$dataDiskNames = @($vm.storageProfile.dataDisks | ForEach-Object { $_.name })

Write-Host "  OS disk:    $osDiskName" -ForegroundColor White
Write-Host "  Data disks: $($dataDiskNames -join ', ')" -ForegroundColor White

# 2. Upgrade each disk SKU (VM must be stopped/deallocated)
Write-Host "[2/3] Upgrading disk SKUs..." -ForegroundColor Green

Write-Host "  -> $osDiskName : $OsDiskTargetSku" -ForegroundColor White
az disk update `
    --resource-group $ResourceGroup `
    --name $osDiskName `
    --subscription $Subscription `
    --sku $OsDiskTargetSku `
    --output none

foreach ($dd in $dataDiskNames) {
    Write-Host "  -> $dd : $DataDiskTargetSku" -ForegroundColor White
    az disk update `
        --resource-group $ResourceGroup `
        --name $dd `
        --subscription $Subscription `
        --sku $DataDiskTargetSku `
        --output none
}

# 3. Start VM
Write-Host "[3/3] Starting VM..." -ForegroundColor Green
az vm start `
    --resource-group $ResourceGroup `
    --name $VmName `
    --subscription $Subscription `
    --output none

$publicIp = az vm show `
    --resource-group $ResourceGroup `
    --name $VmName `
    --subscription $Subscription `
    --show-details `
    --query "publicIps" -o tsv

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "  VM started, disks upgraded to Premium SSD." -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Public IP:  $publicIp" -ForegroundColor White
Write-Host "  SSH:        ssh -i ~/.ssh/${VmName}_key.pem ehalsey@ehalsey-dev01.westus2.cloudapp.azure.com" -ForegroundColor White

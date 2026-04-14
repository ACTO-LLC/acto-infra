# Stop the dev VM and downgrade disks to cheaper SKUs for storage cost savings.
#
# Pricing (West US 2, approx):
#   OS disk  30 GB Premium SSD (P4)  -> Standard SSD (E4) :  ~$3.50/mo savings
#   Data 512 GB Premium SSD (P20)    -> Standard HDD (S20):  ~$53/mo savings
#
# Total savings vs leaving Premium SSD attached while VM is stopped: ~$56/mo
# Trusted Launch requires Premium or Standard SSD for OS disk -- HDD not allowed.
#
# Usage:  .\stop-and-downgrade-disks.ps1
#         .\stop-and-downgrade-disks.ps1 -VmName "other-vm" -ResourceGroup "OTHER-RG"

param(
    [string]$ResourceGroup = "EHALSEY-DEV01-RG",
    [string]$VmName = "ehalsey-dev01-vm",
    [string]$Subscription = "d487e16b-c758-4893-b0e9-a77c6e02e5f3",
    [string]$OsDiskTargetSku = "StandardSSD_LRS",
    [string]$DataDiskTargetSku = "Standard_LRS"
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Stop VM and Downgrade Disks" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  VM:   $VmName" -ForegroundColor Yellow
Write-Host "  RG:   $ResourceGroup" -ForegroundColor Yellow
Write-Host ""

# 1. Deallocate VM
Write-Host "[1/3] Deallocating VM..." -ForegroundColor Green
az vm deallocate `
    --resource-group $ResourceGroup `
    --name $VmName `
    --subscription $Subscription `
    --output none
Write-Host "  ✓ VM deallocated" -ForegroundColor Green

# 2. Get attached disk names
Write-Host "[2/3] Looking up attached disks..." -ForegroundColor Green
$vm = az vm show `
    --resource-group $ResourceGroup `
    --name $VmName `
    --subscription $Subscription `
    --output json | ConvertFrom-Json

$osDiskName = $vm.storageProfile.osDisk.name
$dataDiskNames = @($vm.storageProfile.dataDisks | ForEach-Object { $_.name })

Write-Host "  OS disk:    $osDiskName" -ForegroundColor White
Write-Host "  Data disks: $($dataDiskNames -join ', ')" -ForegroundColor White

# 3. Update each disk SKU
Write-Host "[3/3] Downgrading disk SKUs..." -ForegroundColor Green

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

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "  Done. VM is stopped, disks downgraded." -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "To start the VM and restore Premium SSD:" -ForegroundColor Cyan
Write-Host "  .\start-and-upgrade-disks.ps1" -ForegroundColor Gray

# Azure Ubuntu Dev VM

Bicep template and setup scripts for deploying an Ubuntu Pro 24.04 LTS development VM.

## What's included

- **VM:** Trusted Launch, SSH key auth, AAD SSH login extension
- **Storage:** 30 GB OS disk + 512 GB Premium SSD data disk
- **Network:** VNet, static public IP, NSG (SSH only)
- **Auto-shutdown:** Daily at 8 PM UTC

## Deploy

```powershell
cd azure-dev-vm/bicep
.\deploy.ps1 -SshPublicKeyFile ~/.ssh/id_ed25519.pub
```

Override defaults:
```powershell
.\deploy.ps1 -SshPublicKeyFile ~/.ssh/id_ed25519.pub `
    -VmName "dev02-vm" `
    -VmSize "Standard_D8s_v5" `
    -AdminUsername "jdoe" `
    -ResourceGroupName "DEV02-RG"
```

## Cost-saving disk swap

When the VM will be off for an extended period, downgrade the disks to cheaper SKUs:

```powershell
# Stop VM and downgrade: Premium SSD -> Standard SSD (OS) + Standard HDD (data)
.\scripts\stop-and-downgrade-disks.ps1

# Restore Premium SSD and start the VM
.\scripts\start-and-upgrade-disks.ps1
```

Saves ~$56/mo in storage when stopped. Trusted Launch requires SSD for OS disk, so OS disk goes to Standard SSD (not HDD).

## Post-deploy setup

SSH into the VM and run:
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/<org>/acto-infra/main/azure-dev-vm/scripts/setup-vm.sh)
```

Or copy and run locally:
```bash
scp -i ~/.ssh/<key>.pem azure-dev-vm/scripts/setup-vm.sh user@<ip>:~
ssh -i ~/.ssh/<key>.pem user@<ip> "bash ~/setup-vm.sh"
```

# Azure Dev VM Setup Guide  
**VM Name:** ehalsey-dev01-vm  
**Resource Group:** EHALSEY-DEV01-RG  
**Subscription:** Microsoft Azure Sponsorship (`d487e16b-c758-4893-b0e9-a77c6e02e5f3`)  
**Size:** Standard_D16s_v5 (16 vCPU / 64 GB RAM)  
**Region:** West US 2  
**Public IP:** 4.154.42.33 (static)  
**DNS:** ehalsey-dev01.westus2.cloudapp.azure.com  
**Username:** ehalsey  
**OS:** Ubuntu Pro 24.04 LTS  

**Purpose:** Fast, low-latency development machine for multiple full-stack projects + OpenEMR custom modules using VS Code / Cursor + Docker / Dev Containers.

---

## 1. Connect to the VM via SSH (First Time Only)

First, copy the `.pem` key to your SSH directory:

**Mac / Linux / Git Bash**
```bash
cp ~/Downloads/ehalsey-dev01-vm_key.pem ~/.ssh/
chmod 600 ~/.ssh/ehalsey-dev01-vm_key.pem
ssh -i ~/.ssh/ehalsey-dev01-vm_key.pem ehalsey@ehalsey-dev01.westus2.cloudapp.azure.com
```

**Windows (PowerShell)**
```powershell
Copy-Item "$env:USERPROFILE\Downloads\ehalsey-dev01-vm_key.pem" "$env:USERPROFILE\.ssh\"
icacls "$env:USERPROFILE\.ssh\ehalsey-dev01-vm_key.pem" /inheritance:r /grant:r "$($env:USERNAME):(R)"
ssh -i "$env:USERPROFILE\.ssh\ehalsey-dev01-vm_key.pem" ehalsey@ehalsey-dev01.westus2.cloudapp.azure.com
```

Type `yes` when it asks "Are you sure you want to continue connecting?"

---

## 2. Mount the 512 GB Premium SSD Data Disk (One-Time Setup)

Run these commands **inside the VM**:

```bash
# 1. Identify the unformatted data disk (~512 GB, no partitions)
lsblk
# Look for the disk matching 512G with no mountpoint — typically /dev/sdc,
# but Azure does not guarantee the device name. Adjust commands below if different.

# 2. Format the new disk (ONLY run once — this destroys all data on the disk)
sudo mkfs.ext4 /dev/sdc

# 3. Create mount point and mount it
sudo mkdir -p /mnt/data
sudo mount /dev/sdc /mnt/data

# 4. Make the mount permanent (survives reboots)
sudo blkid /dev/sdc | grep -o 'UUID="[0-9a-f-]*"' | sed 's/UUID="//;s/"//' | xargs -I {} echo "UUID={} /mnt/data ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab

# 5. Verify
df -h | grep /mnt/data
```

You should now see **~512 GB** available at `/mnt/data`.

**Recommended folder structure:**
```bash
/mnt/data/projects/          # All your repos go here
/mnt/data/openemr/           # OpenEMR docker-compose and custom modules
/mnt/data/docker-volumes/    # Persistent DBs, etc.
```

---

## 3. Install Docker + Docker Compose (Official Method)

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
sudo apt install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add your user to docker group (no more sudo docker)
sudo usermod -aG docker ehalsey

# Restart Docker
sudo systemctl restart docker
```

**Log out and log back in** (or run `newgrp docker`) so the group change takes effect.

Test it:
```bash
docker --version
docker compose version
```

---

## 4. Connect VS Code / Cursor (Remote-SSH)

1. Open **VS Code** or **Cursor**.
2. Install the **Remote - SSH** extension (Microsoft) if not already installed.
3. Press `Ctrl+Shift+P` → type **"Remote-SSH: Connect to Host"**
4. Choose **+ Add New SSH Host…**
5. Paste this exact connection string:
   ```
   ssh -i ~/.ssh/ehalsey-dev01-vm_key.pem ehalsey@ehalsey-dev01.westus2.cloudapp.azure.com
   ```
6. Select the SSH config file it suggests.
7. Connect.

Once connected, open folders under `/mnt/data` and use Dev Containers as usual.

---

## 5. Quick OpenEMR Setup Example

```bash
cd /mnt/data
mkdir -p openemr && cd openemr

# Clone your custom OpenEMR docker setup or create docker-compose.yml
# Then:
docker compose up -d
```

Your custom modules can be mounted into the container as usual.

---

## 6. Cost Management & Best Practices

- **Auto-shutdown** (already enabled in VM settings) → set to 8 PM daily.
- Stop the VM when not in use → you pay **~$0 only for storage**.
- Estimated monthly cost (4–8 hrs/day): **$200–$350**.
- All projects live on the 512 GB Premium SSD → very fast I/O.

### Future: Switch to Spot (Cheaper)
Once your Spot quota is approved:
1. Create a new Spot VM.
2. Attach the existing data disk (`ehalsey-dev01-vm_DataDisk_0`).
3. Delete the old VM.

> **Caution:** Spot VMs can be evicted by Azure with ~30 seconds notice when capacity is needed. Save work frequently and ensure running containers can tolerate restarts.

---

## Troubleshooting

- **SSH key permission error** → `chmod 600` the `.pem` file (Mac/Linux) or use `icacls` to restrict access (Windows).
- **Disk not mounting** → `sudo mount -a` to test fstab.
- **Docker permission** → Log out / log back in after `usermod`.
- **Slow VS Code** → Make sure you open folders under `/mnt/data` (not the small OS disk).

#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Post-deploy setup for Ubuntu Dev VM
# Run this on the VM after initial deployment to:
#   1. Format and mount the data disk
#   2. Install Docker CE + Compose
#   3. Create project folder structure
#
# Usage:  bash setup-vm.sh
# ---------------------------------------------------------------------------
set -euo pipefail

echo "======================================"
echo "  Ubuntu Dev VM Setup"
echo "======================================"
echo ""

USERNAME=$(whoami)

# ---------------------------------------------------------------------------
# 1. Format and mount data disk
# ---------------------------------------------------------------------------
echo "--- Data Disk Setup ---"

# Find the unformatted data disk (largest unmounted disk)
DATA_DISK=$(lsblk -dno NAME,SIZE,TYPE | awk '$3=="disk"' | sort -k2 -h | tail -1 | awk '{print $1}')

if [ -z "$DATA_DISK" ]; then
    echo "ERROR: No data disk found."
    exit 1
fi

DISK_PATH="/dev/$DATA_DISK"
echo "Found data disk: $DISK_PATH"

# Check if already formatted
if sudo blkid "$DISK_PATH" | grep -q 'TYPE='; then
    echo "Disk already formatted, skipping mkfs."
else
    echo "Formatting $DISK_PATH as ext4..."
    sudo mkfs.ext4 "$DISK_PATH"
fi

# Mount
sudo mkdir -p /mnt/data
if mountpoint -q /mnt/data; then
    echo "/mnt/data already mounted."
else
    sudo mount "$DISK_PATH" /mnt/data
    echo "Mounted $DISK_PATH at /mnt/data."
fi

# fstab (idempotent)
UUID=$(sudo blkid -s UUID -o value "$DISK_PATH")
if grep -q "$UUID" /etc/fstab; then
    echo "fstab entry already exists."
else
    echo "UUID=$UUID /mnt/data ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab
    echo "Added fstab entry."
fi

# Create folder structure
sudo mkdir -p /mnt/data/projects /mnt/data/openemr /mnt/data/docker-volumes
sudo chown -R "$USERNAME:$USERNAME" /mnt/data
echo "Folder structure created under /mnt/data."

df -h /mnt/data
echo ""

# ---------------------------------------------------------------------------
# 2. Install Docker CE
# ---------------------------------------------------------------------------
echo "--- Docker Installation ---"

if command -v docker &>/dev/null; then
    echo "Docker already installed: $(docker --version)"
else
    sudo apt-get update -qq
    sudo apt-get install -y -qq ca-certificates curl

    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update -qq
    sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    sudo usermod -aG docker "$USERNAME"
    sudo systemctl enable docker
    sudo systemctl start docker

    echo "Docker installed: $(docker --version)"
    echo "Docker Compose: $(docker compose version)"
    echo ""
    echo "NOTE: Log out and back in for docker group membership to take effect."
fi

echo ""
echo "======================================"
echo "  Setup Complete!"
echo "======================================"
echo ""
echo "  Data disk:  /mnt/data ($(df -h /mnt/data --output=avail | tail -1 | xargs) available)"
echo "  Docker:     $(docker --version 2>/dev/null || echo 'installed (re-login for group access)')"
echo "  Projects:   /mnt/data/projects/"
echo ""

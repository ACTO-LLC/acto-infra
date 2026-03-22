# HP Pavilion 17z-e100 — Booting Ubuntu from USB

## Machine Details

| Detail | Value |
|--------|-------|
| Model | HP Pavilion 17z-e100 CTO Notebook PC |
| SKU | E1P44AV |
| Year | Late 2013 |
| CPU | AMD |
| BIOS | InsydeH20 Setup Utility |
| Current OS | Windows 10 |
| Boot modes | UEFI and Legacy (CSM) |

## Creating the Bootable USB

These steps were performed on a separate Windows 11 machine.

### What you need

- **USB drive:** At least 8 GB. We used a 1 TB USB 3.0 SSD. Note: the original 16 GB "KDI-MSFT Windows 10" drive failed with I/O errors (`0xC003045D`) on multiple ports — if a drive gives this error, swap it out.
- **Ubuntu ISO:** Ubuntu 24.04.4 LTS Desktop (amd64), ~6.2 GB. Download from ubuntu.com.
- **Rufus:** v4.6+ from rufus.ie (portable, no install needed).

### Flashing with Rufus

1. Open `rufus-4.6.exe`
2. **Device:** Select the USB drive. If it's larger than 512 GB, expand "Show advanced drive properties" and check **"List USB Hard Drives"** — Rufus hides large drives by default.
3. **Boot selection:** Click SELECT, browse to the Ubuntu ISO.
4. **Partition scheme:** MBR
5. **Target system:** BIOS or UEFI
6. Click **START**.
7. When prompted "ISOHybrid image detected," choose **"Write in ISO Image mode (Recommended)"**. If you get boot errors later (see Troubleshooting), re-flash using DD Image mode instead.
8. Safely eject the USB drive before unplugging.

## Booting on the HP Pavilion

### BIOS Configuration (one-time setup)

1. Power on and **press Esc repeatedly** to reach the HP Startup Menu.
2. Press **F10** to enter BIOS Setup (InsydeH20).
3. Navigate to the **System Configuration** tab.
4. Under **Boot Options:**
   - Set **Legacy Support** to **Enabled** — Ubuntu 24.04 ISOs can fail to boot in UEFI-only mode on this machine with "invalid sector size / you need to load the kernel first."
   - Ensure **USB Boot** is enabled.
5. Press **F10** to save and exit.

### Booting from USB

1. Plug in the Ubuntu USB drive.
2. Power on and **press Esc repeatedly** to reach the HP Startup Menu.
3. Press **F9** to open Boot Device Options.
4. Select the USB drive from the list.
5. Choose **"Try Ubuntu"** from the GRUB menu — do **not** install.

## Inspecting a Suspect USB Drive

1. Disable networking when prompted during Ubuntu startup (or turn off Wi-Fi/Ethernet after boot).
2. Verify you're offline:
   ```
   ping -c 1 google.com
   ```
   Should return "Temporary failure in name resolution" or "Network is unreachable."
3. Plug in the suspect USB and identify it:
   ```
   lsblk
   sudo dmesg | tail -30
   ```
4. Mount it **read-only**:
   ```
   sudo mkdir -p /mnt/suspect
   sudo mount -o ro /dev/sdX1 /mnt/suspect
   ```
   Replace `sdX1` with the actual device (check `dmesg` output).
5. Browse and inspect:
   ```
   ls /mnt/suspect/
   find /mnt/suspect/ -type f -printf '%T+ %p\n' | sort -r | head -50
   ```

## Wiping and Reformatting a USB Drive

1. Unmount the drive if mounted:
   ```
   sudo umount /mnt/suspect
   ```
2. Wipe with zeros (replace `sdX` with actual device):
   ```
   sudo dd if=/dev/zero of=/dev/sdX bs=4M status=progress
   ```
   Wait for the USB light to stop flashing — the laptop screen may go to sleep during this step; that's normal.
3. Verify the wipe:
   ```
   sudo dd if=/dev/sdX bs=512 count=1 | hexdump -C
   ```
   All output should be zeros.
4. Create a fresh GPT partition and format as NTFS:
   ```
   sudo parted /dev/sdX mklabel gpt
   sudo parted /dev/sdX mkpart primary ntfs 0% 100%
   sudo mkfs.ntfs -f /dev/sdX1
   ```
   Ignore the "You may need to update /etc/fstab" messages — they don't apply in a live session.
5. Eject and shut down:
   ```
   sudo eject /dev/sdX
   sudo shutdown now
   ```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Rufus shows "0 devices found" | Expand "Show advanced drive properties" and check "List USB Hard Drives" |
| Rufus error `0xC003045D` (I/O device error) | USB drive is failing — try different ports, then swap the drive |
| "Invalid sector size" / "you need to load the kernel first" | Enter BIOS (Esc → F10), go to System Configuration > Boot Options, enable **Legacy Support** |
| USB still won't boot after enabling Legacy | Re-flash with Rufus using **DD Image mode** instead of ISO Image mode |
| USB drive not in F9 boot menu | Enter BIOS (F10), ensure USB Boot is enabled under System Configuration > Boot Options |

# Safely Inspecting a Suspicious USB Drive

**The safest practical approach is to inspect the USB in a completely isolated environment that doesn't touch your main computer's hard drive or OS.** This protects against common threats like autorun malware, executable files that run on access, or even firmware-level attacks (e.g., BadUSB, which can reprogram the drive to act like a keyboard).

No method is 100% guaranteed against highly sophisticated targeted attacks (like hardware that fries your USB port via overvoltage), but the methods below reduce the risk to near-zero for typical scenarios. Never plug the drive directly into your everyday computer or laptop.

## Best Option for Most People: Boot a Trusted Linux "Live" USB (Runs Entirely in RAM)

This is the consensus recommendation from security experts (e.g., on Stack Exchange, SuperUser, and privacy-focused guides). Linux doesn't automatically execute files from USBs the way Windows often does. The session vanishes when you shut down—no traces left behind.

### Creating the Bootable USB (from a trusted Windows machine)

1. Download the official Ubuntu Desktop ISO from ubuntu.com (or Tails from tails.net for even stronger isolation/privacy). Note: Ubuntu 24.04+ ISOs are ~6 GB, so you'll need a USB drive of at least 8 GB (16 GB recommended if you want room to install tools like ClamAV in the live session).
2. Download Rufus from rufus.ie. It's lightweight, handles UEFI/GPT natively, and is the best option on Windows.
3. Open Rufus, select your USB drive, point it to the downloaded ISO, and click Start. Default settings are fine for most cases.

> **Tip:** If you plan to do this more than once, consider Ventoy (ventoy.net) instead. Ventoy lets you drop ISO files directly onto a USB drive and boot any of them from a menu—no re-flashing needed each time.

> **HP Pavilion 17z-e100:** See [hp-pavilion-ubuntu-usb.md](hp-pavilion-ubuntu-usb.md) for machine-specific BIOS settings, troubleshooting, and step-by-step instructions.

### Booting and Inspecting on the Target Machine

4. Insert the live USB into the target machine (the one you'll use for inspection).
5. Boot from the USB. The target machine is an **HP Pavilion 17z-e100** (SKU E1P44AV) running Windows 10:
   - Restart and **press Esc repeatedly** as soon as the screen turns on to reach the HP Startup Menu.
   - Press **F9** to open the Boot Device Options menu and select your USB drive.
   - If the USB doesn't appear, press **F10** instead to enter BIOS Setup, go to System Configuration > Boot Options, and ensure **USB Boot** is enabled and **Legacy Support** is on (in case UEFI-only doesn't see the drive).
6. Choose "Try Ubuntu" (or equivalent)—do **not** install anything.
7. **For maximum safety:** Disconnect your main hard drive(s) physically if you're comfortable opening the case (pull the SATA/power cables). Disable Wi-Fi/Ethernet in the live session (click the network icon and turn it off).
8. Plug in the suspicious USB thumb drive. Open the Files app (file manager).
9. **Inspect without risk:**
   - Browse the folder list and file names/extensions only.
   - View properties or use the built-in preview for images, text files, or PDFs (don't open suspicious docs in external apps).
   - **Do not** double-click .exe, .scr, .bat, or any executables. Avoid opening Office docs or anything that might run macros.
10. Optional: Scan with ClamAV. This requires a brief internet connection for package download and signature updates, so you'll need to temporarily enable Wi-Fi/Ethernet. In the terminal (Ctrl+Alt+T), run:
    ```
    sudo apt update && sudo apt install clamav
    sudo freshclam
    sudo clamscan -r /media/
    ```
    Disable networking again after the scan completes.

11. When done, safely eject the drive, shut down, and remove the live USB. Your main system is untouched.

**Why this works well:** Everything happens in temporary RAM. Tools like TENS (a security-focused live Linux) or Tails are even more locked-down if you want extras.

## Good Alternative: Virtual Machine (Convenient but Slightly Less Isolated)

If you don't want to reboot:
- Install free VirtualBox (virtualbox.org) or VMware on your main computer.
- Create a new VM and install a fresh Linux (Ubuntu) or Windows inside it.
- In VM settings, enable USB passthrough so only the VM sees the drive (do **not** enable shared folders, clipboard, or drag-and-drop).
- Boot the VM, plug in the USB, and inspect as above.
- Delete the entire VM afterward if anything looks suspicious.

**Caveat:** Some advanced firmware malware can theoretically "escape" a VM via USB controller exploits (rare in the wild but documented in research). It's still far safer than your host OS and works for 99% of cases.

## Other Strong Options

- **Old/disposable computer** (ideal if you have one): Use a cheap used laptop or Raspberry Pi. Never connect it to the internet or your network. Boot live Linux on it, inspect, then wipe or discard the machine.
- **Hardware write-blocker** (advanced/pro): Devices like a Tableau or cheap forensic USB blocker prevent the drive from writing anything. Overkill for most people (~$50–300 on eBay) but lets you scan safely on any PC.

## Extra Precautions

- If the drive might be a "USB killer" (rare but possible), plug it into a cheap USB hub first or a disposable port/machine.
- After inspection: If you want to reuse the drive, format it fully in the live session (use `dd` for a secure wipe or just the Disks app to create a new FAT32/exFAT partition).
- Windows-specific note: Even Microsoft Defender's "Scan" on a plugged-in drive isn't enough alone—autorun and low-level attacks can still trigger.

If the contents look benign (e.g., just photos or documents) after scanning and previewing, you can copy them to another clean drive for further review. Otherwise, physically destroy or securely erase the thumb drive.

This process takes 15–30 minutes once you have the live USB ready and keeps you completely protected. If you're extremely paranoid (e.g., targeted threat), the only truly bulletproof way is disassembling the drive and reading the flash chip on dedicated hardware—but that's not realistic for normal use.

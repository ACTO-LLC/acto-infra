#!/usr/bin/env python3
"""
Network Device Audit

Scans all routers (EdgeRouter, Mango, Netgear) for connected devices and
compares against the known device inventory. Reports any unknown devices.

Usage:
    python scripts/network-device-audit.py

Environment variables (or prompted):
    EDGEROUTER_PASS  - EdgeRouter SSH password (user: Krdm109)
    MANGO_PASS       - Mango SSH password (user: root)
    NETGEAR_PASS     - Netgear web admin password (user: admin)
"""

import json
import os
import re
import sys
import urllib.request
import base64
from datetime import datetime

try:
    import paramiko
except ImportError:
    print("ERROR: paramiko is required. Install with: pip install paramiko")
    sys.exit(1)

# Known devices — MAC (uppercase) -> description
# Update this list when new devices are added to the network.
KNOWN_DEVICES = {
    "28:80:88:1F:61:FA": "Netgear R7000P AP",
    "94:83:C4:86:89:17": "GL.iNet Mango router",
    "48:9E:BD:A0:4F:FF": "EH-HP-DT-01 Desktop (Ethernet)",
    "38:D5:7A:8A:C5:77": "EH-HP-DT-01 Desktop (WiFi)",
    "58:02:05:47:B3:4A": "hplt-001 Laptop",
    "5C:C5:63:F1:B7:26": "Formuler Z10 (Office)",
    "68:4E:05:7A:91:1A": "Formuler Z10 (Living Room)",
    "D0:73:D5:00:6D:22": "LIFX Bulb",
    "C8:3A:6B:AA:B3:68": "Roku",
    "AC:63:BE:11:ED:DE": "Amazon Firestick",
    "B0:E8:92:5F:DD:DF": "Epson Printer",
    "B8:F0:09:00:A6:06": "Espressif IoT Device",
    "2C:64:1F:B5:D3:E8": "Vizio TV (Living Room)",
    "0C:8B:7D:B6:7C:59": "Vizio TV (Bedroom)",
    "CC:95:D7:AB:65:71": "Vizio TV (Third)",
    "28:24:C9:64:54:DC": "Amazon Device",
    "14:2D:27:9B:82:9E": "Hon Hai/Foxconn Device",
    "AC:82:47:4E:D5:4F": "Intel Device",
    "F8:E4:3B:88:6C:E6": "ASIX USB Ethernet Adapter",
    "00:05:1B:A1:E4:6C": "Magic Control Technology Device",
}

# Devices with randomized MACs — we track these by note, not exact MAC
RANDOMIZED_MAC_NOTES = [
    "56:A5:28:50:9C:50 — iPhone",
    "C6:6A:65:D6:D9:EA — Samsung S22",
    "AE:82:46:AF:C4:AC — Unknown mobile",
    "46:A8:0D:CD:A4:96 — Unknown mobile",
]


def is_randomized_mac(mac: str) -> bool:
    """Check if a MAC address has the locally-administered bit set (randomized)."""
    first_octet = int(mac.split(":")[0], 16)
    return bool(first_octet & 0x02)


def get_env_or_prompt(var_name: str, prompt_text: str) -> str:
    val = os.environ.get(var_name)
    if val:
        return val
    return input(prompt_text)


def scan_edgerouter(password: str) -> dict:
    """Scan EdgeRouter ARP table. Returns {mac: {ip, device}}."""
    devices = {}
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        ssh.connect("192.168.1.1", username="Krdm109", password=password, timeout=5)
        stdin, stdout, stderr = ssh.exec_command("cat /proc/net/arp")
        for line in stdout.read().decode().strip().split("\n")[1:]:
            parts = line.split()
            if len(parts) >= 4 and parts[3] != "00:00:00:00:00:00":
                ip = parts[0]
                mac = parts[3].upper()
                devices[mac] = {"ip": ip, "source": "EdgeRouter"}
        ssh.close()
    except Exception as e:
        print(f"  WARNING: EdgeRouter scan failed: {e}")
    return devices


def scan_mango(password: str) -> dict:
    """Scan Mango DHCP leases and ARP table. Returns {mac: {ip, hostname, device}}."""
    devices = {}
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        ssh.connect("192.168.8.1", username="root", password=password, timeout=5)
        # DHCP leases
        stdin, stdout, stderr = ssh.exec_command("cat /tmp/dhcp.leases")
        for line in stdout.read().decode().strip().split("\n"):
            parts = line.split()
            if len(parts) >= 4:
                mac = parts[1].upper()
                ip = parts[2]
                hostname = parts[3] if parts[3] != "*" else "--"
                devices[mac] = {"ip": ip, "hostname": hostname, "source": "Mango"}
        # ARP table for devices without leases
        stdin, stdout, stderr = ssh.exec_command("cat /proc/net/arp")
        for line in stdout.read().decode().strip().split("\n")[1:]:
            parts = line.split()
            if len(parts) >= 4 and parts[3] != "00:00:00:00:00:00":
                mac = parts[3].upper()
                if mac not in devices:
                    devices[mac] = {"ip": parts[0], "source": "Mango (ARP)"}
        ssh.close()
    except Exception as e:
        print(f"  WARNING: Mango scan failed: {e}")
    return devices


def scan_netgear(password: str) -> dict:
    """Scan Netgear attached devices via web API. Returns {mac: {ip, name, contype}}."""
    devices = {}
    try:
        creds = base64.b64encode(f"admin:{password}".encode()).decode()
        req = urllib.request.Request("http://192.168.1.47/DEV_device2.htm")
        req.add_header("Authorization", f"Basic {creds}")
        resp = urllib.request.urlopen(req, timeout=5)
        data = resp.read().decode(errors="replace")

        for line in data.split("\n"):
            if "var dvo" in line:
                idx = line.index("var dvo = ") + len("var dvo = ")
                rest = line[idx:].rstrip().rstrip(";").strip()
                try:
                    dvo = json.loads(rest)
                except json.JSONDecodeError:
                    rest = rest + "}]}"
                    dvo = json.loads(rest)
                for dev in dvo.get("device", []):
                    mac = dev.get("mac", "").upper()
                    if mac:
                        devices[mac] = {
                            "ip": dev.get("ip", "?"),
                            "name": dev.get("name", "--"),
                            "contype": dev.get("contype", "?"),
                            "ssid": dev.get("ssid", ""),
                            "source": "Netgear",
                        }
                break
    except Exception as e:
        print(f"  WARNING: Netgear scan failed: {e}")
    return devices


def lookup_vendor(mac: str) -> str:
    """Look up MAC vendor via macvendors.com API."""
    oui = mac[:8]
    try:
        req = urllib.request.Request(f"https://macvendors.com/query/{oui}")
        req.add_header("User-Agent", "network-audit/1.0")
        resp = urllib.request.urlopen(req, timeout=3)
        return resp.read().decode().strip()
    except Exception:
        return "Unknown"


def main():
    print(f"Network Device Audit — {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 70)

    er_pass = get_env_or_prompt("EDGEROUTER_PASS", "EdgeRouter password: ")
    mango_pass = get_env_or_prompt("MANGO_PASS", "Mango admin password: ")
    netgear_pass = get_env_or_prompt("NETGEAR_PASS", "Netgear admin password: ")

    print("\nScanning routers...")
    er_devices = scan_edgerouter(er_pass)
    mango_devices = scan_mango(mango_pass)
    netgear_devices = scan_netgear(netgear_pass)

    # Merge all discovered MACs
    all_macs = set()
    all_macs.update(er_devices.keys())
    all_macs.update(mango_devices.keys())
    all_macs.update(netgear_devices.keys())

    # Classify
    known = []
    unknown = []
    randomized = []

    for mac in sorted(all_macs):
        sources = []
        ip = "?"
        if mac in er_devices:
            sources.append("EdgeRouter")
            ip = er_devices[mac]["ip"]
        if mac in mango_devices:
            sources.append("Mango")
            ip = mango_devices[mac].get("ip", ip)
        if mac in netgear_devices:
            sources.append("Netgear")
            ip = netgear_devices[mac].get("ip", ip)

        info = {"mac": mac, "ip": ip, "sources": sources}

        if mac in KNOWN_DEVICES:
            info["name"] = KNOWN_DEVICES[mac]
            known.append(info)
        elif is_randomized_mac(mac):
            info["name"] = "(randomized MAC)"
            randomized.append(info)
        else:
            info["vendor"] = lookup_vendor(mac)
            unknown.append(info)

    # Report
    print(f"\nKnown devices: {len(known)}")
    print(f"Randomized MACs: {len(randomized)}")
    print(f"UNKNOWN devices: {len(unknown)}")

    if unknown:
        print("\n" + "!" * 70)
        print("UNKNOWN DEVICES DETECTED")
        print("!" * 70)
        for dev in unknown:
            print(f"  MAC: {dev['mac']}")
            print(f"  IP:  {dev['ip']}")
            print(f"  Vendor: {dev['vendor']}")
            print(f"  Seen on: {', '.join(dev['sources'])}")
            print()

    if randomized:
        print("\nRandomized MACs (may be phones/tablets with MAC privacy):")
        for dev in randomized:
            print(f"  {dev['mac']} — {dev['ip']} ({', '.join(dev['sources'])})")

    print("\nKnown devices:")
    for dev in known:
        print(f"  {dev['name']:40s} {dev['mac']}  ({', '.join(dev['sources'])})")

    # Exit code: 1 if unknown devices found
    if unknown:
        print(f"\nEXIT 1 — {len(unknown)} unknown device(s) found")
        sys.exit(1)
    else:
        print("\nEXIT 0 — All devices accounted for")
        sys.exit(0)


if __name__ == "__main__":
    main()

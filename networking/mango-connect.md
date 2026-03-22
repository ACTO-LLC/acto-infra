# Connecting to the GL.iNet Mango (GL-MT300N-V2)

## WiFi

| Property | Value |
|----------|-------|
| SSID | GL-MT300N-V2-917 |
| Password | mangorouter |
| Security | WPA2-PSK |
| Band | 2.4GHz |

Once connected, your device gets an IP in the 192.168.8.x range.

## Web Admin Panel

1. Connect to the Mango WiFi
2. Open http://192.168.8.1
3. Login with admin password

> **Note:** The admin panel is only accessible from the LAN side (192.168.8.x), not from the WAN/EdgeRouter side (192.168.1.x).

## SSH

1. Connect to the Mango WiFi
2. SSH to root@192.168.8.1 on port 22

```bash
ssh root@192.168.8.1
```

> SSH uses the same admin password as the web panel.

## From Claude Code (programmatic)

```python
import paramiko
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('192.168.8.1', username='root', password='<admin-password>', timeout=5)
stdin, stdout, stderr = ssh.exec_command('<command>')
print(stdout.read().decode())
ssh.close()
```

## Prerequisites

Your device must be connected to the Mango's WiFi (GL-MT300N-V2-917). Management is not accessible from the EdgeRouter/Netgear network (192.168.1.x).

## Static IP Assignments

| Device | IP |
|--------|----|
| EH-HP-DT-01 (Desktop) | 192.168.8.10 |
| hplt-001 (Laptop) | 192.168.8.11 |
| Eric-s-S22 (Phone) | 192.168.8.12 |
| SM-L315U (Watch) | 192.168.8.13 |
| Formuler-Z10 | 192.168.8.14 |

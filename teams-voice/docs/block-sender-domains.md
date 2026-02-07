# Blocking Sender Domains in Exchange Online

Use Exchange Online **mail flow (transport) rules** to reject all inbound email from unwanted sender domains organization-wide.

---

## Prerequisites

- `ExchangeOnlineManagement` PowerShell module installed
- Service principal credentials (see [automation-setup.md](automation-setup.md))

---

## Block a Domain

Connect to Exchange Online, then create a transport rule:

```powershell
Import-Module ExchangeOnlineManagement
Connect-ExchangeOnline `
    -AppId "11b1509b-d570-4d3a-b46e-032215808864" `
    -CertificateThumbprint "23B468A0F2F8A32B673F2CEBBCA9F00B7A3F10A6" `
    -Organization "a-cto.com" `
    -ShowBanner:$false

New-TransportRule `
    -Name "Block <domain>" `
    -SenderDomainIs "<domain>" `
    -RejectMessageReasonText "Emails from this domain are not accepted." `
    -StopRuleProcessing $true
```

Replace `<domain>` with the full sender domain (e.g. `mail.beehiiv.com`).

---

## Verify

```powershell
Get-TransportRule | Where-Object { $_.Name -like "Block *" } |
    Format-Table Name, State, Priority -AutoSize
```

---

## Remove a Block

```powershell
Remove-TransportRule -Identity "Block <domain>" -Confirm:$false
```

---

## Currently Blocked Domains

| Domain | Rule Name | Date Added |
|--------|-----------|------------|
| `mail.beehiiv.com` | Block mail.beehiiv.com | 2026-02-07 |
| `e.conservdirect.com` | Block e.conservdirect.com | 2026-02-07 |

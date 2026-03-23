# ACTO Break-Glass Account

## Overview

A shared mailbox and GitHub "break-glass" account provide business continuity for the ACTO-LLC GitHub organization. The break-glass account holds Org Owner privileges and is only used in emergencies.

## Shared Mailbox

| Property | Value |
|----------|-------|
| Address | `admin-emergency@a-cto.com` |
| Type | Shared Mailbox (no M365 license required) |
| Display Name | Admin Emergency |
| Created | 2026-03-23 |

### Full Access & SendAs Delegates

| User | Email | Full Access | SendAs | AutoMapping |
|------|-------|-------------|--------|-------------|
| Eric Halsey | ehalsey@a-cto.com | Yes | Yes | Yes |
| Sue Halsey | shalsey@a-cto.com | Yes | Yes | Yes |
| Quentin Halsey | quentin.halsey@a-cto.com | Yes | Yes | Yes |

AutoMapping means the mailbox appears automatically in each delegate's Outlook client.

### How permissions were granted

Mailbox creation and permissions were set via Exchange Online PowerShell using certificate-based service principal auth:

```powershell
New-Mailbox -Shared -Name "Admin Emergency" -DisplayName "Admin Emergency" `
    -Alias "admin-emergency" -PrimarySmtpAddress "admin-emergency@a-cto.com"

Add-MailboxPermission -Identity "admin-emergency@a-cto.com" `
    -User "<user>" -AccessRights FullAccess -AutoMapping $true

Add-RecipientPermission -Identity "admin-emergency@a-cto.com" `
    -Trustee "<user>" -AccessRights SendAs -Confirm:$false
```

## GitHub Break-Glass Account

| Property | Value |
|----------|-------|
| GitHub Username | ACTO-Emergency |
| Registered Email | admin-emergency@a-cto.com |
| Org Role | **Owner** of ACTO-LLC |
| Credentials | Stored in Eric's password manager |

### Purpose

- Business continuity if the primary admin (ehalsey) is unavailable
- "Skeleton key" access to the full GitHub organization
- Separate from daily-use accounts to prevent accidental use of Owner privileges

### Cost

- **M365:** $0.00 — shared mailboxes do not require a license
- **GitHub:** $0.00 — org owners on the Free plan are not billed per-seat

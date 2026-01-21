# Microsoft 365 Automation Setup

This document describes the infrastructure used to manage Microsoft Teams Phone System and Exchange Online programmatically, without interactive authentication.

---

## Overview

We use a **Service Principal** with **certificate-based authentication** to manage Teams and Exchange configuration via PowerShell. This enables:

- Automated scripts without user login prompts
- CI/CD pipeline integration
- AI-assisted management via Claude Code with Azure MCP servers

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Claude Code CLI                          │
├─────────────────────────────────────────────────────────────────┤
│  Azure MCP Server                                               │
│  - Provides Azure tooling context                               │
│  - Best practices for Azure/Teams/Exchange operations           │
├─────────────────────────────────────────────────────────────────┤
│  PowerShell Modules                                             │
│  - MicrosoftTeams: Auto Attendants, Call Queues, Users          │
│  - ExchangeOnlineManagement: Mailboxes, Distribution Groups     │
├─────────────────────────────────────────────────────────────────┤
│  Service Principal (Entra ID App Registration)                  │
│  - Certificate stored in Azure Key Vault                        │
│  - Entra ID Roles + API Permissions                             │
├─────────────────────────────────────────────────────────────────┤
│  Microsoft 365 Services                                         │
│  - Microsoft Teams / Phone System                               │
│  - Exchange Online                                              │
└─────────────────────────────────────────────────────────────────┘
```

---

## Service Principal Configuration

### App Registration Details

| Property | Value |
|----------|-------|
| **App Name** | ACTO Internal Automation |
| **Application (Client) ID** | `11b1509b-d570-4d3a-b46e-032215808864` |
| **Tenant ID** | `f8ac75ce-d250-407e-b8cb-e05f5b4cd913` |
| **Certificate Thumbprint** | `23B468A0F2F8A32B673F2CEBBCA9F00B7A3F10A6` |

### Entra ID Roles

The service principal has the following directory roles:

| Role | Purpose |
|------|---------|
| **Teams Administrator** | Full access to Teams admin center and PowerShell cmdlets |
| **Teams Telephony Administrator** | Manage voice and PSTN features |
| **Exchange Administrator** | Full access to Exchange Online management |

### API Permissions

| API | Permission | Type |
|-----|------------|------|
| Office 365 Exchange Online | `Exchange.ManageAsApp` | Application |
| Microsoft Graph | Various | Application |

### Certificate Storage

| Location | Purpose |
|----------|---------|
| Azure Key Vault (`acto-automation-kv`) | Secure storage, rotation, access control |
| Local Machine Certificate Store | Required for PowerShell modules to access |

---

## Connecting to Teams PowerShell

```powershell
Import-Module MicrosoftTeams

Connect-MicrosoftTeams `
    -ApplicationId "11b1509b-d570-4d3a-b46e-032215808864" `
    -TenantId "f8ac75ce-d250-407e-b8cb-e05f5b4cd913" `
    -CertificateThumbprint "23B468A0F2F8A32B673F2CEBBCA9F00B7A3F10A6"
```

### Prerequisites

```powershell
Install-Module MicrosoftTeams -Force -AllowClobber
```

---

## Connecting to Exchange Online

```powershell
Import-Module ExchangeOnlineManagement

Connect-ExchangeOnline `
    -AppId "11b1509b-d570-4d3a-b46e-032215808864" `
    -CertificateThumbprint "23B468A0F2F8A32B673F2CEBBCA9F00B7A3F10A6" `
    -Organization "a-cto.com" `
    -ShowBanner:$false
```

### Prerequisites

```powershell
Install-Module ExchangeOnlineManagement -Force -AllowClobber
```

**Note:** Exchange Online uses `-Organization` (your domain) instead of `-TenantId`.

---

## MCP Server Integration

### What is MCP?

Model Context Protocol (MCP) servers provide Claude Code with specialized tooling and context for specific domains. The Azure MCP server gives Claude:

- Azure best practices for code generation
- Direct access to Azure resource information
- Guidance for Teams/M365 operations

### Configuration

MCP servers are configured in Claude Code settings. The Azure MCP server is enabled for this workspace, providing:

- `mcp__azure__get_azure_bestpractices` - Best practices for Azure operations
- `mcp__azure__documentation` - Search Microsoft Learn docs
- `mcp__m365__*` - CLI for Microsoft 365 commands

### Usage in Practice

When managing Teams/Exchange via Claude Code:

1. Claude uses MCP tools to understand Azure/M365 best practices
2. Generates PowerShell commands using the appropriate module
3. Executes via Bash tool with `pwsh -Command '...'`
4. Service principal auth means no interactive prompts

---

## Common Teams Operations

### Get Auto Attendant Configuration

```powershell
$aa = Get-CsAutoAttendant | Where-Object { $_.Name -like "*ACTO*" }
$aa | Format-List
```

### Get Call Queue Configuration

```powershell
Get-CsCallQueue | Select-Object Name, Identity, RoutingMethod, AgentAlertTime
```

### Update Call Queue Agents

```powershell
$users = @(
    (Get-CsOnlineUser -Identity "user1@domain.com").Identity,
    (Get-CsOnlineUser -Identity "user2@domain.com").Identity
)
Set-CsCallQueue -Identity "<queue-id>" -Users $users
```

### Update Auto Attendant Greeting

```powershell
$aa = Get-CsAutoAttendant -Identity "<aa-id>"
$newGreeting = New-CsAutoAttendantPrompt -TextToSpeechPrompt "Your greeting text here"
$aa.DefaultCallFlow.Menu.Prompts = @($newGreeting)
Set-CsAutoAttendant -Instance $aa
```

---

## Common Exchange Operations

### List Mailboxes

```powershell
Get-Mailbox -ResultSize 10 | Select-Object DisplayName, PrimarySmtpAddress
```

### Get Mailbox Details

```powershell
Get-Mailbox -Identity "user@a-cto.com" | Format-List
```

### List Distribution Groups

```powershell
Get-DistributionGroup | Select-Object DisplayName, PrimarySmtpAddress
```

### Get Distribution Group Members

```powershell
Get-DistributionGroupMember -Identity "sales@a-cto.com" | Select-Object Name, PrimarySmtpAddress
```

### List Mail-Enabled Groups

```powershell
Get-UnifiedGroup | Select-Object DisplayName, PrimarySmtpAddress
```

### Get Mailbox Forwarding Rules

```powershell
Get-Mailbox -Identity "user@a-cto.com" | Select-Object ForwardingAddress, ForwardingSmtpAddress, DeliverToMailboxAndForward
```

### Get Inbox Rules

```powershell
Get-InboxRule -Mailbox "user@a-cto.com" | Select-Object Name, Enabled, Description
```

---

## Security Considerations

### Certificate Management

- Certificate is self-signed with 2-year expiration
- Stored in Azure Key Vault with access policies
- Only automation service accounts have access
- Rotate before expiration

### Principle of Least Privilege

The service principal has only the roles needed:
- No Global Administrator
- No SharePoint Administrator
- Scoped to Teams and Exchange only

### Audit Trail

All changes made via the service principal are logged in:
- Microsoft 365 Unified Audit Log
- Teams Admin Center audit logs
- Exchange Admin Center audit logs
- Entra ID sign-in logs (shows app authentication)

---

## Troubleshooting

### "Certificate not found" Error

Ensure certificate is installed in the correct store:
```powershell
Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.Thumbprint -eq "23B468A0F2F8A32B673F2CEBBCA9F00B7A3F10A6" }
```

### "Insufficient privileges" Error

Verify role assignments in Entra ID:
1. Go to Entra ID → Roles and administrators
2. Search for the required role (Teams Administrator, Exchange Administrator)
3. Confirm service principal is assigned

### "Role isn't supported" Error (Exchange)

Ensure the `Exchange.ManageAsApp` API permission is granted:
1. Go to Entra ID → App registrations → ACTO Internal Automation
2. API permissions → Verify "Office 365 Exchange Online - Exchange.ManageAsApp" has admin consent

### Connection Timeout

Both modules can be slow to connect. Use error handling:
```powershell
Connect-MicrosoftTeams ... -ErrorAction Stop
Connect-ExchangeOnline ... -ErrorAction Stop
```

---

## References

### Teams
- [Microsoft Teams PowerShell Overview](https://learn.microsoft.com/en-us/microsoftteams/teams-powershell-overview)
- [Application-based authentication in Teams PowerShell](https://learn.microsoft.com/en-us/microsoftteams/teams-powershell-application-authentication)

### Exchange
- [App-only authentication in Exchange Online PowerShell](https://learn.microsoft.com/en-us/powershell/exchange/app-only-auth-powershell-v2)
- [Exchange Online PowerShell Module](https://learn.microsoft.com/en-us/powershell/exchange/exchange-online-powershell)

### General
- [Azure Key Vault documentation](https://learn.microsoft.com/en-us/azure/key-vault/)
- [Model Context Protocol](https://modelcontextprotocol.io/)

# Teams Voice Automation Setup

This document describes the infrastructure used to manage Microsoft Teams Phone System programmatically, without interactive authentication.

---

## Overview

We use a **Service Principal** with **certificate-based authentication** to manage Teams configuration via PowerShell. This enables:

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
│  - Best practices for Azure/Teams operations                    │
├─────────────────────────────────────────────────────────────────┤
│  PowerShell + MicrosoftTeams Module                             │
│  - Connect-MicrosoftTeams with certificate auth                 │
│  - Manage Auto Attendants, Call Queues, Users                   │
├─────────────────────────────────────────────────────────────────┤
│  Service Principal (Entra ID App Registration)                  │
│  - Certificate stored in Azure Key Vault                        │
│  - Teams Administrator + Teams Telephony Administrator roles    │
├─────────────────────────────────────────────────────────────────┤
│  Microsoft Teams / Phone System                                 │
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

### Assigned Roles

The service principal has the following Entra ID directory roles:

- **Teams Administrator** - Full access to Teams admin center and PowerShell cmdlets
- **Teams Telephony Administrator** - Manage voice and PSTN features

### Certificate Storage

| Location | Purpose |
|----------|---------|
| Azure Key Vault (`acto-automation-kv`) | Secure storage, rotation, access control |
| Local Machine Certificate Store | Required for PowerShell module to access |

---

## Connecting to Teams PowerShell

### Non-Interactive Connection (Automation)

```powershell
Import-Module MicrosoftTeams

Connect-MicrosoftTeams `
    -ApplicationId "11b1509b-d570-4d3a-b46e-032215808864" `
    -TenantId "f8ac75ce-d250-407e-b8cb-e05f5b4cd913" `
    -CertificateThumbprint "23B468A0F2F8A32B673F2CEBBCA9F00B7A3F10A6"
```

### Prerequisites

1. **MicrosoftTeams PowerShell Module**
   ```powershell
   Install-Module MicrosoftTeams -Force -AllowClobber
   ```

2. **Certificate installed locally**
   - Must be in `Cert:\CurrentUser\My` or `Cert:\LocalMachine\My`
   - Private key must be accessible

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

When managing Teams via Claude Code:

1. Claude uses MCP tools to understand Azure/Teams best practices
2. Generates PowerShell commands using the MicrosoftTeams module
3. Executes via Bash tool with `pwsh -Command '...'`
4. Service principal auth means no interactive prompts

---

## Common Operations

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

## Security Considerations

### Certificate Management

- Certificate is self-signed with 2-year expiration
- Stored in Azure Key Vault with access policies
- Only automation service accounts have access
- Rotate before expiration

### Principle of Least Privilege

The service principal has only the roles needed for Teams management:
- No Global Administrator
- No Exchange Administrator
- No SharePoint Administrator

### Audit Trail

All changes made via the service principal are logged in:
- Microsoft 365 Unified Audit Log
- Teams Admin Center audit logs
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
2. Search for "Teams Administrator"
3. Confirm service principal is assigned

### Connection Timeout

The MicrosoftTeams module can be slow to connect. If timeouts occur:
```powershell
Connect-MicrosoftTeams ... -ErrorAction Stop
```

---

## References

- [Microsoft Teams PowerShell Overview](https://learn.microsoft.com/en-us/microsoftteams/teams-powershell-overview)
- [Application-based authentication in Teams PowerShell](https://learn.microsoft.com/en-us/microsoftteams/teams-powershell-application-authentication)
- [Azure Key Vault documentation](https://learn.microsoft.com/en-us/azure/key-vault/)
- [Model Context Protocol](https://modelcontextprotocol.io/)

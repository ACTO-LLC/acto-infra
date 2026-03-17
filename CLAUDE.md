# CLAUDE.md

## Repository Overview

This repo contains infrastructure-as-code and configuration for ACTO LLC's Microsoft 365 and Azure environments.

## Teams & Exchange PowerShell Authentication

**Always use certificate-based service principal auth** — never interactive login.

```powershell
# Teams
Import-Module MicrosoftTeams
Connect-MicrosoftTeams `
    -ApplicationId "11b1509b-d570-4d3a-b46e-032215808864" `
    -TenantId "f8ac75ce-d250-407e-b8cb-e05f5b4cd913" `
    -CertificateThumbprint "23B468A0F2F8A32B673F2CEBBCA9F00B7A3F10A6"

# Exchange Online
Import-Module ExchangeOnlineManagement
Connect-ExchangeOnline `
    -AppId "11b1509b-d570-4d3a-b46e-032215808864" `
    -CertificateThumbprint "23B468A0F2F8A32B673F2CEBBCA9F00B7A3F10A6" `
    -Organization "a-cto.com" `
    -ShowBanner:$false
```

The session does not persist between `pwsh -Command` invocations. When running multiple Teams/Exchange commands, chain them in a single `pwsh -Command` call or use a `.ps1` script.

## Key Identifiers

| Resource | ID |
|----------|-----|
| Tenant ID | `f8ac75ce-d250-407e-b8cb-e05f5b4cd913` |
| Service Principal (App ID) | `11b1509b-d570-4d3a-b46e-032215808864` |
| Cert Thumbprint | `23B468A0F2F8A32B673F2CEBBCA9F00B7A3F10A6` |
| Sales Queue | `5249573b-93fe-49d9-8b84-d0dc0fb7a178` |
| Support Queue | `18dada23-3862-4469-bc96-ea666217243b` |
| Main Phone Number | (657) 549-3882 |

## Service Principal Permission Limitations

The service principal can **read** Exchange mailbox data (rules, folders, leases) but **cannot write** to individual mailboxes. Specifically:

- `Get-InboxRule`, `Get-Mailbox`, `Get-MailboxFolderStatistics` — **work**
- `New-InboxRule`, `New-MailboxFolder` — **fail** with "Cannot open mailbox"
- Graph API `/users/{id}/mailFolders` and `/messageRules` — **fail** with "ErrorAccessDenied"

**Root cause:** The app registration lacks the `full_access_as_app` Exchange role and `Mail.ReadWrite` Graph permission. See [GitHub issue #12](../../issues/12) to track granting these.

**Workaround:** For per-mailbox write operations (inbox rules, folder creation), generate the PowerShell command and have the user run it from their own authenticated session.

## Project Structure

- `teams-voice/` — Teams Phone System config (auto attendants, call queues, voice routing)
- `teams-voice/docs/` — Documentation for voice setup, agent guides, automation
- `azure-avd-devbox/` — Azure Virtual Desktop and Dev Box configuration

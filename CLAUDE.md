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

## Service Principal Permissions

The service principal has the following permissions for mailbox operations:

- **Exchange:** `full_access_as_app` role, `Exchange.ManageAsApp` — EXO PowerShell read commands work (`Get-InboxRule`, `Get-Mailbox`, etc.)
- **Graph API:** `Mail.ReadWrite`, `MailboxSettings.ReadWrite` — enables inbox rule creation, mail folder management, and mailbox settings via Graph

**Important:** EXO PowerShell write commands (`New-InboxRule -Mailbox`) do NOT work because `ApplicationImpersonation` is deprecated. Use **Graph API** (via `Microsoft.Graph.Mail` module) for mailbox write operations instead. See `scripts/create-inbox-rule.ps1` for an example.

## Dev VM (Remote Commands)

When you need to run commands on the dev VM (e.g. Docker, checking services, managing projects), SSH in using:

```bash
ssh -i ~/.ssh/ehalsey-dev01-vm_key.pem ehalsey@ehalsey-dev01.westus2.cloudapp.azure.com "<command>"
```

Key facts:
- **Host:** `ehalsey-dev01.westus2.cloudapp.azure.com` (static IP: `4.154.42.33`)
- **User:** `ehalsey`
- **Key:** `~/.ssh/ehalsey-dev01-vm_key.pem`
- **OS:** Ubuntu Pro 24.04 LTS
- **Projects live on:** `/mnt/data/projects/`
- **Docker data:** `/mnt/data/docker-volumes/`
- **OpenEMR:** `/mnt/data/openemr/`
- **Subscription:** Microsoft Azure Sponsorship (`d487e16b-c758-4893-b0e9-a77c6e02e5f3`)
- **Resource Group:** `EHALSEY-DEV01-RG`
- **Key Vault:** `acto-infra-kv` (SSH key backed up as secret `ehalsey-dev01-vm-ssh-key`)

For multi-command operations, chain in a single SSH call or use `bash -s <<'REMOTE' ... REMOTE` to avoid session loss between invocations.

The VM auto-shuts down at 8 PM UTC. To start it:
```bash
az vm start -g EHALSEY-DEV01-RG -n ehalsey-dev01-vm --subscription "d487e16b-c758-4893-b0e9-a77c6e02e5f3"
```

## Project Structure

- `teams-voice/` — Teams Phone System config (auto attendants, call queues, voice routing)
- `teams-voice/docs/` — Documentation for voice setup, agent guides, automation
- `azure-avd-devbox/` — Azure Virtual Desktop and Dev Box configuration
- `azure-dev-vm/` — Ubuntu dev VM Bicep template and setup scripts

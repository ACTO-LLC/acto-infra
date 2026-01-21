# Teams Voice Setup - Left Off Here

**Date:** January 20, 2026

---

## Current Status: WAITING FOR PROPAGATION

We configured **Shared Calling** for all users. Microsoft documentation states changes can take **up to 30 minutes** to propagate.

### To Test
1. Wait 30 minutes from ~6:50 PM PST (around 7:20 PM PST)
2. Fully quit and restart Teams
3. Call **+1 657-549-3882**
4. Press **1** for Sales
5. Your Teams should ring

---

## What Was Configured Today

### 1. Service Principal for Automation (No More Interactive Auth!)
- **App ID:** `11b1509b-d570-4d3a-b46e-032215808864`
- **Tenant ID:** `f8ac75ce-d250-407e-b8cb-e05f5b4cd913`
- **Certificate Thumbprint:** `23B468A0F2F8A32B673F2CEBBCA9F00B7A3F10A6`
- **Roles:** Teams Administrator, Teams Telephony Administrator
- **Key Vault:** `acto-automation-kv`

```powershell
# Connect without interactive auth
Import-Module MicrosoftTeams
Connect-MicrosoftTeams -ApplicationId "11b1509b-d570-4d3a-b46e-032215808864" `
    -TenantId "f8ac75ce-d250-407e-b8cb-e05f5b4cd913" `
    -CertificateThumbprint "23B468A0F2F8A32B673F2CEBBCA9F00B7A3F10A6"
```

### 2. Licenses Added
- **Teams Phone Standard** for Eric, Quentin, and Sue
- Enterprise Voice enabled for all three

### 3. Shared Calling Configured
- Policy: `ACTO-SharedCalling`
- Resource Account: Auto Attendant (`autoattendant@a-cto.com`)
- Assigned to: Eric, Quentin, Sue

### 4. Auto Attendant Menu Swapped
- **Press 1 / "sales"** → Sales Queue
- **Press 2 / "support"** → Support Queue
- Greeting: "Thanks for calling A. C. T. O."

### 5. Sales Queue Configuration
- **Routing:** Serial (Eric → Quentin → Sue)
- **Agent Alert Time:** 15 seconds each
- **Presence-Based Routing:** Disabled
- **Conference Mode:** Disabled
- **Timeout:** 5 minutes → forwards to +1 949-296-5389

---

## If Calls Still Don't Ring After 30 Minutes

### Check in Teams Client
1. Go to **Settings** → **Calls**
2. Look for the shared number (+1 657-549-3882)
3. If not visible, the policy hasn't propagated yet

### Verify via PowerShell
```powershell
# Check user configuration
Get-CsOnlineUser -Identity "ehalsey@a-cto.com" | Select-Object DisplayName, EnterpriseVoiceEnabled, TeamsSharedCallingRoutingPolicy

# Should show:
# EnterpriseVoiceEnabled: True
# TeamsSharedCallingRoutingPolicy: ACTO-SharedCalling
```

### If Still Not Working
1. Try signing out of Teams completely and back in
2. Check Teams Admin Center for any errors: https://admin.teams.microsoft.com/voice/call-queues
3. Verify the Sales Queue shows all 3 agents

---

## Key Documentation Links

- [Plan for Shared Calling](https://learn.microsoft.com/en-us/microsoftteams/shared-calling-plan)
- [Configure Shared Calling](https://learn.microsoft.com/en-us/microsoftteams/shared-calling-setup)
- [Plan for Auto attendants and Call queues](https://learn.microsoft.com/en-us/microsoftteams/plan-auto-attendant-call-queue)

---

## Phone Numbers Reference

| Number | Assignment |
|--------|------------|
| +1 657-549-3882 | Auto Attendant (main line) |
| +1 657-549-1945 | Support Queue |
| +1 657-203-8478 | Unassigned |
| +1 657-203-8479 | Unassigned |
| +1 657-549-5669 | Unassigned |

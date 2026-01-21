# Teams Voice Setup - Left Off Here

**Date:** January 20, 2026

---

## Current Status: TESTING TIMEOUT FORWARDING

Configuration is complete. Need to verify that calls forward to Eric's cell after all agents decline.

### To Test
1. Call **+1 657-549-3882**
2. Press **1** for Sales (or **2** for Support)
3. Let all 3 agents ring for 15 seconds each (don't answer)
4. After 45 seconds total, call should forward to **+1 949-296-5389**

---

## Final Configuration (January 20, 2026)

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

### 4. Auto Attendant Menu
- **Press 1 / "sales"** -> Sales Queue
- **Press 2 / "support"** -> Support Queue
- **Say a name** -> Direct to Eric, Quentin, or Sue (not advertised)
- Greeting: "Thanks for calling A. C. T. O."

### 5. Sales Queue Configuration
- **Routing:** Serial (Quentin -> Eric -> Sue)
- **Agent Alert Time:** 15 seconds each
- **Timeout:** 45 seconds -> forwards to Eric (Teams voicemail)

### 6. Support Queue Configuration
- **Routing:** Serial (Eric -> Quentin -> Sue)
- **Agent Alert Time:** 15 seconds each
- **Timeout:** 45 seconds -> forwards to Eric (Teams voicemail)

---

## Important Limitations Discovered

| Setting | Limitation |
|---------|------------|
| Agent Alert Time | Minimum 15 seconds (max 180s) |
| Timeout Threshold | Must be multiple of 15 seconds |

---

## Phone Numbers Reference

| Number | Assignment |
|--------|------------|
| +1 657-549-3882 | Auto Attendant (main line) |
| +1 657-549-1945 | Support Queue |
| +1 657-203-8478 | Unassigned |
| +1 657-203-8479 | Unassigned |
| +1 657-549-5669 | Unassigned |

---

## Key Documentation Links

- [Plan for Shared Calling](https://learn.microsoft.com/en-us/microsoftteams/shared-calling-plan)
- [Configure Shared Calling](https://learn.microsoft.com/en-us/microsoftteams/shared-calling-setup)
- [Plan for Auto attendants and Call queues](https://learn.microsoft.com/en-us/microsoftteams/plan-auto-attendant-call-queue)

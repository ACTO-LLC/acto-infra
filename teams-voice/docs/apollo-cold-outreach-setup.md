# Apollo.io Cold Outreach Setup

**Date:** February 2, 2026

---

## Domain Registration

| Item | Value |
|------|-------|
| **Domain** | a-cto.co |
| **Registrar** | NameCheap |
| **Purpose** | Cold email outreach via Apollo.io |
| **Reason** | Protect primary domain (a-cto.com) reputation |

---

## Progress

### 1. Domain Added to Microsoft 365 ✅
- [x] Domain `a-cto.co` added via PowerShell/Graph API
- [x] TXT verification record added (`MS=ms82932474`)
- [x] Domain verified in M365

### 2. Standalone Mailbox Created ✅
- [x] ~~`quentin@a-cto.co` originally added as alias to Quentin Halsey's mailbox~~ (removed — Apollo.io requires a standalone mailbox for M365)
- [x] Alias removed from `quentin.halsey@a-cto.com`
- [x] Standalone Entra ID user created: `quentin@a-cto.co` (display: "Quentin Halsey (Outreach)")
- [x] Exchange Online Plan 1 license assigned
- User ID: `e8dcdd8b-39be-46e9-958a-f250a9397eb9`
- License: Exchange Online Plan 1 (`EXCHANGESTANDARD`)
- Password must be changed on first sign-in

### 3. DNS Records (NameCheap) ✅
- [x] TXT verification record
- [x] MX record
- [x] SPF record
- [x] Autodiscover CNAME
- [x] DMARC record
- [x] DKIM CNAME records (selector1, selector2)

### 4. DKIM Configuration ✅
- [x] DKIM signing config created in Exchange
- [x] DKIM CNAME records added to NameCheap
- [x] DKIM signing enabled

### 5. Warm Up the Domain
- [ ] Enable Apollo.io mailbox warmup feature
- [ ] Start with 10-20 emails/day
- [ ] Gradually increase over 2-4 weeks
- [ ] Monitor deliverability metrics

### 6. Connect to Apollo.io

#### Add Mailbox
1. Go to [Apollo.io](https://app.apollo.io) > **Settings** (gear icon)
2. Click **Email** > **Mailboxes**
3. Click **Add Mailbox**
4. Select **Microsoft 365 / Outlook**
5. Sign in with `quentin@a-cto.co` credentials
6. Grant Apollo.io permissions to send on your behalf

#### Configure Sending Settings
1. In Apollo.io > **Settings** > **Email** > **Mailboxes**
2. Click on the newly added mailbox
3. Set daily sending limits:
   - **Week 1-2:** 20 emails/day
   - **Week 3-4:** 40 emails/day
   - **Week 5+:** 75-100 emails/day (max recommended)
4. Set sending window (e.g., 8 AM - 6 PM recipient's timezone)
5. Enable **Track Opens** and **Track Clicks**

#### Enable Warmup
1. In the mailbox settings, toggle **Email Warmup** ON
2. Apollo will automatically send/receive warmup emails
3. Keep warmup running for 2-4 weeks before heavy outreach
4. Monitor warmup health score (aim for 90%+)

#### Create Email Sequence
1. Go to **Engage** > **Sequences**
2. Click **New Sequence**
3. Add steps (recommended starter):
   - **Step 1:** Initial outreach email (Day 0)
   - **Step 2:** Follow-up email (Day 3)
   - **Step 3:** Final follow-up (Day 7)
4. Set sequence settings:
   - Send as reply to previous step
   - Skip weekends
   - Stop on reply/meeting booked

---

## DNS Records for NameCheap

### Step 1: Verification Record (ADD THIS FIRST)

| Type | Host | Value | TTL |
|------|------|-------|-----|
| TXT | @ | `MS=ms82932474` | 3600 |

### Step 2: Email Records (after verification)

| Type | Host | Value | Priority | TTL |
|------|------|-------|----------|-----|
| MX | @ | `acto-co0c.mail.protection.outlook.com` | 0 | 3600 |
| TXT | @ | `v=spf1 include:spf.protection.outlook.com -all` | - | 3600 |
| CNAME | autodiscover | `autodiscover.outlook.com` | - | 3600 |

### Step 3: DMARC Record

| Type | Host | Value | TTL |
|------|------|-------|-----|
| TXT | _dmarc | `v=DMARC1; p=quarantine; rua=mailto:dmarc@a-cto.com` | 3600 |

### Step 4: DKIM Records

| Type | Host | Value | TTL |
|------|------|-------|-----|
| CNAME | selector1._domainkey | `selector1-acto-co0c._domainkey.ACTOLLC.w-v1.dkim.mail.microsoft` | 3600 |
| CNAME | selector2._domainkey | `selector2-acto-co0c._domainkey.ACTOLLC.w-v1.dkim.mail.microsoft` | 3600 |

### Optional: Teams/Skype Records (not needed for email-only)

| Type | Host | Value | Priority | Weight | Port | TTL |
|------|------|-------|----------|--------|------|-----|
| CNAME | sip | `sipdir.online.lync.com` | - | - | - | 3600 |
| CNAME | lyncdiscover | `webdir.online.lync.com` | - | - | - | 3600 |
| SRV | _sip._tls | `sipdir.online.lync.com` | 100 | 1 | 443 | 3600 |
| SRV | _sipfederationtls._tcp | `sipfed.online.lync.com` | 100 | 1 | 5061 | 3600 |

---

## Best Practices for Cold Outreach

1. **Never use primary domain** - a-cto.com is protected
2. **Warm up before heavy sending** - Reputation takes time to build
3. **Monitor bounce rates** - Keep under 2%
4. **Monitor spam complaints** - Keep under 0.1%
5. **Use unsubscribe links** - Required by law (CAN-SPAM, GDPR)
6. **Personalize emails** - Improves deliverability and response rates

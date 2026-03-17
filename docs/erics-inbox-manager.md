# Eric's Inbox Manager

Automated inbox filtering for ehalsey@a-cto.com. Moves low-signal emails to **Other\Read Later** so only client, internal, and direct emails remain in the inbox.

## Results

| Metric | Value |
|--------|-------|
| Inbox before | 6,465 |
| Inbox after | 2,051 |
| Emails moved to Read Later | 4,414 |
| Reduction | 68% |

## Rules

Implemented as 4 server-side inbox rules via Microsoft Graph API. Rules apply to all new incoming mail automatically.

### 1. Sender-based

Moves emails where the sender address contains any of:

| Keyword | Catches |
|---------|---------|
| `no-reply` | Generic no-reply senders |
| `donotreply` | Generic do-not-reply senders |
| `@substack.com` | Substack newsletters |
| `@prospera.hn` | Prosperity Press |
| `@zacks.com` | Zacks newsletters |
| `@zcm.zacks.com` | Zacks (subdomain) |
| `@lenovo.com` | Lenovo marketing |
| `@ecomm.lenovo.com` | Lenovo e-commerce |
| `@linkedin.com` | LinkedIn notifications |
| `@digital.costco.com` | Costco marketing |
| `@shop.tiktok.com` | TikTok Shop |
| `@rfpmart.com` | RFP alerts |
| `@campaign.eventbrite.com` | Eventbrite promos |
| `@npmjs.com` | npm incident notifications |
| `@emails.dailygopnews.com` | News digest |
| `@rightworks.com` | Vendor marketing |
| `@enowsoftware.com` | Vendor marketing |

### 2. Subject-based

Moves emails where the subject contains any of: `newsletter`, `posted new`, `deals`, `register`

### 3. info@ alias

Moves emails where the message headers contain `info@a-cto.com`. Emails sent to this alias are almost always spam/marketing since it's a public-facing address.

### 4. Unsubscribe in body

Moves emails where the body contains `unsubscribe`. Strong signal for marketing/bulk mail.

## Exceptions (apply to all rules)

Emails are **never** moved if:
- Subject contains: `PAS`, `MBC`, `KDIT`, `Bamert`, `SOW`, `invoice`, `contract`
- Email was sent only to Eric (direct/intentional)

## Automation

Rules are created and managed via `scripts/create-inbox-rule.ps1`. Re-run the script to reset all 4 rules (it deletes and recreates them).

The script uses the ACTO service principal with `Mail.ReadWrite` and `MailboxSettings.ReadWrite` Graph API permissions. See `CLAUDE.md` for auth details.

## Kept in inbox (intentional)

The following domains were reviewed and kept in inbox:
- `microsoft.com` / `promomail.microsoft.com` / `e-mails.microsoft.com` — Azure alerts and licensing notices mixed in
- `mailer.ingrammicro.com` — Vendor invoices mixed in
- `notification.capitalone.com` / `message.capitalone.com` — Financial notifications
- `e.linkedin.com` / `em.linkedin.com` — LinkedIn subdomains (kept with core `@linkedin.com` rule)
- `github.com` — CI/CD notifications mixed with marketing

## Tuning

To add new domains/keywords, update the rules via the Graph API or re-run `scripts/create-inbox-rule.ps1` after editing the sender/subject lists.

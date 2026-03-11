# Allowing Sender Domains in Exchange Online

Use Exchange Online **mail flow (transport) rules** to bypass spam filtering for a trusted sender domain and optionally release any messages that were already quarantined.

This is the inverse of [block-sender-domains.md](block-sender-domains.md).

---

## When to Use This

Use this when mail from a trusted domain is being:

- marked as spam
- quarantined by Microsoft 365
- consistently delayed or blocked by content filtering

Example: `mail.anthropic.com`

---

## Why This Approach

For this tenant, the most reliable fix is a **high-priority transport rule** that sets the spam confidence level to `-1` for the sender domain:

- `SenderDomainIs = <domain>`
- `SetSCL = -1`
- `StopRuleProcessing = $true`
- `Priority = 0`

This causes Exchange Online to treat matching messages as bypassing spam filtering.

---

## Prerequisites

- `ExchangeOnlineManagement` PowerShell module installed
- Service principal certificate auth configured
- Exchange administrator access via the automation app

See [automation-setup.md](automation-setup.md) for the authentication setup.

---

## Connect to Exchange Online

```powershell
Import-Module ExchangeOnlineManagement

Connect-ExchangeOnline `
    -AppId "11b1509b-d570-4d3a-b46e-032215808864" `
    -CertificateThumbprint "23B468A0F2F8A32B673F2CEBBCA9F00B7A3F10A6" `
    -Organization "a-cto.com" `
    -ShowBanner:$false
```

---

## 1) Check for Existing Rules or Policy Allow Lists

```powershell
Get-TransportRule | Select-Object Name, State, Priority | Sort-Object Priority

Get-HostedContentFilterPolicy |
    Select-Object Name, AllowedSenderDomains, AllowedSenders |
    Format-List
```

If there is already a specific allow rule for the domain, update it instead of creating a duplicate.

---

## 2) Create or Update the Allow Rule

Replace `<domain>` with the full sender domain.

```powershell
$domain = "mail.anthropic.com"
$ruleName = "Allow $domain"
$comments = "Bypass spam filtering for $domain"

$existing = Get-TransportRule -Identity $ruleName -ErrorAction SilentlyContinue

if ($null -eq $existing) {
    New-TransportRule `
        -Name $ruleName `
        -Comments $comments `
        -SenderDomainIs $domain `
        -SetSCL -1 `
        -StopRuleProcessing $true `
        -Priority 0
}
else {
    Set-TransportRule `
        -Identity $ruleName `
        -Comments $comments `
        -SenderDomainIs $domain `
        -SetSCL -1 `
        -StopRuleProcessing $true `
        -Priority 0
}
```

### Notes

- `SetSCL -1` is the key setting.
- `Priority 0` makes the rule run before lower-priority rules.
- `StopRuleProcessing $true` prevents later rules from overriding the allow action.

---

## 3) Verify the Rule

```powershell
Get-TransportRule -Identity "Allow mail.anthropic.com" |
    Format-List Name, State, Priority, SenderDomainIs, SetSCL, StopRuleProcessing, Comments
```

Expected values:

- `State`: `Enabled`
- `SenderDomainIs`: the trusted domain
- `SetSCL`: `-1`
- `StopRuleProcessing`: `True`

---

## 4) Find Matching Quarantined Messages

To review quarantined messages already affected:

```powershell
Get-QuarantineMessage `
    -SenderAddress "*@mail.anthropic.com" `
    -StartReceivedDate (Get-Date).AddDays(-30) `
    -PageSize 500 |
    Select-Object ReceivedTime, SenderAddress, RecipientAddress, Subject, Type, ReleaseStatus |
    Format-Table -Wrap -AutoSize
```

### Important

Use `-SenderAddress "*@mail.anthropic.com"` to match the actual envelope senders.

Using `-Domain "mail.anthropic.com"` may return unrelated results because that filter is broader than the sender address suffix.

---

## 5) Release Existing Quarantined Messages

```powershell
$msgs = Get-QuarantineMessage `
    -SenderAddress "*@mail.anthropic.com" `
    -StartReceivedDate (Get-Date).AddDays(-30) `
    -PageSize 500

if ($msgs.Count -gt 0) {
    $ids = @($msgs | Select-Object -ExpandProperty Identity)

    Release-QuarantineMessage `
        -ReleaseToAll `
        -Identities $ids `
        -ReportFalsePositive `
        -Force
}
```

After release, the messages may still appear in quarantine queries for a while, but their `ReleaseStatus` should show `RELEASED`.

---

## 6) Confirm the Release Status

```powershell
Get-QuarantineMessage `
    -SenderAddress "*@mail.anthropic.com" `
    -StartReceivedDate (Get-Date).AddDays(-30) `
    -PageSize 500 |
    Select-Object ReceivedTime, SenderAddress, ReleaseStatus, RecipientAddress, Subject |
    Format-Table -Wrap -AutoSize
```

---

## Full Example

```powershell
Import-Module ExchangeOnlineManagement

Connect-ExchangeOnline `
    -AppId "11b1509b-d570-4d3a-b46e-032215808864" `
    -CertificateThumbprint "23B468A0F2F8A32B673F2CEBBCA9F00B7A3F10A6" `
    -Organization "a-cto.com" `
    -ShowBanner:$false

$domain = "mail.anthropic.com"
$ruleName = "Allow $domain"
$comments = "Bypass spam filtering for $domain"

$existing = Get-TransportRule -Identity $ruleName -ErrorAction SilentlyContinue

if ($null -eq $existing) {
    New-TransportRule `
        -Name $ruleName `
        -Comments $comments `
        -SenderDomainIs $domain `
        -SetSCL -1 `
        -StopRuleProcessing $true `
        -Priority 0 | Out-Null
}
else {
    Set-TransportRule `
        -Identity $ruleName `
        -Comments $comments `
        -SenderDomainIs $domain `
        -SetSCL -1 `
        -StopRuleProcessing $true `
        -Priority 0 | Out-Null
}

$msgs = Get-QuarantineMessage `
    -SenderAddress "*@mail.anthropic.com" `
    -StartReceivedDate (Get-Date).AddDays(-30) `
    -PageSize 500

if ($msgs.Count -gt 0) {
    $ids = @($msgs | Select-Object -ExpandProperty Identity)
    Release-QuarantineMessage -ReleaseToAll -Identities $ids -ReportFalsePositive -Force | Out-Null
}

Get-TransportRule -Identity $ruleName |
    Format-List Name, State, Priority, SenderDomainIs, SetSCL, StopRuleProcessing, Comments

Disconnect-ExchangeOnline -Confirm:$false
```

---

## Remove the Allow Rule Later

```powershell
Remove-TransportRule -Identity "Allow mail.anthropic.com" -Confirm:$false
```

---

## Operational Lessons Learned

- Check **transport rules** first.
- Do not rely only on hosted content filter allow lists.
- Use `-SenderAddress "*@domain"` when searching quarantine for sender-domain cases.
- Release old quarantined items separately; the transport rule only affects future mail.
- Keep Exchange connection, rule creation, and quarantine release in the same PowerShell session.

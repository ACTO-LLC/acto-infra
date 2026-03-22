# Create "Low Priority - Auto File" inbox rules via Graph API
# Uses Mail.ReadWrite + MailboxSettings.ReadWrite Graph permissions
#
# NOTE: Graph API inbox rules AND conditions together, so we use
# separate rules per condition type to achieve OR logic.
#
# Rules created:
#   1. Sender-based    — no-reply, donotreply, marketing/vendor domains
#   2. Subject-based   — newsletter, posted new, deals, register
#   3. info@ alias     — emails sent to info@a-cto.com (junk alias)
#   4. Unsubscribe     — body contains "unsubscribe"

$tenantId = "f8ac75ce-d250-407e-b8cb-e05f5b4cd913"
$appId = "11b1509b-d570-4d3a-b46e-032215808864"
$thumbprint = "23B468A0F2F8A32B673F2CEBBCA9F00B7A3F10A6"
$mailbox = "ehalsey@a-cto.com"

Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Mail
Connect-MgGraph -ClientId $appId -TenantId $tenantId -CertificateThumbprint $thumbprint -NoWelcome

# Find "Read Later" folder
Write-Host "Searching for Read Later folder..."
$topFolders = Get-MgUserMailFolder -UserId $mailbox -All
$readLaterFolder = $null
foreach ($folder in $topFolders) {
    $children = Get-MgUserMailFolderChildFolder -UserId $mailbox -MailFolderId $folder.Id -All -ErrorAction SilentlyContinue
    foreach ($child in $children) {
        if ($child.DisplayName -eq "Read Later") { $readLaterFolder = $child; break }
    }
    if ($readLaterFolder) { break }
}
if (-not $readLaterFolder) { Write-Error "Read Later folder not found"; exit 1 }
Write-Host "Found folder: $($readLaterFolder.Id)"

# Shared exceptions
$exceptions = @{
    subjectContains = @("PAS", "MBC", "KDIT", "Bamert", "SOW", "invoice", "contract")
    sentOnlyToMe = $true
}

# Delete existing rules if re-running
$existing = Get-MgUserMailFolderMessageRule -UserId $mailbox -MailFolderId "Inbox" | Where-Object { $_.DisplayName -like "Low Priority - Auto File*" }
foreach ($r in $existing) {
    Remove-MgUserMailFolderMessageRule -UserId $mailbox -MailFolderId "Inbox" -MessageRuleId $r.Id
    Write-Host "Deleted: $($r.DisplayName)"
}

# Rule 1: Sender-based
Write-Host "Creating sender rule..."
New-MgUserMailFolderMessageRule -UserId $mailbox -MailFolderId "Inbox" -BodyParameter @{
    displayName = "Low Priority - Auto File (Sender)"
    sequence = 1; isEnabled = $true
    conditions = @{
        senderContains = @(
            "no-reply", "donotreply",
            "@substack.com", "@prospera.hn", "@zacks.com", "@lenovo.com", "@linkedin.com",
            "@ecomm.lenovo.com", "@digital.costco.com", "@shop.tiktok.com",
            "@zcm.zacks.com", "@rfpmart.com", "@campaign.eventbrite.com",
            "@npmjs.com", "@emails.dailygopnews.com",
            "@rightworks.com", "@enowsoftware.com"
        )
    }
    exceptions = $exceptions
    actions = @{ moveToFolder = $readLaterFolder.Id }
}

# Rule 2: Subject-based
Write-Host "Creating subject rule..."
New-MgUserMailFolderMessageRule -UserId $mailbox -MailFolderId "Inbox" -BodyParameter @{
    displayName = "Low Priority - Auto File (Subject)"
    sequence = 2; isEnabled = $true
    conditions = @{ subjectContains = @("newsletter", "posted new", "deals", "register") }
    exceptions = $exceptions
    actions = @{ moveToFolder = $readLaterFolder.Id }
}

# Rule 3: info@ alias
Write-Host "Creating info@ alias rule..."
New-MgUserMailFolderMessageRule -UserId $mailbox -MailFolderId "Inbox" -BodyParameter @{
    displayName = "Low Priority - Auto File (info@ alias)"
    sequence = 3; isEnabled = $true
    conditions = @{ headerContains = @("info@a-cto.com") }
    exceptions = $exceptions
    actions = @{ moveToFolder = $readLaterFolder.Id }
}

# Rule 4: Unsubscribe in body
Write-Host "Creating unsubscribe rule..."
New-MgUserMailFolderMessageRule -UserId $mailbox -MailFolderId "Inbox" -BodyParameter @{
    displayName = "Low Priority - Auto File (Unsubscribe)"
    sequence = 4; isEnabled = $true
    conditions = @{ bodyContains = @("unsubscribe") }
    exceptions = @{ subjectContains = $exceptions.subjectContains }
    actions = @{ moveToFolder = $readLaterFolder.Id }
}

Write-Host "`nDone!"
Get-MgUserMailFolderMessageRule -UserId $mailbox -MailFolderId "Inbox" | Where-Object { $_.DisplayName -like "Low Priority*" } | Format-Table DisplayName, IsEnabled, Sequence

# Create "Low Priority - Auto File" inbox rules via Graph API
# Uses Mail.ReadWrite + MailboxSettings.ReadWrite Graph permissions
#
# NOTE: Graph API inbox rules AND conditions together, so we split
# sender-based and subject-based matching into two separate rules
# to achieve OR logic.

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
        if ($child.DisplayName -eq "Read Later") {
            $readLaterFolder = $child
            Write-Host "Found: $($folder.DisplayName) / $($child.DisplayName)"
            break
        }
    }
    if ($readLaterFolder) { break }
}

if (-not $readLaterFolder) {
    Write-Error "Read Later folder not found"
    exit 1
}

# Shared exceptions for both rules
$exceptions = @{
    subjectContains = @("PAS", "MBC", "KDIT", "Bamert", "SOW", "invoice", "contract")
    sentOnlyToMe = $true
}

# Delete existing rules if re-running
$existing = Get-MgUserMailFolderMessageRule -UserId $mailbox -MailFolderId "Inbox" | Where-Object { $_.DisplayName -like "Low Priority - Auto File*" }
foreach ($r in $existing) {
    Remove-MgUserMailFolderMessageRule -UserId $mailbox -MailFolderId "Inbox" -MessageRuleId $r.Id
    Write-Host "Deleted existing rule: $($r.DisplayName)"
}

# Rule 1: Sender-based (no-reply, newsletter domains, marketing, vendor spam)
Write-Host "Creating sender rule..."
New-MgUserMailFolderMessageRule -UserId $mailbox -MailFolderId "Inbox" -BodyParameter @{
    displayName = "Low Priority - Auto File (Sender)"
    sequence = 1
    isEnabled = $true
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

# Rule 2: Subject-based (newsletter keywords)
Write-Host "Creating subject rule..."
New-MgUserMailFolderMessageRule -UserId $mailbox -MailFolderId "Inbox" -BodyParameter @{
    displayName = "Low Priority - Auto File (Subject)"
    sequence = 2
    isEnabled = $true
    conditions = @{
        subjectContains = @("newsletter", "posted new", "deals", "register")
    }
    exceptions = $exceptions
    actions = @{ moveToFolder = $readLaterFolder.Id }
}

Write-Host "`nDone! Verifying..."
Get-MgUserMailFolderMessageRule -UserId $mailbox -MailFolderId "Inbox" | Where-Object { $_.DisplayName -like "Low Priority*" } | Format-Table DisplayName, IsEnabled, Sequence

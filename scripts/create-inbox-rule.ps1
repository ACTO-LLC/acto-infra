# Create "Low Priority - Auto File" inbox rule via Graph API
# Uses full_access_as_app Exchange role + certificate auth

$tenantId = "f8ac75ce-d250-407e-b8cb-e05f5b4cd913"
$appId = "11b1509b-d570-4d3a-b46e-032215808864"
$thumbprint = "23B468A0F2F8A32B673F2CEBBCA9F00B7A3F10A6"
$mailbox = "ehalsey@a-cto.com"

# Connect to Graph with cert auth
Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Mail
Connect-MgGraph -ClientId $appId -TenantId $tenantId -CertificateThumbprint $thumbprint -NoWelcome

# Find "Read Later" folder - search all top-level folders and their children
Write-Host "Searching for Read Later folder..."
$topFolders = Get-MgUserMailFolder -UserId $mailbox -All
$readLaterFolder = $null

foreach ($folder in $topFolders) {
    $children = Get-MgUserMailFolderChildFolder -UserId $mailbox -MailFolderId $folder.Id -All -ErrorAction SilentlyContinue
    foreach ($child in $children) {
        if ($child.DisplayName -eq "Read Later") {
            $readLaterFolder = $child
            Write-Host "Found: $($folder.DisplayName) / $($child.DisplayName) (ID: $($child.Id))"
            break
        }
    }
    if ($readLaterFolder) { break }
}

if (-not $readLaterFolder) {
    Write-Error "Read Later folder not found"
    exit 1
}

# Create the inbox rule
Write-Host "Creating inbox rule..."
$ruleParams = @{
    displayName = "Low Priority - Auto File"
    sequence = 1
    isEnabled = $true
    conditions = @{
        senderContains = @("no-reply", "donotreply", "@substack.com", "@prospera.hn", "@zacks.com", "@lenovo.com", "@linkedin.com")
        subjectContains = @("newsletter", "posted new", "report", "deals", "register")
    }
    exceptions = @{
        subjectContains = @("PAS", "MBC", "KDIT", "Bamert", "SOW", "invoice", "contract")
        sentOnlyToMe = $true
    }
    actions = @{
        moveToFolder = $readLaterFolder.Id
    }
}

New-MgUserMailFolderMessageRule -UserId $mailbox -MailFolderId "Inbox" -BodyParameter $ruleParams

Write-Host "Done! Verifying..."
Get-MgUserMailFolderMessageRule -UserId $mailbox -MailFolderId "Inbox" | Where-Object { $_.DisplayName -eq "Low Priority - Auto File" } | Format-List DisplayName, IsEnabled, Sequence

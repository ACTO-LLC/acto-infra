Import-Module Microsoft.Graph.Mail -ErrorAction Stop
Connect-MgGraph -ClientId '11b1509b-d570-4d3a-b46e-032215808864' -TenantId 'f8ac75ce-d250-407e-b8cb-e05f5b4cd913' -CertificateThumbprint '23B468A0F2F8A32B673F2CEBBCA9F00B7A3F10A6' -NoWelcome

$mailbox = 'support@a-cto.com'
$bamertId = 'AAMkAGFlYzVjNzM2LWRkYWYtNDBjNi1hNjUzLWVjMDlhOGRlYWJiMQAuAAAAAACQ7r88mcnIQZr5OJe6eguAAQDLw8x_OebVTox3CG-WUywSAAAGEeljAAA='

$pinProp = 'SystemTime 0x0F01'
$expand = [uri]::EscapeDataString("singleValueExtendedProperties(`$filter=Id eq '$pinProp')")
$uri = "https://graph.microsoft.com/v1.0/users/$mailbox/mailFolders/$bamertId/messages?`$top=100&`$select=id,subject,from,receivedDateTime&`$expand=$expand"

$all = @()
$page = 0
do {
    $resp = Invoke-MgGraphRequest -Method GET -Uri $uri
    $all += $resp.value
    $uri = $resp.'@odata.nextLink'
    $page++
    Write-Host "Page $page`: fetched $($resp.value.Count) (total $($all.Count))"
} while ($uri)

# Debug: how many messages have svp key at all?
$withSvp = $all | Where-Object { $_.ContainsKey('singleValueExtendedProperties') }
Write-Host "Messages carrying singleValueExtendedProperties key: $($withSvp.Count)"
if ($withSvp.Count -gt 0) {
    $sample = $withSvp[0]
    Write-Host "Sample keys: $($sample.Keys -join ', ')"
    Write-Host "Sample svp type: $($sample['singleValueExtendedProperties'].GetType().FullName)"
    Write-Host "Sample svp content: $($sample['singleValueExtendedProperties'] | ConvertTo-Json -Compress -Depth 5)"
}

# A pinned message has 0x0F01 = 4500-09-01
$pinned = @()
foreach ($m in $all) {
    $svp = $m['singleValueExtendedProperties']
    if ($null -eq $svp) { continue }
    $arr = @($svp)
    if ($arr.Count -eq 0) { continue }
    $v = $arr[0]['value']
    if ($null -eq $v) { continue }
    # Value may deserialize as DateTime or remain string
    if ($v -is [DateTime]) {
        if ($v.Year -eq 4500) { $pinned += $m }
    } else {
        $vs = [string]$v
        if ($vs -match '^4500' -or $vs -match '/4500') { $pinned += $m }
    }
}
Write-Host ""
Write-Host "=== All pinned messages in folder ==="
Write-Host "Total pinned: $($pinned.Count)"
$pinned | ForEach-Object {
    $sender = $_.from.emailAddress.address
    $subj = $_.subject
    Write-Host "  [$($_.receivedDateTime)] $sender | $subj"
}

Write-Host ""
$brettPinned = $pinned | Where-Object { $_.from.emailAddress.address -eq 'bbamert@bamertseed.com' }
Write-Host "=== Pinned from bbamert@bamertseed.com (Brett): $($brettPinned.Count) ==="

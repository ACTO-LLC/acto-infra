Import-Module Microsoft.Graph.Mail -ErrorAction Stop
Connect-MgGraph -ClientId '11b1509b-d570-4d3a-b46e-032215808864' -TenantId 'f8ac75ce-d250-407e-b8cb-e05f5b4cd913' -CertificateThumbprint '23B468A0F2F8A32B673F2CEBBCA9F00B7A3F10A6' -NoWelcome

$mailbox = 'support@a-cto.com'
$bamertId = 'AAMkAGFlYzVjNzM2LWRkYWYtNDBjNi1hNjUzLWVjMDlhOGRlYWJiMQAuAAAAAACQ7r88mcnIQZr5OJe6eguAAQDLw8x_OebVTox3CG-WUywSAAAGEeljAAA='

# Fetch all messages in folder, expand pin property
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
    if ($page % 5 -eq 0) { Write-Host "Fetched $($all.Count) so far..." }
} while ($uri)
Write-Host "Total messages fetched: $($all.Count)"

# Filter to pinned Brett messages
$targets = @()
foreach ($m in $all) {
    if ($m.from.emailAddress.address -ne 'bbamert@bamertseed.com') { continue }
    $svp = $m['singleValueExtendedProperties']
    if ($null -eq $svp) { continue }
    $arr = @($svp); if ($arr.Count -eq 0) { continue }
    $v = $arr[0]['value']; if ($null -eq $v) { continue }
    $isPinned = $false
    if ($v -is [DateTime] -and $v.Year -eq 4500) { $isPinned = $true }
    elseif (([string]$v) -match '/4500|^4500') { $isPinned = $true }
    if ($isPinned) { $targets += $m }
}
Write-Host "Pinned Brett messages to unpin: $($targets.Count)"

if ($targets.Count -eq 0) { Write-Host "nothing to do"; exit }

$nowIso = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$body = @{
    singleValueExtendedProperties = @(
        @{ id = 'SystemTime 0x0F01'; value = $nowIso },
        @{ id = 'SystemTime 0x0F02'; value = $nowIso }
    )
} | ConvertTo-Json -Depth 5 -Compress

$ok = 0; $fail = 0; $i = 0
foreach ($t in $targets) {
    $i++
    $url = "https://graph.microsoft.com/v1.0/users/$mailbox/messages/$($t.id)"
    try {
        Invoke-MgGraphRequest -Method PATCH -Uri $url -Body $body -ContentType 'application/json' | Out-Null
        $ok++
        if ($i % 10 -eq 0) { Write-Host "  progress $i/$($targets.Count) ok=$ok fail=$fail" }
    } catch {
        $fail++
        Write-Host "  FAIL [$($t.receivedDateTime)] $($t.subject): $($_.Exception.Message)"
    }
}

Write-Host ""
Write-Host "Done. unpinned=$ok failed=$fail"

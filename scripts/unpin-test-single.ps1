Import-Module Microsoft.Graph.Mail -ErrorAction Stop
Connect-MgGraph -ClientId '11b1509b-d570-4d3a-b46e-032215808864' -TenantId 'f8ac75ce-d250-407e-b8cb-e05f5b4cd913' -CertificateThumbprint '23B468A0F2F8A32B673F2CEBBCA9F00B7A3F10A6' -NoWelcome

$mailbox = 'support@a-cto.com'
$bamertId = 'AAMkAGFlYzVjNzM2LWRkYWYtNDBjNi1hNjUzLWVjMDlhOGRlYWJiMQAuAAAAAACQ7r88mcnIQZr5OJe6eguAAQDLw8x_OebVTox3CG-WUywSAAAGEeljAAA='

# Pick the OLDEST pinned Brett message as the single test case (least risky to touch)
$pinProp = 'SystemTime 0x0F01'
$expand = [uri]::EscapeDataString("singleValueExtendedProperties(`$filter=Id eq '$pinProp')")
$filter = [uri]::EscapeDataString("from/emailAddress/address eq 'bbamert@bamertseed.com'")
$uri = "https://graph.microsoft.com/v1.0/users/$mailbox/mailFolders/$bamertId/messages?`$top=100&`$filter=$filter&`$select=id,subject,receivedDateTime&`$expand=$expand"

$resp = Invoke-MgGraphRequest -Method GET -Uri $uri
$pinned = @()
foreach ($m in $resp.value) {
    $svp = $m['singleValueExtendedProperties']
    if ($null -eq $svp) { continue }
    $arr = @($svp); if ($arr.Count -eq 0) { continue }
    $v = $arr[0]['value']; if ($null -eq $v) { continue }
    if ($v -is [DateTime] -and $v.Year -eq 4500) { $pinned += $m }
    elseif (([string]$v) -match '/4500|^4500') { $pinned += $m }
}
Write-Host "Candidate pinned Brett msgs (this page): $($pinned.Count)"
if ($pinned.Count -eq 0) { Write-Host "no candidates"; exit }

$target = $pinned[0]
Write-Host "Test target: $($target.receivedDateTime) | $($target.subject)"
Write-Host "Id: $($target.id)"

# Show current pin state
$nowIso = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$body = @{
    singleValueExtendedProperties = @(
        @{ id = 'SystemTime 0x0F01'; value = $nowIso },
        @{ id = 'SystemTime 0x0F02'; value = $nowIso }
    )
} | ConvertTo-Json -Depth 5

Write-Host ""
Write-Host "PATCH body:"
Write-Host $body

Write-Host ""
Write-Host "Sending PATCH..."
$url = "https://graph.microsoft.com/v1.0/users/$mailbox/messages/$($target.id)"
try {
    Invoke-MgGraphRequest -Method PATCH -Uri $url -Body $body -ContentType 'application/json' | Out-Null
    Write-Host "PATCH ok"
} catch {
    Write-Host "PATCH failed: $($_.Exception.Message)"
    exit 1
}

# Verify
$verifyExpand = [uri]::EscapeDataString("singleValueExtendedProperties(`$filter=Id eq 'SystemTime 0x0F01' or Id eq 'SystemTime 0x0F02')")
$v = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/users/$mailbox/messages/$($target.id)?`$expand=$verifyExpand&`$select=id,subject"
Write-Host ""
Write-Host "After PATCH:"
$v.singleValueExtendedProperties | ForEach-Object { Write-Host "  $($_.id) = $($_.value)" }

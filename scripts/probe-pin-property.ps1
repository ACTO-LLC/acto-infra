Import-Module Microsoft.Graph.Mail -ErrorAction Stop
Connect-MgGraph -ClientId '11b1509b-d570-4d3a-b46e-032215808864' -TenantId 'f8ac75ce-d250-407e-b8cb-e05f5b4cd913' -CertificateThumbprint '23B468A0F2F8A32B673F2CEBBCA9F00B7A3F10A6' -NoWelcome

$mailbox = 'support@a-cto.com'
$bamertId = 'AAMkAGFlYzVjNzM2LWRkYWYtNDBjNi1hNjUzLWVjMDlhOGRlYWJiMQAuAAAAAACQ7r88mcnIQZr5OJe6eguAAQDLw8x_OebVTox3CG-WUywSAAAGEeljAAA='

# Get top 5 recent messages; probe 0x0F01 and 0x0F02 on each
$resp = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/users/$mailbox/mailFolders/$bamertId/messages?`$top=5&`$orderby=receivedDateTime desc&`$select=id,subject,from"

$probes = @(
    'SystemTime 0x0F01',
    'SystemTime 0x0F02',
    'SystemTime 0x0F010040',
    'SystemTime 0xF01',
    'SystemTime 0xF02'
)
foreach ($m in $resp.value) {
    Write-Host ""
    Write-Host "=== $($m.from.emailAddress.address) | $($m.subject.Substring(0,[Math]::Min(50,$m.subject.Length))) ==="
    foreach ($p in $probes) {
        $escp = $p.Replace("'", "''")
        $url = "https://graph.microsoft.com/v1.0/users/$mailbox/messages/$($m.id)" + '?$expand=singleValueExtendedProperties($filter=' + [uri]::EscapeDataString("Id eq '$escp'") + ')&$select=id'
        try {
            $d = Invoke-MgGraphRequest -Method GET -Uri $url -ErrorAction Stop
            $have = $d.singleValueExtendedProperties
            if ($have -and $have.Count -gt 0 -and $null -ne $have[0].value) {
                Write-Host "  $p => $($have[0].value)"
            }
        } catch { }
    }
}

Import-Module Microsoft.Graph.Mail -ErrorAction Stop
Connect-MgGraph -ClientId '11b1509b-d570-4d3a-b46e-032215808864' -TenantId 'f8ac75ce-d250-407e-b8cb-e05f5b4cd913' -CertificateThumbprint '23B468A0F2F8A32B673F2CEBBCA9F00B7A3F10A6' -NoWelcome

$mailbox = 'ehalsey@a-cto.com'
$reports = @(
    @{ Label='Google';    Id='' ; Date='2026-04-21T09:43:00' },
    @{ Label='Microsoft'; Id='' ; Date='2026-04-21T02:05:23' }
)

# Find message IDs by subject
$search = [uri]::EscapeDataString('"dmarc"')
$resp = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/users/$mailbox/messages?`$top=20&`$search=$search&`$select=id,subject,from,receivedDateTime" -Headers @{ 'ConsistencyLevel'='eventual' }
Write-Host "Total search matches: $($resp.value.Count)"
$resp.value | ForEach-Object { Write-Host "  hit: $($_.receivedDateTime) $($_.from.emailAddress.address) | $($_.subject)" }
$today = (Get-Date).ToString('yyyy-MM-dd')
$todays = $resp.value | Where-Object {
    $d = $_['receivedDateTime']
    if ($d -is [DateTime]) { $d.ToString('yyyy-MM-dd') -eq $today }
    else { ([string]$d).StartsWith($today) }
}
Write-Host "Today's matches: $($todays.Count)"

foreach ($m in $todays) {
    $label = if ($m.from.emailAddress.address -match 'google') { 'Google' } elseif ($m.from.emailAddress.address -match 'microsoft') { 'Microsoft' } else { $m.from.emailAddress.address }
    Write-Host ""
    Write-Host "===== $label DMARC report ====="
    Write-Host "Subject: $($m.subject)"

    $atts = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/users/$mailbox/messages/$($m.id)/attachments"
    foreach ($a in $atts.value) {
        Write-Host "Attachment: $($a.name) ($($a.size) bytes)"
        $bytes = [Convert]::FromBase64String($a.contentBytes)
        $xml = $null
        if ($a.name -match '\.gz$') {
            $ms = New-Object System.IO.MemoryStream(,$bytes)
            $gz = New-Object System.IO.Compression.GZipStream($ms, [System.IO.Compression.CompressionMode]::Decompress)
            $sr = New-Object System.IO.StreamReader($gz)
            $xml = $sr.ReadToEnd()
        } elseif ($a.name -match '\.zip$') {
            $tmp = [IO.Path]::GetTempFileName() + '.zip'
            [IO.File]::WriteAllBytes($tmp, $bytes)
            $extDir = [IO.Path]::Combine([IO.Path]::GetTempPath(), [Guid]::NewGuid().ToString())
            Expand-Archive -LiteralPath $tmp -DestinationPath $extDir -Force
            $xmlFile = Get-ChildItem -Path $extDir -Filter *.xml -Recurse | Select-Object -First 1
            $xml = Get-Content $xmlFile.FullName -Raw
            Remove-Item $tmp,$extDir -Recurse -Force -ErrorAction SilentlyContinue
        } else {
            $xml = [System.Text.Encoding]::UTF8.GetString($bytes)
        }

        [xml]$doc = $xml
        $meta = $doc.feedback.report_metadata
        $policy = $doc.feedback.policy_published
        Write-Host "  Reporter: $($meta.org_name) <$($meta.email)>"
        Write-Host "  Report ID: $($meta.report_id)"
        $begin = [DateTimeOffset]::FromUnixTimeSeconds([int64]$meta.date_range.begin).UtcDateTime
        $end = [DateTimeOffset]::FromUnixTimeSeconds([int64]$meta.date_range.end).UtcDateTime
        Write-Host "  Date range: $begin UTC -> $end UTC"
        Write-Host "  Policy: domain=$($policy.domain) p=$($policy.p) sp=$($policy.sp) pct=$($policy.pct) adkim=$($policy.adkim) aspf=$($policy.aspf) rua=$($policy.rua)"

        $records = @($doc.feedback.record)
        $totalCount = ($records | ForEach-Object { [int]$_.row.count } | Measure-Object -Sum).Sum
        Write-Host "  Records: $($records.Count) rows, $totalCount total messages"
        foreach ($rec in $records) {
            $row = $rec.row
            $src = $row.source_ip
            $cnt = $row.count
            $disp = $row.policy_evaluated.disposition
            $dkimEval = $row.policy_evaluated.dkim
            $spfEval = $row.policy_evaluated.spf
            $hdrFrom = $rec.identifiers.header_from
            $dkimAuth = @($rec.auth_results.dkim) | ForEach-Object { "$($_.domain)/$($_.selector)=$($_.result)" }
            $spfAuth = @($rec.auth_results.spf) | ForEach-Object { "$($_.domain)=$($_.result)" }
            Write-Host ("    {0,-15} count={1,-4} disp={2,-10} dkim={3}/spf={4}  hdr_from={5}  dkim[{6}] spf[{7}]" -f $src,$cnt,$disp,$dkimEval,$spfEval,$hdrFrom,($dkimAuth -join ','),($spfAuth -join ','))
        }
    }
}

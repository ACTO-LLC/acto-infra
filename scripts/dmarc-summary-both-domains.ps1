$ErrorActionPreference = 'Stop'

Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
Connect-MgGraph -ClientId '11b1509b-d570-4d3a-b46e-032215808864' `
                -TenantId 'f8ac75ce-d250-407e-b8cb-e05f5b4cd913' `
                -CertificateThumbprint '23B468A0F2F8A32B673F2CEBBCA9F00B7A3F10A6' `
                -NoWelcome

$mailboxes = @('ehalsey@a-cto.com')  # dmarc@a-cto.com doesn't exist; a-cto.co rua has no cross-domain authz
$sinceUtc = (Get-Date).ToUniversalTime().AddDays(-3)
$sinceStr = $sinceUtc.ToString("yyyy-MM-ddTHH:mm:ssZ")

# Summary accumulators: key = "$policyDomain|$sourceIp|$hdrFrom|$dkimSummary|$spfSummary|$disp"
$summary = @{}

function Parse-Xml([string]$xml, [string]$mailbox, [string]$subject) {
    [xml]$doc = $xml
    $policy = $doc.feedback.policy_published
    $domain = [string]$policy.domain
    $meta = $doc.feedback.report_metadata
    $orgName = [string]$meta.org_name
    $beginUnix = [int64]$meta.date_range.begin
    $endUnix = [int64]$meta.date_range.end
    $begin = [DateTimeOffset]::FromUnixTimeSeconds($beginUnix).UtcDateTime
    $records = @($doc.feedback.record)
    foreach ($rec in $records) {
        $row = $rec.row
        $src = [string]$row.source_ip
        $cnt = [int]$row.count
        $disp = [string]$row.policy_evaluated.disposition
        $dkimEval = [string]$row.policy_evaluated.dkim
        $spfEval = [string]$row.policy_evaluated.spf
        $hdrFrom = [string]$rec.identifiers.header_from
        $dkimAuth = @($rec.auth_results.dkim) | ForEach-Object { "$($_.domain)=$($_.result)" } | Sort-Object -Unique
        $spfAuth = @($rec.auth_results.spf) | ForEach-Object { "$($_.domain)=$($_.result)" } | Sort-Object -Unique
        $key = "$domain|$src|$hdrFrom|$($dkimAuth -join ',')|$($spfAuth -join ',')|eval-dkim=$dkimEval/spf=$spfEval|$disp"
        if ($summary.ContainsKey($key)) {
            $summary[$key].Count += $cnt
            $summary[$key].Reporters.Add($orgName) | Out-Null
            if ($begin -lt $summary[$key].FirstSeen) { $summary[$key].FirstSeen = $begin }
        } else {
            $summary[$key] = [pscustomobject]@{
                PolicyDomain = $domain
                SourceIp     = $src
                HdrFrom      = $hdrFrom
                DkimAuth     = ($dkimAuth -join ',')
                SpfAuth      = ($spfAuth -join ',')
                EvalDkim     = $dkimEval
                EvalSpf      = $spfEval
                Disposition  = $disp
                Count        = $cnt
                Reporters    = [System.Collections.Generic.HashSet[string]]::new()
                FirstSeen    = $begin
            }
            $summary[$key].Reporters.Add($orgName) | Out-Null
        }
    }
}

foreach ($mailbox in $mailboxes) {
    Write-Host ""
    Write-Host "=== Pulling DMARC reports from $mailbox (since $sinceStr) ==="
    $filter = [uri]::EscapeDataString("receivedDateTime ge $sinceStr and (contains(subject,'DMARC') or contains(subject,'dmarc') or contains(subject,'Report Domain') or contains(subject,'report domain'))")
    # Use $top=100 and allow paging
    $url = "https://graph.microsoft.com/v1.0/users/$mailbox/messages?`$top=50&`$select=id,subject,from,receivedDateTime&`$filter=$filter"
    $seen = 0
    while ($url) {
        $resp = Invoke-MgGraphRequest -Method GET -Uri $url
        foreach ($m in $resp.value) {
            $seen++
            $atts = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/users/$mailbox/messages/$($m.id)/attachments"
            foreach ($a in $atts.value) {
                if (-not $a.contentBytes) { continue }
                $bytes = [Convert]::FromBase64String($a.contentBytes)
                $xml = $null
                try {
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
                        if ($xmlFile) { $xml = Get-Content $xmlFile.FullName -Raw }
                        Remove-Item $tmp,$extDir -Recurse -Force -ErrorAction SilentlyContinue
                    } elseif ($a.name -match '\.xml$') {
                        $xml = [System.Text.Encoding]::UTF8.GetString($bytes)
                    }
                    if ($xml) { Parse-Xml $xml $mailbox $m.subject }
                } catch {
                    Write-Host "  WARN: failed to parse $($a.name) in '$($m.subject)': $($_.Exception.Message)"
                }
            }
        }
        $url = $resp.'@odata.nextLink'
    }
    Write-Host "  Processed $seen messages"
}

# Reverse DNS helper
$ptrCache = @{}
function Get-Ptr([string]$ip) {
    if ($ptrCache.ContainsKey($ip)) { return $ptrCache[$ip] }
    $val = try { (Resolve-DnsName -Name $ip -Type PTR -ErrorAction Stop -QuickTimeout).NameHost -join ';' } catch { '' }
    if (-not $val) { $val = '(no PTR)' }
    $ptrCache[$ip] = $val
    return $val
}

# Print per-domain summary
foreach ($domain in @('a-cto.com','a-cto.co')) {
    Write-Host ""
    Write-Host "=================================================================="
    Write-Host "Summary for $domain (last 3 days)"
    Write-Host "=================================================================="
    $rows = $summary.Values | Where-Object { $_.PolicyDomain -eq $domain } | Sort-Object -Property Count -Descending
    if (-not $rows) { Write-Host "  (no data)"; continue }
    $total = ($rows | Measure-Object -Property Count -Sum).Sum
    Write-Host "Total reported messages: $total"
    Write-Host ""
    foreach ($r in $rows) {
        $ptr = Get-Ptr $r.SourceIp
        $aligned = if ($r.EvalDkim -eq 'pass' -or $r.EvalSpf -eq 'pass') { 'PASS' } else { 'FAIL' }
        Write-Host ("  src={0,-15} ptr={1}" -f $r.SourceIp, $ptr)
        Write-Host ("      count={0}  disp={1}  hdr_from={2}  dmarc={3}" -f $r.Count, $r.Disposition, $r.HdrFrom, $aligned)
        Write-Host ("      dkim_auth=[{0}]  spf_auth=[{1}]" -f $r.DkimAuth, $r.SpfAuth)
        Write-Host ("      reporters={0}" -f (($r.Reporters) -join ','))
        Write-Host ""
    }
}

Write-Host ""
Write-Host "=== Done ==="

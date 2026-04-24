$ErrorActionPreference = 'Stop'
$key = az keyvault secret show --vault-name acto-infra-kv --name sendgrid-api-key --query value -o tsv
if (-not $key) { throw 'API key not found' }
$headers = @{ Authorization = "Bearer $key" }

$domainId = 30612948

Write-Host '=== Resolving new CNAMEs from public DNS ==='
foreach ($n in 'em8708.a-cto.com','s1._domainkey.a-cto.com','s2._domainkey.a-cto.com') {
    $r = Resolve-DnsName $n -Type CNAME -Server 8.8.8.8 -ErrorAction SilentlyContinue
    if ($r) { $r | Where-Object { $_.Type -eq 'CNAME' } | ForEach-Object { Write-Host "  $n -> $($_.NameHost)" } }
    else { Write-Host "  $n -> (unresolved)" }
}

Write-Host ''
Write-Host "=== POST /v3/whitelabel/domains/$domainId/validate ==="
try {
    $resp = Invoke-RestMethod -Method POST -Uri "https://api.sendgrid.com/v3/whitelabel/domains/$domainId/validate" -Headers $headers
    Write-Host "valid: $($resp.valid)"
    Write-Host "id: $($resp.id)"
    Write-Host "per-record validation:"
    foreach ($k in $resp.validation_results.PSObject.Properties.Name) {
        $v = $resp.validation_results.$k
        Write-Host ("  {0,-12} valid={1}  reason={2}" -f $k, $v.valid, $v.reason)
    }
} catch {
    Write-Host "err: $($_.Exception.Message)"
    if ($_.ErrorDetails) { Write-Host $_.ErrorDetails.Message }
}

Write-Host ''
Write-Host '=== Final record state ==='
$detail = Invoke-RestMethod -Method GET -Uri "https://api.sendgrid.com/v3/whitelabel/domains/$domainId" -Headers $headers
Write-Host "domain=$($detail.domain) valid=$($detail.valid) default=$($detail.default) automatic_security=$($detail.automatic_security)"

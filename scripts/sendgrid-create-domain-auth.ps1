$ErrorActionPreference = 'Stop'
$key = az keyvault secret show --vault-name acto-infra-kv --name sendgrid-api-key --query value -o tsv
if (-not $key) { throw 'API key not found' }
$headers = @{ Authorization = "Bearer $key" }

$body = @{
    domain = 'a-cto.com'
    automatic_security = $true
    default = $true
} | ConvertTo-Json

Write-Host '=== POST /v3/whitelabel/domains ==='
Write-Host "body: $body"
try {
    $resp = Invoke-RestMethod -Method POST -Uri 'https://api.sendgrid.com/v3/whitelabel/domains' -Headers $headers -Body $body -ContentType 'application/json'
    Write-Host ""
    Write-Host "=== Created: id=$($resp.id) ==="
    $resp | ConvertTo-Json -Depth 8
    Write-Host ""
    Write-Host "=== Required DNS records ==="
    foreach ($k in $resp.dns.PSObject.Properties.Name) {
        $rec = $resp.dns.$k
        Write-Host ("  {0,-10} {1,-40} -> {2,-60}  valid={3}" -f $k, $rec.host, $rec.data, $rec.valid)
    }
} catch {
    Write-Host "err: $($_.Exception.Message)"
    if ($_.ErrorDetails) { Write-Host $_.ErrorDetails.Message }
}

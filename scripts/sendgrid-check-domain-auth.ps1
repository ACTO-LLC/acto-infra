$ErrorActionPreference = 'Stop'
$key = az keyvault secret show --vault-name acto-infra-kv --name sendgrid-api-key --query value -o tsv
if (-not $key) { throw 'API key not found in key vault' }
$headers = @{ Authorization = "Bearer $key" }

function Invoke-SG($method, $path, $body=$null) {
    $uri = "https://api.sendgrid.com$path"
    if ($body) {
        Invoke-RestMethod -Method $method -Uri $uri -Headers $headers -Body ($body | ConvertTo-Json -Depth 8) -ContentType 'application/json'
    } else {
        Invoke-RestMethod -Method $method -Uri $uri -Headers $headers
    }
}

Write-Host '=== Account identity ==='
try {
    $u = Invoke-SG GET '/v3/user/username'
    Write-Host "username: $($u.username)"
} catch { Write-Host "username err: $($_.Exception.Message)" }
try {
    $a = Invoke-SG GET '/v3/user/account'
    Write-Host "account type: $($a.type) reputation: $($a.reputation)"
} catch { Write-Host "account err: $($_.Exception.Message)" }
try {
    $subusers = Invoke-SG GET '/v3/subusers'
    Write-Host "subusers: $(@($subusers).Count)"
    $subusers | ForEach-Object { Write-Host "  - $($_.username) disabled=$($_.disabled) email=$($_.email)" }
} catch { Write-Host "subuser err: $($_.Exception.Message)" }

Write-Host ''
Write-Host '=== Raw domain authentication response ==='
$raw = Invoke-WebRequest -Method GET -Uri 'https://api.sendgrid.com/v3/whitelabel/domains?limit=50' -Headers $headers
Write-Host "status: $($raw.StatusCode)"
Write-Host "body:"
Write-Host $raw.Content

Write-Host ''
Write-Host '=== Default domain for ehalsey@a-cto.com ==='
try {
    $def = Invoke-SG GET '/v3/whitelabel/domains/default?domain=a-cto.com'
    $def | ConvertTo-Json -Depth 5
} catch { Write-Host "default err: $($_.Exception.Message)" }

Write-Host ''
Write-Host '=== Link branding ==='
try {
    $links = @(Invoke-SG GET '/v3/whitelabel/links?limit=50')
    Write-Host "count: $($links.Count)"
    $links | ForEach-Object { Write-Host ("  id={0} domain={1} subdomain={2} valid={3} default={4}" -f $_.id, $_.domain, $_.subdomain, $_.valid, $_.default) }
} catch { Write-Host "links err: $($_.Exception.Message)" }

$target = $domains | Where-Object { $_.domain -eq 'a-cto.com' }
if (-not $target) { Write-Host 'No entry for a-cto.com'; return }

Write-Host ''
Write-Host ("=== Full detail for a-cto.com (id={0}) ===" -f $target.id)
$detail = Invoke-SG GET "/v3/whitelabel/domains/$($target.id)"
$detail | ConvertTo-Json -Depth 8

Write-Host ''
Write-Host '=== DNS record validation states ==='
foreach ($recKey in 'mail_cname','dkim1','dkim2','dkim','spf') {
    $rec = $detail.dns.$recKey
    if ($rec) {
        Write-Host ("  {0,-12} valid={1,-5} host={2} -> data={3}" -f $recKey, $rec.valid, $rec.host, $rec.data)
    }
}

$ErrorActionPreference = 'Stop'

Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
Connect-MgGraph -ClientId '11b1509b-d570-4d3a-b46e-032215808864' `
                -TenantId 'f8ac75ce-d250-407e-b8cb-e05f5b4cd913' `
                -CertificateThumbprint '23B468A0F2F8A32B673F2CEBBCA9F00B7A3F10A6' `
                -NoWelcome

$apps = @(
    @{ Name='Apollo';                       AppId='f94ccf82-3918-4567-8a93-da0e5c2a51f7' },
    @{ Name='Apollo Teams Integration';     AppId='f678adb9-65c1-4a7d-8f56-945c6511b590' },
    @{ Name='Apollo.io (Dev - Chemi)';      AppId='324b447f-5115-4f34-9376-104616be12f2' }
)

# Cache for user resolution
$userCache = @{}
function Resolve-User([string]$id) {
    if (-not $id) { return '(tenant-wide / admin consent)' }
    if ($userCache.ContainsKey($id)) { return $userCache[$id] }
    try {
        $u = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/users/$id`?`$select=userPrincipalName,displayName,accountEnabled"
        $label = "$($u.displayName) <$($u.userPrincipalName)> enabled=$($u.accountEnabled)"
    } catch {
        $label = "(user $id - lookup failed: $($_.Exception.Message))"
    }
    $userCache[$id] = $label
    return $label
}

foreach ($app in $apps) {
    Write-Host ""
    Write-Host "=================================================================="
    Write-Host "$($app.Name)  (appId=$($app.AppId))"
    Write-Host "=================================================================="

    # Look up SP object id
    $filter = [uri]::EscapeDataString("appId eq '$($app.AppId)'")
    $spResp = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=$filter"
    $sp = $spResp.value | Select-Object -First 1
    if (-not $sp) { Write-Host "  (service principal not found)"; continue }
    Write-Host "SP objectId      : $($sp.id)"
    Write-Host "displayName      : $($sp.displayName)"
    Write-Host "publisherName    : $($sp.publisherName)"
    Write-Host "homepage         : $($sp.homepage)"
    Write-Host "accountEnabled   : $($sp.accountEnabled)"
    Write-Host "appOwnerOrgId    : $($sp.appOwnerOrganizationId)"
    Write-Host "signInAudience   : $($sp.signInAudience)"

    Write-Host ""
    Write-Host "-- oauth2PermissionGrants (delegated consents) --"
    $grantFilter = [uri]::EscapeDataString("clientId eq '$($sp.id)'")
    $grants = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/oauth2PermissionGrants?`$filter=$grantFilter"
    if (-not $grants.value -or $grants.value.Count -eq 0) {
        Write-Host "  (none)"
    } else {
        foreach ($g in $grants.value) {
            $who = if ($g.consentType -eq 'AllPrincipals') { 'ALL USERS (admin consent)' } else { Resolve-User $g.principalId }
            # Resolve resource SP name
            try {
                $rsp = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/$($g.resourceId)`?`$select=displayName,appId"
                $resourceLabel = "$($rsp.displayName) (appId=$($rsp.appId))"
            } catch { $resourceLabel = $g.resourceId }
            Write-Host "  grantId     : $($g.id)"
            Write-Host "  resource    : $resourceLabel"
            Write-Host "  consentType : $($g.consentType)"
            Write-Host "  principal   : $who"
            Write-Host "  scope       : $($g.scope)"
            Write-Host ""
        }
    }

    Write-Host "-- appRoleAssignedTo (users/groups explicitly assigned to this app) --"
    $assignments = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/$($sp.id)/appRoleAssignedTo"
    if (-not $assignments.value -or $assignments.value.Count -eq 0) {
        Write-Host "  (none)"
    } else {
        foreach ($a in $assignments.value) {
            Write-Host "  principalType=$($a.principalType) principal=$($a.principalDisplayName) id=$($a.principalId)"
        }
    }
}

Write-Host ""
Write-Host "=== Done ==="

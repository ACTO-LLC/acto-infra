$ErrorActionPreference = 'Stop'

$spObjectId = 'e3b872ca-328a-4116-959d-e73260298290'  # Apollo.io (Dev - Chemi)
$grantIds = @(
    'ynK444oyFkGVnecyYCmCkPClKtu38gNIqZ3Yw2Psr_A',  # Graph openid email profile offline_access
    'ynK444oyFkGVnecyYCmCkOUkbVjMPttFnDJyCasdKT4'   # Dataverse user_impersonation
)
$assignmentUserId = '4eeeae76-a021-472d-a233-e660c1a10a2f'  # Quentin

Write-Host '=== Pre-state ==='
az rest --method GET --url "https://graph.microsoft.com/v1.0/servicePrincipals/$spObjectId`?`$select=displayName,accountEnabled,appId" -o json

Write-Host ''
Write-Host '=== Step 1: disable service principal (accountEnabled=false) ==='
$body = '{"accountEnabled": false}'
az rest --method PATCH --url "https://graph.microsoft.com/v1.0/servicePrincipals/$spObjectId" --headers 'Content-Type=application/json' --body $body
Write-Host 'PATCH sent.'

Write-Host ''
Write-Host '=== Step 2: delete oauth2PermissionGrants (delegated consents) ==='
foreach ($gid in $grantIds) {
    Write-Host "DELETE oauth2PermissionGrants/$gid"
    az rest --method DELETE --url "https://graph.microsoft.com/v1.0/oauth2PermissionGrants/$gid"
}

Write-Host ''
Write-Host '=== Step 3: remove appRoleAssignedTo (Quentin) ==='
# Need to look up the assignment id first
$assignments = az rest --method GET --url "https://graph.microsoft.com/v1.0/servicePrincipals/$spObjectId/appRoleAssignedTo" -o json | ConvertFrom-Json
foreach ($a in $assignments.value) {
    if ($a.principalId -eq $assignmentUserId) {
        Write-Host "DELETE appRoleAssignments/$($a.id)  (principal=$($a.principalDisplayName))"
        az rest --method DELETE --url "https://graph.microsoft.com/v1.0/servicePrincipals/$spObjectId/appRoleAssignedTo/$($a.id)"
    }
}

Write-Host ''
Write-Host '=== Post-state ==='
az rest --method GET --url "https://graph.microsoft.com/v1.0/servicePrincipals/$spObjectId`?`$select=displayName,accountEnabled,appId" -o json

$grantFilter = [uri]::EscapeDataString("clientId eq '$spObjectId'")
Write-Host ''
Write-Host 'Remaining oauth2 grants:'
az rest --method GET --url "https://graph.microsoft.com/v1.0/oauth2PermissionGrants?`$filter=$grantFilter" -o json

Write-Host ''
Write-Host 'Remaining appRoleAssignedTo:'
az rest --method GET --url "https://graph.microsoft.com/v1.0/servicePrincipals/$spObjectId/appRoleAssignedTo" -o json

Write-Host ''
Write-Host '=== Done ==='

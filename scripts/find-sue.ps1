Import-Module Microsoft.Graph.Authentication -ErrorAction SilentlyContinue
Connect-MgGraph -TenantId 'f8ac75ce-d250-407e-b8cb-e05f5b4cd913' `
    -ClientId '11b1509b-d570-4d3a-b46e-032215808864' `
    -CertificateThumbprint '23B468A0F2F8A32B673F2CEBBCA9F00B7A3F10A6' `
    -NoWelcome

$uri = "https://graph.microsoft.com/v1.0/users?`$filter=startswith(displayName,'Sue')&`$select=id,displayName,mail,userPrincipalName"
$r = Invoke-MgGraphRequest -Method GET -Uri $uri
$r.value | ForEach-Object { "$($_.displayName) | UPN=$($_.userPrincipalName) | mail=$($_.mail)" }

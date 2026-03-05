Import-Module PnP.PowerShell
Import-Module MSAL.PS

$appId      = "11b1509b-d570-4d3a-b46e-032215808864"
$tenantId   = "f8ac75ce-d250-407e-b8cb-e05f5b4cd913"
$thumbprint = "23B468A0F2F8A32B673F2CEBBCA9F00B7A3F10A6"
$cert       = Get-ChildItem -Path "Cert:\CurrentUser\My" | Where-Object { $_.Thumbprint -eq $thumbprint }

$totalUpdated = 0
$totalErrors  = 0

# ── Get Graph token and enumerate users ──
$graphToken = (Get-MsalToken -ClientId $appId -TenantId $tenantId -ClientCertificate $cert -Scopes "https://graph.microsoft.com/.default").AccessToken
$graphHeaders = @{ "Authorization" = "Bearer $graphToken" }

$usersResp = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/users?`$filter=accountEnabled eq true&`$select=id,displayName,userPrincipalName&`$top=999" -Headers $graphHeaders -Method GET
$users = $usersResp.value
Write-Host "Found $($users.Count) users"

# ── Part 1: OneDrive recordings ──
Write-Host "`n=== Processing OneDrive recordings ==="

$spToken = (Get-MsalToken -ClientId $appId -TenantId $tenantId -ClientCertificate $cert -Scopes "https://actollc-my.sharepoint.com/.default").AccessToken

foreach ($user in $users) {
    $upn = $user.userPrincipalName
    $siteSlug = $upn -replace '@', '_' -replace '\.', '_'
    $siteUrl = "https://actollc-my.sharepoint.com/personal/$siteSlug"

    Write-Host "`n  $upn"

    $spHeaders = @{
        "Authorization" = "Bearer $spToken"
        "Accept"       = "application/json;odata=verbose"
    }

    # Get Documents list GUID
    try {
        $listResp = Invoke-RestMethod -Uri "$siteUrl/_api/web/lists?`$filter=BaseTemplate eq 700&`$select=Id,ItemCount&`$top=1" -Headers $spHeaders -Method GET -ErrorAction Stop
        if ($listResp.d.results.Count -eq 0) {
            Write-Host "    No OneDrive. Skipping."
            continue
        }
        $listGuid = $listResp.d.results[0].Id
    }
    catch {
        Write-Host "    No OneDrive. Skipping."
        continue
    }

    # Check Recordings folder
    try {
        $null = Invoke-RestMethod -Uri "$siteUrl/_api/web/GetFolderByServerRelativeUrl('/personal/$siteSlug/Documents/Recordings')?`$select=ItemCount" -Headers $spHeaders -Method GET -ErrorAction Stop
    }
    catch {
        Write-Host "    No Recordings folder. Skipping."
        continue
    }

    # Find items with expiration via RenderListDataAsStream
    $spHeaders2 = @{
        "Authorization" = "Bearer $spToken"
        "Accept"       = "application/json;odata=verbose"
        "Content-Type" = "application/json;odata=verbose"
    }

    $renderUrl = "$siteUrl/_api/web/lists(guid'$listGuid')/RenderListDataAsStream"
    $renderBody = @{
        parameters = @{
            __metadata = @{ type = "SP.RenderListDataParameters" }
            RenderOptions = 2
            ViewXml = "<View><Query><Where><Eq><FieldRef Name='FSObjType'/><Value Type='Integer'>0</Value></Eq></Where><OrderBy><FieldRef Name='ID' Ascending='FALSE'/></OrderBy></Query><ViewFields><FieldRef Name='FileLeafRef'/><FieldRef Name='_ExpirationDate'/><FieldRef Name='ID'/><FieldRef Name='FileRef'/></ViewFields><RowLimit>200</RowLimit></View>"
            FolderServerRelativeUrl = "/personal/$siteSlug/Documents/Recordings"
        }
    } | ConvertTo-Json -Depth 5

    try {
        $renderResp = Invoke-RestMethod -Uri $renderUrl -Headers $spHeaders2 -Method POST -Body $renderBody
    }
    catch {
        Write-Host "    Error fetching recordings: $($_.Exception.Message)"
        continue
    }

    $expiring = @()
    foreach ($row in $renderResp.Row) {
        $exp = $row.'_ExpirationDate'
        if ($exp -and $exp -ne '') {
            $expiring += $row
        }
    }

    if ($expiring.Count -eq 0) {
        Write-Host "    No recordings with expiration dates. ($($renderResp.Row.Count) total)"
        continue
    }

    Write-Host "    Found $($expiring.Count) recording(s) with expiration (out of $($renderResp.Row.Count) total)"

    # Connect PnP and clear
    Connect-PnPOnline -Url $siteUrl -ClientId $appId -Thumbprint $thumbprint -Tenant "a-cto.com"
    $ctx = Get-PnPContext

    foreach ($row in $expiring) {
        $fileRef = $row.FileRef
        $fileName = $row.FileLeafRef
        $expDate = $row.'_ExpirationDate'

        Write-Host "      Clearing: $fileName (expires: $expDate)"
        try {
            $file = $ctx.Web.GetFileByServerRelativeUrl($fileRef)
            $ctx.Load($file)
            $ctx.Load($file.Properties)
            $ctx.ExecuteQuery()

            $file.Properties["vti_expirationdate"] = $null
            $file.Update()
            $ctx.ExecuteQuery()

            $totalUpdated++
        }
        catch {
            Write-Host "        ERROR: $($_.Exception.Message)"
            $totalErrors++
        }
    }

    Disconnect-PnPOnline
}

# ── Part 2: Teams channel recordings ──
Write-Host "`n=== Processing Teams channel recordings ==="

$graphToken = (Get-MsalToken -ClientId $appId -TenantId $tenantId -ClientCertificate $cert -Scopes "https://graph.microsoft.com/.default").AccessToken
$graphHeaders = @{ "Authorization" = "Bearer $graphToken" }

$groupsResp = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/groups?`$filter=resourceProvisioningOptions/Any(x:x eq 'Team')&`$select=id,displayName&`$top=999" -Headers $graphHeaders -Method GET

foreach ($group in $groupsResp.value) {
    Write-Host "`n  Team: $($group.displayName)"

    try {
        $siteResp = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/groups/$($group.id)/sites/root?`$select=webUrl" -Headers $graphHeaders -Method GET
        $teamSiteUrl = $siteResp.webUrl
    }
    catch {
        Write-Host "    No site. Skipping."
        continue
    }

    $siteHost = ([Uri]$teamSiteUrl).Host
    $teamSpToken = (Get-MsalToken -ClientId $appId -TenantId $tenantId -ClientCertificate $cert -Scopes "https://$siteHost/.default").AccessToken
    $teamSpHeaders = @{
        "Authorization" = "Bearer $teamSpToken"
        "Accept" = "application/json;odata=verbose"
    }

    try {
        $listResp = Invoke-RestMethod -Uri "$teamSiteUrl/_api/web/lists/getbytitle('Documents')?`$select=Id" -Headers $teamSpHeaders -Method GET
        $listGuid = $listResp.d.Id
        $siteRelPath = ([Uri]$teamSiteUrl).AbsolutePath

        # Find channel folders
        $foldersResp = Invoke-RestMethod -Uri "$teamSiteUrl/_api/web/GetFolderByServerRelativeUrl('$siteRelPath/Shared Documents')/Folders?`$select=Name,ServerRelativeUrl&`$top=100" -Headers $teamSpHeaders -Method GET

        foreach ($channelFolder in $foldersResp.d.results) {
            try {
                $recFolder = Invoke-RestMethod -Uri "$teamSiteUrl/_api/web/GetFolderByServerRelativeUrl('$($channelFolder.ServerRelativeUrl)/Recordings')?`$select=ItemCount" -Headers $teamSpHeaders -Method GET
                if ($recFolder.d.ItemCount -eq 0) { continue }
            }
            catch { continue }

            Write-Host "    Channel: $($channelFolder.Name) ($($recFolder.d.ItemCount) items)"

            $teamSpHeaders2 = @{
                "Authorization" = "Bearer $teamSpToken"
                "Accept"       = "application/json;odata=verbose"
                "Content-Type" = "application/json;odata=verbose"
            }

            $renderUrl = "$teamSiteUrl/_api/web/lists(guid'$listGuid')/RenderListDataAsStream"
            $renderBody = @{
                parameters = @{
                    __metadata = @{ type = "SP.RenderListDataParameters" }
                    RenderOptions = 2
                    ViewXml = "<View><Query><Where><Eq><FieldRef Name='FSObjType'/><Value Type='Integer'>0</Value></Eq></Where></Query><ViewFields><FieldRef Name='FileLeafRef'/><FieldRef Name='_ExpirationDate'/><FieldRef Name='ID'/><FieldRef Name='FileRef'/></ViewFields><RowLimit>200</RowLimit></View>"
                    FolderServerRelativeUrl = "$($channelFolder.ServerRelativeUrl)/Recordings"
                }
            } | ConvertTo-Json -Depth 5

            $renderResp = Invoke-RestMethod -Uri $renderUrl -Headers $teamSpHeaders2 -Method POST -Body $renderBody

            $expiring = @()
            foreach ($row in $renderResp.Row) {
                $exp = $row.'_ExpirationDate'
                if ($exp -and $exp -ne '') { $expiring += $row }
            }

            if ($expiring.Count -eq 0) {
                Write-Host "      No recordings with expiration."
                continue
            }

            Write-Host "      Found $($expiring.Count) with expiration"

            Connect-PnPOnline -Url $teamSiteUrl -ClientId $appId -Thumbprint $thumbprint -Tenant "a-cto.com"
            $ctx = Get-PnPContext

            foreach ($row in $expiring) {
                Write-Host "        Clearing: $($row.FileLeafRef) (expires: $($row.'_ExpirationDate'))"
                try {
                    $file = $ctx.Web.GetFileByServerRelativeUrl($row.FileRef)
                    $ctx.Load($file)
                    $ctx.Load($file.Properties)
                    $ctx.ExecuteQuery()
                    $file.Properties["vti_expirationdate"] = $null
                    $file.Update()
                    $ctx.ExecuteQuery()
                    $totalUpdated++
                }
                catch {
                    Write-Host "          ERROR: $($_.Exception.Message)"
                    $totalErrors++
                }
            }

            Disconnect-PnPOnline
        }
    }
    catch {
        Write-Host "    Error: $($_.Exception.Message)"
    }
}

Write-Host "`n========================================="
Write-Host "=== SUMMARY ==="
Write-Host "  Recordings updated: $totalUpdated"
Write-Host "  Errors: $totalErrors"
Write-Host "========================================="

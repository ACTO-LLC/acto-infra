Import-Module Microsoft.Graph.Authentication -ErrorAction SilentlyContinue
Connect-MgGraph -TenantId 'f8ac75ce-d250-407e-b8cb-e05f5b4cd913' `
    -ClientId '11b1509b-d570-4d3a-b46e-032215808864' `
    -CertificateThumbprint '23B468A0F2F8A32B673F2CEBBCA9F00B7A3F10A6' `
    -NoWelcome

$user = 'shalsey@a-cto.com'
$id   = 'AAMkADE3ODE2ZGRiLTIxMGEtNDg2Mi05YWVkLTcxOGJiYzdkOTAwNgBGAAAAAACE1gYtvBfoSbu9PNErykkDBwAhac4I61QCSryE4KDLo7TEAAAAAAEMAAAhac4I61QCSryE4KDLo7TEAALG6en-AAA='
$uri  = "https://graph.microsoft.com/v1.0/users/$user/messages/$id" +
        '?$select=subject,from,sender,toRecipients,ccRecipients,replyTo,receivedDateTime,internetMessageId,internetMessageHeaders,body,bodyPreview'
$m = Invoke-MgGraphRequest -Method GET -Uri $uri

"=== HEADERS ==="
"Subject:         $($m.subject)"
"From:            $($m.from.emailAddress.address)  ($($m.from.emailAddress.name))"
"Sender:          $($m.sender.emailAddress.address)"
"Reply-To:        $(($m.replyTo | ForEach-Object { $_.emailAddress.address }) -join ', ')"
"To:              $(($m.toRecipients | ForEach-Object { $_.emailAddress.address }) -join ', ')"
"Cc:              $(($m.ccRecipients | ForEach-Object { $_.emailAddress.address }) -join ', ')"
"Received:        $($m.receivedDateTime)"
"MessageId:       $($m.internetMessageId)"

"`n=== KEY INTERNET HEADERS ==="
$keep = @('Authentication-Results','DKIM-Signature','Received-SPF','Return-Path','X-Sender-IP','X-Originating-IP','X-Mailer','List-Unsubscribe','X-MS-Exchange-Organization-AuthAs','X-MS-Exchange-Organization-AuthSource','X-MS-Exchange-CrossTenant-AuthSource','X-Forefront-Antispam-Report','X-Microsoft-Antispam')
foreach ($h in $m.internetMessageHeaders) {
    if ($keep -contains $h.name) {
        "$($h.name): $($h.value)"
    }
}

"`n=== BODY (preview) ==="
$m.bodyPreview

"`n=== BODY (full, text) ==="
# strip HTML tags for readability
$txt = $m.body.content -replace '<[^>]+>',' '
$txt = [System.Web.HttpUtility]::HtmlDecode($txt)
$txt = ($txt -replace '\s+',' ').Trim()
$txt

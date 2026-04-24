$ErrorActionPreference = 'Stop'

Import-Module ExchangeOnlineManagement
Connect-ExchangeOnline -AppId '11b1509b-d570-4d3a-b46e-032215808864' `
                      -CertificateThumbprint '23B468A0F2F8A32B673F2CEBBCA9F00B7A3F10A6' `
                      -Organization 'a-cto.com' -ShowBanner:$false

Write-Host '=== Direct recipient lookup: dmarc@a-cto.com ==='
try {
    $r = Get-EXORecipient -Identity 'dmarc@a-cto.com' -ErrorAction Stop
    $r | Format-List Name,RecipientType,RecipientTypeDetails,PrimarySmtpAddress,EmailAddresses
} catch {
    Write-Host "  NOT FOUND ($($_.Exception.Message))"
}

Write-Host ''
Write-Host '=== Scanning all recipients for anything matching dmarc* ==='
Get-EXORecipient -ResultSize Unlimited |
    Where-Object { ($_.EmailAddresses -join ';') -match '(?i)dmarc' -or $_.PrimarySmtpAddress -match '(?i)dmarc' } |
    Format-List Name,RecipientTypeDetails,PrimarySmtpAddress,EmailAddresses

Write-Host ''
Write-Host '=== Accepted domains ==='
Get-AcceptedDomain | Format-Table DomainName,DomainType,Default

Disconnect-ExchangeOnline -Confirm:$false | Out-Null

$ErrorActionPreference = 'Stop'

Import-Module ExchangeOnlineManagement
Connect-ExchangeOnline -AppId '11b1509b-d570-4d3a-b46e-032215808864' `
                      -CertificateThumbprint '23B468A0F2F8A32B673F2CEBBCA9F00B7A3F10A6' `
                      -Organization 'a-cto.com' -ShowBanner:$false

$bookings = Get-Mailbox -RecipientTypeDetails SchedulingMailbox -ResultSize Unlimited
foreach ($b in $bookings) {
    Write-Host "=== $($b.DisplayName) <$($b.PrimarySmtpAddress)> ==="
    $reg = Get-MailboxRegionalConfiguration -Identity $b.PrimarySmtpAddress
    $cal = Get-MailboxCalendarConfiguration -Identity $b.PrimarySmtpAddress
    Write-Host ("  Regional TimeZone      : {0}" -f $reg.TimeZone)
    Write-Host ("  Working Hours TZ       : {0}" -f $cal.WorkingHoursTimeZone)
    Write-Host ("  Working Hours Start/End: {0} - {1}" -f $cal.WorkingHoursStartTime, $cal.WorkingHoursEndTime)
    Write-Host ''
}

Disconnect-ExchangeOnline -Confirm:$false | Out-Null

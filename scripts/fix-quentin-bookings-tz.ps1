$ErrorActionPreference = 'Stop'

Import-Module ExchangeOnlineManagement
Connect-ExchangeOnline -AppId '11b1509b-d570-4d3a-b46e-032215808864' `
                      -CertificateThumbprint '23B468A0F2F8A32B673F2CEBBCA9F00B7A3F10A6' `
                      -Organization 'a-cto.com' -ShowBanner:$false

Write-Host '=== All Bookings (Scheduling) mailboxes in tenant ==='
$bookingsMbx = Get-Mailbox -RecipientTypeDetails SchedulingMailbox -ResultSize Unlimited
$bookingsMbx | Format-Table DisplayName,PrimarySmtpAddress,Alias -AutoSize

if (-not $bookingsMbx) {
    Write-Host 'No SchedulingMailbox recipients found; trying broader search by name...'
    $bookingsMbx = Get-Mailbox -ResultSize Unlimited | Where-Object { $_.DisplayName -match '(?i)quentin' -and $_.DisplayName -match '(?i)book' }
    $bookingsMbx | Format-Table DisplayName,PrimarySmtpAddress,RecipientTypeDetails -AutoSize
}

$quentinBkg = $bookingsMbx | Where-Object { $_.DisplayName -match '(?i)quentin' } | Select-Object -First 1
if (-not $quentinBkg) {
    Write-Host 'ERROR: Could not identify Quentin Booking mailbox'
    exit 1
}

Write-Host ''
Write-Host "=== Target: $($quentinBkg.DisplayName) <$($quentinBkg.PrimarySmtpAddress)> ==="

Write-Host ''
Write-Host '=== Pre-state: Get-MailboxRegionalConfiguration ==='
Get-MailboxRegionalConfiguration -Identity $quentinBkg.PrimarySmtpAddress | Format-List Identity,Language,TimeZone,DateFormat,TimeFormat

Write-Host ''
Write-Host '=== Pre-state: Get-MailboxCalendarConfiguration ==='
Get-MailboxCalendarConfiguration -Identity $quentinBkg.PrimarySmtpAddress | Format-List Identity,WorkingHoursTimeZone,WorkingHoursStartTime,WorkingHoursEndTime,WorkDays

Write-Host ''
Write-Host '=== Applying fix: TimeZone = Pacific Standard Time ==='
Set-MailboxRegionalConfiguration -Identity $quentinBkg.PrimarySmtpAddress -TimeZone 'Pacific Standard Time' -Language en-US -LocalizeDefaultFolderName:$true
Set-MailboxCalendarConfiguration -Identity $quentinBkg.PrimarySmtpAddress -WorkingHoursTimeZone 'Pacific Standard Time'
Write-Host 'Applied.'

Write-Host ''
Write-Host '=== Post-state: Get-MailboxRegionalConfiguration ==='
Get-MailboxRegionalConfiguration -Identity $quentinBkg.PrimarySmtpAddress | Format-List Identity,Language,TimeZone,DateFormat,TimeFormat

Write-Host ''
Write-Host '=== Post-state: Get-MailboxCalendarConfiguration ==='
Get-MailboxCalendarConfiguration -Identity $quentinBkg.PrimarySmtpAddress | Format-List Identity,WorkingHoursTimeZone,WorkingHoursStartTime,WorkingHoursEndTime,WorkDays

Disconnect-ExchangeOnline -Confirm:$false | Out-Null
Write-Host ''
Write-Host '=== Done ==='

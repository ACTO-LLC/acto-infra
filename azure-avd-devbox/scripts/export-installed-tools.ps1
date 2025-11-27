$wingetOut = "$env:USERPROFILE\Desktop\winget-packages.txt"
$devToolsOut = "$env:USERPROFILE\Desktop\dev-tools-summary.txt"

winget list | Out-File -FilePath $wingetOut

$paths = @(
  "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
  "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
  "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$patterns = @(
  "Visual Studio Code", "Power BI", "Docker", "Postman", "Git",
  "Azure Data Studio", "SQL Server Management Studio", "Node.js",
  "Python", "GitHub", "Azure CLI"
)

$installed = foreach ($p in $paths) {
  Get-ItemProperty -Path $p -ErrorAction SilentlyContinue |
    Where-Object {
      $_.DisplayName -and ($patterns | Where-Object { $_ -and ($_.ToLower() -in $_.DisplayName.ToLower()) })
    } |
    Select-Object DisplayName, DisplayVersion, Publisher, InstallLocation
}

$installed | Sort-Object DisplayName | Format-Table -AutoSize | Out-File $devToolsOut

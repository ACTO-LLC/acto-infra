# Output files in the current directory
$wingetOut = "winget-packages.txt"
$devToolsOut = "dev-tools-summary.txt"

# Export winget packages if winget is available
if (Get-Command winget -ErrorAction SilentlyContinue) {
  Write-Host "Exporting winget packages to $wingetOut..."
  winget list | Out-File -FilePath $wingetOut
} else {
  Write-Host "Winget not found, skipping winget export."
}

# Registry paths to search for installed applications
$paths = @(
  "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
  "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
  "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

# Development tools to search for
$patterns = @(
  "Visual Studio Code", "Power BI", "Docker", "Postman", "Git",
  "Azure Data Studio", "SQL Server Management Studio", "Node.js",
  "Python", "GitHub", "Azure CLI", ".NET", "PowerShell"
)

Write-Host "Searching for installed development tools..."

# Search registry for installed applications matching our patterns
$installed = foreach ($p in $paths) {
  Get-ItemProperty -Path $p -ErrorAction SilentlyContinue |
    Where-Object {
      $displayName = $_.DisplayName
      if ($displayName) {
        $patterns | Where-Object { $displayName -match [regex]::Escape($_) }
      }
    } |
    Select-Object DisplayName, DisplayVersion, Publisher, InstallLocation
}

# Remove duplicates and sort
$installed = $installed | Sort-Object DisplayName -Unique

Write-Host "`nFound $($installed.Count) development tools:"
$installed | Format-Table -AutoSize

# Export to file
$installed | Format-Table -AutoSize | Out-File $devToolsOut
Write-Host "`nDevelopment tools summary exported to $devToolsOut"

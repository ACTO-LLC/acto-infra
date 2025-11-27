param(
    [switch]$Quiet
)

function Install-WinGetPackage {
    param([string]$Id)
    winget install --id $Id --accept-source-agreements --accept-package-agreements -h 0
}

Install-WinGetPackage "Microsoft.VisualStudioCode"
Install-WinGetPackage "Git.Git"
Install-WinGetPackage "Microsoft.PowerShell"
Install-WinGetPackage "OpenJS.NodeJS.LTS"
Install-WinGetPackage "Microsoft.AzureCLI"
Install-WinGetPackage "GitHub.cli"
Install-WinGetPackage "Docker.DockerDesktop"
Install-WinGetPackage "Microsoft.AzureDataStudio"
Install-WinGetPackage "Microsoft.SQLServerManagementStudio"
Install-WinGetPackage "Microsoft.PowerBI"
Install-WinGetPackage "Microsoft.PowerBIReportBuilder"
Install-WinGetPackage "Postman.Postman"
Install-WinGetPackage "7zip.7zip"

code --install-extension ms-azuretools.vscode-docker
code --install-extension ms-dotnettools.csharp
code --install-extension ms-vscode.vscode-typescript-next
code --install-extension esbenp.prettier-vscode
code --install-extension dbaeumer.vscode-eslint
code --install-extension ms-azuretools.vscode-bicep
code --install-extension ms-vscode.powershell

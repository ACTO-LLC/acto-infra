[CmdletBinding()]
param(
    [Parameter()]
    [string]$SourceRoot = 'C:\source',

    [Parameter()]
    [ValidateSet('Inventory', 'DryRun', 'Apply')]
    [string]$Mode = 'Inventory',

    [Parameter()]
    [string]$ConfigPath,

    [Parameter()]
    [string]$BackupRoot,

    [Parameter()]
    [string[]]$ExcludeDirectories = @(),

    [Parameter()]
    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-CleanupPath {
    param(
        [Parameter(Mandatory)]
        [string]$PathValue
    )

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        throw 'Path value cannot be empty.'
    }

    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return [System.IO.Path]::GetFullPath($PathValue)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $SourceRoot $PathValue))
}

function Ensure-ParentDirectory {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent | Out-Null
    }
}

function Get-GitFolderType {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $gitEntry = Get-Item -LiteralPath (Join-Path $Path '.git') -Force -ErrorAction SilentlyContinue
    if (-not $gitEntry) {
        return 'none'
    }

    if ($gitEntry.PSIsContainer) {
        return 'repo'
    }

    return 'worktree-or-filegit'
}

function Get-GitMetadata {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $type = Get-GitFolderType -Path $Path
    $branch = ''
    $origin = ''
    $dirty = ''

    if ($type -ne 'none') {
        try { $branch = git -C $Path branch --show-current 2>$null } catch {}
        try { $origin = git -C $Path remote get-url origin 2>$null } catch {}
        try {
            $dirty = if ((git -C $Path status --porcelain 2>$null | Select-Object -First 1)) {
                'dirty'
            } else {
                'clean'
            }
        } catch {}
    }

    [pscustomobject]@{
        GitType = $type
        Branch = $branch
        Origin = $origin
        Dirty = $dirty
    }
}

function Get-TopLevelInventory {
    $dirs = Get-ChildItem -LiteralPath $SourceRoot -Directory | Sort-Object Name
    foreach ($dir in $dirs) {
        $git = Get-GitMetadata -Path $dir.FullName
        [pscustomobject]@{
            Name = $dir.Name
            Path = $dir.FullName
            GitType = $git.GitType
            Branch = $git.Branch
            Origin = $git.Origin
            Dirty = $git.Dirty
            LastWriteTime = $dir.LastWriteTime
        }
    }
}

function Invoke-RobocopyMirror {
    param(
        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter(Mandatory)]
        [string]$Destination
    )

    Ensure-ParentDirectory -Path $Destination

    $args = @(
        $Source,
        $Destination,
        '/E',
        '/COPY:DAT',
        '/DCOPY:DAT',
        '/R:1',
        '/W:1',
        '/NFL',
        '/NDL',
        '/NJH',
        '/NJS',
        '/NP',
        '/XJ'
    )

    if ($ExcludeDirectories.Count -gt 0) {
        $args += '/XD'
        $args += $ExcludeDirectories
    }

    & robocopy @args | Out-Null
    return $LASTEXITCODE
}

function Remove-DirectoryRobust {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    try {
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
        return
    } catch {}

    try {
        Remove-Item -LiteralPath ('\\?\' + $Path) -Recurse -Force -ErrorAction Stop
        return
    } catch {}

    $quoted = ('"\\?\{0}"' -f $Path)
    cmd /c "rd /s /q $quoted" | Out-Null

    if (Test-Path -LiteralPath $Path) {
        throw "Failed to remove $Path"
    }
}

function ConvertTo-ActionResult {
    param(
        [Parameter(Mandatory)]
        [string]$Action,

        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter()]
        [string]$Destination = '',

        [Parameter(Mandatory)]
        [string]$Status,

        [Parameter()]
        [string]$Detail = ''
    )

    [pscustomobject]@{
        Action = $Action
        Source = $Source
        Destination = $Destination
        Status = $Status
        Detail = $Detail
    }
}

function Invoke-CopyThenRemoveAction {
    param(
        [Parameter(Mandatory)]
        [string]$Action,

        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter(Mandatory)]
        [string]$Destination
    )

    if (-not (Test-Path -LiteralPath $Source)) {
        return ConvertTo-ActionResult -Action $Action -Source $Source -Destination $Destination -Status 'missing-source'
    }

    if ($Mode -eq 'DryRun') {
        return ConvertTo-ActionResult -Action $Action -Source $Source -Destination $Destination -Status 'dry-run'
    }

    if (Test-Path -LiteralPath $Destination) {
        return ConvertTo-ActionResult -Action $Action -Source $Source -Destination $Destination -Status 'dest-exists'
    }

    $copyExit = Invoke-RobocopyMirror -Source $Source -Destination $Destination
    if ($copyExit -gt 7) {
        return ConvertTo-ActionResult -Action $Action -Source $Source -Destination $Destination -Status 'copy-failed' -Detail ("robocopy exit {0}" -f $copyExit)
    }

    try {
        Remove-DirectoryRobust -Path $Source
        $removed = -not (Test-Path -LiteralPath $Source)
        return ConvertTo-ActionResult -Action $Action -Source $Source -Destination $Destination -Status ($(if ($removed) { 'moved' } else { 'source-left' })) -Detail ("robocopy exit {0}" -f $copyExit)
    } catch {
        return ConvertTo-ActionResult -Action $Action -Source $Source -Destination $Destination -Status 'copied-source-left' -Detail $_.Exception.Message
    }
}

function Invoke-DeleteAction {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Item
    )

    $source = Resolve-CleanupPath -PathValue $Item.source

    if (-not (Test-Path -LiteralPath $source)) {
        return ConvertTo-ActionResult -Action 'delete' -Source $source -Status 'missing-source'
    }

    $git = Get-GitMetadata -Path $source
    $force = [bool]$Item.force

    if (-not $force -and $git.GitType -ne 'none' -and $git.Dirty -eq 'dirty') {
        return ConvertTo-ActionResult -Action 'delete' -Source $source -Status 'blocked-dirty-repo' -Detail 'Set force=true only after manual review.'
    }

    if ($Mode -eq 'DryRun') {
        return ConvertTo-ActionResult -Action 'delete' -Source $source -Status 'dry-run'
    }

    try {
        Remove-DirectoryRobust -Path $source
        return ConvertTo-ActionResult -Action 'delete' -Source $source -Status ($(if (Test-Path -LiteralPath $source) { 'still-exists' } else { 'deleted' }))
    } catch {
        return ConvertTo-ActionResult -Action 'delete' -Source $source -Status 'failed' -Detail $_.Exception.Message
    }
}

function Get-ConfigArray {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Config,

        [Parameter(Mandatory)]
        [string]$PropertyName
    )

    $value = $Config.$PropertyName
    if ($null -eq $value) {
        return @()
    }

    return @($value)
}

function Load-CleanupConfig {
    if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
        if ($Mode -eq 'Inventory') {
            return $null
        }

        throw 'ConfigPath is required for DryRun and Apply modes.'
    }

    $resolved = Resolve-CleanupPath -PathValue $ConfigPath
    if (-not (Test-Path -LiteralPath $resolved)) {
        throw "Config file not found: $resolved"
    }

    $config = Get-Content -LiteralPath $resolved -Raw | ConvertFrom-Json
    if (-not $BackupRoot) {
        $script:BackupRoot = if ($config.backupRoot) {
            Resolve-CleanupPath -PathValue $config.backupRoot
        } else {
            Resolve-CleanupPath -PathValue 'backup'
        }
    }

    return $config
}

if (-not (Test-Path -LiteralPath $SourceRoot)) {
    throw "Source root not found: $SourceRoot"
}

$SourceRoot = [System.IO.Path]::GetFullPath($SourceRoot)
$config = Load-CleanupConfig

if ($Mode -eq 'Inventory') {
    $inventory = Get-TopLevelInventory
    if ($AsJson) {
        $inventory | ConvertTo-Json -Depth 4
    } else {
        $inventory
    }
    return
}

if (-not $BackupRoot) {
    $BackupRoot = Resolve-CleanupPath -PathValue 'backup'
} else {
    $BackupRoot = Resolve-CleanupPath -PathValue $BackupRoot
}

$results = New-Object System.Collections.Generic.List[object]

foreach ($item in (Get-ConfigArray -Config $config -PropertyName 'moves')) {
    $source = Resolve-CleanupPath -PathValue $item.source
    $destination = Resolve-CleanupPath -PathValue $item.destination
    $results.Add((Invoke-CopyThenRemoveAction -Action 'move' -Source $source -Destination $destination))
}

foreach ($item in (Get-ConfigArray -Config $config -PropertyName 'backup')) {
    $source = Resolve-CleanupPath -PathValue $item.source
    $destination = if ($item.destination) {
        Resolve-CleanupPath -PathValue $item.destination
    } else {
        Join-Path $BackupRoot (Split-Path -Leaf $source)
    }

    $results.Add((Invoke-CopyThenRemoveAction -Action 'backup' -Source $source -Destination $destination))
}

foreach ($item in (Get-ConfigArray -Config $config -PropertyName 'delete')) {
    $results.Add((Invoke-DeleteAction -Item $item))
}

if ($AsJson) {
    $results | ConvertTo-Json -Depth 4
} else {
    $results
}

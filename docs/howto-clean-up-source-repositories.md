# How to Clean Up a Source Repositories Folder

This guide documents a repeatable approach for cleaning up a shared source folder such as `C:\source`.

The goal is to:

- keep one top-level folder per client or internal area
- move active repositories into the correct bucket
- identify stale clones, scratch folders, and empty folders
- avoid deleting anything that still only exists locally
- handle Windows-specific issues such as locked folders, hidden `.git` directories, and special filenames

## Recommended Top-Level Layout

Use a small number of top-level bucket folders:

- one folder per client
- one internal folder such as `acto`
- an optional `personal` folder for OSS, experiments, and non-client work
- an optional `backup` folder for archived copies

Example:

```text
C:\source
  acto
  pas
  mbc
  pomg
  bamert
  medplum
  personal
  backup
```

## Phase 1: Inventory the Current State

Start by listing top-level folders and checking which ones are Git repositories.

```powershell
Get-ChildItem -LiteralPath 'C:\source' -Directory | Sort-Object Name
```

To identify repositories and worktree-style folders:

```powershell
$dirs = Get-ChildItem -LiteralPath 'C:\source' -Directory | Sort-Object Name

$dirs | ForEach-Object {
  $gitEntry = Get-Item -LiteralPath (Join-Path $_.FullName '.git') -Force -ErrorAction SilentlyContinue
  [pscustomobject]@{
    Name = $_.Name
    HasGit = [bool]$gitEntry
    GitType = if (-not $gitEntry) { 'none' } elseif ($gitEntry.PSIsContainer) { 'repo' } else { 'worktree-or-filegit' }
    LastWrite = $_.LastWriteTime
  }
}
```

For Git folders, collect remote and branch metadata:

```powershell
$repo = 'C:\source\some-repo'

[pscustomobject]@{
  Branch = (git -C $repo branch --show-current 2>$null)
  Origin = (git -C $repo remote get-url origin 2>$null)
  Upstream = (git -C $repo rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null)
  Dirty = if ((git -C $repo status --porcelain 2>$null | Select-Object -First 1)) { 'dirty' } else { 'clean' }
}
```

## Phase 2: Classify Folders

Classify each top-level folder into one of these groups:

- active client repo
- active internal repo
- personal or OSS repo
- duplicate copy
- issue-specific scratch folder
- empty folder
- backup folder
- local-only folder that needs manual review

Good signals:

- Git remote organization or repo name
- existing client bucket names
- whether the folder is empty
- whether it has a `.git` directory
- whether it has only copied source without `.git`

## Phase 3: Decide What Can Be Deleted

Safe delete candidates usually include:

- empty folders
- clearly disposable scratch folders
- copied source trees that are not Git repos
- duplicate clones where the branch is already preserved remotely and you have explicitly decided to delete them

Do **not** auto-delete:

- dirty repos with local changes you have not reviewed
- repos with no remote-tracking branch
- bare repos that may be used as a local cache
- anything that may contain the only local copy of work

To check whether a branch exists on the remote:

```powershell
$repo = 'C:\source\some-repo'
$branch = git -C $repo branch --show-current 2>$null
git -C $repo rev-parse --verify ("refs/remotes/origin/" + $branch) 2>$null
```

To check whether a branch is merged into the remote default branch:

```powershell
$repo = 'C:\source\some-repo'
$branch = 'feature/some-branch'
$branchRef = git -C $repo rev-parse --verify ("refs/remotes/origin/" + $branch) 2>$null
$mainRef = git -C $repo rev-parse --verify refs/remotes/origin/main 2>$null

if ($branchRef -and $mainRef) {
  git -C $repo merge-base --is-ancestor $branchRef $mainRef
  if ($LASTEXITCODE -eq 0) {
    'merged'
  } else {
    'not merged'
  }
}
```

If the repo uses `master` rather than `main`, check `refs/remotes/origin/master` instead.

## Phase 4: Dry Run the Plan

Before making changes, generate a dry run for:

- parent folders to create
- folders to move
- folders to delete
- folders to archive into `backup`

Example dry-run move output:

```powershell
$moves = @(
  @{ Source='C:\source\repo-a'; Dest='C:\source\acto\repo-a' },
  @{ Source='C:\source\repo-b'; Dest='C:\source\pas\repo-b' }
)

foreach ($move in $moves) {
  if (-not (Test-Path -LiteralPath $move.Source)) {
    "[SKIP-MISSING] $($move.Source)"
    continue
  }

  if (Test-Path -LiteralPath $move.Dest) {
    "[SKIP-CONFLICT] $($move.Dest)"
    continue
  }

  "[MOVE] Move-Item -LiteralPath '$($move.Source)' -Destination '$($move.Dest)'"
}
```

## Reusable Script

This repo also includes a reusable helper:

```text
scripts\invoke-source-repo-cleanup.ps1
```

It supports three modes:

- `Inventory`
- `DryRun`
- `Apply`

### Example Config

Save a JSON config like this:

```json
{
  "backupRoot": "backup",
  "moves": [
    { "source": "acto-agent", "destination": "acto\\acto-agent" },
    { "source": "mbc-clinic", "destination": "mbc\\mbc-clinic" }
  ],
  "backup": [
    { "source": "modern-accounting-223" },
    { "source": "modern-accounting-224" }
  ],
  "delete": [
    { "source": "pss-issue-1246" },
    { "source": "pss-issue-1347" },
    { "source": "my-vite-app", "force": true }
  ]
}
```

### Example Usage

Inventory:

```powershell
.\scripts\invoke-source-repo-cleanup.ps1 -SourceRoot C:\source -Mode Inventory
```

Dry run:

```powershell
.\scripts\invoke-source-repo-cleanup.ps1 -SourceRoot C:\source -Mode DryRun -ConfigPath .\cleanup-config.json
```

Apply:

```powershell
.\scripts\invoke-source-repo-cleanup.ps1 -SourceRoot C:\source -Mode Apply -ConfigPath .\cleanup-config.json
```

## Phase 5: Prefer Copy-Then-Remove Over Direct Rename

On Windows, direct `Move-Item` often fails for repos because of:

- hidden `.git` directories
- read-only files
- files in use by editors, terminals, or watchers
- reserved names such as `nul`

For large or problematic repo folders, prefer this pattern:

1. copy the repo to the destination
2. verify the destination exists
3. remove the original source folder

Example:

```powershell
$src = 'C:\source\repo-a'
$dest = 'C:\source\acto\repo-a'

robocopy $src $dest /E /COPY:DAT /DCOPY:DAT /R:1 /W:1 /NFL /NDL /NJH /NJS /NP /XJ /XD node_modules dist build coverage .next .turbo .cache bin obj
$copyExit = $LASTEXITCODE

if ($copyExit -le 7) {
  Remove-Item -LiteralPath $src -Recurse -Force
}
```

`robocopy` exit codes `0` through `7` are generally usable here. Larger values should be treated as failure.

## Phase 6: Handle Locked or Weird Folders

If `Remove-Item` fails because of path syntax or reserved filenames, try extended paths:

```powershell
$path = 'C:\source\repo-a'
Remove-Item -LiteralPath ('\\?\' + $path) -Recurse -Force
```

If that still fails, try `cmd` removal:

```powershell
cmd /c "rd /s /q ""\\?\C:\source\repo-a"""
```

If the folder is still locked:

- close VS Code windows for that repo
- stop dev servers, watchers, and terminals inside that repo
- retry removal

## Phase 7: Backup Instead of Delete When Needed

If you want a safer cleanup pass, move questionable folders into `C:\source\backup` instead of deleting them.

Example:

```powershell
$backupRoot = 'C:\source\backup'
$src = 'C:\source\old-branch-folder'
$dest = Join-Path $backupRoot (Split-Path -Leaf $src)

if (-not (Test-Path -LiteralPath $backupRoot)) {
  New-Item -ItemType Directory -Path $backupRoot | Out-Null
}

Move-Item -LiteralPath $src -Destination $dest
```

If direct move fails, use the same `robocopy` plus remove pattern described above.

## Phase 8: Verify the Final Layout

After cleanup:

- list top-level folders again
- confirm each bucket contains the expected repos
- confirm deleted folders are actually gone
- note any blocked folders that still need manual cleanup

Top-level verification:

```powershell
Get-ChildItem -LiteralPath 'C:\source' -Directory | Select-Object Name | Sort-Object Name
```

## Suggested Operating Rules

- always dry-run first
- never delete dirty repos unless the user explicitly approves it
- confirm remote branch or merge state before deleting branch clones
- prefer backup over delete when there is uncertainty
- expect Windows file-locking issues and plan a retry pass
- document blocked items separately instead of forcing removal

## Suggested Checklist

1. Inventory all top-level folders.
2. Map repos to target buckets.
3. Identify empty folders, copies, and questionable clones.
4. Check remote branch presence and merge status for delete candidates.
5. Generate a dry run.
6. Execute safe deletes.
7. Move active repos into bucket folders.
8. Retry locked duplicates after closing editors and terminals.
9. Archive unresolved leftovers into `backup`.
10. Verify the final top-level layout.

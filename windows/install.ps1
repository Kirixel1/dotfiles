<#
.SYNOPSIS
    Installs the dotfiles in this repo onto Windows.

.DESCRIPTION
    Copies kitty, Neovim, Blender and Godot configuration from the repo into the
    locations those applications read on Windows, applying the per-OS edits that
    are required. Anything it would overwrite is backed up first.

    Companion to MIGRATION.md at the repo root. Read that first.

.PARAMETER DryRun
    Report what would happen without touching anything.

.PARAMETER NoBackup
    Skip the pre-flight backup prompt. Existing files are still backed up
    automatically; this only suppresses the "press Enter to continue" pause.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\install.ps1 -DryRun

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\install.ps1
#>

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$NoBackup
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $RepoRoot 'MIGRATION.md'))) {
    throw "MIGRATION.md not found next to this script. Run install.ps1 from inside the dotfiles repo."
}

$Home_    = $env:USERPROFILE
$AppData_ = $env:APPDATA

$Dest = @{
    Kitty   = Join-Path $Home_  '.config\kitty'
    Nvim    = Join-Path $Home_  '.config\nvim'
    Blender = Join-Path $AppData_ 'Blender Foundation\Blender\5.2'
    Godot   = Join-Path $AppData_ 'Godot'
}

$script:steps = 0
$script:warns = @()

function Write-Step  { param([string]$m) $script:steps++; Write-Host "[$script:steps] $m" -ForegroundColor Cyan }
function Write-Ok    { param([string]$m) Write-Host "    OK  $m" -ForegroundColor Green }
function Write-Info  { param([string]$m) Write-Host "    $m" -ForegroundColor Gray }
function Write-Warn2 { param([string]$m) Write-Host "    !!  $m" -ForegroundColor Yellow; $script:warns += $m }

function Backup-Tree {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $bak   = "$Path.bak-$stamp"
    if ($DryRun) { Write-Info "would back up -> $bak"; return }
    Copy-Item -Path $Path -Destination $bak -Recurse -Force
    Write-Ok "backed up existing -> $bak"
}

function Ensure-Dir {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        if ($DryRun) { Write-Info "would create $Path"; return }
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

Write-Host ''
Write-Host '  dotfiles -> Windows installer' -ForegroundColor White
Write-Host "  repo: $RepoRoot"            -ForegroundColor DarkGray
if ($DryRun) { Write-Host '  MODE: DRY RUN (nothing will be written)' -ForegroundColor Yellow }
Write-Host ''

# ---------------------------------------------------------------- pre-flight
Write-Step 'Pre-flight checks'

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Warn2 'git not found on PATH — not required by this script, but useful later.'
}

$blenderInstalled = Get-ChildItem -Path (Join-Path $AppData_ 'Blender Foundation\Blender') `
                                 -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
if ($blenderInstalled) {
    Write-Info "Blender versions present: $($blenderInstalled -join ', ')"
    if ($blenderInstalled -notcontains '5.2') {
        Write-Warn2 'Blender 5.2 NOT found. This script writes a 5.2 folder; if your Blender is a' + "`n" +
                    '        different version it will create its own folder and ignore this config.' + "`n" +
                    '        Install Blender 5.2.x, or edit $Dest.Blender to match your version.'
    } else {
        Write-Ok 'Blender 5.2 present'
    }
} else {
    Write-Warn2 'Blender config dir not found yet — copying anyway. Install Blender 5.2.x afterwards.'
}

# Locate kitty.exe for Godot's external-editor setting. Empty if not found yet.
$script:KittyExe = ''
$kittyCandidates = @(
    (Get-Command kitty.exe -ErrorAction SilentlyContinue | Select-Object -First 1).Source,
    (Join-Path $AppData_ '..\Local\kitty\kitty.exe'),
    (Join-Path $env:LOCALAPPDATA 'kitty\kitty.exe'),
    (Join-Path $env:LOCALAPPDATA 'Programs\kitty\kitty.exe')
) | Where-Object { $_ -and (Test-Path $_) }

if ($kittyCandidates) {
    $script:KittyExe = (Resolve-Path ($kittyCandidates | Select-Object -First 1)).Path
    Write-Ok "kitty.exe found -> $script:KittyExe"
} else {
    Write-Warn2 'kitty.exe not found. Godot will point its external editor at /bin/kitty' + "`n" +
                '        until you either install kitty or set the path in Godot > Editor Settings >' + "`n" +
                '        Filesystem > External Programs > Text Editor.'
}

$repoBlenderVersion = '5.2'
Write-Ok 'pre-flight complete'

# ---------------------------------------------------------------- kitty
Write-Step 'kitty'
$src = Join-Path $RepoRoot 'kitty'
if (Test-Path $src) {
    Backup-Tree $Dest.Kitty
    Ensure-Dir $Dest.Kitty
    if (-not $DryRun) {
        Copy-Item -Path (Join-Path $src '*') -Destination $Dest.Kitty -Recurse -Force
        $conf = Join-Path $Dest.Kitty 'kitty.conf'

        # fish has no native Windows port — comment the line out, don't delete it.
        if (Test-Path $conf) {
            $c = Get-Content $conf -Raw
            if ($c -match '(?m)^shell\s+fish\s*$') {
                $c = $c -replace '(?m)^shell\s+fish\s*$',
                                '// shell fish   # disabled on Windows: fish has no native port'
                Set-Content -Path $conf -Value $c -NoNewline -Encoding utf8
                Write-Ok 'neutralised `shell fish`'
            } else {
                Write-Info 'no `shell fish` line found (already handled?)'
            }
        }
    }
    Write-Ok "kitty -> $($Dest.Kitty)"
    Write-Warn2 'Install the "Iosevka Fixed" font, or text will render in a fallback face.'
} else {
    Write-Warn2 'kitty/ missing from repo'
}

# ---------------------------------------------------------------- nvim
Write-Step 'Neovim'
$src = Join-Path $RepoRoot 'nvim'
if (Test-Path $src) {
    Backup-Tree $Dest.Nvim
    Ensure-Dir $Dest.Nvim
    if (-not $DryRun) {
        foreach ($item in @('init.lua', 'lua', 'nvim-pack-lock.json')) {
            $p = Join-Path $src $item
            if (Test-Path $p) {
                Copy-Item -Path $p -Destination $Dest.Nvim -Recurse -Force
                Write-Ok "copied $item"
            } else {
                Write-Warn2 "missing in repo: nvim/$item"
            }
        }
    }
    Write-Ok "nvim -> $($Dest.Nvim)"
    if (-not $DryRun) {
        Write-Info 'open nvim once — nvim-pack will install plugins from the lockfile'
    }
} else {
    Write-Warn2 'nvim/ missing from repo'
}

# ---------------------------------------------------------------- blender
Write-Step "Blender $repoBlenderVersion"
$src = Join-Path $RepoRoot "blender\$repoBlenderVersion"
if (Test-Path $src) {
    Backup-Tree $Dest.Blender
    Ensure-Dir $Dest.Blender
    if (-not $DryRun) {
        Copy-Item -Path (Join-Path $src '*') -Destination $Dest.Blender -Recurse -Force
        $pref = Join-Path $Dest.Blender 'config\userpref.blend'
        if (Test-Path $pref) {
            Write-Ok ("userpref.blend  ({0:N0} bytes)" -f (Get-Item $pref).Length)
        } else {
            Write-Warn2 'userpref.blend did not land where expected'
        }
    }
    Write-Ok "blender -> $($Dest.Blender)"
    Write-Warn2 'REINSTALL extensions from the extension browser: math_art 1.20.1, palette 1.1.5' + "`n" +
                '        (binaries are intentionally not in this repo — see blender/EXTENSIONS.md)'
    Write-Warn2 'In Blender: Preferences > General > Startup > tick "Save Preferences on Quit"' + "`n" +
                '        Without this, addon/theme changes silently revert every launch.'
} else {
    Write-Warn2 "blender/$repoBlenderVersion missing from repo"
}

# ---------------------------------------------------------------- godot
Write-Step 'Godot'
$src = Join-Path $RepoRoot 'godot'
if (Test-Path $src) {
    Backup-Tree $Dest.Godot
    Ensure-Dir $Dest.Godot
    if (-not $DryRun) {
        Get-ChildItem -Path $src -File | ForEach-Object {
            Copy-Item -Path $_.FullName -Destination $Dest.Godot -Force
        }
        Write-Ok 'copied editor settings'

        # Rewrite Linux absolute paths that are meaningless on Windows.
        foreach ($f in @('editor_settings-4.7.tres', 'editor_settings-4.tres')) {
            $p = Join-Path $Dest.Godot $f
            if (-not (Test-Path $p)) { continue }
            $t   = Get-Content $p -Raw
            $orig = $t

            $t = $t -replace '(?m)^(filesystem/directories/default_project_path\s*=\s*)".*"',
                            "`$1`"$($Home_ -replace '\\','/')`""
            $t = $t -replace '(?m)^(filesystem/import/blender/blender_path\s*=\s*)"/usr/bin/blender"',
                            "`$1`"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe`""
            $t = $t -replace '(?m)^(filesystem/tools/oidn/oidn_denoise_path\s*=\s*)"/usr/bin"',
                            "`$1`"`""
            $t = $t -replace '(?m)^(export/android/debug_keystore\s*=\s*)"/home/kirill/[^"]*"',
                            "`$1`"$($Dest.Godot -replace '\\','/')/keystores/debug.keystore`""
            $t = $t -replace '(?m)^(export/android/android_sdk_path\s*=\s*)"/home/kirill/Android/Sdk"',
                            "`$1`"$($env:LOCALAPPDATA -replace '\\','/')/Android/Sdk`""

            # Godot's "open external editor" points at the kitty binary on Linux.
            if ($script:KittyExe) {
                $t = $t -replace '(?m)^(filesystem/external_programs/terminal_emulator\s*=\s*)"/bin/kitty"',
                                "`$1`"$($script:KittyExe -replace '\\','/')`""
            }

            if ($t -ne $orig) {
                Set-Content -Path $p -Value $t -NoNewline -Encoding utf8
                Write-Ok "rewrote Linux paths in $f"
            }
        }
    }
    Write-Ok "godot -> $($Dest.Godot)"
    Write-Warn2 'Install Godot 4.7.x — it reads editor_settings-4.7.tres and ignores the -4 file.'
} else {
    Write-Warn2 'godot/ missing from repo'
}

# ---------------------------------------------------------------- summary
Write-Host ''
Write-Host '  Done.' -ForegroundColor White

if ($script:warns.Count -gt 0) {
    Write-Host ''
    Write-Host "  $($script:warns.Count) thing(s) needing your attention:" -ForegroundColor Yellow
    Write-Host '  (listed above as "!!")' -ForegroundColor DarkGray
}

Write-Host ''
Write-Host '  Not touched by this script:' -ForegroundColor DarkGray
Write-Host '    - fish   : no native Windows port. Use PowerShell 7 / Nushell,' -ForegroundColor DarkGray
Write-Host '                or reboot into Linux.' -ForegroundColor DarkGray
Write-Host '    - niri   : Linux-only compositor, not applicable.' -ForegroundColor DarkGray
Write-Host ''
Write-Host '  Next: install opencode, then run /connect.' -ForegroundColor Cyan
Write-Host '        npm install -g opencode-ai      (do NOT use bun — unsupported on Windows)' -ForegroundColor DarkGray
Write-Host ''
Write-Host '  Full checklist: MIGRATION.md section 11' -ForegroundColor DarkGray
Write-Host ''
# Windows setup scripts

Applies this dotfiles repo to a Windows machine. Read [`../MIGRATION.md`](../MIGRATION.md)
first for the reasoning.

## Requirements

- PowerShell 5.1+ (built into Windows 10/11) or PowerShell 7
- The dotfiles repo cloned on Windows

## Run

Preview first — prints the plan, writes nothing:

```powershell
powershell -ExecutionPolicy Bypass -File .\windows\install.ps1 -DryRun
```

Then for real:

```powershell
powershell -ExecutionPolicy Bypass -File .\windows\install.ps1
```

Execution policy only needs loosening for this invocation; the flag above is
scoped to the single command and doesn't change your machine settings.

## What it does

| Step | Action |
|---|---|
| Pre-flight | Checks for Blender 5.2 and warns loudly if absent or a different version |
| kitty | Copies `kitty/` → `%USERPROFILE%\.config\kitty\`, comments out `shell fish` |
| Neovim | Copies `init.lua`, `lua/`, `nvim-pack-lock.json` → `%USERPROFILE%\.config\nvim\` |
| Blender | Copies `blender/5.2/` → `%APPDATA%\Blender Foundation\Blender\5.2\` |
| Godot | Copies `godot/` → `%APPDATA%\Godot\`, rewrites Linux absolute paths |

Everything it would overwrite is copied to `<path>.bak-<timestamp>` first.
The script is safe to re-run.

## What it deliberately does NOT do

- **fish** — no native Windows port exists. Use PowerShell 7 or Nushell, or reboot
  into Linux. You have dual boot, so this costs you nothing.
- **niri** — Linux-only compositor.
- **Blender extensions** — `math_art` and `palette` binaries are intentionally not
  in this repo (30 MB, mostly regenerable bytecode and vendored third-party code).
  Reinstall from Blender's extension browser; their enabled flags already ride along
  inside the tracked `userpref.blend`. See [`../blender/EXTENSIONS.md`](../blender/EXTENSIONS.md).
- **opencode** — install manually, see below.

## After it runs

```powershell
npm install -g opencode-ai     # not bun — unsupported on Windows
```

Then launch opencode and run `/connect`. Do **not** copy `auth.json` from the Linux
machine; it holds live credentials and isn't portable.

Then work through the checklist in `MIGRATION.md` section 11.
# MIGRATION.md — Fedora → Windows

Handoff notes for setting up the Windows half of this dual-boot machine.
Written on the Linux side so a fresh OpenCode session on Windows can start informed
instead of from zero.

---

## 0. Read this first

This machine is **dual boot**. Windows is a *second* setup, not a replacement.
The Linux install stays untouched — nothing here is a "move", there is no risk and
no rush.

Because you can reboot into Linux whenever you want, **WSL2 is not needed.**
WSL2 exists to give Windows users a Linux environment without rebooting; you already
have that, for free. Don't install it.

### Decision made

Windows is the chosen platform for the game. Everything here is the Linux half of a
dual-boot machine being given a working second half — nothing is being moved or
deleted from Linux.

---

## 0.5 The short version — do these in order

The detail is in sections 1-11. This is the whole procedure.

### Step 1 — clone

```powershell
git clone https://github.com/Kirixel1/dotfiles.git $HOME\dotfiles
```

### Step 2 — brief the agent

A fresh OpenCode session has no memory of the Linux side. Start with:

```
Read MIGRATION.md in the dotfiles repo
```

Do this before anything else, so it works from the file rather than from context
you would have to retype.

### Step 3 — install the tools

```powershell
winget install Git.Git
winget install OpenJS.NodeJS.LTS
choco install kittywinget install Neovim.Neovim
winget install BlenderFoundation.Blender
```

`winget` may prompt to accept package agreements — answer `Y`.

### Step 4 — apply the configs

```powershell
cd $HOME\dotfiles
powershell -ExecutionPolicy Bypass -File .\windows\install.ps1 -DryRun
powershell -ExecutionPolicy Bypass -File .\windows\install.ps1
```

Run `-DryRun` first. See "Status and known-unknowns" in section 0.5 for why.

### Step 5 — opencode

```powershell
npm install -g opencode-ai
```

Launch it, then run `/connect`. **Never copy `auth.json`** from the Linux
machine — it holds live credentials and is not portable.

---

## Three things that will bite

### Blender version is load-bearing

Your config lives in a folder literally named `5.2`. Install **5.2.x**, not 5.3.
On 5.3 Blender silently creates an empty `5.3` folder and every preference
appears to have vanished — which reads as a failed migration when the copy
worked fine.

### Tick "Save Preferences on Quit" immediately

Preferences → General → Startup. Without it, every addon and theme change
silently reverts on the next launch. Same failure mode already hit on Linux.

### kitty's Windows installer is not the script

The official `installer.sh` is macOS/Linux only. Windows builds come from
`github.com/kovidgoyal/kitty/releases`. The current asset name was never
verified — the GitHub API was unreachable from the Linux machine.

Also install the **Iosevka Fixed** font, or text renders in a fallback face.

---

## Status and known-unknowns

**Good:** the Neovim config should copy verbatim — zero absolute paths, zero
external binaries, no natively-compiled LSP servers. That is unusually portable;
configs usually break on exactly those three things.

**Unknown:** `windows/install.ps1` has never been executed. No PowerShell was
available on the Linux machine. The six Godot path rewrites were verified for
correct output, but PowerShell's own semantics were not. Hence `-DryRun`.

**Linux loose ends** (do not block the migration):
- `xwaylandPersistence` sits in `labwc/rc.xml` but never took effect; it needs
  a labwc restart. The Godot `BadWindow` spam and a detached titlebar are
  probably still present there.
- The Godot black-bars question was never cleanly confirmed. labwc appeared to
  fix the sizing in practice. Moot on Windows, where no compositor decides the
  window size.

---

## 1. Source of truth

This repo: `https://github.com/Kirixel1/dotfiles` (`Kirixel1/dotfiles`, branch `main`).

Clone on Windows:

```powershell
git clone https://github.com/Kirixel1/dotfiles.git $HOME\dotfiles
```

Everything below copies *from* this repo *to* the Windows config locations.

---

## 2. Per-tool plan

| Tool | Linux path (this repo) | Windows destination | Status |
|---|---|---|---|
| kitty | `kitty/` | `%USERPROFILE%\.config\kitty\` | portable, 1 edit |
| Neovim | `nvim/` | `%USERPROFILE%\.config\nvim\` | fully portable |
| Blender | `blender/5.2/` | `%APPDATA%\Blender Foundation\Blender\5.2\` | **pin version** |
| Godot | `godot/` | `%APPDATA%\Godot\` | needs path fixes |
| fish | `fish/` | — | **no Windows port** |
| niri | `niri/` | — | Linux-only |
| opencode | — | `%USERPROFILE%\.config\opencode\` | install separately |

### Automated

`windows/install.ps1` performs the kitty / Neovim / Blender / Godot copies,
applies the required per-OS edits, and backs up anything it overwrites.
See `windows/README.md`.

---

## 3. kitty

Copies cleanly. Exactly **one** line must change:

```kitty
shell fish        # <- fish has no Windows port; delete this line
```

Everything else is portable verbatim: `font_size 22.0`, `cursor #ffdd33`,
`shell_integration no-cursor`, `cursor_shape block`, the Noctalia theme include,
and `font_family family="Iosevka Fixed"`.

**Install the Iosevka Fixed font on Windows** or the terminal renders with a
fallback face and will look wrong.

Caveat: the docs installer script (`kitty/installer.sh`) is **macOS/Linux only**.
On Windows, install from the GitHub releases page. This was *not* verified from
Linux — the GitHub API was unreachable from that machine, so confirm the current
Windows asset name yourself at `github.com/kovidgoyal/kitty/releases`.

---

## 4. Neovim

The cleanest config in the repo. Verified by audit:

- **Zero** absolute paths (`/home/...` appears once, inside a comment)
- **Zero** external binary dependencies (no `fd`, `rg`, `fzf`, `bat` calls)
- **Zero** mason / native-compiled LSP servers

The only LSP is GDScript, and it connects over **TCP `127.0.0.1:6005`**, which is
platform-neutral. All `lua/` modules are pure Lua.

So `init.lua` + `lua/` copy verbatim. Plugins are **not** in the repo (they are
built artifacts under `~/.local/share/nvim`); after copying the config, open nvim
and let `nvim-pack` reinstall them from `nvim-pack-lock.json`, which pins every
plugin to a specific commit.

Expect the usual Windows nvim papercuts: no clipboard `+`/`*` registers without a
clipboard provider, and shell-outs need `.exe` paths. None of this is in your config.

---

## 5. Blender — READ THIS

Copy the whole `5.2` directory to `%APPDATA%\Blender Foundation\Blender\`.

> ### The version directory is load-bearing
> Your config lives in a folder literally named `5.2`. Blender resolves preferences
> by exact version string. **Install Blender 5.2.x on Windows and leave it.**
> If it auto-updates to 5.3, Blender silently creates a fresh empty `5.3` folder and
> every preference appears to have vanished. Same failure mode as a missing config,
> but the cause is the version, not the copy.

Also copy `extensions/` **if** you want the addons — but see the next point.

### Extensions are not vendored

`math_art` (1.20.1) and `palette` (1.1.5) are **deliberately not in this repo**
— see `blender/EXTENSIONS.md` for why. Reinstall them from the extension browser;
their *enabled* flags are already inside the tracked `userpref.blend`.

### Persistence gotcha — same trap as on Linux

Blender only writes `userpref.blend` when you save preferences explicitly, or on
quit if **Preferences → General → Startup → "Save Preferences on Quit"** is ticked.
Turn that on *first*. Otherwise every enable toggle silently reverts on next launch,
and you will re-diagnose the exact bug we already fixed here.

### `blender/5.1/` was removed

You run 5.2.x only, so the old 5.1 config was stale (last touched 2026-08-02) and
has been deleted from this repo. Only `blender/5.2/` is tracked now.

The `.gitignore` patterns use `blender/*/` wildcards, so they still match 5.2 and
will also match a future 5.3 if you ever upgrade.

---

## 6. Godot

`godot/editor_settings-4.7.tres` contains **six Linux absolute paths** that are wrong on
Windows. `install.ps1` rewrites all of them (verified: after rewrite, zero Linux
paths remain); manual equivalents:

| Setting | Linux value | Windows value |
|---|---|---|
| `filesystem/external_programs/terminal_emulator` | `/bin/kitty` | path to `kitty.exe` |
| `filesystem/directories/default_project_path` | `/home/kirill` | `C:/Users/<you>` |
| `filesystem/import/blender/blender_path` | `/usr/bin/blender` | `C:/Program Files/Blender Foundation/Blender 5.2/blender.exe` |
| `filesystem/tools/oidn/oidn_denoise_path` | `/usr/bin` | empty |
| `export/android/debug_keystore` | `/home/kirill/.local/share/...` | `%APPDATA%\Godot\keystores\debug.keystore` |
| `export/android/android_sdk_path` | `/home/kirill/Android/Sdk` | `%LOCALAPPDATA%\Android\Sdk` |

The `terminal_emulator` one matters more than it looks — it's how Godot opens files
in your editor, and pointing it at `/bin/kitty` means Ctrl+O in Godot tries to run a
path that doesn't exist. `install.ps1` locates `kitty.exe` automatically and only
warns if it genuinely can't find it.

Two editor-settings files are tracked: `-4.7.tres` (yours, Godot 4.7.2) and
`-4.tres`. Godot picks by version — **install 4.7.x** or only the `-4` file is read.

---

## 7. fish — no Windows port

fish is POSIX-only and has never been ported to Windows; there is no maintained
Cygwin/MSYS2 build. **On Windows use PowerShell 7 or Nushell.**

You have dual boot, so fish is one reboot away whenever you want it. That is the
entire migration story for this tool.

If you ever do want fish's features without rebooting, the only realistic route is
WSL2. Deliberately not part of this plan.

---

## 8. niri — Linux-only

No Windows equivalent, and none needed. Windows handles window management.

---

## 9. OpenCode

Docs are explicit: *"While OpenCode can run directly on Windows, we recommend using
WSL for the best experience"* (better filesystem perf, full terminal integration).
Since you have dual boot, **use it natively** — WSL is only worth it if you want
it on *both* boots without rebooting.

Install (native, no Bun — explicitly unsupported on Windows):

```powershell
npm install -g opencode-ai
# or: scoop install opencode
# or: choco install opencode
```

Then `/connect` to authenticate.

**Do not copy `auth.json` from Linux.** It holds live credentials and is not
machine-portable. Re-authenticate on Windows.

Your config is effectively empty (`{"$schema": ...}`) plus one dependency
(`@opencode-ai/plugin@1.18.30`), so there is nothing meaningful to port — run
`npm install` in the config dir on Windows if you want the plugin package.

Session history lives in `~/.local/share/opencode/opencode.db` (SQLite, ~400 MB).
Not portable and not worth copying; sessions are tied to projects anyway.

---

## 10. Open questions

One thing I could not settle from Linux. Does not block the migration.

1. **The Godot `open-floating` window-rule was added then removed.** It was written
   while debugging why niri tiled the Godot game window — a tiling compositor
   forces windows to the workspace size, which broke the 1920x960 override and
   caused the black bars. It parsed cleanly but was never confirmed working
   (the `app-id` for the game window was never captured), and it is not in the
   config now. It is also Linux-only, so it does not affect Windows either way.
   If you revisit it: niri's `open-*` rules are evaluated **once, when a window is
   first mapped** — they never re-apply to already-open windows, so a rule can look
   "not working" simply because the window predates the rule.

Note: `prefer-no-csd` was briefly commented out during that debugging session and
has since been restored. Both live and repo currently have it **active**, matching
the last commit.

---

## 11. Quick verification checklist on Windows

After running `windows/install.ps1`:

- [ ] `kitty` opens with the Noctalia theme and Iosevka Fixed renders correctly
- [ ] `nvim` opens with no error, plugins reinstall from the lockfile
- [ ] Blender 5.2 shows your theme and both extensions already enabled
- [ ] Blender: "Save Preferences on Quit" is ticked
- [ ] Godot 4.7 opens, editor theme intact, no `/home/...` paths in settings
- [ ] `opencode --version` runs and `/connect` succeeds
- [ ] Reboot back into Linux — everything still there, nothing disturbed
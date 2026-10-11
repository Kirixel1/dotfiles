# labwc — floating Wayland session

The **default** window manager: floating, client-sized windows. niri stays
installed and one command away (`use-session niri`) if the tiling layout is
wanted.

## Why this exists

niri is a **tiling** compositor. It owns window geometry and forces every window
to fit its workspace layout, *discarding the size an application requested*.

That is what caused black bars in apps with a fixed aspect ratio. Such an app
requests an explicit window size; niri tiled it to the full workspace instead,
letterboxing the content:

```
requested  1920x960   (2:1)
actual     1920x1080  (16:9, forced by niri's layout)
bars       60px top + 60px bottom
```

labwc is a **stacking/floating** WM (wlroots-based, Openbox-compatible). It honours
the size a client requests, so those windows open correctly.

**The important part: there are no per-game rules.** `rc.xml` deliberately has no
`<windowRules>` block. Every app is floated and client-sized automatically, so you
never have to touch settings per project.

## Setup (one-time, needs your password)

```bash
sudo dnf install labwc
```

Pulls in `xdg-desktop-portal-wlr` and `libsfdo`. Nothing else is required —
you already have kitty, and labwc has no dependency on a panel or wallpaper.

## Switching between labwc and niri

labwc starts at login by default — the marker file `~/.config/session-choice`
does not exist, and `config.fish` falls through to `labwc-session`.

```fish
use-session              # show what will start
use-session niri         # next login starts niri
use-session labwc        # back to the default
```

Then **log out and log back in**. There is no display manager installed, so
"logging out" means exiting the compositor from the session itself.

### To switch to niri

1. `use-session niri`
2. Exit labwc — middle-click the desktop → **Exit labwc**, or `Alt+F4` on the
   last window.
3. Log in again at the TTY prompt — niri starts instead.

### To switch back to labwc

1. In niri: `use-session labwc` (or leave it — labwc is the default)
2. Exit niri — `Mod+Shift+E` (has a confirmation dialog)
3. Log in — labwc starts.

## How it works

`~/.config/fish/config.fish` still has the login block, but it now branches:

```fish
if status is-login
    set -l wm (test -f $HOME/.config/session-choice; and cat $HOME/.config/session-choice; or echo niri)
    switch $wm
        case labwc
            labwc-session
        case '*'
            niri-session -l
    end
end
```

No marker file → `niri` → identical to the previous behaviour.

`labwc-session` (a fish function) stops `niri.service` first, because niri holds
the **DRM master** and only one compositor can own it. Without that step labwc
fails to start.

## Keys

| Combo | Action |
|---|---|
| `Super+Return` | kitty (rebound from the uninstalled `lab-sensible-terminal`) |
| `Alt+Tab` | next window |
| `Alt+F4` | close window |
| `Super+a` | toggle maximize |
| `Super+d` | show desktop |
| `Super` + mouse drag | move / resize |
| Middle-click desktop | root menu (Terminal / Reconfigure / Exit) |
| `Alt+Space` | window menu |

Everything else comes from `<default />`, which loads labwc's built-in binds.

## Monitors

labwc has **no output configuration anywhere** — not in `rc.xml`, not as a CLI
flag. Unlike niri's `output {}` blocks, monitors are delegated entirely to
external wlroots tools.

Kanshi was tried first and did not work on this build (`kanshi 1.9.0` rejects
TOML `[profile.name]` headers, and even valid `profile "name"` directives
reported `no profile matched`). `wlr-randr` works, so it is used instead.

The layout mirrors the niri config exactly, and is applied from `autostart`
after a 2-second delay so outputs finish being detected:

```
HDMI-A-4   1920x1080@120   0,0       primary, bottom
DP-4       1920x1080@60    0,-1080   directly above
```

**Y grows downward, so a monitor above has a NEGATIVE y** — same as niri.

Check or change it at any time:

```bash
wlr-randr                                                  # inspect
wlr-randr --output HDMI-A-4 --mode 1920x1080@120.000000 --pos 0,0 --on
wlr-randr --output DP-4     --mode 1920x1080@60.000000  --pos 0,-1080 --on
```

Gotchas: the flag is `--pos`, **not** `--position`. And avoid `--above HDMI-A-4`,
which repositioned HDMI-A-4 to `1920,-1080` as a side effect — set both
positions explicitly instead.

| File | Purpose |
|---|---|
| `rc.xml` | Main config. Mirrors niri's focus/pointer/keyboard settings. |
| `environment` | `XKB_DEFAULT_LAYOUT=us,ru` + `grp:alt_shift_toggle`, matching niri. |
| `autostart` | Intentionally near-empty — black background, no panel, for clean window-edge judgement. All options commented out. |
| `menu.xml` | Right/middle-click root menu. |

## Gotcha: XML comments cannot contain `--`

XML forbids the double hyphen inside comments. A comment containing
`labwc --reconfigure` makes the whole file unparseable, and labwc silently
ignores a broken `rc.xml`. If you edit comments there, avoid `--`.

Validate after editing:

```bash
python3 -c "import xml.etree.ElementTree as ET; ET.parse('$HOME/.config/labwc/rc.xml'); print('ok')"
```

## Not run yet

labwc itself is **not installed** — it needs your sudo password. So the config is
written and XML-validated, but has never been launched. Expect to shake out
small things on first boot (notably: whether the portal autostarts, and whether
you want the noctalia shell running under it).
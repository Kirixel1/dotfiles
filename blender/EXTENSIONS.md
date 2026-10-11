# Blender extensions (not vendored in this repo)

The installed extension **binaries** are deliberately *not* committed here.

| Reason | Detail |
|---|---|
| Reinstallable | Both come from `extensions.blender.org` and are one click away in Blender's extension browser. |
| Mostly generated code | `math_art` is 30 MB, of which **7.1 MB is `__pycache__`** (regenerable bytecode) and the rest is vendored third-party `.py`/`.png`, not our code. |
| Not what actually breaks | The thing that gets lost is the **enabled/disabled flag**, and that lives inside `config/userpref.blend` — which *is* tracked. |

## What to install

Reinstall these in Blender after copying the config:

| Extension | ID | Version | Min Blender |
|---|---|---|---|
| Math Art | `math_art` | 1.20.1 | 4.2.0 |
| Palette | `palette` | 1.1.5 | 4.5.0 |

Both from the `blender_org` repository (`https://extensions.blender.org`).

## Enable state

The enabled flags for both are already stored in `blender/5.2/config/userpref.blend`
as `bl_ext.blender_org.math_art` and `bl_ext.blender_org.palette`. Once the extensions
are installed on a new machine, Blender picks those flags up and they stay enabled.

## Persistence gotcha (cost us an hour on Linux, will bite on Windows too)

Blender only writes `userpref.blend` when you explicitly save preferences, or on quit
if **Preferences → General → Startup → "Save Preferences on Quit"** is ticked.

If that box is off, toggling an extension works for the session and silently reverts
on the next launch. Toggle it on **before** trusting any enable state you have backed
up here.
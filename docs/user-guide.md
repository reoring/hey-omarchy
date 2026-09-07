# Hyprland Shortcut Guide (omarchy-reoring-taisyo)

This guide documents the Hyprland keybindings shipped by this repo.

Source in this repo: `home/.config/hypr/hey-omarchy-bindings.lua`
Installed to: `~/.config/hypr/hey-omarchy-bindings.lua` (via `apply.sh`)

## Modifier keys

- `Super`: the Windows/Command key
- `Hyper`: `Super+Ctrl+Alt+Shift`, produced through keyd's shared layer by holding kana or the registered roBa right thumb.
- `Alt`: either ordinary Alt key; used with Shift for window moves, not workspace switching.
- `code:10..19`: the number row (`1..0` on most layouts)

Tap kana alone and release it in less than 200 ms to send Enter. Hold kana while pressing another key to use Hyper immediately, without waiting for the tap timeout; releasing a standalone long hold sends no Enter. Caps remains Ctrl through Hyprland's `ctrl:nocaps` option.

Henkan taps Backspace and holds Shift; Muhenkan taps the original Muhenkan key and holds Shift. Both share the 200 ms tap limit and immediate chord behavior. Releasing a standalone long hold sends no tap. Holding both conversion keys keeps Shift active until both are released.

A uses `overloadi(a, overloadt(control, a, 250), 200)`: recent typing within 200 ms keeps A literal even if held. Otherwise, release before 250 ms for A or hold at least 250 ms for Ctrl. Quick intervening key taps do not force Ctrl, unlike `lettermod`/`overloadt2`. An A after a pause is emitted on release, so this intentionally trades immediate Ctrl chords and idle A auto-repeat for safer typing. To use Ctrl immediately after typing, use the ordinary Ctrl/Caps key.

These kana/conversion/A remaps belong to the portable `[ids] *` fallback. roBa instead has an explicit keyboard configuration: its right thumb taps Enter / holds Right Command in firmware, and host keyd maps the hold (`rightmeta`) with `layer(hyper)`. Left Super and the trackball are unchanged, and roBa does not inherit the generic A→Ctrl remap. Only keyboard IDs `k:1d50:615e:c4fd5cd7` and `k:1d50:615e:a41a014e` are registered for USB/Bluetooth; other firmware/device names may need keyboard identification with `keyd monitor` and an updated bundle ID. The host mapping works with or without roBa's MAC layer because both emit `RIGHT_WIN`. It neither changes another machine nor flashes firmware.

keyd is required. `apply.sh` uses the existing `setup-keyd.sh` to install `etc/keyd/kana-hyper.conf`, `etc/keyd/roba-hyper.conf`, and the shared `etc/keyd/hyper` into `/etc/keyd/` as one transaction before changing Hyprland defaults, with one interactive sudo escalation per setup invocation. `--skip-packages` requires keyd to be preinstalled. Explicit device configurations take precedence over the portable fallback. `apply.sh --check`, `apply.sh --dry-run`, and `setup-keyd.sh --dry-run` do not authenticate or change the host. To remake only this keyd setup, run `bash ./setup-keyd.sh`; registration in the bundle does not itself deploy it. See the [README](../README.md#apply) for apply commands, per-file backups, and conservative rollback that preserves user changes and shared include dependencies.

Emergency: press **Backspace+Escape+Enter together** to stop keyd if its remaps prevent normal input. Correct the configuration before restarting keyd.

Tip: Press `Super+I` to open Omarchy's keybinding menu (`omarchy menu keybindings`).

## App launchers

| Keys | Action |
| --- | --- |
| `Super+Enter` | Terminal (opens in "terminal cwd") |
| `Super+Shift+F` | File manager (Nautilus) |
| `Super+Shift+B` | Browser |
| `Super+Shift+Alt+B` | Browser (private) |
| `Super+Shift+M` | Music (Spotify) |
| `Super+Shift+N` | Editor |
| `Super+Shift+D` | Docker TUI (lazydocker) |
| `Super+Shift+G` | Signal |
| `Super+Shift+O` | Obsidian |
| `Super+Shift+W` | Typora |
| `Super+Shift+/` | 1Password |

## Web apps

| Keys | Action |
| --- | --- |
| `Super+Shift+A` | ChatGPT |
| `Super+Shift+Alt+A` | Grok |
| `Super+Shift+C` | HEY Calendar |
| `Super+Shift+E` | HEY Mail |
| `Super+Shift+Y` | YouTube |
| `Super+Shift+Alt+G` | WhatsApp |
| `Super+Shift+Ctrl+G` | Google Messages |
| `Super+Shift+P` | Google Photos |
| `Super+Shift+X` | X |
| `Super+Shift+Alt+X` | X (compose) |

## Workspaces (Hyper workflow)

This setup treats one display as the "main" monitor:

- `Hyper+QWERTASDFG` always targets workspaces `1..10` on the current main monitor.
- `Hyper+ZXCVB` targets workspaces `11..15` on the main monitor.
- `Hyper+YUIOP` targets `16..20`, and `Hyper+;` targets `25`. Hyper+H/J/K/L have no workspace bindings; Alt+H/J/K/L and Alt+Shift+H/J/K/L remain free for tmux.
- `Hyper+1..0` targets "parking" workspaces on the non-main monitor when an external display is connected:
  - `1=99` .. `0=90`
  - If there is no second monitor, these fall back to `11..20`.

Switch which monitor is considered "main" with `Super+Ctrl+M`.

The Quattro bar's main-monitor widget is clickable:

- Left click: toggle main monitor
- Right click: set external monitor position (left/right/up/down)

You can also run `hypr-monitor-position menu` or `hypr-monitor-position left|right|up|down`.

### Switch workspace

| Keys | Action |
| --- | --- |
| `Hyper+Q/W/E/R/T` | Go to workspace `1/2/3/4/5` (main) |
| `Hyper+A/S/D/F/G` | Go to workspace `6/7/8/9/10` (main) |
| `Hyper+Z/X/C/V/B` | Go to workspace `11/12/13/14/15` (main) |
| `Hyper+Y/U/I/O/P` | Go to workspace `16/17/18/19/20` (main) |
| `Hyper+;` | Go to workspace `25`; H/J/K/L have no workspace bindings |
| `Hyper+1..0` | Go to parking workspace `99..90` (fallback `11..20`) |

### Move active window

Hold kana or roBa Hyper and an additional Shift, then press the same letter, semicolon, or number-row key:

- Hyper+Shift+key moves the active window to that workspace (and focuses it). Either physical Shift or a held Henkan/Muhenkan mapped to Shift works, in either press order. keyd's shared `[hyper+shift]` layer distinguishes the additional Shift from Hyper's emulated Shift and emits the existing Alt+Shift move shortcut. Ordinary Alt+Shift still works. This distinction requires entering keyd's shared Hyper layer, as both the kana and roBa configurations do; a keyboard emitting only four modifiers does not provide it.
- The old Alt-only workspace-switching bindings are explicitly removed.

## Window / display adjustments

| Keys | Action |
| --- | --- |
| `Super+H/J/K/L` | Move focus left/down/up/right |
| `Super+U` | Toggle split (dwindle) |
| `Super+Ctrl+-` / `Super+Ctrl+=` | Nightlight warmer/cooler (hyprsunset) |
| `Super+Alt+-` / `Super+Alt+=` | Active window opacity down/up |
| `Super+Alt+Shift+-` / `Super+Alt+Shift+=` | Global blur down/up |
| `Super+Shift+;` / `Super+Shift+'` | Workspace gaps down/up |
| `Super+Shift+Ctrl+-` / `Super+Shift+Ctrl+=` | External monitor scale down/up |
| `Super+Ctrl+R` | Toggle refresh rate (60/120 when available) |
| `Super+Ctrl+Y` | Toggle the native Quattro bar |
| `Super+Ctrl+M` | Toggle main monitor + consolidate workspaces |
| `Super+Ctrl+P` | Toggle internal display (safe: won't disable your only monitor) |
| `Super+Ctrl+O` | Toggle lid-close suspend (systemd user service) |
| `Super+Ctrl+Alt+O` | Toggle automatic rotation, persisted for next login |

Notes:

- Opacity adjustment (`Super+Alt+-` / `Super+Alt+=`) uses window tags and native rules in `~/.config/hypr/hey-omarchy.lua`, preserving opacity across title changes and reloads.

## Where to change things

- Keybindings live in `~/.config/hypr/hey-omarchy-bindings.lua`; input and opacity rules live in `~/.config/hypr/hey-omarchy.lua`.
- Edit the bundle's `etc/keyd/kana-hyper.conf` for portable kana/conversion/A tap/hold mappings, `etc/keyd/roba-hyper.conf` for the exact-ID roBa right-thumb hold mapping, and `etc/keyd/hyper` for shared Hyper/Hyper+Shift behavior. Both `.conf` files use `include hyper`; `setup-keyd.sh` installs all three into `/etc/keyd/`. Hyprland's `kb_file` is empty; the old kana XKB file is retired.
- Workspace routing logic is implemented by `~/.local/bin/hypr-ws` and `~/.local/bin/hypr-main-monitor-toggle`.

## Stock shortcuts overridden

Super+J (split) moves to U, Super+K (keybindings) moves to I, and H/J/K/L become focus directions. Super+Ctrl+R (reminder), P (power panel), and O (menu) become refresh-rate, internal-display, and lid-suspend controls. Competing stock bindings are explicitly removed before custom bindings are installed.

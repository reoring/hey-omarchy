# Hyprland Shortcut Guide (omarchy-reoring-taisyo)

This guide documents the Hyprland keybindings shipped by this repo.

Source in this repo: `home/.config/hypr/hey-omarchy-bindings.lua`
Installed to: `~/.config/hypr/hey-omarchy-bindings.lua` (via `apply.sh`)

## Modifier keys

- `Super`: the Windows/Command key
- `AltGr`: Right Alt / kana key in this guide. Native Lua uses `ALT` (Mod1), matching the old configuration; left Alt works too.
- `code:10..19`: the number row (`1..0` on most layouts)

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

## Workspaces (AltGr workflow)

This setup treats one display as the "main" monitor:

- `AltGr+QWERTASDFG` always targets workspaces `1..10` on the current main monitor.
- `AltGr+ZXCVB` targets workspaces `11..15` on the main monitor.
- `AltGr+YUIOP` targets `16..20`, and `AltGr+;` targets `25`. H/J/K/L and their shifted forms are left free for tmux.
- `AltGr+1..0` targets "parking" workspaces on the non-main monitor when an external display is connected:
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
| `AltGr+Q/W/E/R/T` | Go to workspace `1/2/3/4/5` (main) |
| `AltGr+A/S/D/F/G` | Go to workspace `6/7/8/9/10` (main) |
| `AltGr+Z/X/C/V/B` | Go to workspace `11/12/13/14/15` (main) |
| `AltGr+Y/U/I/O/P` | Go to workspace `16/17/18/19/20` (main) |
| `AltGr+;` | Go to workspace `25`; H/J/K/L are unbound for tmux |
| `AltGr+1..0` | Go to parking workspace `99..90` (fallback `11..20`) |

### Move active window

Add `Shift` to the workspace keys:

- `AltGr+Shift+...` moves the active window to that workspace (and focuses it).

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
- Workspace routing logic is implemented by `~/.local/bin/hypr-ws` and `~/.local/bin/hypr-main-monitor-toggle`.

## Stock shortcuts overridden

Super+J (split) moves to U, Super+K (keybindings) moves to I, and H/J/K/L become focus directions. Super+Ctrl+R (reminder), P (power panel), and O (menu) become refresh-rate, internal-display, and lid-suspend controls. Competing stock bindings are explicitly removed before custom bindings are installed.

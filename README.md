# Hey Omarchy-! / へい、おまち〜!

reoring's personal configuration bundle for **Omarchy Quattro (4.x)**, using native Hyprland Lua and the Quickshell desktop shell. Omarchy 3's Hyprland/Waybar configuration is no longer installed.

The bundle leaves Omarchy-managed source files untouched. `apply.sh` backs up changed user files, installs dedicated modules, appends their loader to `hyprland.lua`, and merges custom widgets into the existing `shell.json`. Ordinary user Lua modules, standard bar widgets, and unrelated shell settings are preserved.

Docs: [Japanese README](README.ja.md), [shortcut guide](docs/user-guide.md), [Japanese shortcut guide](user-guide.ja.md), [CSKK notes](japanese/cskk.md).

## What is preserved

- Main-monitor workspaces 1–20 and 25, with parking workspaces 99–90 on the other display and 11–20 single-monitor fallback. Add Shift to move a window. Alt+H/J/K/L are deliberately left free for tmux.
- Right Alt and the kana key operate the workspace shortcuts. Lua uses `ALT` (Mod1), matching the old configuration's actual `ALTGR` behavior; left Alt also matches. Do not write `ALTGR` in native Lua key strings.
- Caps→Ctrl, kana→Alt_R, key repeat 40/600, natural touchpad scrolling at 0.4, and touchpad use while typing.
- Super+H/J/K/L focus, personal app/web-app shortcuts, opacity tags, blur, gaps, scale, refresh rate, monitor positioning, nightlight, and display controls.
- Native bar controls for main monitor, DDC brightness, Fcitx JP/EN, lid suspension, keyboard cleaning, cursor visibility, roBa Bluetooth, WWAN, Tailscale, and CPU/btop.
- Fifteen-minute idle lock and sixteen-minute display blanking, without a preceding screensaver. Resume restores display brightness.
- Sensor-driven display/touch/pen rotation and the existing service's enabled/disabled state.
- Fcitx5/CSKK ASCII passthrough and GTK Emacs-style keys/window controls.

The legacy `waybar-*` executable names remain JSON status producers used by Quickshell. Neither Waybar nor Walker is required. Native shell IPC refreshes the widgets after actions.

## Configuration locations

| File | Purpose |
|---|---|
| `~/.config/hypr/hey-omarchy.lua` | Input, opacity/window rules, optional hardware environment |
| `~/.config/hypr/hey-omarchy-bindings.lua` | Personal keybindings; explicit unbinds override stock shortcuts |
| `~/.config/hypr/keymap-kana-altgr.xkb` | Kana and Caps keyboard mapping |
| `~/.config/hypr/hey-omarchy-options.lua` | Generated monitor/NVIDIA install options |
| `~/.config/omarchy/shell.json` | Existing bar layout plus custom entries and idle settings |
| `~/.config/omarchy/plugins/hey-omarchy/` | Shared status service and native widgets |
| `~/.config/omarchy/plugins/hey-omarchy-lock/` | User-owned lock plugin preserving the old display timeout |
| `~/.local/bin/` | Adjustment, status, input, network, and hardware helpers |
| `~/.config/systemd/user/` | Lid inhibitor and automatic rotation services |

The lock plugin is cloned from Omarchy **4.0.2**; authentication and session locking remain the upstream implementation. Its display idle timeout is configurable as `idle.dpms`. Review/rebase this user-owned clone when upgrading Omarchy's lock implementation; package updates do not update local clones automatically.

## Apply

From this directory:

```sh
bash ./apply.sh --check
bash ./apply.sh --dry-run --skip-packages
bash ./apply.sh --skip-packages
```

Omit `--skip-packages` when the input-method/DDC dependencies still need installing. Applying briefly restarts `omarchy-fcitx5.service` if active, validates and reloads Hyprland, and restarts the desktop shell to avoid stale cached QML components. Applications and the login session stay running.

Unchanged files are skipped. Reapplication preserves existing custom widget positions/settings and does not duplicate widgets. Bundle-owned settings are reapplied, including idle timeouts, so keep intended changes in the bundle too. Old live `.conf` files and Quattro migration backups are not deleted.

Options:

- `--check`: inspect required files and available tools without changing user configuration.
- `--dry-run`: show proposed operations without applying them.
- `--skip-packages`: skip yay package installation.
- `--no-bar`: skip shell widgets and idle settings.
- `--gtk-gsettings` / `--no-gtk-gsettings`: enable/disable GTK preference application (enabled by default).
- `--force-monitors`: apply generic preferred-mode/automatic-position/automatic-scale monitor policy; otherwise preserve `monitors.lua`.
- `--force-nvidia-env` / `--skip-nvidia-env`: override NVIDIA detection. AMD/Intel systems receive no NVIDIA variables by default.
- `--with-shaders`: create user symlinks to installed Aether shaders.

Optional hardware setup:

```sh
bash ./setup-ddcutil.sh
bash ./setup-wwan-latency-switcher.sh --help
bash ./setup-mpvpaper-live-wallpaper.sh --help
```

DDC requires a compatible external display; WWAN requires modem hardware/tools. Absence is displayed rather than treated as successful hardware operation. Automatic rotation requires `monitor-sensor` from iio-sensor-proxy.

The existing CSKK setup may use sudo to register `/usr/lib/cskk` in `/etc/ld.so.conf.d/cskk.conf` if needed; see the CSKK notes.

## Verify and customize

```sh
hyprctl configerrors
omarchy shell hey-omarchy status
omarchy shell idle status
omarchy shell lock status
bash tests/run.sh
```

Edit the bundle's `home/` files and reapply, or edit installed user copies directly. `home/.config/omarchy/hey-omarchy.json` is an installer fragment, not a replacement shell configuration. Its `barAdditions` are merged by widget id and name; standard widgets and unrelated settings remain intact.

Quattro's stock Super+J/K/L and several Ctrl shortcuts are intentionally overridden; see the shortcut guide. `Super+Ctrl+Y` now toggles the native bar, and `Super+Ctrl+Alt+O` toggles persistent automatic rotation.

## Rollback

Changed files are backed up next to their originals as `*.bak.YYYYmmdd-HHMMSS`.

```sh
bash ./rollback.sh --dry-run
bash ./rollback.sh
```

Rollback restores the latest apply backups for managed files, including the Lua entrypoint and shell configuration, then reloads Hyprland and restarts the shell. Files first created by the bundle have no prior backup and are left on disk. This reverses the customization bundle, **not** the Quattro system upgrade.

## License

MIT (see `LICENSE`).

# Hey Omarchy-! / へい、おまち〜!

reoring's personal configuration bundle for **Omarchy Quattro (4.x)**, using native Hyprland Lua and the Quickshell desktop shell. Omarchy 3's Hyprland/Waybar configuration is no longer installed.

The bundle leaves Omarchy-managed source files untouched. `apply.sh` backs up changed user files, installs dedicated modules, appends their loader to `hyprland.lua`, and merges custom widgets into the existing `shell.json`. It also installs the system keyd configuration described below using sudo. Ordinary user Lua modules, standard bar widgets, and unrelated shell settings are preserved.

Docs: [Japanese README](README.ja.md), [shortcut guide](docs/user-guide.md), [Japanese shortcut guide](user-guide.ja.md), [CSKK notes](japanese/cskk.md).

## What is preserved

- Hyper switches main-monitor workspaces 1–20 and 25, with parking workspaces 99–90 on the other display and 11–20 single-monitor fallback. Shared kana/roBa/moNa2 Hyper+Shift moves windows using the same keys; ordinary Alt+Shift also works. Alt+H/J/K/L and Alt+Shift+H/J/K/L remain free for tmux.
- Kana taps Enter when released within 200 ms without a chord; holding it provides Hyper (`Super+Ctrl+Alt+Shift`). Chords activate immediately, with no 200 ms wait; releasing a standalone long hold sends no Enter. Ordinary Alt no longer switches workspaces.
- roBa and moNa2 retain firmware Enter on right-thumb tap / Right Command on hold. On this host, keyd maps that hold to the shared Hyper layer; left Super and trackball input are unchanged. Kana/conversion/A remaps apply only to the registered built-in keyboard, not these external keyboards.
- Henkan taps Backspace and holds Shift. Muhenkan retains its original tap and holds Shift. Both use the same 200 ms tap limit and activate Shift immediately for chords; standalone long holds send no tap.
- A taps normally and holds Ctrl after 250 ms, but stays a literal A when pressed within 200 ms of recent typing. Fast overlapping taps do not force Ctrl. This favors typing safety over immediate Ctrl chords; an A after a pause appears on release.
- Caps→Ctrl remains in Hyprland, with key repeat 40/600, natural touchpad scrolling at 0.4, and touchpad use while typing.
- Super+H/J/K/L focus, personal app/web-app shortcuts, opacity tags, blur, gaps, scale, refresh rate, monitor positioning, nightlight, and display controls.
- Native bar controls for main monitor, DDC brightness, Fcitx JP/EN, lid suspension, keyboard cleaning, cursor visibility, roBa Bluetooth, WWAN, Tailscale, CPU/btop, and CPU frequency limits/boost.
- Fifteen-minute idle lock and sixteen-minute display blanking, without a preceding screensaver. Resume restores display brightness.
- Sensor-driven display/touch/pen rotation and the existing service's enabled/disabled state.
- Fcitx5/CSKK ASCII passthrough and GTK Emacs-style keys/window controls.

The legacy `waybar-*` executable names remain JSON status producers used by Quickshell. Neither Waybar nor Walker is required. Native shell IPC refreshes the widgets after actions.

## Configuration locations

| File | Purpose |
|---|---|
| `~/.config/hypr/hey-omarchy.lua` | Input, opacity/window rules, optional hardware environment |
| `~/.config/hypr/hey-omarchy-bindings.lua` | Personal keybindings; explicit unbinds override stock shortcuts |
| `/etc/keyd/kana-hyper.conf` | Built-in keyboard only: kana, Henkan, Muhenkan, and A tap/hold mappings; includes `hyper` |
| `/etc/keyd/roba-hyper.conf` | Exact roBa/moNa2 keyboard IDs; maps `rightmeta = layer(hyper)` and includes `hyper` |
| `/etc/keyd/hyper` | Shared `[hyper:C-A-S-M]` and `[hyper+shift]` layers for workspace switching and window moves |
| `~/.config/hypr/hey-omarchy-options.lua` | Generated monitor/NVIDIA install options |
| `~/.config/omarchy/shell.json` | Existing bar layout plus custom entries and idle settings |
| `~/.config/omarchy/plugins/hey-omarchy/` | Shared status service and native widgets |
| `~/.config/omarchy/plugins/hey-omarchy-lock/` | User-owned lock plugin preserving the old display timeout |
| `~/.config/omarchy/plugins/reoring.rain/` | Bundled wallpaper rain and glass droplets, including the compiled shader; enabling is left to the user's shell configuration |
| `~/.local/bin/` | Adjustment, status, input, network, and hardware helpers |
| `~/.config/systemd/user/` | Lid inhibitor and automatic rotation services |

The lock plugin is based on Omarchy **4.0.2**, with the host's face-unlock extension restored. Its display idle timeout is configurable as `idle.dpms`. Face scanning requires the existing trusted `/etc/pam.d/omarchy-lock-face` service, Howdy installation/account gate under `/opt/howdy/`, camera configuration, enrolled models, and `dbus-monitor`. This bundle does not install or overwrite that authentication stack or copy biometric data; without the face PAM service, face unlock stays disabled and password/fingerprint handling remains available as configured. F2 or clicking the face hint retries recognition; password input, sleep, and display blanking cancel a scan. Review/rebase this user-owned clone when upgrading Omarchy; package updates do not update local clones automatically.

The `cpu-frequency` widget uses the bundled `hey-cpu-frequency` helper. Status is read-only and refreshes every 30 seconds. Left click opens upper-limit/uncap/boost choices; right click opens btop. Changes require Polkit authorization through `pkexec`, supported Linux cpufreq controls, and the Omarchy menu/notification commands. Limits are temporary, not fixed CPU clocks, and may reset on reboot or power-management changes.

## Apply

From this directory:

```sh
bash ./apply.sh --check
bash ./apply.sh --dry-run --skip-packages
bash ./apply.sh --skip-packages
```

keyd is required. Omit `--skip-packages` when keyd or the input-method/DDC dependencies still need installing; `--skip-packages` requires keyd to be preinstalled. `apply.sh` calls the existing `setup-keyd.sh` to install all three files from `etc/keyd/` into `/etc/keyd/` as one transaction, using one normal interactive sudo escalation per setup invocation. It enables/starts keyd, reloading its configuration when already active. This setup must succeed before user Hyprland defaults are changed. `--check` and `--dry-run` do not authenticate, change the host, or start/reload services.

`etc/keyd/kana-hyper.conf` matches only the built-in keyboard ID `0001:0001:3cf016cc`, with `katakanahiragana = overload(hyper, enter)` and `[global] overload_tap_timeout = 200`; there is no wildcard fallback. `etc/keyd/roba-hyper.conf` registers roBa IDs `k:1d50:615e:c4fd5cd7` / `k:1d50:615e:a41a014e` and moNa2 IDs `k:1d50:615e:90998e90` / `k:1d50:615e:534ac1e7`. These external keyboards do not receive the built-in keyboard's A→Ctrl remap. Other firmware/device names may produce different IDs: identify the keyboard with `keyd monitor` before adapting the bundle.

Both configurations use `include hyper` to share `etc/keyd/hyper`, including Hyper+Shift window moves. roBa/moNa2 firmware emits Enter on right-thumb tap and Right Command (`RIGHT_WIN`, seen by keyd as `rightmeta`) on hold. The host maps only that hold to Hyper; left Super and trackball input are unchanged. The mapping applies with or without roBa's MAC layer because both emit the same `RIGHT_WIN`. It does not change another machine or flash firmware. Registration in this repository alone does not deploy it.

To preview or remake only the keyd portion with keyd already installed:

```sh
bash ./setup-keyd.sh --dry-run
bash ./setup-keyd.sh
```

Hyprland uses an empty `kb_file` and retains `kb_options = "ctrl:nocaps"`; the obsolete installed `~/.config/hypr/keymap-kana-altgr.xkb` is backed up and removed.

Applying briefly restarts `omarchy-fcitx5.service` if active, validates and reloads Hyprland, and restarts the desktop shell to avoid stale cached QML components. Applications and the login session stay running. If a keyd remap makes typing unusable, press **Backspace+Escape+Enter together** to stop keyd; fix its configuration before starting it again.

Unchanged files are skipped. Reapplication preserves existing custom widget positions/settings and does not duplicate widgets. **Managed files are replaced by the repository copies, not merged**, after saving adjacent timestamped backups; review local changes before applying and bring them into the bundle first. Shell JSON is merged, but bundle-owned settings such as idle timeouts are reapplied. Old live `.conf` files and Quattro migration backups are not deleted.

Options:

- `--check`: inspect required files and available tools without authentication or host changes.
- `--dry-run`: show proposed operations without authentication or host changes.
- `--skip-packages`: skip yay package installation; keyd must already be installed.
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

Changed files, including all three `/etc/keyd/` bundle files and the obsolete kana XKB file when present, are backed up next to their originals as `*.bak.YYYYmmdd-HHMMSS`.

```sh
bash ./rollback.sh --dry-run
bash ./rollback.sh
```

Rollback restores the latest apply backups for managed user files, including the Lua entrypoint and shell configuration, then reloads Hyprland and restarts the shell. For keyd, it uses sudo and per-file ownership/backup records to restore prior files, or safely remove bundle-created files when there were no previous files. Only unchanged, bundle-owned files are reverted: later user edits are preserved, and identical preexisting files are not claimed. Rollback conservatively preserves the shared `hyper` include when retained configurations depend on it. It reloads keyd if active without disabling the service or removing unrelated remaps. To roll back only keyd, use `bash ./setup-keyd.sh --rollback` (add `--dry-run` to preview without authentication or host changes). The obsolete kana XKB file is restored when an apply backup exists. Other files first created by the bundle have no prior backup and are left on disk. `--dry-run` changes nothing. This reverses the customization bundle, **not** the Quattro system upgrade.

## License

MIT (see `LICENSE`).

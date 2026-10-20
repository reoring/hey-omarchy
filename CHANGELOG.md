# Changelog

## Unreleased

- Add `Super+Shift+V` and a "Windows 11" launcher entry for the libvirt `win11` VM: `win11` starts or resumes the domain on `qemu:///system` when needed, then opens its virt-manager console or focuses the existing one, notifying on failure (including hosts without the VM).
- Bundle the remaining shell personalization: the power widget's battery percentage through a new `barWidgetSettings` fragment step reasserted on every apply (so machines that already swapped in `reoring.power` get it too), the machine-level `~/.config/omarchy/shell.toml` text size (`[font] base-size = 12`), and the `reoring.background` wallpaper-video service clone, installed but left disabled.
- Bundle the bar consolidation: personal clones of the stock Bluetooth, network, display, and power panels (`reoring.*`) absorb roBa, mobile data (5G/LTE status, signal, connect toggle, Auto/5G/4G), DDC brightness, main monitor/external position, and CPU usage/frequency limits; Omarchy's Tailscale widget replaces the drawer's Tailscale control, leaving five drawer controls. Apply swaps the stock entries in place through the new `barReplacements` fragment step, keeping their settings, and installs executable plugin helpers such as `mobile-status` with their exec bit.
- Stop `setup-wwan-docomo.sh` from restricting NetworkManager to WWAN: Omarchy retired systemd-networkd, so the `10-wwan-only.conf` split left Ethernet unmanaged. `install`/`uninstall` now remove the marker-tagged `10-wwan-only.conf` and `10-wwan-unmanaged.network`, and `uninstall` no longer disables NetworkManager.
- Support the X1 Carbon Gen 14 Foxconn T99W696 WWAN modem (PCI `17cb:0308`) in `setup-wwan-docomo.sh`: detect the modem family by PCI id, install `lenovo-wwan-unlock` and enable `lenovo-cfgservice.service` for the FCC unlock, and re-run the unlock on `enable` instead of the Quectel-only `--direct-mbim` path.
- Harden the MHI WWAN suspend hook: stop ModemManager and `mbim-proxy` before unloading MHI, wait for `wwan0mbim0` before restarting it on resume, and run a post-resume watchdog that recovers a wedged MBIM channel (`NotOpened`) with up to two MHI `soc_reset` recoveries.
- Register `/usr/lib/cskk` with the dynamic linker for any `libcskk.so.N`; cskk 4.0 ships `libcskk.so.4`, so the previous `.so.3`-only check skipped the fix and CSKK failed to load.
- Preserve the current right-side ordering on apply: keep the personal-control drawer directly after the system tray and place agents after Bluetooth. The system tray and personal controls remain separate.
- Move the remaining center indicators, keyboard layout, weather, and update widgets beside the left-aligned clock, leaving the center empty without disabling their features.
- Group all 13 personal bar controls behind a `⋯` / `‹` visibility toggle; start collapsed without disabling their functions or status polling. Replace legacy per-control entries, hide workspace labels, and move the existing clock beside the left menu while preserving its format.
- Restore custom bar widget visibility on current Omarchy by using the scoped `serviceFor()` API instead of the inaccessible private service registry.
- Restore all ten audited pre-apply files, including built-in-only kana mapping, both moNa2 IDs, face-unlock service/UI, CPU-frequency widget definitions, Fcitx profiles/notifications, and original binding/helper text.
- Bundle `hey-cpu-frequency` and register its bar entry; retain existing Howdy/PAM as an external host prerequisite without copying biometric data or changing authentication setup.
- Bundle the existing `reoring.rain` wallpaper rain and glass-droplet plugin, including shader source and compiled QSB, without changing shell enablement.
- Add a rain-icon bar toggle and `hey-rain status|toggle|on|off`; persist the selection through the shell plugin API and unload both rain and glass rendering when off.
- Default CSKK to Ascii for new input contexts, retaining ASCII key passthrough and the existing `Ctrl-j` / `l` mode switches.
- Map the registered built-in keyboard's Right Alt directly to three-modifier Hyper (`Super+Ctrl+Alt`); keep kana as tap Enter / hold Hyper with a 200 ms tap limit and immediate chords, and retain Caps→Ctrl.
- Add Henkan tap Backspace / hold Shift and Muhenkan original tap / hold Shift, using the same 200 ms tap limit.
- Make A tap A / hold Ctrl with a 250 ms hold threshold, a 200 ms recent-typing guard, and no early Ctrl activation from overlapping taps.
- Bind Hyper to workspace switching and Hyper+Shift directly to window moves, including held Henkan/Muhenkan as Shift; retire the old four-modifier Hyper composite and Alt+Shift routing.
- Install and back up the keyboard configurations before Hyprland changes; retire the kana XKB map and restore prior keyboard configuration on rollback.
- Register roBa/moNa2 host-only right-thumb mappings alongside built-in-only input remaps, sharing the three-modifier Hyper layer through the transactional keyd setup with dependency-aware rollback; preserve firmware Enter taps, left Super, and trackball input.

## v0.2.0 - 2026-09-07

- Migrate the bundle to Omarchy Quattro: native Hyprland Lua modules, typed Lua helper mutations, and Quickshell status widgets instead of Waybar/Walker.
- Preserve installed kana/Caps mapping, tmux-safe Alt workspace shortcuts, touchpad settings, opacity tags, automatic rotation, and hardware controls.
- Merge custom shell settings without dropping unrelated widgets or duplicating entries; preserve 900-second lock and 960-second display idle timing with a user-owned lock clone.
- Update apply/rollback for dedicated Lua modules, the Quattro Fcitx service, backups, and a fresh shell restart; validate shell setting preservation and rollback.

## v0.1.0 - 2026-04-22

- Unbind default `SUPER+L` so vim-style focus-right works without conflicting with omarchy's workspace layout toggle.
- Add a CSKK ASCII (@) passthrough rule so key-driven apps (e.g. Obsidian Vim mode, Steam games) keep receiving key events.
- apply.sh installs `~/.config/fcitx5/conf/fcitx5-cskk` and generates `~/.local/share/libcskk/rules/passthrough_ascii/rule.toml` from system rules.
- Document the rationale and snippets in `japanese/cskk.md`.
- Add a WWAN latency switcher helper + setup script and test coverage.
- Add a mpvpaper live wallpaper setup helper.
- Adjust Hyprland AltGr workspace routing and extend `hypr-ws` for internal/external monitor targets.

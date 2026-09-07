# Changelog

## Unreleased

- Default kana to tap Enter / hold Hyper via required keyd (200 ms tap limit, immediate chords), and move workspace switching to Hyper while retaining Alt+Shift window moves and Caps→Ctrl.
- Add Henkan tap Backspace / hold Shift and Muhenkan original tap / hold Shift, using the same 200 ms tap limit.
- Make A tap A / hold Ctrl with a 250 ms hold threshold, a 200 ms recent-typing guard, and no early Ctrl activation from overlapping taps.
- Support kana Hyper+Shift workspace moves through a keyd composite layer, including held Henkan/Muhenkan as Shift, without changing Hyper-only workspace switching.
- Install and back up the portable keyd configuration before Hyprland changes; retire the kana XKB map and restore prior keyboard configuration on rollback.
- Register roBa's host-only right-thumb Hyper mapping alongside the portable kana fallback, sharing Hyper/Hyper+Shift layers through the existing keyd setup with transactional three-file installation and dependency-aware rollback; preserve firmware Enter taps, left Super, and trackball input.

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

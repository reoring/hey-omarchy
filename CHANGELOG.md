# Changelog

## Unreleased

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

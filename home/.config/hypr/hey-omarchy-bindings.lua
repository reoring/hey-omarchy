-- Replace, never stack, custom bindings over stock or normal user bindings.
local function bind(keys, description, action)
  hl.unbind(keys)
  o.bind(keys, description, action)
end

-- Preserve the user's application choices and launch arguments.
bind("SUPER + RETURN", "Terminal", 'uwsm-app -- xdg-terminal-exec --dir="$(omarchy cmd terminal cwd)"')
bind("SUPER + SHIFT + F", "File manager", "uwsm-app -- nautilus --new-window")
bind("SUPER + SHIFT + B", "Browser", "omarchy launch browser")
bind("SUPER + SHIFT + ALT + B", "Browser (private)", "omarchy launch browser --private")
bind("SUPER + SHIFT + M", "Music", "omarchy launch or focus spotify")
bind("SUPER + SHIFT + N", "Editor", "omarchy launch editor")
bind("SUPER + SHIFT + D", "Docker", "omarchy launch tui lazydocker")
bind("SUPER + SHIFT + G", "Signal", 'omarchy launch or focus ^signal$ "uwsm-app -- signal-desktop"')
bind("SUPER + SHIFT + O", "Obsidian", 'omarchy launch or focus ^obsidian$ "uwsm-app -- obsidian -disable-gpu --enable-wayland-ime"')
bind("SUPER + SHIFT + W", "Typora", "uwsm-app -- typora --enable-wayland-ime")
bind("SUPER + SHIFT + SLASH", "Passwords", "uwsm-app -- 1password")
bind("SUPER + SHIFT + A", "ChatGPT", { webapp = "https://chatgpt.com" })
bind("SUPER + SHIFT + ALT + A", "Grok", { webapp = "https://grok.com" })
bind("SUPER + SHIFT + C", "Calendar", { webapp = "https://app.hey.com/calendar/weeks/" })
bind("SUPER + SHIFT + E", "Email", { webapp = "https://app.hey.com" })
bind("SUPER + SHIFT + Y", "YouTube", { webapp = "https://youtube.com/" })
bind("SUPER + SHIFT + ALT + G", "WhatsApp", { webapp = "https://web.whatsapp.com/", focus = true })
bind("SUPER + SHIFT + CTRL + G", "Google Messages", { webapp = "https://messages.google.com/web/conversations", focus = true })
bind("SUPER + SHIFT + P", "Google Photos", { webapp = "https://photos.google.com/", focus = true })
bind("SUPER + SHIFT + X", "X", { webapp = "https://x.com/" })
bind("SUPER + SHIFT + ALT + X", "X Post", { webapp = "https://x.com/compose/post" })

-- Legacy "ALTGR" matched ALT by substring, i.e. Mod1, not Mod5. Native Lua
-- accepts only ALT/MOD1; preserve the user's Alt_R/kana Mod1 keymap. This also
-- retains left Alt's existing behavior. H/J/K/L remain free for tmux.
local workspace_keys = {
  "Q", "W", "E", "R", "T", "A", "S", "D", "F", "G",
  "Z", "X", "C", "V", "B", "Y", "U", "I", "O", "P",
}
for workspace, key in ipairs(workspace_keys) do
  bind("ALT + " .. key, "Switch to workspace " .. workspace, "~/.local/bin/hypr-ws main goto " .. workspace)
  bind("ALT + SHIFT + " .. key, "Move window to workspace " .. workspace, "~/.local/bin/hypr-ws main move " .. workspace)
end
bind("ALT + semicolon", "Switch to workspace 25", "~/.local/bin/hypr-ws main goto 25")
bind("ALT + SHIFT + semicolon", "Move window to workspace 25", "~/.local/bin/hypr-ws main move 25")
for _, key in ipairs({ "H", "J", "K", "L" }) do
  hl.unbind("ALT + " .. key)
  hl.unbind("ALT + SHIFT + " .. key)
end

-- Number row parks on the non-main monitor; retain single-monitor 11-20 fallback.
-- Only Super+number workspace switching was disabled; shifted stock moves stay.
for index = 1, 10 do
  local key = "code:" .. (index + 9)
  local parked = 100 - index
  local fallback = 10 + index
  local target = parked .. " " .. fallback
  hl.unbind("SUPER + " .. key)
  bind("ALT + " .. key, "Parking workspace (" .. parked .. "/" .. fallback .. ")", "~/.local/bin/hypr-ws park goto " .. target)
  bind("ALT + SHIFT + " .. key, "Park window (" .. parked .. "/" .. fallback .. ")", "~/.local/bin/hypr-ws park move " .. target)
end

-- Super+J split moves to U; Super+K keybindings moves to I. Super+L's
-- stock layout toggle is replaced by rightward focus, as in the user's config.
bind("SUPER + U", "Toggle window split", hl.dsp.layout("togglesplit"))
bind("SUPER + I", "Show key bindings", "omarchy menu keybindings")
bind("SUPER + H", "Move window focus left", hl.dsp.focus({ direction = "l" }))
bind("SUPER + J", "Move window focus down", hl.dsp.focus({ direction = "d" }))
bind("SUPER + K", "Move window focus up", hl.dsp.focus({ direction = "u" }))
bind("SUPER + L", "Move window focus right", hl.dsp.focus({ direction = "r" }))

-- Stock resize bindings use physical keycodes, while the user's adjustments
-- use keysyms. Remove both forms so one keypress cannot execute both actions.
-- hl.unbind matches display strings: modifier order must match stock exactly.
for _, modifiers in ipairs({ "SUPER + CTRL", "SUPER + ALT", "SUPER + SHIFT + ALT", "SUPER + CTRL + SHIFT" }) do
  hl.unbind(modifiers .. " + code:20")
  hl.unbind(modifiers .. " + code:21")
end
bind("SUPER + CTRL + minus", "Nightlight stronger (warmer)", "~/.local/bin/hyprsunset-adjust down")
bind("SUPER + CTRL + equal", "Nightlight weaker (cooler)", "~/.local/bin/hyprsunset-adjust up")
bind("SUPER + ALT + minus", "Opacity down", "~/.local/bin/hypr-opacity-adjust down")
bind("SUPER + ALT + equal", "Opacity up", "~/.local/bin/hypr-opacity-adjust up")
bind("SUPER + ALT + SHIFT + minus", "Blur down", "~/.local/bin/hypr-blur-adjust down")
bind("SUPER + ALT + SHIFT + equal", "Blur up", "~/.local/bin/hypr-blur-adjust up")
bind("SUPER + SHIFT + semicolon", "Workspace gaps down", "~/.local/bin/hypr-gaps-adjust down")
bind("SUPER + SHIFT + apostrophe", "Workspace gaps up", "~/.local/bin/hypr-gaps-adjust up")
bind("SUPER + SHIFT + CTRL + minus", "Scale down (external)", "~/.local/bin/hypr-scale-adjust down external")
bind("SUPER + SHIFT + CTRL + equal", "Scale up (external)", "~/.local/bin/hypr-scale-adjust up external")
bind("SUPER + CTRL + R", "Toggle refresh rate (60/120)", "~/.local/bin/hypr-refresh-toggle")
bind("SUPER + CTRL + Y", "Toggle top bar", "omarchy toggle bar")
bind("SUPER + CTRL + J", "Toggle Fcitx EN group", "~/.local/bin/fcitx-en-toggle toggle")
bind("SUPER + CTRL + M", "Toggle main monitor + move workspaces", "~/.local/bin/hypr-main-monitor-toggle")
bind("SUPER + CTRL + P", "Toggle internal display", "~/.local/bin/hypr-internal-display-toggle")
bind("SUPER + CTRL + O", "Toggle lid-close suspend", "~/.local/bin/hypr-lid-suspend-toggle")
bind("SUPER + CTRL + ALT + O", "Toggle automatic screen rotation", "~/.local/bin/hypr-auto-rotate toggle")

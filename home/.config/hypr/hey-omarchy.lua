-- Load after Omarchy defaults and the normal user modules in hyprland.lua.
local options = require("hypr.hey-omarchy-options")

hl.config({
  input = {
    kb_layout = "us",
    kb_options = "ctrl:nocaps",
    kb_file = "", -- Kana tap/hold is handled by keyd.
    repeat_rate = 40,
    repeat_delay = 600,
    numlock_by_default = true,
    touchpad = {
      natural_scroll = true,
      scroll_factor = 0.4,
      disable_while_typing = false,
    },
  },
})

o.window("(Alacritty|kitty)", { scroll_touchpad = 1.5 })
o.window("com.mitchellh.ghostty", { scroll_touchpad = 0.2 })

-- Keep these anonymous: Hyprland evaluates all named rules before anonymous
-- rules, including Omarchy's defaults. The final matching opacity must win.
-- https://wiki.hypr.land/Configuring/Basics/Window-Rules/
o.window(".*", { opacity = "0.97 0.50" })
for percent = 20, 100, 5 do
  local alpha = string.format("%.2f", percent / 100)
  o.window({ tag = "alpha_" .. alpha }, {
    opacity = alpha .. " override " .. alpha .. " override " .. alpha .. " override",
    opaque = percent == 100,
  })
end

-- By default leave monitors.lua (and its topology) untouched. Even an explicit
-- reset uses the installed user's generic policy, not the old bundle's DP-4.
if options.force_monitors then
  hl.env("GDK_SCALE", "2")
  hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
end

-- Installer decides this from hardware detection and explicit force/skip flags.
-- No NVIDIA variables are applied to an AMD/Intel machine by this bundle.
if options.nvidia then
  hl.env("NVD_BACKEND", "direct")
  hl.env("LIBVA_DRIVER_NAME", "nvidia")
  hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
end

-- The installed legacy looknfeel/autostart files contain no active overrides.
-- Keep using normal Quattro user modules; rotation is a user systemd service.
require("hypr.hey-omarchy-bindings")

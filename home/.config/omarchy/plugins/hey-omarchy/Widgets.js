// Names and actions are the user's installed Waybar modules, not stock substitutes.
var modules = [
  { name: "tailscale", helper: "waybar-tailscale", interval: 30, left: ["waybar-tailscale-toggle"], right: ["waybar-tailscale-peers"] },
  { name: "bt-roba", helper: "waybar-bt-roba", interval: 10, left: ["waybar-bt-roba-toggle"], right: ["omarchy-shell", "shell", "toggle", "omarchy.bluetooth"], rightSystem: true },
  { name: "wwan", helper: "waybar-wwan", interval: 10, left: ["wwan-menu"] },
  { name: "ddc-brightness", helper: "waybar-ddc-brightness", interval: 3600,
    left: ["ddc-brightness", "menu", "--no-notify", "--osd"], right: ["ddc-brightness", "set", "100", "--no-notify", "--osd"],
    up: ["ddc-brightness", "up", "--no-notify", "--osd"], down: ["ddc-brightness", "down", "--no-notify", "--osd"] },
  { name: "main-monitor", helper: "waybar-main-monitor", interval: 3600, left: ["hypr-main-monitor-toggle"], right: ["hypr-monitor-position", "menu"] },
  { name: "lid", helper: "waybar-lid-suspend", interval: 3600, left: ["hypr-lid-suspend-toggle"] },
  { name: "fcitx-en", helper: "waybar-fcitx-en", interval: 3600, left: ["fcitx-en-toggle", "toggle"], middle: ["fcitx-en-toggle", "on"], right: ["fcitx-en-toggle", "off"] },
  { name: "keyboard-clean", helper: "waybar-keyboard-clean", interval: 3600, left: ["hypr-keyboard-clean-toggle", "toggle"], right: ["hypr-keyboard-clean-toggle", "off"] },
  { name: "cursor-invisible", helper: "waybar-cursor-invisible", interval: 3600, left: ["hypr-cursor-invisible-toggle", "toggle"], right: ["hypr-cursor-invisible-toggle", "off"] },
  { name: "cpu-frequency", helper: "hey-cpu-frequency", interval: 30, left: ["hey-cpu-frequency", "menu"], right: ["omarchy-launch-or-focus-tui", "btop"], rightSystem: true },
  { name: "cpu", left: ["omarchy-launch-or-focus-tui", "btop"], leftSystem: true, right: ["alacritty"], rightSystem: true }
]

function definition(name) {
  for (var i = 0; i < modules.length; i++) if (modules[i].name === name) return modules[i]
  return null
}

function hasClass(status, name) {
  var value = status ? status.class : ""
  return Array.isArray(value) ? value.indexOf(name) !== -1 : value === name
}

function opacity(name, status) {
  if (hasClass(status, "hidden")) return 0
  var dim = []
  if (name === "tailscale") dim = ["disconnected", "needs-login", "unknown"]
  else if (name === "wwan") dim = ["disconnected", "absent", "unavailable"]
  else if (name === "bt-roba") dim = ["disconnected", "unpaired", "unknown"]
  else if (name === "ddc-brightness") dim = ["unavailable"]
  else if (name === "cpu-frequency") dim = ["unknown"]
  else if (name === "fcitx-en" || name === "cursor-invisible") dim = ["unknown"]
  for (var i = 0; i < dim.length; i++) if (hasClass(status, dim[i])) return name === "tailscale" ? 0.4 : 0.55
  return 1
}

function active(name, status) {
  return ["fcitx-en", "keyboard-clean", "cursor-invisible"].indexOf(name) !== -1 && hasClass(status, "active")
}

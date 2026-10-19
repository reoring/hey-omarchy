// Names and actions are the user's installed Waybar modules, not stock substitutes.
var modules = [
  { name: "lid", helper: "waybar-lid-suspend", interval: 3600, left: ["hypr-lid-suspend-toggle"] },
  { name: "fcitx-en", helper: "waybar-fcitx-en", interval: 3600, left: ["fcitx-en-toggle", "toggle"], middle: ["fcitx-en-toggle", "on"], right: ["fcitx-en-toggle", "off"] },
  { name: "keyboard-clean", helper: "waybar-keyboard-clean", interval: 3600, left: ["hypr-keyboard-clean-toggle", "toggle"], right: ["hypr-keyboard-clean-toggle", "off"] },
  { name: "cursor-invisible", helper: "waybar-cursor-invisible", interval: 3600, left: ["hypr-cursor-invisible-toggle", "toggle"], right: ["hypr-cursor-invisible-toggle", "off"] },
  { name: "rain", helper: "hey-rain", interval: 30, left: ["hey-rain", "toggle"], right: ["hey-rain", "off"] }
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
  if (name === "fcitx-en" || name === "cursor-invisible") dim = ["unknown"]
  for (var i = 0; i < dim.length; i++) if (hasClass(status, dim[i])) return 0.55
  return 1
}

function active(name, status) {
  return ["fcitx-en", "keyboard-clean", "cursor-invisible"].indexOf(name) !== -1 && hasClass(status, "active")
}

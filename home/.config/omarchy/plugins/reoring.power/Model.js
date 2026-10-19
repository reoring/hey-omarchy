function clampIndex(index, length) {
  if (length <= 0) return 0
  return Math.max(0, Math.min(length - 1, index))
}

function selectProfileIndex(index, delta, profiles) {
  var values = Array.isArray(profiles) ? profiles : []
  if (values.length === 0) return 0
  return clampIndex(index + delta, values.length)
}

function parseKeyValue(raw) {
  var next = {}
  var lines = String(raw || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var idx = lines[i].indexOf("\t")
    if (idx <= 0) continue
    next[lines[i].substring(0, idx)] = lines[i].substring(idx + 1).trim()
  }
  return next
}

function parseProfiles(raw, previousIndex) {
  var lines = String(raw || "").split("\n")
  var list = []
  var active = ""
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim()
    if (!line) continue
    var parts = line.split("\t")
    list.push(parts[0])
    if (parts[1] === "1") active = parts[0]
  }
  return {
    profiles: list,
    activeProfile: active,
    profileIndex: clampIndex(previousIndex || 0, list.length)
  }
}

function profileIcon(name) {
  if (name === "power-saver") return "󰌪"
  if (name === "balanced") return "󰊚"
  if (name === "performance") return "󰓅"
  return "󰂄"
}

function batteryFraction(device) {
  return device && device.isPresent ? Math.max(0, Math.min(1, device.percentage)) : 0
}

function chargeThresholdActive(device, onBattery, states) {
  var d = device || {}
  var s = states || {}
  if (!(d && d.isPresent && !onBattery)) return false

  var fraction = batteryFraction(d)
  if (d.state === s.Discharging) return false
  if (d.state === s.PendingCharge) return true
  if (d.state === s.FullyCharged && fraction < 0.99) return true
  if (d.state !== s.Charging || fraction >= 0.99) return false

  return Number(d.changeRate || 0) <= 0.2 || Number(d.timeToFull || 0) >= 8 * 60 * 60
}

function batteryIcon(device, onBattery, states) {
  var d = device || {}
  if (!d.isPresent) return ""

  var chargingIcons = ["󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅"]
  var defaultIcons = ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
  var index = Math.max(0, Math.min(9, Math.floor(d.percentage * 10)))
  var threshold = chargeThresholdActive(d, onBattery, states)

  if (threshold) return defaultIcons[index]
  if (d.state === states.FullyCharged) return "󰂅"
  if (!onBattery) return chargingIcons[index]
  return defaultIcons[index]
}

function modeLabel(device, onBattery, states) {
  var d = device || {}
  if (!d.isPresent) return ""

  var percentage = d.isPresent ? d.percentage : 0
  if (chargeThresholdActive(d, onBattery, states)) return "Threshold"
  if (onBattery) return "On battery"
  if (!onBattery && percentage >= 1) return "Fully charged"
  return "Charging"
}

// One /proc/stat read. Usage is the busy share of the jiffies elapsed since
// `previous`; -1 until there are two samples to compare.
function cpuSample(raw, previous) {
  var fields = String(raw || "").split("\n")[0].trim().split(/\s+/)
  if (fields[0] !== "cpu" || fields.length < 9) return null
  var total = 0
  for (var i = 1; i <= 8; i++) total += Number(fields[i])
  var idle = Number(fields[4]) + Number(fields[5])
  var usage = -1
  if (previous && total > previous.total)
    usage = Math.max(0, Math.min(100, Math.round(100 * (1 - (idle - previous.idle) / (total - previous.total)))))
  return { total: total, idle: idle, usage: usage }
}

// The upper limits `hey-cpu-frequency menu` offers, in kHz.
var cpuCapPresets = [800000, 1000000, 1500000, 2000000, 2500000, 3000000]

// Same GHz spelling as the script ("0.8", "2.0", "4.825"), which is also
// what its `set` subcommand parses back.
function cpuGhz(khz) {
  var value = (Number(khz) / 1000000).toFixed(3).replace(/0+$/, "").replace(/\.$/, "")
  return value.indexOf(".") === -1 ? value + ".0" : value
}

// "3.3–4.8 GHz" / "0.4 GHz" -> { low, high } in kHz.
function cpuSpanKhz(text) {
  var numbers = String(text || "").match(/\d+(?:\.\d+)?/g)
  if (!numbers) return null
  var low = Math.round(parseFloat(numbers[0]) * 1000000)
  var high = numbers.length > 1 ? Math.round(parseFloat(numbers[1]) * 1000000) : low
  return { low: low, high: high }
}

// `hey-cpu-frequency status` JSON. The cap itself comes from the machine
// fields (limit_khz, uncapped); spans and the measured clock only exist as
// "Label: value" tooltip lines.
function parseCpuFrequency(raw) {
  var data
  try {
    data = JSON.parse(String(raw || "").trim())
  } catch (error) {
    return null
  }
  if (!data || typeof data.text !== "string") return null

  var info = {}
  var lines = String(data.tooltip || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var idx = lines[i].indexOf(": ")
    if (idx <= 0) continue
    info[lines[i].substring(0, idx)] = lines[i].substring(idx + 2).trim()
  }

  var limits = Array.isArray(data.limit_khz) ? data.limit_khz : []
  var uniform = limits.length > 0
  for (var j = 1; j < limits.length; j++) if (limits[j] !== limits[0]) uniform = false
  var available = data["class"] !== "unknown"

  return {
    available: available,
    text: data.text,
    error: available ? "" : String(data.tooltip || ""),
    uncapped: data.uncapped === true,
    limitKhz: uniform ? Number(limits[0]) : -1,
    limit: info["Set upper limit"] || "",
    floor: info["Set lower limit"] || "",
    clock: String(info["Measured active clock"] || "").replace(/\s*\(last sample\)$/, ""),
    driverMax: info["Driver maximum with current boost setting"] || "",
    boost: String(data.boost || "")
  }
}

// Mirrors the menu: presets inside every policy's [lower limit, driver
// maximum] window, then "max" for the uncap. Options are kHz strings.
function cpuCapOptions(freq) {
  if (!freq || !freq.available) return []
  var floor = cpuSpanKhz(freq.floor)
  var ceiling = cpuSpanKhz(freq.driverMax)
  var lower = floor ? floor.high : 0
  var upper = ceiling ? ceiling.low : Infinity
  var list = []
  for (var i = 0; i < cpuCapPresets.length; i++) {
    var value = cpuCapPresets[i]
    if (lower <= value && value <= upper) list.push(String(value))
  }
  list.push("max")
  return list
}

// The option matching the live cap, or "" for a mixed/off-preset cap.
function cpuCapCurrent(freq) {
  if (!freq || !freq.available) return ""
  if (freq.uncapped) return "max"
  return freq.limitKhz > 0 ? String(freq.limitKhz) : ""
}

function cpuCapLabel(option) {
  return option === "max" ? "Max" : cpuGhz(option)
}

function cpuCapTooltip(option) {
  return option === "max" ? "Release the upper limit (driver maximum)" : "Cap every core at " + cpuGhz(option) + " GHz"
}

// hey-cpu-frequency arguments; the script handles pkexec and verification.
function cpuCapArgs(option) {
  return option === "max" ? ["uncap"] : ["set", cpuGhz(option)]
}

if (typeof module !== "undefined") {
  module.exports = {
    clampIndex: clampIndex,
    selectProfileIndex: selectProfileIndex,
    parseKeyValue: parseKeyValue,
    parseProfiles: parseProfiles,
    profileIcon: profileIcon,
    batteryFraction: batteryFraction,
    chargeThresholdActive: chargeThresholdActive,
    batteryIcon: batteryIcon,
    modeLabel: modeLabel,
    cpuSample: cpuSample,
    cpuCapPresets: cpuCapPresets,
    cpuGhz: cpuGhz,
    cpuSpanKhz: cpuSpanKhz,
    parseCpuFrequency: parseCpuFrequency,
    cpuCapOptions: cpuCapOptions,
    cpuCapCurrent: cpuCapCurrent,
    cpuCapLabel: cpuCapLabel,
    cpuCapTooltip: cpuCapTooltip,
    cpuCapArgs: cpuCapArgs
  }
}

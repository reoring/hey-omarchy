function clampBrightness(value) {
  var n = Number(value)
  if (!isFinite(n)) return 1
  return Math.max(1, Math.min(100, Math.round(n)))
}

function normalizeScale(scale) {
  var n = parseFloat(String(scale || ""))
  if (!isFinite(n)) return ""
  return String(Math.round(n * 100) / 100)
}

function gcd(a, b) {
  while (b) {
    var remainder = a % b
    a = b
    b = remainder
  }
  return a
}

function cleanScale(scale, width, height) {
  var requested = Number(scale)
  var modeWidth = Number(width)
  var modeHeight = Number(height)
  if (!isFinite(requested) || !isFinite(modeWidth) || !isFinite(modeHeight)
      || requested <= 0 || modeWidth <= 0 || modeHeight <= 0) return ""

  var divisor = gcd(Math.round(modeWidth * 120), Math.round(modeHeight * 120))
  var scaleUnits = Math.round(requested * 120)
  if (scaleUnits > divisor) scaleUnits = divisor
  while (divisor % scaleUnits !== 0) scaleUnits++
  return normalizeScale(scaleUnits / 120)
}

function matchingScaleIndex(scales, currentScale, width, height) {
  var current = Number(currentScale)
  if (!Array.isArray(scales) || !isFinite(current)) return -1

  var bestIndex = -1
  var bestDistance = Infinity
  var normalizedCurrent = normalizeScale(current)
  for (var i = 0; i < scales.length; i++) {
    if (cleanScale(scales[i], width, height) !== normalizedCurrent) continue

    var distance = Math.abs(Number(scales[i]) - current)
    if (distance < bestDistance) {
      bestIndex = i
      bestDistance = distance
    }
  }
  return bestIndex
}

function availableScales(scales, width, height) {
  if (!Array.isArray(scales) || Number(width) <= 0 || Number(height) <= 0) return scales || []

  var byEffectiveScale = {}
  for (var i = 0; i < scales.length; i++) {
    var requested = Number(scales[i])
    var effective = Number(cleanScale(requested, width, height))

    if (!isFinite(requested) || !isFinite(effective)) continue

    var key = normalizeScale(effective)
    var existing = byEffectiveScale[key]
    if (!existing || Math.abs(requested - effective) < existing.distance) {
      byEffectiveScale[key] = {
        value: String(scales[i]),
        index: i,
        distance: Math.abs(requested - effective)
      }
    }
  }

  return Object.keys(byEffectiveScale)
    .map(function(key) { return byEffectiveScale[key] })
    .sort(function(a, b) { return a.index - b.index })
    .map(function(candidate) { return candidate.value })
}

function brightnessName(percent) {
  var p = Math.round(percent)
  if (p >= 95) return "Sun blast"
  if (p >= 80) return "Solar flare"
  if (p >= 65) return "Golden hour"
  if (p >= 45) return "Even day"
  if (p >= 30) return "Soft glow"
  if (p >= 20) return "Lamp light"
  if (p >= 10) return "Candlelit"
  return "Night owl"
}

function parseDisplays(raw) {
  var displays = []
  try {
    displays = raw ? JSON.parse(String(raw)) : []
  } catch (e) {
    displays = []
  }
  if (!Array.isArray(displays)) displays = []

  var count = 0
  for (var i = 0; i < displays.length; i++) {
    if (displays[i] && displays[i].enabled) count++
  }

  return {
    displays: displays,
    enabledDisplayCount: count
  }
}

// External monitors take the full 0-100 DDC/CI range; `ddc-brightness set`
// accepts 0 (unlike the backlight, where 0 would black out the panel).
function clampDdcBrightness(value) {
  var n = Number(value)
  if (!isFinite(n)) return 0
  return Math.max(0, Math.min(100, Math.round(n)))
}

// `ddc-brightness get` prints the bare percent on success and nothing on
// stdout when no DDC/CI display answers. -1 = unavailable.
function parseDdcBrightness(raw) {
  var text = String(raw || "").trim()
  if (!/^[0-9]+$/.test(text)) return -1
  return clampDdcBrightness(parseInt(text, 10))
}

// Order of the external-position pills; values are hypr-monitor-position's
// subcommands (where the external sits relative to the laptop panel).
var externalPositions = ["left", "right", "up", "down"]

function positionLabel(position) {
  if (position === "left") return "Left"
  if (position === "right") return "Right"
  if (position === "up") return "Up"
  if (position === "down") return "Down"
  return position
}

// waybar-main-monitor prints Waybar JSON: class is the resolved main role
// ("internal" | "external", already normalized to whichever display exists),
// and the tooltip carries "Main monitor: NAME (role)" plus "External
// position: DIR" (DIR is "auto" until hypr-monitor-position has run).
function parseMainMonitor(raw) {
  var parsed = {}
  try {
    parsed = JSON.parse(String(raw || "").trim() || "{}")
  } catch (e) {
    parsed = {}
  }
  var tooltip = String(parsed.tooltip || "")
  var name = /Main monitor:\s*(\S+)/.exec(tooltip)
  var position = /External position:\s*(\S+)/.exec(tooltip)
  var pos = position ? position[1] : ""
  return {
    role: parsed["class"] === "external" ? "external" : "internal",
    monitor: name && name[1] !== "unknown" ? name[1] : "",
    position: externalPositions.indexOf(pos) >= 0 ? pos : ""
  }
}

function displayEnabled(displays, name) {
  if (!name || !Array.isArray(displays)) return false
  for (var i = 0; i < displays.length; i++) {
    if (displays[i] && displays[i].name === name) return !!displays[i].enabled
  }
  return false
}

if (typeof module !== "undefined") {
  module.exports = {
    clampBrightness: clampBrightness,
    normalizeScale: normalizeScale,
    cleanScale: cleanScale,
    matchingScaleIndex: matchingScaleIndex,
    availableScales: availableScales,
    brightnessName: brightnessName,
    parseDisplays: parseDisplays,
    clampDdcBrightness: clampDdcBrightness,
    parseDdcBrightness: parseDdcBrightness,
    externalPositions: externalPositions,
    positionLabel: positionLabel,
    parseMainMonitor: parseMainMonitor,
    displayEnabled: displayEnabled
  }
}

function deviceLabel(device) {
  if (!device) return ""
  return String(device.deviceName || device.name || "").trim()
}

function toArray(values) {
  if (!values) return []
  if (Array.isArray(values)) return values.slice()

  var length = Number(values.length || 0)
  if (!isFinite(length) || length <= 0) return []

  var list = []
  for (var i = 0; i < length; i++) list.push(values[i])
  return list
}

function isUuidLike(value) {
  var text = String(value || "").trim()
  if (text === "") return false
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(text)
    || /^[0-9a-f]{32}$/i.test(text)
    || /^0x[0-9a-f]{4,32}$/i.test(text)
    || /^0000[0-9a-f]{4}-0000-1000-8000-00805f9b34fb$/i.test(text)
}

function isAddressLike(value) {
  var text = String(value || "").trim()
  return /^([0-9a-f]{2}[:-]){5}[0-9a-f]{2}$/i.test(text)
}

function normalizedAddress(value) {
  return String(value || "").trim().toLowerCase().replace(/[^0-9a-f]/g, "")
}

function hasHumanName(device) {
  var label = deviceLabel(device)
  return label !== "" && !isUuidLike(label) && !isAddressLike(label)
}

function nodeProps(node) {
  return node && node.ready && node.properties ? node.properties : {}
}

function nodeText(node) {
  var props = nodeProps(node)
  return [
    node ? node.name : "",
    node ? node.description : "",
    node ? node.nickname : "",
    node ? node.nick : "",
    props["node.name"],
    props["node.description"],
    props["node.nick"],
    props["device.name"],
    props["device.description"],
    props["device.product.name"],
    props["device.alias"],
    props["device.string"],
    props["api.bluez5.address"],
    props["bluez5.address"],
    props["media.name"]
  ].join(" ").toLowerCase()
}

function bluetoothSinkMatchesDevice(node, device) {
  if (!node || !node.isSink || node.isStream || !device) return false

  var address = normalizedAddress(device.address)
  var text = nodeText(node)
  if (address !== "" && normalizedAddress(text).indexOf(address) !== -1) return true

  var label = deviceLabel(device).toLowerCase()
  return label !== "" && text.indexOf(label) !== -1
}

function sortedByLabel(devices) {
  var list = toArray(devices)
  list.sort(function(a, b) { return deviceLabel(a).localeCompare(deviceLabel(b)) })
  return list
}

// Primitives-only projection of a BlueZ device for list-model rows. Holding
// the Device QObject in model data puts a live wrapper into every delegate's
// var property, and BlueZ churn (discovery timeouts, unpair) can destroy the
// object while a delegate is still incubating, which segfaults quickshell.
// Actions resolve the backend object via Panel.deviceFor().
function deviceRow(d) {
  if (!d) return null
  return {
    address: d.address || "",
    name: d.name || "",
    deviceName: d.deviceName || "",
    connected: !!d.connected,
    state: d.state !== undefined ? d.state : -1,
    batteryAvailable: !!d.batteryAvailable,
    battery: d.battery !== undefined ? d.battery : 0,
    pairing: !!d.pairing
  }
}

// The roBa split keyboard is pinned above the device lists. It is matched the
// way ~/.local/bin/bt-roba matches it — "roba" anywhere in the Alias or Name,
// case-insensitively — so the panel and the helper it runs always agree on
// which BlueZ entries are the keyboard.
var FAVORITE_MATCH = "roba"

function isFavorite(device) {
  if (!device) return false
  var text = (String(device.name || "") + "\n" + String(device.deviceName || "")).toLowerCase()
  return text.indexOf(FAVORITE_MATCH) !== -1
}

function isPaired(device) {
  return !!(device && (device.paired || device.bonded))
}

// ZMK boards can leave more than one BlueZ entry behind (a stale bond next to
// a fresh random address). Show the one that matters most: connected, then
// paired, then whatever the scan turned up.
function favoriteDevice(devices) {
  var values = toArray(devices)
  var best = null
  var bestRank = -1
  for (var i = 0; i < values.length; i++) {
    var d = values[i]
    if (!isFavorite(d)) continue
    var rank = d.connected ? 2 : (isPaired(d) ? 1 : 0)
    if (rank > bestRank) { best = d; bestRank = rank }
  }
  return best
}

// Same classes waybar-bt-roba reports, plus "off" for a powered-down adapter,
// which the helper cannot get past anyway.
function favoriteState(device, adapterEnabled) {
  if (!adapterEnabled) return "off"
  if (!device) return "missing"
  if (device.connected) return "connected"
  if (isPaired(device)) return "disconnected"
  return "unpaired"
}

// Nearby BLE beacons that flood scan results. Only unpaired ("discovered")
// entries are hidden, so a deliberately paired match still shows up.
var HIDDEN_DISCOVERED_PREFIXES = ["endo_"]

function isHiddenDiscovered(device) {
  var label = deviceLabel(device).toLowerCase()
  for (var i = 0; i < HIDDEN_DISCOVERED_PREFIXES.length; i++) {
    if (label.indexOf(HIDDEN_DISCOVERED_PREFIXES[i]) === 0) return true
  }
  return false
}


// The favorite is left out of the generic sections: it already has its pinned
// row with the same disconnect/forget actions, and listing it twice would put
// two cursor stops — one connecting via the helper, one not — on one board.
function deviceLists(devices) {
  var values = toArray(devices)
  var connected = []
  var known = []
  var discovered = []

  for (var i = 0; i < values.length; i++) {
    var d = values[i]
    if (!d || !hasHumanName(d) || isFavorite(d)) continue
    if (d.connected) connected.push(d)
    else if (d.paired || d.bonded || d.trusted) known.push(d)
    else if (!isHiddenDiscovered(d)) discovered.push(d)
  }

  return {
    connected: sortedByLabel(connected),
    known: sortedByLabel(known),
    discovered: sortedByLabel(discovered)
  }
}

function cloneMap(map) {
  var next = ({})
  for (var key in map || {}) next[key] = map[key]
  return next
}

function pendingAction(actions, address) {
  return address && actions && actions[address] ? actions[address] : ""
}

function withPendingAction(actions, address, action) {
  var next = cloneMap(actions)
  if (!address) return next
  if (action) next[address] = action
  else delete next[address]
  return next
}

function visibleSections(lists, discovering, favorite) {
  var sections = []
  if (favorite) sections.push("favorite")
  if (lists && lists.connected && lists.connected.length > 0) sections.push("connected")
  if (lists && lists.known && lists.known.length > 0) sections.push("known")
  if (discovering && lists && lists.discovered && lists.discovered.length > 0) sections.push("discovered")
  return sections
}

function sectionDevices(lists, section) {
  if (!lists) return []
  if (section === "connected") return lists.connected || []
  if (section === "known") return lists.known || []
  if (section === "discovered") return lists.discovered || []
  return []
}

if (typeof module !== "undefined") {
  module.exports = {
    deviceLabel: deviceLabel,
    toArray: toArray,
    isUuidLike: isUuidLike,
    isAddressLike: isAddressLike,
    normalizedAddress: normalizedAddress,
    hasHumanName: hasHumanName,
    nodeProps: nodeProps,
    nodeText: nodeText,
    bluetoothSinkMatchesDevice: bluetoothSinkMatchesDevice,
    sortedByLabel: sortedByLabel,
    deviceRow: deviceRow,
    deviceLists: deviceLists,
    isFavorite: isFavorite,
    isPaired: isPaired,
    favoriteDevice: favoriteDevice,
    favoriteState: favoriteState,
    cloneMap: cloneMap,
    pendingAction: pendingAction,
    withPendingAction: withPendingAction,
    visibleSections: visibleSections,
    sectionDevices: sectionDevices
  }
}

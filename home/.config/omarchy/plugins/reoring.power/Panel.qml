import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "omarchy.power"
  ipcTarget: "omarchy.power"
  // manageIpc: false so this panel can own the single IpcHandler the target
  // permits — needed for the togglePercentage method below.
  manageIpc: false
  property var batteryInfo: ({})
  property var systemInfo: ({})
  property var profiles: []
  property string activeProfile: ""
  property int profileIndex: 0
  property bool cursorActive: false
  // Which cursor row owns the keyboard: the profile pills, the btop button on
  // the CPU header line, or the CPU cap pills.
  property string focusSection: "profile"  // "profile" | "btop" | "cpu"

  // CPU section, folded in from the hey-omarchy cpu / cpu-frequency bar
  // modules. Usage is a /proc/stat delta like that module's; the cap and the
  // measured clock come from `hey-cpu-frequency status`. Sampled only while
  // the panel is open.
  readonly property string cpuFrequencyCommand: Quickshell.env("HOME") + "/.local/bin/hey-cpu-frequency"
  property var cpuPrevious: null
  property int cpuUsage: -1
  property var cpuFreq: null
  readonly property var cpuCapOptions: Model.cpuCapOptions(cpuFreq)
  readonly property string cpuCapCurrent: Model.cpuCapCurrent(cpuFreq)
  // In-flight cap answers the click immediately -- pkexec can sit on the
  // password prompt for a while -- and holds until a fresh status lands.
  property string pendingCap: ""
  readonly property string cpuCapEffective: pendingCap !== "" ? pendingCap : cpuCapCurrent
  property string cpuCapError: ""
  property bool cpuFreqRefreshPending: false
  property int cpuCapIndex: 0
  readonly property bool showPercentage: setting("showPercentage", false) === true
  // With the percentage shown the button paints a text block wider than an
  // icon, so the open-panel mark takes the painted width instead of the
  // icon-sized fraction of the slot the fallback assumes.
  readonly property real openPanelIndicatorWidth: showPercentage && !button.vertical ? button.glyphPaintedWidth : 0
  readonly property bool batteryPresent: {
    var device = UPower.displayDevice
    return !!(device && device.isPresent)
  }

  function upowerStates() {
    return {
      Charging: UPowerDeviceState.Charging,
      Discharging: UPowerDeviceState.Discharging,
      FullyCharged: UPowerDeviceState.FullyCharged,
      PendingCharge: UPowerDeviceState.PendingCharge
    }
  }

  function selectProfileByDelta(delta) {
    profileIndex = Model.selectProfileIndex(profileIndex, delta, profiles)
  }

  function activateSelectedProfile() {
    if (profileIndex < 0 || profileIndex >= profiles.length) return
    setProfile(profiles[profileIndex])
  }

  function batteryIcon() {
    var device = UPower.displayDevice
    return Model.batteryIcon(device, root.discharging, upowerStates())
  }

  function modeLabel() {
    var device = UPower.displayDevice
    return Model.modeLabel(device, root.discharging, upowerStates())
  }

  function profileIcon(name) {
    return Model.profileIcon(name)
  }

  readonly property bool fullyCharged: {
    var device = UPower.displayDevice
    return device && device.isPresent && device.state === UPowerDeviceState.FullyCharged && !root.chargeThresholdActive
  }
  readonly property bool discharging: {
    var device = UPower.displayDevice
    return !!(device && device.isPresent && UPower.onBattery)
  }
  readonly property bool chargeThresholdActive: {
    var device = UPower.displayDevice
    return Model.chargeThresholdActive(device, root.discharging, upowerStates())
  }
  readonly property bool batteryFull: fullyCharged || (!root.discharging && batteryFraction >= 1)
  readonly property bool batteryFlowIdle: batteryFull || chargeThresholdActive

  // 0..1 charge level, used by the visual progress bar.
  readonly property real batteryFraction: {
    var d = UPower.displayDevice
    return Model.batteryFraction(d)
  }

  readonly property bool charging: {
    var d = UPower.displayDevice
    return d && d.isPresent && !UPower.onBattery && !root.batteryFlowIdle
  }

  readonly property color batteryFillColor: {
    return root.bar ? root.bar.foreground : Color.foreground
  }

  // Cute agent-flavored phrases shown in the hero status line, rotated on a
  // timer so the panel feels alive when current is flowing (either direction).
  readonly property var chargingPhrases: [
    "Pumping power",
    "Injecting electrons",
    "Pouring juice",
    "Amassing watts",
    "Hoarding joules",
    "Sucking volts",
    "Topping reserves",
    "Soaking amps",
    "Inhaling kilowatts"
  ]
  readonly property var onBatteryPhrases: [
    "Slurping power",
    "Spending joules",
    "Draining watts",
    "Burning electrons",
    "Sipping juice",
    "Spending coulombs",
    "Bleeding amps",
    "Guzzling volts",
    "Munching reserves"
  ]
  property int phraseIndex: 0

  // Whichever list is "active" given the current power state.
  readonly property var activePhrases: {
    if (fullyCharged) return []
    if (charging) return chargingPhrases
    if (discharging) return onBatteryPhrases
    return []
  }
  readonly property bool rotatingPhrases: activePhrases.length > 0

  readonly property string heroStatusText: {
    if (fullyCharged) return "Fully charged"
    if (rotatingPhrases) return activePhrases[phraseIndex % activePhrases.length]
    return modeLabel()
  }

  function refresh() {
    if (!batteryPresent) return

    if (!batteryProc.running) batteryProc.running = true
    if (!profilesProc.running) profilesProc.running = true
    if (!systemProc.running) systemProc.running = true
  }

  function updateKeyValue(raw, targetName) {
    var next = Model.parseKeyValue(raw)
    // Keep last known good data if a refresh briefly returns nothing — happens
    // around AC plug/unplug events. Avoids the section collapsing mid-transition.
    if (Object.keys(next).length === 0) return
    if (targetName === "battery") batteryInfo = next
    else systemInfo = next
  }

  function updateProfiles(raw) {
    var parsed = Model.parseProfiles(raw, profileIndex)
    // Same guard as battery: preserve the last known profile list across
    // transient empty payloads so the buttons don't blink out.
    if (parsed.profiles.length === 0) return
    profiles = parsed.profiles
    activeProfile = parsed.activeProfile
    profileIndex = parsed.profileIndex
    if (opened && !cursorActive) {
      var idx = profiles.indexOf(activeProfile)
      if (idx >= 0) profileIndex = idx
    }
  }

  function setProfile(profile) {
    if (!profile || actionProc.running) return
    actionProc.command = ["omarchy-powerprofiles-set", root.discharging ? "battery" : "ac", profile]
    actionProc.running = true
  }

  function sampleCpu() {
    cpuStat.reload()
    refreshCpuFrequency()
  }

  function refreshCpuFrequency() {
    if (cpuFreqProc.running) cpuFreqRefreshPending = true
    else cpuFreqProc.running = true
  }

  function updateCpuUsage(raw) {
    // FileView also loads once at startup; a baseline taken then would turn
    // the first open's reading into an average since boot.
    if (!opened) return
    var sample = Model.cpuSample(raw, cpuPrevious)
    if (!sample) return
    cpuPrevious = sample
    if (sample.usage >= 0) cpuUsage = sample.usage
  }

  function updateCpuFrequency(raw) {
    var parsed = Model.parseCpuFrequency(raw)
    if (!parsed) return
    cpuFreq = parsed
    // A sample that started before the cap write finished is already stale.
    if (!capProc.running && !cpuFreqRefreshPending) pendingCap = ""
  }

  // The script does its own pkexec, verification and rollback; the panel
  // only reports what it says on failure.
  function setCpuCap(option) {
    if (!option || capProc.running || option === cpuCapCurrent) return
    pendingCap = option
    cpuCapError = ""
    capProc.command = [cpuFrequencyCommand].concat(Model.cpuCapArgs(option))
    capProc.running = true
  }

  function openBtop() {
    Quickshell.execDetached(["omarchy-launch-or-focus-tui", "btop"])
    close()
  }

  function selectCpuCapByDelta(delta) {
    cpuCapIndex = Model.clampIndex(cpuCapIndex + delta, cpuCapOptions.length)
  }

  function syncCpuCapIndex() {
    var idx = cpuCapOptions.indexOf(cpuCapCurrent)
    cpuCapIndex = idx >= 0 ? idx : 0
  }

  // Vertical order follows the layout: profiles, the btop button on the CPU
  // header line, then the cap pills (absent when the script reports nothing).
  function moveFocusSection(dy) {
    var order = cpuCapOptions.length > 0 ? ["profile", "btop", "cpu"] : ["profile", "btop"]
    var idx = order.indexOf(focusSection)
    focusSection = order[Model.clampIndex((idx >= 0 ? idx : 0) + dy, order.length)]
    if (focusSection === "cpu") selectCpuCapByDelta(0)
  }

  function activateFocused() {
    if (focusSection === "btop") openBtop()
    else if (focusSection === "cpu") setCpuCap(cpuCapOptions[cpuCapIndex])
    else activateSelectedProfile()
  }

  function togglePercentage() {
    root.settings = Object.assign({}, root.settings, { showPercentage: !root.showPercentage })
    if (root.bar && root.bar.shell) root.bar.shell.updateEntryInline(root.moduleName, root.settings)
  }

  IpcHandler {
    target: "omarchy.power"

    function open() { root.open() }
    function close() { root.close() }
    function show() { root.open() }
    function hide() { root.close() }
    function toggle() { root.toggle() }
    function togglePercentage() { root.togglePercentage() }
  }

  onOpenedChanged: {
    if (opened) {
      if (!batteryPresent) {
        close()
        return
      }

      refresh()
      var idx = profiles.indexOf(activeProfile)
      profileIndex = idx >= 0 ? idx : 0
      syncCpuCapIndex()
      focusSection = "profile"
      cursorActive = false
    } else {
      // Next open measures usage from its own baseline.
      cpuPrevious = null
      cpuUsage = -1
    }
  }

  onBatteryPresentChanged: if (!batteryPresent) close()

  visible: batteryPresent
  implicitWidth: batteryPresent ? button.implicitWidth : 0
  implicitHeight: batteryPresent ? button.implicitHeight : 0

  Process {
    id: batteryProc
    command: ["omarchy-battery-status", "--shell"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.updateKeyValue(text, "battery") }
  }

  Process {
    id: profilesProc
    command: ["omarchy-powerprofiles-list", "--active-state"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.updateProfiles(text) }
  }

  Process {
    id: systemProc
    command: ["omarchy-system-stats"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.updateKeyValue(text, "system") }
  }

  Process {
    id: actionProc
    onExited: root.refresh()
  }

  Timer { interval: 5000; running: root.opened; repeat: true; onTriggered: root.refresh() }

  FileView {
    id: cpuStat
    path: "/proc/stat"
    printErrors: false
    onLoaded: root.updateCpuUsage(text())
  }

  Process {
    id: cpuFreqProc
    command: [root.cpuFrequencyCommand, "status"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.updateCpuFrequency(text) }
    onExited: {
      if (root.cpuFreqRefreshPending) {
        root.cpuFreqRefreshPending = false
        Qt.callLater(root.refreshCpuFrequency)
      }
    }
  }

  Process {
    id: capProc
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (text.trim() !== "") root.cpuCapError = text.trim()
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        if (root.cpuCapError === "") root.cpuCapError = "hey-cpu-frequency exited with status " + exitCode
        root.pendingCap = ""
      }
      root.refreshCpuFrequency()
    }
  }

  // Usage needs two samples, so the first number lands one tick after open.
  Timer { interval: 2000; running: root.opened; repeat: true; triggeredOnStart: true; onTriggered: root.sampleCpu() }

  // Rotate the status phrase while the panel is open and we're in a
  // rotating state (charging or on battery). The text swap is wrapped in a
  // fade so the changeover reads as one organism rather than a hard cut.
  Timer {
    id: phraseTimer
    interval: 2800
    running: root.opened && root.rotatingPhrases
    repeat: true
    triggeredOnStart: false
    onTriggered: phraseSwap.restart()
  }

  SequentialAnimation {
    id: phraseSwap
    PropertyAnimation {
      target: heroStatus; property: "opacity"
      to: 0.0; duration: 180; easing.type: Easing.OutQuad
    }
    ScriptAction {
      script: {
        var n = root.activePhrases.length
        if (n > 0) root.phraseIndex = (root.phraseIndex + 1) % n
      }
    }
    PropertyAnimation {
      target: heroStatus; property: "opacity"
      to: 1.0; duration: 260; easing.type: Easing.InQuad
    }
  }

  // If we leave a rotating state mid-swap, halt the animation and snap back
  // to full opacity so "FULLY CHARGED" is legible immediately rather than
  // appearing dimmed.
  Connections {
    target: root
    function onRotatingPhrasesChanged() {
      if (!root.rotatingPhrases) {
        phraseSwap.stop()
        heroStatus.opacity = 1.0
      }
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.showPercentage && !vertical
      ? Math.round(root.batteryFraction * 100) + "% " + root.batteryIcon()
      : root.batteryIcon()
    slotSize: Style.bar.iconSlot * (root.showPercentage && !vertical ? 2 : 1)
    tooltipText: ""
    onPressed: function(b) {
      if (!root.batteryPresent) return
      if (b === Qt.RightButton) root.togglePercentage()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened && root.batteryPresent
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        if (dy !== 0) root.moveFocusSection(dy)
        else if (root.focusSection === "profile") root.selectProfileByDelta(dx)
        else if (root.focusSection === "cpu") root.selectCpuCapByDelta(dx)
      }
      onActivateRequested: if (root.cursorActive) root.activateFocused()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        // ---------- Hero: battery icon · title/status · percentage ----------
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, heroPercent.implicitHeight)

          Text {
            id: heroIcon
            textFormat: Text.PlainText
            text: root.batteryIcon()
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.display
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            Behavior on color { ColorAnimation { duration: 200 } }
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: heroPercent.left
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: "Battery"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              id: heroStatus
              textFormat: Text.PlainText
              text: root.heroStatusText.toUpperCase()
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              elide: Text.ElideRight
              width: parent.width
            }
          }

          Text {
            id: heroPercent
            textFormat: Text.PlainText
            text: root.batteryInfo.percentage || "—"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.displayLarge
            font.bold: true
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            Behavior on color { ColorAnimation { duration: 200 } }
          }
        }

        // ---------- Battery progress bar ----------
        Item {
          width: parent.width
          implicitHeight: Style.space(8)

          Rectangle {
            id: barTrack
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.12)
          }

          Rectangle {
            id: barFill
            anchors.left: barTrack.left
            anchors.verticalCenter: barTrack.verticalCenter
            height: barTrack.height
            radius: barTrack.radius
            color: root.batteryFillColor
            width: Math.max(barTrack.height, barTrack.width * root.batteryFraction)

            Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 220 } }

            // Subtle pulse while charging — visible signal that energy is flowing in.
            SequentialAnimation on opacity {
              running: root.charging && !root.fullyCharged && root.opened
              loops: Animation.Infinite
              alwaysRunToEnd: true
              NumberAnimation { from: 1.0; to: 0.55; duration: 950; easing.type: Easing.InOutSine }
              NumberAnimation { from: 0.55; to: 1.0; duration: 950; easing.type: Easing.InOutSine }
            }
          }
        }

        // ---------- Stats ----------
        // Visibility is intentionally only gated by "we've ever loaded data" so
        // the section never collapses mid-transition. fullyCharged is *not* part
        // of the condition: UPower briefly reports FullyCharged on plug-in when
        // the battery sits above the charge-control start threshold, and we
        // refuse to flicker the whole panel for that ~1s window.
        Row {
          visible: root.batteryInfo.percentage !== undefined
          width: parent.width
          spacing: Style.space(20)

          Column {
            width: (parent.width - parent.spacing) / 2
            spacing: Style.spacing.labelGap
            InfoPair { label: "Battery size"; value: root.batteryInfo.size || "" }
            InfoPair { label: "Charge cycles"; value: root.batteryInfo.cycles || "—" }
          }

          Column {
            width: (parent.width - parent.spacing) / 2
            spacing: Style.spacing.labelGap
            InfoPair {
              label: root.chargeThresholdActive ? "Charge limit" : (root.discharging ? "Time left" : "Time to full")
              value: root.chargeThresholdActive ? (root.batteryInfo.threshold || "-") : (root.batteryFlowIdle ? "-" : (root.batteryInfo.time || "—"))
            }
            InfoPair {
              label: root.chargeThresholdActive ? "Battery state" : (root.discharging ? "Discharging" : "Charging")
              value: root.chargeThresholdActive ? "Holding" : (root.batteryFull ? "-" : (root.batteryInfo.rate || ""))
            }
          }
        }

        // ---------- Power profile picker ----------
        PanelSeparator {
          foreground: root.bar.foreground
        }

        Column {
          width: parent.width
          spacing: Style.space(10)

          PanelSectionHeader {
            text: "POWER PROFILE"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
          }

          Row {
            id: profileRow
            width: parent.width
            spacing: Style.space(6)

            readonly property real cellWidth: root.profiles.length > 0
              ? (width - spacing * (root.profiles.length - 1)) / root.profiles.length
              : 0

            Repeater {
              model: root.profiles
              Button {
                required property var modelData
                required property int index
                width: profileRow.cellWidth
                iconText: root.profileIcon(String(modelData))
                iconSize: Style.font.title
                text: String(modelData).charAt(0).toUpperCase() + String(modelData).slice(1)
                fontSize: Style.font.bodySmall
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                horizontalPadding: Style.spacing.controlPaddingX
                verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
                bordered: true
                active: root.activeProfile === modelData
                hasCursor: root.cursorActive && root.focusSection === "profile" && root.profileIndex === index
                onClicked: root.setProfile(modelData)
                onHovered: function(h) {
                  if (h) {
                    root.cursorActive = true
                    root.focusSection = "profile"
                    root.profileIndex = index
                  }
                }
              }
            }
          }
        }

        // ---------- CPU: usage, clock, upper frequency limit ----------
        PanelSeparator {
          foreground: root.bar.foreground
        }

        Column {
          width: parent.width
          spacing: Style.space(10)

          // btop rides on the header line, the same way the network panel
          // puts a section's switch beside its title.
          Item {
            width: parent.width
            implicitHeight: Math.max(cpuHeader.implicitHeight, btopButton.implicitHeight)

            PanelSectionHeader {
              id: cpuHeader
              text: "CPU"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Button {
              id: btopButton
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: "btop"
              tooltipText: "Open btop"
              fontSize: Style.font.caption
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              horizontalPadding: Style.spacing.controlPaddingX
              verticalPadding: Style.space(2)
              bordered: true
              hasCursor: root.cursorActive && root.focusSection === "btop"
              onClicked: root.openBtop()
              onHovered: function(h) {
                if (h) {
                  root.cursorActive = true
                  root.focusSection = "btop"
                }
              }
            }
          }

          Row {
            width: parent.width
            spacing: Style.space(20)

            Column {
              width: (parent.width - parent.spacing) / 2
              spacing: Style.spacing.labelGap
              InfoPair { label: "Usage"; value: root.cpuUsage >= 0 ? root.cpuUsage + "%" : "—" }
              InfoPair { label: "Clock"; value: root.cpuFreq && root.cpuFreq.clock ? root.cpuFreq.clock : "—" }
            }

            Column {
              width: (parent.width - parent.spacing) / 2
              spacing: Style.spacing.labelGap
              InfoPair {
                label: "Upper limit"
                value: !root.cpuFreq || !root.cpuFreq.available ? "—" : (root.cpuFreq.uncapped ? "Released" : (root.cpuFreq.limit || "—"))
              }
              InfoPair { label: "Driver max"; value: root.cpuFreq && root.cpuFreq.driverMax ? root.cpuFreq.driverMax : "—" }
            }
          }

          // Upper-limit presets in GHz, same set as `hey-cpu-frequency menu`.
          Row {
            id: cpuCapRow
            visible: root.cpuCapOptions.length > 0
            width: parent.width
            spacing: Style.space(6)

            readonly property int count: Math.max(1, root.cpuCapOptions.length)
            readonly property real cellWidth: (width - spacing * (count - 1)) / count

            Repeater {
              model: root.cpuCapOptions
              Button {
                required property var modelData
                required property int index
                width: cpuCapRow.cellWidth
                text: Model.cpuCapLabel(modelData)
                tooltipText: Model.cpuCapTooltip(modelData)
                fontSize: Style.font.bodySmall
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                horizontalPadding: Style.space(2)
                verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
                bordered: true
                active: root.cpuCapEffective === modelData
                hasCursor: root.cursorActive && root.focusSection === "cpu" && root.cpuCapIndex === index
                onClicked: root.setCpuCap(modelData)
                onHovered: function(h) {
                  if (h) {
                    root.cursorActive = true
                    root.focusSection = "cpu"
                    root.cpuCapIndex = index
                  }
                }
              }
            }
          }

          // pkexec prompt in flight, or what the script said when it refused.
          Text {
            readonly property string message: {
              if (capProc.running) return "Waiting for authorization…"
              if (root.cpuCapError) return root.cpuCapError
              if (root.cpuFreq && !root.cpuFreq.available) return root.cpuFreq.error
              return ""
            }
            visible: message !== ""
            width: parent.width
            textFormat: Text.PlainText
            text: message
            wrapMode: Text.Wrap
            color: root.bar.foreground
            opacity: 0.6
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }

  component InfoPair: Row {
    property string label: ""
    property string value: ""

    width: parent.width
    spacing: Style.space(8)

    InfoLabel { text: label }
    Item { width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth - parent.spacing * 2); height: 1 }
    InfoValue { text: value }
  }

  component InfoLabel: Text {
    textFormat: Text.PlainText
    color: root.bar.foreground
    opacity: 0.6
    font.family: root.bar.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  component InfoValue: Text {
    textFormat: Text.PlainText
    color: root.bar.foreground
    font.family: root.bar.fontFamily
    font.pixelSize: Style.font.bodySmall
  }
}

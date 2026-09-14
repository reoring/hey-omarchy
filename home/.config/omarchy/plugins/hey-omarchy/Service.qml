import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "Widgets.js" as Widgets

Item {
  id: root
  property var shell: null
  readonly property string bin: Quickshell.env("HOME") + "/.local/bin/"
  property var statuses: ({})
  property var cpuPrevious: null
  property bool controlsExpanded: false

  function publish(name, status) {
    var next = Object.assign({}, statuses)
    next[name] = status
    statuses = next
  }

  function refresh(name) {
    if (name === "all" || name === "cpu") cpuStats.reload()
    for (var i = 0; i < sources.count; i++) {
      var source = sources.objectAt(i)
      if (source && (name === "all" || source.definition.name === name)) source.refresh()
    }
  }

  function runAction(name, action) {
    var definition = Widgets.definition(name)
    var command = definition ? definition[action] : null
    if (!command || command.length === 0) return
    var argv = command.slice()
    if (!definition[action + "System"]) argv[0] = bin + argv[0]
    Quickshell.execDetached(argv)
    // State-changing helpers publish an IPC refresh after committing their state.
  }

  Instantiator {
    id: sources
    model: Widgets.modules.filter(function(entry) { return !!entry.helper })
    delegate: Item {
      id: source
      required property var modelData
      readonly property var definition: modelData
      property bool refreshPending: false

      function refresh() {
        if (probe.running) refreshPending = true
        else {
          probe.running = true
        }
      }

      Process {
        id: probe
        command: [root.bin + source.definition.helper]
        stdout: StdioCollector {
          waitForEnd: true
          onStreamFinished: {
            try {
              var data = JSON.parse(text.trim())
              if (!data || typeof data !== "object" || typeof data.text !== "string") throw new Error("expected status JSON with text")
              root.publish(source.definition.name, data)
            } catch (error) {
              root.publish(source.definition.name, { text: "?", tooltip: source.definition.name + ": invalid status output\n" + error, class: "unknown" })
            }
          }
        }
        onExited: function(exitCode) {
          if (exitCode !== 0) root.publish(source.definition.name, { text: "?", tooltip: source.definition.helper + " exited with status " + exitCode, class: "unknown" })
          if (source.refreshPending) {
            source.refreshPending = false
            Qt.callLater(source.refresh)
          }
        }
      }

      Timer {
        interval: source.definition.interval * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: source.refresh()
      }
    }
  }

  // /proc/stat supplies the old CPU percentage without launching a command.
  FileView {
    id: cpuStats
    path: "/proc/stat"
    printErrors: false
    onLoaded: {
      var fields = text().split("\n")[0].trim().split(/\s+/)
      if (fields[0] !== "cpu" || fields.length < 9) return
      var total = 0
      for (var i = 1; i <= 8; i++) total += Number(fields[i])
      var idle = Number(fields[4]) + Number(fields[5])
      var previous = root.cpuPrevious
      root.cpuPrevious = { total: total, idle: idle }
      if (previous && total > previous.total) {
        var usage = Math.round(100 * (1 - (idle - previous.idle) / (total - previous.total)))
        root.publish("cpu", { text: "󰍛", tooltip: "CPU usage: " + usage + "%", class: "" })
      } else {
        root.publish("cpu", { text: "󰍛", tooltip: "CPU usage: measuring", class: "" })
      }
    }
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: cpuStats.reload()
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (["monitoradded", "monitoraddedv2", "monitorremoved"].indexOf(String(event.name)) !== -1) {
        root.refresh("main-monitor")
        root.refresh("ddc-brightness")
      }
    }
  }

  IpcHandler {
    target: "hey-omarchy"
    function refresh(name: string): void { root.refresh(name) }
    function status(): string { return JSON.stringify(root.statuses) }
  }
}

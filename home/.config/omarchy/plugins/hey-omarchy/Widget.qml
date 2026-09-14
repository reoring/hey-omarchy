import QtQuick
import qs.Ui
import "Widgets.js" as Widgets

BarWidget {
  id: root
  moduleName: "hey-omarchy"
  readonly property var service: bar?.shell?.serviceFor(moduleName) ?? null

  visible: true
  implicitWidth: controls.implicitWidth
  implicitHeight: controls.implicitHeight

  Grid {
    id: controls
    anchors.centerIn: parent
    spacing: 0
    columns: root.vertical ? 1 : Widgets.modules.length + 1

    Repeater {
      model: root.service && root.service.controlsExpanded ? Widgets.modules : []

      delegate: WidgetButton {
        id: controlButton
        required property var modelData
        readonly property var status: root.service ? root.service.statuses[modelData.name] || ({}) : ({})
        property real scrollAccumulator: 0

        bar: root.bar
        visible: hasVisualContent && !Widgets.hasClass(status, "hidden")
        text: status.text === undefined ? "" : String(status.text)
        tooltipText: String(status.tooltip || "")
        horizontalMargin: modelData.name === "ddc-brightness" ? 11.5 : 7.5
        fontSize: 12
        activeColor: "#a55555"
        active: Widgets.active(modelData.name, status)
        opacity: Widgets.opacity(modelData.name, status)
        textRotation: root.vertical ? -90 : 0

        onPressed: function(button) {
          if (!root.service) return
          var action = button === Qt.RightButton ? "right" : button === Qt.MiddleButton ? "middle" : "left"
          root.service.runAction(modelData.name, action)
        }
        onWheelMoved: function(delta) {
          if (modelData.name !== "ddc-brightness" || !root.service || delta === 0) return
          scrollAccumulator += delta / 120
          if (Math.abs(scrollAccumulator) < 0.05) return
          root.service.runAction(modelData.name, scrollAccumulator > 0 ? "up" : "down")
          scrollAccumulator = 0
        }
        onTooltipTextChanged: if (tooltipHovered && bar) bar.showTooltip(controlButton, tooltipText)
      }
    }

    WidgetButton {
      id: toggleButton
      bar: root.bar
      text: root.service && root.service.controlsExpanded ? "‹" : "⋯"
      tooltipText: root.service && root.service.controlsExpanded ? "Hide Hey Omarchy controls" : "Show Hey Omarchy controls"
      horizontalMargin: 7.5
      fontSize: 12
      textRotation: root.vertical ? -90 : 0

      onPressed: function(button) {
        if (button === Qt.LeftButton && root.service) root.service.controlsExpanded = !root.service.controlsExpanded
      }
      onTooltipTextChanged: if (tooltipHovered && bar) bar.showTooltip(toggleButton, tooltipText)
    }
  }
}

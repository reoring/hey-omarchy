import QtQuick
import qs.Ui
import "Widgets.js" as Widgets

BarWidget {
  id: root
  moduleName: "hey-omarchy"
  readonly property string name: String(setting("name", "main-monitor"))
  readonly property var service: {
    // Services are registered after widget creation; read the registry property
    // directly so replacing its map re-evaluates this binding.
    var services = bar?.shell?._services
    return services ? services["hey-omarchy"] || null : null
  }
  readonly property var status: service ? service.statuses[name] || ({}) : ({})
  property real scrollAccumulator: 0

  visible: button.hasVisualContent
  implicitWidth: button.hasVisualContent ? button.implicitWidth : 0
  implicitHeight: button.hasVisualContent ? button.implicitHeight : 0

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.status.text === undefined ? "" : String(root.status.text)
    tooltipText: String(root.status.tooltip || "")
    horizontalMargin: root.name === "ddc-brightness" ? 11.5 : 7.5
    fontSize: 12
    activeColor: "#a55555"
    active: Widgets.active(root.name, root.status)
    opacity: Widgets.opacity(root.name, root.status)
    textRotation: root.vertical ? -90 : 0

    onPressed: function(button) {
      if (!root.service) return
      var action = button === Qt.RightButton ? "right" : button === Qt.MiddleButton ? "middle" : "left"
      root.service.runAction(root.name, action)
    }
    onWheelMoved: function(delta) {
      if (root.name !== "ddc-brightness" || !root.service || delta === 0) return
      root.scrollAccumulator += delta / 120
      if (Math.abs(root.scrollAccumulator) < 0.05) return
      root.service.runAction(root.name, root.scrollAccumulator > 0 ? "up" : "down")
      root.scrollAccumulator = 0
    }
    onTooltipTextChanged: if (tooltipHovered && bar) bar.showTooltip(button, tooltipText)
  }
}

import QtQuick
import Quickshell
import "WaterSimulation.js" as Water

Item {
  id: glass
  clip: true
  property var simulation: null

  Image {
    id: background
    anchors.fill: parent
    source: "file://" + Quickshell.env("HOME") + "/.local/state/omarchy/current/background"
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
  }

  // Share one screen-sized, correctly cropped texture between all water lenses.
  ShaderEffectSource {
    id: wallpaperTexture
    sourceItem: background
    hideSource: true
    live: true
    visible: false
    textureSize: Qt.size(Math.max(1, glass.width), Math.max(1, glass.height))
  }

  Repeater {
    id: lenses
    model: glass.simulation ? glass.simulation.drops.length : 0

    ShaderEffect {
      visible: false
      property vector2d screenSize: Qt.vector2d(glass.width, glass.height)
      property vector4d drawRect: Qt.vector4d(x, y, width, height)
      property vector4d drop: Qt.vector4d(0, 0, 1, 1)
      property vector4d flow: Qt.vector4d(0, 0, 0, 0)
      property vector2d appearance: Qt.vector2d(0, 0)
      property var wallpaper: wallpaperTexture
      fragmentShader: Qt.resolvedUrl("glass.frag.qsb")
    }
  }

  function advance(dt) {
    if (!simulation) simulation = Water.create(width, height)
    Water.step(simulation, dt, width, height)
    for (var i = 0; i < simulation.drops.length; ++i) {
      var d = simulation.drops[i]
      var lens = lenses.itemAt(i)
      if (!lens) continue
      lens.visible = d.active && d.opacity > 0.001
      if (!lens.visible) continue
      var reach = d.radius * d.stretch * 1.6 + 8
      lens.x = d.baseX - d.radius * 2.5 - 8
      lens.y = Math.min(d.y - reach, d.trailTop - 4)
      lens.width = d.radius * 5 + 16
      lens.height = d.y + reach - lens.y
      // Pinned drops do not need new uniform vectors on every frame.
      if (lens.drop.x !== d.x || lens.drop.y !== d.y
          || lens.drop.z !== d.radius || lens.drop.w !== d.stretch)
        lens.drop = Qt.vector4d(d.x, d.y, d.radius, d.stretch)
      if (lens.flow.x !== d.baseX || lens.flow.y !== d.seed
          || lens.flow.z !== d.trailTop || lens.flow.w !== d.trailAlpha)
        lens.flow = Qt.vector4d(d.baseX, d.seed, d.trailTop, d.trailAlpha)
      if (lens.appearance.x !== d.impact || lens.appearance.y !== d.opacity)
        lens.appearance = Qt.vector2d(d.impact, d.opacity)
    }
  }

  FrameAnimation {
    running: glass.width > 0 && glass.height > 0 && background.status === Image.Ready
    onTriggered: glass.advance(frameTime)
  }
}

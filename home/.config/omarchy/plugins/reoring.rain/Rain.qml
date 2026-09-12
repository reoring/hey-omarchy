import QtQuick
import QtQuick.Particles
import Quickshell
import Quickshell.Wayland

Scope {
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel
      required property var modelData
      screen: modelData
      anchors { top: true; bottom: true; left: true; right: true }
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      // Above the existing wallpaper, below every normal application window.
      WlrLayershell.namespace: "reoring-rain"
      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      mask: Region {}

      ParticleSystem {
        id: rain
        anchors.fill: parent

        ImageParticle {
          groups: ["distant"]
          source: Qt.resolvedUrl("drop.svg")
          color: "#c6ddd9"
          alpha: 0.15
          alphaVariation: 0.04
          entryEffect: ImageParticle.None
        }

        ImageParticle {
          groups: ["near"]
          source: Qt.resolvedUrl("drop.svg")
          color: "#d4e8e4"
          alpha: 0.24
          alphaVariation: 0.05
          entryEffect: ImageParticle.None
        }

        Emitter {
          group: "distant"
          x: 0
          y: -40
          width: rain.width + 240
          emitRate: rain.width / 12
          lifeSpan: (rain.height + 100) / 430 * 1000
          size: 25
          sizeVariation: 7
          velocity: PointDirection {
            x: -70
            y: 510
            xVariation: 8
            yVariation: 80
          }
        }

        Emitter {
          group: "near"
          x: 0
          y: -50
          width: rain.width + 240
          emitRate: rain.width / 20
          lifeSpan: (rain.height + 120) / 730 * 1000
          size: 43
          sizeVariation: 9
          velocity: PointDirection {
            x: -115
            y: 850
            xVariation: 12
            yVariation: 120
          }
        }
      }

      Glass {
        anchors.fill: parent
      }
    }
  }
}

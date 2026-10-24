import QtQuick
import QtQuick.Effects

// A monitor as macOS draws one: the wallpaper, its corners rounded, in a
// thin black bezel with a hairline of light along its edge and a soft
// shadow under it. What's put inside is drawn over the wallpaper (a menu
// bar, a window). Used by the screens at the top of the pane, the scale
// cards, and the arrangement. `view` is the SettingsView.
Item {
  id: screen
  required property var view
  property real radius: 6
  property real bezel: 3
  property bool shadow: true
  property int sourceWidth: 360
  default property alias content: glass.data

  Rectangle {
    anchors.fill: parent
    radius: screen.radius
    color: "#0b0b0c"
    layer.enabled: screen.shadow && visible
    layer.effect: MultiEffect {
      shadowEnabled: true
      shadowColor: Qt.rgba(0, 0, 0, 0.55)
      shadowBlur: 0.5
      shadowVerticalOffset: 2
      autoPaddingEnabled: true
    }
  }
  Rectangle {
    id: glassMask
    anchors.fill: glass
    radius: Math.max(1, screen.radius - screen.bezel * 0.6)
    visible: false
    layer.enabled: glass.visible
  }
  Item {
    id: glass
    anchors.fill: parent
    anchors.margins: screen.bezel
    layer.enabled: visible
    layer.effect: MultiEffect {
      maskEnabled: true
      maskSource: glassMask
      maskThresholdMin: 0.5
      maskSpreadAtMin: 1
    }
    Image {
      anchors.fill: parent
      source: "file://" + screen.view.host.home + "/.local/state/omarchy/current/background"
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: false
      sourceSize.width: screen.sourceWidth
    }
  }
  // The bezel's edge catching the light.
  Rectangle {
    anchors.fill: parent
    radius: screen.radius
    color: "transparent"
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.12)
  }
}

import QtQuick
import Quickshell.Widgets

// iOS Control Center–style volume, laid on its side: the island becomes a wide
// slider that fills with the theme accent from the left, speaker glyph near
// the left end.
ClippingRectangle {
  id: slider
  required property var host
  // The island rectangle; the slider shares its corner radius.
  required property Item shape
  readonly property real level: host.muted ? 0 : Math.max(0, Math.min(1, host.volume))
  // Animate the level, not the pixel width, so the fill doesn't
  // restart its motion every frame while the island morphs.
  property real shownLevel: level
  Behavior on shownLevel { NumberAnimation { duration: 220 * host.motionScale; easing.type: Easing.OutCubic } }
  radius: shape.radius
  color: "transparent"
  opacity: host.volumePill ? 1 : 0
  visible: opacity > 0.01
  Behavior on opacity { NumberAnimation { duration: opacity > 0.5 ? 70 : 150 * host.motionScale; easing.type: Easing.InOutQuad } }

  // Grey track behind the fill: solid, since the clipping shape
  // drops translucent colors (it's white at 16% over the black island).
  Rectangle {
    anchors.fill: parent
    color: "#2a2a2a"
  }
  Rectangle {
    id: volumeFill
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: parent.width * slider.shownLevel
    color: host.colorAccent
  }
  Text {
    id: volumeIcon
    anchors.left: parent.left
    anchors.leftMargin: 18
    anchors.verticalCenter: parent.verticalCenter
    // Accent ink on the fill, light text when the fill doesn't reach it.
    readonly property bool onFill: volumeFill.width > x + width / 2
    text: slider.level <= 0 ? "󰖁" : slider.level < 0.34 ? "󰕿" : slider.level < 0.67 ? "󰖀" : "󰕾"
    color: onFill ? host.colorAccentText : host.colorText
    font.family: host.fontFamily
    font.pixelSize: 26
    Behavior on color { ColorAnimation { duration: 120 * host.motionScale } }
  }
}

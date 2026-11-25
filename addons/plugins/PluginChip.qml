import QtQuick
import "../../components"

// A plugin in the Plugins zone's XSmall and Small sizes (see PluginsZone):
// `round` is a bare round badge, its icon alone, as the Controls' XS ones; else
// a short tile, the icon's badge then the name. Accent while the plugin is on.
// A click does what PluginTile's does (see PluginsAddon.activate).
// `addon` is the PluginsAddon, `entry` the plugin, `center` the ControlCenter.
Rectangle {
  id: chip
  required property var addon
  required property var entry
  required property var center
  property bool round: false
  readonly property real size: 38
  readonly property var icon: addon.iconOf(entry.id)

  width: round ? size : 0
  height: size
  radius: round ? size / 2 : Math.min(center.cardRadius, size / 2)
  color: round ? (entry.enabled ? center.accent : center.well) : mouse.containsMouse ? center.tile : center.card
  border.width: round ? 0 : 1
  border.color: center.edge
  Behavior on color { MotionColorAnimation { theme: chip.center.host.theme } }
  scale: mouse.pressed ? 0.97 : 1
  Behavior on scale { MotionAnimation { theme: chip.center.host.theme; pace: mouse.pressed ? "press" : "standard" } }

  Rectangle {
    id: badge
    visible: !chip.round
    anchors.left: parent.left
    anchors.leftMargin: 5
    anchors.verticalCenter: parent.verticalCenter
    width: chip.size - 10; height: width; radius: width / 2
    color: chip.entry.enabled ? chip.center.accent : chip.center.well
    Behavior on color { MotionColorAnimation { theme: chip.center.host.theme } }
    Text {
      anchors.centerIn: parent
      text: chip.icon.text
      color: chip.entry.enabled ? chip.center.badgeOnInk : chip.center.text
      font.family: chip.icon.family || chip.center.iconFont
      font.pixelSize: chip.center.host.theme.px(15)
    }
  }
  Text {
    visible: chip.round
    anchors.centerIn: parent
    text: chip.icon.text
    color: chip.entry.enabled ? chip.center.badgeOnInk : chip.center.text
    Behavior on color { MotionColorAnimation { theme: chip.center.host.theme } }
    font.family: chip.icon.family || chip.center.iconFont
    font.pixelSize: chip.center.host.theme.px(18)
  }
  Text {
    visible: !chip.round
    anchors.left: badge.right
    anchors.leftMargin: 8
    anchors.right: parent.right
    anchors.rightMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    text: chip.entry.name
    elide: Text.ElideRight
    color: chip.center.text
    font.family: chip.center.host.theme.textFontFamily
    font.pixelSize: chip.center.host.theme.size.body
    font.weight: Font.DemiBold
    font.letterSpacing: chip.center.host.theme.tracking(chip.center.host.theme.textFontFamily, chip.center.host.theme.size.body)
  }
  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: chip.addon.activate(chip.entry)
  }
  // Only the round one hides its name.
  Tooltip {
    enabled: chip.round
    theme: chip.center.host.theme
    text: chip.entry.name + (chip.entry.enabled ? "" : " (off)")
  }
}

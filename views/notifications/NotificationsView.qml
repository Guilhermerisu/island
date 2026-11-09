import QtQuick
import "../control-center"

// The notification history on its own, opened from the hover capsules' bell:
// the control center's notifications zone (NotificationHistory), without the
// rest of the control center. Esc closes.
Item {
  id: view
  required property var host
  property bool active: false

  // What NotificationHistory reads off the control center it sits in.
  readonly property var center: view
  readonly property color text: host.theme.text
  readonly property color textMuted: host.theme.secondary
  readonly property color tile: host.theme.tile
  readonly property color card: host.theme.card
  readonly property color edge: host.theme.hairline
  readonly property color well: host.theme.well
  readonly property color wellHover: host.theme.wellHover
  readonly property string iconFont: host.theme.fontFamily
  readonly property bool editMode: false

  implicitWidth: history.implicitWidth
  implicitHeight: history.implicitHeight

  onActiveChanged: if (active) Qt.callLater(function() { view.forceActiveFocus() })
  Keys.onEscapePressed: view.host.view = "rest"

  NotificationHistory { id: history; center: view; width: view.width }
}

import QtQuick
import QtQuick.Layouts

// An app-icon squircle with a soft top-to-bottom gradient, as macOS draws
// its settings icons. Neutral when colorful icons are off.
// `view` is the SettingsView, for its colours.
Rectangle {
  id: paneIcon
  required property var view
  property string glyph: ""
  property color tint: paneIcon.view.accent
  property bool neutral: !paneIcon.view.settings.colorfulSettingsIcons
  property bool onAccent: false
  implicitWidth: 20
  implicitHeight: 20
  radius: width * 0.26
  gradient: Gradient {
    GradientStop { position: 0; color: paneIcon.neutral ? (paneIcon.onAccent ? paneIcon.view.accentInk : paneIcon.view.well) : Qt.lighter(paneIcon.tint, 1.18) }
    GradientStop { position: 1; color: paneIcon.neutral ? (paneIcon.onAccent ? paneIcon.view.accentInk : paneIcon.view.well) : paneIcon.tint }
  }
  border.width: paneIcon.neutral ? 0 : 1
  border.color: Qt.rgba(1, 1, 1, 0.16)
  Text {
    anchors.centerIn: parent
    text: paneIcon.glyph
    color: paneIcon.neutral ? (paneIcon.onAccent ? paneIcon.view.accent : paneIcon.view.textMuted) : "#ffffff"
    font.family: paneIcon.view.host.theme.fontFamily
    font.pixelSize: Math.round(paneIcon.width * 0.62)
  }
}

import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../views/settings/controls"

// Activity Monitor's quit sheet over the whole Settings view: Quit asks the
// process to end (SIGTERM), Force Quit ends it at once (SIGKILL).
// `view` is the SettingsView, which it's parented to.
Item {
  id: sheet
  required property var view
  property var row: null
  readonly property bool open: row !== null
  signal quit(var row, bool force)
  anchors.fill: parent
  z: 60
  // Visible as soon as it opens, so it can take focus mid-fade.
  visible: open || opacity > 0.01
  opacity: open ? 1 : 0
  Behavior on opacity { MotionAnimation { theme: sheet.view.host.theme; pace: sheet.open ? "fade" : "exit"; curve: "fade" } }

  function ask(target) {
    row = target
    forceActiveFocus()
  }
  function close() {
    row = null
    view.forceActiveFocus()
  }
  function finish(force) {
    if (row) quit(row, force)
    close()
  }
  // Settings closing (or the island showing another view) drops the question,
  // so it can't come back armed with old processes.
  Connections {
    target: sheet.view
    function onActiveChanged() { if (!sheet.view.active) sheet.row = null }
  }
  Keys.onEscapePressed: function(event) { close(); event.accepted = true }
  Keys.onReturnPressed: finish(false)

  Rectangle {
    anchors.fill: parent
    radius: 14
    color: Qt.rgba(0, 0, 0, 0.45)
    MouseArea {
      anchors.fill: parent
      onClicked: sheet.close()
      onWheel: function(wheel) {}
    }
  }

  Rectangle {
    id: card
    anchors.horizontalCenter: parent.horizontalCenter
    y: sheet.open ? 40 : 20
    Behavior on y { MotionAnimation { theme: sheet.view.host.theme; pace: sheet.open ? "standard" : "exit" } }
    width: 340
    height: body.implicitHeight + 36
    radius: 14
    color: Qt.tint(sheet.view.panel, sheet.view.host.theme.withAlpha(sheet.view.text, 0.12))
    border.width: 1
    border.color: sheet.view.host.theme.withAlpha(sheet.view.text, 0.1)
    MouseArea { anchors.fill: parent }

    ColumnLayout {
      id: body
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: 18
      spacing: 10
      Text {
        Layout.alignment: Qt.AlignHCenter
        text: "󰅙"
        color: "#ff453a"
        font.family: sheet.view.host.theme.fontFamily
        font.pixelSize: 40
      }
      Text {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: "Are you sure you want to quit “" + (sheet.row ? sheet.row.name : "") + "”?"
        color: sheet.view.text
        font.family: "Adwaita Sans"
        font.pixelSize: sheet.view.detailFontSize
        font.weight: Font.Bold
      }
      Text {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: sheet.row && sheet.row.children > 0
          ? "Its " + (sheet.row.children + 1) + " processes will be asked to end. Force Quit ends them at once, losing unsaved work."
          : "Force Quit ends it at once, losing unsaved work."
        color: sheet.view.textMuted
        font.family: "Adwaita Sans"
        font.pixelSize: sheet.view.detailCaptionFontSize
      }
      RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 6
        spacing: 8
        SettingsButton { view: sheet.view; label: "Cancel"; Layout.fillWidth: true; onClicked: sheet.close() }
        SettingsButton { view: sheet.view; label: "Force Quit"; Layout.fillWidth: true; onClicked: sheet.finish(true) }
        SettingsButton { view: sheet.view; label: "Quit"; primary: true; Layout.fillWidth: true; onClicked: sheet.finish(false) }
      }
    }
  }
}

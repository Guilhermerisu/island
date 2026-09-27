import QtQuick
import Quickshell.Widgets
import "file:///usr/share/omarchy/shell/plugins/clipboard/ClipboardHistory.js" as ClipboardHistory

// Clipboard live activity, laid out like a Dynamic Island activity on one
// line: what was copied on the leading side (an image's thumbnail, or a copy
// or file symbol in the accent), the copied text or file name in the middle,
// and "Copied" trailing in the accent. Fed by the history Omarchy's
// clipboard plugin records (see Island.qml). Clicking it opens the clipboard
// history.
Item {
  id: pill
  required property var host
  readonly property var entry: host.lastClip
  readonly property bool shown: host.clipboardPill
  readonly property string imagePath: {
    if (!entry) return ""
    if (entry.type === "image") return String(entry.path || "")
    var files = ClipboardHistory.filePaths(entry)
    return files.length === 1 && ClipboardHistory.isImagePath(files[0]) ? files[0] : ""
  }
  readonly property bool isFiles: !!entry && ClipboardHistory.filePaths(entry).length > 0

  opacity: shown ? 1 : 0
  visible: opacity > 0.01
  Behavior on opacity { NumberAnimation { duration: opacity > 0.5 ? 70 : 150 * pill.host.motionScale; easing.type: Easing.InOutQuad } }

  // Leading: the thumbnail, or the symbol, springing in.
  Item {
    id: leading
    anchors.left: parent.left
    anchors.leftMargin: 10
    anchors.verticalCenter: parent.verticalCenter
    width: 26; height: 26
    scale: pill.shown ? 1 : 0.4
    Behavior on scale { NumberAnimation { duration: 360 * pill.host.motionScale; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
    ClippingRectangle {
      anchors.fill: parent
      visible: !!pill.imagePath
      radius: 6
      color: "transparent"
      Image {
        anchors.fill: parent
        source: pill.imagePath ? "file://" + pill.imagePath : ""
        sourceSize.width: 52
        sourceSize.height: 52
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
      }
    }
    Text {
      anchors.centerIn: parent
      visible: !pill.imagePath
      text: pill.isFiles ? "󰈔" : "󰆏"
      color: pill.host.colorAccent
      font.family: pill.host.fontFamily
      font.pixelSize: 19
    }
  }

  // Middle: what was copied.
  Text {
    anchors.left: leading.right
    anchors.leftMargin: 10
    anchors.right: trailing.left
    anchors.rightMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    text: pill.entry ? ClipboardHistory.previewText(pill.entry) : ""
    textFormat: Text.PlainText
    elide: Text.ElideRight
    color: "#ffffff"
    font.family: "Adwaita Sans"
    font.pixelSize: 13
    font.weight: Font.Medium
    font.letterSpacing: -0.2
  }

  // Trailing: the status, a beat after the rest.
  Text {
    id: trailing
    anchors.right: parent.right
    anchors.rightMargin: 16
    anchors.verticalCenter: parent.verticalCenter
    text: "Copied"
    color: pill.host.colorAccent
    font.family: "Adwaita Sans"
    font.pixelSize: 13
    font.weight: Font.DemiBold
    font.letterSpacing: -0.2
    opacity: pill.shown ? 1 : 0
    Behavior on opacity {
      SequentialAnimation {
        PauseAnimation { duration: pill.shown ? 120 * pill.host.motionScale : 0 }
        NumberAnimation { duration: 180 * pill.host.motionScale; easing.type: Easing.OutQuad }
      }
    }
  }
}

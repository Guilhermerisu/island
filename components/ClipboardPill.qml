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
  readonly property var entry: host.clipboard.last
  readonly property bool shown: host.clipboardPill
  // Copied files: file:// URIs (most apps), or plain absolute paths, one per
  // line (Nautilus).
  readonly property var files: {
    if (!entry || entry.type !== "text") return []
    var uris = ClipboardHistory.filePaths(entry)
    if (uris.length) return uris
    var lines = String(entry.text || "").split(/\r?\n/).map(function(l) { return l.trim() }).filter(function(l) { return l })
    return lines.length && lines.every(function(l) { return /^\/[^\0]+$/.test(l) }) ? lines : []
  }
  readonly property bool isFiles: files.length > 0
  readonly property string imagePath: {
    if (!entry) return ""
    if (entry.type === "image") return String(entry.path || "")
    return files.length === 1 && ClipboardHistory.isImagePath(files[0]) ? files[0] : ""
  }
  readonly property bool thumbnailReady: thumbnail.status === Image.Ready

  opacity: shown ? 1 : 0
  visible: opacity > 0.01
  Behavior on opacity { MotionAnimation { theme: pill.host.theme; pace: "fade"; curve: "fade" } }

  // Leading: the thumbnail, or the symbol, settling gently into place.
  Item {
    id: leading
    anchors.left: parent.left
    anchors.leftMargin: 10
    anchors.verticalCenter: parent.verticalCenter
    width: 26; height: 26
    scale: pill.shown ? 1 : 0.86
    Behavior on scale { MotionAnimation { theme: pill.host.theme; pace: "expressive" } }
    ClippingRectangle {
      anchors.fill: parent
      visible: pill.thumbnailReady
      radius: 6
      color: "transparent"
      Image {
        id: thumbnail
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
      visible: !pill.thumbnailReady
      text: pill.isFiles ? "󰈔" : "󰆏"
      color: pill.host.theme.accent
      font.family: pill.host.theme.fontFamily
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
    text: {
      if (!pill.entry) return ""
      // Omarchy labels every PNG "Screenshot from …", even a copied image.
      if (pill.entry.type === "image") return "Image"
      if (pill.isFiles) return pill.files.length === 1 ? ClipboardHistory.fileName(pill.files[0]) : pill.files.length + " files"
      var preview = ClipboardHistory.previewText(pill.entry)
      if (pill.entry.type !== "text" || !pill.host.clipboard.isHtml(pill.entry.text)) return preview
      // Rich text from a browser arrives as HTML; show its words, not tags.
      var plain = String(pill.entry.text).replace(/<(script|style)[\s\S]*?<\/\1>/gi, " ")
        .replace(/<[^>]*>/g, " ").replace(/&nbsp;/g, " ").replace(/&amp;/g, "&")
        .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"").replace(/\s+/g, " ").trim()
      return plain || "Rich text"
    }
    textFormat: Text.PlainText
    elide: Text.ElideRight
    color: "#ffffff"
    font.family: pill.host.theme.textFontFamily
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
    color: pill.host.theme.accent
    font.family: pill.host.theme.textFontFamily
    font.pixelSize: 13
    font.weight: Font.DemiBold
    font.letterSpacing: -0.2
    opacity: pill.shown ? 1 : 0
    Behavior on opacity {
      SequentialAnimation {
        PauseAnimation { duration: pill.shown ? pill.host.theme.contentRevealDelay : 0 }
        MotionAnimation { theme: pill.host.theme; pace: "standard" }
      }
    }
  }
}

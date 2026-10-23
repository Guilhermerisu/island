import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../../components"
// Omarchy's own history helpers, so search and previews match its picker.
import "file:///usr/share/omarchy/shell/plugins/clipboard/ClipboardHistory.js" as ClipboardHistory

// Clipboard history: the shared list view over the history Omarchy's
// clipboard plugin keeps (it stays in charge of capturing copies; this only
// reads and acts on them). Enter pastes into the app you were using,
// Shift+Enter copies without pasting, Alt+Enter opens the entry, and Delete
// removes it — the same keys and commands as Omarchy's picker.
ListPicker {
  id: clipboard
  placeholder: "Search clipboard"
  emptyText: history.length ? "Nothing matches" : "Clipboard history is empty"
  rowHeight: 44
  visibleRows: 9
  // Room for the image preview even when only a few entries match.
  minRows: 5
  items: ClipboardHistory.displayRows(history, query, 50)
  onChosen: function(entry) { paste(entry, false) }
  onKeyFilter: function(event) {
    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      if (event.modifiers & Qt.AltModifier) { open(selected); event.accepted = true }
      else if (event.modifiers & Qt.ShiftModifier) { paste(selected, true); event.accepted = true }
    } else if (event.key === Qt.Key_Delete) {
      remove(selected); event.accepted = true
    }
  }

  readonly property string omarchyPath: Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy"
  property var history: []
  // A delete re-reads the file first and drops the entry by its stable key, so
  // a copy that landed since the last watch still survives the write.
  property string pendingRemoveKey: ""
  FileView {
    id: historyFile
    path: clipboard.host.home + "/.local/state/omarchy/clipboard-history.json"
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: clipboard.historyLoaded(text())
    onLoadFailed: { clipboard.pendingRemoveKey = ""; clipboard.history = [] }
    onFileChanged: reload()
  }
  function historyLoaded(raw) {
    var fresh = ClipboardHistory.parseHistory(raw)
    if (pendingRemoveKey) {
      var key = pendingRemoveKey
      pendingRemoveKey = ""
      var next = fresh.filter(function(entry) { return ClipboardHistory.entryKey(entry) !== key })
      history = next
      if (next.length !== fresh.length) historyFile.setText(JSON.stringify(next, null, 2) + "\n")
      return
    }
    history = fresh
  }

  // Close first so the keyboard goes back to the previous app, then let
  // Omarchy's commands paste (or just copy) the entry by its history index.
  Process { id: runner }
  function run(argv) {
    host.view = "rest"
    // Pasting copies the entry again; that's not news for the Copied pill.
    host.clipboard.quietUntil = Date.now() + 2500
    runner.command = ["bash", "-c", 'sleep 0.15; exec "$@"', "--"].concat(argv)
    runner.startDetached()
  }
  function paste(row, copyOnly) {
    if (!row) return
    var bin = omarchyPath + "/bin/"
    if (row.entryType === "image")
      run([bin + "omarchy-clipboard-paste-file"].concat(copyOnly ? ["--copy-only"] : []).concat([row.mime, row.path]))
    else if (row.fullText)
      run([bin + "omarchy-clipboard-paste-text", copyOnly ? "--copy-only" : "--shift-insert", "--history-index", String(row.index)])
  }
  function open(row) {
    if (!row) return
    run([omarchyPath + "/bin/omarchy-clipboard-open", "--history-index", String(row.index)])
  }
  // Writing the shared history file; Omarchy's plugin reloads it too.
  function remove(row) {
    if (!row) return
    var entry = history[row.index]
    if (!entry) return
    pendingRemoveKey = ClipboardHistory.entryKey(entry)
    historyFile.reload(true)
  }

  // Preview pane: the selected picture, rounded, at its own proportions.
  sideWidth: 280
  // Only pictures get the pane; text rows already show their content.
  sideVisible: !!(selected && selected.previewImage)
  side: Component {
    Item {
      id: preview
      property var entry: ({})
      readonly property bool isImage: !!entry.previewImage
      readonly property string body: String(entry.fullText || entry.previewText || "").trim()

      Item {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        // The picture in a card at the top of the pane, fitted at its own
        // aspect ratio, with the entry's name under it.
        Rectangle {
          id: previewCard
          readonly property real ratio: previewImage.implicitHeight > 0 ? previewImage.implicitWidth / previewImage.implicitHeight : 1
          readonly property real inner: width - 16
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          height: Math.min(inner / ratio, parent.height - 50) + 16 + 26
          radius: clipboard.host.theme.radii.card
          color: clipboard.host.theme.card
          border.width: 1
          border.color: clipboard.host.theme.hairline
          visible: preview.isImage && previewImage.status === Image.Ready
          ClippingRectangle {
            anchors.top: parent.top
            anchors.topMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            height: Math.min(previewCard.inner / previewCard.ratio, previewCard.parent.height - 50)
            width: height * previewCard.ratio
            radius: 10
            color: "transparent"
            Image {
              id: previewImage
              anchors.fill: parent
              source: preview.isImage ? "file://" + preview.entry.previewImage : ""
              sourceSize.width: 640
              fillMode: Image.PreserveAspectFit
              asynchronous: true
              smooth: true
            }
          }
          Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 10
            anchors.bottomMargin: 8
            horizontalAlignment: Text.AlignHCenter
            text: String(preview.entry.previewText || "").trim()
            textFormat: Text.PlainText
            elide: Text.ElideMiddle
            color: clipboard.host.theme.secondary
            font.family: clipboard.host.theme.textFontFamily
            font.letterSpacing: clipboard.host.theme.tracking(clipboard.host.theme.textFontFamily, clipboard.host.theme.px(11))
            font.pixelSize: clipboard.host.theme.px(11)
          }
        }
        Text {
          anchors.centerIn: parent
          visible: preview.isImage && previewImage.status === Image.Error
          text: "Image unavailable"
          color: clipboard.host.theme.muted
          font.family: clipboard.host.theme.textFontFamily
          font.letterSpacing: clipboard.host.theme.tracking(clipboard.host.theme.textFontFamily, clipboard.host.theme.px(12))
          font.pixelSize: clipboard.host.theme.px(12)
        }
        Text {
          anchors.fill: parent
          visible: !preview.isImage
          text: preview.body
          textFormat: Text.PlainText
          wrapMode: Text.Wrap
          elide: Text.ElideRight
          clip: true
          color: clipboard.host.theme.text
          font.family: clipboard.host.theme.textFontFamily
          font.letterSpacing: clipboard.host.theme.tracking(clipboard.host.theme.textFontFamily, clipboard.host.theme.px(15))
          font.pixelSize: clipboard.host.theme.px(15)
          lineHeight: 1.3
        }
      }
    }
  }

  row: Component {
    Item {
      id: clipRow
      property var entry: ({})
      property bool selected: false
      readonly property bool hasPreview: !!entry.previewImage

      // Image thumbnail, or a plain glyph for text / file entries.
      Item {
        id: badge
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 28; height: 28
        ClippingRectangle {
          anchors.fill: parent
          radius: 6
          color: "transparent"
          visible: clipRow.hasPreview && thumb.status === Image.Ready
          Image {
            id: thumb
            anchors.fill: parent
            source: clipRow.hasPreview ? "file://" + clipRow.entry.previewImage : ""
            sourceSize.width: 56
            sourceSize.height: 56
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
          }
        }
        Text {
          anchors.centerIn: parent
          visible: !(clipRow.hasPreview && thumb.status === Image.Ready)
          text: clipRow.entry.entryType === "image" ? "󰋩" : clipRow.entry.entryType === "file" ? "󰈔" : "󰆒"
          color: clipRow.selected ? clipboard.host.theme.text : clipboard.host.theme.muted
          font.family: clipboard.host.theme.fontFamily
          font.pixelSize: clipboard.host.theme.px(18)
        }
      }
      Text {
        anchors.left: badge.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: String(clipRow.entry.previewText || "").trim()
        textFormat: Text.PlainText
        elide: Text.ElideRight
        maximumLineCount: 1
        color: clipboard.host.theme.text
        font.family: clipboard.host.theme.textFontFamily
        font.letterSpacing: clipboard.host.theme.tracking(clipboard.host.theme.textFontFamily, clipboard.host.theme.px(13))
        font.pixelSize: clipboard.host.theme.px(13)
        font.weight: clipRow.selected ? Font.Medium : Font.Normal
      }
    }
  }
}

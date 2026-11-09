import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../../components"

// Wallpaper picker for the current theme: the images and videos in the theme's
// backgrounds/ folder plus ~/.config/omarchy/backgrounds/<theme>/, the same
// set Omarchy's own background switcher offers. Rows come from
// omarchy-menu-images, which also gives videos the ffmpegthumbnailer stills the
// native picker shows: Qt cannot draw a video frame as a card, so a still is
// what makes them selectable. Applying runs omarchy-theme-bg-set.
Picker {
  id: ws
  cardHeight: 110
  placeholder: "Search wallpapers"
  emptyText: "No wallpapers match"
  currentKey: currentPath
  applyCommand: function(entry) { return ["omarchy-theme-bg-set", entry.path] }
  onApplied: linkReader.running = true

  onActiveChanged: {
    if (!active) return
    // The theme's backgrounds folder is replaced on theme switches, so reload
    // the rows on every open.
    refresh()
    linkReader.running = true
  }

  card: Component {
    ClippingRectangle {
      id: wallpaperCard
      property var entry: ({})
      radius: ws.cardRadius
      color: ws.host.theme.surface

      Image {
        anchors.fill: parent
        // Every row carries a thumbnail: the still itself for an image, the
        // first frame for a video.
        source: wallpaperCard.entry.thumbnail ? "file://" + wallpaperCard.entry.thumbnail : ""
        sourceSize.width: 400
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
      }
    }
  }

  // ---------- Wallpaper data ----------

  readonly property string stateDir: host.home + "/.local/state/omarchy/current"
  readonly property string themeDir: stateDir + "/theme/backgrounds"
  readonly property string userDir: host.theme.name
    ? host.home + "/.config/omarchy/backgrounds/" + host.theme.name
    : ""
  property string currentPath: ""

  // The current background is a symlink; resolve it to compare with cards.
  Process {
    id: linkReader
    command: ["readlink", "-f", ws.stateDir + "/background"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: ws.currentPath = String(text || "").trim()
    }
  }
  Component.onCompleted: {
    linkReader.running = true
    // Warm the rows so the first open shows cards straight away; the open
    // still refreshes them for a theme switch.
    refresh()
  }

  // The theme name is read asynchronously at startup; warm once it is known.
  Connections {
    target: ws.host.theme
    function onNameChanged() { if (ws.active) ws.refresh() }
  }

  // ---------- Rows ----------

  // The native selector builds the rows (and their cached thumbnails) for
  // both folders; --print-rows keeps it from opening its own picker.
  property bool scanQueued: false
  property string rowsOutput: ""

  function refresh() {
    if (!userDir) return
    if (rowsReader.running) { scanQueued = true; return }
    rowsReader.command = ["omarchy-menu-images", "--print-rows", themeDir, userDir]
    rowsReader.running = true
  }

  Process {
    id: rowsReader
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: ws.rowsOutput = String(text || "")
    }
    onExited: function(code) {
      // A missing command (an older Omarchy) must not wipe the last good list.
      if (code === 0) ws.collect(ws.rowsOutput)
      if (!ws.scanQueued) return
      ws.scanQueued = false
      ws.refresh()
    }
  }

  // "00-fog-desends.jpg" -> "fog-desends"
  function displayName(fileName) {
    return String(fileName).replace(/\.[^.]+$/, "").replace(/^\d+[-_ ]+/, "")
  }

  // One "path<TAB>thumbnail" line per media file, in the same order as the
  // native picker. A video the converter rejected simply has no line.
  function collect(rows) {
    var list = []
    var lines = rows.split("\n")
    for (var i = 0; i < lines.length; i++) {
      if (!lines[i]) continue
      var columns = lines[i].split("\t")
      var path = columns[0]
      if (!path) continue
      var fileName = path.split("/").pop()
      list.push({
        key: path,
        path: path,
        thumbnail: columns[1] || path,
        fileName: fileName,
        name: displayName(fileName)
      })
    }
    list.sort(function(a, b) { return a.fileName < b.fileName ? -1 : a.fileName > b.fileName ? 1 : 0 })
    items = list
  }
}

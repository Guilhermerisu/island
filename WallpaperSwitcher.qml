import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

// Wallpaper picker for the current theme: the images in the theme's
// backgrounds/ folder plus ~/.config/omarchy/backgrounds/<theme>/, the same
// set Omarchy's own background switcher offers. Applying runs
// omarchy-theme-bg-set.
Picker {
  id: ws
  viewName: "wallpapers"
  cardHeight: 110
  placeholder: "Search wallpapers…"
  emptyText: "No wallpapers match"
  currentKey: currentPath
  applyCommand: function(entry) { return ["omarchy-theme-bg-set", entry.path] }
  onApplied: linkReader.running = true

  onActiveChanged: {
    if (!active) return
    // The theme's backgrounds folder is replaced on theme switches, which a
    // directory watch can miss; reload both listings on every open.
    refreshTick++
    linkReader.running = true
  }

  card: Component {
    ClippingRectangle {
      id: wallpaperCard
      property var entry: ({})
      radius: 14
      color: ws.host.colorSurface

      Image {
        anchors.fill: parent
        source: wallpaperCard.entry.path ? "file://" + wallpaperCard.entry.path : ""
        sourceSize.width: 400
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
      }
    }
  }

  // ---------- Wallpaper data ----------

  readonly property string stateDir: host.home + "/.local/state/omarchy/current"
  property string currentPath: ""
  property int refreshTick: 0
  readonly property var imageFilters: ["*.jpg", "*.jpeg", "*.png", "*.gif", "*.bmp", "*.webp"]

  // The current background is a symlink; resolve it to compare with cards.
  Process {
    id: linkReader
    command: ["readlink", "-f", ws.stateDir + "/background"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: ws.currentPath = String(text || "").trim()
    }
  }
  Component.onCompleted: linkReader.running = true

  // A trailing slash toggled by refreshTick forces FolderListModel to rescan.
  FolderListModel {
    id: themeBackgrounds
    folder: "file://" + ws.stateDir + "/theme/backgrounds" + (ws.refreshTick % 2 ? "/" : "")
    nameFilters: ws.imageFilters
    caseSensitive: false
    showDirs: false
    onStatusChanged: collectTimer.restart()
    onCountChanged: collectTimer.restart()
  }
  FolderListModel {
    id: userBackgrounds
    folder: ws.host.themeName ? "file://" + ws.host.home + "/.config/omarchy/backgrounds/" + ws.host.themeName + (ws.refreshTick % 2 ? "/" : "") : ""
    nameFilters: ws.imageFilters
    caseSensitive: false
    showDirs: false
    onStatusChanged: collectTimer.restart()
    onCountChanged: collectTimer.restart()
  }

  // "00-fog-desends.jpg" -> "fog-desends"
  function displayName(fileName) {
    return String(fileName).replace(/\.[^.]+$/, "").replace(/^\d+[-_ ]+/, "")
  }

  // Both folders rescan independently; rebuilding on each signal would
  // briefly publish one folder while the other is mid-rescan (and empty).
  // Coalesce, and wait until neither is loading.
  Timer {
    id: collectTimer
    interval: 40
    onTriggered: {
      if (themeBackgrounds.status === FolderListModel.Loading || userBackgrounds.status === FolderListModel.Loading) restart()
      else ws.collect()
    }
  }

  function collect() {
    var list = []
    function add(model) {
      for (var i = 0; i < model.count; i++) {
        var path = String(model.get(i, "filePath"))
        var fileName = String(model.get(i, "fileName"))
        list.push({ key: path, path: path, fileName: fileName, name: displayName(fileName) })
      }
    }
    add(userBackgrounds)
    add(themeBackgrounds)
    list.sort(function(a, b) { return a.fileName < b.fileName ? -1 : a.fileName > b.fileName ? 1 : 0 })
    items = list
  }
}

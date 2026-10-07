import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import "../../components"

// Theme picker: one card per installed theme showing its background color
// and palette. Applying runs omarchy-theme-set.
Picker {
  id: ts
  placeholder: "Search themes…"
  emptyText: "No themes match"
  currentKey: host.theme.name
  applyCommand: function(entry) { return ["omarchy-theme-set", entry.name] }

  card: Component {
    Rectangle {
      id: themeCard
      property var entry: ({})
      radius: ts.cardRadius
      color: entry.background || ts.host.theme.surface

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 27
        spacing: 7
        Repeater {
          model: themeCard.entry.swatches || []
          delegate: Rectangle {
            required property var modelData
            width: 16; height: 16; radius: 8
            color: modelData
          }
        }
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        width: parent.width - 20
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: themeCard.entry.name || ""
        color: themeCard.entry.foreground || ts.host.theme.text
        font.family: ts.host.theme.textFontFamily
        font.pixelSize: 13
        font.weight: Font.DemiBold
      }
    }
  }

  // ---------- Theme data ----------
  //
  // Themes are the folders in ~/.config/omarchy/themes and Omarchy's stock
  // themes dir; a user folder shadows the stock one of the same name. Each
  // card reads the theme's colors.toml, falling back to the stock copy when
  // the user folder has none.

  readonly property string userThemesDir: host.home + "/.config/omarchy/themes"
  readonly property string stockThemesDir: (Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy") + "/themes"

  FolderListModel {
    id: userThemes
    folder: "file://" + ts.userThemesDir
    showFiles: false
    showDotAndDotDot: false
    onStatusChanged: ts.collectDirs()
    onCountChanged: ts.collectDirs()
  }
  FolderListModel {
    id: stockThemes
    folder: "file://" + ts.stockThemesDir
    showFiles: false
    showDotAndDotDot: false
    onStatusChanged: ts.collectDirs()
    onCountChanged: ts.collectDirs()
  }

  // Sorted theme names, and one entry per colors.toml to read:
  // { name, path, rank } where rank 0 (user copy) beats rank 1 (stock).
  property var themeNames: []
  property var colorSources: []
  // "name/rank" -> parsed colors (or null when missing/unreadable).
  property var parsedColors: ({})

  function collectDirs() {
    if (userThemes.status !== FolderListModel.Ready || stockThemes.status !== FolderListModel.Ready) return
    var byName = {}
    function add(model, dir) {
      for (var i = 0; i < model.count; i++) {
        var name = String(model.get(i, "fileName"))
        if (!byName[name]) byName[name] = []
        byName[name].push(dir + "/" + name + "/colors.toml")
      }
    }
    add(userThemes, userThemesDir)
    add(stockThemes, stockThemesDir)
    var names = Object.keys(byName).sort()
    var sources = []
    names.forEach(function(n) {
      byName[n].forEach(function(path, rank) { sources.push({ name: n, path: path, rank: rank }) })
    })
    parsedColors = ({})
    themeNames = names
    colorSources = sources
  }

  // Every candidate file is read in parallel; switching one FileView's path
  // after a failure drops the retry, so there's no fallback chain here.
  Instantiator {
    model: ts.colorSources
    delegate: FileView {
      required property var modelData
      path: modelData.path
      printErrors: false
      onLoaded: ts.addColors(modelData.name + "/" + modelData.rank, text())
      onLoadFailed: ts.addColors(modelData.name + "/" + modelData.rank, "")
    }
  }

  function parseColors(raw) {
    var c = {}
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var m = lines[i].match(/^\s*([A-Za-z0-9_]+)\s*=\s*["']?(#[0-9A-Fa-f]{6})/)
      if (m) c[m[1]] = m[2]
    }
    function pick(a, b) { return c[a] || c[b] || "" }
    var background = pick("background", "color0")
    if (!background) return null
    var swatches = []
    var names = ["red", "green", "yellow", "blue", "magenta", "cyan"]
    for (var j = 0; j < names.length; j++) {
      var s = pick(names[j], "color" + (j + 1))
      if (s) swatches.push(s)
    }
    return { background: background, foreground: pick("foreground", "color7"), accent: pick("accent", "color4"), swatches: swatches }
  }

  function addColors(key, raw) {
    var next = Object.assign({}, parsedColors)
    next[key] = parseColors(raw)
    parsedColors = next
    publish()
  }

  // Rebuild the card list once every theme's colors.toml has been read.
  function publish() {
    for (var i = 0; i < colorSources.length; i++)
      if (!((colorSources[i].name + "/" + colorSources[i].rank) in parsedColors)) return
    var list = []
    for (var j = 0; j < themeNames.length; j++) {
      var name = themeNames[j]
      var colors = parsedColors[name + "/0"] || parsedColors[name + "/1"]
      if (!colors) continue
      list.push({ key: name, name: name, background: colors.background, foreground: colors.foreground,
                  accent: colors.accent, swatches: colors.swatches })
    }
    items = list
  }
}

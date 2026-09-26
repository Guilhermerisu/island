import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

// Theme picker hosted by the island: search field, a centered carousel of
// theme cards (background + palette), and Enter to apply. Reads its palette
// and timings from the island root passed in as `host`.
Item {
  id: ts
  required property var host
  property bool active: false
  signal closeRequested()

  property var themes: []
  property string query: ""
  property bool applying: false
  readonly property var filtered: {
    var q = query.trim().toLowerCase().replace(/\s+/g, "-")
    if (!q) return themes
    return themes.filter(function(t) { return t.name.indexOf(q) !== -1 })
  }
  readonly property var selected: filtered[carousel.currentIndex] || null

  implicitHeight: header.height + 14 + carousel.height

  onActiveChanged: {
    if (!active) return
    applying = false
    search.text = ""
    selectCurrent()
    Qt.callLater(function() { search.forceActiveFocus() })
  }
  // Typing jumps to the first match; list rebuilds keep the selection.
  onQueryChanged: jumpTo(0)

  // Move the selection without the carousel scrolling through everything in
  // between (a model reset otherwise animates back from card 0).
  property bool snapping: false
  function jumpTo(index) {
    snapping = true
    carousel.currentIndex = index
    carousel.positionViewAtIndex(index, ListView.Center)
    Qt.callLater(function() { ts.snapping = false })
  }

  function selectCurrent() {
    for (var i = 0; i < filtered.length; i++) {
      if (filtered[i].name === currentName) { jumpTo(i); return }
    }
  }

  // ---------- Theme data ----------
  //
  // Themes are the folders in ~/.config/omarchy/themes and Omarchy's stock
  // themes dir; a user folder shadows the stock one of the same name. Each
  // card reads the theme's colors.toml, falling back to the stock copy when
  // the user folder has none. theme.name holds the active theme's folder name.

  readonly property string home: Quickshell.env("HOME")
  readonly property string userThemesDir: home + "/.config/omarchy/themes"
  readonly property string stockThemesDir: (Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy") + "/themes"
  property string currentName: ""

  FileView {
    path: ts.home + "/.local/state/omarchy/current/theme.name"
    watchChanges: true
    printErrors: false
    onLoaded: ts.currentName = text().trim()
    onFileChanged: reload()
  }

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
      list.push({ name: name, background: colors.background, foreground: colors.foreground,
                  accent: colors.accent, swatches: colors.swatches })
    }
    var keep = selected ? selected.name : ""
    themes = list
    if (!active) return
    for (var k = 0; k < filtered.length; k++) {
      if (filtered[k].name === keep) { jumpTo(k); return }
    }
    selectCurrent()
  }

  Process {
    id: applier
    onExited: {
      ts.applying = false
      ts.closeRequested()
    }
  }

  function move(delta) {
    if (!filtered.length) return
    carousel.currentIndex = (carousel.currentIndex + delta + filtered.length) % filtered.length
  }

  function apply() {
    if (!selected || applying) return
    if (selected.name === currentName) { closeRequested(); return }
    applying = true
    applier.command = ["omarchy-theme-set", selected.name]
    applier.running = true
  }

  // ---------- Search ----------

  Item {
    id: header
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: 30

    Text {
      id: searchIcon
      anchors.left: parent.left
      anchors.leftMargin: 4
      anchors.verticalCenter: parent.verticalCenter
      text: "󰍉"
      color: ts.host.colorMuted
      font.family: ts.host.fontFamily
      font.pixelSize: 17
    }
    TextInput {
      id: search
      anchors.left: searchIcon.right
      anchors.leftMargin: 12
      anchors.right: parent.right
      anchors.rightMargin: 4
      anchors.verticalCenter: parent.verticalCenter
      color: ts.host.colorText
      selectionColor: ts.host.withAlpha(ts.host.colorAccent, 0.4)
      selectedTextColor: ts.host.colorText
      font.family: "Adwaita Sans"
      font.pixelSize: 15
      clip: true
      onTextChanged: ts.query = text
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Right || event.key === Qt.Key_Down || (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier))) {
          ts.move(1); event.accepted = true
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
          ts.move(-1); event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          ts.apply(); event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
          ts.closeRequested(); event.accepted = true
        }
      }
      Text {
        anchors.fill: parent
        verticalAlignment: Text.AlignVCenter
        visible: search.text === ""
        text: "Search themes…"
        color: ts.host.colorMuted
        font: search.font
      }
    }
  }

  // ---------- Carousel ----------

  ListView {
    id: carousel
    readonly property int cardWidth: 196
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: header.bottom
    anchors.topMargin: 14
    height: 106
    orientation: ListView.Horizontal
    spacing: 12
    clip: true
    model: ts.filtered
    boundsBehavior: Flickable.StopAtBounds
    highlightRangeMode: ListView.StrictlyEnforceRange
    preferredHighlightBegin: (width - cardWidth) / 2
    preferredHighlightEnd: (width + cardWidth) / 2
    highlightMoveDuration: ts.snapping ? 0 : 240 * ts.host.motionScale
    keyNavigationEnabled: false

    WheelHandler {
      onWheel: function(event) {
        var d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
        ts.move(d > 0 ? -1 : 1)
      }
    }

    delegate: Rectangle {
      id: card
      required property var modelData
      required property int index
      readonly property bool isSelected: ListView.isCurrentItem
      width: carousel.cardWidth
      height: carousel.height - 4
      y: 2
      radius: 14
      color: modelData.background || ts.host.colorSurface
      border.width: isSelected ? 2 : 1
      border.color: isSelected ? ts.host.colorAccent : ts.host.withAlpha(ts.host.colorText, 0.08)
      opacity: isSelected ? 1 : 0.55
      scale: isSelected ? 1 : 0.95
      Behavior on opacity { NumberAnimation { duration: 180 * ts.host.motionScale; easing.type: Easing.OutCubic } }
      Behavior on scale { NumberAnimation { duration: 180 * ts.host.motionScale; easing.type: Easing.OutCubic } }
      Behavior on border.color { ColorAnimation { duration: 180 * ts.host.motionScale } }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 27
        spacing: 7
        Repeater {
          model: card.modelData.swatches || []
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
        text: card.modelData.name
        color: card.modelData.foreground || ts.host.colorText
        font.family: "Adwaita Sans"
        font.pixelSize: 13
        font.weight: Font.DemiBold
      }
      // Marks the theme that's active right now.
      Rectangle {
        visible: card.modelData.name === ts.currentName
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 9
        width: 6; height: 6; radius: 3
        color: card.modelData.foreground || ts.host.colorText
      }
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (card.isSelected) ts.apply()
          else carousel.currentIndex = card.index
          search.forceActiveFocus()
        }
      }
    }

    Text {
      anchors.centerIn: parent
      visible: ts.filtered.length === 0 && ts.themes.length > 0
      text: "No themes match"
      color: ts.host.colorMuted
      font.family: "Adwaita Sans"
      font.pixelSize: 13
    }
  }

  // Fade the cards out toward the ends, into the island's background.
  Rectangle {
    anchors.left: carousel.left
    anchors.top: carousel.top
    anchors.bottom: carousel.bottom
    width: 56
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0; color: ts.host.colorBackground }
      GradientStop { position: 1; color: ts.host.withAlpha(ts.host.colorBackground, 0) }
    }
  }
  Rectangle {
    anchors.right: carousel.right
    anchors.top: carousel.top
    anchors.bottom: carousel.bottom
    width: 56
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0; color: ts.host.withAlpha(ts.host.colorBackground, 0) }
      GradientStop { position: 1; color: ts.host.colorBackground }
    }
  }
}

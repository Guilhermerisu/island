import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../../components"
import "../../components/IconSource.js" as IconSource
// Omarchy's own launcher ranking, so results match its menu exactly.
import "file:///usr/share/omarchy/shell/services/AppSearch.js" as AppSearch

// Application launcher: the shared list view over the installed apps (icon
// tile and name). Search matches names, descriptions, and keywords. Uses the
// same app set as Omarchy's launcher (desktop entries minus its hidden lists)
// and launches the same way. Enabled addons can add rows for the typed text
// (Ask AI's, see addons/Addon.qml): after the apps, or first when they say
// so or no app matches.
ListPicker {
  id: launcher
  rowHeight: 44
  rowPadding: 10
  placeholder: ["Search apps"].concat(host.addons.launcherHints).join(" or ")
  emptyText: "No apps match"
  items: host.addons.searchResults(query, results, true, true)
  onChosen: function(entry) { if (entry.addonRow) entry.run(); else launch(entry) }
  onActiveChanged: if (active) hiddenScan.running = true

  // DesktopEntries changes when apps are installed or removed.
  property int appsRevision: 0
  Connections {
    target: DesktopEntries.applications
    function onValuesChanged() { launcher.appsRevision++ }
  }
  readonly property var results: {
    appsRevision; hiddenIds
    var values = DesktopEntries.applications.values || []
    return AppSearch.sortedEntries(values, query, function(entry) { return !!hiddenIds[String(entry.id || "")] })
      .map(function(row) { return row.entry })
  }

  row: Component {
    Item {
      id: appRow
      property var entry: ({})
      property bool selected: false
      readonly property bool isAddon: !!(entry && entry.addonRow)
      // A name ending in a bracketed variant ("Cisco Packet Tracer 9.0.1
      // (PTSA)") shows it after the base name, quieter.
      readonly property string fullName: isAddon ? "" : String(AppSearch.entryName(entry) || "")
      readonly property var variant: fullName.match(/^(.*\S)\s*\(([^()]+)\)$/)

      ClippingRectangle {
        id: iconTile
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 32; height: 32; radius: 8
        // App icons carry their own shape; only glyphs sit on a tile.
        color: appRow.isAddon && appRow.entry.tile ? appRow.entry.tile
          : !appRow.isAddon && appIcon.status === Image.Ready ? "transparent"
          : launcher.host.theme.fill("subtle")
        Text {
          anchors.centerIn: parent
          visible: appRow.isAddon
          text: appRow.isAddon ? appRow.entry.glyph || "" : ""
          color: appRow.isAddon && appRow.entry.ink ? appRow.entry.ink : launcher.host.theme.text
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: launcher.host.theme.px(22)
        }
        Image {
          id: appIcon
          anchors.centerIn: parent
          width: 32; height: 32
          visible: !appRow.isAddon && status === Image.Ready
          source: appRow.isAddon ? "" : IconSource.source(appRow.entry && appRow.entry.icon)
          sourceSize.width: 64
          sourceSize.height: 64
          fillMode: Image.PreserveAspectFit
          asynchronous: true
        }
        Text {
          anchors.centerIn: parent
          visible: !appRow.isAddon && appIcon.status !== Image.Ready
          text: "󰀻"
          color: launcher.host.theme.muted
          font.family: launcher.host.theme.fontFamily
          font.pixelSize: launcher.host.theme.px(18)
        }
      }
      Text {
        anchors.left: iconTile.right
        anchors.leftMargin: 12
        anchors.right: openHint.visible ? openHint.left : parent.right
        anchors.rightMargin: openHint.visible ? 12 : 0
        anchors.verticalCenter: parent.verticalCenter
        visible: !appRow.isAddon
        text: !appRow.variant ? launcher.escaped(appRow.fullName)
          : launcher.escaped(appRow.variant[1]) + "<font color=\"" + launcher.host.theme.secondary + "\"> · " + launcher.escaped(appRow.variant[2]) + "</font>"
        textFormat: Text.StyledText
        elide: Text.ElideRight
        maximumLineCount: 1
        color: launcher.host.theme.text
        font.family: launcher.host.theme.textFontFamily
        font.letterSpacing: launcher.host.theme.tracking(launcher.host.theme.textFontFamily, launcher.host.theme.px(14))
        font.pixelSize: launcher.host.theme.px(14)
      }
      // What Enter does, on the selected app only.
      KeyHint {
        id: openHint
        visible: appRow.selected && !appRow.isAddon
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        theme: launcher.host.theme
        label: "Open"
      }
      // An addon's row: its label and detail, muted, on one line
      // ("Ask Claude" and the question).
      Row {
        anchors.left: iconTile.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: appRow.isAddon
        spacing: 8
        Text {
          id: askLabel
          text: appRow.isAddon ? appRow.entry.label || "" : ""
          color: launcher.host.theme.text
          font.family: launcher.host.theme.textFontFamily
          font.letterSpacing: launcher.host.theme.tracking(launcher.host.theme.textFontFamily, launcher.host.theme.px(14))
          font.pixelSize: launcher.host.theme.px(14)
          font.weight: Font.Medium
        }
        Text {
          width: parent.width - askLabel.width - parent.spacing
          text: appRow.isAddon ? appRow.entry.detail || "" : ""
          textFormat: Text.PlainText
          elide: Text.ElideRight
          color: launcher.host.theme.muted
          font.family: launcher.host.theme.textFontFamily
          font.letterSpacing: launcher.host.theme.tracking(launcher.host.theme.textFontFamily, launcher.host.theme.px(14))
          font.pixelSize: launcher.host.theme.px(14)
        }
      }
    }
  }

  // App names are drawn as styled text (for a variant's grey), so their own
  // markup characters are escaped.
  function escaped(text) {
    return String(text).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
  }

  // ---------- Hidden entries (same sources as Omarchy's AppLibrary) ----------

  readonly property string omarchyPath: Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy"
  property var configuredHidden: ({})
  property var desktopHidden: ({})
  readonly property var hiddenIds: Object.assign({}, configuredHidden, desktopHidden)

  function idSet(raw) {
    var set = {}
    String(raw || "").split(/\n/).forEach(function(line) {
      var id = line.trim().replace(/\.desktop$/, "")
      if (id) set[id] = true
    })
    return set
  }
  FileView {
    path: launcher.omarchyPath + "/default/omarchy/launcher.hides"
    watchChanges: true
    printErrors: false
    onLoaded: launcher.configuredHidden = launcher.idSet(text())
    onFileChanged: reload()
  }
  Process {
    id: hiddenScan
    command: ["bash", launcher.omarchyPath + "/shell/services/hidden-entries.sh",
      [Quickshell.env("XDG_CURRENT_DESKTOP"), Quickshell.env("XDG_SESSION_DESKTOP"), Quickshell.env("DESKTOP_SESSION")]
        .filter(function(v) { return String(v || "").length > 0 }).join(":")]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: launcher.desktopHidden = launcher.idSet(text)
    }
  }
  Component.onCompleted: hiddenScan.running = true

  // ---------- Launching ----------

  Process { id: runner }
  function launch(entry) {
    if (!entry || !entry.id) return
    host.view = "rest"
    // Same as Omarchy: gtk-launch inside a uwsm app scope, keeping the
    // .desktop suffix so ids like org.telegram.desktop resolve.
    runner.command = ["uwsm-app", "--", "gtk-launch", String(entry.id) + ".desktop"]
    runner.startDetached()
  }
}

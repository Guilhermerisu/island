import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../../components"
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
  placeholder: ["Search"].concat(host.addons.launcherHints).join(" or ")
  emptyText: "No apps match"
  items: {
    var text = query.trim()
    if (!text) return results
    var rows = host.addons.launcherRows(text)
    var first = rows.filter(function(row) { return row.first || !results.length })
    var last = rows.filter(function(row) { return first.indexOf(row) === -1 })
    return first.concat(results, last)
  }
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

      ClippingRectangle {
        id: iconTile
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 36; height: 36; radius: 10
        color: appRow.isAddon && appRow.entry.tile ? appRow.entry.tile : launcher.host.theme.withAlpha(launcher.host.theme.text, 0.08)
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
          width: 26; height: 26
          visible: !appRow.isAddon && status === Image.Ready
          source: appRow.isAddon ? "" : launcher.iconSource(appRow.entry && appRow.entry.icon)
          sourceSize.width: 52
          sourceSize.height: 52
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
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: !appRow.isAddon
        text: appRow.isAddon ? "" : AppSearch.entryName(appRow.entry)
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: launcher.host.theme.text
        font.family: launcher.host.theme.textFontFamily
        font.pixelSize: launcher.host.theme.px(14)
        font.weight: Font.DemiBold
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
          font.pixelSize: launcher.host.theme.px(14)
          font.weight: Font.DemiBold
        }
        Text {
          width: parent.width - askLabel.width - parent.spacing
          text: appRow.isAddon ? appRow.entry.detail || "" : ""
          textFormat: Text.PlainText
          elide: Text.ElideRight
          color: launcher.host.theme.muted
          font.family: launcher.host.theme.textFontFamily
          font.pixelSize: launcher.host.theme.px(14)
        }
      }
    }
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

  function iconSource(icon) {
    var value = String(icon || "")
    if (!value) return ""
    if (value.indexOf("file://") === 0 || value.indexOf("image://") === 0) return value
    if (value.charAt(0) === "/") return "file://" + value
    return Quickshell.iconPath(value, true)
  }
}

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
// Omarchy's own launcher ranking, so results match its menu exactly.
import "file:///usr/share/omarchy/shell/services/AppSearch.js" as AppSearch

// Application launcher hosted by the island: a large search field over a list
// of apps (icon tile and name); the selected row gets a soft highlight and an
// accent bar. Search still matches names, descriptions, and keywords. Type to filter, ↑/↓ (or
// Tab, PageUp/PageDown) to move, Enter or a click to launch, Esc to close.
// Uses the same app set as Omarchy's launcher (desktop entries minus its
// hidden lists) and launches the same way.
Item {
  id: launcher
  required property var host

  readonly property bool active: host.view === "apps"
  visible: active || opacity > 0.01
  enabled: active
  opacity: active && host.surfaceContentReady ? 1 : 0
  Behavior on opacity { NumberAnimation { duration: (launcher.host.surfaceContentReady ? 190 : 110) * launcher.host.motionScale; easing.type: Easing.InOutQuad } }

  readonly property int rowHeight: 50
  readonly property int visibleRows: 7
  implicitHeight: header.height + 10 + 1 + 8 + list.height

  property string query: ""
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

  onActiveChanged: {
    if (!active) return
    search.text = ""
    list.currentIndex = 0
    list.positionViewAtBeginning()
    hiddenScan.running = true
    Qt.callLater(function() { search.forceActiveFocus() })
  }
  onQueryChanged: {
    list.currentIndex = 0
    list.positionViewAtBeginning()
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

  function move(delta) {
    if (!results.length) return
    list.currentIndex = Math.max(0, Math.min(results.length - 1, list.currentIndex + delta))
  }

  // ---------- Search ----------

  Item {
    id: header
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: 40

    Text {
      id: searchIcon
      anchors.left: parent.left
      anchors.leftMargin: 6
      anchors.verticalCenter: parent.verticalCenter
      text: "󰍉"
      color: launcher.host.colorMuted
      font.family: launcher.host.fontFamily
      font.pixelSize: 22
    }
    TextInput {
      id: search
      anchors.left: searchIcon.right
      anchors.leftMargin: 12
      anchors.right: parent.right
      anchors.rightMargin: 6
      anchors.verticalCenter: parent.verticalCenter
      color: launcher.host.colorText
      selectionColor: launcher.host.withAlpha(launcher.host.colorAccent, 0.4)
      selectedTextColor: launcher.host.colorText
      font.family: "Adwaita Sans"
      font.pixelSize: 21
      font.weight: Font.Normal
      clip: true
      onTextChanged: launcher.query = text
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Down || (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier))) {
          launcher.move(1); event.accepted = true
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
          launcher.move(-1); event.accepted = true
        } else if (event.key === Qt.Key_PageDown) {
          launcher.move(launcher.visibleRows); event.accepted = true
        } else if (event.key === Qt.Key_PageUp) {
          launcher.move(-launcher.visibleRows); event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          launcher.launch(launcher.results[list.currentIndex]); event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
          launcher.host.view = "rest"; event.accepted = true
        }
      }
      Text {
        anchors.fill: parent
        verticalAlignment: Text.AlignVCenter
        visible: search.text === ""
        text: "Search"
        color: launcher.host.colorMuted
        font: search.font
      }
    }
  }

  Rectangle {
    id: divider
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: header.bottom
    anchors.topMargin: 10
    height: 1
    color: launcher.host.withAlpha(launcher.host.colorText, 0.1)
  }

  // ---------- Results ----------

  ListView {
    id: list
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: divider.bottom
    anchors.topMargin: 8
    height: launcher.rowHeight * launcher.visibleRows
    clip: true
    model: launcher.results
    boundsBehavior: Flickable.StopAtBounds
    keyNavigationEnabled: false
    highlightMoveDuration: 0
    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

    delegate: Item {
      id: row
      required property var modelData
      required property int index
      readonly property bool isSelected: ListView.isCurrentItem
      width: ListView.view.width
      height: launcher.rowHeight

      Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 8
        radius: 12
        color: row.isSelected ? launcher.host.withAlpha(launcher.host.colorText, 0.07) : "transparent"
      }
      // Accent bar marking the selected row.
      Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 3
        height: 22
        radius: 1.5
        color: launcher.host.colorAccent
        visible: row.isSelected
      }

      ClippingRectangle {
        id: iconTile
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        width: 36; height: 36; radius: 10
        color: launcher.host.withAlpha(launcher.host.colorText, 0.08)
        Image {
          id: appIcon
          anchors.centerIn: parent
          width: 26; height: 26
          source: launcher.iconSource(row.modelData.icon)
          sourceSize.width: 52
          sourceSize.height: 52
          fillMode: Image.PreserveAspectFit
          asynchronous: true
          visible: status === Image.Ready
        }
        Text {
          anchors.centerIn: parent
          visible: appIcon.status !== Image.Ready
          text: "󰀻"
          color: launcher.host.colorMuted
          font.family: launcher.host.fontFamily
          font.pixelSize: 18
        }
      }
      Column {
        anchors.left: iconTile.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1
        Text {
          width: parent.width
          text: AppSearch.entryName(row.modelData)
          textFormat: Text.PlainText
          elide: Text.ElideRight
          color: launcher.host.colorText
          font.family: "Adwaita Sans"
          font.pixelSize: 14
          font.weight: Font.DemiBold
        }
      }
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: launcher.launch(row.modelData)
      }
    }

    Text {
      anchors.centerIn: parent
      visible: launcher.results.length === 0
      text: "No apps match"
      color: launcher.host.colorMuted
      font.family: "Adwaita Sans"
      font.pixelSize: 13
    }
  }
}

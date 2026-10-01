import QtQuick
import "../../components"
import QtQuick.Layouts
import "controls"
import "pages"

// The island's own settings, laid out like macOS System Settings: a sidebar
// with search, and a pane of grouped rows. Opened from
// the control center's gear; Esc goes back to it. Changes apply live and are
// saved to ~/.config/omarchy/island.json (see services/IslandSettings.qml).
// Each pane is a page in pages/; the rows and switches are in controls/.
Item {
  id: settingsView
  required property var host
  property bool active: false
  readonly property var settings: host.settings
  property string currentPage: "General"
  property string searchQuery: ""
  readonly property var pages: ["General", "Search", "Live Activities", "Notifications", "Addons", "Keybinds"]
  readonly property var pageInfo: ({
    "General": { icon: "󰒓", color: "#8e8e93", about: "Appearance, motion, and how the pill looks at rest." },
    "Search": { icon: "󰍉", color: "#5e7a99", about: "Get answers to launcher questions right in the island." },
    "Live Activities": { icon: "󰨚", color: "#34c759", about: "Choose what shows up on the pill while it's happening." },
    "Notifications": { icon: "󰂚", color: "#ff3b30", about: "How notification banners appear on the island." },
    "Addons": { icon: "󰐱", color: "#af52de", about: "Extras that stay unloaded until you switch them on." },
    "Keybinds": { icon: "󰌌", color: "#8e8e93", about: "Keyboard shortcuts that open each part of the island." }
  })
  function pageMatches(page) {
    var query = searchQuery.trim().toLowerCase()
    if (query === "") return true
    var terms = {
      "General": "general appearance display shape island style dynamic island colorful sidebar icons colorful live activities theme accent neutral motion animation speed hover lift pill notch style 24-hour clock",
      "Search": "search ask with claude codex launcher answers",
      "Live Activities": "live activities now playing media cover sound wave clipboard downloads system updates battery charging low bluetooth devices volume hud workspace workspaces keyboard layout indicator languages",
      "Notifications": "notifications banner duration",
      "Addons": "addons extensions extras " + host.addons.entries.map(function(addon) {
        return [addon.name, addon.description || ""].concat((addon.options || []).map(function(option) { return option.label || "" })).join(" ")
      }).join(" "),
      "Keybinds": "keybinds keybindings keyboard shortcuts keys"
    }
    return String(terms[page] || page).toLowerCase().indexOf(query) !== -1
  }
  readonly property bool hasSearchResults: {
    var query = searchQuery
    if (query === "") return true
    for (var i = 0; i < pages.length; i++) if (pageMatches(pages[i])) return true
    return false
  }

  readonly property color panel: host.theme.background
  readonly property color text: host.theme.text
  readonly property color textMuted: Qt.tint(panel, host.theme.withAlpha(text, 0.6))
  readonly property color sidebar: Qt.tint(panel, host.theme.withAlpha(text, 0.07))
  readonly property color card: Qt.tint(panel, host.theme.withAlpha(text, 0.075))
  readonly property color well: Qt.tint(panel, host.theme.withAlpha(text, 0.16))
  readonly property color wellHover: Qt.tint(panel, host.theme.withAlpha(text, 0.22))
  readonly property color divider: host.theme.withAlpha(text, 0.09)
  readonly property color accent: host.theme.accent
  readonly property color accentInk: host.theme.accentText

  readonly property int detailFontSize: 15
  readonly property int detailCaptionFontSize: 13
  readonly property int detailTitleFontSize: 19

  // Keep keyboard-focused gallery cards inside the detail pane's viewport.
  function revealSettingsItem(item) {
    var top = item.mapToItem(groups, 0, 0).y
    var bottom = top + item.height
    if (top < scroller.contentY) scroller.contentY = top
    else if (bottom > scroller.contentY + scroller.height)
      scroller.contentY = Math.min(bottom - scroller.height, Math.max(0, scroller.contentHeight - scroller.height))
  }

  implicitHeight: 640
  onActiveChanged: {
    if (active) Qt.callLater(function() { settingsView.forceActiveFocus() })
    else menuButton = null
  }
  onCurrentPageChanged: {
    menuButton = null
    scroller.contentY = 0
  }
  Keys.onEscapePressed: {
    if (menuButton) menuButton = null
    else host.view = "controls"
  }

  // ---------- Window ----------

  RowLayout {
    anchors.fill: parent
    spacing: 10

    // Sidebar: search and the panes.
    Rectangle {
      Layout.preferredWidth: 212
      Layout.fillHeight: true
      radius: 14
      color: settingsView.sidebar
      border.width: 1
      border.color: settingsView.host.theme.withAlpha(settingsView.text, 0.05)
      ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.topMargin: 14
        anchors.bottomMargin: 12
        spacing: 2
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 28
          Layout.bottomMargin: 10
          radius: 7
          color: settingsView.host.theme.withAlpha(settingsView.text, 0.08)
          border.width: searchInput.activeFocus ? 2 : 0
          border.color: settingsView.host.theme.withAlpha(settingsView.accent, 0.6)
          Text {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: "󰍉"
            color: settingsView.textMuted
            font.family: settingsView.host.theme.fontFamily
            font.pixelSize: 14
          }
          Text {
            anchors.left: parent.left
            anchors.leftMargin: 28
            anchors.verticalCenter: parent.verticalCenter
            visible: searchInput.text === ""
            text: "Search"
            color: settingsView.textMuted
            font.family: "Adwaita Sans"
            font.pixelSize: 13
          }
          TextInput {
            id: searchInput
            anchors.left: parent.left
            anchors.leftMargin: 28
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            color: settingsView.text
            font.family: "Adwaita Sans"
            font.pixelSize: 13
            onTextChanged: {
              settingsView.searchQuery = text
              if (text.trim() === "" || settingsView.pageMatches(settingsView.currentPage)) return
              for (var i = 0; i < settingsView.pages.length; i++) {
                if (settingsView.pageMatches(settingsView.pages[i])) {
                  settingsView.currentPage = settingsView.pages[i]
                  break
                }
              }
            }
            Keys.onEscapePressed: function(event) {
              if (text !== "") { text = ""; event.accepted = true }
              else event.accepted = false
            }
          }
        }
        Repeater {
          model: settingsView.pages
          delegate: SidebarItem {
            view: settingsView
            required property string modelData
            title: modelData
          }
        }
        Text {
          visible: settingsView.searchQuery !== "" && !settingsView.hasSearchResults
          text: "No Results"
          color: settingsView.textMuted
          font.family: "Adwaita Sans"
          font.pixelSize: 13
          Layout.alignment: Qt.AlignHCenter
          Layout.topMargin: 18
        }
        Item { Layout.fillHeight: true }
      }
    }

    // Detail pane: the pane's groups, under its header.
    ColumnLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: 6
      Flickable {
        id: scroller
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentHeight: groups.implicitHeight + 16
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
          id: groups
          x: 4
          width: scroller.width - 8
          spacing: 20

          PaneHeader { view: settingsView; page: settingsView.currentPage; Layout.topMargin: 4 }
          GeneralPage { view: settingsView }
          SearchPage { view: settingsView }
          ActivitiesPage { view: settingsView }
          NotificationsPage { view: settingsView }
          AddonsPage { view: settingsView }
          KeybindsPage { view: settingsView }
        }
      }
    }
  }

  // ---------- Pop-up menu ----------

  // The open pop-up button; its choices show in popMenu, under it.
  property Item menuButton: null
  property var menuOptions: []
  property var menuValue
  FontMetrics { id: menuFont; font.family: "Adwaita Sans"; font.pixelSize: settingsView.detailFontSize }
  function openMenu(button) {
    var widest = 0
    for (var i = 0; i < button.options.length; i++) widest = Math.max(widest, menuFont.advanceWidth(button.options[i].label))
    menuOptions = button.options
    menuValue = button.value
    popMenu.width = Math.max(button.width, Math.ceil(widest) + 52)
    popMenu.height = button.options.length * 28 + 10
    var p = button.mapToItem(settingsView, 0, 0)
    popMenu.x = Math.max(4, p.x + button.width - popMenu.width)
    var below = p.y + button.height + 4
    popMenu.y = below + popMenu.height <= height - 4 ? below : p.y - popMenu.height - 4
    menuButton = button
  }
  MouseArea {
    anchors.fill: parent
    z: 49
    visible: settingsView.menuButton !== null
    onClicked: settingsView.menuButton = null
    onWheel: function(wheel) { settingsView.menuButton = null }
  }
  Rectangle {
    id: popMenu
    z: 50
    visible: opacity > 0.01
    enabled: !!settingsView.menuButton
    opacity: settingsView.menuButton ? 1 : 0
    scale: settingsView.menuButton ? 1 : 0.96
    transformOrigin: Item.Top
    Behavior on opacity { MotionAnimation { theme: settingsView.host.theme; pace: settingsView.menuButton ? "fade" : "exit"; curve: "fade" } }
    Behavior on scale { MotionAnimation { theme: settingsView.host.theme; pace: settingsView.menuButton ? "standard" : "exit" } }
    radius: 9
    color: Qt.tint(settingsView.panel, settingsView.host.theme.withAlpha(settingsView.text, 0.13))
    border.width: 1
    border.color: settingsView.host.theme.withAlpha(settingsView.text, 0.1)
    Column {
      id: menuColumn
      x: 5
      y: 5
      width: parent.width - 10
      Repeater {
        model: settingsView.menuOptions
        delegate: Rectangle {
          id: menuItem
          required property var modelData
          readonly property bool chosen: settingsView.menuValue === modelData.value
          width: menuColumn.width
          height: 28
          radius: 5
          color: itemMouse.containsMouse ? settingsView.accent : "transparent"
          Text {
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            visible: menuItem.chosen
            text: "󰄬"
            color: itemMouse.containsMouse ? settingsView.accentInk : settingsView.text
            font.family: settingsView.host.theme.fontFamily
            font.pixelSize: 12
          }
          Text {
            id: menuText
            x: 26
            anchors.verticalCenter: parent.verticalCenter
            text: menuItem.modelData.label
            color: itemMouse.containsMouse ? settingsView.accentInk : settingsView.text
            font.family: "Adwaita Sans"
            font.pixelSize: settingsView.detailFontSize
          }
          MouseArea {
            id: itemMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              var button = settingsView.menuButton
              settingsView.menuButton = null
              if (button) button.picked(menuItem.modelData.value)
            }
          }
        }
      }
    }
  }
}

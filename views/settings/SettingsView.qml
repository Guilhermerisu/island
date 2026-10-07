import QtQuick
import Quickshell.Io
import "../../components"
import QtQuick.Layouts
import "controls"
import "pages"

Item {
  id: settingsView
  required property var host
  property bool active: false
  readonly property var settings: host.settings
  property string currentPage: "General"
  // The shortcuts, for the Addons page's rows too.
  readonly property var keybinds: keybindsPage
  property string searchQuery: ""
  // The core panes, with the enabled addons' own (see addons/Addon.qml)
  // after Addons.
  readonly property var addonPages: host.addons.settingsPages
  readonly property var pages: ["General", "Search", "Live Activities", "Notifications", "Addons"]
    .concat(addonPages.map(function(page) { return page.title }), ["Keybinds"])
  onPagesChanged: if (pages.indexOf(currentPage) === -1) currentPage = "General"
  readonly property var pageInfo: {
    var info = Object.assign({}, corePageInfo)
    for (var i = 0; i < addonPages.length; i++)
      info[addonPages[i].title] = { icon: addonPages[i].icon, color: addonPages[i].color, layers: addonPages[i].iconLayers || [], about: addonPages[i].about || "" }
    return info
  }
  readonly property var corePageInfo: ({
    "General": { icon: "󰒓", color: "#8e8e93", about: "Appearance, motion, and how the pill looks at rest." },
    "Search": { icon: "󰍉", color: "#5e7a99", about: "Get answers to launcher questions right in the island." },
    "Live Activities": { icon: "󰨚", color: "#34c759", about: "Choose what shows up on the pill while it's happening." },
    "Notifications": { icon: "󰂚", color: "#ff3b30", about: "How notification banners appear on the island." },
    "Addons": { icon: "󰄐", color: "#0a84ff", about: "Extras that stay unloaded until you add them." },
    "Keybinds": { icon: "󰌌", color: "#8e8e93", about: "Keyboard shortcuts that open each part of the island." }
  })
  function pageMatches(page) {
    var query = searchQuery.trim().toLowerCase()
    if (query === "") return true
    var terms = {
      "General": "general appearance display shape island style dynamic island colorful sidebar icons colorful live activities theme accent neutral motion animation speed hover lift pill notch style 24-hour clock",
      "Search": "search ask with claude codex launcher answers",
      "Live Activities": "live activities now playing media cover sound wave clipboard downloads system updates battery charging low bluetooth devices volume hud workspace workspaces indicator",
      "Notifications": "notifications banner duration",
      "Addons": "addons extensions extras store cart add remove " + host.addons.entries.map(function(addon) {
        return [addon.name, addon.description || ""].concat((addon.options || []).map(function(option) { return option.label || "" })).join(" ")
      }).join(" "),
      "Keybinds": "keybinds keybindings keyboard shortcuts keys"
    }
    var addonPage = host.addons.settingsPage(page)
    if (addonPage) terms[page] = page + " " + (addonPage.search || "")
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

  readonly property int detailFontSize: host.theme.px(15)
  readonly property int detailCaptionFontSize: host.theme.px(13)
  readonly property int detailTitleFontSize: host.theme.px(19)

  function revealSettingsItem(item) {
    var top = item.mapToItem(groups, 0, 0).y
    var bottom = top + item.height
    if (top < scroller.contentY) scroller.contentY = top
    else if (bottom > scroller.contentY + scroller.height)
      scroller.contentY = Math.min(bottom - scroller.height, Math.max(0, scroller.contentHeight - scroller.height))
  }

  implicitHeight: 640
  onActiveChanged: {
    if (active && host.settingsPage !== "") {
      currentPage = host.settingsPage
      host.settingsPage = ""
    }
    if (active) Qt.callLater(function() { settingsView.forceActiveFocus() })
    else menuButton = null
  }
  onCurrentPageChanged: {
    menuButton = null
    scroller.contentY = 0
  }
  Keys.onEscapePressed: {
    if (fontPickerButton) fontPickerButton = null
    else if (menuButton) menuButton = null
    else host.view = "controls"
  }

  RowLayout {
    anchors.fill: parent
    spacing: 10

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
            font.pixelSize: settingsView.host.theme.px(14)
          }
          Text {
            anchors.left: parent.left
            anchors.leftMargin: 28
            anchors.verticalCenter: parent.verticalCenter
            visible: searchInput.text === ""
            text: "Search"
            color: settingsView.textMuted
            font.family: settingsView.host.theme.textFontFamily
            font.pixelSize: settingsView.host.theme.px(13)
          }
          TextInput {
            id: searchInput
            anchors.left: parent.left
            anchors.leftMargin: 28
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            color: settingsView.text
            font.family: settingsView.host.theme.textFontFamily
            font.pixelSize: settingsView.host.theme.px(13)
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
          font.family: settingsView.host.theme.textFontFamily
          font.pixelSize: settingsView.host.theme.px(13)
          Layout.alignment: Qt.AlignHCenter
          Layout.topMargin: 18
        }
        Item { Layout.fillHeight: true }
      }
    }

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
          // By count: addonPages is rebuilt whenever any addon loads, and a
          // new array as the model would recreate the open page.
          Repeater {
            model: settingsView.addonPages.length
            delegate: Loader {
              id: addonPage
              required property int index
              readonly property var modelData: settingsView.addonPages[index] || ({})
              readonly property bool shown: settingsView.currentPage === modelData.title
              visible: shown
              Layout.fillWidth: true
              Layout.preferredHeight: item ? item.implicitHeight : 0
              onShownChanged: load()
              Component.onCompleted: load()
              function load() {
                if (!shown) { source = ""; return }
                setSource(modelData.source, Object.assign({ view: settingsView }, modelData.properties || {}))
              }
              Binding { target: addonPage.item; property: "shown"; value: addonPage.shown && settingsView.active; when: addonPage.item !== null }
            }
          }
          KeybindsPage { id: keybindsPage; view: settingsView }
        }
      }
    }
  }

  property Item menuButton: null
  property var menuOptions: []
  property var menuValue
  FontMetrics { id: menuFont; font.family: settingsView.host.theme.textFontFamily; font.pixelSize: settingsView.detailFontSize }
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
    visible: settingsView.menuButton !== null || settingsView.fontPickerButton !== null
    onClicked: {
      settingsView.menuButton = null
      settingsView.fontPickerButton = null
    }
    onWheel: function(wheel) {
      settingsView.menuButton = null
      settingsView.fontPickerButton = null
    }
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
            font.pixelSize: settingsView.host.theme.px(12)
          }
          Text {
            id: menuText
            x: 26
            anchors.verticalCenter: parent.verticalCenter
            text: menuItem.modelData.label
            color: itemMouse.containsMouse ? settingsView.accentInk : settingsView.text
            font.family: settingsView.host.theme.textFontFamily
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

  // ---------- Font picker ----------
  //
  // The custom font row opens a searchable list of every installed family;
  // typing a family name from memory is guesswork.

  property Item fontPickerButton: null
  property var fontList: []
  property string fontQuery: ""
  property int fontCursor: 0

  Process {
    command: ["bash", "-c", "fc-list : -f '%{family[0]}\\n' | grep -v -iE 'emoji|signwriting' | sort -u"]
    running: true
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: settingsView.fontList = String(text || "").split("\n").filter(function(f) { return f.trim() !== "" })
    }
  }
  readonly property var filteredFonts: {
    var q = settingsView.fontQuery.trim().toLowerCase()
    if (q === "") return settingsView.fontList
    return settingsView.fontList.filter(function(f) { return f.toLowerCase().indexOf(q) !== -1 })
  }
  function openFontPicker(button) {
    fontQuery = ""
    fontCursor = 0
    fontPickerButton = button
    var p = button.mapToItem(settingsView, 0, 0)
    fontPanel.x = Math.max(4, Math.min(settingsView.width - fontPanel.width - 4, p.x + button.width - fontPanel.width))
    var below = p.y + button.height + 4
    fontPanel.y = below + fontPanel.height <= settingsView.height - 4 ? below : Math.max(4, p.y - fontPanel.height - 4)
    Qt.callLater(function() { fontInput.forceActiveFocus() })
  }
  function pickFont(font) {
    if (!font) return
    settingsView.settings.customFont = font
    settingsView.settings.textFontMode = "custom"
    settingsView.fontPickerButton = null
  }

  Rectangle {
    id: fontPanel
    z: 51
    visible: opacity > 0.01
    enabled: !!settingsView.fontPickerButton
    opacity: settingsView.fontPickerButton ? 1 : 0
    scale: settingsView.fontPickerButton ? 1 : 0.96
    transformOrigin: Item.Top
    Behavior on opacity { MotionAnimation { theme: settingsView.host.theme; pace: settingsView.fontPickerButton ? "fade" : "exit"; curve: "fade" } }
    Behavior on scale { MotionAnimation { theme: settingsView.host.theme; pace: settingsView.fontPickerButton ? "standard" : "exit" } }
    width: 264
    height: fontSearch.height + 10 + Math.max(1, Math.min(9, settingsView.filteredFonts.length)) * 26 + 10
    radius: 9
    color: Qt.tint(settingsView.panel, settingsView.host.theme.withAlpha(settingsView.text, 0.13))
    border.width: 1
    border.color: settingsView.host.theme.withAlpha(settingsView.text, 0.1)

    Rectangle {
      id: fontSearch
      x: 5
      y: 5
      width: parent.width - 10
      height: 28
      radius: 5
      color: settingsView.host.theme.withAlpha(settingsView.text, 0.08)
      border.width: fontInput.activeFocus ? 2 : 0
      border.color: settingsView.host.theme.withAlpha(settingsView.accent, 0.6)
      Text {
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: "󰍉"
        color: settingsView.textMuted
        font.family: settingsView.host.theme.fontFamily
        font.pixelSize: settingsView.host.theme.px(13)
      }
      Text {
        anchors.left: parent.left
        anchors.leftMargin: 28
        anchors.verticalCenter: parent.verticalCenter
        visible: fontInput.text === ""
        text: "Search fonts"
        color: settingsView.textMuted
        font.family: settingsView.host.theme.textFontFamily
        font.pixelSize: settingsView.detailFontSize - 1
      }
      TextInput {
        id: fontInput
        anchors.left: parent.left
        anchors.leftMargin: 28
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        color: settingsView.text
        selectionColor: settingsView.accent
        selectedTextColor: settingsView.accentInk
        font.family: settingsView.host.theme.textFontFamily
        font.pixelSize: settingsView.detailFontSize - 1
        onTextChanged: { settingsView.fontQuery = text; settingsView.fontCursor = 0 }
        Keys.onDownPressed: function(event) { settingsView.fontCursor = Math.min(settingsView.filteredFonts.length - 1, settingsView.fontCursor + 1); event.accepted = true }
        Keys.onUpPressed: function(event) { settingsView.fontCursor = Math.max(0, settingsView.fontCursor - 1); event.accepted = true }
        Keys.onEscapePressed: function(event) { settingsView.fontPickerButton = null; event.accepted = true }
        Keys.onReturnPressed: function(event) { settingsView.pickFont(settingsView.filteredFonts[settingsView.fontCursor]); event.accepted = true }
        Keys.onEnterPressed: function(event) { settingsView.pickFont(settingsView.filteredFonts[settingsView.fontCursor]); event.accepted = true }
      }
    }

    ListView {
      id: fontRows
      x: 5
      y: fontSearch.y + fontSearch.height + 5
      width: parent.width - 10
      height: parent.height - y - 5
      clip: true
      model: settingsView.filteredFonts
      boundsBehavior: Flickable.StopAtBounds
      keyNavigationEnabled: false
      onCountChanged: if (count > 0) positionViewAtIndex(Math.min(settingsView.fontCursor, count - 1), ListView.Contain)
      MouseArea {
        anchors.fill: parent
        onWheel: function(wheel) { fontRows.flick(0, wheel.angleDelta.y * 2) }
      }
      delegate: Rectangle {
        id: fontRow
        required property string modelData
        required property int index
        readonly property bool chosen: modelData === settingsView.settings.customFont
        readonly property bool current: index === settingsView.fontCursor
        width: fontRows.width
        height: 26
        radius: 5
        color: fontMouse.containsMouse || fontRow.current ? settingsView.accent : "transparent"
        Text {
          x: 8
          anchors.verticalCenter: parent.verticalCenter
          visible: fontRow.chosen
          text: "󰄬"
          color: fontMouse.containsMouse || fontRow.current ? settingsView.accentInk : settingsView.text
          font.family: settingsView.host.theme.fontFamily
          font.pixelSize: settingsView.host.theme.px(12)
        }
        Text {
          x: 26
          anchors.right: parent.right
          anchors.rightMargin: 8
          anchors.verticalCenter: parent.verticalCenter
          text: fontRow.modelData
          elide: Text.ElideRight
          color: fontMouse.containsMouse || fontRow.current ? settingsView.accentInk : settingsView.text
          font.family: settingsView.host.theme.textFontFamily
          font.pixelSize: settingsView.detailFontSize
        }
        MouseArea {
          id: fontMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onEntered: settingsView.fontCursor = fontRow.index
          onClicked: settingsView.pickFont(fontRow.modelData)
        }
      }
      Text {
        anchors.centerIn: parent
        visible: settingsView.filteredFonts.length === 0
        text: "No fonts match"
        color: settingsView.textMuted
        font.family: settingsView.host.theme.textFontFamily
        font.pixelSize: settingsView.detailFontSize - 2
      }
    }
  }
}

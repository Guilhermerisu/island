import QtQuick
import Quickshell.Io
import "../../components"
import QtQuick.Layouts
import QtQuick.Effects
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
  readonly property var pages: ["General", "Live Activities", "Notifications", "Addons"]
    .concat(addonPages.map(function(page) { return page.title }), ["Keybinds"])
  onPagesChanged: if (pages.indexOf(currentPage) === -1) currentPage = "General"
  readonly property var pageInfo: {
    var info = Object.assign({}, corePageInfo)
    for (var i = 0; i < addonPages.length; i++)
      info[addonPages[i].title] = { icon: addonPages[i].icon, color: addonPages[i].color, layers: addonPages[i].iconLayers || [], about: addonPages[i].about || "", header: addonPages[i].header !== false }
    return info
  }
  readonly property var corePageInfo: ({
    "General": { icon: "󰒓", color: settingsView.host.theme.system.gray, about: "Appearance, motion, and how the pill looks at rest." },
    "Live Activities": { icon: "󰨚", color: "#34c759", about: "Choose what shows up on the pill while it's happening." },
    "Notifications": { icon: "󰂚", color: "#ff3b30", about: "How notification banners appear on the island." },
    "Addons": { icon: "󰄐", color: settingsView.host.theme.system.blue, about: "Extras that stay unloaded until you add them." },
    "Keybinds": { icon: "󰌌", color: settingsView.host.theme.system.gray, about: "Keyboard shortcuts that open each part of the island." }
  })
  function pageMatches(page) {
    var query = searchQuery.trim().toLowerCase()
    if (query === "") return true
    var terms = {
      "General": "general appearance display shape island style dynamic island colorful sidebar icons colorful live activities theme accent neutral motion animation speed hover lift pill notch style 24-hour clock am pm format date day weekday font typography text size custom autohide hide fullscreen tiling tile",
      "Live Activities": "live activities now playing media cover sound wave play pause playback track clipboard downloads screen recording record system updates battery charging low bluetooth devices network wifi ethernet volume brightness hud osd workspace workspaces indicator",
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
  readonly property color textMuted: host.theme.secondary
  readonly property color sidebar: host.theme.card
  readonly property color card: host.theme.card
  readonly property color well: host.theme.well
  readonly property color wellHover: host.theme.wellHover
  readonly property color divider: host.theme.hairline
  readonly property color edge: host.theme.hairline
  readonly property color accent: host.theme.accent
  readonly property color accentInk: host.theme.accentText

  readonly property int detailFontSize: host.theme.px(13)
  readonly property int detailCaptionFontSize: host.theme.px(11)
  readonly property int detailTitleFontSize: host.theme.px(22)

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
    else closePopups()
  }
  // A pane asked for while Settings is open (an addon's shortcut): go to it,
  // or close Settings when it's already the one showing.
  Connections {
    target: settingsView.host
    function onSettingsPageChanged() {
      if (!settingsView.active || settingsView.host.settingsPage === "") return
      if (settingsView.host.settingsPage === settingsView.currentPage) settingsView.host.view = "rest"
      else settingsView.currentPage = settingsView.host.settingsPage
      settingsView.host.settingsPage = ""
    }
  }
  onCurrentPageChanged: {
    closePopups()
    scroller.contentY = 0
  }
  Keys.onEscapePressed: {
    if (menuButton || fontPickerButton) closePopups()
    else host.view = "controls"
  }
  // The pop-up menu and the font picker share one scrim and close together.
  function closePopups() {
    menuButton = null
    fontPickerButton = null
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
      border.color: settingsView.edge
      // One highlight for the open pane that glides between the rows.
      Rectangle {
        readonly property Item at: sidebarItems.itemAt(settingsView.pages.indexOf(settingsView.currentPage))
        visible: !!at && at.visible
        x: sidebarColumn.x + (at ? at.x : 0)
        y: sidebarColumn.y + (at ? at.y : 0)
        width: at ? at.width : 0
        height: at ? at.height : 0
        radius: 8
        color: settingsView.host.theme.fill("raised")
        Behavior on y { MotionAnimation { theme: settingsView.host.theme; pace: "quick" } }
      }
      ColumnLayout {
        id: sidebarColumn
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.topMargin: 12
        anchors.bottomMargin: 12
        spacing: 1
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 28
          Layout.bottomMargin: 10
          radius: height / 2
          color: settingsView.host.theme.fill("subtle")
          border.width: searchInput.activeFocus ? 2 : 0
          border.color: settingsView.host.theme.accentFill("ring")
          Text {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: "󰍉"
            color: settingsView.textMuted
            font.family: settingsView.host.theme.fontFamily
            font.pixelSize: settingsView.host.theme.px(14)
          }
          Text {
            anchors.left: parent.left
            anchors.leftMargin: 30
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
            anchors.leftMargin: 30
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
          id: sidebarItems
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
        OverlayScrollbar { flickable: scroller; parent: scroller; theme: settingsView.host.theme }
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentHeight: groups.implicitHeight + 28
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
          id: groups
          x: 4
          width: scroller.width - 8
          spacing: 20

          PaneHeader { view: settingsView; page: settingsView.currentPage }
          GeneralPage { view: settingsView }
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
      // Soft edges where the page runs on above or below.
      Repeater {
        model: [
          { top: true, shown: scroller.contentY > 1 },
          { top: false, shown: scroller.contentY < scroller.contentHeight - scroller.height - 1 }
        ]
        delegate: Rectangle {
          required property var modelData
          parent: scroller
          z: 1
          anchors.left: parent.left
          anchors.right: parent.right
          y: modelData.top ? 0 : scroller.height - height
          height: 24
          opacity: modelData.shown ? 1 : 0
          Behavior on opacity { MotionAnimation { theme: settingsView.host.theme; pace: "fade"; curve: "fade" } }
          gradient: Gradient {
            GradientStop { position: 0; color: modelData.top ? settingsView.panel : "transparent" }
            GradientStop { position: 1; color: modelData.top ? "transparent" : settingsView.panel }
          }
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
    // As macOS's pop-up menus: the current choice opens over the button.
    var chosen = 0
    for (var j = 0; j < button.options.length; j++) if (button.options[j].value === button.value) chosen = j
    var y = p.y + (button.height - 28) / 2 - 5 - chosen * 28
    popMenu.y = Math.max(4, Math.min(height - popMenu.height - 4, y))
    menuButton = button
  }
  MouseArea {
    anchors.fill: parent
    z: 49
    visible: settingsView.menuButton !== null || settingsView.fontPickerButton !== null
    onClicked: settingsView.closePopups()
    onWheel: function(wheel) { settingsView.closePopups() }
  }
  Rectangle {
    id: popMenu
    z: 50
    visible: opacity > 0.01
    enabled: !!settingsView.menuButton
    opacity: settingsView.menuButton ? 1 : 0
    scale: settingsView.menuButton ? 1 : 0.96
    transformOrigin: Item.Center
    Behavior on opacity { MotionAnimation { theme: settingsView.host.theme; pace: settingsView.menuButton ? "fade" : "exit"; curve: "fade" } }
    Behavior on scale { MotionAnimation { theme: settingsView.host.theme; pace: settingsView.menuButton ? "standard" : "exit" } }
    radius: 10
    color: settingsView.host.theme.solid("raised")
    border.width: 1
    border.color: settingsView.host.theme.fill("raised")
    layer.enabled: visible
    layer.effect: MultiEffect {
      shadowEnabled: true
      shadowColor: Qt.rgba(0, 0, 0, 0.5)
      shadowBlur: 0.8
      shadowVerticalOffset: 6
    }
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
          radius: settingsView.host.theme.radii.small
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
    // Rows grow with the text size, from 26 at the default.
    readonly property int rowHeight: Math.max(26, settingsView.detailFontSize + 11)
    width: 264
    height: fontSearch.height + 10 + Math.max(1, Math.min(9, settingsView.filteredFonts.length)) * fontPanel.rowHeight + 10
    radius: 10
    color: settingsView.host.theme.solid("raised")
    border.width: 1
    border.color: settingsView.host.theme.fill("raised")
    layer.enabled: visible
    layer.effect: MultiEffect {
      shadowEnabled: true
      shadowColor: Qt.rgba(0, 0, 0, 0.5)
      shadowBlur: 0.8
      shadowVerticalOffset: 6
    }

    Rectangle {
      id: fontSearch
      x: 5
      y: 5
      width: parent.width - 10
      height: Math.max(28, settingsView.detailFontSize + 13)
      radius: settingsView.host.theme.radii.small
      color: settingsView.host.theme.fill("subtle")
      border.width: fontInput.activeFocus ? 2 : 0
      border.color: settingsView.host.theme.accentFill("ring")
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
        font.pixelSize: settingsView.detailFontSize
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
        font.pixelSize: settingsView.detailFontSize
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
      OverlayScrollbar { flickable: fontRows; parent: fontRows; theme: settingsView.host.theme }
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
        height: fontPanel.rowHeight
        radius: settingsView.host.theme.radii.small
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
          anchors.left: parent.left
          anchors.leftMargin: 26
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
        font.pixelSize: settingsView.host.theme.px(12)
      }
    }
  }
}

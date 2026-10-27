import QtQuick
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
  readonly property var pages: ["General", "Live Activities", "Notifications", "Addons"]
    .concat(addonPages.map(function(page) { return page.title }), ["Keybinds"])
  onPagesChanged: if (pages.indexOf(currentPage) === -1) currentPage = "General"
  readonly property var pageInfo: {
    var info = Object.assign({}, corePageInfo)
    for (var i = 0; i < addonPages.length; i++) {
      var flat = flatAddonIcons[addonPages[i].title] || {}
      info[addonPages[i].title] = { icon: flat.icon || addonPages[i].icon, color: flat.color || addonPages[i].color, layers: addonPages[i].iconLayers || [], about: addonPages[i].about || "", header: addonPages[i].header !== false }
    }
    return info
  }
  // Settings draws its pane icons flat (see PaneIcon); an addon pane whose
  // own icon only reads drawn in layers gets a line glyph and colour here.
  readonly property var flatAddonIcons: ({
    "System Stats": { icon: "󰺢", color: "#8b5cf6" },
    "Displays": { icon: "󰍹", color: "#0ea5e9" }
  })
  readonly property var corePageInfo: ({
    "General": { icon: "󰢻", color: settingsView.host.theme.system.gray, about: "Appearance, motion, and how the pill looks at rest." },
    "Live Activities": { icon: "󰨚", color: "#34c759", about: "Choose what shows up on the pill while it's happening." },
    "Notifications": { icon: "󰂜", color: "#ff3b30", about: "How notification banners appear on the island." },
    "Addons": { icon: "󰐕", color: settingsView.host.theme.system.blue, about: "Extras that stay unloaded until you add them." },
    "Keybinds": { icon: "󰥻", color: settingsView.host.theme.system.gray, about: "Keyboard shortcuts that open each part of the island." }
  })
  function pageMatches(page) {
    var query = searchQuery.trim().toLowerCase()
    if (query === "") return true
    var terms = {
      "General": "general time format 12-hour clock style hide automatically appearance display shape island style dynamic island colorful sidebar icons colorful live activities theme accent neutral motion animation speed pill notch style 24-hour clock am pm format date day weekday font typography text size custom autohide hide fullscreen tiling tile omarchy menu search apps applications",
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
  // A pane title's exact weight on Adwaita Sans's weight axis, set with
  // font.weight: Font.Bold (the fallback for fonts without the axis).
  readonly property var titleFontAxes: ({ "wght": 500 })
  // The narrowest a row's pop-up or segmented control gets, so the controls
  // down the right of a group line up on both edges.
  readonly property int controlWidth: 156

  function revealSettingsItem(item) {
    var top = item.mapToItem(groups, 0, 0).y
    var bottom = top + item.height
    if (top < scroller.contentY) scroller.contentY = top
    else if (bottom > scroller.contentY + scroller.height)
      scroller.contentY = Math.min(bottom - scroller.height, Math.max(0, scroller.contentHeight - scroller.height))
  }

  implicitHeight: 672
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
    if (active) pageIn.restart()
  }
  // A new pane settles in: up a few pixels as it fades in, as System
  // Settings' panes do, instead of the old one swapping out in place.
  ParallelAnimation {
    id: pageIn
    MotionAnimation { theme: settingsView.host.theme; target: groups; property: "opacity"; from: 0; to: 1; pace: "fade"; curve: "fade" }
    MotionAnimation { theme: settingsView.host.theme; target: groupsShift; property: "y"; from: 6; to: 0; pace: "standard" }
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
    spacing: 0

    // The sidebar runs to the island's edge in a lighter grey of its own.
    // Its outer corners follow the open island's (30, square on top in
    // notch style).
    Rectangle {
      Layout.preferredWidth: 220
      Layout.fillHeight: true
      color: settingsView.host.theme.fill("subtle")
      topLeftRadius: settingsView.settings.notch ? 0 : 30
      bottomLeftRadius: 30
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
        anchors.leftMargin: 12
        anchors.rightMargin: 13
        anchors.topMargin: 16
        anchors.bottomMargin: 16
        spacing: 2
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 30
          Layout.bottomMargin: 12
          radius: settingsView.host.theme.radii.medium
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
            font.letterSpacing: settingsView.host.theme.tracking(settingsView.host.theme.textFontFamily, settingsView.host.theme.px(13))
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
            font.letterSpacing: settingsView.host.theme.tracking(settingsView.host.theme.textFontFamily, settingsView.host.theme.px(13))
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
          font.letterSpacing: settingsView.host.theme.tracking(settingsView.host.theme.textFontFamily, settingsView.host.theme.px(13))
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
      Layout.leftMargin: 12
      Layout.rightMargin: 12
      Layout.topMargin: 12
      Layout.bottomMargin: 4
      spacing: 6
      Flickable {
        id: scroller
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
          transform: Translate { id: groupsShift }

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
      // Soft edges where the page runs on above or below. A fixed model, so
      // scrolling only changes the opacity (and the fade runs) instead of
      // rebuilding the edges.
      Repeater {
        model: 2
        delegate: Rectangle {
          required property int index
          readonly property bool upper: index === 0
          parent: scroller
          z: 1
          anchors.left: parent.left
          anchors.right: parent.right
          y: upper ? 0 : scroller.height - height
          height: 24
          opacity: (upper ? scroller.contentY > 1 : scroller.contentY < scroller.contentHeight - scroller.height - 1) ? 1 : 0
          Behavior on opacity { MotionAnimation { theme: settingsView.host.theme; pace: "fade"; curve: "fade" } }
          gradient: Gradient {
            GradientStop { position: 0; color: upper ? settingsView.panel : "transparent" }
            GradientStop { position: 1; color: upper ? "transparent" : settingsView.panel }
          }
        }
      }
    }
  }

  // ---------- Pop-ups ----------

  property alias menuButton: popMenu.button
  function openMenu(button) { popMenu.openFor(button) }
  property alias fontPickerButton: fontPanel.button
  function openFontPicker(button) { fontPanel.openFor(button) }
  MouseArea {
    anchors.fill: parent
    z: 49
    visible: settingsView.menuButton !== null || settingsView.fontPickerButton !== null
    onClicked: settingsView.closePopups()
    onWheel: function(wheel) { settingsView.closePopups() }
  }
  SettingsMenu { id: popMenu; view: settingsView }
  SettingsFontPanel { id: fontPanel; view: settingsView }
}

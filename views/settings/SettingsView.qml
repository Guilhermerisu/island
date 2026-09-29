import QtQuick
import QtQuick.Layouts
import Quickshell.Io

// The island's own settings, laid out like macOS System Settings: a sidebar
// with search, and a pane of grouped rows. Opened from
// the control center's gear; Esc goes back to it. Changes apply live and are
// saved to ~/.config/omarchy/island.json (see Island.qml).
Item {
  id: settingsView
  required property var host
  property bool active: false
  readonly property var settings: host.settings
  property string currentPage: "General"
  property string searchQuery: ""
  readonly property var pages: ["General", "Search", "Live Activities", "Notifications", "Keybinds"]
  readonly property var pageInfo: ({
    "General": { icon: "󰒓", color: "#8e8e93", about: "Appearance, motion, and how the pill looks at rest." },
    "Search": { icon: "󰍉", color: "#5e7a99", about: "Get answers to launcher questions right in the island." },
    "Live Activities": { icon: "󰨚", color: "#34c759", about: "Choose what shows up on the pill while it's happening." },
    "Notifications": { icon: "󰂚", color: "#ff3b30", about: "How notification banners appear on the island." },
    "Keybinds": { icon: "󰌌", color: "#8e8e93", about: "Keyboard shortcuts that open each part of the island." }
  })
  function pageMatches(page) {
    var query = searchQuery.trim().toLowerCase()
    if (query === "") return true
    var terms = {
      "General": "general appearance colorful sidebar icons neutral motion animation speed hover lift pill notch style 24-hour clock volume hud workspace workspaces",
      "Search": "search ask with claude codex launcher answers",
      "Live Activities": "live activities now playing media cover sound wave clipboard downloads system updates battery charging low bluetooth devices",
      "Notifications": "notifications banner duration",
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

  readonly property color panel: host.colorBackground
  readonly property color text: host.colorText
  readonly property color textMuted: Qt.tint(panel, host.withAlpha(text, 0.6))
  readonly property color sidebar: Qt.tint(panel, host.withAlpha(text, 0.07))
  readonly property color card: Qt.tint(panel, host.withAlpha(text, 0.075))
  readonly property color well: Qt.tint(panel, host.withAlpha(text, 0.16))
  readonly property color wellHover: Qt.tint(panel, host.withAlpha(text, 0.22))
  readonly property color divider: host.withAlpha(text, 0.09)
  readonly property color accent: host.colorAccent
  readonly property color accentInk: host.colorAccentText
  readonly property int animDuration: 180 * host.motionScale

  implicitHeight: 640
  onActiveChanged: {
    if (active) Qt.callLater(function() { settingsView.forceActiveFocus() })
    else { stopRecording(); menuButton = null }
    if (active && currentPage === "Keybinds") { shortcutList.running = true; boundList.running = true }
  }
  onCurrentPageChanged: {
    stopRecording()
    cancelPending()
    menuButton = null
    scroller.contentY = 0
    if (currentPage === "Keybinds") { shortcutList.running = true; boundList.running = true }
  }
  Component.onDestruction: if (recordingId !== "") submapReset.running = true
  Keys.onEscapePressed: {
    if (menuButton) menuButton = null
    else host.view = "controls"
  }




  // ---------- Controls ----------

  // The small switch System Settings uses in its lists.
  component SettingsSwitch: Rectangle {
    id: sw
    property bool checked: false
    signal toggled(bool checked)
    implicitWidth: 34
    implicitHeight: 20
    radius: 10
    color: checked ? settingsView.accent : settingsView.well
    Behavior on color { ColorAnimation { duration: settingsView.animDuration; easing.type: Easing.OutCubic } }
    Rectangle {
      width: 16; height: 16; radius: 8
      y: 2
      x: sw.checked ? sw.width - width - 2 : 2
      color: "#ffffff"
      border.width: 1
      border.color: Qt.rgba(0, 0, 0, 0.12)
      Behavior on x { NumberAnimation { duration: settingsView.animDuration; easing.type: Easing.OutCubic } }
    }
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: sw.toggled(!sw.checked)
    }
  }

  // Pop-up button: the current choice with up/down chevrons; the choices open
  // in a menu (see popMenu below).
  component SettingsPopUp: Rectangle {
    id: pop
    property var options: []   // [{ label, value }]
    property var value
    signal picked(var value)
    readonly property string currentLabel: {
      for (var i = 0; i < options.length; i++) if (options[i].value === value) return options[i].label
      return ""
    }
    readonly property bool open: settingsView.menuButton === pop
    implicitWidth: Math.max(96, popLabel.implicitWidth + 40)
    implicitHeight: 24
    radius: 6
    color: open || popMouse.containsMouse ? settingsView.wellHover : settingsView.well
    Text {
      id: popLabel
      anchors.left: parent.left
      anchors.leftMargin: 10
      anchors.verticalCenter: parent.verticalCenter
      text: pop.currentLabel
      color: settingsView.text
      font.family: "Adwaita Sans"
      font.pixelSize: 13
    }
    Column {
      anchors.right: parent.right
      anchors.rightMargin: 8
      anchors.verticalCenter: parent.verticalCenter
      spacing: -5
      Repeater {
        model: ["󰅃", "󰅀"]
        delegate: Text {
          required property string modelData
          text: modelData
          color: settingsView.textMuted
          font.family: settingsView.host.fontFamily
          font.pixelSize: 10
        }
      }
    }
    MouseArea {
      id: popMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: pop.open ? settingsView.menuButton = null : settingsView.openMenu(pop)
    }
  }

  // macOS push button: small rounded rectangle, accent for the default action.
  component SettingsButton: Rectangle {
    id: button
    property string label: ""
    property bool primary: false
    signal clicked()
    implicitWidth: buttonText.implicitWidth + 24
    implicitHeight: 24
    radius: 6
    color: primary ? settingsView.accent : buttonMouse.containsMouse ? settingsView.wellHover : settingsView.well
    Text {
      id: buttonText
      anchors.centerIn: parent
      text: button.label
      color: button.primary ? settingsView.accentInk : settingsView.text
      font.family: "Adwaita Sans"
      font.pixelSize: 13
      font.weight: button.primary ? Font.DemiBold : Font.Normal
    }
    MouseArea {
      id: buttonMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: button.clicked()
    }
  }

  // An app-icon squircle with a soft top-to-bottom gradient, as macOS draws
  // its settings icons. Neutral when colorful icons are off.
  component PaneIcon: Rectangle {
    id: paneIcon
    property string glyph: ""
    property color tint: settingsView.accent
    property bool neutral: !settingsView.settings.colorfulSettingsIcons
    property bool onAccent: false
    implicitWidth: 20
    implicitHeight: 20
    radius: width * 0.26
    gradient: Gradient {
      GradientStop { position: 0; color: paneIcon.neutral ? (paneIcon.onAccent ? settingsView.accentInk : settingsView.well) : Qt.lighter(paneIcon.tint, 1.18) }
      GradientStop { position: 1; color: paneIcon.neutral ? (paneIcon.onAccent ? settingsView.accentInk : settingsView.well) : paneIcon.tint }
    }
    border.width: paneIcon.neutral ? 0 : 1
    border.color: Qt.rgba(1, 1, 1, 0.16)
    Text {
      anchors.centerIn: parent
      text: paneIcon.glyph
      color: paneIcon.neutral ? (paneIcon.onAccent ? settingsView.accent : settingsView.textMuted) : "#ffffff"
      font.family: settingsView.host.fontFamily
      font.pixelSize: Math.round(paneIcon.width * 0.62)
    }
  }

  // ---------- Rows and groups ----------

  // One row of a group: label (and optional detail) on the left, a control
  // on the right, and a hairline under every row but the last.
  component SettingsRow: Item {
    id: row
    property string label: ""
    property string detail: ""
    property bool last: false
    default property alias control: slot.data
    Layout.fillWidth: true
    implicitHeight: detail !== "" ? 50 : 38
    Column {
      anchors.left: parent.left
      anchors.leftMargin: 14
      anchors.right: slot.left
      anchors.rightMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      spacing: 2
      Text {
        width: parent.width
        text: row.label
        elide: Text.ElideRight
        color: settingsView.text
        font.family: "Adwaita Sans"
        font.pixelSize: 13
      }
      Text {
        width: parent.width
        visible: row.detail !== ""
        text: row.detail
        elide: Text.ElideRight
        color: settingsView.textMuted
        font.family: "Adwaita Sans"
        font.pixelSize: 11
      }
    }
    Item {
      id: slot
      anchors.right: parent.right
      anchors.rightMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      width: childrenRect.width
      height: childrenRect.height
    }
    Rectangle {
      visible: !row.last
      anchors.left: parent.left
      anchors.leftMargin: 14
      anchors.right: parent.right
      anchors.rightMargin: 14
      anchors.bottom: parent.bottom
      height: 1
      color: settingsView.divider
    }
  }

  // A group of rows under a bold section title, with an optional footnote.
  component SettingsGroup: ColumnLayout {
    id: group
    property string title: ""
    property string footer: ""
    default property alias rows: groupBody.data
    Layout.fillWidth: true
    spacing: 6
    Text {
      visible: group.title !== ""
      Layout.leftMargin: 2
      text: group.title
      color: settingsView.text
      font.family: "Adwaita Sans"
      font.pixelSize: 13
      font.weight: Font.DemiBold
    }
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: groupBody.implicitHeight
      radius: 10
      color: settingsView.card
      border.width: 1
      border.color: settingsView.host.withAlpha(settingsView.text, 0.04)
      ColumnLayout {
        id: groupBody
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0
      }
    }
    Text {
      visible: group.footer !== ""
      Layout.fillWidth: true
      Layout.leftMargin: 2
      text: group.footer
      wrapMode: Text.WordWrap
      color: settingsView.textMuted
      font.family: "Adwaita Sans"
      font.pixelSize: 11
    }
  }

  // The header System Settings puts at the top of a pane: the pane's icon,
  // its name, and what it's for.
  component PaneHeader: Rectangle {
    id: header
    property string page: ""
    readonly property var info: settingsView.pageInfo[page] || ({})
    Layout.fillWidth: true
    implicitHeight: headerColumn.implicitHeight + 36
    radius: 12
    color: settingsView.card
    border.width: 1
    border.color: settingsView.host.withAlpha(settingsView.text, 0.04)
    Column {
      id: headerColumn
      anchors.centerIn: parent
      width: Math.min(parent.width - 48, 380)
      spacing: 8
      PaneIcon {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 48
        height: 48
        glyph: header.info.icon || ""
        tint: header.info.color || settingsView.accent
      }
      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: header.page
        color: settingsView.text
        font.family: "Adwaita Sans"
        font.pixelSize: 17
        font.weight: Font.Bold
      }
      Text {
        width: parent.width
        visible: text !== ""
        horizontalAlignment: Text.AlignHCenter
        text: header.info.about || ""
        wrapMode: Text.WordWrap
        lineHeight: 1.1
        color: settingsView.textMuted
        font.family: "Adwaita Sans"
        font.pixelSize: 12
      }
    }
  }

  component SidebarItem: Rectangle {
    id: side
    property string title: ""
    readonly property var info: settingsView.pageInfo[title] || ({})
    readonly property bool selected: settingsView.currentPage === title
    Layout.fillWidth: true
    Layout.preferredHeight: 36
    radius: 8
    visible: settingsView.pageMatches(title)
    color: selected ? settingsView.accent : sideMouse.containsMouse ? settingsView.host.withAlpha(settingsView.text, 0.06) : "transparent"
    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: 8
      anchors.rightMargin: 8
      spacing: 10
      PaneIcon {
        Layout.preferredWidth: 26
        Layout.preferredHeight: 26
        glyph: side.info.icon || ""
        tint: side.info.color || settingsView.accent
        onAccent: side.selected
      }
      Text {
        Layout.fillWidth: true
        text: side.title
        elide: Text.ElideRight
        color: side.selected ? settingsView.accentInk : settingsView.text
        font.family: "Adwaita Sans"
        font.pixelSize: 15
      }
    }
    MouseArea {
      id: sideMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: settingsView.currentPage = side.title
    }
  }

  // ---------- Keybinds ----------

  readonly property string bindingsScript: host.companionDir + "/bindings.sh"
  property var shortcuts: []
  property string recordingId: ""
  property string recordHint: ""
  property string pendingId: ""
  property string pendingKeys: ""
  property string pendingConflict: ""
  property var setQueue: []

  Process {
    id: shortcutList
    command: ["bash", settingsView.bindingsScript, "list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var list = []
        String(text || "").split("\n").forEach(function(line) {
          var cols = line.split("\t")
          if (cols.length >= 2 && cols[0]) list.push({ id: cols[0], label: cols[1], keys: cols[2] || "", command: cols[3] || "" })
        })
        settingsView.shortcuts = list
      }
    }
  }
  Process {
    id: shortcutSet
    onExited: settingsView.runNextSet()
  }
  // Every live binding, so a conflict shows the moment the keys are typed.
  property var liveBindings: []
  Process {
    id: boundList
    command: ["bash", settingsView.bindingsScript, "bound"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        settingsView.liveBindings = String(text || "").split("\n").filter(function(line) { return line !== "" })
          .map(function(line) {
            var cols = line.split("\t")
            return { keys: cols[0], description: cols[1] || "", command: cols.slice(2).join("\t") }
          })
      }
    }
  }
  Process { id: submapEnter; command: ["hyprctl", "dispatch", "hl.dsp.submap(\"island-record\")"] }
  Process { id: submapReset; command: ["hyprctl", "dispatch", "hl.dsp.submap(\"reset\")"] }
  Timer {
    id: recordTimeout
    interval: 10000
    onTriggered: settingsView.stopRecording()
  }

  function setShortcut(id, keys) {
    shortcuts = shortcuts.map(function(entry) {
      if (entry.id === id) return { id: entry.id, label: entry.label, keys: keys, command: entry.command }
      if (keys !== "" && entry.keys === keys) return { id: entry.id, label: entry.label, keys: "", command: entry.command }
      return entry
    })
    queueRun(["set", id, keys])
  }
  function restoreDefaults() {
    stopRecording()
    cancelPending()
    queueRun(["reset"])
  }
  function queueRun(args) {
    setQueue = setQueue.concat([args])
    if (!shortcutSet.running) runNextSet()
  }
  function runNextSet() {
    if (setQueue.length === 0) { shortcutList.running = true; boundList.running = true; return }
    var next = setQueue[0]
    setQueue = setQueue.slice(1)
    shortcutSet.command = ["bash", bindingsScript].concat(next)
    shortcutSet.running = true
  }

  function startRecording(id) {
    cancelPending()
    recordingId = id
    recordHint = ""
    submapEnter.running = true
    recordTimeout.restart()
    recorder.forceActiveFocus()
  }
  function stopRecording() {
    if (recordingId === "") return
    recordingId = ""
    recordHint = ""
    recordTimeout.stop()
    submapReset.running = true
    if (active) settingsView.forceActiveFocus()
  }
  function captured(keys) {
    var id = recordingId
    stopRecording()
    var own = shortcuts.filter(function(e) { return e.id === id })[0]
    var used = liveBindings.filter(function(b) {
      return b.keys === keys && (!own || b.command !== own.command)
    })[0]
    if (!used) { setShortcut(id, keys); return }
    pendingId = id
    pendingKeys = keys
    pendingConflict = used.description
  }
  function applyPending() {
    if (pendingId !== "") setShortcut(pendingId, pendingKeys)
    cancelPending()
  }
  function cancelPending() {
    pendingId = ""
    pendingKeys = ""
    pendingConflict = ""
  }

  // Qt key → Hyprland key name. Digits and punctuation go by their physical
  // key, so Shift doesn't turn 1 into !.
  readonly property var scanKeys: ({
    10: "1", 11: "2", 12: "3", 13: "4", 14: "5", 15: "6", 16: "7", 17: "8", 18: "9", 19: "0",
    20: "MINUS", 21: "EQUAL", 34: "BRACKETLEFT", 35: "BRACKETRIGHT", 47: "SEMICOLON",
    48: "APOSTROPHE", 49: "GRAVE", 51: "BACKSLASH", 59: "COMMA", 60: "PERIOD", 61: "SLASH"
  })
  function keyName(event) {
    var k = event.key
    if (k >= Qt.Key_A && k <= Qt.Key_Z) return String.fromCharCode(k)
    if (k >= Qt.Key_F1 && k <= Qt.Key_F24) return "F" + (k - Qt.Key_F1 + 1)
    var names = {}
    names[Qt.Key_Space] = "SPACE"; names[Qt.Key_Return] = "RETURN"; names[Qt.Key_Enter] = "RETURN"
    names[Qt.Key_Escape] = "ESCAPE"; names[Qt.Key_Tab] = "TAB"; names[Qt.Key_Backtab] = "TAB"
    names[Qt.Key_Backspace] = "BACKSPACE"; names[Qt.Key_Delete] = "DELETE"; names[Qt.Key_Insert] = "INSERT"
    names[Qt.Key_Home] = "HOME"; names[Qt.Key_End] = "END"; names[Qt.Key_PageUp] = "PRIOR"; names[Qt.Key_PageDown] = "NEXT"
    names[Qt.Key_Left] = "LEFT"; names[Qt.Key_Right] = "RIGHT"; names[Qt.Key_Up] = "UP"; names[Qt.Key_Down] = "DOWN"
    names[Qt.Key_Print] = "PRINT"
    return names[k] || scanKeys[event.nativeScanCode] || ""
  }

  function shortcutText(keys) {
    if (!keys) return "None"
    var names = {
      SUPER: "Super", SHIFT: "Shift", CTRL: "Ctrl", ALT: "Alt",
      ESCAPE: "Esc", RETURN: "Enter", BACKSPACE: "Backspace", PRIOR: "Page Up", NEXT: "Page Down",
      COMMA: ",", PERIOD: ".", SLASH: "/", MINUS: "-", EQUAL: "=", GRAVE: "`", SEMICOLON: ";",
      APOSTROPHE: "'", BRACKETLEFT: "[", BRACKETRIGHT: "]", BACKSLASH: "\\"
    }
    return keys.split(" + ").map(function(part) {
      return names[part] || (part.length <= 3 ? part : part.charAt(0) + part.slice(1).toLowerCase())
    }).join(" + ")
  }

  // One shortcut, like a row of macOS's Keyboard Shortcuts: the name, and the
  // keys on the right. Click the keys to type new ones; keys that are
  // taken add a warning line with Cancel and Replace.
  component ShortcutRow: Item {
    id: shortcutRow
    property var entry: ({})
    property bool last: false
    readonly property bool recording: settingsView.recordingId === entry.id
    readonly property bool asking: settingsView.pendingId === entry.id && settingsView.pendingConflict !== ""
    Layout.fillWidth: true
    implicitHeight: asking ? 60 : 38
    Behavior on implicitHeight { NumberAnimation { duration: settingsView.animDuration; easing.type: Easing.OutCubic } }

    Text {
      anchors.left: parent.left
      anchors.leftMargin: 14
      anchors.right: keysField.left
      anchors.rightMargin: 10
      y: 10
      text: shortcutRow.entry.label
      elide: Text.ElideRight
      color: settingsView.text
      font.family: "Adwaita Sans"
      font.pixelSize: 13
    }
    Rectangle {
      id: keysField
      anchors.right: parent.right
      anchors.rightMargin: 10
      y: 7
      width: Math.max(shortcutRow.recording ? 150 : 0, keysText.implicitWidth + 16)
      height: 24
      radius: 6
      visible: !shortcutRow.asking
      color: shortcutRow.recording ? settingsView.host.withAlpha(settingsView.accent, 0.16)
        : keysMouse.containsMouse ? settingsView.well : settingsView.host.withAlpha(settingsView.well, 0)
      Behavior on width { NumberAnimation { duration: settingsView.animDuration; easing.type: Easing.OutCubic } }
      Behavior on color { ColorAnimation { duration: settingsView.animDuration; easing.type: Easing.OutCubic } }
      // Focus ring: settles in from slightly larger, like macOS's.
      Rectangle {
        anchors.centerIn: parent
        width: parent.width + 6
        height: parent.height + 6
        radius: parent.radius + 3
        color: "transparent"
        border.width: 3
        border.color: settingsView.host.withAlpha(settingsView.accent, 0.55)
        opacity: shortcutRow.recording ? 1 : 0
        scale: shortcutRow.recording ? 1 : 1.12
        Behavior on opacity { NumberAnimation { duration: settingsView.animDuration; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: settingsView.animDuration * 1.2; easing.type: Easing.OutCubic } }
      }
      Text {
        id: keysText
        anchors.centerIn: parent
        text: shortcutRow.recording ? (settingsView.recordHint || "Type Shortcut") : settingsView.shortcutText(shortcutRow.entry.keys)
        color: shortcutRow.recording ? settingsView.accent
          : shortcutRow.entry.keys === "" ? settingsView.textMuted : settingsView.text
        font.family: "Adwaita Sans"
        font.pixelSize: 13
        Behavior on color { ColorAnimation { duration: settingsView.animDuration; easing.type: Easing.OutCubic } }
      }
      MouseArea {
        id: keysMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: shortcutRow.recording ? settingsView.stopRecording() : settingsView.startRecording(shortcutRow.entry.id)
      }
    }
    Row {
      anchors.right: parent.right
      anchors.rightMargin: 10
      y: 7
      spacing: 6
      visible: shortcutRow.asking
      SettingsButton { label: "Cancel"; onClicked: settingsView.cancelPending() }
      SettingsButton { label: "Replace"; primary: true; onClicked: settingsView.applyPending() }
    }
    Row {
      x: 14
      y: 36
      spacing: 5
      visible: shortcutRow.asking
      Text {
        text: "󰀪"
        color: "#febc2e"
        font.family: settingsView.host.fontFamily
        font.pixelSize: 12
      }
      Text {
        text: settingsView.shortcutText(settingsView.pendingKeys) + " is used by " + settingsView.pendingConflict
        color: settingsView.textMuted
        font.family: "Adwaita Sans"
        font.pixelSize: 11
      }
    }
    Rectangle {
      visible: !shortcutRow.last
      anchors.left: parent.left
      anchors.leftMargin: 14
      anchors.right: parent.right
      anchors.rightMargin: 14
      anchors.bottom: parent.bottom
      height: 1
      color: settingsView.divider
    }
  }

  readonly property var shortcutSections: [
    { title: "Menus", ids: ["menu", "apps", "power"] },
    { title: "Search", ids: ["keybinds", "emoji", "clipboard"] },
    { title: "Appearance", ids: ["themes", "wallpapers"] },
    { title: "Island", ids: ["controls", "player", "settings"] }
  ]

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
      border.color: settingsView.host.withAlpha(settingsView.text, 0.05)
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
          color: settingsView.host.withAlpha(settingsView.text, 0.08)
          border.width: searchInput.activeFocus ? 2 : 0
          border.color: settingsView.host.withAlpha(settingsView.accent, 0.6)
          Text {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: "󰍉"
            color: settingsView.textMuted
            font.family: settingsView.host.fontFamily
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

          PaneHeader { page: settingsView.currentPage; Layout.topMargin: 4 }

      SettingsGroup {
        title: "Pill"
        visible: settingsView.currentPage === "General"
        SettingsRow {
          label: "Workspace Indicator"
          detail: "Show which workspace you're on when you switch"
          SettingsSwitch {
            checked: settingsView.settings.workspaceHud
            onToggled: function(on) { settingsView.settings.workspaceHud = on }
          }
        }
        SettingsRow {
          label: "24-Hour Clock"
          SettingsSwitch {
            checked: settingsView.settings.clock24h
            onToggled: function(on) { settingsView.settings.clock24h = on }
          }
        }
        SettingsRow {
          label: "Volume HUD"
          detail: "Show the level when the volume changes"
          SettingsSwitch {
            checked: settingsView.settings.volumeHud
            onToggled: function(on) { settingsView.settings.volumeHud = on }
          }
        }
        SettingsRow {
          label: "Notch Style"
          detail: "Attach the island to the top edge, like a MacBook notch"
          last: true
          SettingsSwitch {
            checked: settingsView.settings.notch
            onToggled: function(on) { settingsView.settings.notch = on }
          }
        }
      }

      SettingsGroup {
        title: "Appearance"
        visible: settingsView.currentPage === "General"
        SettingsRow {
          label: "Colorful Sidebar Icons"
          detail: "Use macOS-style colors in the sidebar"
          last: true
          SettingsSwitch {
            checked: settingsView.settings.colorfulSettingsIcons
            onToggled: function(on) { settingsView.settings.colorfulSettingsIcons = on }
          }
        }
      }

      SettingsGroup {
        title: "Motion"
        visible: settingsView.currentPage === "General"
        SettingsRow {
          label: "Animation Speed"
          SettingsPopUp {
            options: [{ label: "Fast", value: 1 }, { label: "Normal", value: 1.5 }, { label: "Relaxed", value: 2 }]
            value: settingsView.settings.motionScale
            onPicked: function(v) { settingsView.settings.motionScale = v }
          }
        }
        SettingsRow {
          label: "Hover Lift"
          detail: "The clock pill lifts slightly under the pointer"
          last: true
          SettingsSwitch {
            checked: settingsView.settings.hoverLift
            onToggled: function(on) { settingsView.settings.hoverLift = on }
          }
        }
      }

      SettingsGroup {
        title: "Ask AI"
        visible: settingsView.currentPage === "Search"
        footer: "Uses the command-line tool you're signed in to. Choose None to turn asking off."
        SettingsRow {
          label: "Ask With"
          detail: "Answers launcher questions in the island"
          last: true
          SettingsPopUp {
            options: [{ label: "Claude", value: "claude" }, { label: "Codex", value: "chatgpt" }, { label: "None", value: "none" }]
            value: settingsView.settings.askAi
            onPicked: function(v) { settingsView.settings.askAi = v }
          }
        }
      }

      SettingsGroup {
        title: "Show on the Pill"
        visible: settingsView.currentPage === "Live Activities"
        SettingsRow {
          label: "Now Playing"
          detail: "Show the cover and sound wave while media plays"
          SettingsSwitch {
            checked: settingsView.settings.mediaPill
            onToggled: function(on) { settingsView.settings.mediaPill = on }
          }
        }
        SettingsRow {
          label: "Clipboard"
          detail: "Show what you copied for a moment"
          SettingsSwitch {
            checked: settingsView.settings.clipboard
            onToggled: function(on) { settingsView.settings.clipboard = on }
          }
        }
        SettingsRow {
          label: "Downloads"
          detail: "Show browser downloads in progress on the pill"
          SettingsSwitch {
            checked: settingsView.settings.downloads
            onToggled: function(on) { settingsView.settings.downloads = on }
          }
        }
        SettingsRow {
          label: "System Updates"
          detail: "Show pacman, yay, paru, and Omarchy updates on the pill"
          SettingsSwitch {
            checked: settingsView.settings.systemUpdates
            onToggled: function(on) { settingsView.settings.systemUpdates = on }
          }
        }
        SettingsRow {
          label: "Battery"
          detail: "Show when charging starts and when the battery runs low"
          SettingsSwitch {
            checked: settingsView.settings.batteryActivity
            onToggled: function(on) { settingsView.settings.batteryActivity = on }
          }
        }
        SettingsRow {
          label: "Bluetooth Devices"
          detail: "Show devices connecting and disconnecting"
          last: true
          SettingsSwitch {
            checked: settingsView.settings.bluetoothActivity
            onToggled: function(on) { settingsView.settings.bluetoothActivity = on }
          }
        }
      }

      SettingsGroup {
        title: "Banners"
        visible: settingsView.currentPage === "Notifications"
        SettingsRow {
          label: "Banner Duration"
          detail: "How long a notification stays on the pill"
          last: true
          SettingsPopUp {
            options: [{ label: "3 seconds", value: 3 }, { label: "5 seconds", value: 5 }, { label: "8 seconds", value: 8 }]
            value: settingsView.settings.bannerSeconds
            onPicked: function(v) { settingsView.settings.bannerSeconds = v }
          }
        }
      }

      Repeater {
        model: settingsView.currentPage === "Keybinds" ? settingsView.shortcutSections : []
        delegate: SettingsGroup {
          id: section
          required property var modelData
          readonly property var entries: settingsView.shortcuts.filter(function(e) { return section.modelData.ids.indexOf(e.id) !== -1 })
          title: modelData.title
          Repeater {
            model: section.entries
            delegate: ShortcutRow {
              required property var modelData
              required property int index
              entry: modelData
              last: index === section.entries.length - 1
            }
          }
        }
      }

      RowLayout {
        visible: settingsView.currentPage === "Keybinds"
        Layout.fillWidth: true
        SettingsButton { label: "Restore Defaults"; onClicked: settingsView.restoreDefaults() }
        Item { Layout.fillWidth: true }
      }
        }
      }
    }
  }

  // ---------- Pop-up menu ----------

  // The open pop-up button; its choices show in popMenu, under it.
  property Item menuButton: null
  property var menuOptions: []
  property var menuValue
  FontMetrics { id: menuFont; font.family: "Adwaita Sans"; font.pixelSize: 13 }
  function openMenu(button) {
    var widest = 0
    for (var i = 0; i < button.options.length; i++) widest = Math.max(widest, menuFont.advanceWidth(button.options[i].label))
    menuOptions = button.options
    menuValue = button.value
    popMenu.width = Math.max(button.width, Math.ceil(widest) + 52)
    popMenu.height = button.options.length * 24 + 10
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
    opacity: settingsView.menuButton ? 1 : 0
    scale: settingsView.menuButton ? 1 : 0.96
    transformOrigin: Item.Top
    Behavior on opacity { NumberAnimation { duration: 110 * settingsView.host.motionScale } }
    Behavior on scale { NumberAnimation { duration: 110 * settingsView.host.motionScale; easing.type: Easing.OutCubic } }
    radius: 9
    color: Qt.tint(settingsView.panel, settingsView.host.withAlpha(settingsView.text, 0.13))
    border.width: 1
    border.color: settingsView.host.withAlpha(settingsView.text, 0.1)
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
          height: 24
          radius: 5
          color: itemMouse.containsMouse ? settingsView.accent : "transparent"
          Text {
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            visible: menuItem.chosen
            text: "󰄬"
            color: itemMouse.containsMouse ? settingsView.accentInk : settingsView.text
            font.family: settingsView.host.fontFamily
            font.pixelSize: 12
          }
          Text {
            id: menuText
            x: 26
            anchors.verticalCenter: parent.verticalCenter
            text: menuItem.modelData.label
            color: itemMouse.containsMouse ? settingsView.accentInk : settingsView.text
            font.family: "Adwaita Sans"
            font.pixelSize: 13
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

  // Takes the keyboard while a shortcut is being recorded.
  Item {
    id: recorder
    width: 0
    height: 0
    // A modifier's own press doesn't include itself in event.modifiers yet.
    function modifierFor(key) {
      if (key === Qt.Key_Meta || key === Qt.Key_Super_L || key === Qt.Key_Super_R) return Qt.MetaModifier
      if (key === Qt.Key_Shift) return Qt.ShiftModifier
      if (key === Qt.Key_Control) return Qt.ControlModifier
      if (key === Qt.Key_Alt) return Qt.AltModifier
      return 0
    }
    onActiveFocusChanged: if (!activeFocus) settingsView.stopRecording()
    function heldMods(modifiers) {
      var mods = []
      if (modifiers & Qt.MetaModifier) mods.push("SUPER")
      if (modifiers & Qt.ShiftModifier) mods.push("SHIFT")
      if (modifiers & Qt.ControlModifier) mods.push("CTRL")
      if (modifiers & Qt.AltModifier) mods.push("ALT")
      return mods
    }
    function showHeld(modifiers) {
      var mods = heldMods(modifiers)
      settingsView.recordHint = mods.length ? settingsView.shortcutText(mods.join(" + ")) + " + …" : ""
    }
    Keys.onReleased: function(event) {
      event.accepted = true
      if (settingsView.recordingId !== "" && settingsView.keyName(event) === "") showHeld(event.modifiers & ~recorder.modifierFor(event.key))
    }
    Keys.onPressed: function(event) {
      event.accepted = true
      var name = settingsView.keyName(event)
      if (name === "") { showHeld(event.modifiers | recorder.modifierFor(event.key)); return }
      var mods = heldMods(event.modifiers)
      if (name === "ESCAPE" && mods.length === 0) { settingsView.stopRecording(); return }
      if ((name === "BACKSPACE" || name === "DELETE") && mods.length === 0) {
        var id = settingsView.recordingId
        settingsView.stopRecording()
        settingsView.setShortcut(id, "")
        return
      }
      if (mods.length === 0 && !/^F\d+$/.test(name)) { settingsView.recordHint = "Add a Modifier"; return }
      settingsView.captured(mods.concat([name]).join(" + "))
    }
  }
}

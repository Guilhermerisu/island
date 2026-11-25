import QtQuick
import Quickshell.Widgets
import "../../components"

// The notifications zone as XSmall (one line: the count and the newest app) or
// Small (all of them as compact banners, newest on top, an app's folded into
// one stack). NotificationHistory draws it in place of the list, and tells it
// `zoneSize`, the banners in order (`rows`, with their stack) and what "2m ago"
// counts from (`now`). Nothing of the full list is out of reach: the buttons
// of an app, folding a stack, Dismiss and Clear All are in the menu a right
// click (XS, S) or the ⋯ chip (S) opens, over the columns (center.openPopover).
// `center` is the ControlCenter.
Item {
  id: glance
  required property var center
  required property string zoneSize
  property var rows: []
  property real now: Date.now()
  // Fold or unfold the stack `id`, which NotificationHistory keeps.
  signal stackToggled(var id)

  // The notification's image or app icon, or the brand tile of Claude Code and
  // Codex, or the accent bell: shared with the banners of the full list.
  component Avatar: ClippingRectangle {
    id: avatar
    required property var center
    required property var row
    // A live image handle dies with the shell; fall back to the app icon (then
    // the bell) when it no longer loads.
    property bool imageFailed: false
    readonly property string source: center.host.notifications.iconSource(row, imageFailed)
    readonly property var brand: center.host.notifications.brand(row)
    width: 36; height: 36; radius: center.host.theme.radii.large
    readonly property bool generic: !brand && icon.status !== Image.Ready
    color: brand ? brand.tile : "transparent"
    // Same tile as the banner (NotificationPill), so a notification looks the
    // same on the pill and here.
    Rectangle {
      anchors.fill: parent
      visible: avatar.generic
      gradient: Gradient {
        GradientStop { position: 0; color: Qt.lighter(avatar.center.host.theme.accent, 1.25) }
        GradientStop { position: 1; color: avatar.center.host.theme.accent }
      }
    }
    Image {
      id: icon
      anchors.fill: parent
      source: avatar.source
      sourceSize.width: 60
      sourceSize.height: 60
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      visible: status === Image.Ready
      onStatusChanged: if (status === Image.Error) avatar.imageFailed = true
    }
    Text {
      anchors.centerIn: parent
      visible: icon.status !== Image.Ready
      text: avatar.brand ? avatar.brand.glyph : "󰂚"
      color: avatar.brand ? avatar.brand.ink : avatar.center.host.theme.accentText
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: avatar.center.host.theme.px(20)
    }
  }

  readonly property var theme: center.host.theme
  readonly property var notifications: center.host.notifications
  readonly property bool xs: zoneSize === "xsmall"
  readonly property int total: notifications.history.length
  // The newest stack: its head is what the line names.
  readonly property var stack: notifications.stacks.length ? notifications.stacks[0] : null
  readonly property var head: stack ? stack.head : null
  readonly property string app: head ? String(head.app || "") : ""

  // One line (XS, or nothing to show), else the banners: tall as they are, so
  // the zone's height comes from them and never from the room it is given.
  implicitHeight: xs || !head ? line.height : list.implicitHeight

  // A folded stack goes whole; one on its own, or unfolded, one by one.
  function dismissRow(row) {
    if (!(row.stackSize > 1 && !row.stackOpen)) { notifications.dismiss(row); return }
    var stack = notifications.stacks.find(function(s) { return s.id === row.stackId })
    if (stack) notifications.dismissAll([stack.head].concat(stack.rest))
  }
  function hasButtons(row) {
    return center.host.settings.notificationButtons && !!row.isActive && (row.actions || []).length > 0
  }
  // As a click on the banner of the full list, which closes the control
  // center for the app's window.
  function openRow(row) {
    center.host.view = "rest"
    notifications.open(row, false)
  }
  // What the menu holds. For a banner: Open, the app's buttons, the stack,
  // Dismiss. For the line: the full list, the buttons of the notifications
  // still on screen (the latest few). Clear All is in both (first for the
  // line, whose menu may be cut short when the control center is short).
  function menuFor(row) {
    var out = []
    if (row) {
      out.push({ label: "Open", run: function() { glance.openRow(row) } })
      for (var i = 0; hasButtons(row) && i < row.actions.length; i++)
        out.push({ label: String(row.actions[i].label || ""), run: glance.pressButton.bind(glance, row, i) })
      if (row.stackSize > 1)
        out.push({ label: row.stackOpen ? "Show Less" : "Show " + (row.stackSize - 1) + " More", run: function() { glance.stackToggled(row.stackId) } })
      out.push({ label: row.stackSize > 1 && !row.stackOpen ? "Clear Stack" : "Dismiss", run: function() { glance.dismissRow(row) } })
    } else {
      out.push({ label: "Open Notifications", run: function() { glance.center.host.view = "notifications" } })
      out.push({ label: "Clear All", run: function() { glance.notifications.clearAll() } })
      var shown = 0
      for (var n = 0; n < notifications.history.length && shown < 4; n++) {
        var r = notifications.history[n]
        if (!hasButtons(r)) continue
        shown++
        out.push({ label: notifications.title(r), heading: true })
        for (var b = 0; b < r.actions.length; b++)
          out.push({ label: String(r.actions[b].label || ""), run: glance.pressButton.bind(glance, r, b) })
      }
    }
    if (row) out.push({ label: "Clear All", run: function() { glance.notifications.clearAll() } })
    return out
  }
  function pressButton(row, index) { notifications.runAction(row, index) }
  function openMenu(anchor, row) { center.openPopover(anchor, menu, { entries: menuFor(row) }) }

  // The round chips on a banner: ⋯ for its menu, +N / Less for its stack.
  component Chip: Rectangle {
    id: chip
    required property var center
    property string text
    property bool glyph: false
    signal clicked
    width: Math.max(16, chipText.implicitWidth + 12)
    height: 16
    radius: height / 2
    color: chipMouse.containsMouse ? center.wellHover : center.well
    Behavior on color { MotionColorAnimation { theme: chip.center.host.theme } }
    Text {
      id: chipText
      anchors.centerIn: parent
      text: chip.text
      color: chip.center.textMuted
      font.family: chip.glyph ? chip.center.iconFont : chip.center.host.theme.textFontFamily
      font.pixelSize: chip.glyph ? chip.center.host.theme.px(12) : chip.center.host.theme.size.footnote
      font.weight: Font.DemiBold
    }
    MouseArea {
      id: chipMouse
      anchors.fill: parent
      anchors.margins: -3
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: chip.clicked()
    }
  }
  // One line of the menu: a button, or a muted heading over the buttons of a
  // notification.
  component MenuEntry: Rectangle {
    id: entry
    required property var center
    property string label
    property bool heading: false
    signal activated
    height: heading ? 22 : 28
    radius: 6
    color: !heading && entryMouse.containsMouse ? center.wellHover : "transparent"
    Text {
      anchors.verticalCenter: parent.verticalCenter
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.leftMargin: 8
      anchors.rightMargin: 8
      text: entry.label
      textFormat: Text.PlainText
      elide: Text.ElideRight
      color: entry.heading ? entry.center.textMuted : entry.center.text
      font.family: entry.center.host.theme.textFontFamily
      font.pixelSize: entry.heading ? entry.center.host.theme.size.subheadline : entry.center.host.theme.size.callout
      font.weight: entry.heading ? Font.DemiBold : Font.Medium
    }
    MouseArea {
      id: entryMouse
      anchors.fill: parent
      enabled: !entry.heading
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: entry.activated()
    }
  }
  Component {
    id: menu
    Item {
      id: panel
      required property var entries
      implicitWidth: 200
      implicitHeight: entryColumn.implicitHeight
      Column {
        id: entryColumn
        width: parent.width
        spacing: 2
        Repeater {
          model: panel.entries
          delegate: MenuEntry {
            required property var modelData
            width: entryColumn.width
            center: glance.center
            label: modelData.label
            heading: !!modelData.heading
            onActivated: { glance.center.closePopover(); modelData.run() }
          }
        }
      }
    }
  }

  // XS, or nothing to show: one line, in the fixed height of an XS zone.
  Rectangle {
    id: line
    visible: glance.xs || !glance.head
    width: parent.width
    height: glance.center.zoneXsHeight
    radius: glance.center.cardRadius
    color: lineHover.hovered && lineMouse.enabled ? glance.center.tile : glance.center.card
    border.width: 1
    border.color: glance.center.edge
    scale: lineMouse.pressed ? 0.98 : 1
    Behavior on scale { MotionAnimation { theme: glance.theme; pace: lineMouse.pressed ? "press" : "standard" } }
    Behavior on color { MotionColorAnimation { theme: glance.theme } }
    HoverHandler { id: lineHover }

    // Click: the history in the island. Right click: the menu.
    MouseArea {
      id: lineMouse
      anchors.fill: parent
      enabled: !!glance.head
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      cursorShape: Qt.PointingHandCursor
      onClicked: function(mouse) {
        if (mouse.button === Qt.RightButton) glance.openMenu(line, null)
        else glance.center.host.view = "notifications"
      }
    }
    Row {
      anchors.verticalCenter: parent.verticalCenter
      anchors.left: parent.left
      anchors.leftMargin: 12
      anchors.right: parent.right
      anchors.rightMargin: 12
      spacing: 8
      Text {
        id: bell
        anchors.verticalCenter: parent.verticalCenter
        text: "󰂚"
        color: glance.head ? glance.theme.accent : glance.center.textMuted
        font.family: glance.center.iconFont
        font.pixelSize: glance.theme.px(16)
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - bell.width - parent.spacing
        textFormat: Text.PlainText
        elide: Text.ElideRight
        text: !glance.head ? "No notifications"
          : glance.total + (glance.total === 1 ? " notification" : " notifications") + (glance.app ? " · " + glance.app : "")
        color: glance.head ? glance.center.text : glance.center.textMuted
        font.family: glance.theme.textFontFamily
        font.letterSpacing: glance.theme.tracking(glance.theme.textFontFamily, glance.theme.size.callout)
        font.pixelSize: glance.theme.size.callout
        font.weight: glance.head ? Font.Medium : Font.Normal
      }
    }
  }

  // Small: the banners of the full list, compact (a line of text each).
  Column {
    id: list
    visible: !glance.xs && !!glance.head
    width: parent.width
    spacing: 4
    Repeater {
      model: glance.rows
      delegate: Item {
        id: banner
        required property var modelData
        readonly property var row: modelData
        readonly property bool stacked: !!row.stackSize && row.stackSize > 1
        readonly property bool folded: stacked && !row.stackOpen
        // The unfolded rest of a stack sits inset under its newest.
        readonly property real inset: row.child ? 12 : 0
        readonly property bool buttons: glance.hasButtons(row)
        // The whole banner, × and chips included (their Tooltip would take the
        // hover of a mouse area under it).
        readonly property bool hovered: bannerHover.hovered
        HoverHandler { id: bannerHover }
        width: glance.width
        height: card.height + (folded ? 6 : 0)

        // The notifications behind the top one of a folded stack.
        Rectangle {
          visible: banner.folded
          x: 10
          y: card.height - 4
          width: parent.width - 20
          height: 10
          radius: glance.center.cardRadius
          color: glance.center.tile
          border.width: 1
          border.color: glance.center.edge
        }
        Rectangle {
          id: card
          x: banner.inset
          width: parent.width - banner.inset
          height: Math.max(textCol.implicitHeight, 36) + 16
          radius: glance.center.cardRadius
          color: banner.hovered ? glance.center.tile : glance.center.card
          border.width: 1
          border.color: glance.center.edge
          scale: cardMouse.pressed ? 0.98 : 1
          Behavior on scale { MotionAnimation { theme: glance.theme; pace: cardMouse.pressed ? "press" : "standard" } }
          Behavior on color { MotionColorAnimation { theme: glance.theme } }

          // Click: as on the full list's banner. Right click: its menu.
          MouseArea {
            id: cardMouse
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: function(mouse) {
              if (mouse.button === Qt.RightButton) glance.openMenu(card, banner.row)
              else glance.openRow(banner.row)
            }
          }
          Avatar {
            id: avatar
            center: glance.center
            row: banner.row
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
          }
          Column {
            id: textCol
            anchors.left: avatar.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Item {
              width: parent.width
              height: title.height
              Text {
                id: title
                anchors.left: parent.left
                anchors.right: age.left
                anchors.rightMargin: 8
                text: glance.notifications.title(banner.row)
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: glance.center.text
                font.family: glance.theme.textFontFamily
                font.letterSpacing: glance.theme.tracking(glance.theme.textFontFamily, glance.theme.size.body)
                font.pixelSize: glance.theme.size.body
                font.weight: Font.DemiBold
              }
              // Gives its place to the × while hovered.
              Text {
                id: age
                anchors.right: parent.right
                anchors.baseline: title.baseline
                opacity: banner.hovered ? 0 : 1
                Behavior on opacity { MotionAnimation { theme: glance.theme; pace: "fade"; curve: "fade" } }
                text: glance.notifications.age(banner.row.timestamp, glance.now)
                textFormat: Text.PlainText
                color: glance.center.textMuted
                font.family: glance.theme.textFontFamily
                font.letterSpacing: glance.theme.tracking(glance.theme.textFontFamily, glance.theme.size.subheadline)
                font.pixelSize: glance.theme.size.subheadline
              }
            }
            // One line whatever Settings' full-text option says.
            Text {
              id: bodyLine
              width: parent.width - (chips.visible ? chips.width + 8 : 0)
              visible: text !== ""
              text: String(banner.row.body || "").replace(/\s+/g, " ").trim()
              textFormat: Text.PlainText
              maximumLineCount: 1
              elide: Text.ElideRight
              color: glance.theme.withAlpha(glance.center.text, 0.78)
              font.family: glance.theme.textFontFamily
              font.letterSpacing: glance.theme.tracking(glance.theme.textFontFamily, glance.theme.size.callout)
              font.pixelSize: glance.theme.size.callout
            }
          }
          // ⋯ opens the menu (the app's buttons are in it), +N unfolds the stack.
          Row {
            id: chips
            visible: banner.buttons || banner.stacked
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.bottom: parent.bottom
            // Under the time, not on it, when there is no line of text.
            anchors.bottomMargin: bodyLine.visible ? 8 : 4
            spacing: 4
            Chip {
              visible: banner.buttons
              center: glance.center
              glyph: true
              text: "󰇘"
              onClicked: glance.openMenu(card, banner.row)
              Tooltip { theme: glance.theme; text: "Buttons" }
            }
            Chip {
              visible: banner.stacked
              center: glance.center
              text: banner.row.stackOpen ? "Less" : "+" + (banner.row.stackSize - 1)
              onClicked: glance.stackToggled(banner.row.stackId)
              Tooltip { theme: glance.theme; text: banner.row.stackOpen ? "Fold the stack" : "Show the stack" }
            }
          }
          // The × of the full list, where the time was.
          Rectangle {
            id: close
            visible: opacity > 0
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.top: parent.top
            anchors.topMargin: 6
            scale: closeMouse.pressed ? 0.9 : 1
            Behavior on scale { MotionAnimation { theme: glance.theme; pace: closeMouse.pressed ? "press" : "standard" } }
            width: 20; height: 20; radius: 10
            opacity: banner.hovered ? 1 : 0
            Behavior on opacity { MotionAnimation { theme: glance.theme; pace: "fade"; curve: "fade" } }
            color: closeHover.hovered ? glance.center.wellHover : glance.center.well
            border.width: 1
            border.color: glance.theme.fill("raised")
            Text {
              anchors.centerIn: parent
              text: "󰅖"
              color: glance.center.text
              font.family: glance.center.iconFont
              font.pixelSize: glance.theme.px(12)
            }
            HoverHandler { id: closeHover; blocking: false; cursorShape: Qt.PointingHandCursor }
            MouseArea {
              id: closeMouse
              anchors.fill: parent
              anchors.margins: -3
              onClicked: glance.dismissRow(banner.row)
            }
            Tooltip { theme: glance.theme; text: banner.folded ? "Clear Stack" : "Dismiss" }
          }
        }
      }
    }
  }
}

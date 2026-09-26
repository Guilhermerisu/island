import QtQuick
import Quickshell.Io

// Shared picker surface for the island's switchers: a search field over a
// carousel of cards, with the neighbours fading into the island. The selected
// card stays centered, except that the first and last cards sit flush with
// the edges. Keyboard: type to filter, ←/→ (or Tab, or the wheel) to move,
// Enter to apply, Esc to close. Clicking the selected card applies it.
//
// A switcher provides `viewName` (the island view that shows it), `items`
// ([{ key, name, … }], filtered by name), `currentKey` (the active item),
// `applyCommand` (entry -> argv), and a `card` component whose root declares
// `property var entry`. The picker draws the selection outline and the
// active-item dot over each card, runs the command, and closes.
Item {
  id: picker
  required property var host
  property string viewName: ""
  property var items: []
  property string currentKey: ""
  property var applyCommand: null
  property string placeholder: "Search…"
  property string emptyText: "Nothing matches"
  property int cardWidth: 196
  property int cardHeight: 102
  property Component card
  // The selected card grows past full size and the rest shrink back; the
  // strip is padded so the enlarged card never gets clipped.
  property real selectedScale: 1.06
  property real restScale: 0.9
  readonly property int pad: Math.ceil(cardWidth * (selectedScale - 1) / 2) + 2
  // Emitted after the apply command finishes, before the picker closes.
  signal applied(var entry)

  readonly property bool active: viewName !== "" && host.view === viewName
  visible: active || opacity > 0.01
  enabled: active
  opacity: active && host.surfaceContentReady ? 1 : 0
  Behavior on opacity { NumberAnimation { duration: (picker.host.surfaceContentReady ? 190 : 110) * picker.host.motionScale; easing.type: Easing.InOutQuad } }

  implicitHeight: header.height + 14 + carousel.height

  function close() { if (active) host.view = "rest" }

  property string query: ""
  readonly property var filtered: {
    var q = query.trim().toLowerCase().replace(/\s+/g, "-")
    if (!q) return items
    return items.filter(function(item) { return String(item.name).toLowerCase().indexOf(q) !== -1 })
  }
  readonly property var selected: filtered[carousel.currentIndex] || null

  onActiveChanged: {
    if (!active) return
    search.text = ""
    selectCurrent()
    Qt.callLater(function() { search.forceActiveFocus() })
  }
  // Typing jumps to the first match.
  onQueryChanged: jumpTo(0)

  // A new item list (e.g. a theme installed while open) keeps the selection
  // instead of snapping back to the first card.
  property string lastSelectedKey: ""
  onSelectedChanged: if (selected) lastSelectedKey = selected.key
  onItemsChanged: {
    if (!active) return
    for (var i = 0; i < filtered.length; i++)
      if (filtered[i].key === lastSelectedKey) { jumpTo(i); return }
    selectCurrent()
  }

  function selectCurrent() {
    for (var i = 0; i < filtered.length; i++)
      if (filtered[i].key === currentKey) { jumpTo(i); return }
    if (filtered.length) jumpTo(0)
  }

  function move(delta) {
    if (!filtered.length) return
    var next = carousel.currentIndex + delta
    if (next >= 0 && next < filtered.length) carousel.currentIndex = next
    // Wrapping around jumps straight to the other end instead of scrolling
    // the whole strip back.
    else jumpTo((next + filtered.length) % filtered.length)
  }

  // ---------- Applying ----------

  property var pendingEntry: null
  function apply() {
    if (!selected || applier.running) return
    if (selected.key === currentKey || !applyCommand) { close(); return }
    pendingEntry = selected
    applier.command = applyCommand(selected)
    applier.running = true
  }
  Process {
    id: applier
    onExited: {
      picker.applied(picker.pendingEntry)
      picker.close()
    }
  }

  // ---------- Scrolling ----------

  // One duration and easing for everything a selection change moves (strip
  // scroll, outline, card fade and scale), so it reads as one motion.
  readonly property int moveDuration: 240 * host.motionScale

  // Jump without the carousel scrolling through everything in between (a
  // model reset otherwise animates back from card 0).
  function jumpTo(index) {
    carousel.currentIndex = index
    scrollToCurrent(true)
  }

  // Center the selected card, clamped so the strip never scrolls past its
  // first or last card (plus the padding that leaves room to grow).
  function scrollToCurrent(instant) {
    if (!filtered.length) return
    var span = cardWidth + carousel.spacing
    var contentWidth = filtered.length * span - carousel.spacing
    var target = carousel.currentIndex * span + cardWidth / 2 - carousel.width / 2
    var minX = -pad
    var maxX = Math.max(minX, contentWidth - carousel.width + pad)
    target = Math.max(minX, Math.min(maxX, target)) + carousel.originX
    scrollAnimation.stop()
    if (instant) carousel.contentX = target
    else {
      scrollAnimation.to = target
      scrollAnimation.start()
    }
  }
  NumberAnimation {
    id: scrollAnimation
    target: carousel
    property: "contentX"
    duration: picker.moveDuration
    easing.type: Easing.OutCubic
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
      color: picker.host.colorMuted
      font.family: picker.host.fontFamily
      font.pixelSize: 17
    }
    TextInput {
      id: search
      anchors.left: searchIcon.right
      anchors.leftMargin: 12
      anchors.right: parent.right
      anchors.rightMargin: 4
      anchors.verticalCenter: parent.verticalCenter
      color: picker.host.colorText
      selectionColor: picker.host.withAlpha(picker.host.colorAccent, 0.4)
      selectedTextColor: picker.host.colorText
      font.family: "Adwaita Sans"
      font.pixelSize: 15
      clip: true
      onTextChanged: picker.query = text
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Right || event.key === Qt.Key_Down || (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier))) {
          picker.move(1); event.accepted = true
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
          picker.move(-1); event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          picker.apply(); event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
          picker.close(); event.accepted = true
        }
      }
      Text {
        anchors.fill: parent
        verticalAlignment: Text.AlignVCenter
        visible: search.text === ""
        text: picker.placeholder
        color: picker.host.colorMuted
        font: search.font
      }
    }
  }

  // ---------- Carousel ----------

  ListView {
    id: carousel
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: header.bottom
    anchors.topMargin: 14
    height: Math.ceil(picker.cardHeight * picker.selectedScale) + 4
    leftMargin: picker.pad
    rightMargin: picker.pad
    orientation: ListView.Horizontal
    spacing: 12
    clip: true
    model: picker.filtered
    boundsBehavior: Flickable.StopAtBounds
    keyNavigationEnabled: false
    onCurrentIndexChanged: picker.scrollToCurrent(false)
    // The island morphs open, so the strip widens; keep the selection placed.
    onWidthChanged: picker.scrollToCurrent(true)

    WheelHandler {
      onWheel: function(event) {
        var d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
        picker.move(d > 0 ? -1 : 1)
      }
    }

    // Each slot spans the strip's full height with the card centered in it,
    // so the enlarged selected card has room above and below (a horizontal
    // ListView ignores a delegate's own y).
    delegate: Item {
      id: slot
      required property var modelData
      required property int index
      readonly property bool isSelected: ListView.isCurrentItem
      width: picker.cardWidth
      height: carousel.height
      opacity: isSelected ? 1 : 0.55
      scale: isSelected ? picker.selectedScale : picker.restScale
      Behavior on opacity { NumberAnimation { duration: picker.moveDuration; easing.type: Easing.OutCubic } }
      Behavior on scale { NumberAnimation { duration: picker.moveDuration; easing.type: Easing.OutCubic } }

      Item {
        anchors.centerIn: parent
        width: picker.cardWidth
        height: picker.cardHeight

        Loader {
          anchors.fill: parent
          sourceComponent: picker.card
          onLoaded: item.entry = Qt.binding(function() { return slot.modelData })
        }
        // Selection outline, drawn over the card so image cards get it too.
        Rectangle {
          anchors.fill: parent
          radius: 14
          color: "transparent"
          border.width: slot.isSelected ? 2 : 1
          border.color: slot.isSelected ? picker.host.colorAccent : picker.host.withAlpha(picker.host.colorText, 0.08)
          Behavior on border.color { ColorAnimation { duration: picker.moveDuration; easing.type: Easing.OutCubic } }
        }
        // Marks the item that's active right now.
        Rectangle {
          visible: slot.modelData.key === picker.currentKey
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: 9
          width: 7; height: 7; radius: 3.5
          color: picker.host.colorAccent
          border.width: 1
          border.color: Qt.rgba(0, 0, 0, 0.35)
        }
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (slot.isSelected) picker.apply()
            else carousel.currentIndex = slot.index
            search.forceActiveFocus()
          }
        }
      }
    }

    Text {
      anchors.centerIn: parent
      visible: picker.filtered.length === 0 && picker.items.length > 0
      text: picker.emptyText
      color: picker.host.colorMuted
      font.family: "Adwaita Sans"
      font.pixelSize: 13
    }
  }

  // Fade the cards out toward the ends, into the island's background; each
  // fade hides once the strip reaches that end.
  Rectangle {
    anchors.left: carousel.left
    anchors.top: carousel.top
    anchors.bottom: carousel.bottom
    width: 56
    opacity: carousel.contentX - carousel.originX < -picker.pad + 1 ? 0 : 1
    Behavior on opacity { NumberAnimation { duration: 150 * picker.host.motionScale } }
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0; color: picker.host.colorBackground }
      GradientStop { position: 1; color: picker.host.withAlpha(picker.host.colorBackground, 0) }
    }
  }
  Rectangle {
    anchors.right: carousel.right
    anchors.top: carousel.top
    anchors.bottom: carousel.bottom
    width: 56
    opacity: carousel.contentX - carousel.originX > carousel.contentWidth - carousel.width + picker.pad - 1 ? 0 : 1
    Behavior on opacity { NumberAnimation { duration: 150 * picker.host.motionScale } }
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0; color: picker.host.withAlpha(picker.host.colorBackground, 0) }
      GradientStop { position: 1; color: picker.host.colorBackground }
    }
  }
}

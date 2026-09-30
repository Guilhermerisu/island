import QtQuick
import Quickshell.Io

// Shared picker surface for the island's switchers: a search field over a
// carousel of cards, with the neighbours fading into the island. The selected
// card stays centered, except that the first and last cards sit flush with
// the edges. Keyboard: type to filter, ←/→ (or Tab, or the wheel) to move,
// Enter to apply, Esc to close. Clicking the selected card applies it.
//
// A switcher provides `items` ([{ key, name, … }], filtered by name),
// `currentKey` (the active item),
// `applyCommand` (entry -> argv), and a `card` component whose root declares
// `property var entry`. The picker draws the selection outline and the
// active-item dot over each card, runs the command, and closes.
Item {
  id: picker
  required property var host
  // Set by the Surface that shows this picker.
  property bool active: false
  property var items: []
  property string currentKey: ""
  property var applyCommand: null
  property string placeholder: "Search…"
  property string emptyText: "Nothing matches"
  property int cardWidth: 196
  property int cardHeight: 102
  property Component card
  // The selected card grows past full size and the rest shrink back. It's
  // marked by a ring set just outside the card (macOS picker style); the
  // strip is padded so the enlarged card and its ring never get clipped.
  property real selectedScale: 1.05
  property real restScale: 0.92
  readonly property int cardRadius: 16
  readonly property real ringGap: 4
  readonly property real ringWidth: 2.5
  readonly property real ringReach: (ringGap + ringWidth) * selectedScale
  readonly property int pad: Math.ceil(cardWidth * (selectedScale - 1) / 2 + ringReach) + 2
  // Emitted after the apply command finishes, before the picker closes.
  signal applied(var entry)

  implicitHeight: search.height + 14 + carousel.height

  function close() { if (active) host.view = "rest" }

  readonly property string query: search.text
  readonly property var filtered: {
    var q = query.trim().toLowerCase().replace(/\s+/g, "-")
    if (!q) return items
    return items.filter(function(item) { return String(item.name).toLowerCase().indexOf(q) !== -1 })
  }
  readonly property var selected: filtered[carousel.currentIndex] || null

  onActiveChanged: {
    if (!active) return
    search.clear()
    selectCurrent()
    Qt.callLater(function() { search.focusInput() })
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
  readonly property int moveDuration: 240 * host.theme.motionScale

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

  SearchField {
    id: search
    host: picker.host
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    placeholder: picker.placeholder
    onKeyPressed: function(event) {
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
  }

  // ---------- Carousel ----------

  ListView {
    id: carousel
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: search.bottom
    anchors.topMargin: 14
    height: Math.ceil(picker.cardHeight * picker.selectedScale + 2 * picker.ringReach) + 4
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
      opacity: isSelected ? 1 : 0.6
      scale: isSelected ? picker.selectedScale : picker.restScale
      Behavior on opacity { NumberAnimation { duration: picker.moveDuration; easing.type: Easing.OutCubic } }
      // A gentle spring as the card settles into its size.
      Behavior on scale { NumberAnimation { duration: picker.moveDuration; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }

      Item {
        anchors.centerIn: parent
        width: picker.cardWidth
        height: picker.cardHeight

        Loader {
          anchors.fill: parent
          sourceComponent: picker.card
          onLoaded: item.entry = Qt.binding(function() { return slot.modelData })
        }
        // Hairline so dark cards still read against the black island.
        Rectangle {
          anchors.fill: parent
          radius: picker.cardRadius
          color: "transparent"
          border.width: 1
          border.color: picker.host.theme.withAlpha(picker.host.theme.text, 0.06)
        }
        // Selection ring, set a few pixels outside the card; fades in.
        Rectangle {
          anchors.fill: parent
          anchors.margins: -(picker.ringGap + picker.ringWidth)
          radius: picker.cardRadius + picker.ringGap + picker.ringWidth
          color: "transparent"
          border.width: picker.ringWidth
          border.color: picker.host.theme.accent
          opacity: slot.isSelected ? 1 : 0
          Behavior on opacity { NumberAnimation { duration: picker.moveDuration; easing.type: Easing.OutCubic } }
        }
        // Checkmark badge on the item that's active right now.
        Rectangle {
          visible: slot.modelData.key === picker.currentKey
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: 7
          width: 18; height: 18; radius: 9
          color: picker.host.theme.accent
          border.width: 1
          border.color: Qt.rgba(0, 0, 0, 0.25)
          Text {
            anchors.centerIn: parent
            text: "󰄬"
            color: picker.host.theme.accentText
            font.family: picker.host.theme.fontFamily
            font.pixelSize: 12
          }
        }
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (slot.isSelected) picker.apply()
            else carousel.currentIndex = slot.index
            search.focusInput()
          }
        }
      }
    }

    Text {
      anchors.centerIn: parent
      visible: picker.filtered.length === 0 && picker.items.length > 0
      text: picker.emptyText
      color: picker.host.theme.muted
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
    Behavior on opacity { NumberAnimation { duration: 150 * picker.host.theme.motionScale } }
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0; color: picker.host.theme.background }
      GradientStop { position: 1; color: picker.host.theme.withAlpha(picker.host.theme.background, 0) }
    }
  }
  Rectangle {
    anchors.right: carousel.right
    anchors.top: carousel.top
    anchors.bottom: carousel.bottom
    width: 56
    opacity: carousel.contentX - carousel.originX > carousel.contentWidth - carousel.width + picker.pad - 1 ? 0 : 1
    Behavior on opacity { NumberAnimation { duration: 150 * picker.host.theme.motionScale } }
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0; color: picker.host.theme.withAlpha(picker.host.theme.background, 0) }
      GradientStop { position: 1; color: picker.host.theme.background }
    }
  }
}

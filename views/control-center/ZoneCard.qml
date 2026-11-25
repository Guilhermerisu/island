import QtQuick
import QtQuick.Layouts
import "../../addons"
import "../../components"

// One zone of the control center, in its column: what it holds (the control
// grid, the notifications, or an addon's zone, see addons/Addon.qml). A zone
// is as tall as its body: XSmall is one line, center.zoneXsHeight, or taller
// if what it holds is (a Controls zone on several rows); Small and Normal are
// what their body asks for. Nothing in a zone scrolls: when the zones are
// taller than the island the page scrolls (Views.qml). Each body is told its
// `zoneSize` and `zoneRoom`, see addons/Addon.qml.
// Edit mode changes none of that: the zone has the size, the height and the
// content it has outside it. What it adds is a title bar above the zone, in
// the column (`bar`, zoneBoard.barHeight and a gap, on top of the zone's
// height): the grip that moves it, its name, the XS · S · M that sizes it and
// the − that removes it. A zone is a preview, which takes no click or hover,
// except one with its own editing (the grid, the Plugins tiles), in any size.
// `center` is the ControlCenter, `zoneBoard` the ZoneColumns, `zoneId` the zone,
// `columnWidth` the width its column will have once the island has its width.
Item {
  id: zone
  required property var center
  required property var zoneBoard
  required property string zoneId
  required property real columnWidth
  readonly property var info: center.zones.definition(zoneId)
  readonly property bool isAddon: !!(info && info.addon)
  readonly property var addonRoot: isAddon ? center.host.addons.root(info.addon) : null
  // A zone the addon draws itself: its `zone`, or the one of its `zones` this
  // is. Without, its first view or Settings page in a card (see AddonZone).
  readonly property var ownComponent: !addonRoot ? null : info.key ? (addonRoot.zones || {})[info.key] || null : addonRoot.zone
  readonly property bool hasContent: !!addonRoot && ((addonRoot.views || []).length > 0 || (addonRoot.settingsPages || []).length > 0)
  readonly property var bodyComponent: ownComponent || (hasContent ? mountedZone : null)
  Component { id: mountedZone; AddonZone { mount: true } }
  readonly property bool editableBody: zoneId === "controls" || !!(info && info.editable)
  readonly property string zoneSize: center.zones.size(zoneId)
  // A zone with its own editing (the grid, the Plugins tiles), in any size:
  // its body keeps the pointer, XSmall's pips and Small's tiles included.
  readonly property bool editsInPlace: center.editMode && editableBody
  readonly property bool preview: center.editMode && !editsInPlace
  // What the body asks for (its implicit height, never the height it is
  // given), the notifications' small gap under the grid included.
  readonly property real natural: viewport.natural + above
  readonly property real topGap: zoneId === "notifications" && zoneSize === "normal" ? 4 : 0
  readonly property real above: topGap
  // The zone's height: what its body asks for, XSmall's at least its line.
  readonly property real fitted: zoneSize === "xsmall" ? Math.max(center.zoneXsHeight, natural) : natural
  // The height a body is told it has, informative: XSmall's line, none (the
  // body's own height) for Small and Normal.
  readonly property real zoneRoom: zoneSize === "xsmall" ? center.zoneXsHeight : Number.POSITIVE_INFINITY
  // Eases the height only while the size changes: elsewhere it follows what
  // the body asks for, frame by frame (a picker opening).
  property bool resizing: false
  onZoneSizeChanged: { resizing = true; resizeTimer.restart() }
  Timer { id: resizeTimer; interval: zone.center.host.theme.motionDuration("standard") + 50; onTriggered: zone.resizing = false }
  // Judged by the column's final width, so the zone doesn't flip between its
  // content and the warning while the island is still growing.
  // The registry's minWidth, else what the addon's first view asks of the
  // island (its width less its padding, plus the card's own), known once the
  // addon is on.
  readonly property real minWidth: {
    if (!isAddon) return 0
    if (info.minWidth > 0) return info.minWidth
    var view = addonRoot && (addonRoot.views || [])[0]
    return view && view.width > 0 ? view.width - 2 * (view.padding === undefined ? 16 : view.padding) + 32 : 0
  }
  // XSmall and Small are drawn to fit the narrowest column, so no minimum.
  readonly property bool tooNarrow: zoneSize === "normal" && minWidth > 0 && columnWidth < minWidth
  readonly property bool addonOff: isAddon && !center.host.addons.isEnabled(info.addon)
  // Made the first time the control center opens, then kept.
  property bool opened: center.active
  Connections {
    target: zone.center
    function onActiveChanged() { if (zone.center.active) zone.opened = true }
  }
  implicitHeight: stack.implicitHeight
  // Fades and grows in once made (a zone added, or moved to another column).
  property bool appeared: false
  Component.onCompleted: appeared = true
  opacity: !appeared ? 0 : zoneBoard.draggedId === zoneId ? 0.4 : 1
  Behavior on opacity { MotionAnimation { theme: zone.center.host.theme; pace: "fade"; curve: "fade" } }
  scale: appeared ? 1 : 0.96
  Behavior on scale { enabled: zone.zoneBoard.animating; MotionAnimation { theme: zone.center.host.theme; pace: "standard" } }

  // The column's layout places it at once; it's drawn from where it was and
  // eases there, so sizes are never in doubt. Not until the layout has first
  // placed it, or a new zone would slide down from the column's top.
  transform: Translate { id: slide }
  MotionAnimation { id: slideHome; target: slide; property: "y"; to: 0; theme: zone.center.host.theme; pace: "standard" }
  property bool placed: false
  property real lastY: 0
  Timer { interval: 50; running: true; onTriggered: { zone.lastY = zone.y; zone.placed = true } }
  onYChanged: {
    if (placed && zoneBoard.animating) {
      slide.y += lastY - y
      slideHome.restart()
    }
    lastY = y
  }

  ColumnLayout {
    id: stack
    width: zone.width
    // The gap between the title bar and the body (the bar is hidden outside
    // edit mode, and a hidden item takes no spacing).
    spacing: zone.center.gap
    // Edit mode's title bar, above the zone in the column (the zone itself keeps
    // the size and content it has outside edit mode: the bar is added on top).
    Rectangle {
      id: bar
      visible: zone.center.editMode
      opacity: visible ? 1 : 0
      Behavior on opacity { enabled: zone.center.settled; MotionAnimation { theme: zone.center.host.theme; pace: "fade"; curve: "fade" } }
      Layout.fillWidth: true
      Layout.preferredHeight: zone.zoneBoard.barHeight
      radius: Math.min(zone.center.cardRadius, height / 2)
      color: zone.center.card
      border.width: 1
      border.color: zone.center.edge
      // Six dots, the grip.
      Grid {
        anchors.verticalCenter: parent.verticalCenter
        x: 14
        columns: 2
        spacing: 3
        Repeater {
          model: 6
          Rectangle { width: 3; height: 3; radius: 1.5; color: zone.center.textMuted }
        }
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        x: 32
        text: zone.info ? zone.info.icon : ""
        color: zone.center.textMuted
        font.family: zone.center.iconFont
        font.pixelSize: zone.center.host.theme.px(14)
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        x: 54
        // Shortened rather than the sizes: a narrow column has little to spare.
        width: Math.max(0, sizes.x - 6 - x)
        elide: Text.ElideRight
        text: zone.info ? zone.info.title : zone.zoneId
        color: zone.center.text
        font.family: zone.center.host.theme.textFontFamily
        font.letterSpacing: zone.center.host.theme.tracking(zone.center.host.theme.textFontFamily, zone.center.host.theme.size.callout)
        font.pixelSize: zone.center.host.theme.size.callout
        font.weight: Font.DemiBold
      }
      // XS · S · M, saved as it's clicked. A well with a chip gliding between
      // the three, as the columns' choice in the header and Settings' segmented.
      Rectangle {
        id: sizes
        readonly property real cell: 26
        readonly property var options: [
          { label: "XS", value: "xsmall", tip: "Extra Small" },
          { label: "S", value: "small", tip: "Small" },
          { label: "M", value: "normal", tip: "Normal" }
        ]
        readonly property int current: {
          for (var i = 0; i < options.length; i++) if (options[i].value === zone.zoneSize) return i
          return 2
        }
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 4
        width: options.length * cell + 4
        height: 22
        radius: height / 2
        color: Qt.rgba(0, 0, 0, 0.3)
        Rectangle {
          x: 2 + sizes.current * sizes.cell
          y: 2
          width: sizes.cell
          height: sizes.height - 4
          radius: height / 2
          color: zone.center.well
          Behavior on x { MotionAnimation { theme: zone.center.host.theme; pace: "quick" } }
        }
        Repeater {
          model: sizes.options
          delegate: Item {
            id: choice
            required property var modelData
            required property int index
            readonly property bool selected: index === sizes.current
            x: 2 + index * sizes.cell
            y: 2
            width: sizes.cell
            height: sizes.height - 4
            scale: choiceMouse.pressed ? 0.94 : 1
            Behavior on scale { MotionAnimation { theme: zone.center.host.theme; pace: choiceMouse.pressed ? "press" : "standard" } }
            Text {
              anchors.centerIn: parent
              text: choice.modelData.label
              color: choice.selected ? zone.center.text : zone.center.textMuted
              Behavior on color { MotionColorAnimation { theme: zone.center.host.theme } }
              font.family: zone.center.host.theme.textFontFamily
              font.letterSpacing: zone.center.host.theme.tracking(zone.center.host.theme.textFontFamily, zone.center.host.theme.size.footnote)
              font.pixelSize: zone.center.host.theme.size.footnote
              font.weight: choice.selected ? Font.DemiBold : Font.Medium
            }
            Tooltip { theme: zone.center.host.theme; text: choice.modelData.tip }
            // Takes the press, so it doesn't start dragging the bar.
            MouseArea {
              id: choiceMouse
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: zone.center.zones.setSize(zone.zoneId, choice.modelData.value)
            }
          }
        }
      }
      HoverHandler { cursorShape: dragger.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor }
      // Only follows the pointer: the board moves a stand-in for the zone.
      DragHandler {
        id: dragger
        target: null
        onActiveChanged: {
          if (active) zone.zoneBoard.beginDrag(zone.zoneId, Qt.size(bar.width, bar.height), centroid.pressPosition, centroid.scenePosition)
          else zone.zoneBoard.finishDrag()
        }
        onCentroidChanged: if (active) zone.zoneBoard.moveDrag(centroid.scenePosition)
      }
      CcEditBadge {
        center: zone.center
        shown: zone.zoneBoard.draggedId !== zone.zoneId
        cornerRadius: bar.radius
        tip: "Remove"
        onClicked: zone.center.zones.remove(zone.zoneId)
      }
    }
    // The body: the grid and the notifications, or an addon's zone (made in the
    // loader, so the component's parent has `center`, `zoneActive`, `zoneSize`
    // and `zoneRoom`), as wide as the column and as tall as it asks to be.
    Item {
      id: viewport
      // What the body asks for.
      readonly property real natural: zone.isAddon
        ? (addonBody.active ? (addonBody.item ? addonBody.item.implicitHeight : 0) : placeholder.base)
        : (plainBody.item ? plainBody.item.implicitHeight : 0)
      // XSmall's line is cut, as is a zone while its size eases. A
      // curve-rendered Shape (a card's ›) ignores an ancestor's clip, so a cut
      // zone is drawn to a texture of its own size, which can't overflow.
      clip: zone.zoneSize === "xsmall" || zone.resizing
      layer.enabled: clip
      Layout.fillWidth: true
      // The notifications sit a little off the grid above them.
      Layout.topMargin: zone.above
      // Only a change of size eases: a picker opening is followed frame by frame.
      Layout.preferredHeight: Math.max(0, zone.fitted - zone.above)
      Behavior on Layout.preferredHeight { enabled: zone.resizing && zone.center.settled; MotionAnimation { theme: zone.center.host.theme; pace: "standard" } }

      Loader {
        id: plainBody
        active: !zone.isAddon
        width: viewport.width
        height: item ? item.implicitHeight : 0
        sourceComponent: zone.zoneId === "controls" ? controlsZone : notificationsZone
        // Only a body that has the property is told, so one that doesn't know
        // about sizes stays as it is.
        onLoaded: {
          if (item.zoneSize !== undefined) item.zoneSize = Qt.binding(function() { return zone.zoneSize })
          if (item.zoneRoom !== undefined) item.zoneRoom = Qt.binding(function() { return zone.zoneRoom })
        }
      }
      Loader {
        id: addonBody
        property var center: zone.center
        property bool zoneActive: zone.center.active
        property var addonRoot: zone.addonRoot
        property string zoneSize: zone.zoneSize
        property real zoneRoom: zone.zoneRoom
        active: zone.isAddon && !!zone.bodyComponent && !zone.tooNarrow && zone.opened
        width: viewport.width
        height: item ? item.implicitHeight : 0
        sourceComponent: zone.bodyComponent
      }
      // In its place while the addon is off or loading, or the column too narrow.
      Rectangle {
        id: placeholder
        visible: zone.isAddon && !addonBody.active
        readonly property real base: zone.addonOff || zone.tooNarrow ? 64 : zone.center.tileHeight * 0.7
        width: viewport.width
        // Kept to what the zone's size shows, so its words stay in view.
        // XSmall's fills its line; the others are as tall as they are.
        height: zone.zoneSize === "xsmall" ? zone.center.zoneXsHeight : base
        radius: zone.center.cardRadius
        color: zone.center.card
        border.width: 1
        border.color: zone.center.edge
        Column {
          anchors.centerIn: parent
          width: parent.width - 24
          spacing: 2
          Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: zone.addonOff ? zone.info.name + " is off"
              : zone.tooNarrow ? zone.info.name + " needs a wider column"
              : zone.addonRoot && !zone.bodyComponent ? "Nothing to show" : "Loading…"
            color: zone.addonOff || zone.tooNarrow ? zone.center.text : zone.center.textMuted
            font.family: zone.center.host.theme.textFontFamily
            font.letterSpacing: zone.center.host.theme.tracking(zone.center.host.theme.textFontFamily, zone.center.host.theme.size.callout)
            font.pixelSize: zone.center.host.theme.size.callout
            font.weight: zone.addonOff || zone.tooNarrow ? Font.DemiBold : Font.Normal
          }
          Text {
            visible: zone.addonOff || zone.tooNarrow
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: zone.addonOff ? "Turn On" : "Use fewer columns"
            color: zone.addonOff ? zone.center.accent : zone.center.textMuted
            font.family: zone.center.host.theme.textFontFamily
            font.letterSpacing: zone.center.host.theme.tracking(zone.center.host.theme.textFontFamily, zone.center.host.theme.size.subheadline)
            font.pixelSize: zone.center.host.theme.size.subheadline
            MouseArea {
              anchors.fill: parent
              anchors.margins: -4
              enabled: zone.addonOff
              cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
              onClicked: zone.center.host.addons.setEnabled(zone.info.addon, true)
            }
          }
        }
      }

      // A preview (edit mode) is only to look at: nothing under it takes a click
      // or a hover, and the wheel goes on to the page.
      MouseArea {
        anchors.fill: parent
        z: 200
        enabled: zone.preview
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        onWheel: function(wheel) { wheel.accepted = false }
      }
    }
  }
  Component { id: controlsZone; ControlLayout { center: zone.center } }
  Component { id: notificationsZone; NotificationHistory { center: zone.center } }
}

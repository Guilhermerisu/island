pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

// Displays in an XSmall or Small control center zone (see "Zone sizes" in
// Addon.qml), in place of the pane's groups: a mounted Settings page has no
// card of its own (AddonZone pads it 0), so this draws one, of exactly the
// height the size allows. XSmall is one line, the count and the main
// display's mode; Small the screens as arranged, in proportion and named,
// beside the main display's mode and scale. Read-only: the resolution, scale,
// arrangement and the rest stay in Settings, which a click on either size
// opens (the addon has no view).
// `view` is a ZoneLook, `displays` the DisplaysAddon.
Rectangle {
  id: glance
  required property var view
  required property var displays
  required property string zoneSize
  readonly property var theme: view.host.theme
  readonly property bool xs: zoneSize === "xsmall"
  // XSmall is the zone's fixed line (the page's `zoneRoom`, 58: the card is
  // padded 0); Small is as tall as it holds, under its 91 minimum.
  property real xsHeight: 58
  implicitHeight: xs ? xsHeight : 80
  radius: theme.radii.card
  color: view.card
  border.width: 1
  border.color: view.edge

  // The monitors as they are, not as Settings' pending edits have them.
  readonly property var on: displays.original.filter(function(e) { return !e.disabled })
  // The one the island is on (hyprland's focused), else the first.
  readonly property var main: on.filter(function(e) { return e.focused })[0] || on[0] || null
  readonly property bool turned: !!main && main.transform % 2 === 1
  readonly property string size: !main ? "" : turned ? main.height + " × " + main.width : main.width + " × " + main.height
  readonly property string scaleText: main ? "Scale " + Number(main.scale.toFixed(2)) : ""
  readonly property string rate: main && main.rate ? Math.round(Number(main.rate)) + " Hz" : ""

  // Each box (logical size, turned) fitted into the canvas, centred.
  readonly property var boxes: on.map(function(e) { return Object.assign({ name: e.name, main: e === main }, displays.box(e)) })
  readonly property var bounds: {
    var x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity
    boxes.forEach(function(b) {
      x0 = Math.min(x0, b.x); y0 = Math.min(y0, b.y)
      x1 = Math.max(x1, b.x + b.w); y1 = Math.max(y1, b.y + b.h)
    })
    return boxes.length ? { x: x0, y: y0, w: x1 - x0, h: y1 - y0 } : { x: 0, y: 0, w: 1, h: 1 }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: glance.view.host.openSettings("Displays")
  }

  RowLayout {
    visible: glance.xs
    anchors.fill: parent
    anchors.leftMargin: 12
    anchors.rightMargin: 12
    spacing: 8
    Text {
      text: "󰍹"
      color: glance.view.accent
      font.family: glance.theme.fontFamily
      font.pixelSize: glance.theme.px(16)
    }
    Text {
      Layout.fillWidth: true
      // "2 displays · 2560 × 1440 @ 1.25": the count, the main one's mode and scale.
      text: !glance.main ? "No displays" : glance.on.length + (glance.on.length === 1 ? " display" : " displays")
        + " · " + glance.size.replace(/ /g, "") + " @ " + Number(glance.main.scale.toFixed(2))
      elide: Text.ElideRight
      color: glance.view.text
      font.family: glance.theme.textFontFamily
      font.features: { "tnum": 1 }
      font.pixelSize: glance.view.detailFontSize
      font.weight: Font.Medium
    }
  }

  RowLayout {
    visible: !glance.xs
    anchors.fill: parent
    anchors.margins: 12
    spacing: 12
    Item {
      id: canvas
      Layout.fillWidth: true
      Layout.preferredWidth: 1
      Layout.fillHeight: true
      readonly property real k: Math.min(width / glance.bounds.w, height / glance.bounds.h)
      Repeater {
        model: glance.boxes
        delegate: Item {
          id: box
          required property var modelData
          x: (canvas.width - glance.bounds.w * canvas.k) / 2 + (modelData.x - glance.bounds.x) * canvas.k
          y: (canvas.height - glance.bounds.h * canvas.k) / 2 + (modelData.y - glance.bounds.y) * canvas.k
          width: modelData.w * canvas.k
          height: modelData.h * canvas.k
          DisplayScreen {
            anchors.fill: parent
            view: glance.view
            wallpaper: glance.displays.wallpaper
            radius: 3
            bezel: 1.5
            shadow: false
            sourceWidth: 120
          }
          // The name, over a scrim to read on any wallpaper; outside the
          // screen's own content, which is masked to its glass.
          Rectangle {
            anchors.fill: parent
            anchors.margins: 1.5
            radius: 2
            color: Qt.rgba(0, 0, 0, 0.42)
            Text {
              anchors.fill: parent
              anchors.margins: 2
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
              text: box.modelData.name
              elide: Text.ElideRight
              color: "white"
              font.family: glance.theme.textFontFamily
              font.pixelSize: 9
              font.weight: Font.Medium
            }
          }
          // The main one ringed, as the pane rings the picked one.
          Rectangle {
            anchors.fill: parent
            radius: 3
            color: "transparent"
            border.width: 1.5
            border.color: glance.view.accent
            visible: box.modelData.main && glance.boxes.length > 1
          }
        }
      }
    }
    Column {
      Layout.preferredWidth: 104
      Layout.alignment: Qt.AlignVCenter
      spacing: 2
      Text {
        width: parent.width
        text: glance.main ? glance.main.title.trim() : "No displays"
        elide: Text.ElideRight
        color: glance.view.text
        font.family: glance.theme.textFontFamily
        font.pixelSize: glance.view.detailFontSize
        font.weight: Font.DemiBold
      }
      Text {
        width: parent.width
        visible: !!glance.main
        text: glance.size
        elide: Text.ElideRight
        color: glance.view.textMuted
        font.family: glance.theme.textFontFamily
        font.features: { "tnum": 1 }
        font.pixelSize: glance.view.detailCaptionFontSize
      }
      Text {
        width: parent.width
        visible: !!glance.main
        text: glance.scaleText + (glance.rate !== "" ? " · " + glance.rate : "")
        elide: Text.ElideRight
        color: glance.view.textMuted
        font.family: glance.theme.textFontFamily
        font.features: { "tnum": 1 }
        font.pixelSize: glance.view.detailCaptionFontSize
      }
    }
  }
}

import QtQuick
import "../../components"

// The call on the island, as Apple's: a green phone and the call's length
// leading, the mic's waveform trailing, the clock between them. Hovered, it
// grows into FaceTime's round buttons under them: mic, camera, and sharing,
// each white while it's switched on (muted, camera off, sharing), and a red
// hang up. `meetings` is the MeetingsAddon.
Item {
  id: pill
  required property var meetings
  readonly property var host: meetings.host
  readonly property var theme: host.theme
  readonly property bool colorful: host.settings.colorfulLiveActivities
  readonly property color ink: colorful ? pill.theme.system.green : theme.accent
  readonly property color endInk: pill.theme.system.red

  // A button's tooltip: what it does, or where to go when the app has no
  // shortcut for it.
  function tip(kind, label, elsewhere) {
    return meetings.hasKey(kind) ? label : "Open " + meetings.callName + " " + elsewhere
  }

  opacity: meetings.pillShown ? 1 : 0
  visible: opacity > 0.01
  Behavior on opacity { MotionAnimation { theme: pill.theme; pace: "fade"; curve: "fade" } }

  // The phone and time, then the waveform, come in from a blur in turn, as
  // the other pills.
  PillReveal { id: reveal; theme: pill.theme; shown: pill.meetings.pillShown }

  // How far the island has grown from the resting pill (0) to the controls
  // (1), read off its live width, so the row's insets ride the island's
  // spring, bounce and all, instead of drifting against its edge on a curve
  // of their own. Both ends are taken as it starts to grow: the width it
  // grows from (the clock's included) and the addon's grown pillWidth.
  property real restWidth: 0
  property real grownWidth: 0
  readonly property real grow: grownWidth > restWidth
    ? Math.max(0, Math.min(1, (width - restWidth) / (grownWidth - restWidth)))
    : meetings.expanded ? 1 : 0
  Connections {
    target: pill.meetings
    function onExpandedChanged() {
      if (!pill.meetings.expanded) return
      pill.restWidth = pill.width
      pill.grownWidth = pill.meetings.pillWidth
    }
  }

  HoverHandler {
    enabled: pill.meetings.pillShown
    onHoveredChanged: pill.meetings.hovered = hovered
  }

  // The resting row, kept at the top while the pill grows.
  Item {
    id: top
    width: parent.width
    height: pill.meetings.restHeight
    // Leaving, it all shrinks away into the island.
    opacity: pill.meetings.leaving ? 0 : 1
    scale: pill.meetings.leaving ? 0.92 : 1
    Behavior on opacity { MotionAnimation { theme: pill.theme; pace: "collapse"; curve: "exit" } }
    Behavior on scale { MotionAnimation { theme: pill.theme; pace: "collapse"; curve: "exit" } }

    // Leading and trailing groups about the same width and inset alike (the
    // phone glyph's own padding taken off), so the clock sits balanced
    // between them.
    Row {
      anchors.left: parent.left
      anchors.leftMargin: 14 + (pill.meetings.inset + 2 - 14) * pill.grow
      anchors.verticalCenter: parent.verticalCenter
      spacing: 3
      opacity: reveal.leadingIn
      PillPart { progress: reveal.leadingIn }
      // Ended, the phone hangs up: it turns red and tips down into
      // phone.down, the time stopped beside it in red.
      Item {
        anchors.verticalCenter: parent.verticalCenter
        width: 15
        height: 15
        // Its glyph sits a touch high in its box: down half a pixel, sized
        // to the digits' height.
        CallIcon {
          anchors.centerIn: parent
          anchors.verticalCenterOffset: 0.5
          name: "phone"
          size: 15
          color: pill.ink
          opacity: pill.meetings.ended ? 0 : 1
          rotation: pill.meetings.ended ? 90 : 0
          Behavior on opacity { MotionAnimation { theme: pill.theme; pace: "fade"; curve: "fade" } }
          Behavior on rotation { MotionAnimation { theme: pill.theme; pace: "morph" } }
        }
        CallIcon {
          anchors.centerIn: parent
          name: "phone.down"
          size: 17
          color: pill.endInk
          opacity: pill.meetings.ended ? 1 : 0
          rotation: pill.meetings.ended ? 0 : -45
          scale: pill.meetings.ended ? 1 : 0.6
          Behavior on scale { MotionAnimation { theme: pill.theme; pace: "morph" } }
          Behavior on opacity { MotionAnimation { theme: pill.theme; pace: "fade"; curve: "fade" } }
          Behavior on rotation { MotionAnimation { theme: pill.theme; pace: "morph" } }
        }
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: pill.meetings.timeText(pill.meetings.elapsed)
        color: pill.meetings.ended ? pill.endInk : pill.ink
        Behavior on color { MotionColorAnimation { theme: pill.theme } }
        font.family: pill.theme.textFontFamily
        font.pixelSize: pill.theme.px(13)
        font.weight: Font.DemiBold
        font.features: { "tnum": 1, "case": 1 }
        font.letterSpacing: -0.2
      }
    }

    // Grown, and as the call starts, the app's icon and name take the
    // clock's place between them.
    Row {
      anchors.centerIn: parent
      spacing: 6
      opacity: (pill.meetings.expanded || pill.meetings.intro) && !pill.meetings.ended ? 1 : 0
      Behavior on opacity { MotionAnimation { theme: pill.theme; pace: "fade"; curve: "fade" } }
      Image {
        id: appIcon
        anchors.verticalCenter: parent.verticalCenter
        visible: status === Image.Ready
        width: 18
        height: 18
        sourceSize.width: 36
        sourceSize.height: 36
        source: pill.meetings.callIcon
        asynchronous: true
        smooth: true
        mipmap: true
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, pill.width - 150 - (appIcon.visible ? appIcon.width + parent.spacing : 0))
        elide: Text.ElideRight
        text: pill.meetings.callName
        color: "#e2e6de"
        font.family: pill.theme.textFontFamily
        font.pixelSize: pill.theme.px(14)
        font.weight: Font.DemiBold
        font.letterSpacing: -0.3
      }
    }

    // The waveform, as Apple's: rounded bars about the middle line, moving
    // together with the voice and settling into dots in silence; dim while
    // muted.
    Row {
      anchors.right: parent.right
      anchors.rightMargin: 17 + (pill.meetings.inset + 5 - 17) * pill.grow
      anchors.verticalCenter: parent.verticalCenter
      spacing: 2.5
      // Dimmed apart from the reveal, so muting fades while the reveal
      // drives the opacity frame by frame.
      property real dim: pill.meetings.micMuted ? 0.4 : 1
      Behavior on dim { MotionAnimation { theme: pill.theme; pace: "fade"; curve: "fade" } }
      opacity: dim * reveal.trailingIn
      PillPart { progress: reveal.trailingIn }
      Repeater {
        model: pill.meetings.meterBars
        delegate: Rectangle {
          id: bar
          required property int index
          readonly property real level: pill.meetings.levels[index] || 0
          anchors.verticalCenter: parent.verticalCenter
          width: 3
          // Whole pixels, so a change too small to see isn't drawn.
          height: Math.round(3 + level * 15)
          radius: 1.5
          color: pill.ink
          // Ended, the dots fold away one after another, from the first,
          // ahead of "Call Ended" coming in; back all at once.
          property real shown: pill.meetings.ended ? 0 : 1
          Behavior on shown {
            SequentialAnimation {
              PauseAnimation { duration: pill.meetings.ended ? pill.theme.scaled(bar.index * 20) : 0 }
              MotionAnimation { theme: pill.theme; pace: "fade"; curve: "exit" }
            }
          }
          opacity: shown
          scale: shown
        }
      }
    }

    // Ended, "Call Ended" in the waveform's place.
    Text {
      id: endedLabel
      anchors.right: parent.right
      anchors.rightMargin: 16
      anchors.verticalCenter: parent.verticalCenter
      text: "Call Ended"
      color: pill.endInk
      // In from the right after the dots, as they leave.
      property real shown: pill.meetings.ended ? 1 : 0
      Behavior on shown {
        SequentialAnimation {
          PauseAnimation { duration: pill.meetings.ended ? pill.theme.contentRevealDelay + pill.theme.scaled(60) : 0 }
          MotionAnimation { theme: pill.theme; pace: "morph" }
        }
      }
      transform: Translate { x: 10 * (1 - endedLabel.shown) }
      font.family: pill.theme.textFontFamily
      font.pixelSize: pill.theme.px(13)
      font.weight: Font.DemiBold
      font.letterSpacing: -0.2
      opacity: shown
    }
  }

  // The controls, spread across the pill within its inset, rising in one
  // after another as it grows, and leaving together as it shrinks.
  Row {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: top.bottom
    anchors.topMargin: 4
    spacing: (pill.width - 2 * pill.meetings.inset - 4 * pill.meetings.buttonSize) / 3

    CallButton {
      order: 0
      icon: "mic"
      on: pill.meetings.micMuted
      tip: on ? "Unmute" : "Mute"
      onClicked: pill.meetings.toggleMic()
    }
    CallButton {
      order: 1
      icon: "video"
      on: !pill.meetings.cameraOn
      tip: pill.tip("camera", on ? "Turn Camera On" : "Turn Camera Off", "for the camera")
      onClicked: pill.meetings.act("camera")
    }
    CallButton {
      order: 2
      icon: "display"
      on: pill.meetings.sharing
      slashes: false
      tip: pill.tip("share", on ? "Stop Sharing" : "Share Screen", on ? "to stop sharing" : "to share")
      onClicked: pill.meetings.act("share")
    }
    CallButton {
      order: 3
      icon: "phone.down"
      hangUp: true
      tip: pill.tip("hangup", "End Call", "to hang up")
      onClicked: pill.meetings.act("hangup")
    }
  }

  // A round button as FaceTime's: grey with a white glyph, white with a
  // dark one (struck through, unless `slashes` is off) while it's on; the
  // hang-up one red. Each is lit softly from above, with a hairline rim.
  // Its colours are solid, so the slash's gap can be cut in the button's
  // own colour.
  component CallButton: Rectangle {
    id: button
    property int order: 0
    property string icon: ""
    property string tip: ""
    property bool on: false
    property bool slashes: true
    property bool hangUp: false
    signal clicked()
    readonly property real lift: mouse.containsMouse ? 0.07 : 0
    property color base: hangUp ? Qt.tint("#ff3b30", Qt.rgba(1, 1, 1, lift * 1.4))
      : on ? Qt.tint("#ffffff", Qt.rgba(0, 0, 0, lift))
      : Qt.tint(pill.theme.background, Qt.rgba(1, 1, 1, 0.18 + lift))
    width: pill.meetings.buttonSize
    height: width
    radius: width / 2
    color: base
    gradient: Gradient {
      GradientStop { position: 0; color: Qt.tint(button.base, Qt.rgba(1, 1, 1, button.on && !button.hangUp ? 0 : 0.06)) }
      GradientStop { position: 1; color: Qt.tint(button.base, Qt.rgba(0, 0, 0, button.on && !button.hangUp ? 0.07 : 0.04)) }
    }
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, button.on && !button.hangUp ? 0 : 0.07)
    Behavior on base { MotionColorAnimation { theme: pill.theme } }

    // In after the ones before it; out all at once.
    property real reveal: pill.meetings.expanded ? 1 : 0
    Behavior on reveal {
      SequentialAnimation {
        PauseAnimation { duration: pill.meetings.expanded ? pill.theme.contentRevealDelay + pill.theme.scaled(button.order * 19) : 0 }
        MotionAnimation { theme: pill.theme; pace: pill.meetings.expanded ? "morph" : "exit" }
      }
    }
    opacity: reveal
    visible: reveal > 0.01
    property real press: mouse.pressed ? 0.92 : 1
    Behavior on press { MotionAnimation { theme: pill.theme; pace: "press" } }
    scale: (0.82 + 0.18 * reveal) * press
    transform: Translate { y: (1 - button.reveal) * 7 }

    CallIcon {
      anchors.centerIn: parent
      theme: pill.theme
      name: button.icon
      size: button.hangUp ? 28 : 25
      color: button.on && !button.hangUp ? "#1c1c1e" : "#ffffff"
      Behavior on color { MotionColorAnimation { theme: pill.theme } }
      knockout: button.base
      slashed: button.on && button.slashes
    }
    MouseArea {
      id: mouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: button.clicked()
    }
    Tooltip { theme: pill.theme; text: button.tip }
  }
}

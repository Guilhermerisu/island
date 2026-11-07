import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Wayland
import "../../components"

// Now-playing view, opened from the media pill's cover or wave: cover, title
// and artist, the live sound wave, a seekable progress bar with elapsed and
// remaining time, transport controls, shuffle and a shortcut to the player's
// window. Keys: Space play/pause, S shuffle, ←/→ seek 10 s, Esc close.
Item {
  id: player
  required property var host
  property bool active: false

  readonly property var mpris: host.nowPlaying.player
  readonly property bool playing: !!(mpris && mpris.isPlaying)
  readonly property real length: mpris && mpris.lengthSupported ? mpris.length : 0
  readonly property bool canSeek: !!(mpris && mpris.canSeek && length > 0)
  property real position: 0
  property bool dragging: false

  readonly property bool canShuffle: !!(mpris && mpris.canControl && mpris.shuffleSupported)
  // The player's desktop entry. Chromium-based players (Electron apps)
  // report an empty desktopEntry, so fall back to a heuristic lookup on the
  // identity. Reading the applications list makes it re-run once it loads.
  readonly property var appEntry: {
    DesktopEntries.applications.values
    if (!mpris) return null
    var de = String(mpris.desktopEntry || ""), id = String(mpris.identity || "")
    return (de !== "" ? DesktopEntries.byId(de) || DesktopEntries.heuristicLookup(de) : null)
      || (id !== "" ? DesktopEntries.heuristicLookup(id) : null)
  }
  // The player's window, from the compositor's live toplevel list, which
  // follows windows opening later. Exact matches only, so a
  // browser is never mistaken for another app: the app id or its last
  // segment (com.spotify.Client -> client) against the names the player and
  // its desktop entry go by, most specific first so a generic name such as
  // "chromium" only counts when nothing better matches.
  readonly property var appWindow: {
    var tl = ToplevelManager.toplevels.values
    if (!mpris) return null
    var dbus = String(mpris.dbusName || "").replace(/^org\.mpris\.MediaPlayer2\./, "").replace(/\.instance.*$/, "")
    var names = [mpris.desktopEntry, appEntry ? appEntry.id : "", appEntry ? appEntry.startupClass : "", mpris.identity, dbus]
    for (var n = 0; n < names.length; n++) {
      var name = String(names[n] || "").toLowerCase()
      if (name === "") continue
      for (var i = 0; i < tl.length; i++) {
        var cls = String(tl[i].appId || "").toLowerCase()
        if (cls !== "" && (cls === name || cls.substring(cls.lastIndexOf(".") + 1) === name)) return tl[i]
      }
    }
    return null
  }
  readonly property bool canOpenApp: !!(appWindow || (mpris && mpris.canRaise) || appEntry)

  implicitHeight: layout.implicitHeight

  onActiveChanged: {
    if (!active) return
    position = mpris ? mpris.position : 0
    Qt.callLater(function() { player.forceActiveFocus() })
  }
  // Mpris only reports position on seeks; re-read it while open and playing
  // so the bar and times glide. 30 Hz is smooth for a bar that moves a pixel
  // or two a second, without redrawing the island every display frame.
  Timer {
    interval: 33
    repeat: true
    running: player.active && player.playing && !player.dragging
    onTriggered: player.position = player.mpris ? player.mpris.position : 0
  }
  Connections {
    target: player.mpris
    function onPositionChanged() { if (!player.dragging) player.position = player.mpris.position }
  }

  function action(name) { if (host.nowPlaying.service) host.nowPlaying.service.runAction(name, false, "") }
  function toggleShuffle() { if (canShuffle) mpris.shuffle = !mpris.shuffle }
  // Close first so the app, not the island, gets the keyboard; focus follows
  // after the island's layer has let go of it. Window, else the player's own
  // Raise, else its desktop entry (single-instance apps bring their window
  // up when launched again).
  function openApp() {
    var win = appWindow
    host.view = "rest"
    if (win) { focusTimer.win = win; focusTimer.restart() }
    else if (mpris && mpris.canRaise) mpris.raise()
    else if (appEntry) appEntry.execute()
  }
  Timer {
    id: focusTimer
    property var win: null
    interval: 150
    onTriggered: {
      if (!win) return
      win.activate()
      // On Hyprland 0.56 activate() only focuses a window on the current
      // workspace; this Lua-config dispatch (the form Omarchy's own scripts
      // use) is what brings its workspace up. Matched on the live app id, not
      // on Hyprland's client list, so nothing here goes stale.
      Hyprland.dispatch('hl.dsp.focus({ window = "class:' + String(win.appId).replace(/["\\]/g, "") + '" })')
    }
  }
  function seekTo(seconds) {
    if (!canSeek) return
    var target = Math.max(0, Math.min(length, seconds))
    mpris.position = target
    position = target
  }
  function clock(seconds) {
    var s = Math.max(0, Math.floor(seconds || 0))
    var m = Math.floor(s / 60), r = s % 60
    return m + ":" + (r < 10 ? "0" : "") + r
  }

  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Space) { action("playPause"); event.accepted = true }
    else if (event.key === Qt.Key_S) { toggleShuffle(); event.accepted = true }
    else if (event.key === Qt.Key_Left) { seekTo(position - 10); event.accepted = true }
    else if (event.key === Qt.Key_Right) { seekTo(position + 10); event.accepted = true }
    else if (event.key === Qt.Key_Escape) { host.view = "rest"; event.accepted = true }
  }

  ColumnLayout {
    id: layout
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    spacing: 0

    // ---------- Cover, title, wave ----------

    RowLayout {
      Layout.fillWidth: true
      spacing: 16

      ClippingRectangle {
        Layout.preferredWidth: 72
        Layout.preferredHeight: 72
        radius: 16
        color: "transparent"
        id: coverBox
        // Two covers taking turns: a new track's art loads into the hidden
        // one and fades in over the old, so changing tracks never flashes
        // the fallback in between.
        readonly property string art: player.host.nowPlaying.art
        property Image front: coverA
        readonly property Image back: front === coverA ? coverB : coverA
        readonly property bool hasArt: art !== "" && (front.status === Image.Ready || back.status === Image.Ready)
        onArtChanged: {
          if (art === front.source.toString()) { back.source = ""; return }
          back.source = art
        }
        Component.onCompleted: front.source = art
        function arrived(cover) {
          if (cover !== back || cover.status !== Image.Ready) return
          cover.opacity = 0
          front = cover
          coverIn.target = cover
          coverIn.restart()
        }
        ArtFallback {
          anchors.fill: parent
          host: player.host
          glyphSize: 30
          visible: !coverBox.hasArt
        }
        component Cover: Image {
          id: c
          anchors.fill: parent
          sourceSize.width: 144
          sourceSize.height: 144
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          cache: false
          visible: status === Image.Ready && coverBox.art !== ""
          z: c === coverBox.front ? 1 : 0
          onStatusChanged: coverBox.arrived(c)
        }
        Cover { id: coverA }
        Cover { id: coverB }
        MotionAnimation {
          id: coverIn
          theme: player.host.theme
          property: "opacity"
          to: 1
          pace: "fade"
          curve: "fade"
          // Once it's in, the old cover underneath is let go (unless it's
          // already loading the next track's).
          onFinished: if (coverBox.back.source.toString() !== coverBox.art) coverBox.back.source = ""
        }
      }
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 2
        Text {
          Layout.fillWidth: true
          text: player.mpris ? String(player.mpris.trackTitle || "Unknown track") : "Nothing playing"
          textFormat: Text.PlainText
          elide: Text.ElideRight
          color: "#ffffff"
          font.family: player.host.theme.textFontFamily
          font.letterSpacing: player.host.theme.tracking(player.host.theme.textFontFamily, player.host.theme.px(17))
          font.pixelSize: player.host.theme.px(17)
          font.weight: Font.DemiBold
        }
        Text {
          Layout.fillWidth: true
          visible: text !== ""
          text: player.mpris ? String(player.mpris.trackArtist || player.mpris.identity || "") : ""
          textFormat: Text.PlainText
          elide: Text.ElideRight
          color: Qt.rgba(1, 1, 1, 0.55)
          font.family: player.host.theme.textFontFamily
          font.letterSpacing: player.host.theme.tracking(player.host.theme.textFontFamily, player.host.theme.px(15))
          font.pixelSize: player.host.theme.px(15)
        }
      }
      SoundWave {
        Layout.alignment: Qt.AlignTop
        Layout.topMargin: 10
        color: player.host.nowPlaying.tint
        playing: player.active && player.playing
        barWidth: 3.5
        maxHeight: 24
      }
    }

    // ---------- Progress ----------

    RowLayout {
      Layout.fillWidth: true
      Layout.topMargin: 22
      spacing: 12
      visible: player.length > 0

      Text {
        text: player.clock(player.position)
        color: Qt.rgba(1, 1, 1, 0.55)
        font.family: player.host.theme.textFontFamily
        font.letterSpacing: player.host.theme.tracking(player.host.theme.textFontFamily, player.host.theme.px(12))
        font.pixelSize: player.host.theme.px(12)
        font.weight: Font.Medium
        font.features: { "tnum": 1 }
      }
      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 18
        Rectangle {
          id: track
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width
          height: 6
          radius: 3
          color: Qt.rgba(1, 1, 1, 0.16)
          Rectangle {
            height: parent.height
            radius: parent.radius
            width: player.length > 0 ? parent.width * Math.max(0, Math.min(1, player.position / player.length)) : 0
            color: Qt.rgba(1, 1, 1, 0.6)
          }
        }
        MouseArea {
          anchors.fill: parent
          enabled: player.canSeek
          cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
          function at(x) { return Math.max(0, Math.min(1, x / width)) * player.length }
          onPressed: function(e) { player.dragging = true; player.position = at(e.x) }
          onPositionChanged: function(e) { if (pressed) player.position = at(e.x) }
          onReleased: function(e) { player.dragging = false; player.seekTo(at(e.x)) }
        }
      }
      Text {
        text: "−" + player.clock(player.length - player.position)
        color: Qt.rgba(1, 1, 1, 0.55)
        font.family: player.host.theme.textFontFamily
        font.letterSpacing: player.host.theme.tracking(player.host.theme.textFontFamily, player.host.theme.px(12))
        font.pixelSize: player.host.theme.px(12)
        font.weight: Font.Medium
        font.features: { "tnum": 1 }
      }
    }

    // ---------- Controls ----------

    Item {
      Layout.fillWidth: true
      Layout.topMargin: player.length > 0 ? 16 : 22
      Layout.preferredHeight: 48

      component Control: Text {
        id: control
        property string name: ""
        property bool available: true
        signal activated()
        color: "#ffffff"
        opacity: available ? (controlMouse.pressed ? 0.6 : 1) : 0.35
        Behavior on opacity { MotionAnimation { theme: player.host.theme; pace: "quick"; curve: "fade" } }
        font.family: player.host.theme.fontFamily
        scale: controlMouse.pressed ? 0.94 : 1
        Behavior on scale { MotionAnimation { theme: player.host.theme; pace: controlMouse.pressed ? "press" : "standard" } }
        MouseArea {
          id: controlMouse
          anchors.fill: parent
          anchors.margins: -10
          enabled: control.available
          cursorShape: Qt.PointingHandCursor
          onClicked: control.activated()
        }
        Tooltip { theme: player.host.theme; text: control.name; above: true }
      }

      // Shuffle and open-app hang off the sides of the transport row, so
      // Previous / Play / Next stay centred whatever their glyph widths.
      Control {
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: transport.left
        anchors.rightMargin: 46
        text: "󰒟"
        name: !player.canShuffle && player.mpris ? "Shuffle isn't supported by " + String(player.mpris.identity || "this player")
          : player.mpris && player.mpris.shuffle ? "Shuffle: on" : "Shuffle: off"
        color: player.mpris && player.mpris.shuffle ? player.host.nowPlaying.tint : Qt.rgba(1, 1, 1, 0.6)
        font.pixelSize: player.host.theme.px(26)
        available: player.canShuffle
        onActivated: player.toggleShuffle()
      }
      Control {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: transport.right
        anchors.leftMargin: 46
        text: "󰏌"
        name: "Open " + (player.mpris ? String(player.mpris.identity || player.mpris.desktopEntry || "app") : "app")
        color: Qt.rgba(1, 1, 1, 0.6)
        font.pixelSize: player.host.theme.px(26)
        available: player.canOpenApp
        onActivated: player.openApp()
      }

      Row {
        id: transport
        anchors.centerIn: parent
        spacing: 46
        Control {
          anchors.verticalCenter: parent.verticalCenter
          text: "󰑟"
          name: "Previous"
          font.pixelSize: player.host.theme.px(34)
          available: !!(player.mpris && player.mpris.canGoPrevious)
          onActivated: player.action("previous")
        }
        Control {
          anchors.verticalCenter: parent.verticalCenter
          text: player.playing ? "󰏤" : "󰐊"
          name: player.playing ? "Pause" : "Play"
          font.pixelSize: player.host.theme.px(42)
          available: !!player.mpris
          onActivated: player.action("playPause")
        }
        Control {
          anchors.verticalCenter: parent.verticalCenter
          text: "󰈑"
          name: "Next"
          font.pixelSize: player.host.theme.px(34)
          available: !!(player.mpris && player.mpris.canGoNext)
          onActivated: player.action("next")
        }
      }
    }
  }
}

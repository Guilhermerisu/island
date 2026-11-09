import QtQuick

// The album art playing, in two covers taking turns: a new track's art loads
// into the hidden one and fades in over the old, so changing tracks never
// flashes the fallback in between.
Item {
  id: coverBox
  required property var host
  // The art's pixel size; it's drawn as big as this item.
  property int imageSize: 144
  property alias glyphSize: fallback.glyphSize
  readonly property string art: host.nowPlaying.art
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
    id: fallback
    anchors.fill: parent
    host: coverBox.host
    visible: !coverBox.hasArt
  }
  component Cover: Image {
    id: c
    anchors.fill: parent
    sourceSize.width: coverBox.imageSize
    sourceSize.height: coverBox.imageSize
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    // Browsers rewrite and delete their cover files as tracks change; never
    // hold on to a cached copy of one.
    cache: false
    visible: status === Image.Ready && coverBox.art !== ""
    z: c === coverBox.front ? 1 : 0
    onStatusChanged: coverBox.arrived(c)
  }
  Cover { id: coverA }
  Cover { id: coverB }
  MotionAnimation {
    id: coverIn
    theme: coverBox.host.theme
    property: "opacity"
    to: 1
    pace: "fade"
    curve: "fade"
    // Once it's in, the old cover underneath is let go (unless it's
    // already loading the next track's).
    onFinished: if (coverBox.back.source.toString() !== coverBox.art) coverBox.back.source = ""
  }
}

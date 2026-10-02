import QtQuick

// A colour weather icon for a WMO code, built from layers: the sun (or the
// moon at night) peeking out, a front cloud and a darker one behind it, and
// rain, snow, or a bolt under them. Layer positions are shares of `size`.
Item {
  id: icon
  property int code: 0
  property bool day: true
  property real size: 48
  property string fontFamily: ""
  implicitWidth: size
  implicitHeight: size

  readonly property string kind: {
    if (code <= 0) return "clear"
    if (code <= 2) return "partly"
    if (code === 3) return "cloudy"
    if (code === 45 || code === 48) return "fog"
    if (code >= 95) return "storm"
    if ((code >= 71 && code <= 77) || code === 85 || code === 86) return "snow"
    if (code >= 80 && code <= 82) return "showers"
    return "rain"
  }
  readonly property bool hasOrb: kind === "clear" || kind === "partly" || kind === "showers"
  readonly property bool hasCloud: kind !== "clear" && kind !== "fog"
  readonly property bool hasBackCloud: kind === "cloudy" || kind === "rain" || kind === "storm" || kind === "snow"
  readonly property bool falling: kind === "rain" || kind === "showers" || kind === "storm" || kind === "snow"
  // Clouds sit higher when something falls from them.
  readonly property real cloudY: falling ? 0.46 : 0.6

  readonly property string cloudGlyph: String.fromCodePoint(0xF015F)
  readonly property string moonGlyph: String.fromCodePoint(0xF0F65)
  readonly property string boltGlyph: String.fromCodePoint(0xF0241)
  readonly property string snowGlyph: String.fromCodePoint(0xF0717)
  readonly property string fogGlyph: String.fromCodePoint(0xF0591)

  component Layer: Text {
    required property real cx
    required property real cy
    required property real share
    x: icon.size * cx - width / 2
    y: icon.size * cy - height / 2
    width: icon.size * share
    height: icon.size * share
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    font.family: icon.fontFamily
    font.pixelSize: Math.round(icon.size * share)
  }

  // The sun, or the moon.
  Item {
    visible: icon.hasOrb
    readonly property bool alone: icon.kind === "clear"
    readonly property real share: alone ? 0.56 : icon.kind === "showers" ? 0.36 : 0.42
    readonly property real cx: alone ? 0.5 : 0.64
    readonly property real cy: alone ? 0.5 : icon.kind === "showers" ? 0.3 : 0.36
    width: icon.size * share
    height: width
    x: icon.size * cx - width / 2
    y: icon.size * cy - height / 2
    Rectangle {
      visible: icon.day
      anchors.fill: parent
      radius: width / 2
      gradient: Gradient {
        GradientStop { position: 0; color: "#ffd84d" }
        GradientStop { position: 1; color: "#ffc300" }
      }
    }
    Text {
      visible: !icon.day
      anchors.centerIn: parent
      text: icon.moonGlyph
      color: "#b9a3ff"
      font.family: icon.fontFamily
      font.pixelSize: Math.round(parent.width * (parent.alone ? 1.5 : 1.15))
    }
  }

  Layer {
    visible: icon.kind === "fog"
    cx: 0.5; cy: 0.5; share: 0.82
    text: icon.fogGlyph
    color: "#aeb4bf"
  }

  Layer {
    visible: icon.hasBackCloud
    cx: 0.62; cy: icon.cloudY - 0.12; share: 0.66
    text: icon.cloudGlyph
    color: icon.kind === "storm" ? "#5d6370" : "#8a909c"
  }
  Layer {
    visible: icon.hasCloud
    cx: 0.44; cy: icon.cloudY; share: 0.8
    text: icon.cloudGlyph
    color: icon.kind === "storm" ? "#a3a9b4" : icon.hasBackCloud ? "#dfe3ea" : "#f2f4f8"
    opacity: icon.hasOrb ? 0.94 : 1
  }

  // Rain: short slanted drops under the cloud.
  Repeater {
    model: icon.kind === "rain" || icon.kind === "showers" ? [0.3, 0.46, 0.62] : []
    delegate: Rectangle {
      required property real modelData
      width: Math.max(2, icon.size * 0.065)
      height: icon.size * 0.15
      radius: width / 2
      x: icon.size * modelData - width / 2
      y: icon.size * 0.76
      rotation: 18
      color: "#5ac8fa"
    }
  }
  Repeater {
    model: icon.kind === "snow" ? [0.3, 0.48, 0.66] : []
    delegate: Layer {
      required property real modelData
      cx: modelData; cy: 0.86; share: 0.2
      text: icon.snowGlyph
      color: "#e6f2ff"
    }
  }
  Layer {
    visible: icon.kind === "storm"
    cx: 0.46; cy: 0.8; share: 0.4
    text: icon.boltGlyph
    color: "#ffd60a"
  }
}

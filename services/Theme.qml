import QtQuick
import Quickshell.Io
import qs.Commons

// The island's colours, font and motion speed. The island is always black;
// text and accents come from the Omarchy theme, flipped when the theme's text
// is dark so it stays readable on black.
Item {
  id: theme
  required property var settings
  required property string home

  readonly property string fontFamily: "monospace"
  readonly property color background: "#000000"
  readonly property bool textIsLight: luminance(Color.foreground) > 0.5
  readonly property color text: textIsLight ? Color.foreground : Color.background
  readonly property color muted: textIsLight ? Color.muted : withAlpha(text, 0.6)
  readonly property color accent: Color.accent
  readonly property color accentText: contrastOn(Color.accent)
  readonly property color urgent: Color.urgent
  readonly property color surface: Qt.tint(background, withAlpha(text, 0.07))
  readonly property real motionScale: settings.motionScale > 0 ? settings.motionScale : 1.5
  // Shared timing keeps pill content fades consistent at every speed.
  readonly property int feedbackFadeDuration: Math.round(100 * motionScale)
  // The current Omarchy theme's name, for the theme and wallpaper switchers.
  property string name: ""

  function withAlpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
  function luminance(x) { return 0.2126 * x.r + 0.7152 * x.g + 0.0722 * x.b }
  function contrastOn(c) {
    var l = luminance(c)
    return Math.abs(l - luminance(background)) > Math.abs(l - luminance(text)) ? background : text
  }

  FileView {
    path: theme.home + "/.local/state/omarchy/current/theme.name"
    watchChanges: true
    printErrors: false
    onLoaded: theme.name = text().trim()
    onFileChanged: reload()
  }
}

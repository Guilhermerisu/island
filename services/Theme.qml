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
  // Text family for the island's surfaces: its own, Omarchy's (the menu font,
  // so `omarchy font set` and OMARCHY_MENU_FONT carry over), or a custom one.
  readonly property string pluginFont: "Adwaita Sans"
  readonly property string textFontFamily: {
    var mode = settings.textFontMode || "island"
    if (mode === "omarchy") return Style.font.menuFamily || Style.font.family || pluginFont
    var custom = String(settings.customFont || "").trim()
    if (mode === "custom" && custom) return custom
    return pluginFont
  }
  readonly property color background: "#000000"
  readonly property bool textIsLight: luminance(Color.foreground) > 0.5
  readonly property color text: textIsLight ? Color.foreground : Color.background
  readonly property color muted: textIsLight ? Color.muted : withAlpha(text, 0.6)
  readonly property color accent: Color.accent
  readonly property color accentText: contrastOn(Color.accent)
  readonly property color urgent: Color.urgent
  readonly property color surface: Qt.tint(background, withAlpha(text, 0.07))
  readonly property real motionScale: settings.motionScale > 0 ? settings.motionScale : 1.5
  // Motion roles share one cadence at every user-selected speed. Curves end
  // with a soft landing; geometry stays inside its bounds without bouncing.
  readonly property var motionDurations: ({
    press: 65, quick: 110, standard: 170, expressive: 220,
    morph: 240, collapse: 190, fade: 110, exit: 90
  })
  readonly property int feedbackFadeDuration: motionDuration("fade")
  readonly property int contentRevealDelay: Math.round(45 * motionScale)
  function motionDuration(pace) {
    return Math.round((motionDurations[pace] || motionDurations.standard) * motionScale)
  }
  function motionCurve(curve) {
    if (curve === "morph") return [0.22, 0.8, 0.24, 1, 1, 1]
    if (curve === "fade") return [0.2, 0, 0.2, 1, 1, 1]
    if (curve === "exit") return [0.4, 0, 1, 1, 1, 1]
    return [0.16, 1, 0.3, 1, 1, 1]
  }
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

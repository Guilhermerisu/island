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
  // One knob for every text size in the island: sizes are written as the
  // value at 1.0 and passed through px().
  readonly property real textScale: settings.textScale > 0 ? settings.textScale : 1
  function px(size) { return Math.max(1, Math.round(size * textScale)) }
  // Letter spacing for the island's own font (Adwaita Sans, drawn from
  // Inter): Inter's size-based tracking, a touch looser below 12px and
  // tighter as text grows, as macOS does. Other fonts keep their spacing.
  function tracking(family, size) {
    if (family !== pluginFont || !(size > 0)) return 0
    return size * (-0.0223 + 0.185 * Math.exp(-0.1745 * size))
  }
  readonly property color background: "#000000"
  readonly property bool textIsLight: luminance(Color.foreground) > 0.5
  readonly property color text: textIsLight ? Color.foreground : Color.background
  readonly property color muted: textIsLight ? Color.muted : withAlpha(text, 0.6)
  readonly property color accent: Color.accent
  // Apple's dark-mode system colours, for what keeps its meaning whatever
  // the Omarchy theme: status, colourful live activities, charts.
  readonly property var system: ({
    red: "#ff453a", orange: "#ff9f0a", yellow: "#ffd60a", green: "#30d158", cyan: "#64d2ff",
    blue: "#0a84ff", indigo: "#5e5ce6", purple: "#bf5af2", gray: "#8e8e93"
  })
  readonly property color accentText: contrastOn(Color.accent)
  readonly property color urgent: Color.urgent
  readonly property color surface: card
  // The island's greys: a few text-tint levels every view shares, so a card,
  // a hover or a divider is the same grey everywhere. `fill()` is see-through
  // (for hovers and edges laid over anything); `solid()` is that grey on the
  // black island. Accent tints follow the same idea with `accentFill()`.
  readonly property var greys: ({ quiet: 0.05, subtle: 0.08, raised: 0.12, strong: 0.16, stronger: 0.22 })
  readonly property var accentTints: ({ soft: 0.18, medium: 0.3, ring: 0.5 })
  function fill(level) { return withAlpha(text, greys[level]) }
  function solid(level) { return Qt.tint(background, fill(level)) }
  function accentFill(level) { return withAlpha(accent, accentTints[level]) }
  readonly property color secondary: Qt.tint(background, withAlpha(text, 0.6))
  // Neutral (not theme-tinted) grey for placeholders and the search glyph.
  readonly property color placeholder: Qt.tint(background, withAlpha(text, 0.38))
  readonly property color card: solid("subtle")
  readonly property color tile: solid("raised")
  readonly property color well: solid("strong")
  readonly property color wellHover: solid("stronger")
  readonly property color hairline: fill("subtle")
  // Corner radii, so a corner is the same size everywhere. A box sitting
  // directly in an open view (a card, a group, a list) is concentric with
  // the island: its 30 radius minus the usual 16 padding.
  readonly property var radii: ({ tiny: 4, small: 6, medium: 8, large: 10, card: 14 })
  readonly property real motionScale: settings.motionScale > 0 ? settings.motionScale : 1.5
  // Motion roles share one cadence at every user-selected speed. Curves end
  // with a soft landing; geometry stays inside its bounds, except the
  // island itself, which swings a touch past its size as it grows
  // (morphBounce) and lands flat as it shrinks.
  readonly property var motionDurations: ({
    press: 65, quick: 110, standard: 170, expressive: 220,
    morph: 240, collapse: 190, fade: 110, exit: 90,
    data: 330
  })
  readonly property int feedbackFadeDuration: motionDuration("fade")
  readonly property int contentRevealDelay: Math.round(45 * motionScale)
  // How far the island's height trails its width as it grows (and the width
  // trails the height as it shrinks), so it morphs as one shape.
  readonly property int morphLag: Math.round(28 * motionScale)
  readonly property real morphBounce: 0.2
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

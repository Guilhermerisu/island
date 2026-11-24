import QtQuick
import QtTest
import qs.Commons as Commons
import "../services"

TestCase {
  name: "ThemeContrast"

  Theme {
    id: theme
    home: "/nonexistent"
    settings: ({ themeBackground: false })
  }

  function init() { Commons.Color.accent = "#8d8d8d"; theme.settings = { themeBackground: false } }

  function test_contrastRatio() {
    fuzzyCompare(theme.contrastRatio("#000000", "#ffffff"), 21, 0.01)
    fuzzyCompare(theme.contrastRatio("#ffffff", "#000000"), 21, 0.01)
    fuzzyCompare(theme.contrastRatio("#777777", "#777777"), 1, 0.001)
    fuzzyCompare(theme.contrastRatio("#8d8d8d", "#000000"), 6.33, 0.02)
  }

  function test_keepsSaturatedAccentOnBlack() {
    // Orange and red accents a 4.5:1 rule against raised cards would drop.
    Commons.Color.accent = "#d65d0e"
    compare(theme.accent, Qt.color("#d65d0e"))
    Commons.Color.accent = "#e06c75"
    compare(theme.accent, Qt.color("#e06c75"))
  }

  function test_keepsAccentOnLightTheme() {
    Commons.Color.background = "#fafafa"
    theme.settings = { themeBackground: true }
    Commons.Color.accent = "#1e66f5"
    compare(theme.text, Qt.color("#1a1a1a"))
    compare(theme.accent, Qt.color("#1e66f5"))
    Commons.Color.background = "#101315"
  }

  function test_fallsBackWhenAccentUnreadable() {
    Commons.Color.accent = "#111111"
    compare(theme.accent, theme.text)
  }

  function test_fallsBackWhenAccentMissing() {
    Commons.Color.accent = undefined
    compare(theme.accent, theme.text)
  }

  function test_inkPicksIslandFillOrLabel() {
    Commons.Color.accent = "#8d8d8d"
    compare(theme.accentText, theme.background)
    compare(theme.contrastOn(Qt.color("#203060")), theme.text)
  }
}

import QtQuick
import QtTest
import "../views/settings/controls"

TestCase {
  id: test
  name: "AgentSelection"
  when: windowShown
  visible: true
  width: 500
  height: 300

  QtObject {
    id: theme
    property string textFontFamily: "sans-serif"
    property string fontFamily: "sans-serif"
    property var radii: ({ small: 4 })
    function px(n) { return n }
    function tracking(family, size) { return 0 }
    function fill(level) { return "#333333" }
    function solid(level) { return "#222222" }
    function motionDuration(pace) { return 0 }
    function motionCurve(curve) { return [0.16, 1, 0.3, 1, 1, 1] }
  }
  Item {
    id: view
    anchors.fill: parent
    property var host: ({ theme: theme })
    property int controlWidth: 160
    property int detailFontSize: 14
    property color text: "white"
    property color textMuted: "#cccccc"
    property color accent: "#4477aa"
    property color accentInk: "white"
    property alias menuButton: menu.button
    function openMenu(button) { menu.openFor(button) }

    SettingsPopUp {
      id: selector
      view: view
      x: 40; y: 80
      options: [{ label: "Claude", value: "claude" }, { label: "Codex", value: "codex" }, { label: "Gemini", value: "agy" }, { label: "All Models", value: "all" }]
      multiSelect: true
      onPicked: function(next) { value = next }
    }
    SettingsMenu { id: menu; view: view }
    SettingsSegmented {
      id: tabs
      view: view
      x: 40; y: 200
      options: selector.selectedValues.map(function(id) { return { label: id, value: id } })
      value: "claude"
      onPicked: function(next) { value = next }
    }
  }

  function init() { menu.button = null; selector.multiSelect = true; selector.value = "claude" }
  function choose(index, modifiers) {
    if (!menu.button) mouseClick(selector, 10, 10)
    tryCompare(menu, "opacity", 1)
    // Its rows are laid out on the next frame; clicked before, they all sit at the top.
    verify(waitForRendering(menu))
    mouseClick(menu, 35, 5 + index * 28 + 14, Qt.LeftButton, modifiers || Qt.NoModifier)
  }
  function test_mouse_selection() {
    compare(selector.currentLabel, "Claude")
    choose(1, Qt.ControlModifier)
    compare(selector.value, ["claude", "codex"])
    tryCompare(selector, "currentLabel", "Claude + Codex")
    compare(menu.button, selector)
    choose(2, Qt.ControlModifier)
    compare(selector.value, ["claude", "codex", "agy"])
    tryCompare(selector, "currentLabel", "Claude + Codex + Gemini")
    choose(3, Qt.ControlModifier)
    compare(selector.value, ["claude", "codex", "agy", "all"])
    choose(1, Qt.ControlModifier)
    compare(selector.value, ["claude", "agy", "all"])
    choose(3)
    compare(selector.value, ["all"])
    compare(menu.button, null)
    choose(3, Qt.ControlModifier)
    compare(selector.value, ["all"])
  }
  function test_other_popups_remain_single() {
    selector.multiSelect = false
    choose(2, Qt.ControlModifier)
    compare(selector.value, "agy")
    compare(menu.button, null)
  }
  function test_tabs_switch_without_changing_selection() {
    selector.value = ["claude", "codex", "agy", "all"]
    tabs.value = "claude"
    verify(waitForRendering(tabs))
    mouseClick(tabs, 2 + tabs.chipWidth * 1.5, 14)
    compare(tabs.value, "codex")
    compare(selector.value, ["claude", "codex", "agy", "all"])
    mouseClick(tabs, 2 + tabs.chipWidth * 2.5, 14)
    compare(tabs.value, "agy")
    mouseClick(tabs, 2 + tabs.chipWidth * 3.5, 14)
    compare(tabs.value, "all")
  }
}

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../controls"

ColumnLayout {
  id: page
  required property var view
  readonly property var settings: view.settings
  visible: view.currentPage === "Island Visibility"
  Layout.fillWidth: true
  spacing: 20

  component ToggleRow: SettingsRow {
    id: row
    required property string setting
    SettingsSwitch {
      view: page.view
      checked: page.settings[row.setting]
      onToggled: function(on) { page.settings[row.setting] = on }
    }
  }

  SettingsGroup {
    view: page.view
    title: "Hide automatically"
    ToggleRow {
      view: page.view
      setting: "autoHideEnabled"
      label: "Automatic hiding"
    }
    Repeater {
      model: [
        { setting: "autoHideFullscreen", label: "When a window is fullscreen" },
        { setting: "autoHideMaximized", label: "When a window is maximized" },
        { setting: "autoHideTiling", label: "When windows are tiled" },
        { setting: "autoHideFloating", label: "When there are floating windows" },
        { setting: "autoHideEmpty", label: "On an empty workspace" },
        { setting: "autoHideScreensaver", label: "While the screensaver is running" },
        { setting: "autoHideWithBar", label: "When the Omarchy bar is hidden" }
      ]
      delegate: ToggleRow {
        required property var modelData
        view: page.view
        setting: modelData.setting
        label: modelData.label
        enabled: page.settings.autoHideEnabled
        opacity: enabled ? 1 : 0.45
      }
    }
    SettingsRow {
      view: page.view
      label: "After inactivity"
      enabled: page.settings.autoHideEnabled
      opacity: enabled ? 1 : 0.45
      last: true
      SettingsPopUp {
        view: page.view
        value: page.settings.autoHideIdleSeconds
        options: [
          { label: "Off", value: 0 }, { label: "15 sec", value: 15 }, { label: "30 sec", value: 30 },
          { label: "1 min", value: 60 }, { label: "5 min", value: 300 }
        ]
        onPicked: function(seconds) { page.settings.autoHideIdleSeconds = seconds }
      }
    }
  }

  SettingsGroup {
    view: page.view
    title: "Reveal and manual hiding"
    ToggleRow {
      view: page.view
      setting: "hideOnRightClick"
      label: "Hide or reveal with right-click"
      detail: "Click the island to hide it. Right-click its position at the top to reveal it."
    }
    ToggleRow {
      view: page.view
      setting: "revealOnHover"
      label: "Reveal at the top edge"
      detail: "Hover at the top of the screen when the island is automatically hidden."
    }
    ToggleRow {
      view: page.view
      setting: "revealOnFeedback"
      label: "Show banners while hidden"
      detail: "Let notifications and status changes briefly reveal the island."
      last: true
    }
  }
}

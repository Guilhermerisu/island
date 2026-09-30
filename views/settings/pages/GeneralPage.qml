import QtQuick
import QtQuick.Layouts
import "../controls"

// Settings → General: the pill, appearance and motion.
ColumnLayout {
  id: page
  required property var view
  visible: view.currentPage === "General"
  Layout.fillWidth: true
  spacing: 20

  SettingsGroup {
    view: page.view
    title: "Pill"
    SettingsRow {
      view: page.view
      label: "Workspace Indicator"
      detail: "Show which workspace you're on when you switch"
      SettingsSwitch {
        view: page.view
        checked: page.view.settings.workspaceHud
        onToggled: function(on) { page.view.settings.workspaceHud = on }
      }
    }
    SettingsRow {
      view: page.view
      label: "Keyboard Layout Indicator"
      detail: "Show the layout when you switch keyboard languages"
      SettingsSwitch {
        view: page.view
        checked: page.view.settings.keyboardHud
        onToggled: function(on) { page.view.settings.keyboardHud = on }
      }
    }
    SettingsRow {
      view: page.view
      label: "24-Hour Clock"
      SettingsSwitch {
        view: page.view
        checked: page.view.settings.clock24h
        onToggled: function(on) { page.view.settings.clock24h = on }
      }
    }
    SettingsRow {
      view: page.view
      label: "Volume HUD"
      detail: "Show the level when the volume changes"
      SettingsSwitch {
        view: page.view
        checked: page.view.settings.volumeHud
        onToggled: function(on) { page.view.settings.volumeHud = on }
      }
    }
    SettingsRow {
      view: page.view
      label: "Notch Style"
      detail: "Attach the island to the top edge, like a MacBook notch"
      last: true
      SettingsSwitch {
        view: page.view
        checked: page.view.settings.notch
        onToggled: function(on) { page.view.settings.notch = on }
      }
    }
  }

  SettingsGroup {
    view: page.view
    title: "Appearance"
    SettingsRow {
      view: page.view
      label: "Colorful Sidebar Icons"
      detail: "Use macOS-style colors in the sidebar"
      last: true
      SettingsSwitch {
        view: page.view
        checked: page.view.settings.colorfulSettingsIcons
        onToggled: function(on) { page.view.settings.colorfulSettingsIcons = on }
      }
    }
  }

  SettingsGroup {
    view: page.view
    title: "Motion"
    SettingsRow {
      view: page.view
      label: "Animation Speed"
      SettingsPopUp {
        view: page.view
        options: [{ label: "Fast", value: 1 }, { label: "Normal", value: 1.5 }, { label: "Relaxed", value: 2 }]
        value: page.view.settings.motionScale
        onPicked: function(v) { page.view.settings.motionScale = v }
      }
    }
    SettingsRow {
      view: page.view
      label: "Hover Lift"
      detail: "The clock pill lifts slightly under the pointer"
      last: true
      SettingsSwitch {
        view: page.view
        checked: page.view.settings.hoverLift
        onToggled: function(on) { page.view.settings.hoverLift = on }
      }
    }
  }
}

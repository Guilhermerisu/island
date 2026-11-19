pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../../views/settings/controls"

ColumnLayout {
  id: page
  required property var view
  required property var todos
  property bool last: false
  property string message: ""
  property string delay: "15"
  property string result: ""
  readonly property int minutes: /^[0-9]{1,5}$/.test(delay) ? Number(delay) : 0
  readonly property bool ready: message.length > 0 && message.length <= 240
    && minutes >= 1 && minutes <= 10080 && !todos.schedulingReminder
  spacing: 0

  Connections {
    target: page.todos
    function onReminderFinished(success) {
      page.result = success ? "Reminder scheduled" : "Couldn’t schedule the reminder"
      if (success) page.message = ""
    }
  }

  SettingsRow {
    view: page.view
    label: "Reminder message"
    SettingsTextField {
      view: page.view
      placeholder: "Reminder message"
      value: page.message
      enabled: !page.todos.schedulingReminder
      onEdited: function(text) { page.message = text }
    }
  }
  SettingsRow {
    view: page.view
    label: "Remind in (minutes)"
    SettingsTextField {
      view: page.view
      implicitWidth: 85
      value: page.delay
      enabled: !page.todos.schedulingReminder
      onEdited: function(text) { page.delay = text }
    }
  }
  SettingsRow {
    view: page.view
    label: "Custom reminder"
    detail: page.result
    last: page.last
    SettingsButton {
      view: page.view
      label: "Set Reminder"
      primary: page.ready
      enabled: page.ready
      opacity: enabled ? 1 : 0.5
      activeFocusOnTab: enabled
      Accessible.role: Accessible.Button
      Accessible.name: ("Set Reminder")
      Accessible.onPressAction: if (enabled) clicked()
      Keys.onSpacePressed: clicked()
      Keys.onReturnPressed: clicked()
      onClicked: {
        page.view.forceActiveFocus()
        page.result = page.todos.scheduleReminder(page.minutes, page.message) ? "" : "Couldn’t schedule the reminder"
      }
    }
  }
}

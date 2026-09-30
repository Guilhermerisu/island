import QtQuick
import QtQuick.Layouts
import "../controls"

// Settings → Search: which AI answers launcher questions.
ColumnLayout {
  id: page
  required property var view
  visible: view.currentPage === "Search"
  Layout.fillWidth: true
  spacing: 20

  SettingsGroup {
    view: page.view
    title: "Ask AI"
    footer: "Uses the command-line tool you're signed in to. Choose None to turn asking off."
    SettingsRow {
      view: page.view
      label: "Ask With"
      detail: "Answers launcher questions in the island"
      last: true
      SettingsPopUp {
        view: page.view
        options: [{ label: "Claude", value: "claude" }, { label: "Codex", value: "chatgpt" }, { label: "None", value: "none" }]
        value: page.view.settings.askAi
        onPicked: function(v) { page.view.settings.askAi = v }
      }
    }
  }
}

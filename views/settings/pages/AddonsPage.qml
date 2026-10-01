pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../controls"

// Settings → Addons: the features kept out of the core (see addons/Addons.qml),
// each switched on here. An enabled addon's options sit under its row.
ColumnLayout {
  id: page
  required property var view
  readonly property var addons: view.host.addons
  visible: view.currentPage === "Addons"
  Layout.fillWidth: true
  spacing: 20

  SettingsGroup {
    view: page.view
    footer: "An addon isn't loaded at all until it's switched on."
    Repeater {
      model: page.addons.entries
      delegate: ColumnLayout {
        id: addon
        required property var modelData
        required property int index
        readonly property bool on: page.addons.isEnabled(modelData.id)
        readonly property var options: on ? modelData.options || [] : []
        readonly property bool lastAddon: index === page.addons.entries.length - 1
        Layout.fillWidth: true
        spacing: 0

        SettingsRow {
          view: page.view
          icon: addon.modelData.icon || ""
          iconTint: addon.modelData.color || page.view.accent
          label: addon.modelData.name
          detail: addon.modelData.description || ""
          last: addon.lastAddon && addon.options.length === 0
          SettingsSwitch {
            view: page.view
            checked: addon.on
            onToggled: function(on) { page.addons.setEnabled(addon.modelData.id, on) }
          }
        }

        Repeater {
          model: addon.options
          delegate: SettingsRow {
            id: optionRow
            required property var modelData
            required property int index
            readonly property var value: page.addons.option(addon.modelData.id, modelData.key)
            function pick(value) { page.addons.setOption(addon.modelData.id, modelData.key, value) }
            view: page.view
            indent: 40
            label: modelData.label || modelData.key
            detail: modelData.detail || ""
            last: addon.lastAddon && index === addon.options.length - 1
            Loader {
              sourceComponent: optionRow.modelData.type === "popup" ? popUpOption : switchOption
              Component {
                id: switchOption
                SettingsSwitch {
                  view: page.view
                  checked: !!optionRow.value
                  onToggled: function(on) { optionRow.pick(on) }
                }
              }
              Component {
                id: popUpOption
                SettingsPopUp {
                  view: page.view
                  options: optionRow.modelData.choices || []
                  value: optionRow.value
                  onPicked: function(v) { optionRow.pick(v) }
                }
              }
            }
          }
        }
      }
    }
    SettingsRow {
      visible: page.addons.entries.length === 0
      view: page.view
      label: "No addons available"
      last: true
    }
  }
}

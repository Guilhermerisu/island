pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../../components"
import "../controls"

ColumnLayout {
  id: page
  required property var view
  readonly property var addons: view.host.addons
  visible: view.currentPage === "Addons"
  Layout.fillWidth: true
  spacing: 4

  property string expanded: ""
  // An addon asked to be shown (host.openSettings("Addons", id)) opens with
  // its options out.
  Connections {
    target: page.view.host
    function onSettingsAddonChanged() { page.takeAddon() }
  }
  Component.onCompleted: takeAddon()
  function takeAddon() {
    if (view.host.settingsAddon === "") return
    expanded = view.host.settingsAddon
    view.host.settingsAddon = ""
  }

  Repeater {
    model: page.addons.entries
    delegate: ColumnLayout {
      id: addon
      required property var modelData
      readonly property bool on: page.addons.isEnabled(modelData.id)
      readonly property var options: modelData.options || []
      readonly property var shortcuts: page.view.keybinds ? page.view.keybinds.addonEntries(modelData.id) : []
      // Only an enabled addon has its options and shortcuts to open.
      readonly property bool hasOptions: on && (options.length > 0 || shortcuts.length > 0)
      readonly property bool open: hasOptions && page.expanded === modelData.id
      Layout.fillWidth: true
      spacing: 4

      Rectangle {
        id: entryRow
        Layout.fillWidth: true
        implicitHeight: Math.max(54, entryText.implicitHeight + 20)
        radius: 14
        color: rowHover.hovered || addon.open ? page.view.card : "transparent"
        border.width: rowHover.hovered || addon.open ? 1 : 0
        border.color: page.view.host.theme.withAlpha(page.view.text, 0.04)
        Behavior on color { MotionColorAnimation { theme: page.view.host.theme } }

        HoverHandler { id: rowHover }
        MouseArea {
          anchors.fill: parent
          enabled: addon.hasOptions
          cursorShape: addon.hasOptions ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: page.expanded = addon.open ? "" : addon.modelData.id
        }

        PaneIcon {
          id: entryIcon
          view: page.view
          x: 10
          anchors.verticalCenter: parent.verticalCenter
          width: 32
          height: 32
          glyph: addon.modelData.icon || ""
          layers: addon.modelData.iconLayers || []
          tint: addon.modelData.color || page.view.accent
        }
        Column {
          id: entryText
          anchors.left: entryIcon.right
          anchors.leftMargin: 14
          anchors.right: entryControls.left
          anchors.rightMargin: 16
          anchors.verticalCenter: parent.verticalCenter
          spacing: 2
          Text {
            width: parent.width
            text: addon.modelData.name
            elide: Text.ElideRight
            color: page.view.text
            font.family: page.view.host.theme.textFontFamily
            font.pixelSize: page.view.detailFontSize + 1
            font.weight: Font.Medium
          }
          Text {
            width: parent.width
            visible: text !== ""
            text: addon.modelData.description || ""
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            color: page.view.textMuted
            font.family: page.view.host.theme.textFontFamily
            font.pixelSize: page.view.detailCaptionFontSize + 1
          }
        }
        Row {
          id: entryControls
          anchors.right: parent.right
          anchors.rightMargin: 12
          anchors.verticalCenter: parent.verticalCenter
          spacing: 10
          StoreButton {
            anchors.verticalCenter: parent.verticalCenter
            view: page.view
            added: addon.on
            onClicked: {
              if (addon.on && page.expanded === addon.modelData.id) page.expanded = ""
              page.addons.setEnabled(addon.modelData.id, !addon.on)
            }
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 12
            horizontalAlignment: Text.AlignHCenter
            opacity: addon.hasOptions ? (rowHover.hovered || addon.open ? 1 : 0.55) : 0
            text: "󰅂"
            rotation: addon.open ? 90 : 0
            color: page.view.textMuted
            font.family: page.view.host.theme.fontFamily
            font.pixelSize: 14
            Behavior on rotation { MotionAnimation { theme: page.view.host.theme; pace: "standard" } }
          }
        }
      }

      Rectangle {
        visible: addon.open
        Layout.fillWidth: true
        Layout.bottomMargin: 6
        Layout.preferredHeight: optionList.implicitHeight
        radius: 10
        color: page.view.card
        border.width: 1
        border.color: page.view.host.theme.withAlpha(page.view.text, 0.04)
        ColumnLayout {
          id: optionList
          anchors.left: parent.left
          anchors.right: parent.right
          spacing: 0
          Repeater {
            model: addon.open ? addon.options : []
            delegate: SettingsRow {
              id: optionRow
              required property var modelData
              required property int index
              readonly property var value: page.addons.option(addon.modelData.id, modelData.key)
              function pick(value) { page.addons.setOption(addon.modelData.id, modelData.key, value) }
              view: page.view
              label: modelData.label || modelData.key
              detail: modelData.detail || ""
              last: index === addon.options.length - 1 && addon.shortcuts.length === 0
              Loader {
                sourceComponent: optionRow.modelData.type === "popup" ? popUpOption
                  : optionRow.modelData.type === "text" ? textOption : switchOption
                Component {
                  id: switchOption
                  SettingsSwitch {
                    view: page.view
                    checked: !!optionRow.value
                    onToggled: function(on) { optionRow.pick(on) }
                  }
                }
                Component {
                  id: textOption
                  SettingsTextField {
                    view: page.view
                    value: optionRow.value === undefined ? "" : String(optionRow.value)
                    placeholder: optionRow.modelData.placeholder || ""
                    onCommitted: function(v) { optionRow.pick(v) }
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
          // Its shortcuts, recorded by the Keybinds page (which leaves them out).
          Repeater {
            model: addon.open ? addon.shortcuts : []
            delegate: ShortcutRow {
              required property var modelData
              required property int index
              view: page.view
              keybinds: page.view.keybinds
              entry: addon.shortcuts.length === 1 ? Object.assign({}, modelData, { label: "Keyboard Shortcut" }) : modelData
              last: index === addon.shortcuts.length - 1
            }
          }
        }
      }
    }
  }

  Text {
    visible: page.addons.entries.length === 0
    Layout.fillWidth: true
    Layout.topMargin: 12
    horizontalAlignment: Text.AlignHCenter
    text: "No addons available"
    color: page.view.textMuted
    font.family: page.view.host.theme.textFontFamily
    font.pixelSize: page.view.detailFontSize
  }
}

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
  spacing: 20

  property string expanded: ""
  // An addon option's control, whatever kind, so they line up in its card.
  readonly property int optionWidth: 200
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

  // As System Settings' lists: what's added, then what isn't, each in its
  // own group.
  Repeater {
    model: [{ title: "Added", on: true }, { title: "Available", on: false }]
    delegate: SettingsGroup {
      id: group
      required property var modelData
      readonly property var items: page.addons.entries.filter(function(entry) { return page.addons.isEnabled(entry.id) === group.modelData.on })
      view: page.view
      title: modelData.title
      count: String(items.length)
      visible: items.length > 0
      Repeater {
        model: group.items
        delegate: ColumnLayout {
          id: addon
          required property var modelData
          required property int index
          readonly property bool on: page.addons.isEnabled(modelData.id)
          readonly property var options: modelData.options || []
          readonly property var shortcuts: page.view.keybinds ? page.view.keybinds.addonEntries(modelData.id) : []
          // Only an enabled addon has its options and shortcuts to open.
          readonly property bool hasOptions: on && (options.length > 0 || shortcuts.length > 0)
          readonly property bool open: hasOptions && page.expanded === modelData.id
          Layout.fillWidth: true
          readonly property bool last: index === group.items.length - 1
          spacing: 0

          Item {
            id: entryRow
            Layout.fillWidth: true
            implicitHeight: Math.max(54, entryText.implicitHeight + 20)

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
              x: 14
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
                font.letterSpacing: page.view.host.theme.tracking(page.view.host.theme.textFontFamily, page.view.host.theme.px(15))
                font.pixelSize: page.view.host.theme.px(15)
                font.weight: Font.Medium
              }
              Text {
                width: parent.width
                visible: text !== ""
                readonly property var describedWith: addon.modelData.describedWith
                readonly property string shown: describedWith ? String(page.addons.option(addon.modelData.id, describedWith.key) || "") : ""
                text: shown !== "" ? describedWith.text.arg(shown) : addon.modelData.description || ""
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                color: page.view.textMuted
                font.family: page.view.host.theme.textFontFamily
                font.letterSpacing: page.view.host.theme.tracking(page.view.host.theme.textFontFamily, page.view.detailFontSize)
                font.pixelSize: page.view.detailFontSize
              }
            }
            Row {
              id: entryControls
              anchors.right: parent.right
              anchors.rightMargin: 14
              anchors.verticalCenter: parent.verticalCenter
              spacing: 10
              // Remove waits for the row to be hovered (or opened), as in
              // System Settings, so the Added list isn't a column of
              // buttons; it keeps its room so the text doesn't reflow.
              Item {
                readonly property bool shown: !addon.on || rowHover.hovered || addon.open
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: storeButton.implicitWidth
                implicitHeight: storeButton.implicitHeight
                enabled: shown
                opacity: shown ? 1 : 0
                Behavior on opacity { MotionAnimation { theme: page.view.host.theme; pace: "fade"; curve: "fade" } }
                StoreButton {
                  id: storeButton
                  view: page.view
                  added: addon.on
                  onClicked: {
                    if (addon.on && page.expanded === addon.modelData.id) page.expanded = ""
                    page.addons.setEnabled(addon.modelData.id, !addon.on)
                  }
                }
              }
              // Only added addons have options, so only their group keeps a
              // slot for it and the buttons line up in both.
              Text {
                visible: group.modelData.on
                anchors.verticalCenter: parent.verticalCenter
                width: 12
                horizontalAlignment: Text.AlignHCenter
                opacity: addon.hasOptions ? (rowHover.hovered || addon.open ? 1 : 0.55) : 0
                text: "󰅂"
                rotation: addon.open ? 90 : 0
                color: page.view.textMuted
                font.family: page.view.host.theme.fontFamily
                font.pixelSize: page.view.host.theme.px(14)
                Behavior on rotation { MotionAnimation { theme: page.view.host.theme; pace: "standard" } }
              }
            }
          }

          // Its options, in an inset card under the addon's name.
          Rectangle {
            visible: addon.open
            Layout.fillWidth: true
            Layout.leftMargin: entryText.x
            Layout.rightMargin: 16
            Layout.bottomMargin: 16
            Layout.preferredHeight: optionList.implicitHeight
            radius: page.view.host.theme.radii.large
            color: page.view.host.theme.solid("quiet")
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
                  // An option for one choice of "with" (Ask AI's model for its AI).
                  visible: !modelData.visibleWith || page.addons.option(addon.modelData.id, "with") === modelData.visibleWith
                  function pick(value) { page.addons.setOption(addon.modelData.id, modelData.key, value) }
                  view: page.view
                  label: modelData.label || modelData.key
                  detail: modelData.detail || ""
                  last: index === addon.options.length - 1 && addon.shortcuts.length === 0
                  Loader {
                    sourceComponent: optionRow.modelData.type === "popup" ? popUpOption
                      : optionRow.modelData.type === "segmented" ? segmentedOption
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
                        icon: optionRow.modelData.icon || ""
                        implicitWidth: page.optionWidth
                        onCommitted: function(v) { optionRow.pick(v) }
                      }
                    }
                    Component {
                      id: popUpOption
                      SettingsPopUp {
                        view: page.view
                        minWidth: page.optionWidth
                        options: optionRow.modelData.choices || []
                        value: optionRow.value
                        onPicked: function(v) { optionRow.pick(v) }
                      }
                    }
                    Component {
                      id: segmentedOption
                      SettingsSegmented {
                        view: page.view
                        minWidth: page.optionWidth
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
                  entry: addon.shortcuts.length === 1 ? Object.assign({}, modelData, { label: "Keyboard shortcut" }) : modelData
                  // What it opens; the boxed keys show they can be clicked to change.
                  detail: (modelData.command.indexOf("addonSettings") !== -1 ? "Opens its Settings pane" : "Opens the " + addon.modelData.name.toLowerCase() + " view")
                  boxed: true
                  fieldWidth: page.optionWidth
                  last: index === addon.shortcuts.length - 1
                }
              }
            }
          }
          // The hairline between addons, across the whole group.
          Rectangle {
            visible: !addon.last
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: page.view.divider
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
    font.letterSpacing: page.view.host.theme.tracking(page.view.host.theme.textFontFamily, page.view.detailFontSize)
    font.pixelSize: page.view.detailFontSize
  }
}

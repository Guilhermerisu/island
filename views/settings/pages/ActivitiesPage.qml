pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../controls"
import "../../../components"
import "../../../services/ActivityPriority.mjs" as Priority

// Settings → Live Activities: checkable static previews of the real pill.
ColumnLayout {
  id: page
  required property var view
  visible: view.currentPage === "Live Activities"
  Layout.fillWidth: true
  spacing: 20

  readonly property var order: view.host.indicatorOrder
  readonly property bool customPriority: order.join(",") !== Priority.defaultOrder.join(",")

  function moveIndicator(id, offset) {
    var next = Priority.moveIndicator(order, id, offset)
    if (next !== order) view.settings.indicatorOrder = next.join(",")
  }

  component PriorityButton: SettingsButton {
    id: priorityButton
    required property string action
    required property string activity
    implicitWidth: implicitHeight
    radius: height / 2
    opacity: enabled ? 1 : 0.35
    activeFocusOnTab: enabled
    border.width: activeFocus ? 1 : 0
    border.color: view.accent
    Accessible.role: Accessible.Button
    Accessible.name: action + " · " + activity
    Accessible.onPressAction: if (enabled) clicked()
    Keys.onSpacePressed: clicked()
    Keys.onReturnPressed: clicked()
    Tooltip { theme: priorityButton.view.host.theme; text: priorityButton.action }
  }

  KeyedListModel {
    id: priorityRows
    keyOf: indicator => indicator.id
    values: page.visible ? page.order.map(id => Priority.indicators.find(indicator => indicator.id === id)) : []
  }

  SettingsGroup {
    view: page.view
    title: "Indicator Priority"
    footer: "The highest active indicator appears on the collapsed Island. Media without a known type uses the music priority."
    ListView {
      id: priorityList
      readonly property real rowHeight: Math.max(44, page.view.detailFontSize * 2 + 18)
      Layout.fillWidth: true
      Layout.preferredHeight: count * rowHeight
      interactive: false
      clip: true
      model: priorityRows.model
      move: Transition {
        MotionAnimation { theme: page.view.host.theme; property: "y"; pace: "quick" }
      }
      moveDisplaced: Transition {
        MotionAnimation { theme: page.view.host.theme; property: "y"; pace: "quick" }
      }
      delegate: SettingsRow {
        id: priorityRow
        required property int index
        required property var entry
        view: page.view
        width: priorityList.width
        height: priorityList.rowHeight
        label: entry.label
        icon: entry.icon
        iconTint: entry.color
        RowLayout {
          width: implicitWidth
          height: implicitHeight
          spacing: 6
          PriorityButton {
            view: page.view
            label: "↑"
            action: "Move up"
            activity: priorityRow.label
            enabled: priorityRow.index > 0
            onClicked: page.moveIndicator(priorityRow.entry.id, -1)
          }
          PriorityButton {
            view: page.view
            label: "↓"
            action: "Move down"
            activity: priorityRow.label
            enabled: priorityRow.index < priorityList.count - 1
            onClicked: page.moveIndicator(priorityRow.entry.id, 1)
          }
        }
      }
    }
    SettingsRow {
      view: page.view
      label: "Default Indicator Order"
      last: true
      SettingsButton {
        view: page.view
        label: "Reset"
        enabled: page.customPriority
        opacity: enabled ? 1 : 0.35
        activeFocusOnTab: enabled
        Accessible.role: Accessible.Button
        Accessible.name: "Default Indicator Order"
        Accessible.onPressAction: if (enabled) clicked()
        Keys.onSpacePressed: clicked()
        Keys.onReturnPressed: clicked()
        onClicked: page.view.settings.indicatorOrder = ""
      }
    }
  }

  readonly property var activities: [
    { kind: "media", key: "mediaPill", title: "Now Playing", description: "Track details and album artwork" },
    { kind: "playback", key: "playbackOsd", title: "Play & Pause", description: "Resume or skip a paused track" },
    { kind: "workspace", key: "workspaceHud", title: "Workspace Indicator", description: "Show which workspace is active" },
    { kind: "downloads", key: "downloads", title: "Downloads", description: "Show active download progress" },
    { kind: "recording", key: "screenRecordingActivity", title: "Screen Recording", description: "Show time recorded; click to stop" },
    { kind: "updates", key: "systemUpdates", title: "System Updates", description: "Show available system updates" },
    { kind: "bluetooth", key: "bluetoothActivity", title: "Bluetooth Devices", description: "Show Bluetooth connection status" },
    { kind: "network", key: "networkActivity", title: "Network", description: "Wi-Fi and Ethernet status" },
    { kind: "battery", key: "batteryActivity", title: "Battery", description: "Charging and low battery alerts" },
    { kind: "volume", key: "volumeHud", title: "Volume", description: "Display the current volume level" },
    { kind: "brightness", key: "brightnessHud", title: "Brightness", description: "Display the brightness level" },
    { kind: "clipboard", key: "clipboard", title: "Clipboard", description: "Preview recently copied content" }
  ]

  readonly property int enabledCount: activities.filter(function(activity) { return !!view.settings[activity.key] }).length

  // As a group's title (see SettingsGroup), with how many are on.
  RowLayout {
    Layout.fillWidth: true
    Layout.leftMargin: 14
    Layout.rightMargin: 14
    Layout.bottomMargin: -12
    Text {
      Layout.fillWidth: true
      text: "Activities"
      color: page.view.textMuted
      font.family: page.view.host.theme.textFontFamily
      font.letterSpacing: page.view.host.theme.tracking(page.view.host.theme.textFontFamily, page.view.detailFontSize)
      font.pixelSize: page.view.detailFontSize
      font.weight: Font.Medium
    }
    Text {
      text: page.enabledCount + " of " + page.activities.length + " on"
      color: page.view.textMuted
      font.family: page.view.host.theme.textFontFamily
      font.features: { "tnum": 1 }
      font.letterSpacing: page.view.host.theme.tracking(page.view.host.theme.textFontFamily, page.view.detailFontSize)
      font.pixelSize: page.view.detailFontSize
    }
  }

  GridLayout {
    Layout.fillWidth: true
    columns: page.width < 420 ? 1 : 2
    columnSpacing: 12
    rowSpacing: 12
    Repeater {
      model: page.activities
      delegate: ActivityCard {
        required property var modelData
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        view: page.view
        kind: modelData.kind
        title: modelData.title
        description: modelData.description
        checked: page.view.settings[modelData.key]
        onToggled: function(on) { page.view.settings[modelData.key] = on }
      }
    }
  }
}

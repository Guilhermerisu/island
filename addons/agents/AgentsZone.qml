import QtQuick
import QtQuick.Layouts
import ".."
import "../../components"

// The Agents zone of the control center (see "Zone sizes" in Addon.qml).
// Normal is what an addon without a zone of its own gets: the Settings pane in
// a card, mounted by AddonZone. XSmall is the session (5-hour) limit alone;
// Small, the session and weekly limits and the tokens used a day on average.
// Both read the addon's usage record (AgentsAddon). What the Normal pane has
// beyond that (the models, the days, the time to a reset) is its Settings page,
// which a click on either size opens; with several agents picked in the
// options, the agent is chosen in a popover (Small's first line, or a right
// click on either), as the pane's switch does.
AddonZone {
  id: zone
  readonly property var agents: parent.addonRoot
  readonly property var theme: center.host.theme
  readonly property bool compact: zoneSize !== "normal"
  mount: !compact

  // Counted once while its content is shown, as AddonZone does for a mounted
  // pane, so the addon keeps the usage record fresh (see zoneViews).
  readonly property bool counting: compact && shown
  property bool counted: false
  function count() {
    if (counted === counting) return
    counted = counting
    agents.zoneViews += counting ? 1 : -1
  }
  onCountingChanged: count()
  Component.onCompleted: count()
  Component.onDestruction: if (counted && agents) agents.zoneViews -= 1

  readonly property bool several: agents.selectedAgents.length > 1
  // The agent's popover, under `anchor` (nothing to choose with one agent).
  function pickAgent(anchor) {
    if (several) center.openPopover(anchor, picker, {})
  }

  Loader {
    width: parent.width
    height: item ? item.implicitHeight : 0
    active: zone.compact
    sourceComponent: zone.zoneSize === "xsmall" ? xsmall : small
    // The whole card, its padding too, under the content: a click opens the
    // Agents page in Settings, a right click the agent's popover.
    MouseArea {
      id: card
      anchors.fill: parent
      anchors.margins: -zone.padding
      z: -1
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      cursorShape: Qt.PointingHandCursor
      onClicked: function(mouse) {
        if (mouse.button === Qt.RightButton) zone.pickAgent(card)
        else zone.center.host.openSettings("Agents")
      }
    }
  }

  component Label: Text {
    color: zone.center.text
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
    font.family: zone.theme.textFontFamily
    font.pixelSize: zone.theme.size.footnote
    font.letterSpacing: zone.theme.tracking(zone.theme.textFontFamily, zone.theme.size.footnote)
    font.features: { "tnum": 1 }
  }

  component AgentBadge: Rectangle {
    id: badge
    property var provider: zone.agents.provider
    property real size: 18
    width: size
    height: size
    radius: 5
    color: provider ? provider.color : zone.center.accent
    Text {
      anchors.centerIn: parent
      text: badge.provider ? badge.provider.glyph : ""
      color: "#ffffff"
      font.family: zone.center.iconFont
      font.pixelSize: Math.round(badge.size * (badge.provider ? badge.provider.glyphSize : 0.65))
    }
  }

  // A limit as a thin meter: its name, the bar, the share used, and an
  // optional reset countdown. "—" until the record has it (or for an agent
  // without that limit).
  component Meter: Item {
    id: meter
    property string title: ""
    property var limit: null
    property string resetText: ""
    property bool reserveReset: false
    property real titleWidth: 50
    readonly property real used: limit ? Math.max(0, Number(limit.percent) || 0) : 0
    implicitHeight: 16
    TextMetrics { id: figureMetrics; font: figure.font; text: "100%" }
    TextMetrics { id: resetSampleMetrics; font: resetLabel.font; text: "23h 59m" }
    TextMetrics { id: resetActualMetrics; font: resetLabel.font; text: meter.resetText }
    RowLayout {
      anchors.fill: parent
      spacing: 6
      Label {
        id: name
        visible: meter.width >= 180
        Layout.preferredWidth: meter.titleWidth > 0 ? meter.titleWidth : implicitWidth
        Layout.alignment: Qt.AlignVCenter
        text: meter.title
        color: zone.center.textMuted
      }
      Rectangle {
        Layout.fillWidth: true
        Layout.minimumWidth: 24
        Layout.preferredHeight: 4
        Layout.alignment: Qt.AlignVCenter
        radius: 2
        color: zone.center.well
        Rectangle {
          width: Math.max(meter.used > 0 ? parent.height : 0, parent.width * Math.min(1, meter.used))
          Behavior on width { MotionAnimation { theme: zone.theme; pace: "data" } }
          height: parent.height
          radius: parent.radius
          color: zone.agents.usedColor(meter.used)
        }
      }
      Label {
        id: figure
        Layout.preferredWidth: Math.max(32, Math.ceil(figureMetrics.width))
        Layout.alignment: Qt.AlignVCenter
        horizontalAlignment: Text.AlignRight
        text: meter.limit ? Math.round(meter.used * 100) + "%" : "—"
        color: meter.used >= 0.5 ? zone.agents.usedColor(meter.used) : zone.center.text
        font.weight: Font.Medium
      }
      Label {
        id: resetLabel
        visible: meter.reserveReset || meter.resetText !== ""
        Layout.preferredWidth: visible ? Math.max(44, Math.ceil(Math.max(resetSampleMetrics.width, resetActualMetrics.width))) : 0
        Layout.alignment: Qt.AlignVCenter
        horizontalAlignment: Text.AlignRight
        text: meter.resetText
        color: zone.center.textMuted
      }
    }
  }

  Component {
    id: xsmall
    Item {
      implicitHeight: zone.room
      RowLayout {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        spacing: 8
        AgentBadge {
          Layout.alignment: Qt.AlignVCenter
          provider: zone.agents.provider
          size: 18
        }
        // All Models has no session limit, so show its daily average instead.
        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: 18
          visible: zone.agents.providerId === "all"
          Label {
            anchors.left: parent.left
            anchors.right: allFigure.left
            anchors.rightMargin: 8
            height: parent.height
            text: "Daily average"
            color: zone.center.textMuted
          }
          Label {
            id: allFigure
            anchors.right: parent.right
            height: parent.height
            text: zone.agents.record ? zone.agents.tokens(zone.agents.averageTokens) + " tokens" : "—"
            font.weight: Font.Medium
          }
        }
        Meter {
          Layout.fillWidth: true
          Layout.preferredHeight: 18
          visible: zone.agents.providerId !== "all"
          title: "Session"
          titleWidth: 0
          limit: zone.agents.sessionLimit
          resetText: zone.agents.shortCountdown(zone.agents.sessionLimit && zone.agents.sessionLimit.resetsAt)
        }
      }
    }
  }

  Component {
    id: small
    ColumnLayout {
      id: smallBody
      spacing: 6
      readonly property string sessionReset: zone.agents.shortCountdown(zone.agents.sessionLimit && zone.agents.sessionLimit.resetsAt)
      readonly property string weeklyReset: zone.agents.shortCountdown(zone.agents.weeklyLimit && zone.agents.weeklyLimit.resetsAt)
      readonly property bool anyReset: sessionReset !== "" || weeklyReset !== ""
      // Header: always shows the active agent's badge and name; with several
      // agents picked, clicking opens the agent switcher popover.
      Item {
        id: header
        Layout.fillWidth: true
        Layout.preferredHeight: 20
        AgentBadge {
          id: headerBadge
          anchors.verticalCenter: parent.verticalCenter
          provider: zone.agents.provider
          size: 18
        }
        Label {
          id: agentName
          anchors.left: headerBadge.right
          anchors.leftMargin: 8
          anchors.verticalCenter: parent.verticalCenter
          width: Math.min(implicitWidth, parent.width - headerBadge.width - 8 - (zone.several ? 18 : 0))
          text: zone.agents.provider.name
          font.weight: Font.Medium
        }
        Text {
          visible: zone.several
          anchors.left: agentName.right
          anchors.leftMargin: 4
          anchors.verticalCenter: parent.verticalCenter
          text: "󰅀"
          color: zone.center.textMuted
          font.family: zone.center.iconFont
          font.pixelSize: zone.theme.size.footnote
        }
        MouseArea {
          visible: zone.several
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: zone.pickAgent(header)
        }
      }
      Meter {
        Layout.fillWidth: true
        Layout.preferredHeight: 16
        title: "Session"
        limit: zone.agents.sessionLimit
        resetText: smallBody.sessionReset
        reserveReset: smallBody.anyReset
      }
      Meter {
        Layout.fillWidth: true
        Layout.preferredHeight: 16
        title: "Weekly"
        limit: zone.agents.weeklyLimit
        resetText: smallBody.weeklyReset
        reserveReset: smallBody.anyReset
      }
      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 16
        Label {
          height: parent.height
          text: "Daily average"
          color: zone.center.textMuted
        }
        Label {
          anchors.right: parent.right
          height: parent.height
          text: zone.agents.record ? zone.agents.tokens(zone.agents.averageTokens) + " tokens" : "—"
          font.weight: Font.Medium
        }
      }
    }
  }

  // The agents picked in the options, the shown one marked.
  Component {
    id: picker
    Item {
      implicitWidth: 188
      implicitHeight: list.implicitHeight
      Column {
        id: list
        width: parent.width
        Repeater {
          model: zone.agents.selectedAgents
          delegate: Rectangle {
            id: choice
            required property string modelData
            readonly property var itemProvider: zone.agents.providers[choice.modelData]
            readonly property bool current: choice.modelData === zone.agents.providerId
            width: parent.width
            height: 30
            radius: 8
            color: pick.containsMouse ? zone.center.wellHover : "transparent"
            AgentBadge {
              id: choiceBadge
              anchors.left: parent.left
              anchors.leftMargin: 8
              anchors.verticalCenter: parent.verticalCenter
              provider: choice.itemProvider
              size: 18
            }
            Label {
              anchors.left: choiceBadge.right
              anchors.leftMargin: 8
              anchors.right: mark.left
              anchors.rightMargin: 4
              height: parent.height
              text: choice.itemProvider.name
            }
            Text {
              id: mark
              anchors.right: parent.right
              anchors.rightMargin: 8
              height: parent.height
              verticalAlignment: Text.AlignVCenter
              visible: choice.current
              text: "󰄬"
              color: zone.center.accent
              font.family: zone.center.iconFont
              font.pixelSize: zone.theme.size.callout
            }
            MouseArea {
              id: pick
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: { zone.agents.activeAgent = choice.modelData; zone.center.closePopover() }
            }
          }
        }
      }
    }
  }
}

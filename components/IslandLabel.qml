import QtQuick

// The resting pill's clock, plus the plain-text feedback and setup warning
// that share its spot. Supports both single-line and stacked two-line typography.
Item {
  id: labelRoot
  required property var host
  // The pill on the island (see IslandPill); the label hides behind it unless
  // it keeps the clock in its middle.
  property Item pill: null
  readonly property bool shown: (host.view === "rest" || host.view === "feedback") && (!pill || pill.keepsClock)
  // Closing a view, it waits for the island to have nearly shrunk, so it
  // doesn't fade in over the view's content in the middle of a big island.
  readonly property bool fits: parent.height < parent.targetHeight + 24
  opacity: shown && fits ? 1 : 0

  readonly property bool isWarningOrFeedback: (host.view === "feedback" && !host.notificationPill && !host.volumePill) || host.setup.needsSetup
  readonly property bool isStacked: host.clockStacked && !isWarningOrFeedback

  readonly property font font: singleText.font
  readonly property real advanceWidth: isStacked
    ? Math.max(stackedTimeMetrics.advanceWidth, stackedSubMetrics.advanceWidth)
    : singleMetrics.advanceWidth

  width: Math.max(singleText.implicitWidth, stackedCol.implicitWidth)
  height: isStacked ? stackedCol.implicitHeight : singleText.implicitHeight

  // Single-line text (for feedback, warning, or single-line clock styles)
  Text {
    id: singleText
    anchors.centerIn: parent
    visible: !labelRoot.isStacked
    width: Math.min(labelRoot.parent ? labelRoot.parent.width - 24 : 300, implicitWidth)
    horizontalAlignment: Text.AlignHCenter
    elide: Text.ElideRight
    textFormat: Text.PlainText
    text: host.view === "feedback" && !host.notificationPill && !host.volumePill ? host.feedback
      : host.setup.needsSetup ? "󰀦  " + host.setup.warning
      : host.clockText
    color: host.view === "rest" && host.setup.needsSetup ? host.theme.urgent : "#e2e6de"
    font.family: host.theme.textFontFamily
    font.pixelSize: host.theme.px(15)
    font.weight: Font.DemiBold
    font.features: { "tnum": 1, "case": 1 }
    font.letterSpacing: -0.4
  }
  TextMetrics { id: singleMetrics; font: singleText.font; text: singleText.text }

  // Two-line stacked column (time on top, day/date on bottom)
  Column {
    id: stackedCol
    anchors.centerIn: parent
    visible: labelRoot.isStacked
    spacing: 0

    Text {
      id: stackedTimeText
      anchors.horizontalCenter: parent.horizontalCenter
      text: labelRoot.host.clockTimeText
      color: "#e2e6de"
      font.family: labelRoot.host.theme.textFontFamily
      font.pixelSize: labelRoot.host.theme.px(13)
      font.weight: Font.DemiBold
      font.features: { "tnum": 1, "case": 1 }
      font.letterSpacing: -0.3
    }
    Text {
      id: stackedSubText
      anchors.horizontalCenter: parent.horizontalCenter
      text: labelRoot.host.clockSubText
      color: Qt.rgba(0.88, 0.90, 0.87, 0.7)
      font.family: labelRoot.host.theme.textFontFamily
      font.pixelSize: labelRoot.host.theme.px(10)
      font.weight: Font.Medium
      font.letterSpacing: -0.1
    }
  }
  TextMetrics { id: stackedTimeMetrics; font: stackedTimeText.font; text: stackedTimeText.text }
  TextMetrics { id: stackedSubMetrics; font: stackedSubText.font; text: stackedSubText.text }

  Behavior on opacity { MotionAnimation { theme: labelRoot.host.theme; pace: labelRoot.shown && labelRoot.fits ? "fade" : "exit"; curve: "fade" } }
}

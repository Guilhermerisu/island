import QtQuick

// Text whose digits roll when they change, as SwiftUI's numeric text
// transition: only the digits that differ move, out through a blur while the
// new one comes in, upward as the number grows and downward as it shrinks.
// Anything else in the text (a colon, "Mon") just changes in place.
Item {
  id: roller
  required property var theme
  property string text: ""
  property color color: theme.text
  property font font

  // Digits one by one, and runs of anything else whole so they keep their
  // kerning. A change in how many there are simply redraws them.
  readonly property var tokens: text.match(/\d|\D+/g) || []
  readonly property real number: parseInt(text.replace(/\D/g, ""), 10) || 0
  property real settledNumber: number
  onNumberChanged: Qt.callLater(function() { roller.settledNumber = roller.number })

  implicitWidth: row.implicitWidth
  implicitHeight: probe.implicitHeight
  baselineOffset: probe.baselineOffset

  Text { id: probe; visible: false; text: "0"; font: roller.font }

  Row {
    id: row
    anchors.right: parent.right
    Repeater {
      model: roller.tokens.length
      delegate: Item {
        id: slot
        required property int index
        readonly property string token: roller.tokens[index] || ""
        property string current: ""
        property string previous: ""
        property real progress: 1
        property int direction: 1
        readonly property real travel: height * 0.45
        Component.onCompleted: current = token
        onTokenChanged: {
          if (token === current) return
          if (!/^\d$/.test(token) || !/^\d$/.test(current)) {
            run.stop()
            progress = 1
            current = token
            return
          }
          direction = roller.number >= roller.settledNumber ? 1 : -1
          previous = current
          current = token
          progress = 0
          run.restart()
        }
        implicitWidth: incoming.implicitWidth
        implicitHeight: incoming.implicitHeight
        width: implicitWidth
        height: implicitHeight

        Text {
          id: incoming
          text: slot.current
          color: roller.color
          font: roller.font
          y: slot.direction * (1 - slot.progress) * slot.travel
          opacity: slot.progress
          layer.enabled: run.running
          layer.effect: PillBlur { blur: 0.5 * (1 - slot.progress) }
        }
        Text {
          visible: run.running
          text: slot.previous
          color: roller.color
          font: roller.font
          y: -slot.direction * slot.progress * slot.travel
          opacity: 1 - slot.progress
          layer.enabled: run.running
          layer.effect: PillBlur { blur: 0.5 * slot.progress }
        }
        MotionAnimation {
          id: run
          theme: roller.theme
          target: slot
          property: "progress"
          to: 1
          pace: "expressive"
        }
      }
    }
  }
}

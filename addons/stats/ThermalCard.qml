pragma ComponentBehavior: Bound
import QtQuick
import "../../components"

// How hot the machine runs, as macOS puts it, in the same card as the
// others: the hottest part's temperature on the ring, each part's below it,
// and one word in the capsule for whichever part runs hottest for its kind.
// Chips are Good under 70 °C, Fair under 80, High under 90; SSDs, which
// slow down sooner, 20 °C lower.
StatCard {
  id: card
  property var temps: []          // [{ label, value, ssd }]
  readonly property var levels: [
    { label: "Good", color: card.view.host.theme.system.green },
    { label: "Fair", color: card.view.host.theme.system.yellow },
    { label: "High", color: card.view.host.theme.system.orange },
    { label: "Max", color: card.view.host.theme.system.red }
  ]
  function levelOf(t) {
    var good = t.ssd ? 50 : 70
    return t.value < good ? 0 : t.value < good + 10 ? 1 : t.value < good + 20 ? 2 : 3
  }
  readonly property int level: temps.reduce(function(top, t) { return Math.max(top, card.levelOf(t)) }, 0)
  // The part furthest into its scale: the highest level, then the hottest.
  readonly property var hottest: temps.reduce(function(top, t) {
    if (!top) return t
    var a = card.levelOf(t), b = card.levelOf(top)
    return a > b || (a === b && t.value > top.value) ? t : top
  }, null)

  title: "Thermal"
  status: temps.length ? levels[level].label : ""
  statusColor: levels[level].color
  // Its temperature toward its Max (100 °C for chips, 80 for SSDs). The
  // ring stays orange; the capsule carries the level.
  ringColor: card.view.host.theme.system.orange
  value: hottest ? hottest.value / ((hottest.ssd ? 50 : 70) + 30) * 100 : 0
  ringText: hottest ? Math.round(hottest.value) + "°" : "—"
  caption: hottest ? hottest.label : ""
  rows: temps.map(function(t) { return { label: t.label, value: Math.round(t.value) + " °C" } })
}

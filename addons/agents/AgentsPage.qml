pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import "../../components"
import "../../views/settings/controls"

// The Agents pane, laid out as macOS System Settings would: the agent as the
// pane's header (its icon, plan, and a Refresh button), its usage limits
// as Storage-style rows with a thin meter each, then the last six days and
// today as Screen Time's weekly chart, with the scale on its right and, while
// a day is hovered, its total in a tooltip; last, all-time tokens by model as
// Storage's bar.
// Limits colour green, yellow, then red.
ColumnLayout {
  id: page
  required property var view
  required property var agents
  property bool shown: false
  spacing: 20

  readonly property var record: agents.record
  readonly property var provider: agents.provider
  // Typed, so theme.withAlpha can tint it.
  readonly property color tint: provider.color
  readonly property var limits: record && record.limits || []
  readonly property var days: record && record.recentDays || []
  readonly property real busiest: Math.max.apply(null, [0].concat(days.map(function(d) { return d.messageCount || 0 })))
  readonly property real week: days.reduce(function(sum, d) { return sum + (d.messageCount || 0) }, 0)
  readonly property real average: days.length ? week / days.length : 0
  readonly property real today: days.length ? days[days.length - 1].messageCount || 0 : 0
  // The chart's top: the busiest day rounded up to a half or whole power of
  // ten, as Screen Time's scale is, so its gridlines land on round figures.
  readonly property real scaleTop: {
    if (busiest <= 0) return 1
    var unit = Math.pow(10, Math.floor(Math.log(busiest) / Math.LN10)) / 2
    return Math.ceil(busiest / unit) * unit
  }

  readonly property color red: page.view.host.theme.system.red
  readonly property color green: page.view.host.theme.system.green
  readonly property color yellow: page.view.host.theme.system.yellow

  // A clock for the countdowns, ticking while the pane is open.
  property real now: Date.now()
  Timer {
    interval: 30000
    repeat: true
    running: page.shown
    triggeredOnStart: true
    onTriggered: page.now = Date.now()
  }

  // Used: green under half, yellow, red from 80%.
  function usedColor(p) { return p >= 0.8 ? red : p >= 0.5 ? yellow : green }
  // The collectors' labels ("Session (5-hour)", "5h window", "Weekly (7-day)",
  // "720h window").
  function limitTitle(label) {
    if (/5.?h/i.test(label)) return "5-Hour Limit"
    if (/week|7.?d/i.test(label)) return "Weekly Limit"
    if (/720h|30.?d|month/i.test(label)) return "Monthly Limit"
    return label
  }
  function countdown(iso) {
    var ms = new Date(iso).getTime() - now
    if (!isFinite(ms)) return ""
    if (ms <= 0) return "now"
    var minutes = Math.floor(ms / 60000), hours = Math.floor(minutes / 60), days = Math.floor(hours / 24)
    if (days > 0) return days + (days === 1 ? " day" : " days") + (hours % 24 ? " " + hours % 24 + " hr" : "")
    if (hours > 0) return hours + " hr " + (minutes % 60) + " min"
    return Math.max(1, minutes) + " min"
  }
  function resetTime(iso) {
    var at = new Date(iso)
    if (!isFinite(at.getTime())) return ""
    var clock = Qt.formatTime(at, view.host.settings.clock24h ? "HH:mm" : "h:mm AP")
    return at.toDateString() === new Date(now).toDateString() ? clock : Qt.formatDate(at, "dddd") + " " + clock
  }
  function resetText(iso) {
    var left = countdown(iso)
    if (left === "") return ""
    return left === "now" ? "Resets now" : "Resets in " + left + " · " + resetTime(iso)
  }
  function tokens(n) {
    n = n || 0
    if (n >= 1e9) return (n / 1e9).toFixed(1) + "B"
    if (n >= 1e6) return (n / 1e6).toFixed(1) + "M"
    if (n >= 1e3) return (n / 1e3).toFixed(1) + "K"
    return String(Math.round(n))
  }
  // Round scale figures: "50M", not "50.0M".
  function scaleLabel(n) { return tokens(n).replace(".0", "") }
  // "YYYY-MM-DD" as a local day: "Mon", or with `full` "Monday".
  function dayName(date, last, full) {
    if (last) return "Today"
    var p = String(date).split("-")
    return Qt.formatDate(new Date(Number(p[0]), Number(p[1]) - 1, Number(p[2])), full ? "dddd" : "ddd")
  }
  // Today against the daily average: "2.6× your daily average",
  // "42% below your daily average".
  function vsAverage() {
    if (!record || average <= 0) return ""
    var ratio = today / average
    if (ratio >= 1.95) return ratio.toFixed(1).replace(".0", "") + "× your daily average"
    var change = Math.round((ratio - 1) * 100)
    if (change === 0) return "About your daily average"
    return Math.abs(change) + "% " + (change > 0 ? "above" : "below") + " your daily average"
  }
  // The week's busiest day: "Busiest on Thursday".
  readonly property string busiestText: {
    if (busiest <= 0 || days.length < 2) return ""
    for (var i = 0; i < days.length; i++)
      if ((days[i].messageCount || 0) === busiest) return "Busiest " + (i === days.length - 1 ? "today" : "on " + dayName(days[i].date, false, true))
    return ""
  }
  function updatedText() {
    if (agents.updating) return "Updating…"
    if (!record || !record.updatedAt) return ""
    var minutes = Math.floor((now - new Date(record.updatedAt).getTime()) / 60000)
    return minutes < 1 ? "Updated just now" : minutes < 60 ? "Updated " + minutes + " min ago" : "Updated " + resetTime(record.updatedAt)
  }
  // Tokens by model, all time: the four largest in the agent's colour and
  // then others', the rest as Other, largest first.
  // All Models (all-usage.py's record): no limits, every model listed.
  readonly property bool allModels: provider.id === "all"
  // Every model, largest first: { label, source, value }.
  readonly property var modelRows: (record && record.models || []).map(function(m) {
    return { label: m.name || modelName(m.id), source: m.source || "", value: m.tokens || 0 }
  })
  readonly property var models: {
    var usage = record && record.modelUsage || {}
    var rows = Object.keys(usage).map(function(id) {
      var u = usage[id] || {}
      return { label: modelName(id), value: (u.inputTokens || 0) + (u.outputTokens || 0) + (u.cacheReadInputTokens || 0) + (u.cacheCreationInputTokens || 0) }
    }).filter(function(m) { return m.value > 0 }).sort(function(a, b) { return b.value - a.value })
    var palette = [tint].concat([page.view.host.theme.system.purple, page.view.host.theme.system.cyan, page.view.host.theme.system.yellow, page.view.host.theme.system.green, page.view.host.theme.system.blue].filter(function(c) {
      return String(c).toLowerCase() !== String(provider.color).toLowerCase()
    }))
    var top = rows.slice(0, 4)
    var rest = rows.slice(4).reduce(function(sum, m) { return sum + m.value }, 0)
    if (rest > 0) top.push({ label: "Other", value: rest, other: true })
    return top.map(function(m, i) {
      return { label: m.label, value: m.value, color: m.other ? page.view.host.theme.system.gray : palette[i], text: tokens(m.value) }
    })
  }
  readonly property real modelTotal: models.reduce(function(sum, m) { return sum + m.value }, 0)
  // "claude-opus-5-5" → "Opus 5.5", "claude-haiku-4-5-20251001" → "Haiku 4.5",
  // "gpt-6.1-sol" → "GPT-6.1 Sol".
  function modelName(id) {
    var parts = String(id).replace(/^claude-/, "").replace(/-\d{8}$/, "").split("-")
    var cap = function(w) { return w.charAt(0).toUpperCase() + w.slice(1) }
    if (parts[0] === "gpt") return "GPT-" + parts.slice(1, 2).join("") + (parts.length > 2 ? " " + parts.slice(2).map(cap).join(" ") : "")
    var words = parts.filter(function(p) { return !/^\d/.test(p) }).map(cap)
    var version = parts.filter(function(p) { return /^\d/.test(p) }).join(".")
    return words.join(" ") + (version ? " " + version : "")
  }

  readonly property string plan: {
    var tier = record && record.tierLabel || ""
    return tier === "" ? "" : tier.charAt(0).toUpperCase() + tier.slice(1) + " Plan"
  }

  // The agent as the pane's header, as Apple Account's pane leads with the
  // account: its icon large, its name, the plan and when it was read, and
  // Refresh. In Settings' header card, which this pane draws in its place.
  Rectangle {
    Layout.fillWidth: true
    implicitHeight: agentColumn.implicitHeight + 32
    radius: page.view.host.theme.radii.card
    color: page.view.card
    border.width: 1
    border.color: page.view.edge
    Column {
      id: agentColumn
      anchors.centerIn: parent
      width: Math.min(parent.width - 48, 380)
      spacing: 6
      PaneIcon {
        view: page.view
        anchors.horizontalCenter: parent.horizontalCenter
        width: 56
        height: 56
        glyph: page.provider.glyph
        tint: page.tint
        layers: [{ glyph: page.provider.glyph, color: "#ffffff", x: 0.5, y: 0.5, size: page.provider.glyphSize }]
      }
      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: page.provider.name
        elide: Text.ElideRight
        color: page.view.text
        font.family: page.view.host.theme.textFontFamily
        font.features: { "tnum": 1 }
        font.pixelSize: page.view.detailTitleFontSize
        font.weight: Font.Bold
        font.letterSpacing: -0.3
      }
      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: [page.allModels ? (page.record && page.record.sources || []).join(", ") : page.plan, page.updatedText()]
          .filter(function(t) { return t !== "" }).join(" · ")
        visible: text !== ""
        elide: Text.ElideRight
        color: page.view.textMuted
        font.family: page.view.host.theme.textFontFamily
        font.features: { "tnum": 1 }
        font.pixelSize: page.view.detailCaptionFontSize
      }
      Item { width: 1; height: 4 }
      SettingsButton {
        view: page.view
        anchors.horizontalCenter: parent.horizontalCenter
        label: "Refresh"
        opacity: page.agents.updating ? 0.5 : 1
        onClicked: if (!page.agents.updating) page.agents.refresh()
      }
    }
  }

  // Usage limits, as Storage's rows: name and share used, a thin meter, and
  // when the window resets -----------------------------------------------------
  SettingsGroup {
    visible: !page.allModels
    view: page.view
    title: "Usage Limits"
    Repeater {
      // By count: each record's new array would otherwise replay the meters.
      model: page.limits.length
      delegate: Item {
        id: limit
        required property int index
        readonly property var modelData: page.limits[index] || ({ label: "", percent: 0, resetsAt: "" })
        readonly property real used: Math.max(0, Number(modelData.percent) || 0)
        Layout.fillWidth: true
        implicitHeight: limitBody.implicitHeight + 26
        ColumnLayout {
          id: limitBody
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.leftMargin: 14
          anchors.rightMargin: 14
          spacing: 7
          RowLayout {
            Layout.fillWidth: true
            spacing: 4
            Text {
              Layout.fillWidth: true
              text: page.limitTitle(limit.modelData.label)
              elide: Text.ElideRight
              color: page.view.text
              font.family: page.view.host.theme.textFontFamily
              font.features: { "tnum": 1 }
              font.pixelSize: page.view.detailFontSize
            }
            // The figure stands out; "used" stays quiet beside it.
            Text {
              text: Math.round(limit.used * 100) + "%"
              color: limit.used >= 0.5 ? page.usedColor(limit.used) : page.view.text
              font.family: page.view.host.theme.textFontFamily
              font.pixelSize: page.view.detailFontSize
              font.weight: Font.Medium
              font.features: { "tnum": 1 }
            }
            Text {
              text: "used"
              color: page.view.textMuted
              font.family: page.view.host.theme.textFontFamily
              font.pixelSize: page.view.detailFontSize
            }
          }
          Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 8
            Rectangle {
              anchors.fill: parent
              radius: 4
              color: page.view.well
              Rectangle {
                width: Math.max(limit.used > 0 ? parent.height : 0, parent.width * Math.min(1, limit.used))
                Behavior on width { MotionAnimation { theme: page.view.host.theme; pace: "data" } }
                height: parent.height
                radius: parent.radius
                color: page.usedColor(limit.used)
              }
            }
          }
          Text {
            Layout.fillWidth: true
            visible: text !== ""
            text: page.resetText(limit.modelData.resetsAt)
            elide: Text.ElideRight
            color: page.view.textMuted
            font.family: page.view.host.theme.textFontFamily
            font.pixelSize: page.view.detailCaptionFontSize
            font.features: { "tnum": 1 }
          }
        }
        Rectangle {
          visible: limit.index < page.limits.length - 1
          anchors.left: parent.left
          anchors.leftMargin: 14
          anchors.right: parent.right
          anchors.rightMargin: 14
          anchors.bottom: parent.bottom
          height: 1
          color: page.view.divider
        }
      }
    }
    // No limits: why, and how to get them back.
    Item {
      visible: page.limits.length === 0
      Layout.fillWidth: true
      implicitHeight: noLimits.implicitHeight + 24
      PaneIcon {
        id: warnIcon
        view: page.view
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.top: parent.top
        anchors.topMargin: 12
        width: 24
        height: 24
        glyph: "󰀦"
        tint: page.view.host.theme.system.orange
      }
      Column {
        id: noLimits
        anchors.left: warnIcon.right
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Text {
          width: parent.width
          text: page.record ? "Limits Unavailable" : "Reading Limits…"
          color: page.view.text
          font.family: page.view.host.theme.textFontFamily
          font.features: { "tnum": 1 }
          font.pixelSize: page.view.detailFontSize
        }
        Text {
          visible: page.record !== null
          width: parent.width
          wrapMode: Text.WordWrap
          // The command in the text colour.
          textFormat: Text.StyledText
          text: (page.record && page.record.usageStatusText ? page.record.usageStatusText + ". " : "")
            + "Sign in with <font color=\"" + page.view.text + "\">" + page.provider.login + "</font> to see them."
          color: page.view.textMuted
          font.family: page.view.host.theme.textFontFamily
          font.features: { "tnum": 1 }
          font.pixelSize: page.view.detailCaptionFontSize
        }
      }
    }
  }

  // Tokens, as Screen Time's week: the daily average large, then the chart,
  // then today and the week as rows ---------------------------------------------
  SettingsGroup {
    view: page.view
    title: "Tokens"
    Item {
      Layout.fillWidth: true
      implicitHeight: chartBody.implicitHeight + 28
      ColumnLayout {
        id: chartBody
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        spacing: 12
        Column {
          spacing: 1
          Text {
            text: "Daily Average"
            color: page.view.textMuted
            font.family: page.view.host.theme.textFontFamily
            font.features: { "tnum": 1 }
            font.pixelSize: page.view.detailCaptionFontSize
          }
          Text {
            text: page.record ? page.tokens(page.average) : "—"
            color: page.view.text
            font.family: page.view.host.theme.textFontFamily
            font.pixelSize: page.view.host.theme.px(22)
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
          }
        }

        // The chart: gridlines at nothing, half, and the top of the scale,
        // their figures on the right; a bar a day, rounded on top.
        Item {
          id: chart
          Layout.fillWidth: true
          Layout.preferredHeight: 130
          readonly property real axisWidth: 44
          readonly property real plotWidth: width - axisWidth
          readonly property real plotHeight: height - 22
          readonly property real columnWidth: plotWidth / Math.max(1, page.days.length)
          // The day under the pointer, or -1.
          property int hovered: -1
          function yFor(v) { return plotHeight - plotHeight * Math.min(1, v / page.scaleTop) }

          // An empty week says so, with no scale to read.
          Text {
            visible: page.record !== null && page.busiest <= 0
            x: (chart.plotWidth - width) / 2
            y: (chart.plotHeight - height) / 2
            text: "No usage in the last 7 days"
            color: page.view.textMuted
            font.family: page.view.host.theme.textFontFamily
            font.features: { "tnum": 1 }
            font.pixelSize: page.view.detailCaptionFontSize
          }

          Repeater {
            model: [0, 0.5, 1]
            delegate: Item {
              id: grid
              required property real modelData
              y: chart.yFor(page.scaleTop * modelData)
              width: chart.width
              Rectangle {
                visible: grid.modelData === 0
                width: chart.plotWidth
                height: 1
                color: page.view.host.theme.fill("stronger")
              }
              Repeater {
                model: grid.modelData === 0 || page.busiest <= 0 ? 0 : Math.floor(chart.plotWidth / 4)
                delegate: Rectangle {
                  required property int index
                  x: index * 4
                  width: 1.5
                  height: 1
                  color: page.view.host.theme.fill("strong")
                }
              }
              Text {
                visible: page.busiest > 0
                x: chart.plotWidth + 6
                anchors.verticalCenter: parent.top
                text: grid.modelData === 0 ? "0" : page.scaleLabel(page.scaleTop * grid.modelData)
                color: page.view.textMuted
                font.family: page.view.host.theme.textFontFamily
                font.pixelSize: page.view.host.theme.px(11)
                font.features: { "tnum": 1 }
              }
            }
          }

          Repeater {
            model: page.days.length
            delegate: Item {
              id: day
              required property int index
              readonly property var modelData: page.days[index] || ({ date: "", messageCount: 0 })
              readonly property bool today: index === page.days.length - 1
              readonly property real count: modelData.messageCount || 0
              x: index * chart.columnWidth
              // The hovered day's tooltip over its neighbours' bars.
              z: dayHover.containsMouse ? 2 : 0
              width: chart.columnWidth
              height: chart.height
              // The bar, rounded only on top.
              Item {
                anchors.horizontalCenter: parent.horizontalCenter
                y: chart.plotHeight - height
                width: Math.min(chart.columnWidth * 0.5, 26)
                height: day.count > 0 ? Math.max(3, chart.plotHeight - chart.yFor(day.count)) : 0
                Behavior on height { MotionAnimation { theme: page.view.host.theme; pace: "data" } }
                clip: true
                Rectangle {
                  width: parent.width
                  height: parent.height + radius
                  radius: 4
                  // The others greyed out, as Screen Time does, rather than
                  // faded to a muddy tint.
                  color: chart.hovered === -1 || chart.hovered === day.index ? page.tint : page.view.host.theme.fill("stronger")
                  Behavior on color { MotionColorAnimation { theme: page.view.host.theme } }
                }
              }
              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                text: page.dayName(day.modelData.date, day.today)
                color: day.today ? page.view.text : page.view.textMuted
                font.family: page.view.host.theme.textFontFamily
                font.features: { "tnum": 1 }
                font.pixelSize: page.view.host.theme.px(11)
                font.weight: day.today ? Font.DemiBold : Font.Normal
              }
              MouseArea {
                id: dayHover
                anchors.fill: parent
                hoverEnabled: true
                onContainsMouseChanged: {
                  if (containsMouse) chart.hovered = day.index
                  else if (chart.hovered === day.index) chart.hovered = -1
                }
              }
              // Its total, over the bar while hovered.
              Rectangle {
                visible: dayHover.containsMouse && day.count > 0
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.max(0, chart.yFor(day.count) - height - 6)
                z: 2
                width: hoverText.implicitWidth + 16
                height: hoverText.implicitHeight + 10
                radius: 6
                color: page.view.panel
                border.width: 1
                border.color: page.view.host.theme.fill("raised")
                layer.enabled: visible
                layer.effect: MultiEffect {
                  shadowEnabled: true
                  shadowColor: Qt.rgba(0, 0, 0, 0.45)
                  shadowBlur: 0.5
                  shadowVerticalOffset: 2
                }
                Column {
                  id: hoverText
                  anchors.centerIn: parent
                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: page.dayName(day.modelData.date, day.today, true)
                    color: page.view.textMuted
                    font.family: page.view.host.theme.textFontFamily
                    font.features: { "tnum": 1 }
                    font.pixelSize: page.view.host.theme.px(10)
                  }
                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: page.tokens(day.count)
                    color: page.view.text
                    font.family: page.view.host.theme.textFontFamily
                    font.pixelSize: page.view.host.theme.px(12)
                    font.weight: Font.Medium
                    font.features: { "tnum": 1 }
                  }
                }
              }
            }
          }
        }
      }
      Rectangle {
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.bottom: parent.bottom
        height: 1
        color: page.view.divider
      }
    }
    SettingsRow {
      view: page.view
      label: "Today"
      detail: page.vsAverage()
      Text {
        text: page.tokens(page.today)
        color: page.view.textMuted
        font.family: page.view.host.theme.textFontFamily
        font.pixelSize: page.view.detailFontSize
        font.features: { "tnum": 1 }
      }
    }
    SettingsRow {
      view: page.view
      label: "Last 7 Days"
      detail: page.busiestText
      last: true
      Text {
        text: page.tokens(page.week)
        color: page.view.textMuted
        font.family: page.view.host.theme.textFontFamily
        font.pixelSize: page.view.detailFontSize
        font.features: { "tnum": 1 }
      }
    }
  }

  // Tokens by model, as Storage's bar: a segment a model, its dot, name, and
  // total under it; for All Models, a row a model with where it ran ------------
  SettingsGroup {
    visible: page.allModels ? page.modelRows.length > 0 : page.models.length > 0
    view: page.view
    title: "Tokens by Model"
    Repeater {
      model: page.allModels ? page.modelRows.length : 0
      delegate: Item {
        id: modelRow
        required property int index
        readonly property var modelData: page.modelRows[index] || ({ label: "", source: "", value: 0 })
        Layout.fillWidth: true
        implicitHeight: 44
        Column {
          anchors.left: parent.left
          anchors.leftMargin: 14
          anchors.right: modelValue.left
          anchors.rightMargin: 12
          anchors.verticalCenter: parent.verticalCenter
          spacing: 1
          Text {
            width: parent.width
            text: modelRow.modelData.label
            elide: Text.ElideRight
            color: page.view.text
            font.family: page.view.host.theme.textFontFamily
            font.features: { "tnum": 1 }
            font.pixelSize: page.view.detailFontSize
          }
          Text {
            width: parent.width
            visible: text !== ""
            text: modelRow.modelData.source
            elide: Text.ElideRight
            color: page.view.textMuted
            font.family: page.view.host.theme.textFontFamily
            font.features: { "tnum": 1 }
            font.pixelSize: page.view.detailCaptionFontSize
          }
        }
        Text {
          id: modelValue
          anchors.right: parent.right
          anchors.rightMargin: 14
          anchors.verticalCenter: parent.verticalCenter
          text: page.tokens(modelRow.modelData.value)
          color: page.view.textMuted
          font.family: page.view.host.theme.textFontFamily
          font.pixelSize: page.view.detailFontSize
          font.features: { "tnum": 1 }
        }
        Rectangle {
          visible: modelRow.index < page.modelRows.length - 1
          anchors.left: parent.left
          anchors.leftMargin: 14
          anchors.right: parent.right
          anchors.rightMargin: 14
          anchors.bottom: parent.bottom
          height: 1
          color: page.view.divider
        }
      }
    }
    Item {
      visible: !page.allModels
      Layout.fillWidth: true
      implicitHeight: modelBar.implicitHeight + 28
      UsageBar {
        id: modelBar
        view: page.view
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        barHeight: 18
        barRadius: 5
        total: page.modelTotal
        segments: page.models
      }
    }
  }
}

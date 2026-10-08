import QtQuick
import ".."

// Ask AI: text typed in the launcher can be sent to Claude or Codex (the
// Ask row, see launcherRow), answered Siri-style in the island (see
// AnswerView) through the command-line tool you're signed in to.
Addon {
  id: askAddon
  views: [{ name: "answer", component: answerView }]
  launcherHint: "ask"

  Component {
    id: answerView
    AnswerView { host: askAddon.host; ask: askAddon; active: askAddon.host.view === "answer" }
  }

  readonly property var providers: ({
    claude: { name: "Claude", cli: "claude", glyph: "", tile: "#d97757", ink: "#ffffff" },
    codex: { name: "Codex", cli: "codex", glyph: "", tile: "#f2f2f2", ink: "#000000" }
  })
  readonly property var provider: providers[addon.option("with")] || providers.codex

  property string question: ""
  function ask(text) {
    text = String(text || "").trim()
    if (!text) return
    question = text
    host.view = "answer"
  }

  // The Ask row: first when the text reads like a question.
  function launcherRow(text) {
    return {
      glyph: provider.glyph, tile: provider.tile, ink: provider.ink,
      label: "Ask " + provider.name, detail: "“" + text + "”",
      first: looksLikeQuestion(text),
      run: function() { askAddon.ask(text) }
    }
  }
  function looksLikeQuestion(text) {
    if (/\?$/.test(text)) return true
    var words = text.split(/\s+/)
    return words.length >= 3
      && /^(who|what|when|where|why|how|which|whose|can|could|should|would|is|are|was|were|do|does|did|will|explain|write|tell|give|summari[sz]e|translate|define|compare|help)$/i.test(words[0])
  }
}

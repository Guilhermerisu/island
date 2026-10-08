import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../components"

// Siri-style answers: a question typed in the launcher is sent to the chosen
// AI through its command-line tool, signed in with your own account (Claude
// Code's `claude -p`, or `codex exec`). Like Siri in the
// Dynamic Island, a compact pill with glowing dots while it thinks, then the
// answer in large type as it arrives (Claude streams word by word; Codex
// answers at once). Copy appears on hover. Esc closes (and stops a pending
// answer).
Item {
  id: answer
  required property var host
  // The addon (see AskAddon), which holds the question and the AI.
  required property var ask
  property bool active: false

  readonly property var provider: ask.provider
  property string question: ""
  property string text: ""
  property string error: ""
  property bool busy: false

  // What the model is told, plus facts about this install so answers about
  // the desktop are concrete instead of guesses: where things are
  // configured, the Omarchy commands for common jobs, and the live list of
  // key bindings (loaded once, like the Keybindings view does).
  readonly property string systemPrompt: "You answer questions typed into the search bar of Omarchy, "
    + "Be brief: give the direct answer first, then at most a few short sentences or a short list. "
    + "Reply in plain text like Siri: no Markdown, no bold, no headings, no code formatting; "
    + "write key combinations as Super+Alt+Space. For questions about this "
    + "desktop, prefer Omarchy's own tools and the facts below. Only name commands, menu entries, or "
    + "key bindings that appear below or that you are sure exist; if you are unsure, say so.\n\n"
    + "Facts about this install:\n"
    + "- Hyprland is configured in Lua in ~/.config/hypr/ (bindings.lua, hyprland.lua, input.lua, "
    + "monitors.lua, looknfeel.lua, autostart.lua). There is no hyprland.conf.\n"
    + "- Omarchy's own settings are in ~/.config/omarchy/.\n"
    + "- The Omarchy menu (Super+Alt+Space) has Style, Setup, Install, Remove, Update, and System sections.\n"
    + "- Theme: Omarchy menu > Style > Theme, or `omarchy-theme-set <name>` (`omarchy-theme-list` lists them).\n"
    + "- Wallpaper: Omarchy menu > Style > Background, `omarchy-theme-bg-next` for the next one, or "
    + "`omarchy-theme-bg-set <file>`. Extra wallpapers go in ~/.config/omarchy/backgrounds/<theme>/.\n"
    + "- Font: Omarchy menu > Style > Font, or `omarchy-font-set <name>`.\n"
    + "- Update everything: `omarchy-update` (Omarchy menu > Update).\n"
    + "- Packages: `omarchy-pkg-install` / `omarchy-pkg-remove`, or the Install and Remove menus. Web apps: `omarchy-webapp-install`.\n"
    + "- Restart the desktop shell: `omarchy-restart-shell`.\n"
    + (bindings ? "\nKey bindings (keys → action):\n" + bindings : "")

  property string bindings: ""
  Process {
    running: true
    command: ["bash", "-c", 'set -- --print; source "$(command -v omarchy-menu-keybindings)" >/dev/null; output_binding_records | cut -f1']
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: answer.bindings = String(text || "").split("\n")
        .map(function(line) { return line.replace(/\s{2,}/g, " ").trim() })
        .filter(function(line) { return line.indexOf("→") > 0 })
        .join("\n")
    }
  }

  implicitHeight: layout.implicitHeight

  onActiveChanged: {
    if (active) {
      start(ask.question)
      Qt.callLater(function() { answer.forceActiveFocus() })
    } else {
      runner.running = false
    }
  }
  Keys.onEscapePressed: host.view = "rest"

  function start(q) {
    question = String(q || "").trim()
    text = ""
    error = ""
    if (!question || !provider) return
    busy = true
    runner.running = false
    if (provider.cli === "claude") {
      runner.command = ["claude", "-p",
        "--setting-sources", "", "--strict-mcp-config", "--tools", "",
        "--model", "haiku", "--no-session-persistence",
        "--output-format", "stream-json", "--include-partial-messages", "--verbose",
        "--system-prompt", systemPrompt, question]
    } else {
      // Codex adds anything piped to it to the prompt and waits for the
      // pipe to close, so give it an empty stdin.
      runner.command = ["sh", "-c", 'exec codex exec --json --skip-git-repo-check --ephemeral -s read-only "$1" < /dev/null',
        "sh", systemPrompt + "\n\nQuestion: " + question]
    }
    runner.running = true
  }

  function handle(line) {
    var event
    try { event = JSON.parse(line) } catch (e) { return }
    if (event.type === "stream_event" && event.event && event.event.type === "content_block_delta"
        && event.event.delta && event.event.delta.type === "text_delta") {
      text += event.event.delta.text
    } else if (event.type === "result") {
      if (event.is_error) error = String(event.result || "Claude couldn't answer")
      else if (!text) text = String(event.result || "")
      busy = false
    } else if (event.type === "item.completed" && event.item && event.item.type === "agent_message") {
      text = String(event.item.text || "")
    } else if (event.type === "turn.completed") {
      busy = false
    } else if (event.type === "error" || event.type === "turn.failed") {
      error = String((event.error && event.error.message) || event.message || "Couldn't get an answer")
      busy = false
    }
  }

  Process {
    id: runner
    workingDirectory: "/tmp"
    stdout: SplitParser { onRead: function(line) { answer.handle(line) } }
    stderr: StdioCollector { id: runnerErr; waitForEnd: true }
    onExited: function(code) {
      if (answer.busy && !answer.text && !answer.error)
        answer.error = code === 0 ? "No answer came back" : (String(runnerErr.text || "").trim().split("\n").pop() || "Couldn't get an answer")
      answer.busy = false
    }
  }

  Process { id: helper }
  function copy() {
    helper.command = ["wl-copy", "--", text]
    helper.startDetached()
  }

  readonly property bool thinking: busy && !text && !error
  // A compact pill while it thinks, then wide enough for the answer.
  readonly property int surfaceWidth: thinking ? 280 : 580
  readonly property int surfacePadding: thinking ? 14 : 28
  readonly property int surfaceRadius: 44
  HoverHandler { id: hover }

  ColumnLayout {
    id: layout
    anchors.left: parent.left
    anchors.right: parent.right
    spacing: 14

    // Thinking: Siri's glowing dots in a compact pill.
    SiriDots {
      visible: answer.thinking
      running: answer.thinking && answer.active
      Layout.leftMargin: 2
    }

    // The answer in large type, like Siri; it grows as words stream in.
    Flickable {
      id: scroller
      visible: !answer.thinking
      Layout.fillWidth: true
      Layout.preferredHeight: Math.min(body.implicitHeight, 460)
      contentHeight: body.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      Text {
        id: body
        width: scroller.width
        // Plain text, like Siri; strip any Markdown the model slips in, and
        // Codex's web-search citation markers (wrapped in private-use
        // characters, e.g. "citeturn2search1").
        text: answer.error || answer.text.replace(/[^]*/g, "").replace(/[-]/g, "")
          .replace(/\*\*(.+?)\*\*/g, "$1").replace(/__(.+?)__/g, "$1")
          .replace(/`([^`]+)`/g, "$1").replace(/^#+\s*/gm, "").replace(/\[([^\]]+)\]\([^)]*\)/g, "$1")
          .replace(/[ \t]+$/gm, "").trim()
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: answer.error ? answer.host.theme.urgent : "#ffffff"
        font.family: answer.host.theme.textFontFamily
        font.pixelSize: answer.host.theme.px(21)
        font.letterSpacing: -0.3
        lineHeight: 1.1
      }
    }
  }

  // Copy: out of the way until you hover, floating over the bottom corner so
  // it doesn't take space from the answer.
  Rectangle {
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.bottomMargin: -4
    visible: answer.text !== "" && opacity > 0.01
    width: actions.implicitWidth + 24
    height: actions.implicitHeight + 12
    radius: height / 2
    color: answer.host.theme.background
    opacity: hover.hovered && !answer.busy ? 1 : 0
    Behavior on opacity { MotionAnimation { theme: answer.host.theme; pace: "fade"; curve: "fade" } }
    RowLayout {
      id: actions
      anchors.centerIn: parent
      spacing: 8
      Rectangle {
        implicitWidth: copyLabel.implicitWidth + 26
        implicitHeight: 28
        radius: 14
        color: copyMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.12)
        Text {
          id: copyLabel
          anchors.centerIn: parent
          text: "Copy"
          color: "#ffffff"
          font.family: answer.host.theme.textFontFamily
          font.pixelSize: answer.host.theme.px(12)
          font.weight: Font.DemiBold
        }
        MouseArea {
          id: copyMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: answer.copy()
        }
      }
    }
  }
}

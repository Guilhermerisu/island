import QtQuick
import Quickshell.Io

// NetworkManager's connections, through nmcli, for Settings → Network (see
// NetworkPage): the saved profiles by kind, one profile's settings and its
// live address, and what changes them: edit, connect, disconnect, forget, add
// a Wi-Fi network, import a VPN, set the hostname. Commands run one at a
// time, with their arguments passed as such (never through a shell string);
// connecting runs beside them, since it can take a minute and can be cancelled.
// Passwords reach nmcli on its stdin, out of `ps`.
// A failure's message is kept in `error` until the next command.
Item {
  id: nm

  // [{ uuid, name, type, kind, device, active }], Wi-Fi first, then Ethernet,
  // VPN, and the rest. Loopback, bridges, and other virtual links stay out.
  property var connections: []
  property string hostname: ""
  property string error: ""
  // The uuid being connected to.
  property string connecting: ""
  // The open profile's uuid, its settings ({ field: value }, the keys nmcli's
  // own, like "ipv4.method"), and when it's connected its live addresses.
  property string detailUuid: ""
  property var detail: ({})
  property var live: ({})
  // nm-connection-editor is installed: the way to what Settings doesn't cover
  // (VPN options, bridges), and zenity, which picks a certificate's file.
  property bool editorAvailable: false
  property bool filePickerAvailable: false

  readonly property var kinds: ({
    "802-11-wireless": "Wi-Fi", "802-3-ethernet": "Ethernet", "vpn": "VPN", "wireguard": "VPN",
    "gsm": "Mobile", "cdma": "Mobile", "bluetooth": "Bluetooth", "pppoe": "Other"
  })
  readonly property var kindOrder: ["Wi-Fi", "Ethernet", "VPN", "Mobile", "Bluetooth", "Other"]
  // The settings read for a connection: nmcli's own, by name, so one a
  // profile doesn't have (802.1X on a WPA2 network) is just missing.
  readonly property string detailSettings: "connection,ipv4,ipv6,802-11-wireless,802-11-wireless-security,802-3-ethernet,802-1x"

  // --- Running nmcli ---

  property var queue: []
  property var current: null
  // run(["connection", "up", uuid], function(ok, output) { … }); the message
  // of a failed one goes to `error` as well, unless `quiet`.
  function run(args, done, quiet) {
    queue = queue.concat([{ command: nmcliCommand(args), done: done, quiet: quiet }])
    next()
  }
  // Stderr joins stdout, and the exit code ends it. C locale, so the values
  // ("yes", "no") don't depend on the language.
  function nmcliCommand(args) {
    return ["bash", "-c", 'LC_ALL=C nmcli "$@" 2>&1; echo "::rc=$?"', "--"].concat(args)
  }
  function parseResult(text) {
    var match = String(text).match(/(?:^|\n)::rc=(\d+)\s*$/)
    return { ok: !!match && match[1] === "0", output: match ? String(text).slice(0, match.index) : String(text) }
  }
  function next() {
    if (current || queue.length === 0) return
    current = queue[0]
    queue = queue.slice(1)
    proc.environment = current.secret ? { ISLAND_SECRET: current.secret } : ({})
    proc.command = current.command
    proc.running = true
  }
  Process {
    id: proc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var result = nm.parseResult(text)
        var job = nm.current
        nm.current = null
        proc.environment = ({})
        if (!result.ok && !job.quiet) nm.error = result.output.trim() || "nmcli failed"
        if (job.done) job.done(result.ok, result.output)
        nm.next()
      }
    }
  }

  // nmcli -g separates values with ":" and escapes a ":" or "\" inside one
  // with a backslash.
  function unescapeValue(value) { return String(value).replace(/\\(.)/g, "$1") }
  function splitFields(line) {
    var parts = [], part = ""
    for (var i = 0; i < line.length; i++) {
      var c = line[i]
      if (c === "\\" && i + 1 < line.length) part += line[++i]
      else if (c === ":") { parts.push(part); part = "" }
      else part += c
    }
    parts.push(part)
    return parts
  }

  // --- Reading ---

  function refresh() {
    run(["-g", "NAME,UUID,TYPE,DEVICE", "connection", "show"], function(ok, output) {
      if (!ok) return
      var found = []
      output.split("\n").forEach(function(line) {
        if (line === "") return
        var cols = nm.splitFields(line)
        var kind = nm.kinds[cols[2]]
        if (kind) found.push({ uuid: cols[1], name: cols[0], type: cols[2], kind: kind, device: cols[3] || "", active: cols[3] !== "" })
      })
      found.sort(function(a, b) {
        return nm.kindOrder.indexOf(a.kind) - nm.kindOrder.indexOf(b.kind)
          || (a.active === b.active ? a.name.localeCompare(b.name) : a.active ? -1 : 1)
      })
      nm.connections = found
      // After the list: a connection's device comes from it.
      if (nm.detailUuid !== "") nm.loadDetail(nm.detailUuid)
    })
    run(["general", "hostname"], function(ok, output) { if (ok) nm.hostname = output.trim() })
    if (!checkEditor.running) checkEditor.running = true
  }
  Process {
    id: checkEditor
    command: ["sh", "-c", "command -v nm-connection-editor >/dev/null && echo editor; command -v zenity >/dev/null && echo picker"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        nm.editorAvailable = String(text).indexOf("editor") !== -1
        nm.filePickerAvailable = String(text).indexOf("picker") !== -1
      }
    }
  }

  function entry(uuid) {
    for (var i = 0; i < connections.length; i++) if (connections[i].uuid === uuid) return connections[i]
    return null
  }

  function loadDetail(uuid) {
    var item = entry(uuid)
    if (!item) { closeDetail(); return }
    detailUuid = uuid
    run(["-t", "-f", detailSettings, "connection", "show", uuid], function(ok, output) {
      if (!ok || nm.detailUuid !== uuid) return
      var values = {}
      output.split("\n").forEach(function(line) {
        var at = line.indexOf(":")
        if (at > 0) values[line.slice(0, at)] = nm.unescapeValue(line.slice(at + 1))
      })
      nm.detail = values
    })
    if (item.device === "") { live = ({}); return }
    run(["-g", "IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.ADDRESS,GENERAL.HWADDR,GENERAL.MTU", "device", "show", item.device], function(ok, output) {
      if (!ok || nm.detailUuid !== uuid) return
      var lines = output.split("\n").map(nm.unescapeValue)
      nm.live = { ip4: lines[0] || "", gateway: lines[1] || "", dns: lines[2] || "", ip6: lines[3] || "", mac: lines[4] || "", mtu: lines[5] || "" }
    })
  }
  function closeDetail() {
    detailUuid = ""
    detail = ({})
    live = ({})
  }

  // --- Changing ---

  // Applies the settings to a connection that's up, without dropping it.
  function reapply(uuid) {
    var item = entry(uuid)
    if (item && item.device !== "") run(["device", "reapply", item.device], function() { nm.loadDetail(uuid) })
  }
  // modify(uuid, ["ipv4.method", "auto", …], reapplied): nmcli's property and
  // value pairs; `reapplied` pushes IP and DNS changes to a live connection.
  function modify(uuid, pairs, reapplied) {
    if (uuid === "") return
    run(["connection", "modify", uuid].concat(pairs), function(ok) {
      if (!ok) return
      if (reapplied) nm.reapply(uuid)
      nm.refresh()
    })
  }
  // Writes a password through nmcli's editor, which reads it from stdin. It
  // can't keep a space at either end, so that's refused rather than changed.
  function setSecret(uuid, property, value, done) {
    if (uuid === "") return
    if (value !== value.trim()) {
      error = "A password can't start or end with a space."
      if (done) done(false)
      return
    }
    queue = queue.concat([{ command: ["bash", "-c", secretScript, "--", property, uuid], secret: value, done: done }])
    next()
  }
  // The editor exits 0 whatever happened, and echoes its input: only its errors
  // come out.
  readonly property string secretScript: 'out=$(printf "set %s %s\\nsave persistent\\nquit\\n" "$1" "$ISLAND_SECRET" | LC_ALL=C nmcli connection edit "$2" 2>&1); errors=$(printf "%s\\n" "$out" | grep "^Error"); if [ -n "$errors" ]; then printf "%s\\n" "$errors"; echo "::rc=1"; else echo "::rc=0"; fi'
  // secrets: [[property, value], …], one after the other; done(ok).
  function setSecrets(uuid, secrets, done) {
    if (secrets.length === 0) { done(true); return }
    setSecret(uuid, secrets[0][0], secrets[0][1], function(ok) {
      if (ok) nm.setSecrets(uuid, secrets.slice(1), done)
      else done(false)
    })
  }

  // Cancelled by taking the connection down, which ends the `up` as a failure.
  property bool connectCancelled: false
  function connect(uuid) {
    if (connecting === uuid) return
    if (connecting !== "") { error = "Still connecting to another network."; return }
    connecting = uuid
    connectCancelled = false
    upProc.command = nmcliCommand(["connection", "up", uuid])
    upProc.running = true
  }
  function cancelConnect() {
    if (connecting === "") return
    connectCancelled = true
    run(["connection", "down", connecting], null, true)
  }
  Process {
    id: upProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var result = nm.parseResult(text)
        if (!result.ok && !nm.connectCancelled) nm.error = result.output.trim() || "nmcli failed"
        nm.connecting = ""
        if (nm.active) nm.refresh()
      }
    }
  }
  function disconnect(uuid) { run(["connection", "down", uuid], function() { nm.refresh() }) }
  function forget(uuid) {
    run(["connection", "delete", uuid], function(ok) {
      if (!ok) return
      nm.closeDetail()
      nm.refresh()
    })
  }
  // `security` is the extra nmcli arguments of its security, and `secrets` its
  // passwords (see setSecrets). A profile whose passwords don't save is removed.
  function addWifi(ssid, hidden, security, secrets, then) {
    var args = ["connection", "add", "type", "wifi", "ifname", "*", "con-name", ssid, "ssid", ssid, "wifi.hidden", hidden ? "yes" : "no"].concat(security)
    run(args, function(ok, output) {
      if (!ok) return
      // By uuid: another profile can have the same name.
      var added = output.match(/\(([0-9a-fA-F-]{36})\)/)
      if (!added) { nm.error = output.trim(); nm.refresh(); return }
      nm.setSecrets(added[1], secrets, function(saved) {
        if (!saved) { nm.run(["connection", "delete", added[1]], function() { nm.refresh() }); return }
        nm.refresh()
        nm.connect(added[1])
        if (then) then()
      })
    })
  }
  // type: "wireguard" or "openvpn"
  function importVpn(type, path, then) {
    run(["connection", "import", "type", type, "file", path], function(ok) {
      if (!ok) return
      nm.refresh()
      if (then) then()
    })
  }
  function setHostname(name) {
    run(["general", "hostname", name], function() { nm.refresh() })
  }
  // Asks for a certificate or key file; done(path) gets the chosen one.
  Process {
    id: picker
    property var done: null
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var path = String(text).trim()
        if (path !== "" && picker.done) picker.done(path)
      }
    }
  }
  function pickFile(done) {
    if (picker.running) return
    picker.done = done
    picker.command = ["zenity", "--file-selection", "--title=Choose a file"]
    picker.running = true
  }
  Process { id: editor }
  function openEditor(uuid) {
    editor.command = ["nm-connection-editor", "--edit", uuid]
    editor.startDetached()
  }

  // Read while Settings → Network is open, and dropped when it closes.
  property bool active: false
  onActiveChanged: {
    if (active) refresh()
    else { closeDetail(); error = "" }
  }
}

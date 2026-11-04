import QtQuick
import QtQuick.Layouts
import "../controls"
import "../../../services"

// Settings → Network: what nmtui does, in a pane. The saved connections by
// kind (Wi-Fi, Ethernet, VPN), the computer's hostname, adding a Wi-Fi network
// or importing a VPN; and, opened from a connection, its status and addresses,
// its IPv4 and IPv6 setup, and its Wi-Fi options, connecting, disconnecting,
// and forgetting it. Everything goes through NetworkManager (see
// NetworkConnections). Plain fields save as they're committed; the address
// setup waits for Apply, since a manual one needs its address.
ColumnLayout {
  id: page
  required property var view
  visible: view.currentPage === "Network"
  Layout.fillWidth: true
  spacing: 20

  readonly property bool shown: view.active && view.currentPage === "Network"
  NetworkConnections { id: client; active: page.shown }

  readonly property bool detailOpen: client.detailUuid !== ""
  readonly property var item: client.entry(client.detailUuid)
  readonly property var d: client.detail
  readonly property bool wifi: !!item && item.type === "802-11-wireless"
  readonly property string keyMgmt: d["802-11-wireless-security.key-mgmt"] || ""
  readonly property bool hasPassword: keyMgmt === "wpa-psk" || keyMgmt === "sae"
  readonly property bool connecting: !!item && client.connecting === item.uuid

  readonly property var kindIcons: ({ "Wi-Fi": "󰖩", "Ethernet": "󰈀", "VPN": "󰦝", "Mobile": "󰢾", "Bluetooth": "󰂯", "Other": "󰛳" })
  readonly property var kindTints: ({
    "Wi-Fi": view.host.theme.system.blue, "Ethernet": view.host.theme.system.gray, "VPN": view.host.theme.system.green,
    "Mobile": view.host.theme.system.orange, "Bluetooth": view.host.theme.system.blue, "Other": view.host.theme.system.gray
  })
  readonly property color green: view.host.theme.system.green
  readonly property var shownKinds: client.kindOrder.filter(function(kind) {
    return client.connections.some(function(c) { return c.kind === kind })
  })

  // The address setup being edited, per protocol: { method, addr, gw, dns, ignore }.
  property var edit: ({ ipv4: {}, ipv6: {} })
  // What the profile has for each, the connection they're of, and the ones just
  // applied, which the next read replaces with what NetworkManager made of them.
  property var editBase: ({ ipv4: {}, ipv6: {} })
  property string editUuid: ""
  property var applied: ({})
  function sameEdit(a, b) {
    return a.method === b.method && a.addr === b.addr && a.gw === b.gw && a.dns === b.dns && a.ignore === b.ignore
  }
  // Rereads them; one being edited stays, whatever else changed on the connection.
  function loadEdits() {
    var next = {}, base = {}
    ;["ipv4", "ipv6"].forEach(function(p) {
      base[p] = {
        method: d[p + ".method"] || "auto", addr: d[p + ".addresses"] || "", gw: d[p + ".gateway"] || "",
        dns: d[p + ".dns"] || "", ignore: d[p + ".ignore-auto-dns"] === "yes"
      }
      var keep = editUuid === client.detailUuid && !applied[p] && !sameEdit(edit[p], editBase[p])
      next[p] = keep ? edit[p] : base[p]
    })
    editUuid = client.detailUuid
    editBase = base
    edit = next
    applied = ({})
    confirmForget = false
  }
  Connections {
    target: client
    function onDetailChanged() { page.loadEdits() }
  }
  function setEdit(proto, key, value) {
    var next = Object.assign({}, edit)
    next[proto] = Object.assign({}, next[proto])
    next[proto][key] = value
    edit = next
  }
  function dirty(proto) { return !sameEdit(edit[proto], editBase[proto]) }
  function revertEdit(proto) {
    view.forceActiveFocus()
    var next = Object.assign({}, edit)
    next[proto] = editBase[proto]
    edit = next
  }
  function applyEdit(proto) {
    // Commits the field being typed in.
    view.forceActiveFocus()
    var e = edit[proto]
    var manual = e.method === "manual"
    if (manual && e.addr === "") { client.error = "A manual setup needs an address, like 192.168.1.20/24."; return }
    // Only automatic and manual setups use DNS servers.
    var usesDns = manual || e.method === "auto" || e.method === "dhcp"
    var done = Object.assign({}, applied)
    done[proto] = true
    applied = done
    client.modify(client.detailUuid, [
      proto + ".method", e.method,
      proto + ".addresses", manual ? e.addr : "",
      proto + ".gateway", manual ? e.gw : "",
      proto + ".dns", usesDns ? e.dns : "",
      proto + ".ignore-auto-dns", usesDns && e.ignore ? "yes" : "no"
    ], true)
  }

  // 802.1X, the sign-in of company and campus networks: the profile's method,
  // and the files its certificates and key are read from.
  readonly property string eap: d["802-1x.eap"] || ""
  readonly property bool tunnelled: eap === "peap" || eap === "ttls" || eap === "fast"
  readonly property var eapMethods: [{ label: "PEAP", value: "peap" }, { label: "TTLS", value: "ttls" }, { label: "TLS (certificate)", value: "tls" }, { label: "FAST", value: "fast" }, { label: "LEAP", value: "leap" }, { label: "PWD", value: "pwd" }]
  readonly property var innerMethods: [{ label: "None", value: "" }, { label: "MSCHAPv2", value: "mschapv2" }, { label: "MSCHAP", value: "mschap" }, { label: "PAP", value: "pap" }, { label: "CHAP", value: "chap" }, { label: "GTC", value: "gtc" }, { label: "MD5", value: "md5" }, { label: "TLS", value: "tls" }]
  function pathOf(value) { return String(value || "").replace(/^file:\/\//, "") }
  // nmcli doesn't expand "~".
  function expand(path) { return path.replace(/^~(?=\/|$)/, view.host.home) }
  // Sets one 802.1X value, a path for the files; empty clears it.
  function setEap(key, value) { client.modify(client.detailUuid, ["802-1x." + key, value], false) }
  function setEapPath(key, value) { setEap(key, expand(value)) }
  function setEapSecret(key, value) { client.setSecret(client.detailUuid, "802-1x." + key, value) }

  property bool confirmForget: false
  // "wifi" or "vpn" while that form is open.
  property string adding: ""
  property string newSsid: ""
  property bool newHidden: false
  property string newSec: "psk"
  property string newKey: ""
  property string newEap: "peap"
  property string newIdentity: ""
  property string newEapPassword: ""
  property string newInner: "mschapv2"
  property string newCa: ""
  property string newClientCert: ""
  property string newPrivateKey: ""
  property string newKeyPassword: ""
  property string vpnType: "wireguard"
  property string vpnPath: ""
  onShownChanged: if (!shown) adding = ""
  // Leaving the form forgets what was typed in it, passwords above all.
  onAddingChanged: {
    newSsid = ""
    newHidden = false
    newKey = ""
    newIdentity = ""
    newEapPassword = ""
    newCa = ""
    newClientCert = ""
    newPrivateKey = ""
    newKeyPassword = ""
    vpnPath = ""
  }

  component ValueText: Text {
    color: page.view.textMuted
    font.family: page.view.host.theme.textFontFamily
    font.letterSpacing: page.view.host.theme.tracking(page.view.host.theme.textFontFamily, page.view.detailFontSize)
    font.pixelSize: page.view.detailFontSize
    elide: Text.ElideRight
  }

  // The fill behind a row of a group's card (the connected one's green, the
  // hover): flush with the card's inside, so its first and last row follow the
  // card's rounded corners instead of floating inside them.
  component RowFill: Rectangle {
    id: fill
    property bool first: false
    property bool last: false
    // The card's radius less its 1 px border.
    readonly property real corner: page.view.host.theme.radii.card - 1
    anchors.fill: parent
    anchors.leftMargin: 1
    anchors.rightMargin: 1
    anchors.topMargin: first ? 1 : 0
    anchors.bottomMargin: last ? 1 : 0
    radius: 0
    topLeftRadius: first ? corner : 0
    topRightRadius: first ? corner : 0
    bottomLeftRadius: last ? corner : 0
    bottomRightRadius: last ? corner : 0
  }

  // A file's path, typed or chosen in a file dialog. `committed` gets the path.
  component PathField: Row {
    id: pathField
    required property var view
    required property var nmClient
    property string value: ""
    property string placeholder: "/path/to/file"
    signal committed(string value)
    spacing: 6
    SettingsTextField { view: pathField.view; value: pathField.value; placeholder: pathField.placeholder; onCommitted: function(v) { pathField.committed(v) } }
    SettingsButton {
      visible: pathField.nmClient.filePickerAvailable
      view: pathField.view
      label: "Choose…"
      onClicked: pathField.nmClient.pickFile(function(path) { pathField.committed(path) })
    }
  }

  // A failure from nmcli, until the next command or dismissed.
  Rectangle {
    visible: client.error !== ""
    Layout.fillWidth: true
    implicitHeight: errorText.implicitHeight + 24
    radius: page.view.host.theme.radii.card
    color: page.view.card
    border.width: 1
    border.color: page.view.edge
    Text {
      id: errorIcon
      anchors.left: parent.left
      anchors.leftMargin: 14
      anchors.verticalCenter: parent.verticalCenter
      text: "󰀪"
      color: page.view.host.theme.system.yellow
      font.family: page.view.host.theme.fontFamily
      font.pixelSize: page.view.host.theme.px(16)
    }
    Text {
      id: errorText
      anchors.left: errorIcon.right
      anchors.leftMargin: 10
      anchors.right: dismiss.left
      anchors.rightMargin: 10
      anchors.verticalCenter: parent.verticalCenter
      text: client.error
      textFormat: Text.PlainText
      wrapMode: Text.Wrap
      color: page.view.text
      font.family: page.view.host.theme.textFontFamily
      font.pixelSize: page.view.detailCaptionFontSize
    }
    SettingsButton {
      id: dismiss
      view: page.view
      label: "Dismiss"
      anchors.right: parent.right
      anchors.rightMargin: 10
      anchors.verticalCenter: parent.verticalCenter
      onClicked: client.error = ""
    }
  }

  // ---------- The connections ----------

  ColumnLayout {
    visible: !page.detailOpen
    Layout.fillWidth: true
    spacing: 20

    SettingsGroup {
      view: page.view
      title: "This Computer"
      SettingsRow {
        view: page.view
        label: "Hostname"
        detail: "The name this computer has on the network"
        last: true
        SettingsTextField {
          view: page.view
          value: client.hostname
          placeholder: "hostname"
          onCommitted: function(v) { if (v !== "") client.setHostname(v) }
        }
      }
    }

    Repeater {
      model: page.shownKinds
      delegate: SettingsGroup {
        id: kindGroup
        required property string modelData
        readonly property var members: client.connections.filter(function(c) { return c.kind === modelData })
        view: page.view
        title: modelData
        count: String(members.length)
        Repeater {
          model: kindGroup.members
          delegate: Item {
            id: connectionRow
            required property var modelData
            required property int index
            Layout.fillWidth: true
            implicitHeight: row.implicitHeight
            readonly property bool first: connectionRow.index === 0
            readonly property bool final: connectionRow.index === kindGroup.members.length - 1
            // The connected one stands out in green, the one under the pointer lightly.
            RowFill {
              visible: connectionRow.modelData.active
              first: connectionRow.first
              last: connectionRow.final
              color: page.view.host.theme.withAlpha(page.green, 0.16)
              border.width: 1
              border.color: page.view.host.theme.withAlpha(page.green, 0.4)
            }
            RowFill {
              visible: !connectionRow.modelData.active && rowMouse.containsMouse
              first: connectionRow.first
              last: connectionRow.final
              color: page.view.host.theme.fill("quiet")
            }
            SettingsRow {
              id: row
              view: page.view
              anchors.left: parent.left
              anchors.right: parent.right
              icon: page.kindIcons[connectionRow.modelData.kind] || ""
              iconTint: connectionRow.modelData.active ? page.green : page.kindTints[connectionRow.modelData.kind] || page.view.accent
              label: connectionRow.modelData.name
              detail: client.connecting === connectionRow.modelData.uuid ? "Connecting…" : connectionRow.modelData.active ? "Connected · " + connectionRow.modelData.device : "Not connected"
              // The green row has its own edge.
              last: connectionRow.final || connectionRow.modelData.active
              ValueText { text: "󰅂"; font.family: page.view.host.theme.fontFamily }
            }
            MouseArea {
              id: rowMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: client.loadDetail(connectionRow.modelData.uuid)
            }
          }
        }
      }
    }

    SettingsGroup {
      view: page.view
      title: "Add"
      SettingsRow {
        view: page.view
        label: "Wi-Fi Network"
        detail: "Join a hidden network, or one that isn't in range"
        SettingsButton { view: page.view; label: page.adding === "wifi" ? "Cancel" : "Add…"; onClicked: page.adding = page.adding === "wifi" ? "" : "wifi" }
      }
      SettingsRow {
        view: page.view
        label: "VPN"
        detail: "Import a WireGuard or OpenVPN configuration file"
        last: true
        SettingsButton { view: page.view; label: page.adding === "vpn" ? "Cancel" : "Import…"; onClicked: page.adding = page.adding === "vpn" ? "" : "vpn" }
      }
    }

    SettingsGroup {
      id: wifiForm
      visible: page.adding === "wifi"
      view: page.view
      title: "New Wi-Fi Network"
      readonly property bool enterprise: page.newSec === "eap"
      readonly property bool newTunnelled: page.newEap === "peap" || page.newEap === "ttls" || page.newEap === "fast"
      SettingsRow {
        view: page.view
        label: "Network Name"
        SettingsTextField { view: page.view; value: page.newSsid; placeholder: "SSID"; onCommitted: function(v) { page.newSsid = v } }
      }
      SettingsRow {
        view: page.view
        label: "Security"
        SettingsPopUp {
          view: page.view
          options: [{ label: "Open", value: "open" }, { label: "WPA/WPA2 Personal", value: "psk" }, { label: "WPA Enterprise", value: "eap" }]
          value: page.newSec
          onPicked: function(v) { page.newSec = v }
        }
      }
      SettingsRow {
        view: page.view
        label: "Hidden"
        detail: "The network doesn't announce its name"
        last: page.newSec === "open"
        SettingsSwitch { view: page.view; checked: page.newHidden; onToggled: function(on) { page.newHidden = on } }
      }
      SettingsRow {
        view: page.view
        visible: page.newSec === "psk"
        label: "Password"
        last: true
        SettingsTextField { view: page.view; secret: true; value: page.newKey; placeholder: "Password"; onCommitted: function(v) { page.newKey = v } }
      }
      SettingsRow {
        view: page.view
        visible: wifiForm.enterprise
        label: "Method"
        SettingsPopUp { view: page.view; options: page.eapMethods; value: page.newEap; onPicked: function(v) { page.newEap = v } }
      }
      SettingsRow {
        view: page.view
        visible: wifiForm.enterprise
        label: "Identity"
        detail: "Your user name"
        SettingsTextField { view: page.view; value: page.newIdentity; placeholder: "user@example.com"; onCommitted: function(v) { page.newIdentity = v } }
      }
      SettingsRow {
        view: page.view
        visible: wifiForm.enterprise && page.newEap !== "tls"
        label: "Password"
        SettingsTextField { view: page.view; secret: true; value: page.newEapPassword; placeholder: "Password"; onCommitted: function(v) { page.newEapPassword = v } }
      }
      SettingsRow {
        view: page.view
        visible: wifiForm.enterprise && wifiForm.newTunnelled
        label: "Inner Authentication"
        SettingsPopUp { view: page.view; options: page.innerMethods; value: page.newInner; onPicked: function(v) { page.newInner = v } }
      }
      SettingsRow {
        view: page.view
        visible: wifiForm.enterprise
        label: "CA Certificate"
        detail: "Empty: the system's certificates"
        last: page.newEap !== "tls"
        PathField { view: page.view; nmClient: client; value: page.newCa; placeholder: "/path/to/ca.pem"; onCommitted: function(v) { page.newCa = v } }
      }
      SettingsRow {
        view: page.view
        visible: wifiForm.enterprise && page.newEap === "tls"
        label: "Client Certificate"
        PathField { view: page.view; nmClient: client; value: page.newClientCert; placeholder: "/path/to/client.pem"; onCommitted: function(v) { page.newClientCert = v } }
      }
      SettingsRow {
        view: page.view
        visible: wifiForm.enterprise && page.newEap === "tls"
        label: "Private Key"
        PathField { view: page.view; nmClient: client; value: page.newPrivateKey; placeholder: "/path/to/key.pem"; onCommitted: function(v) { page.newPrivateKey = v } }
      }
      SettingsRow {
        view: page.view
        visible: wifiForm.enterprise && page.newEap === "tls"
        label: "Key Password"
        last: true
        SettingsTextField { view: page.view; secret: true; value: page.newKeyPassword; placeholder: "Password"; onCommitted: function(v) { page.newKeyPassword = v } }
      }
      Item {
        Layout.fillWidth: true
        implicitHeight: 44
        SettingsButton {
          view: page.view
          primary: true
          label: "Add and Connect"
          anchors.right: parent.right
          anchors.rightMargin: 14
          anchors.verticalCenter: parent.verticalCenter
          onClicked: {
            // Commits the field being typed in.
            page.view.forceActiveFocus()
            var security = [], secrets = []
            if (page.newSsid === "") { client.error = "Enter the network's name."; return }
            if (page.newSec === "psk") {
              if (page.newKey === "") { client.error = "Enter the network's password."; return }
              security = ["wifi-sec.key-mgmt", "wpa-psk"]
              secrets = [["802-11-wireless-security.psk", page.newKey]]
            } else if (page.newSec === "eap") {
              if (page.newIdentity === "") { client.error = "Enter your identity."; return }
              security = ["wifi-sec.key-mgmt", "wpa-eap", "802-1x.eap", page.newEap, "802-1x.identity", page.newIdentity]
              if (page.newEap !== "tls" && page.newEapPassword !== "") secrets = [["802-1x.password", page.newEapPassword]]
              if (wifiForm.newTunnelled && page.newInner !== "") security = security.concat(["802-1x.phase2-auth", page.newInner])
              if (page.newCa !== "") security = security.concat(["802-1x.ca-cert", page.expand(page.newCa)])
              else security = security.concat(["802-1x.system-ca-certs", "yes"])
              if (page.newEap === "tls") {
                if (page.newClientCert === "" || page.newPrivateKey === "") { client.error = "TLS needs a client certificate and a private key."; return }
                security = security.concat(["802-1x.client-cert", page.expand(page.newClientCert), "802-1x.private-key", page.expand(page.newPrivateKey)])
                if (page.newKeyPassword !== "") secrets = [["802-1x.private-key-password", page.newKeyPassword]]
              }
            }
            client.addWifi(page.newSsid, page.newHidden, security, secrets, function() { page.adding = "" })
          }
        }
      }
    }

    SettingsGroup {
      visible: page.adding === "vpn"
      view: page.view
      title: "Import VPN"
      SettingsRow {
        view: page.view
        label: "Type"
        SettingsSegmented {
          view: page.view
          options: [{ label: "WireGuard", value: "wireguard" }, { label: "OpenVPN", value: "openvpn" }]
          value: page.vpnType
          onPicked: function(v) { page.vpnType = v }
        }
      }
      SettingsRow {
        view: page.view
        label: "File"
        detail: "Path to the .conf or .ovpn file"
        last: true
        SettingsTextField { view: page.view; value: page.vpnPath; placeholder: "~/vpn.conf"; onCommitted: function(v) { page.vpnPath = v } }
      }
      Item {
        Layout.fillWidth: true
        implicitHeight: 44
        SettingsButton {
          view: page.view
          primary: true
          label: "Import"
          anchors.right: parent.right
          anchors.rightMargin: 14
          anchors.verticalCenter: parent.verticalCenter
          onClicked: {
            // Commits the field being typed in.
            page.view.forceActiveFocus()
            if (page.vpnPath === "") { client.error = "Enter the file's path."; return }
            client.importVpn(page.vpnType, page.expand(page.vpnPath), function() { page.adding = "" })
          }
        }
      }
    }
  }

  // ---------- One connection ----------

  ColumnLayout {
    visible: page.detailOpen && !!page.item
    Layout.fillWidth: true
    spacing: 20

    RowLayout {
      Layout.fillWidth: true
      SettingsButton { view: page.view; label: "‹  All Connections"; onClicked: { page.view.forceActiveFocus(); client.closeDetail() } }
      Item { Layout.fillWidth: true }
      SettingsButton {
        view: page.view
        primary: !page.connecting && !(page.item && page.item.active)
        label: page.connecting ? "Cancel" : page.item && page.item.active ? "Disconnect" : "Connect"
        onClicked: page.connecting ? client.cancelConnect() : page.item.active ? client.disconnect(page.item.uuid) : client.connect(page.item.uuid)
      }
    }

    SettingsGroup {
      view: page.view
      title: "Status"
      SettingsRow {
        view: page.view
        label: "Name"
        SettingsTextField {
          view: page.view
          value: page.d["connection.id"] || ""
          onCommitted: function(v) { if (v !== "") client.modify(client.detailUuid, ["connection.id", v], false) }
        }
      }
      SettingsRow {
        view: page.view
        label: "State"
        last: !page.item || !page.item.active
        ValueText {
          text: page.connecting ? "Connecting…" : page.item && page.item.active ? "Connected on " + page.item.device : "Not connected"
          color: page.item && page.item.active ? page.green : page.view.textMuted
        }
      }
      SettingsRow {
        view: page.view
        visible: !!page.item && page.item.active && !!client.live.ip4
        label: "IP Address"
        ValueText { text: client.live.ip4 || "" }
      }
      SettingsRow {
        view: page.view
        visible: !!page.item && page.item.active && !!client.live.gateway
        label: "Router"
        ValueText { text: client.live.gateway || "" }
      }
      SettingsRow {
        view: page.view
        visible: !!page.item && page.item.active && !!client.live.dns
        label: "DNS Servers"
        ValueText { text: (client.live.dns || "").replace(/ \| /g, ", ") }
      }
      SettingsRow {
        view: page.view
        visible: !!page.item && page.item.active && !!client.live.mac
        label: "Hardware Address"
        last: true
        ValueText { text: client.live.mac || "" }
      }
    }

    SettingsGroup {
      view: page.view
      title: "General"
      SettingsRow {
        view: page.view
        label: "Connect Automatically"
        detail: "Join whenever it's in range"
        SettingsSwitch {
          view: page.view
          checked: page.d["connection.autoconnect"] === "yes"
          onToggled: function(on) { client.modify(client.detailUuid, ["connection.autoconnect", on ? "yes" : "no"], false) }
        }
      }
      SettingsRow {
        view: page.view
        label: "Priority"
        detail: "The higher one is joined first"
        last: true
        SettingsTextField {
          view: page.view
          implicitWidth: 80
          value: page.d["connection.autoconnect-priority"] || "0"
          onCommitted: function(v) {
            if (/^-?\d+$/.test(v)) client.modify(client.detailUuid, ["connection.autoconnect-priority", v], false)
            else client.error = "The priority is a whole number."
          }
        }
      }
    }

    Repeater {
      model: [
        { proto: "ipv4", title: "IPv4", example: "192.168.1.20/24", gateway: "192.168.1.1",
          methods: [{ label: "Automatic (DHCP)", value: "auto" }, { label: "Manual", value: "manual" }, { label: "Link-Local Only", value: "link-local" }, { label: "Shared", value: "shared" }, { label: "Off", value: "disabled" }] },
        { proto: "ipv6", title: "IPv6", example: "fd00::20/64", gateway: "fd00::1",
          methods: [{ label: "Automatic", value: "auto" }, { label: "Automatic (DHCP Only)", value: "dhcp" }, { label: "Manual", value: "manual" }, { label: "Link-Local Only", value: "link-local" }, { label: "Off", value: "disabled" }, { label: "Ignore", value: "ignore" }] }
      ]
      delegate: SettingsGroup {
        id: ipGroup
        required property var modelData
        readonly property var e: page.edit[modelData.proto] || ({})
        readonly property bool manual: e.method === "manual"
        readonly property bool usesDns: manual || e.method === "auto" || e.method === "dhcp"
        view: page.view
        title: modelData.title
        SettingsRow {
          view: page.view
          label: "Configure"
          last: !ipGroup.manual && !ipGroup.usesDns && !page.dirty(ipGroup.modelData.proto)
          SettingsPopUp {
            view: page.view
            options: ipGroup.modelData.methods
            value: ipGroup.e.method
            onPicked: function(v) { page.setEdit(ipGroup.modelData.proto, "method", v) }
          }
        }
        SettingsRow {
          view: page.view
          visible: ipGroup.manual
          label: "Address"
          detail: "With its prefix, like " + ipGroup.modelData.example
          SettingsTextField { view: page.view; value: ipGroup.e.addr || ""; placeholder: ipGroup.modelData.example; onEdited: function(v) { page.setEdit(ipGroup.modelData.proto, "addr", v) } }
        }
        SettingsRow {
          view: page.view
          visible: ipGroup.manual
          label: "Router"
          SettingsTextField { view: page.view; value: ipGroup.e.gw || ""; placeholder: ipGroup.modelData.gateway; onEdited: function(v) { page.setEdit(ipGroup.modelData.proto, "gw", v) } }
        }
        SettingsRow {
          view: page.view
          visible: ipGroup.usesDns
          label: "DNS Servers"
          detail: "Separated by commas"
          last: !(ipGroup.e.method === "auto" || ipGroup.e.method === "dhcp") && !page.dirty(ipGroup.modelData.proto)
          SettingsTextField { view: page.view; value: ipGroup.e.dns || ""; placeholder: "Automatic"; onEdited: function(v) { page.setEdit(ipGroup.modelData.proto, "dns", v) } }
        }
        SettingsRow {
          view: page.view
          visible: ipGroup.e.method === "auto" || ipGroup.e.method === "dhcp"
          label: "Only Use These DNS Servers"
          detail: "Ignore the ones the network hands out"
          last: !page.dirty(ipGroup.modelData.proto)
          SettingsSwitch { view: page.view; checked: !!ipGroup.e.ignore; onToggled: function(on) { page.setEdit(ipGroup.modelData.proto, "ignore", on) } }
        }
        Item {
          visible: page.dirty(ipGroup.modelData.proto)
          Layout.fillWidth: true
          implicitHeight: 44
          Row {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            SettingsButton { view: page.view; label: "Revert"; onClicked: page.revertEdit(ipGroup.modelData.proto) }
            SettingsButton { view: page.view; primary: true; label: "Apply"; onClicked: page.applyEdit(ipGroup.modelData.proto) }
          }
        }
      }
    }

    SettingsGroup {
      visible: page.wifi
      view: page.view
      title: "Wi-Fi"
      SettingsRow {
        view: page.view
        label: "Network Name"
        ValueText { text: page.d["802-11-wireless.ssid"] || "" }
      }
      SettingsRow {
        view: page.view
        label: "Security"
        detail: page.hasPassword ? "" : page.eap !== "" ? "Set up under 802.1X below" : "Other setups are edited in Advanced Settings"
        ValueText {
          text: ({ "wpa-psk": "WPA/WPA2 Personal", "sae": "WPA3 Personal", "wpa-eap": "WPA Enterprise", "ieee8021x": "802.1X", "none": "WEP", "": "None" })[page.keyMgmt] || page.keyMgmt
        }
      }
      SettingsRow {
        view: page.view
        visible: page.hasPassword
        label: "Password"
        detail: "Type a new one to change it"
        SettingsTextField {
          view: page.view
          secret: true
          writeOnly: true
          placeholder: "Unchanged"
          onCommitted: function(v) { if (v !== "") client.setSecret(client.detailUuid, "802-11-wireless-security.psk", v) }
        }
      }
      SettingsRow {
        view: page.view
        label: "Hidden Network"
        SettingsSwitch {
          view: page.view
          checked: page.d["802-11-wireless.hidden"] === "yes"
          onToggled: function(on) { client.modify(client.detailUuid, ["802-11-wireless.hidden", on ? "yes" : "no"], false) }
        }
      }
      SettingsRow {
        view: page.view
        label: "Private Address"
        detail: "The hardware address it presents"
        last: true
        SettingsPopUp {
          view: page.view
          options: [{ label: "Default", value: "" }, { label: "Random", value: "random" }, { label: "Stable", value: "stable" }, { label: "Permanent", value: "permanent" }]
          value: page.d["802-11-wireless.cloned-mac-address"] || ""
          onPicked: function(v) { client.modify(client.detailUuid, ["802-11-wireless.cloned-mac-address", v], false) }
        }
      }
    }

    SettingsGroup {
      visible: page.eap !== ""
      view: page.view
      title: "802.1X"
      footer: "Files are read when the connection is made. Passwords are only written, never shown."
      SettingsRow {
        view: page.view
        label: "Method"
        SettingsPopUp { view: page.view; options: page.eapMethods; value: page.eap; onPicked: function(v) { page.setEap("eap", v) } }
      }
      SettingsRow {
        view: page.view
        label: "Identity"
        SettingsTextField { view: page.view; value: page.d["802-1x.identity"] || ""; onCommitted: function(v) { page.setEap("identity", v) } }
      }
      SettingsRow {
        view: page.view
        visible: page.tunnelled
        label: "Anonymous Identity"
        detail: "Sent in the clear, before the tunnel"
        SettingsTextField { view: page.view; value: page.d["802-1x.anonymous-identity"] || ""; onCommitted: function(v) { page.setEap("anonymous-identity", v) } }
      }
      SettingsRow {
        view: page.view
        visible: page.eap !== "tls"
        label: "Password"
        detail: "Type a new one to change it"
        SettingsTextField { view: page.view; secret: true; writeOnly: true; placeholder: "Unchanged"; onCommitted: function(v) { if (v !== "") page.setEapSecret("password", v) } }
      }
      SettingsRow {
        view: page.view
        visible: page.tunnelled
        label: "Inner Authentication"
        SettingsPopUp { view: page.view; options: page.innerMethods; value: page.d["802-1x.phase2-auth"] || ""; onPicked: function(v) { page.setEap("phase2-auth", v) } }
      }
      SettingsRow {
        view: page.view
        label: "CA Certificate"
        detail: "Checks the network is the right one"
        PathField { view: page.view; nmClient: client; value: page.pathOf(page.d["802-1x.ca-cert"]); placeholder: "None"; onCommitted: function(v) { page.setEapPath("ca-cert", v) } }
      }
      SettingsRow {
        view: page.view
        label: "Use System Certificates"
        detail: "Trust the certificates already on this computer"
        SettingsSwitch { view: page.view; checked: page.d["802-1x.system-ca-certs"] === "yes"; onToggled: function(on) { page.setEap("system-ca-certs", on ? "yes" : "no") } }
      }
      SettingsRow {
        view: page.view
        label: "Server Domain"
        detail: "The name its certificate must end with"
        last: page.eap !== "tls"
        SettingsTextField { view: page.view; value: page.d["802-1x.domain-suffix-match"] || ""; placeholder: "corp.example.com"; onCommitted: function(v) { page.setEap("domain-suffix-match", v) } }
      }
      SettingsRow {
        view: page.view
        visible: page.eap === "tls"
        label: "Client Certificate"
        PathField { view: page.view; nmClient: client; value: page.pathOf(page.d["802-1x.client-cert"]); placeholder: "None"; onCommitted: function(v) { page.setEapPath("client-cert", v) } }
      }
      SettingsRow {
        view: page.view
        visible: page.eap === "tls"
        label: "Private Key"
        PathField { view: page.view; nmClient: client; value: page.pathOf(page.d["802-1x.private-key"]); placeholder: "None"; onCommitted: function(v) { page.setEapPath("private-key", v) } }
      }
      SettingsRow {
        view: page.view
        visible: page.eap === "tls"
        label: "Key Password"
        last: true
        SettingsTextField { view: page.view; secret: true; writeOnly: true; placeholder: "Unchanged"; onCommitted: function(v) { if (v !== "") page.setEapSecret("private-key-password", v) } }
      }
    }

    SettingsGroup {
      view: page.view
      title: "Manage"
      SettingsRow {
        view: page.view
        visible: client.editorAvailable
        label: "Advanced Settings"
        detail: "802.1X, VPN options, and more, in NetworkManager's editor"
        SettingsButton { view: page.view; label: "Open…"; onClicked: client.openEditor(client.detailUuid) }
      }
      SettingsRow {
        view: page.view
        label: page.wifi ? "Forget This Network" : "Delete This Connection"
        detail: page.confirmForget ? "This removes its saved settings." : ""
        last: true
        Row {
          spacing: 8
          SettingsButton { visible: page.confirmForget; view: page.view; label: "Cancel"; onClicked: page.confirmForget = false }
          SettingsButton {
            view: page.view
            primary: page.confirmForget
            label: page.confirmForget ? (page.wifi ? "Forget" : "Delete") : (page.wifi ? "Forget…" : "Delete…")
            onClicked: page.confirmForget ? client.forget(client.detailUuid) : page.confirmForget = true
          }
        }
      }
    }
  }
}

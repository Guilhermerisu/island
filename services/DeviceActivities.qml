import QtQuick
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.UPower

// Device live activities: the battery starting to charge or running low, a
// Bluetooth device connecting or disconnecting, and Wi-Fi or Ethernet
// connecting or disconnecting. Each sends `show` with the
// DevicePill's fields (see its header), kept in `current`.
Item {
  id: activities
  required property var settings
  // The last one shown.
  property var current: ({})
  signal show(var activity)
  function announce(activity) {
    current = activity
    show(activity)
  }

  // For a few seconds after the shell starts, everything is only recorded:
  // devices reporting in aren't news.
  property bool ready: false
  Timer {
    interval: 3000
    running: true
    onTriggered: {
      activities.batteryWarned = activities.batteryLevel <= 10 ? 10 : activities.batteryLevel <= 20 ? 20 : 101
      activities.btKnown = activities.btConnected
      activities.netKnown = activities.netConnected
      activities.ready = true
    }
  }

  // Battery: charging started, and the level falling to 20% and to 10%, each
  // once per discharge.
  readonly property var batteryDevice: UPower.displayDevice
  readonly property bool hasBattery: !!(batteryDevice && batteryDevice.isLaptopBattery)
  readonly property int batteryLevel: hasBattery ? Math.round(batteryDevice.percentage * 100) : -1
  readonly property bool onPower: hasBattery && !UPower.onBattery
  property int batteryWarned: 101
  onOnPowerChanged: {
    if (onPower) batteryWarned = 101
    if (!ready || !onPower || !hasBattery || !settings.batteryActivity) return
    announce({ kind: "charging", title: "Charging", status: batteryLevel + "%", battery: batteryLevel, connected: true })
  }
  onBatteryLevelChanged: {
    if (!ready || !hasBattery || onPower || batteryLevel < 0) return
    var threshold = batteryLevel <= 10 ? 10 : batteryLevel <= 20 ? 20 : 101
    if (threshold >= batteryWarned) return
    batteryWarned = threshold
    if (settings.batteryActivity)
      announce({ kind: "lowBattery", title: "Low Battery", status: batteryLevel + "%", battery: batteryLevel, connected: true })
  }

  // Bluetooth: a device connecting or disconnecting.
  readonly property var btConnected: {
    var devs = Bluetooth.devices ? Bluetooth.devices.values : []
    return devs.filter(function(d) { return d && d.connected }).map(function(d) {
      return { key: String(d.address), name: String(d.deviceName || d.name || d.address), icon: String(d.icon || ""),
        battery: d.batteryAvailable ? Math.round(d.battery * 100) : -1 }
    })
  }
  property var btKnown: []
  onBtConnectedChanged: {
    if (!ready) return
    var change = changes(btKnown, btConnected)
    btKnown = btConnected
    if (!settings.bluetoothActivity || !change) return
    announce({ kind: "bluetooth", title: change.device.name, status: change.connected ? "Connected" : "Disconnected",
      battery: change.connected ? change.device.battery : -1, connected: change.connected, icon: change.device.icon })
  }

  // The newest device in `now` that isn't in `known` (or, given `moved`, is
  // there but moved(was, now) says it changed), else the newest one that left,
  // as { device, connected }; null when nothing did.
  function changes(known, now, moved) {
    function find(list, key) {
      for (var i = 0; i < list.length; i++) if (list[i].key === key) return list[i]
      return null
    }
    var joined = now.filter(function(d) {
      var was = find(known, d.key)
      return !was || (!!moved && moved(was, d))
    })
    if (joined.length) return { device: joined[joined.length - 1], connected: true }
    var left = known.filter(function(d) { return !find(now, d.key) })
    if (left.length) return { device: left[left.length - 1], connected: false }
    return null
  }

  // Network: a Wi-Fi or wired device connecting or disconnecting, or a Wi-Fi
  // device moving to another network. A Wi-Fi device is named after the
  // network it is on, wired ones are "Ethernet". Devices are keyed by
  // interface and changes settle for a moment first: the network's name can
  // arrive after the device reports connected, which would otherwise show a
  // nameless "Wi-Fi" pill and then a second one.
  function networkName(device, wired) {
    if (wired) return "Ethernet"
    var nets = device && device.networks ? device.networks.values : []
    for (var i = 0; i < nets.length; i++) {
      if (nets[i] && nets[i].connected) return String(nets[i].name || "")
    }
    return ""
  }
  readonly property var netConnected: {
    var devs = Networking.devices ? Networking.devices.values : []
    var out = []
    for (var i = 0; i < devs.length; i++) {
      var d = devs[i]
      if (!d || !d.connected) continue
      var wired = d.type === DeviceType.Wired
      if (!wired && d.type !== DeviceType.Wifi) continue
      out.push({ key: String(d.name || (wired ? "wired" : "wifi")), name: networkName(d, wired), wired: wired })
    }
    return out
  }
  property var netKnown: []
  onNetConnectedChanged: if (ready) netSettle.restart()
  Timer {
    id: netSettle
    interval: 1200
    onTriggered: activities.announceNetwork()
  }
  function announceNetwork() {
    var change = changes(netKnown, netConnected, function(was, d) {
      return d.name !== "" && was.name !== "" && d.name !== was.name
    })
    netKnown = netConnected
    if (!settings.networkActivity || !change) return
    announce({ kind: "network", title: change.device.name || "Wi-Fi", status: change.connected ? "Connected" : "Disconnected",
      battery: -1, connected: change.connected, wired: change.device.wired })
  }
}

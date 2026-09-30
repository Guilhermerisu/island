import QtQuick
import Quickshell.Bluetooth
import Quickshell.Services.UPower

// Device live activities: the battery starting to charge or running low, and
// a Bluetooth device connecting or disconnecting. Each sends `show` with the
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
    var known = btKnown, now = btConnected
    function has(list, key) { return list.some(function(d) { return d.key === key }) }
    btKnown = now
    if (!settings.bluetoothActivity) return
    var joined = now.filter(function(d) { return !has(known, d.key) })
    var left = known.filter(function(d) { return !has(now, d.key) })
    if (joined.length) {
      var d = joined[joined.length - 1]
      announce({ kind: "bluetooth", title: d.name, status: "Connected", battery: d.battery, connected: true, icon: d.icon })
    } else if (left.length) {
      announce({ kind: "bluetooth", title: left[left.length - 1].name, status: "Disconnected", battery: -1, connected: false, icon: left[left.length - 1].icon })
    }
  }
}

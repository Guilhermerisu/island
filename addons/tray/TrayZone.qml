import QtQuick
import ".."

// The system tray as a control center zone (see `zone` in Addon.qml). Normal
// is the tray list as it was, made as the card would have made it; XSmall and
// Small are the apps' icons, wrapped onto rows (see TrayChips) instead of the
// list cut down. `addon` is the TrayAddon.
AddonZone {
  id: zone
  required property var addon

  Loader {
    width: parent.width
    height: item ? item.implicitHeight : 0
    active: zone.zoneSize === "normal"
    sourceComponent: TrayList { host: zone.addon.host; inZone: true; active: zone.zoneActive }
  }
  Loader {
    width: parent.width
    height: item ? item.implicitHeight : 0
    active: zone.zoneSize !== "normal"
    sourceComponent: TrayChips {
      host: zone.addon.host
      center: zone.center
      small: zone.zoneSize === "small"
      // XSmall's chips fill its room (a constant 42).
      room: zone.room
    }
  }
}

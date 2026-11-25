import QtQuick
import ".."

// The system tray as an island view (see TrayList), and as a control center
// zone (see TrayZone), which draws the apps' icons for the XSmall and Small sizes.
Addon {
  id: trayAddon
  views: [{ name: "tray", width: 440, component: trayList }]
  zone: Component { TrayZone { addon: trayAddon } }
  Component {
    id: trayList
    TrayList { host: trayAddon.host; active: trayAddon.host.view === "tray" }
  }
}

import QtQuick
import ".."

// The system tray as an island view (see TrayList).
Addon {
  id: trayAddon
  views: [{ name: "tray", width: 440, component: trayList }]
  Component {
    id: trayList
    TrayList { host: trayAddon.host; active: trayAddon.host.view === "tray" }
  }
}

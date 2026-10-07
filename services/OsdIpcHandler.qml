import QtQuick
import Quickshell.Io

// Omarchy releases before ShellIpc: the stock OSD listens on a plain
// IpcHandler, so the island does the same.
Item {
  signal shown(string payload)
  IpcHandler {
    target: "osd"
    function show(payload: string): string {
      shown(payload)
      return "ok"
    }
  }
}

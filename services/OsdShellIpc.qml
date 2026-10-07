import QtQuick
import qs.Commons

// Newer Omarchy: `omarchy-shell` answers the `osd` target through ShellIpc.
// Omarchy releases without ShellIpc fail to load this file, and OsdBridge
// falls back to OsdIpcHandler.qml.
Item {
  signal shown(string payload)
  ShellIpc {
    target: "osd"
    function show(payload: string): string {
      shown(payload)
      return "ok"
    }
  }
}

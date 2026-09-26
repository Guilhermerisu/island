import QtQuick

// The resting pill's clock, plus the plain-text feedback and setup warning
// that share its spot.
Text {
  required property var host
  opacity: !host.notificationPill && !host.volumePill && (host.view === "rest" || host.view === "feedback") ? 1 : 0
  width: parent.width - 24
  horizontalAlignment: Text.AlignHCenter
  elide: Text.ElideRight
  textFormat: Text.PlainText
  // Notifications have their own layout; don't flash their text in
  // this label while it fades out.
  text: host.view === "feedback" && !host.notificationPill && !host.volumePill ? host.feedback
    : host.companionNeedsSetup ? "󰀦  " + host.companionWarning
    : Qt.formatDateTime(host.clockDate, "HH:mm")
  // A fixed soft off-white on the always-black island; the setup
  // warning keeps the theme's urgent color.
  color: host.view === "rest" && host.companionNeedsSetup ? host.colorUrgent : "#c2c8bd"
  // Adwaita Sans (Inter-based) at semibold; tabular figures keep the
  // digits from shifting as the time changes.
  font.family: "Adwaita Sans"
  font.pixelSize: 16
  font.weight: Font.DemiBold
  font.features: { "tnum": 1 }
  // Get out of the way fast, fade back in gently.
  Behavior on opacity { NumberAnimation { duration: opacity > 0.5 ? 70 : 150 * host.motionScale; easing.type: Easing.InOutQuad } }
}

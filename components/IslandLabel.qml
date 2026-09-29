import QtQuick

// The resting pill's clock, plus the plain-text feedback and setup warning
// that share its spot.
Text {
  required property var host
  // Hidden behind the notification, volume, clipboard, and finished-download
  // pills (the media and downloading pills keep the clock in the middle).
  opacity: !host.notificationPill && !host.volumePill && !host.clipboardPill && !host.activityPill && !host.downloadDone && (host.view === "rest" || host.view === "feedback") ? 1 : 0
  width: parent.width - 24
  horizontalAlignment: Text.AlignHCenter
  elide: Text.ElideRight
  textFormat: Text.PlainText
  // Notifications have their own layout; don't flash their text in
  // this label while it fades out.
  text: host.view === "feedback" && !host.notificationPill && !host.volumePill ? host.feedback
    : host.companionNeedsSetup ? "󰀦  " + host.companionWarning
    : host.settings.clock24h ? Qt.formatDateTime(host.clockDate, "HH:mm")
    // Qt only counts hours to 12 when there's an AM/PM marker; iOS drops it.
    : Qt.formatDateTime(host.clockDate, "h:mm AP").replace(/\s*[AP]M$/i, "")
  // A fixed soft off-white on the always-black island; the setup
  // warning keeps the theme's urgent color.
  color: host.view === "rest" && host.companionNeedsSetup ? host.colorUrgent : "#e2e6de"
  // Adwaita Sans (Inter-based) at semibold; tabular figures keep the
  // digits from shifting as the time changes.
  font.family: "Adwaita Sans"
  font.pixelSize: 16
  font.weight: Font.DemiBold
  // Apple-style: tabular digits, the colon raised to sit centered on them
  // (Inter's "case" forms), and SF's tight tracking.
  font.features: { "tnum": 1, "case": 1 }
  font.letterSpacing: -0.4
  // Get out of the way fast, fade back in gently.
  Behavior on opacity { NumberAnimation { duration: opacity > 0.5 ? 70 : 150 * host.motionScale; easing.type: Easing.InOutQuad } }
}

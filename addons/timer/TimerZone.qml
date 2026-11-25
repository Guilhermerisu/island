import QtQuick
import ".."

// The timer as a control center zone (see `zone` in Addon.qml): the timer
// view in its card, as the card would have mounted it, plus what the compact
// sizes need that the mount can't give: the control center, for the popover
// that sets any length (`picker`, the Normal view's own picker). `addon` is
// the TimerAddon.
AddonZone {
  id: zone
  required property var addon

  TimerView {
    width: parent.width
    height: implicitHeight
    timer: zone.addon
    inZone: true
    active: zone.zoneActive
    zoneSize: zone.zoneSize
    center: zone.center
    picker: pickerComponent
  }

  Component {
    id: pickerComponent
    // The view draws a little past its right edge (its length's well), which
    // the popover would cut: hence the margin.
    Item {
      implicitWidth: 280
      implicitHeight: 52
      TimerView {
        anchors.fill: parent
        anchors.rightMargin: 10
        timer: zone.addon
        inZone: true
        active: true
        center: zone.center
      }
    }
  }
}

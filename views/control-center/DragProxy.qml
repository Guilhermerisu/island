import QtQuick
import QtQuick.Effects
import "../../components"

// The card lifted off the control center while it's dragged, in edit mode:
// held under the pointer with a shadow, then settled into its slot on drop,
// or sunk where it was let go when it has no slot (removed, or dropped
// outside). One for the whole control center (see ControlCenter.dragProxy),
// used by the control grid. The caller sets `grabX` /
// `grabY` (where in the card the pointer went down) and calls `lift`, moves
// it with `follow`, and ends with `release`. What it shows is `content`,
// loaded in a Loader that also carries `controlKey` and `galleryPreview` for
// the control cards. `center` is the ControlCenter; the parent is its drag layer.
Rectangle {
  id: proxy
  required property var center
  property Component content: null
  // Kept past the drag, so it still shows its card while it settles.
  property string key: ""
  property bool fromGallery: false
  property bool held: false
  property bool lifted: false
  property bool sinking: false
  property bool settling: false
  // Where in the card it's held.
  property real grabX: 0
  property real grabY: 0

  function lift(key, fromGallery, width, height, content) {
    settleTimer.stop()
    settling = false
    // Reset while hidden, so the lift always starts from the card's size.
    sinking = false
    proxy.key = key
    proxy.fromGallery = fromGallery
    proxy.content = content
    proxy.width = width
    proxy.height = height
    held = true
    lifted = true
  }
  // Under the pointer at (x, y) of `source`.
  function follow(source, x, y) {
    var point = source.mapToItem(parent, x, y)
    proxy.x = point.x - grabX
    proxy.y = point.y - grabY
  }
  // `target`: where to settle ({ x, y, width, height }, in the layer), or
  // none to sink.
  function release(target) {
    lifted = false
    if (target) {
      settling = true
      x = target.x
      y = target.y
      width = target.width
      height = target.height
      settleTimer.restart()
    } else {
      sinking = true
      held = false
    }
  }

  opacity: held ? 1 : 0
  visible: opacity > 0.01
  scale: lifted ? 1.05 : sinking ? 0.9 : 1
  radius: center.cardRadius
  color: center.card
  // Appears at once over the card it lifts; only fades on the way out.
  Behavior on opacity { enabled: proxy.sinking || proxy.settling; MotionAnimation { theme: proxy.center.host.theme; pace: "exit"; curve: "exit" } }
  Behavior on scale {
    enabled: proxy.visible
    MotionAnimation { theme: proxy.center.host.theme; pace: proxy.sinking ? "exit" : "standard"; curve: proxy.sinking ? "exit" : "settle" }
  }
  // Follows the pointer directly while dragged, and eases only to settle.
  Behavior on x { enabled: proxy.settling; MotionAnimation { theme: proxy.center.host.theme; pace: "standard" } }
  Behavior on y { enabled: proxy.settling; MotionAnimation { theme: proxy.center.host.theme; pace: "standard" } }
  Behavior on width { enabled: proxy.settling; MotionAnimation { theme: proxy.center.host.theme; pace: "standard" } }
  Behavior on height { enabled: proxy.settling; MotionAnimation { theme: proxy.center.host.theme; pace: "standard" } }
  Timer {
    id: settleTimer
    interval: proxy.center.host.theme.motionDuration("standard")
    onTriggered: proxy.held = false
  }
  // The shadow deepens as it lifts and fades as it settles.
  property real shadowStrength: lifted ? 1 : 0
  Behavior on shadowStrength { MotionAnimation { theme: proxy.center.host.theme; pace: proxy.lifted ? "standard" : "exit"; curve: proxy.lifted ? "settle" : "exit" } }
  layer.enabled: visible
  layer.effect: MultiEffect {
    shadowEnabled: true
    shadowColor: Qt.rgba(0, 0, 0, 0.6)
    shadowOpacity: proxy.shadowStrength
    shadowBlur: 0.8
    shadowVerticalOffset: 6
  }
  Loader {
    anchors.fill: parent
    enabled: false
    property var center: proxy.center
    property string controlKey: proxy.key
    property bool galleryPreview: proxy.fromGallery
    sourceComponent: proxy.content
  }
}

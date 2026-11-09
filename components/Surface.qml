import QtQuick
import QtQuick.Effects

// Wraps one island view (control center, a switcher, the launcher, …): names
// it, sizes the island around it, and handles showing it. The view inside
// only needs an `active` input and an implicit size.
//
//   Surface {
//     id: emojiSurface
//     host: root; viewName: "emojis"; fixedWidth: 600
//     EmojiPicker { host: emojiSurface.host; active: emojiSurface.active }
//   }
Item {
  id: surface
  required property var host
  // The island view (and IPC route) that shows this surface.
  required property string viewName
  // Island width while open; 0 sizes it to the view's implicit width.
  property int fixedWidth: 0
  // Space between the island's edge and the view, on every side.
  property int padding: 16
  property int maxHeight: 100000
  // The island's corner radius while open; 0 keeps the usual one.
  property int cornerRadius: 0
  // Whether the island takes the keyboard while this is open.
  property bool wantsKeyboard: true

  default property alias content: holder.data
  readonly property Item view: holder.children.length ? holder.children[0] : null
  readonly property bool active: host.view === viewName
  readonly property bool revealed: active && host.surfaceContentReady

  readonly property real islandWidth: fixedWidth > 0 ? fixedWidth : implicitWidth + 2 * padding
  readonly property real islandHeight: Math.min(implicitHeight + 2 * padding, maxHeight)

  anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
  anchors.top: parent ? parent.top : undefined
  anchors.topMargin: padding
  implicitWidth: view ? view.implicitWidth : 0
  // Its final width from the first frame, centred in the island and cropped
  // by it while it morphs, so the view lays out once, not on every frame of
  // the spring. A view with no set width follows the island instead.
  width: fixedWidth > 0 ? fixedWidth - 2 * padding : parent ? parent.width - 2 * padding : 0
  implicitHeight: view ? view.implicitHeight : 0
  // Never taller than the island can be: a view that wants more has to scroll.
  height: Math.min(implicitHeight, maxHeight - 2 * padding)

  // Content fades in once the island has started morphing open.
  visible: active || opacity > 0.01
  enabled: active
  opacity: revealed ? 1 : 0
  Behavior on opacity { MotionAnimation { theme: surface.host.theme; pace: surface.revealed ? "standard" : "exit"; curve: "fade" } }

  // Lets the island know this view exists (for its open/closed logic).
  Component.onCompleted: host.registerSurface(viewName)
  Component.onDestruction: host.unregisterSurface(viewName)

  // How far the island has grown to this view's height, 0 → 1. The island
  // (Views fills it) rides a spring, so the content below follows the shape
  // frame by frame instead of on a clock of its own: it settles as the
  // island does, and turns around with it.
  readonly property real grown: parent && islandHeight > 0
    ? Math.max(0, Math.min(1, parent.height / islandHeight)) : 0

  // Going straight from one view to another: Apple's blur replace. The old one
  // blurs and recedes as it fades, the new one sharpens and settles into place,
  // and they cross while neither is legible.
  // Arriving at a smaller view than the last is a way back, so it's quicker.
  // Decided on becoming active, before the reveal starts these animations.
  property string arrivePace: "morph"
  onActiveChanged: if (active) arrivePace = parent && parent.height > islandHeight + 1 ? "standard" : "morph"
  property real settle: revealed ? 1 : 0.96
  Behavior on settle { MotionAnimation { theme: surface.host.theme; pace: surface.revealed ? surface.arrivePace : "exit"; curve: surface.revealed ? "morph" : "fade" } }
  property real veil: revealed ? 0 : 1
  Behavior on veil { MotionAnimation { theme: surface.host.theme; pace: surface.revealed ? surface.arrivePace : "exit"; curve: surface.revealed ? "morph" : "fade" } }

  Item {
    id: holder
    anchors.fill: parent
    // Transform the content without disturbing the panel's measured size.
    transformOrigin: Item.Top
    scale: (0.985 + 0.015 * surface.grown) * (surface.host.switchingSurface ? surface.settle : 1)
    // Only while it's blurred: a layer costs a texture the size of the view.
    layer.enabled: surface.host.switchingSurface && surface.visible && surface.veil > 0.001
    layer.effect: MultiEffect {
      autoPaddingEnabled: false
      blurEnabled: true
      blurMax: 28
      blur: surface.veil
    }
    transform: Translate { y: -6 * (1 - surface.grown) }
  }
}

import QtQuick

// What one control of the control center is, as data and actions, for the
// compact sizes (CcPip, CcCompactTile, CcThinSlider): a tile's look and click
// are read from the very card the grid would draw (made out of sight, so
// every core control and every addon's tile is covered without a copy of its
// logic), the sliders' (Sound, Microphone, Display) from Controls.
// `center` is the ControlCenter, `controlKey` the control.
Item {
  id: s
  required property var center
  required property string controlKey
  readonly property var controls: center.controls
  readonly property bool isSlider: controls.canBeVertical(controlKey)
  // The tile card (a CcTile), none for a slider.
  readonly property var tile: tileLoader.item
  visible: false

  Loader {
    id: tileLoader
    active: !s.isSlider
    // What the cards read from their parent (see ControlLayout).
    property var center: s.center
    property string controlKey: s.controlKey
    property bool galleryPreview: false
    sourceComponent: s.center.controlComponent(s.controlKey)
  }

  readonly property bool isSound: controlKey === "sound"
  readonly property string title: isSlider ? controls.title(controlKey) : tile ? tile.title : ""
  readonly property string subtitle: isSlider ? detail : tile ? tile.subtitle : ""
  readonly property bool checked: isSlider ? isSound ? controls.controlPresent("sound") && !controls.muted
    : controlKey === "microphone" ? controls.microphoneReady && !controls.microphoneMuted : false
    : !!tile && tile.checked
  readonly property bool available: isSlider ? isSound ? controls.controlPresent("sound")
    : controlKey === "microphone" ? controls.microphoneReady : controls.brightnessAvailable
    : !!tile && tile.available
  // The brightness has nothing to switch.
  readonly property bool clickable: isSlider ? controlKey !== "display" : !!tile && tile.clickable
  // Wi-Fi and Bluetooth: the click opens their details, the badge switches.
  readonly property bool opens: !isSlider && !!tile && tile.opens
  readonly property string iconFamily: !isSlider && tile ? tile.iconFamily : ""
  // A tile with no icon of its own (Calendar's is drawn over its badge) shows
  // its addon's.
  readonly property string icon: {
    if (!isSlider) {
      if (tile && tile.icon !== "") return tile.icon
      var addon = center.host.addons.entry(String(controlKey).split(".")[0])
      return addon ? addon.icon : ""
    }
    if (isSound) return controls.muted || controls.volume <= 0 ? "󰖁" : controls.volume < 0.34 ? "󰕿" : controls.volume < 0.67 ? "󰖀" : "󰕾"
    return controlKey === "microphone" ? controls.microphoneMuted ? "󰍭" : "󰍬" : "󰃠"
  }

  // Sliders: the level (0 to 1) and how it reads.
  readonly property real value: isSound ? controls.muted ? 0 : controls.volume
    : controlKey === "microphone" ? controls.microphoneVolume : controls.brightness / 100
  readonly property string detail: !available ? "Unavailable"
    : isSound ? controls.muted ? "Muted" : Math.round(controls.volume * 100) + "%"
    : controlKey === "microphone" ? controls.microphoneMuted ? "Muted" : Math.round(controls.microphoneVolume * 100) + "%"
    : controls.brightness + "%"

  // The ring's level: the level, nothing while muted (the microphone keeps its
  // volume then).
  readonly property real ringLevel: !available ? 0 : controlKey === "microphone" && controls.microphoneMuted ? 0 : value
  // Where the sources are: Sound's outputs, the microphone's inputs.
  readonly property bool hasSources: isSlider && available
    && (isSound ? controls.outputs.length > 0 : controlKey === "microphone" && controls.inputs.length > 0)

  // The popover of a slider (a CcLevelPopover, made by the caller: this is
  // inside it): its level and, for Sound and the microphone, the list of
  // sources. Opened from `anchor`.
  function openPopover(anchor, popover) {
    if (isSlider && available) center.openPopover(anchor, popover, { center: center, controlKey: controlKey })
  }

  // Click: the tile's, or the sound's and the microphone's mute.
  function activate() {
    if (!available || !clickable) return
    if (!isSlider) tile.clicked()
    else if (isSound) { if (controls.sink && controls.sink.audio) controls.sink.audio.muted = !controls.muted }
    else controls.toggleMicrophoneMute()
  }
  // Right click.
  function openDetails() { if (opens && available) tile.opened() }
  function setValue(v) {
    v = Math.max(0, Math.min(1, v))
    if (!isSlider || !available) return
    if (isSound) {
      controls.sink.audio.volume = v
      if (controls.sink.audio.muted && v > 0) controls.sink.audio.muted = false
    } else if (controlKey === "microphone") controls.microphoneSource.audio.volume = v
    else controls.setBrightness(Math.round(v * 100))
  }
  // The wheel's step, as the sliders' (CcSlider), not while the page scrolls.
  function nudge(up) {
    if (center.editMode || center.pageScrolling) return false
    setValue(value + (up ? 0.05 : -0.05))
    return true
  }
}

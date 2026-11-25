import QtQuick
import QtTest
import "../views/control-center/zones.js" as Zones

TestCase {
  name: "ZoneSizes"

  function test_sizeOf_defaults_to_normal() {
    compare(Zones.sizeOf("", "weather"), "normal")
    compare(Zones.sizeOf("not json", "weather"), "normal")
    compare(Zones.sizeOf("[]", "weather"), "normal")
    compare(Zones.sizeOf("null", "weather"), "normal")
    compare(Zones.sizeOf('{"stats":"small"}', "weather"), "normal")
    compare(Zones.sizeOf('{"weather":"huge"}', "weather"), "normal")
    compare(Zones.sizeOf('{"weather":"normal"}', "weather"), "normal")
    // Not the object's own keys.
    compare(Zones.sizeOf("{}", "toString"), "normal")
  }

  function test_sizeOf_reads_saved() {
    compare(Zones.sizeOf('{"weather":"small","stats":"xsmall"}', "weather"), "small")
    compare(Zones.sizeOf('{"weather":"small","stats":"xsmall"}', "stats"), "xsmall")
  }

  function test_withSize() {
    var json = Zones.withSize("", "weather", "small")
    compare(json, '{"weather":"small"}')
    json = Zones.withSize(json, "stats", "xsmall")
    compare(Zones.sizeOf(json, "weather"), "small")
    compare(Zones.sizeOf(json, "stats"), "xsmall")
    // Back to normal drops the entry, and the last one leaves "".
    json = Zones.withSize(json, "weather", "normal")
    compare(json, '{"stats":"xsmall"}')
    compare(Zones.withSize(json, "stats", "normal"), "")
    compare(Zones.withSize("", "stats", "normal"), "")
    // Unknown sizes are normal; invalid JSON starts over.
    compare(Zones.withSize('{"stats":"small"}', "stats", "huge"), "")
    compare(Zones.withSize("garbage", "stats", "small"), '{"stats":"small"}')
    compare(Zones.withSize("[1]", "stats", "small"), '{"stats":"small"}')
  }

  readonly property int gap: 8
  // The island's padding twice (32), the header (30) and its gap (8).
  readonly property int chrome: 70

  // XS is a third of what the columns have at the least island height (260):
  // three of them and the gaps between fill 190 to the pixel.
  function test_xs_height_comes_from_the_least_island() {
    var xs = Zones.xsHeight(chrome, gap)
    compare(xs, 58)
    compare(3 * xs + 2 * gap, Zones.minIslandHeight - chrome)
    // A taller chrome or gap leaves a smaller line.
    verify(Zones.xsHeight(chrome + 12, gap) < xs)
    verify(Zones.xsHeight(chrome, gap + 3) < xs)
  }

  // Edit mode's add panel: its default, its wish, and what the screen leaves it.
  function test_edit_panel_height() {
    compare(Zones.editPanelHeight(0, 1000), Zones.defaultEditPanelHeight)
    compare(Zones.editPanelHeight(-1, 1000), Zones.defaultEditPanelHeight)
    compare(Zones.editPanelHeight(500, 1000), 500)
    // It is what shrinks when the screen runs out, down to its least.
    compare(Zones.editPanelHeight(500, 300), 300)
    compare(Zones.editPanelHeight(0, 200), 200)
    compare(Zones.editPanelHeight(500, 50), Zones.minEditPanelHeight)
    compare(Zones.editPanelHeight(10, 1000), Zones.minEditPanelHeight)
    compare(Zones.editPanelHeight(333.4, 1000), 333)
  }

  function test_island_width_bounds_by_layout() {
    var b1 = Zones.islandWidthBounds(1, 2560, 16, 8)
    var b2 = Zones.islandWidthBounds(2, 2560, 16, 8)
    var b3 = Zones.islandWidthBounds(3, 2560, 16, 8)
    compare(b1.min, 360)
    compare(b1.max, 820)
    compare(b1.fallback, 540)
    compare(b2.min, 560)
    compare(b2.max, 1440)
    compare(b2.fallback, 888)
    compare(b3.min, 828)
    compare(b3.max, 1920)
    compare(b3.fallback, 1156)
    // Distinct and monotonically increasing bounds across layouts.
    verify(b1.min < b2.min && b2.min < b3.min)
    verify(b1.max < b2.max && b2.max < b3.max)
    // Clamps to 94% on smaller screens (e.g. 1024px -> 962px).
    var small3 = Zones.islandWidthBounds(3, 1024, 16, 8)
    compare(small3.min, 828)
    compare(small3.max, 962)
    compare(small3.fallback, 962)
    // Tiny screen keeps min <= max.
    var tiny3 = Zones.islandWidthBounds(3, 800, 16, 8)
    compare(tiny3.max, 752)
    compare(tiny3.min, 752)
    compare(tiny3.fallback, 752)
  }

  function test_saved_and_with_width() {
    compare(Zones.savedWidth("", 1), 0)
    compare(Zones.savedWidth("not json", 2), 0)
    compare(Zones.savedWidth("[]", 2), 0)
    compare(Zones.savedWidth("null", 2), 0)
    compare(Zones.savedWidth('{"1":0,"2":-10,"3":"900"}', 1), 0)
    compare(Zones.savedWidth('{"1":0,"2":-10,"3":"900"}', 2), 0)
    compare(Zones.savedWidth('{"1":0,"2":-10,"3":"900"}', 3), 0)
    compare(Zones.savedWidth("{}", "toString"), 0)

    var json = Zones.withWidth("", 1, 620.4)
    compare(json, '{"1":620}')
    json = Zones.withWidth(json, 3, 1380)
    compare(Zones.savedWidth(json, 1), 620)
    compare(Zones.savedWidth(json, 2), 0)
    compare(Zones.savedWidth(json, 3), 1380)
    // Resetting one layout preserves others; resetting the last yields "".
    json = Zones.withWidth(json, 1, 0)
    compare(json, '{"3":1380}')
    compare(Zones.withWidth(json, 3, 0), "")
    compare(Zones.withWidth("garbage", 2, 950), '{"2":950}')
  }

  function test_island_width_custom_and_fallback() {
    // Legacy 3-argument call still returns the layout fallback.
    compare(Zones.islandWidth(1, 2560, 8), 540)
    compare(Zones.islandWidth(2, 2560, 8), 888)
    compare(Zones.islandWidth(3, 2560, 8), 1156)
    // Zero or invalid custom width falls back to default.
    compare(Zones.islandWidth(2, 2560, 8, 0, 16), 888)
    compare(Zones.islandWidth(2, 2560, 8, -1, 16), 888)
    // Custom width is kept within the layout's bounds.
    compare(Zones.islandWidth(1, 2560, 8, 200, 16), 360)
    compare(Zones.islandWidth(1, 2560, 8, 620.6, 16), 621)
    compare(Zones.islandWidth(1, 2560, 8, 1200, 16), 820)
    compare(Zones.islandWidth(3, 2560, 8, 600, 16), 828)
    compare(Zones.islandWidth(3, 2560, 8, 1500, 16), 1500)
    compare(Zones.islandWidth(3, 1024, 8, 1500, 16), 962)
  }
}

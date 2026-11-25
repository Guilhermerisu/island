.pragma library

// The control center's zones as plain data, kept free of Quickshell: a model
// is a list of columns, each a list of zone ids. Every function returns a new
// model.

var fallback = [["controls", "notifications"]]
// What the island is wide for 1, 2 and 3 columns, each column taking its
// share of it (and the gaps between them).
var islandWidths = [0, 540, 440, 380]
var maxScreenShare = 0.94

function clampColumns(value) {
  var n = Math.round(Number(value))
  return n >= 1 ? Math.min(3, n) : 1
}

// The saved JSON as `columns` lists of known, distinct ids. Invalid or empty
// JSON gives the default. Columns beyond `columns` are folded into the last
// one, so shrinking never loses a zone. `aliases` ({ old: new }) renames ids
// saved under an earlier name.
function normalize(json, columns, known, aliases) {
  var saved
  try { saved = JSON.parse(json) } catch (e) { saved = null }
  var valid = Array.isArray(saved) && saved.length > 0
    && saved.every(function(column) { return Array.isArray(column) })
  if (!valid) saved = fallback
  var result = []
  var seen = {}
  for (var c = 0; c < columns; c++) result.push([])
  for (var i = 0; i < saved.length; i++) {
    var target = result[Math.min(i, columns - 1)]
    for (var j = 0; j < saved[i].length; j++) {
      var id = saved[i][j]
      if (aliases && typeof id === "string" && Object.prototype.hasOwnProperty.call(aliases, id)) id = aliases[id]
      if (typeof id !== "string" || known.indexOf(id) === -1 || seen[id]) continue
      seen[id] = true
      target.push(id)
    }
  }
  return result
}

// `next`, a change made while `json`'s extra columns were folded, with those
// columns kept: the folded last column is cut back at the places it was
// joined. Zones stay in the order they have on screen, so one moved ahead of
// its old column takes what follows it along.
function unfold(json, next) {
  var saved
  try { saved = JSON.parse(json) } catch (e) { return next }
  if (!Array.isArray(saved) || saved.length <= next.length) return next
  var last = next.length - 1
  var from = {}
  for (var c = last; c < saved.length; c++)
    if (Array.isArray(saved[c])) saved[c].forEach(function(id) { from[id] = c })
  var result = next.slice(0, last)
  for (c = last; c < saved.length; c++) result.push([])
  var at = last
  next[last].forEach(function(id) {
    if (from[id] > at) at = from[id]
    result[at].push(id)
  })
  return result
}

function without(model, id) {
  return model.map(function(column) { return column.filter(function(zone) { return zone !== id }) })
}
function remove(model, id) { return without(model, id) }

// At the end of the shortest column (the first of equals).
function add(model, id) {
  var next = without(model, id)
  var shortest = 0
  for (var i = 1; i < next.length; i++)
    if (next[i].length < next[shortest].length) shortest = i
  next[shortest].push(id)
  return next
}

// To `index` in `column`, an index into that column as it is before the
// move (where a drop lands), so moving down within a column counts the
// zone's own old place.
function move(model, id, column, index) {
  if (column < 0 || column >= model.length) return model
  var from = -1
  var at = -1
  for (var c = 0; c < model.length; c++) {
    var found = model[c].indexOf(id)
    if (found !== -1) { from = c; at = found }
  }
  var next = without(model, id)
  if (from === column && at < index) index--
  next[column].splice(Math.max(0, Math.min(index, next[column].length)), 0, id)
  return next
}

function absent(model, known) {
  return known.filter(function(id) {
    return !model.some(function(column) { return column.indexOf(id) !== -1 })
  })
}

// Width bounds and default for `columns` columns, clamped to `screenWidth`
// (up to 94% so 3 columns can widen while keeping a margin at the edges).
function islandWidthBounds(columns, screenWidth, padding, gap) {
  if (padding === undefined) padding = 16
  if (gap === undefined) gap = 8
  columns = clampColumns(columns)
  var screenMax = screenWidth > 0 ? Math.floor(maxScreenShare * screenWidth) : 2400
  var defaultRaw = columns * islandWidths[columns] + (columns - 1) * gap
  var fallback = Math.round(screenWidth > 0 ? Math.min(defaultRaw, screenMax) : defaultRaw)
  var minRaw = columns === 1 ? 360 : columns * minColumnWidth + (columns - 1) * gap + 2 * padding
  var maxRaw = [0, 820, 1440, 1920][columns]
  var max = Math.min(maxRaw, screenMax)
  var min = Math.min(minRaw, max)
  return {
    min: Math.round(min),
    max: Math.round(max),
    fallback: Math.round(Math.max(min, Math.min(fallback, max)))
  }
}

function savedWidth(json, columns) {
  var saved
  try { saved = JSON.parse(json) } catch (e) { return 0 }
  if (!saved || typeof saved !== "object" || Array.isArray(saved)) return 0
  var key = String(columns)
  var value = Object.prototype.hasOwnProperty.call(saved, key) ? saved[key] : 0
  return typeof value === "number" && isFinite(value) && value > 0 ? value : 0
}

function withWidth(json, columns, width) {
  var all
  try { all = JSON.parse(json) } catch (e) { all = null }
  if (!all || typeof all !== "object" || Array.isArray(all)) all = {}
  var key = String(columns)
  if (typeof width === "number" && isFinite(width) && width > 0) all[key] = Math.round(width)
  else delete all[key]
  return Object.keys(all).length > 0 ? JSON.stringify(all) : ""
}

// The island's width for `columns` columns, using `customWidth` when valid
// (clamped to the layout's bounds) or the layout's default otherwise.
function islandWidth(columns, screenWidth, gap, customWidth, padding) {
  var bounds = islandWidthBounds(columns, screenWidth, padding === undefined ? 16 : padding, gap === undefined ? 8 : gap)
  if (typeof customWidth === "number" && isFinite(customWidth) && customWidth > 0)
    return Math.round(Math.max(bounds.min, Math.min(customWidth, bounds.max)))
  return bounds.fallback
}

// The room the columns share inside an island of that width and padding.
function columnsSpace(columns, island, padding, gap) {
  return island - 2 * padding - (columns - 1) * gap
}

// The zones' sizes: JSON of { "<zoneId>": "xsmall" | "small" }, a zone with
// no entry being "normal" (the default, drawn as it always was).
var sizes = ["xsmall", "small", "normal"]

function sizeOf(json, id) {
  var saved
  try { saved = JSON.parse(json) } catch (e) { return "normal" }
  if (!saved || typeof saved !== "object" || Array.isArray(saved)) return "normal"
  var size = Object.prototype.hasOwnProperty.call(saved, id) ? saved[id] : "normal"
  return sizes.indexOf(size) === -1 ? "normal" : size
}

// The JSON with `id` at `size`; "normal" drops its entry, and with none left
// it is "". Other zones' entries are kept (invalid JSON starts over).
function withSize(json, id, size) {
  var all
  try { all = JSON.parse(json) } catch (e) { all = null }
  if (!all || typeof all !== "object" || Array.isArray(all)) all = {}
  if (size === "xsmall" || size === "small") all[id] = size
  else delete all[id]
  return Object.keys(all).length > 0 ? JSON.stringify(all) : ""
}

// The island's least height (Views.qml's 260): an XS zone is sized from it.
var minIslandHeight = 260

// An XS zone's one line: a third of what the columns have at that least
// height, once the `chrome` around them (island padding twice, header and the
// space under it) is taken out, so three fill it: 58 for the usual 70
// (32 + 30 + 8) and a `gap` of 8 between zones, (190 - 2 x 8) / 3. A zone
// whose content is taller (Controls on several rows) is as tall as that.
function xsHeight(chrome, gap) {
  return Math.floor((minIslandHeight - chrome - 2 * gap) / 3)
}

// The add panel's height in edit mode (it is a menu you stretch to see more
// to add). `wanted` is the saved or dragged one, 0 for the default; `room` is
// what is left of the screen under the zones' frame: the panel is the first
// thing to shrink when the island would be taller than that, but is never
// under its least.
var defaultEditPanelHeight = 320
var minEditPanelHeight = 140
function editPanelHeight(wanted, room) {
  var want = wanted > 0 ? wanted : defaultEditPanelHeight
  return Math.round(Math.max(minEditPanelHeight, Math.min(want, room)))
}

// What no column is narrower than, set with the handles between them.
var minColumnWidth = 260

// Each column's share of the width (summing to 1) for `columns` columns, from
// the saved JSON ({ "<count>": [shares] }). Anything unusable, or a count
// not saved, is an even split.
function shares(json, columns) {
  var saved
  try { saved = JSON.parse(json)[String(columns)] } catch (e) { saved = null }
  var total = 0
  var valid = Array.isArray(saved) && saved.length === columns && saved.every(function(share) {
    total += share
    return typeof share === "number" && isFinite(share) && share > 0
  })
  return Array.from({ length: columns }, function(_, i) { return valid ? saved[i] / total : 1 / columns })
}

// The JSON with `values` saved for their count; the other counts are kept.
// Without `values`, that count goes back to an even split.
function withShares(json, columns, values) {
  var all
  try { all = JSON.parse(json) } catch (e) { all = null }
  if (!all || typeof all !== "object" || Array.isArray(all)) all = {}
  if (values) all[String(columns)] = values.map(function(share) { return Math.round(share * 10000) / 10000 })
  else delete all[String(columns)]
  return Object.keys(all).length > 0 ? JSON.stringify(all) : ""
}

// The pixel width of each column given its share, over `visible` (a flag per
// column): a hidden one gets 0 and the others split `space` in proportion,
// none under `minimum` (the rest then share what is left). With no room for
// the minimum, an even split.
function widths(sharesList, visible, space, minimum) {
  var shown = []
  for (var i = 0; i < sharesList.length; i++) if (visible[i]) shown.push(i)
  var result = sharesList.map(function() { return 0 })
  if (shown.length === 0) return result
  if (space < shown.length * minimum) {
    shown.forEach(function(i) { result[i] = space / shown.length })
    return result
  }
  var pinned = {}
  // Pinning one at the minimum can push another under it: go again.
  for (var pass = 0; pass <= shown.length; pass++) {
    var left = space
    var weight = 0
    shown.forEach(function(i) {
      if (pinned[i]) left -= minimum
      else weight += sharesList[i]
    })
    var changed = false
    shown.forEach(function(i) {
      result[i] = pinned[i] ? minimum : left * sharesList[i] / weight
      if (!pinned[i] && result[i] < minimum) { pinned[i] = true; changed = true }
    })
    if (!changed) break
  }
  return result
}

// The shares after the handle between columns `a` and `b` (both showing) is
// dragged `dx` pixels from where `current` (the shares then) had them: the
// two keep what they share between them, neither under `minimum`.
function dragShares(current, visible, space, minimum, a, b, dx) {
  var width = widths(current, visible, space, minimum)
  var pair = width[a] + width[b]
  if (pair < 2 * minimum) return current
  var left = Math.max(minimum, Math.min(pair - minimum, width[a] + dx))
  var next = current.slice()
  var own = current[a] + current[b]
  next[a] = own * left / pair
  next[b] = own - next[a]
  return next
}

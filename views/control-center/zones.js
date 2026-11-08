.pragma library

// The control center's zones as plain data, so they can be checked without
// Quickshell (task/checks/zones-check.js): a model is a list of columns,
// each a list of zone ids. Every function returns a new model.

var fallback = [["controls", "notifications"]]
// What the island is wide for 1, 2 and 3 columns, each column taking its
// share of it (and the gaps between them).
var islandWidths = [0, 540, 440, 380]
var maxScreenShare = 0.8

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

// The island's width for `columns` columns, kept to a share of the screen
// (when its width is known).
function islandWidth(columns, screenWidth, gap) {
  var wanted = columns * islandWidths[columns] + (columns - 1) * gap
  return Math.round(screenWidth > 0 ? Math.min(wanted, maxScreenShare * screenWidth) : wanted)
}

// The room the columns share inside an island of that width and padding.
function columnsSpace(columns, island, padding, gap) {
  return island - 2 * padding - (columns - 1) * gap
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

.pragma library

// Where the control center's cards go, as plain data so it can be checked
// without Quickshell (task/checks/vertical-layout-check.js).
//
// `items` are { key, wide, vertical, extra } in display order; `o` is
// { width, inset, gap, tileHeight, sectionHeight }. Small tiles pair up two
// to a row, wide cards (sliders) take a row, and consecutive vertical cards
// stand side by side, up to maxPerRow in equal widths, three tiles tall.
// `extra` is the room a wide card's picker adds; a vertical card has none.
// Returns { key: {x, y, width, height}, ..., height: total }.

var maxPerRow = 4
// A vertical card stays a tall pill however wide the column is (and sits at the
// left, as in a narrow column): wider than this it would read as a block.
var maxVerticalWidth = 132

function place(items, o) {
  var result = {}
  var fullWidth = o.width - 2 * o.inset
  var halfWidth = (fullWidth - o.gap) / 2
  var rowY = o.inset
  var halfUsed = false
  var small = function(i) { return i < items.length && !items[i].wide && !items[i].vertical }
  for (var i = 0; i < items.length; i++) {
    var item = items[i]
    if (item.vertical) {
      if (halfUsed) { rowY += o.tileHeight + o.gap; halfUsed = false }
      var count = 1
      while (count < maxPerRow && i + count < items.length && items[i + count].vertical) count++
      var cardWidth = Math.min(maxVerticalWidth, (fullWidth - (count - 1) * o.gap) / count)
      var rowHeight = 3 * o.tileHeight + 2 * o.gap
      for (var j = 0; j < count; j++)
        result[items[i + j].key] = { x: o.inset + j * (cardWidth + o.gap), y: rowY, width: cardWidth, height: rowHeight }
      rowY += rowHeight + o.gap
      i += count - 1
    } else if (item.wide) {
      if (halfUsed) { rowY += o.tileHeight + o.gap; halfUsed = false }
      var cardHeight = o.sectionHeight + (item.extra || 0)
      result[item.key] = { x: o.inset, y: rowY, width: fullWidth, height: cardHeight }
      rowY += cardHeight + o.gap
    } else if (halfUsed) {
      result[item.key] = { x: o.inset + halfWidth + o.gap, y: rowY, width: halfWidth, height: o.tileHeight }
      rowY += o.tileHeight + o.gap
      halfUsed = false
    } else {
      var nextIsSmall = small(i + 1)
      result[item.key] = { x: o.inset, y: rowY, width: nextIsSmall ? halfWidth : fullWidth, height: o.tileHeight }
      if (nextIsSmall) halfUsed = true
      else rowY += o.tileHeight + o.gap
    }
  }
  result.height = Math.max(0, rowY + (halfUsed ? o.tileHeight : rowY > o.inset ? -o.gap : 0) + o.inset)
  return result
}

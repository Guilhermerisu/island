import QtQuick

// A ListModel kept in step with a JS array by each row's stable key, so a
// view's delegates stay put while rows come, go and reorder, and its add,
// remove and displaced transitions can run. Feeding a fresh array straight
// to a view rebuilds every delegate instead, and the rows pop.
// Delegates read each row as the `entry` role (a plain copy of the value).
QtObject {
  id: keyed
  // The array to mirror; plain values only (no live objects).
  property var values: []
  // A row's identity across refreshes, as a string.
  property var keyOf: function(value) { return String(value) }
  // False until the first fill that has rows, so a view can let that one in
  // without animating every row.
  property bool primed: false
  readonly property ListModel model: ListModel {}

  onValuesChanged: sync()
  Component.onCompleted: sync()

  function sync() {
    var next = values || []
    var keys = []
    var wanted = {}
    for (var i = 0; i < next.length; i++) {
      keys.push(String(keyOf(next[i])))
      wanted[keys[i]] = true
    }
    for (var r = model.count - 1; r >= 0; r--)
      if (!wanted[model.get(r).key]) model.remove(r)
    // Walk the target order: each row is found among the ones not placed
    // yet (so a repeated key still gets its own row), moved up into place,
    // and only rewritten when its value changed.
    for (var j = 0; j < next.length; j++) {
      var json = JSON.stringify(next[j])
      var at = -1
      for (var m = j; m < model.count; m++) if (model.get(m).key === keys[j]) { at = m; break }
      if (at === -1) {
        model.insert(j, { key: keys[j], json: json, entry: next[j] })
        continue
      }
      if (at !== j) model.move(at, j, 1)
      if (model.get(j).json !== json) model.set(j, { json: json, entry: next[j] })
    }
    if (model.count > next.length) model.remove(next.length, model.count - next.length)
    if (next.length) primed = true
  }
}

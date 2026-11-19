// Adapted from omarchy-priority-todos (MIT, see LICENSE).
// Task store helpers. The panel owns the live array; this file only
// parses, sorts, and returns new arrays so QML bindings re-evaluate.

var RANK = { critical: 0, high: 1, medium: 2, low: 3 }
var LABEL = {
  critical: "Critical",
  high: "High",
  medium: "Medium",
  low: "Low"
}
var PRIORITY_OPTIONS = [
  { value: "critical", label: "Critical" },
  { value: "high", label: "High" },
  { value: "medium", label: "Medium" },
  { value: "low", label: "Low" }
]
var TAB_OPTIONS = [
  { value: "backlog", label: "Backlog" },
  { value: "ongoing", label: "Ongoing" },
  { value: "complete", label: "Completed" }
]

function trim(value) {
  return String(value || "").replace(/^\s+|\s+$/g, "")
}

function priorityOptions() {
  return PRIORITY_OPTIONS
}

function tabOptions() {
  return TAB_OPTIONS
}

function normalizePriority(value) {
  var priority = String(value || "").toLowerCase()
  if (Object.prototype.hasOwnProperty.call(RANK, priority)) return priority
  return "medium"
}

function normalizeStatus(status, completed) {
  var value = String(status || "").toLowerCase()
  if (value === "backlog" || value === "ongoing" || value === "complete") return value
  return completed === true ? "complete" : "ongoing"
}

function normalizeTab(tab) {
  var value = String(tab || "").toLowerCase()
  if (value === "backlog" || value === "ongoing" || value === "complete") return value
  return "ongoing"
}

function addStatusForTab(tab) {
  return String(tab || "") === "backlog" ? "backlog" : "ongoing"
}

function cycleTab(current, direction) {
  var tabs = TAB_OPTIONS
  var i = 0
  for (; i < tabs.length; i++) if (tabs[i].value === current) break
  if (i >= tabs.length) i = 1
  var next = i + (direction > 0 ? 1 : -1)
  if (next < 0) next = tabs.length - 1
  if (next >= tabs.length) next = 0
  return tabs[next].value
}

function rank(priority) {
  return RANK[normalizePriority(priority)]
}

function label(priority) {
  return LABEL[normalizePriority(priority)]
}

function statusLabel(status) {
  var value = normalizeStatus(status, false)
  if (value === "backlog") return "Backlog"
  if (value === "complete") return "Completed"
  return "Ongoing"
}

function newId() {
  return Date.now().toString(36) + "-" + Math.floor(Math.random() * 1e9).toString(36)
}

function copyTask(task, overrides) {
  var status = normalizeStatus(task.status, task.completed)
  var next = {
    id: task.id,
    title: task.title,
    description: task.description,
    priority: task.priority,
    status: status,
    completed: status === "complete",
    createdAt: task.createdAt,
    completedAt: task.completedAt
  }
  if (overrides) {
    for (var key in overrides) next[key] = overrides[key]
  }
  next.status = normalizeStatus(next.status, next.completed)
  next.completed = next.status === "complete"
  return next
}

function createTask(title, description, priority, status) {
  var now = Date.now()
  var nextStatus = normalizeStatus(status, false)
  if (nextStatus === "complete") nextStatus = "ongoing"
  return {
    id: newId(),
    title: trim(title),
    description: trim(description),
    priority: normalizePriority(priority),
    status: nextStatus,
    completed: false,
    createdAt: now,
    completedAt: 0
  }
}

function normalizeTask(raw) {
  if (!raw || typeof raw !== "object") return null
  var title = trim(raw.title)
  if (title === "") return null
  var status = normalizeStatus(raw.status, raw.completed)
  return {
    id: String(raw.id || newId()),
    title: title,
    description: trim(raw.description),
    priority: normalizePriority(raw.priority),
    status: status,
    completed: status === "complete",
    createdAt: Number(raw.createdAt) || 0,
    completedAt: Number(raw.completedAt) || 0
  }
}

function parseStore(raw) {
  var text = trim(raw)
  try {
    var data = JSON.parse(text)
    var list = Array.isArray(data) ? data : data && data.tasks
    if (!Array.isArray(list)) return null
    var out = []
    for (var i = 0; i < list.length; i++) {
      var task = normalizeTask(list[i])
      if (task) out.push(task)
    }
    return { tasks: out, activeTab: normalizeTab(data && data.activeTab) }
  } catch (e) {
    return null
  }
}

function serialize(tasks, activeTab) {
  return JSON.stringify({
    version: 1,
    activeTab: normalizeTab(activeTab),
    tasks: tasks || []
  }, null, 2) + "\n"
}

function matches(task, query, translate) {
  var needle = trim(query).toLowerCase()
  if (needle === "") return true
  return String(task.title || "").toLowerCase().indexOf(needle) >= 0
      || String(task.description || "").toLowerCase().indexOf(needle) >= 0
      || label(task.priority).toLowerCase().indexOf(needle) >= 0
      || statusLabel(task.status).toLowerCase().indexOf(needle) >= 0
      || (translate && (translate(label(task.priority)).toLowerCase().includes(needle)
        || translate(statusLabel(task.status)).toLowerCase().includes(needle)))
}

function compareTasks(a, b) {
  var rankDelta = rank(a.priority) - rank(b.priority)
  if (rankDelta !== 0) return rankDelta
  if (a.status === "complete" && b.status === "complete")
    return (Number(b.completedAt) || 0) - (Number(a.completedAt) || 0)
  return (Number(b.createdAt) || 0) - (Number(a.createdAt) || 0)
}

function listed(tasks, query, status, translate) {
  var list = tasks || []
  var want = normalizeStatus(status, false)
  var out = []
  for (var i = 0; i < list.length; i++) {
    var task = list[i]
    if (!task) continue
    if (normalizeStatus(task.status, task.completed) !== want) continue
    if (!matches(task, query, translate)) continue
    out.push(task)
  }
  out.sort(compareTasks)
  return out
}

function add(tasks, task) {
  if (!task || !task.title) return tasks || []
  return [task].concat(tasks || [])
}

function mapTasks(tasks, id, fn) {
  var list = tasks || []
  var out = []
  var changed = false
  for (var i = 0; i < list.length; i++) {
    var task = list[i]
    if (!task || task.id !== id) {
      out.push(task)
      continue
    }
    var next = fn(task)
    if (next === task) {
      out.push(task)
    } else {
      changed = true
      out.push(next)
    }
  }
  return changed ? out : list
}

function setStatus(tasks, id, status) {
  var nextStatus = normalizeStatus(status, false)
  var now = Date.now()
  return mapTasks(tasks, id, function(task) {
    if (task.status === nextStatus) return task
    return copyTask(task, {
      status: nextStatus,
      completedAt: nextStatus === "complete" ? now : 0
    })
  })
}

function remove(tasks, id) {
  var list = tasks || []
  var out = []
  for (var i = 0; i < list.length; i++) {
    if (list[i] && list[i].id !== id) out.push(list[i])
  }
  return out.length === list.length ? list : out
}

function removeCompleted(tasks) {
  var list = tasks || []
  var out = []
  for (var i = 0; i < list.length; i++) {
    if (list[i] && normalizeStatus(list[i].status, list[i].completed) !== "complete")
      out.push(list[i])
  }
  return out.length === list.length ? list : out
}

function updateTask(tasks, id, title, description, priority) {
  var nextTitle = trim(title)
  var nextDescription = trim(description)
  var nextPriority = normalizePriority(priority)
  if (nextTitle === "") return tasks || []
  return mapTasks(tasks, id, function(task) {
    if (task.title === nextTitle && task.description === nextDescription && task.priority === nextPriority)
      return task
    return copyTask(task, {
      title: nextTitle,
      description: nextDescription,
      priority: nextPriority
    })
  })
}

function countStatus(tasks, status) {
  var list = tasks || []
  var want = normalizeStatus(status, false)
  var count = 0
  for (var i = 0; i < list.length; i++) {
    if (list[i] && normalizeStatus(list[i].status, list[i].completed) === want) count++
  }
  return count
}

function ongoingCount(tasks) {
  return countStatus(tasks, "ongoing")
}

function highestOngoing(tasks) {
  var list = tasks || []
  var best = ""
  var bestRank = 99
  for (var i = 0; i < list.length; i++) {
    var task = list[i]
    if (!task || normalizeStatus(task.status, task.completed) !== "ongoing") continue
    var taskRank = rank(task.priority)
    if (taskRank < bestRank) {
      bestRank = taskRank
      best = task.priority
    }
  }
  return best
}

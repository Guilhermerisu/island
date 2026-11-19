pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import ".."
import "../../views/control-center"
import "Todos.js" as Todos

Addon {
  id: todos
  views: [{ name: "todos", width: 500, padding: 20, component: todosView }]
  tiles: [{ key: "list", title: "Priority Todos", component: todosTile }]

  readonly property string stateDir: host.theme.home + "/.local/state/omarchy"
  readonly property int ongoingCount: Todos.ongoingCount(tasks)
  readonly property int reminderMinutes: Number(addon.option?.("reminderMinutes") ?? 60)
  readonly property var unfinished: Todos.listed(tasks, "", "ongoing").concat(Todos.listed(tasks, "", "backlog"))
  readonly property string highestPriority: Todos.highestOngoing(tasks)
  readonly property bool writable: loadState === "ready" && pending === null
  property var tasks: []
  property string activeTab: "ongoing"
  property string loadState: "loading"
  property string error: ""
  property bool readLegacy: false
  property var pending: null
  readonly property bool schedulingReminder: customReminder.running
  signal saveFinished(bool success)
  signal reminderFinished(bool success)

  Timer {
    interval: Math.max(1, todos.reminderMinutes) * 60000
    running: todos.loadState === "ready" && todos.reminderMinutes > 0 && todos.unfinished.length > 0
    repeat: true
    onTriggered: todos.remind()
  }
  Process { id: reminder }
  function remind() {
    if (!unfinished.length) return
    var heading = ("Unfinished tasks (%1)").replace("%1", String(unfinished.length))
    var title = unfinished[0].title.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    reminder.command = ["notify-send", "-a", "Priority Todos", "-i", "view-task", "--", heading, title]
    reminder.startDetached()
  }
  function scheduleReminder(minutes, message) {
    if (schedulingReminder || !Number.isInteger(minutes) || minutes < 1 || minutes > 10080
      || !message.trim() || message.trim().length > 240)
      return false
    customReminder.command = ["omarchy-reminder", String(minutes), message.trim()]
    customReminder.running = true
    return true
  }
  Process {
    id: customReminder
    onExited: function(code) { todos.reminderFinished(code === 0) }
  }

  function priorityColor(priority) {
    var theme = host.theme
    if (theme.luminance(theme.background) > 0.45) {
      return ({ critical: "#b31f19", high: "#905000", medium: "#776000", low: "#0058aa" })[priority]
        || theme.secondary
    }
    return ({ critical: theme.system.red, high: theme.system.orange, medium: theme.system.yellow,
      low: theme.system.blue })[priority] || theme.secondary
  }

  function loadFailed() {
    loadState = "failed"
    error = "Couldn’t read the task list"
  }

  function restore(raw, migrate) {
    var data = Todos.parseStore(raw)
    if (!data) {
      loadFailed()
      return
    }
    tasks = data.tasks
    activeTab = data.activeTab
    loadState = "ready"
    if (migrate) write(tasks, activeTab)
  }

  function save(nextTasks, nextTab) {
    if (!writable) return false
    error = ""
    if (nextTasks === tasks && nextTab === activeTab) return false
    write(nextTasks, nextTab)
    return true
  }

  function write(nextTasks, nextTab) {
    pending = { tasks: nextTasks, tab: nextTab }
    store.setText(Todos.serialize(nextTasks, nextTab))
  }

  function selectTab(tab) { save(tasks, Todos.normalizeTab(tab)) }
  function move(task, status) { save(Todos.setStatus(tasks, task.id, status), activeTab) }
  function remove(task) { return save(Todos.remove(tasks, task.id), activeTab) }
  function clearCompleted() { return save(Todos.removeCompleted(tasks), activeTab) }

  function saveTask(task, title, description, priority) {
    if (!Todos.trim(title)) return false
    if (task) return save(Todos.updateTask(tasks, task.id, title, description, priority), activeTab)
    var newTask = Todos.createTask(title, description, priority, Todos.addStatusForTab(activeTab))
    return save(Todos.add(tasks, newTask), newTask.status)
  }

  FileView {
    id: store
    path: todos.stateDir + "/island-todos.json"
    atomicWrites: true
    printErrors: false
    onLoaded: if (todos.loadState === "loading" && !todos.readLegacy) todos.restore(text(), false)
    onLoadFailed: function(error) {
      if (todos.loadState !== "loading" || todos.readLegacy) return
      if (error === FileViewError.FileNotFound) todos.readLegacy = true
      else todos.loadFailed()
    }
    onSaved: {
      var saved = todos.pending
      if (!saved) return
      todos.tasks = saved.tasks
      todos.activeTab = saved.tab
      todos.pending = null
      todos.saveFinished(true)
    }
    onSaveFailed: function(error) {
      todos.pending = null
      todos.error = "Couldn’t save the task list"
      todos.saveFinished(false)
    }
  }

  // The standalone widget keeps its own file. Only read it when Island has
  // no task list yet, and write the imported snapshot into Island's file.
  FileView {
    path: todos.readLegacy ? todos.stateDir + "/todos.json" : ""
    printErrors: false
    onLoaded: if (todos.loadState === "loading") todos.restore(text(), true)
    onLoadFailed: function(error) {
      if (!todos.readLegacy || todos.loadState !== "loading") return
      if (error === FileViewError.FileNotFound) todos.loadState = "ready"
      else todos.loadFailed()
    }
  }

  Component {
    id: todosView
    TodosView { todo: todos; active: todos.host.view === "todos" }
  }
  Component {
    id: todosTile
    CcTile {
      anchors.fill: parent
      center: parent.center
      icon: "󰄳"
      centerIconInk: true
      title: "Priority Todos"
      subtitle: todos.ongoingCount > 0 ? String(todos.ongoingCount) + " · "
        + (Todos.label(todos.highestPriority)) : "Nothing ongoing"
      checked: todos.ongoingCount > 0
      onClicked: todos.host.view = "todos"
    }
  }
}

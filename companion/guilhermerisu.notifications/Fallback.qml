import QtQuick
import Quickshell.Services.Notifications
import "DiscordCall.mjs" as Calls

// What the companion falls back on when Omarchy's own notification service
// can't be loaded (see Service.qml): a bare server that keeps banners coming
// to the island. Stacks and history come from the native service.
Item {
  id: fallback
  // Feed rows (see Service.qml), newest first.
  property var rows: []
  required property bool discordCallsInDnd
  property bool doNotDisturb: false
  property var refs: ({})
  property int seq: 0

  NotificationServer {
    keepOnReload: false
    imageSupported: true
    actionsSupported: true
    onNotification: function(n) { fallback.take(n) }
  }

  function take(n) {
    if (doNotDisturb && n.urgency !== NotificationUrgency.Critical
        && !Calls.bypassDoNotDisturb(n, discordCallsInDnd)) { n.tracked = false; return }
    // Otherwise the object is destroyed when this handler returns.
    n.tracked = true
    var key = "fallback" + Date.now().toString(36) + (++seq)
    refs[key] = n
    n.closed.connect(function() {
      delete fallback.refs[key]
      fallback.rows = fallback.rows.filter(function(r) { return r.key !== key })
    })
    var normal = n.urgency !== NotificationUrgency.Critical
    var hints = n.hints || ({})
    rows = [{ key: key, originalId: n.id, timestamp: Date.now(), app: n.appName, appIcon: n.appIcon, image: n.image,
              category: String(hints.category || ""), desktopEntry: String(hints["desktop-entry"] || ""),
              hasDefault: Array.from(n.actions).some(action => action.identifier === "default"),
              glyph: "", summary: n.summary, body: String(n.body).replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim(), urgency: n.urgency,
              group: "", stack: 1, actions: visibleActions(n).map(action => ({ id: action.identifier, label: action.text })),
              duration: normal ? Math.max(8000, n.expireTimeout) : 0 }].concat(rows)
  }

  function visibleActions(n) { return Array.from(n.actions).filter(action => action.identifier !== "default") }
  function runAction(key, index) {
    var n = refs[key]
    var action = n && visibleActions(n)[index]
    if (!action) return false
    action.invoke()
    dismiss(key)
    return true
  }

  // The sender's default action, if it has one; either way the banner goes.
  function invoke(key) {
    var n = refs[key]
    for (var i = 0; n && i < n.actions.length; i++)
      if (String(n.actions[i].identifier) === "default") { n.actions[i].invoke(); break }
    dismiss(key)
  }
  function dismiss(key) { if (refs[key]) refs[key].dismiss() }
}

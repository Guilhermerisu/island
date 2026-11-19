const hostName = "com.omarchy.island_youtube";
const allowedActions = new Set(["status", "next", "previous", "shuffle", "open"]);
let port;

function connect() {
  if (port) return;
  const connection = chrome.runtime.connectNative(hostName);
  port = connection;
  connection.onDisconnect.addListener(() => {
    void chrome.runtime.lastError;
    port = undefined;
  });
  connection.onMessage.addListener(async ({ action, title }) => {
    let result = {};
    try {
      if (allowedActions.has(action) && typeof title === "string" && title.trim()) {
        result = await handle(action, title);
      }
    } catch {
      // A tab may close or navigate while handling a request.
    }
    if (port === connection) connection.postMessage(result);
  });
}

async function handle(action, title) {
  const tabs = await chrome.tabs.query({ url: "https://www.youtube.com/watch*" });
  const candidates = await Promise.all(tabs.map(async tab => {
    try {
      const status = await chrome.tabs.sendMessage(tab.id, { action: "status", title });
      return status?.matched ? { tab, status } : null;
    } catch {
      return null;
    }
  }));
  const matches = candidates.filter(Boolean);
  const playing = matches.filter(candidate => candidate.status.playing);
  const eligible = playing.length ? playing : matches;
  if (eligible.length !== 1) return {};
  const { tab, status } = eligible[0];
  if (action === "status") return { ...status, canOpen: true };
  if (action === "open") {
    await chrome.tabs.update(tab.id, { active: true });
    await chrome.windows.update(tab.windowId, { focused: true });
    return { ok: true };
  }
  return chrome.tabs.sendMessage(tab.id, { action, title });
}

chrome.runtime.onStartup.addListener(connect);
chrome.runtime.onInstalled.addListener(connect);
chrome.alarms.onAlarm.addListener(alarm => {
  if (alarm.name === "native-host") connect();
});
chrome.alarms.create("native-host", { periodInMinutes: 0.5 });
connect();

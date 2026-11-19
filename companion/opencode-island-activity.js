import { spawnSync } from "node:child_process";
import { homedir } from "node:os";
import { join } from "node:path";

export const IslandActivity = async () => {
  const states = new Map();
  const bridge = join(process.env.XDG_CONFIG_HOME || join(homedir(), ".config"),
    "omarchy", "plugins", "guilhermerisu.island", "companion", "island-activity");
  function update(id, state) {
    if (!id || states.get(id) === state || (state === "done" && !states.has(id))) return;
    const status = spawnSync(bridge, [state, "--pid", String(process.pid), "opencode:" + id, "OpenCode"], {
      stdio: "ignore", timeout: 1000,
    });
    if (status.status !== 0) return;
    if (state === "done") states.delete(id);
    else states.set(id, state);
  }
  return {
    event: async ({ event }) => {
      const { sessionID, status } = event.properties || {};
      if (event.type === "session.status") {
        if (status?.type === "busy" || status?.type === "retry") update(sessionID, "start");
        else if (status?.type === "idle") update(sessionID, "done");
      } else if (event.type === "session.idle") {
        update(sessionID, "done");
      } else if (event.type === "permission.asked" || event.type === "question.asked") {
        update(sessionID, "waiting");
      } else if (["permission.replied", "question.replied", "question.rejected"].includes(event.type)) {
        if (states.get(sessionID) === "waiting") update(sessionID, "start");
      }
    },
  };
};

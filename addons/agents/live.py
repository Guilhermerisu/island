#!/usr/bin/env python3
"""Claude Code's sessions at work, for the Agents addon's live activity.

Follows the transcripts Claude Code writes as it goes (<config>/projects/
<project>/<session>.jsonl, for ~/.claude and any ~/.claude-* profile) and
prints one JSON line whenever what's worth showing changes:

  {"sessions": [{"id", "state", "startedAt", "doneAt"}]}

newest first. `state` is "thinking", "tool" (a step is running), "asking"
(it's waiting on your answer to a question or its plan), or "done"
(the turn ended, or was interrupted, `doneAt` ms ago at most DONE_KEPT).
`startedAt` is when you sent the turn's prompt, or when its first step
started if the prompt is out of reach.

Only the tail of a transcript is read when it's first seen, then what's
added to it. A session nothing's written to for IDLE seconds is dropped
(a permission prompt left waiting, or a closed window), or ASKING_IDLE
while it waits on your answer.
"""
import calendar
import glob
import json
import os
import time

POLL = 0.5          # seconds between looks at the sessions in play
RELIST = 3          # seconds between looks for new transcripts
IDLE = 10 * 60      # a session silent this long is no longer shown
ASKING_IDLE = 60 * 60  # ...unless it's waiting on your answer
DONE_KEPT = 30      # seconds a finished turn stays listed
TAIL = 1 << 20      # bytes read of a transcript first seen
MAX_SESSIONS = 4
ASKING_TOOLS = ("AskUserQuestion", "ExitPlanMode")  # the tools that wait on your answer


def now_ms():
    return int(time.time() * 1000)


def iso_ms(ts):
    try:
        return calendar.timegm(time.strptime(ts[:19], "%Y-%m-%dT%H:%M:%S")) * 1000 + int(ts[20:23] or 0)
    except (TypeError, ValueError):
        return now_ms()


class Session:
    def __init__(self, path):
        self.path = path
        self.id = os.path.splitext(os.path.basename(path))[0]
        self.offset = 0
        self.running = {}      # the turn's running steps by id: whether it's asking
        self.state = ""        # "", thinking, tool, asking, done
        self.started = 0
        self.done_at = 0
        self.updated = 0

    def read(self):
        try:
            size = os.path.getsize(self.path)
        except OSError:
            return
        if size < self.offset:
            self.offset = 0
        if size == self.offset:
            return
        first = self.offset == 0
        start = max(0, size - TAIL) if first else self.offset
        with open(self.path, "rb") as f:
            f.seek(start)
            data = f.read(size - start)
        # A line still being written waits for the next look.
        end = data.rfind(b"\n") + 1
        self.offset = start + end
        chunk = data[:end].decode("utf-8", "replace").splitlines()
        if first and start > 0:
            chunk = chunk[1:]
        for line in chunk:
            try:
                self.take(json.loads(line))
            except (ValueError, AttributeError):
                pass

    def take(self, entry):
        kind = entry.get("type")
        if kind not in ("user", "assistant") or entry.get("isSidechain"):
            return
        stamp = iso_ms(entry.get("timestamp"))
        self.updated = max(self.updated, stamp)
        content = (entry.get("message") or {}).get("content")
        if kind == "user":
            if isinstance(content, str) or not any(b.get("type") == "tool_result" for b in content or []):
                text = content if isinstance(content, str) else " ".join(
                    b.get("text", "") for b in content or [] if b.get("type") == "text")
                if text.startswith("[Request interrupted"):
                    self.finish(stamp)
                elif not entry.get("isMeta") and text.strip() and not text.lstrip().startswith("<"):
                    # A new turn.
                    self.running, self.state, self.started, self.done_at = {}, "thinking", stamp, 0
                return
            for block in content:
                if block.get("type") == "tool_result":
                    self.running.pop(block.get("tool_use_id"), None)
            if self.state != "done":
                self.state = self.working()
            return
        for block in content or []:
            if block.get("type") == "tool_use":
                self.running[block.get("id")] = block.get("name") in ASKING_TOOLS
                self.started = self.started or stamp
        if (entry.get("message") or {}).get("stop_reason") == "end_turn":
            self.finish(stamp)
        elif self.state != "done" or self.running:
            self.state = self.working()
            self.done_at = 0

    def working(self):
        if any(self.running.values()):
            return "asking"
        return "tool" if self.running else "thinking"

    def finish(self, stamp):
        self.running = {}
        self.state = "done"
        self.done_at = stamp

    def shown(self, now):
        if not self.state:
            return False
        if self.state == "done":
            return now - self.done_at < DONE_KEPT * 1000
        # Waiting on you, nothing's written for as long as you take.
        idle = ASKING_IDLE if self.state == "asking" else IDLE
        return now - max(self.updated, mtime_ms(self.path)) < idle * 1000

    def snapshot(self):
        return {"id": self.id, "state": self.state, "startedAt": self.started, "doneAt": self.done_at}


def mtime_ms(path):
    try:
        return int(os.path.getmtime(path) * 1000)
    except OSError:
        return 0


def roots():
    seen, out = set(), []
    for root in [os.environ.get("CLAUDE_CONFIG_DIR", "")] + glob.glob(os.path.expanduser("~/.claude*")):
        projects = os.path.join(root, "projects") if root else ""
        real = os.path.realpath(projects) if projects and os.path.isdir(projects) else ""
        if real and real not in seen:
            seen.add(real)
            out.append(real)
    return out


def main():
    sessions, hot, last, listed = {}, [], None, 0
    while True:
        if os.getppid() == 1:
            return
        now = time.time()
        if now - listed >= RELIST:
            listed = now
            # Followed as long as one could still be shown: a question can
            # wait on you longer than a session may otherwise sit quiet.
            hot = [p for r in roots() for p in glob.glob(os.path.join(r, "*", "*.jsonl"))
                   if now - os.path.getmtime(p) < max(IDLE, ASKING_IDLE)]
        for path in hot:
            if path not in sessions:
                sessions[path] = Session(path)
            sessions[path].read()
        stamp = now_ms()
        shown = sorted((s for s in sessions.values() if s.shown(stamp)), key=lambda s: -s.updated)
        out = json.dumps({"sessions": [s.snapshot() for s in shown[:MAX_SESSIONS]]}, separators=(",", ":"))
        if out != last:
            last = out
            try:
                print(out, flush=True)
            except BrokenPipeError:
                os._exit(0)
        # Forgotten once they've gone quiet, so the next look reads them afresh.
        for path in [p for p in sessions if p not in hot]:
            del sessions[path]
        time.sleep(POLL)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Claude Code's and Codex's sessions at work, for the Agents addon's live activity.

Follows the transcripts Claude Code writes as it goes (<config>/projects/
<project>/<session>.jsonl, for ~/.claude and any ~/.claude-* profile) and
Codex's (~/.codex/sessions/<year>/<month>/<day>/rollout-*.jsonl, the CLI, the
IDE extension and the ChatGPT desktop app alike) and prints one JSON line
whenever what's worth showing changes:

  {"sessions": [{"id", "provider", "name", "state", "startedAt", "doneAt",
                 "interrupted", "transcript"}]}

newest first. `state` is "thinking", "tool" (a step is running), "asking"
(it's waiting on your answer to a question or its plan), or "done"
(the turn ended, or was interrupted, `doneAt` ms ago at most DONE_KEPT;
`interrupted` tells the two apart).
`startedAt` is when you sent the turn's prompt, or when its first step
started if the prompt is out of reach.

Only the tail of a transcript is read when it's first seen, then what's
added to it. A session nothing's written to for IDLE seconds is dropped
(a permission prompt left waiting, or a closed window), or ASKING_IDLE
while it waits on your answer.
"""
import calendar
from datetime import date, timedelta
import glob
import json
import os
from pathlib import Path
import time

POLL = 0.5          # seconds between looks at the sessions in play
RELIST = 3          # seconds between looks for new transcripts
IDLE = 10 * 60      # a session silent this long is no longer shown
ASKING_IDLE = 60 * 60  # ...unless it's waiting on your answer
DONE_KEPT = 30      # seconds a finished turn stays listed
TAIL = 1 << 20      # bytes read of a transcript first seen
CODEX_TAIL = 16 << 20  # tool output can fill several MiB of one Codex turn
MAX_SESSIONS = 4
CODEX_START = ("task_started", "turn_started")
CODEX_FINISH = ("task_complete", "turn_completed")
CODEX_EVENTS = tuple(f'"{kind}"' for kind in CODEX_START + CODEX_FINISH + ("turn_aborted",))
CODEX_TOOL_IN = ("function_call", "custom_tool_call")
CODEX_TOOL_OUT = ("function_call_output", "custom_tool_call_output")
ASKING_TOOLS = ("AskUserQuestion", "ExitPlanMode")  # the tools that wait on your answer


def now_ms():
    return int(time.time() * 1000)


def iso_ms(ts):
    try:
        return calendar.timegm(time.strptime(ts[:19], "%Y-%m-%dT%H:%M:%S")) * 1000 + int(ts[20:23] or 0)
    except (TypeError, ValueError):
        return now_ms()


class Session:
    def __init__(self, path, provider="claude"):
        self.path = path
        self.provider = provider
        self.name = "Claude Code" if provider == "claude" else "Codex"
        self.meta_read = False
        self.hidden = False    # a Codex sub-agent's: its parent's turn covers it
        self.turn = None
        self.id = os.path.splitext(os.path.basename(path))[0]
        self.offset = 0
        self.running = {}      # the turn's running steps by id: whether it's asking
        self.state = ""        # "", thinking, tool, asking, done
        self.started = 0
        self.done_at = 0
        self.interrupted = False
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
        limit = CODEX_TAIL if self.provider == "codex" else TAIL
        start = max(0, size - limit) if first else self.offset
        try:
            with open(self.path, "rb") as f:
                if self.provider == "codex" and not self.meta_read:
                    self.read_meta(f.readline(TAIL))
                f.seek(start)
                data = f.read(size - start)
        except OSError:
            return
        # A line still being written waits for the next look.
        end = data.rfind(b"\n") + 1
        self.offset = start + end
        chunk = data[:end].decode("utf-8", "replace").splitlines()
        if first and start > 0:
            chunk = chunk[1:]
        for line in chunk:
            if self.provider == "codex" and not self.codex_line(line):
                continue
            try:
                self.take(json.loads(line))
            except (ValueError, AttributeError, TypeError):
                pass

    # Codex's transcripts are mostly output nobody here needs: only a turn's
    # start and end and its tool calls are parsed.
    @staticmethod
    def codex_line(line):
        if '"event_msg"' in line:
            return any(kind in line for kind in CODEX_EVENTS)
        return '"response_item"' in line and ('"function_call' in line or '"custom_tool_call' in line)

    # Its first line says where the session runs.
    def read_meta(self, line):
        try:
            entry = json.loads(line)
            if entry.get("type") != "session_meta":
                return
            meta = entry.get("payload") or {}
            source, origin = meta.get("source"), str(meta.get("originator", "")).lower()
            self.id = meta.get("id") or self.id
            if isinstance(source, dict) and "subagent" in source:
                self.hidden = True
            elif "desktop" in origin or "chatgpt" in origin:
                self.name = "Codex Desktop"
            elif source == "vscode":
                self.name = "Codex IDE"
            elif source in ("cli", "exec"):
                self.name = "Codex CLI"
        except (ValueError, AttributeError, TypeError):
            return
        self.meta_read = True

    def take_codex(self, entry):
        payload = entry.get("payload") or {}
        kind = payload.get("type")
        stamp = iso_ms(entry.get("timestamp"))
        if entry.get("type") == "response_item":
            call = payload.get("call_id")
            if call and self.state not in ("", "done"):
                if kind in CODEX_TOOL_IN:
                    asking = str(payload.get("name", "")).endswith(("request_user_input", "request_user_input_async"))
                    self.running[call] = asking
                elif kind in CODEX_TOOL_OUT:
                    self.running.pop(call, None)
                else:
                    return
                self.updated = max(self.updated, stamp)
                self.state = self.working()
            return
        if entry.get("type") != "event_msg":
            return
        if kind in CODEX_START:
            self.updated = max(self.updated, stamp)
            self.turn = payload.get("turn_id")
            self.running, self.state, self.started, self.done_at = {}, "thinking", stamp, 0
            self.interrupted = False
        elif kind in CODEX_FINISH + ("turn_aborted",):
            turn = payload.get("turn_id")
            if self.turn and turn and self.turn != turn:
                return
            self.updated = max(self.updated, stamp)
            if self.state and self.state != "done":
                self.finish(stamp, interrupted=kind == "turn_aborted")

    def take(self, entry):
        if self.provider == "codex":
            self.take_codex(entry)
            return
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
                    self.finish(stamp, interrupted=True)
                elif not entry.get("isMeta") and text.strip() and not text.lstrip().startswith("<"):
                    # A new turn.
                    self.running, self.state, self.started, self.done_at = {}, "thinking", stamp, 0
                    self.interrupted = False
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

    def finish(self, stamp, interrupted=False):
        self.running = {}
        self.state = "done"
        self.done_at = stamp
        self.interrupted = interrupted

    def shown(self, now):
        if not self.state:
            return False
        if self.state == "done":
            return now - self.done_at < DONE_KEPT * 1000
        # Waiting on you, nothing's written for as long as you take.
        idle = ASKING_IDLE if self.state == "asking" else IDLE
        return now - max(self.updated, mtime_ms(self.path)) < idle * 1000

    def snapshot(self):
        return {"id": self.id, "provider": self.provider, "name": self.name, "state": self.state,
                "startedAt": self.started, "doneAt": self.done_at, "interrupted": self.interrupted,
                "transcript": self.path}


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


# Today's and yesterday's rollouts: a turn can run across midnight.
def codex_paths():
    root = Path(os.environ.get("CODEX_HOME") or Path.home() / ".codex") / "sessions"
    today = date.today()
    for day in (today, today - timedelta(days=1)):
        yield from (str(p) for p in (root / day.strftime("%Y/%m/%d")).glob("rollout-*.jsonl"))


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
            found = [(p, "claude") for r in roots() for p in glob.glob(os.path.join(r, "*", "*.jsonl"))]
            found.extend((p, "codex") for p in codex_paths())
            hot = [(p, provider) for p, provider in found if now - mtime_ms(p) / 1000 < max(IDLE, ASKING_IDLE)]
        for path, provider in hot:
            if path not in sessions:
                sessions[path] = Session(path, provider)
            sessions[path].read()
        stamp = now_ms()
        shown = sorted((s for s in sessions.values() if not s.hidden and s.shown(stamp)), key=lambda s: -s.updated)
        out = json.dumps({"sessions": [s.snapshot() for s in shown[:MAX_SESSIONS]]}, separators=(",", ":"))
        if out != last:
            last = out
            try:
                print(out, flush=True)
            except BrokenPipeError:
                os._exit(0)
        # Forgotten once they've gone quiet, so the next look reads them afresh.
        for path in [p for p in sessions if p not in {h[0] for h in hot}]:
            del sessions[path]
        time.sleep(POLL)


if __name__ == "__main__":
    main()

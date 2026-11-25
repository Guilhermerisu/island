#!/usr/bin/env python3
"""Claude Code's sessions at work, for the Agents addon's live activity.

Follows the transcripts Claude Code writes as it goes (<config>/projects/
<project>/<session>.jsonl, for ~/.claude and any ~/.claude-* profile) and
prints one JSON line whenever what's worth showing changes:

  {"sessions": [{"id", "title", "state", "startedAt", "doneAt", "interrupted",
                 "text", "prompt", "summary", "steps": [...]}]}

newest first. `state` is "thinking", "tool" (a step is running), "asking"
(it's waiting on your answer to a question or its plan), or "done"
(the turn ended, or was interrupted, `doneAt` ms ago at most DONE_KEPT;
`interrupted` tells the two apart).
`startedAt` is when you sent the turn's prompt, or when its first step
started if the prompt is out of reach (0 if neither is known).
`steps` are the current turn's last tool calls, oldest first: {"id",
"label", "kind" (read, edit, run, search, web, agent, ask, other),
"status" (running, done, error), "startedAt", "endedAt" (once it's
finished), "file", "command", "added", "removed", and an ask's
"question"}. `summary` counts the whole turn, past the steps listed:
{"steps", "files" (edited), "added", "removed"}. `text` is the agent's
latest line to you this turn, `prompt` yours that started it.

Only the tail of a transcript is read when it's first seen, then what's
added to it. A session nothing's written to for IDLE seconds is dropped
(a permission prompt left waiting, or a closed window), or ASKING_IDLE
while it waits on your answer.
"""
import calendar
import glob
import json
import os
import re
import time

POLL = 0.5          # seconds between looks at the sessions in play
RELIST = 3          # seconds between looks for new transcripts
IDLE = 10 * 60      # a session silent this long is no longer shown
ASKING_IDLE = 60 * 60  # ...unless it's waiting on your answer
DONE_KEPT = 30      # seconds a finished turn stays listed
TAIL = 1 << 20      # bytes read of a transcript first seen
MAX_STEPS = 6
MAX_SESSIONS = 4
ASKING_TOOLS = ("AskUserQuestion", "ExitPlanMode")  # the tools that wait on your answer


def now_ms():
    return int(time.time() * 1000)


def iso_ms(ts):
    try:
        return calendar.timegm(time.strptime(ts[:19], "%Y-%m-%dT%H:%M:%S")) * 1000 + int(ts[20:23] or 0)
    except (TypeError, ValueError):
        return now_ms()


def lines_of(text):
    return len(str(text or "").splitlines())


def short(text, n=80):
    text = " ".join(str(text or "").split())
    return text if len(text) <= n else text[: n - 1] + "…"


def command_summary(command):
    """The part of a shell command that does the work: `cd x && npm test`
    is `npm test`, `S=/tmp/a; omarchy restart shell >/dev/null` is
    `omarchy restart shell`."""
    line = command.strip().splitlines()[0] if command.strip() else ""
    for part in re.split(r"\s*(?:&&|\|\||;)\s*", line):
        part = re.sub(r"\s*(?:\d?>>?|&>)\s*\S+", "", part.split("|")[0]).strip()
        words = part.split()
        while words and re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", words[0]):
            words.pop(0)
        if words and words[0] not in ("cd", "sleep", "export", "source", ".", "set", "true"):
            return short(" ".join(words), 60)
    return short(line, 60)


def step_for(block):
    name = block.get("name") or ""
    args = block.get("input") or {}
    base = os.path.basename(str(args.get("file_path") or args.get("notebook_path") or args.get("path") or ""))
    step = {"id": block.get("id"), "kind": "other", "status": "running", "file": "", "command": "",
            "added": 0, "removed": 0}
    if name == "Read":
        step.update(kind="read", label="Read " + base, file=base)
    elif name in ("Edit", "MultiEdit", "NotebookEdit"):
        edits = args.get("edits") or [args]
        step.update(kind="edit", label="Edit " + base, file=base,
                    added=sum(lines_of(e.get("new_string") or e.get("new_source")) for e in edits),
                    removed=sum(lines_of(e.get("old_string")) for e in edits))
    elif name == "Write":
        step.update(kind="edit", label="Write " + base, file=base, added=lines_of(args.get("content")))
    elif name in ("Bash", "PowerShell"):
        command = str(args.get("command") or "").strip()
        step.update(kind="run", command=command_summary(command),
                    label=short(args.get("description") or "Run " + command, 60))
    elif name in ("Grep", "Glob"):
        step.update(kind="search", label="Search " + short(args.get("pattern"), 40))
    elif name in ("WebSearch", "WebFetch"):
        url = str(args.get("url") or "")
        host = url.split("/")[2] if url.count("/") >= 2 else ""
        step.update(kind="web", label="Fetch " + host if host else "Search " + short(args.get("query"), 40))
    elif name in ("Agent", "Task"):
        step.update(kind="agent", label=short(args.get("description") or "Run an agent", 60))
    elif name in ASKING_TOOLS:
        if name == "ExitPlanMode":
            step.update(kind="ask", label="Review the plan", question="It has a plan ready for you to approve.")
        else:
            questions = args.get("questions") or [{}]
            question = str((questions[0] if isinstance(questions[0], dict) else {}).get("question") or "")
            step.update(kind="ask", label=short(question or "Ask you a question", 60), question=short(question, 160))
    elif name == "TodoWrite":
        step.update(label="Update the to-do list")
    elif name == "Skill":
        step.update(label="Use " + str(args.get("skill") or "a skill"))
    elif name.startswith("mcp__"):
        step.update(label=name.split("__")[-1].replace("_", " ").capitalize())
    else:
        step.update(label=name)
    return step


class Session:
    def __init__(self, path):
        self.path = path
        self.id = os.path.splitext(os.path.basename(path))[0]
        self.offset = 0
        self.title = ""
        self.prompt = ""
        self.cwd = ""
        self.steps = []
        self.text = ""
        self.state = ""        # "", thinking, tool, asking, done
        self.started = 0
        self.count = 0
        self.edits = {}        # the turn's edits by step: [path, added, removed]
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
        if kind == "custom-title":
            self.title = entry.get("customTitle") or self.title
        elif kind == "agent-name" and not self.title:
            self.title = entry.get("agentName") or ""
        elif kind == "last-prompt":
            self.prompt = entry.get("lastPrompt") or self.prompt
        if kind not in ("user", "assistant") or entry.get("isSidechain"):
            return
        self.cwd = entry.get("cwd") or self.cwd
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
                    self.steps, self.text, self.state, self.done_at = [], "", "thinking", 0
                    self.started, self.count, self.edits = stamp, 0, {}
                    self.interrupted = False
                    self.prompt = text
                return
            for block in content:
                if block.get("type") != "tool_result":
                    continue
                patch = entry.get("toolUseResult") if isinstance(entry.get("toolUseResult"), dict) else {}
                hunks = patch.get("structuredPatch")
                lines = None
                if hunks:
                    marks = [l[:1] for h in hunks for l in h.get("lines", [])]
                    lines = (marks.count("+"), marks.count("-"))
                # A failed edit changed nothing, so it isn't counted.
                if block.get("is_error"):
                    self.edits.pop(block.get("tool_use_id"), None)
                edit = self.edits.get(block.get("tool_use_id"))
                if edit and lines:
                    edit[1], edit[2] = lines
                for step in self.steps:
                    if step["id"] == block.get("tool_use_id"):
                        step["status"] = "error" if block.get("is_error") else "done"
                        step["endedAt"] = stamp
                        if lines:
                            step["added"], step["removed"] = lines
            if self.state != "done":
                self.state = self.working()
            return
        for block in content or []:
            if block.get("type") == "tool_use":
                step = step_for(block)
                step["startedAt"] = stamp
                self.started = self.started or stamp
                self.count += 1
                if step["kind"] == "edit":
                    args = block.get("input") or {}
                    path = args.get("file_path") or args.get("notebook_path") or step["file"]
                    self.edits[step["id"]] = [path, step["added"], step["removed"]]
                self.steps = (self.steps + [step])[-MAX_STEPS:]
            elif block.get("type") == "text" and block.get("text", "").strip():
                self.text = short(block["text"].strip().splitlines()[0], 120)
        if (entry.get("message") or {}).get("stop_reason") == "end_turn":
            self.finish(stamp)
        elif self.state != "done" or self.running():
            self.state = self.working()
            self.done_at = 0
            self.interrupted = False

    def working(self):
        running = [s for s in self.steps if s["status"] == "running"]
        if any(s["kind"] == "ask" for s in running):
            return "asking"
        return "tool" if running else "thinking"

    def running(self):
        return any(s["status"] == "running" for s in self.steps)

    def finish(self, stamp, interrupted=False):
        for step in self.steps:
            if step["status"] == "running":
                step["status"] = "error"
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
        project = os.path.basename(self.cwd.rstrip("/")) if self.cwd else ""
        return {"id": self.id, "title": short(self.title or self.prompt or project or "Claude Code", 60),
                "state": self.state, "startedAt": self.started, "doneAt": self.done_at,
                "interrupted": self.interrupted, "text": self.text, "prompt": short(self.prompt, 160),
                "summary": {"steps": self.count, "files": len({e[0] for e in self.edits.values()}),
                            "added": sum(e[1] for e in self.edits.values()),
                            "removed": sum(e[2] for e in self.edits.values())},
                "steps": self.steps}


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

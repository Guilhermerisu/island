#!/usr/bin/env python3
"""Claude Code's and Codex's sessions at work, for the Agents addon's live activity.

Follows the transcripts Claude Code writes as it goes (<config>/projects/
<project>/<session>.jsonl, for ~/.claude and any ~/.claude-* profile) and
Codex's (~/.codex/sessions/<year>/<month>/<day>/rollout-*.jsonl, the CLI, the
IDE extension and the ChatGPT desktop app alike) and prints one JSON line
whenever what's worth showing changes:

  {"sessions": [{"id", "provider", "name", "title", "state", "startedAt",
                 "doneAt", "interrupted", "transcript", "text", "prompt",
                 "summary", "steps": [...]}]}

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
from datetime import date, timedelta
import glob
import json
import os
from pathlib import Path
import re
import time

POLL = 0.5          # seconds between looks at the sessions in play
RELIST = 3          # seconds between looks for new transcripts
RESCAN = 30         # ...and between looks through all of Codex's days
IDLE = 10 * 60      # a session silent this long is no longer shown
ASKING_IDLE = 60 * 60  # ...unless it's waiting on your answer
DONE_KEPT = 30      # seconds a finished turn stays listed
TAIL = 1 << 20      # bytes read of a transcript first seen
MAX_STEPS = 6
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


CODEX_ASKING = ("request_user_input", "request_user_input_async")
CODEX_RUN = ("shell", "local_shell", "exec_command", "container.exec")


def codex_step(payload):
    """A Codex tool call as a step, as step_for makes Claude's."""
    name = str(payload.get("name") or "")
    step = {"id": payload.get("call_id"), "kind": "other", "status": "running", "file": "",
            "command": "", "added": 0, "removed": 0, "label": name or "Use a tool"}
    if name.endswith(CODEX_ASKING):
        step.update(kind="ask", label="Ask you a question", question="It's waiting on your answer.")
    elif name in CODEX_RUN:
        try:
            args = json.loads(payload.get("arguments") or "{}")
        except ValueError:
            args = {}
        command = args.get("command") or args.get("cmd") or ""
        if isinstance(command, list):
            # ["bash", "-lc", "npm test"] runs its last word.
            command = command[-1] if command[:1] in (["bash"], ["sh"], ["zsh"]) else " ".join(map(str, command))
        command = str(command)
        step.update(kind="run", command=command_summary(command), label=short("Run " + command_summary(command), 60))
    return step


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
        limit = CODEX_TAIL if self.provider == "codex" else TAIL
        start = max(0, size - limit) if first else self.offset
        try:
            with open(self.path, "rb") as f:
                if self.provider == "codex" and not self.meta_read:
                    self.read_meta(f.readline(CODEX_TAIL))
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

    # Its first line says where the session runs. Read once it's whole, even
    # if it turns out not to be the session's meta.
    def read_meta(self, line):
        if not line.endswith(b"\n"):
            return
        self.meta_read = True
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

    def take_codex(self, entry):
        payload = entry.get("payload") or {}
        kind = payload.get("type")
        stamp = iso_ms(entry.get("timestamp"))
        if entry.get("type") == "response_item":
            call = payload.get("call_id")
            if call and self.state not in ("", "done"):
                if kind in CODEX_TOOL_IN:
                    step = codex_step(payload)
                    step["startedAt"] = stamp
                    self.count += 1
                    self.add_step(step)
                elif kind in CODEX_TOOL_OUT:
                    for step in self.steps:
                        if step["id"] == call and step["status"] == "running":
                            step["status"] = "done"
                            step["endedAt"] = stamp
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
            self.steps, self.text, self.state, self.done_at = [], "", "thinking", 0
            self.started, self.count, self.edits = stamp, 0, {}
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
                self.add_step(step)
            elif block.get("type") == "text" and block.get("text", "").strip():
                self.text = short(block["text"].strip().splitlines()[0], 120)
        # end_turn, but also stop_sequence (API errors such as an expired
        # login), max_tokens or refusal: anything but a step still to run.
        if (entry.get("message") or {}).get("stop_reason") not in (None, "tool_use"):
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

    def add_step(self, step):
        """Keeps the last MAX_STEPS steps, dropping finished ones first, so
        a step still running is never lost (working() reads them)."""
        steps = self.steps + [step]
        while len(steps) > MAX_STEPS:
            done = next((i for i, s in enumerate(steps) if s["status"] != "running"), None)
            if done is None:
                break
            steps.pop(done)
        self.steps = steps

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
        return {"id": self.id, "provider": self.provider, "name": self.name,
                "title": short(self.title or self.prompt or project or self.name, 60),
                "state": self.state, "startedAt": self.started, "doneAt": self.done_at,
                "interrupted": self.interrupted, "transcript": self.path,
                "text": self.text, "prompt": short(self.prompt, 160),
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


# Today's and yesterday's rollouts (a turn can run across midnight), and, now
# and then, every day's: a resumed session goes on in the rollout of the day
# it began.
def codex_paths(everywhere=False):
    root = Path(os.environ.get("CODEX_HOME") or Path.home() / ".codex") / "sessions"
    if everywhere:
        yield from (str(p) for p in root.glob("*/*/*/rollout-*.jsonl"))
        return
    today = date.today()
    for day in (today, today - timedelta(days=1)):
        yield from (str(p) for p in (root / day.strftime("%Y/%m/%d")).glob("rollout-*.jsonl"))


def main():
    sessions, hot, last, listed, scanned, resumed = {}, [], None, 0, 0, []
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
            if now - scanned >= RESCAN:
                scanned = now
                recent = {p for p, _ in found}
                resumed = [p for p in codex_paths(everywhere=True)
                           if p not in recent and now - mtime_ms(p) / 1000 < max(IDLE, ASKING_IDLE)]
            found.extend((p, "codex") for p in resumed)
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
        followed = {p for p, _ in hot}
        for path in [p for p in sessions if p not in followed]:
            del sessions[path]
        time.sleep(POLL)


if __name__ == "__main__":
    main()

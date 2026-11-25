#!/usr/bin/env python3
"""Plays a fake agent turn and films the island's agents pill and its notices, to see their animations.

  python3 tests/banner_demo.py codex|claude [out-dir]

The turn is written as a transcript the agents addon follows: it thinks for a
second, asks a question, then finishes. Needs the island with the Agents addon
on, and grim; the frames of the island (the top middle of the first monitor,
GRIM_REGION to change it) land in out-dir, named by their second. The fake
transcript is removed at the end.
"""
import json, os, subprocess, sys, threading, time
from datetime import datetime, timezone
from pathlib import Path

agent = sys.argv[1]
out = Path(sys.argv[2] if len(sys.argv) > 2 else "banner-frames"); out.mkdir(exist_ok=True)
now = lambda: datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z")
if agent == "codex":
    today = datetime.now().strftime("%Y/%m/%d")
    f = Path.home() / ".codex/sessions" / today / "rollout-island-banner-test.jsonl"
    f.parent.mkdir(parents=True, exist_ok=True)
else:
    d = Path.home() / ".claude/projects/-tmp-island-banner-test"; d.mkdir(exist_ok=True)
    f = d / "11111111-2222-3333-4444-555555555555.jsonl"

def w(entry):
    with open(f, "a") as h: h.write(json.dumps(entry) + "\n")

def script():
    f.write_text("")
    time.sleep(1)
    if agent == "codex":
        w({"type": "session_meta", "payload": {"id": "banner-test", "originator": "codex_cli_rs", "source": "cli"}})
        w({"type": "event_msg", "timestamp": now(), "payload": {"type": "task_started", "turn_id": "t"}})
        time.sleep(3); w({"type": "response_item", "timestamp": now(), "payload": {"type": "function_call", "call_id": "q", "name": "request_user_input"}})
        time.sleep(7); w({"type": "response_item", "timestamp": now(), "payload": {"type": "function_call_output", "call_id": "q"}})
        time.sleep(1); w({"type": "event_msg", "timestamp": now(), "payload": {"type": "task_complete", "turn_id": "t"}})
    else:
        w({"type": "user", "timestamp": now(), "message": {"content": "hi"}})
        time.sleep(3); w({"type": "assistant", "timestamp": now(), "message": {"stop_reason": "tool_use", "content": [{"type": "tool_use", "id": "q", "name": "AskUserQuestion"}]}})
        time.sleep(7); w({"type": "user", "timestamp": now(), "message": {"content": [{"type": "tool_result", "tool_use_id": "q"}]}})
        time.sleep(1); w({"type": "assistant", "timestamp": now(), "message": {"stop_reason": "end_turn", "content": [{"type": "text", "text": "ok"}]}})
    time.sleep(8)
    f.unlink(missing_ok=True)
    if agent == "claude": f.parent.rmdir()

t0 = time.time()
threading.Thread(target=script, daemon=True).start()
n = 0
while time.time() - t0 < 19:
    subprocess.run(["grim", "-g", os.environ.get("GRIM_REGION", "630,0 340x75"), str(out / f"{n:03d}_{time.time()-t0:05.2f}.png")])
    n += 1
print(n, "frames")

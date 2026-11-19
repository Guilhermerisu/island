"""Read and validate per-user activity events written by the Island companion."""
import json
import os
from pathlib import Path


def runtime():
    directory = os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}"
    return Path(directory) / "island-activities"


def process_start(pid):
    try:
        return Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()[19]
    except (OSError, IndexError, UnicodeError):
        return None


def external_sessions(now, idle, done_kept):
    for path in runtime().glob("*.json"):
        try:
            data = json.loads(path.read_text())
            if not isinstance(data, dict):
                continue
            state = data["state"]
            if state not in ("thinking", "tool", "asking", "done", "failed"):
                continue
            age = now - data["updatedAt"]
            ended = state in ("done", "failed")
            pid = data["pid"]
            if not isinstance(pid, int) or not 0 <= pid:
                continue
            if ended:
                if age >= done_kept:
                    continue
            elif pid:
                started = process_start(pid)
                if not started or started != data["processStart"]:
                    continue
            elif age >= idle:
                continue
            fields = ("id", "name", "startedAt", "doneAt", "updatedAt")
            yield {**{key: data[key] for key in fields}, "provider": "external",
                   "state": "done" if ended else state, "failed": state == "failed"}
        except (OSError, ValueError, TypeError, KeyError):
            continue

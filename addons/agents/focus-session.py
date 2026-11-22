"""Focus the Hyprland client that owns a Claude Code or Codex session."""
import json
import os
from pathlib import Path
import re
import subprocess
import sys

PROC = Path("/proc")
ADDRESS = re.compile(r"0x[0-9a-fA-F]+")


def hyprctl(*args):
    try:
        return subprocess.check_output(
            ["hyprctl", *args], stderr=subprocess.DEVNULL, text=True, timeout=1
        ).strip()
    except (OSError, subprocess.SubprocessError):
        return ""


def hypr_list(query):
    try:
        data = json.loads(hyprctl("-j", query))
    except ValueError:
        return []
    return data if isinstance(data, list) else []


def session_pids(session_id):
    roots = set(Path.home().glob(".claude*"))
    config = os.environ.get("CLAUDE_CONFIG_DIR")
    if config:
        roots.add(Path(config))
    for root in roots:
        for marker in (root / "sessions").glob("[0-9]*.json"):
            try:
                data = json.loads(marker.read_bytes())
                if data.get("sessionId", data.get("session_id")) != session_id:
                    continue
                pid = int(marker.stem)
                if (PROC / str(pid) / "comm").read_text().strip() in {"claude", "claude-code"}:
                    yield pid
            except (OSError, ValueError, AttributeError):
                continue


def transcript_pids(transcript):
    """Codex keeps its rollout file open while a session runs, in the CLI
    and in the desktop app's server alike."""
    try:
        wanted = os.path.realpath(transcript)
    except (OSError, ValueError):
        return
    for entry in PROC.glob("[0-9]*"):
        try:
            if entry.stat().st_uid != os.getuid():
                continue
            for fd in (entry / "fd").iterdir():
                if os.path.realpath(fd) == wanted:
                    yield int(entry.name)
                    break
        except OSError:
            continue


def ancestors(pid):
    while pid > 1:
        yield pid
        try:
            stat = (PROC / str(pid) / "stat").read_text()
            pid = int(stat.rsplit(")", 1)[1].split()[1])
        except (OSError, ValueError, IndexError):
            return


def resolve(session_id, clients, provider="claude", transcript=""):
    by_pid, matches = {}, {}
    for window in clients:
        address = window.get("address", "")
        if window.get("mapped") and not window.get("hidden") and ADDRESS.fullmatch(address):
            by_pid.setdefault(window.get("pid"), []).append(window)
    pids = transcript_pids(transcript) if provider == "codex" and transcript else session_pids(session_id)
    for pid in pids:
        for owner in ancestors(pid):
            if owner in by_pid:
                matches.update((window["address"], window) for window in by_pid[owner])
                break
    return next(iter(matches.values())) if len(matches) == 1 else None


def focus(window):
    workspace = window.get("workspace", {}).get("name", "")
    if workspace.startswith("special:") and not any(
        monitor.get("specialWorkspace", {}).get("name") == workspace for monitor in hypr_list("monitors")
    ):
        name = workspace.removeprefix("special:")
        if (hyprctl("dispatch", f"hl.dsp.workspace.toggle_special({json.dumps(name, ensure_ascii=False)})") != "ok"
                and hyprctl("dispatch", "togglespecialworkspace", name) != "ok"):
            return False
    address = "address:" + window["address"]
    return (hyprctl("dispatch", f"hl.dsp.focus({{ window = {json.dumps(address)} }})") == "ok"
            or hyprctl("dispatch", "focuswindow", address) == "ok")


if __name__ == "__main__":
    args = sys.argv[1:] + [""] * (3 - len(sys.argv[1:]))
    target = resolve(args[0], hypr_list("clients"), args[1] or "claude", args[2]) if len(sys.argv) in (2, 4) else None
    sys.exit(0 if target and focus(target) else 1)

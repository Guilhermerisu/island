#!/usr/bin/env python3
"""Prints the name of the app receiving the screen share: the PipeWire node
the portal's video stream is linked to (pw-dump), or nothing. With --active,
prints 1 while the portal has a screen-share stream, else 0."""
import json
import subprocess
import sys

try:
    objects = json.loads(subprocess.run(["pw-dump"], capture_output=True, text=True, timeout=5).stdout or "[]")
except (OSError, ValueError, subprocess.SubprocessError):
    objects = []
nodes = {o["id"]: (o.get("info") or {}).get("props") or {} for o in objects if o.get("type") == "PipeWire:Interface:Node"}
sources = [i for i, p in nodes.items()
           if p.get("media.class") == "Video/Source"
           # Hyprland's portal names its streams xdph-streaming-…, wlroots' xdpw-…
           and (str(p.get("node.name", "")).startswith(("xdph", "xdpw")) or "portal" in str(p.get("application.name", "")).lower())]
if "--active" in sys.argv:
    print(1 if sources else 0)
    sys.exit(0)
names = []
for o in objects:
    if o.get("type") != "PipeWire:Interface:Link":
        continue
    info = o.get("info") or {}
    if info.get("output-node-id") in sources:
        p = nodes.get(info.get("input-node-id"), {})
        name = p.get("application.name") or p.get("application.process.binary") or p.get("node.name")
        if name and name not in names:
            names.append(name)
print(", ".join(names))

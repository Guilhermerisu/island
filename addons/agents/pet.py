#!/usr/bin/env python3
"""Find Codex's mascot, the pet picked in Codex or the ChatGPT desktop app.

Prints one JSON line: {"id", "source", "cols", "rows"}, `source` the file://
URL of the pet's spritesheet (192 × 208 pixel cells, `cols` × `rows` of
them), or nothing when no pet can be found, and the addon then keeps its
built-in mascot.

The pet is the one picked in Codex's own state (~/.codex), "codex" if none.
Its sheet is a custom pet's in ~/.codex/pets/<id>/, or one shipped inside the
installed ChatGPT desktop app, read out of its app.asar (nothing's
downloaded) into a cache beside the island's.
"""
import json
import os
from pathlib import Path
import re
import struct
import sys

CELL_W, CELL_H = 192, 208
SHEET = re.compile(r"^(?P<id>.+)-spritesheet-v(?P<version>\d+)(?:\.[0-9a-f]+)?\.webp$")
APP_DIRS = ("/usr/lib/chatgpt", "/opt/chatgpt", "/opt/ChatGPT", "/usr/lib/codex", "/opt/codex")
SELECTION_KEYS = ("pet-selection", "selected-pet", "selected-avatar", "avatar-selection")
MAX_SHEET = 8 << 20


def codex_home():
    return Path(os.environ.get("CODEX_HOME") or Path.home() / ".codex")


def selected_pet():
    try:
        state = json.loads((codex_home() / ".codex-global-state.json").read_text())
    except (OSError, ValueError):
        return "codex"
    found = []

    def walk(node, key=""):
        if isinstance(node, dict):
            for k, v in node.items():
                # A selection per account is a dict under the key.
                walk(v, key if any(s in key for s in SELECTION_KEYS) else k.lower())
        elif isinstance(node, str) and node and any(s in key for s in SELECTION_KEYS):
            found.append(node)
        elif isinstance(node, list):
            for v in node:
                walk(v, key)

    walk(state)
    return found[-1] if found else "codex"


def webp_size(data):
    if data[:4] != b"RIFF" or data[8:12] != b"WEBP":
        return None
    kind = data[12:16]
    if kind == b"VP8L":
        bits = struct.unpack("<I", data[21:25])[0]
        return (bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1
    if kind == b"VP8X":
        return int.from_bytes(data[24:27], "little") + 1, int.from_bytes(data[27:30], "little") + 1
    if kind == b"VP8 ":
        return struct.unpack("<HH", data[26:30])[0] & 0x3FFF, struct.unpack("<HH", data[28:32])[1] & 0x3FFF
    return None


def custom_sheet(pet):
    folder = codex_home() / "pets" / pet
    if not re.fullmatch(r"[\w.-]+", pet) or not folder.is_dir():
        return None
    names = []
    for manifest in ("pet.json", "avatar.json"):
        try:
            data = json.loads((folder / manifest).read_text())
            names += [str(data[k]) for k in ("spritesheet", "spritesheetPath", "spritesheet_path") if k in data]
        except (OSError, ValueError, TypeError):
            continue
    names += [p.name for p in sorted(folder.glob("*.webp")) + sorted(folder.glob("*.png"))]
    for name in names:
        path = (folder / name).resolve()
        # The sheet stays inside the pet's folder.
        if folder.resolve() in path.parents and path.is_file() and path.stat().st_size <= MAX_SHEET:
            return path
    return None


def asar_sheet(archive, pet):
    """The newest `<pet>-spritesheet-v*.webp` in an app.asar: (name, bytes)."""
    with open(archive, "rb") as f:
        head = f.read(16)
        pickle, length = struct.unpack("<II", head[4:8] + head[12:16])
        header = json.loads(f.read(length))
        base = 8 + pickle
        node = header.get("files", {})
        for part in ("webview", "assets"):
            node = node.get(part, {}).get("files", {})
        best = None
        for name, meta in node.items():
            m = SHEET.match(name)
            if m and m["id"] == pet and "offset" in meta and (best is None or int(m["version"]) > best[0]):
                best = (int(m["version"]), name, meta)
        if not best:
            return None
        f.seek(base + int(best[2]["offset"]))
        return best[1], f.read(min(int(best[2]["size"]), MAX_SHEET))


def app_archives():
    seen = set()
    dirs = [*APP_DIRS, *(str(p) for p in Path("/usr/lib").glob("*chatgpt*")), *(str(p) for p in Path("/opt").glob("*[cC]hat[gG][pP][tT]*"))]
    for root in dirs:
        archive = Path(root) / "resources" / "app.asar"
        if archive.is_file() and archive not in seen:
            seen.add(archive)
            yield archive


def cache_dir():
    root = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache")
    return root / "guilhermerisu.island" / "pet"


def find(pet):
    path = custom_sheet(pet)
    if path:
        return path, path.read_bytes()
    for archive in app_archives():
        try:
            found = asar_sheet(archive, pet)
        except (OSError, ValueError, struct.error, KeyError):
            continue
        if found:
            name, data = found
            target = cache_dir() / name
            if not target.exists() or target.stat().st_size != len(data):
                target.parent.mkdir(parents=True, mode=0o700, exist_ok=True)
                partial = target.with_suffix(".part")
                partial.write_bytes(data)
                partial.replace(target)
            return target, data
    return None


def main():
    pet = selected_pet()
    # The pet picked may not ship with the app (an older one, say): Codex's own.
    found = find(pet) or (find("codex") if pet != "codex" else None)
    if not found:
        return
    path, data = found
    size = webp_size(data)
    cols, rows = (size[0] // CELL_W, size[1] // CELL_H) if size else (0, 0)
    if cols < 1 or rows < 9:
        return
    print(json.dumps({"id": pet, "source": path.resolve().as_uri(), "cols": cols, "rows": rows}), flush=True)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:  # the built-in mascot stays when anything's off
        print(f"pet.py: {error}", file=sys.stderr)

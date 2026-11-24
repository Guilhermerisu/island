"""Reading files out of an Electron app's app.asar, and keeping what's read in
the island's cache. Shared by clawd.py and pet.py."""
import json
import os
from pathlib import Path
import struct


class Asar:
    """An open app.asar: `files` its header's tree, `read(meta)` a file's bytes."""

    def __init__(self, path):
        self.file = open(path, "rb")
        try:
            head = self.file.read(16)
            pickle, length = struct.unpack("<II", head[4:8] + head[12:16])
            self.files = json.loads(self.file.read(length))
            self.base = 8 + pickle
        except Exception:
            self.file.close()
            raise

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.file.close()

    def walk(self, node=None, prefix=""):
        """Every packed file's path and header entry (unpacked ones have no offset)."""
        for name, meta in ((self.files if node is None else node).get("files") or {}).items():
            path = f"{prefix}/{name}"
            if "files" in meta:
                yield from self.walk(meta, path)
            elif "offset" in meta:
                yield path, meta

    def read(self, meta):
        self.file.seek(self.base + int(meta["offset"]))
        return self.file.read(int(meta["size"]))


def cache_dir(name):
    root = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache")
    return root / "guilhermerisu.island" / name


def cache(target, data):
    """Writes `data` to `target` whole (through a .part file) unless it's there."""
    if target.exists() and target.stat().st_size == len(data):
        return target
    target.parent.mkdir(parents=True, mode=0o700, exist_ok=True)
    partial = target.with_name(target.name + ".part")
    partial.write_bytes(data)
    partial.replace(target)
    return target

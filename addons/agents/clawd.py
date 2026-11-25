#!/usr/bin/env python3
"""Find Claude's mascot, Clawd, as Anthropic animates it.

The Claude desktop app, if it's installed, ships Clawd's sprites (the ones its
Clawd Quest game plays) inside its app.asar. This reads them from there, paints
the animations the island uses into one spritesheet (a row each, every frame in
a cell of the same size, Clawd's feet at the same spot in all of them) in a
cache beside the island's, and prints one JSON line:

  {"source", "cellW", "cellH", "cols", "rows": [animation, ...], "body": [x0, y0, x1, y1]}

`source` is the sheet's file:// URL, `rows` the animations in the order of
its rows, and `body` the box his standing body fills in a cell. It prints nothing when the app or the sprites can't be found, and the
addon then keeps its built-in Clawd. Nothing is downloaded.
"""
import json
from pathlib import Path
import re
import struct
import sys
import zlib

from appasar import Asar, cache, cache_dir

# The animations in the sheet's row order.
ANIMATIONS = ("Thinking", "Laptop", "LookingAround", "Swaying", "Lightbulb", "Waving", "DancingHappy")
APP_DIRS = ("~/.local/opt/claude-desktop/usr/lib/claude-desktop", "/usr/lib/claude-desktop", "/opt/Claude",
            "/opt/claude-desktop", "/usr/lib/claude", "/opt/claude")
ENGINE = re.compile(r"^/?\.vite/renderer/[^/]+/assets/clawdQuestEngine-[\w-]+\.js$")
MAX_SOURCE = 4 << 20


def archives():
    for root in APP_DIRS:
        archive = Path(root).expanduser() / "resources" / "app.asar"
        if archive.is_file():
            yield archive


def engine_source(archive):
    with Asar(archive) as asar:
        for path, meta in asar.walk():
            if ENGINE.match(path) and int(meta["size"]) <= MAX_SOURCE:
                return asar.read(meta).decode("utf-8", "replace"), path
    return None


def sprite_table(source):
    """The `{Name:{cat,w,h,fps,palette,base,deltas,a0}}` table, as JSON."""
    start = source.find("{BreakDancing:{")
    if start < 0:
        return None
    depth, i, quote = 0, start, None
    while i < len(source):
        c = source[i]
        if quote:
            if c == "\\":
                i += 1
            elif c == quote:
                quote = None
        elif c in "\"'`":
            quote = c
        elif c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                break
        i += 1
    text = source[start:i + 1]
    # JavaScript's literal as JSON: the deltas written as "...".split("x"), its
    # keys quoted, `!0` and `!1` as booleans.
    text = re.sub(r'"((?:[^"\\]|\\.)*)"\.split\("(.)"\)', lambda m: json.dumps(m[1].split(m[2])), text)
    text = re.sub(r'([{,])([A-Za-z_][\w]*):', r'\1"\2":', text)
    text = re.sub(r"!0\b", "true", text)
    text = re.sub(r"!1\b", "false", text)
    return json.loads(text)


def frames(sprite):
    """Each frame of a sprite as a list of palette indexes (255: clear)."""
    cur = [255 if ch == "." else int(ch, 36) for ch in sprite["base"]]
    out = [list(cur)]
    for delta in sprite["deltas"]:
        if delta:
            for change in delta.split(","):
                cur[int(change[:-1], 36)] = 255 if change[-1] == "." else int(change[-1], 36)
        out.append(list(cur))
    return out


def anchor(sprite):
    box = sprite.get("a0") or [0, 0, 0, 0]
    if box[2] <= 0:
        box = [0, 0, sprite["w"], sprite["h"]]
    return round(box[0] + box[2] / 2), box[1] + box[3]


def png(width, height, rgba):
    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)
    raw = b"".join(b"\x00" + bytes(rgba[y * width * 4:(y + 1) * width * 4]) for y in range(height))
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def build(table):
    sprites = [table[name] for name in ANIMATIONS]
    anchors = [anchor(s) for s in sprites]
    # Room around the common anchor for the widest and tallest of them.
    left = max(a[0] for a in anchors)
    right = max(s["w"] - a[0] for s, a in zip(sprites, anchors))
    above = max(a[1] for a in anchors)
    below = max(s["h"] - a[1] for s, a in zip(sprites, anchors))
    cell_w, cell_h = left + right, above + below
    cols = max(len(frames(s)) for s in sprites)
    width, height = cols * cell_w, len(sprites) * cell_h
    pixels = bytearray(width * height * 4)
    for row, (sprite, (ax, ay)) in enumerate(zip(sprites, anchors)):
        colors = [tuple(int(c[i:i + 2], 16) for i in (1, 3, 5)) for c in sprite["palette"]]
        for col, frame in enumerate(frames(sprite)):
            ox, oy = col * cell_w + left - ax, row * cell_h + above - ay
            for index, value in enumerate(frame):
                if value == 255:
                    continue
                x, y = ox + index % sprite["w"], oy + index // sprite["w"]
                at = (y * width + x) * 4
                pixels[at:at + 4] = bytes((*colors[value], 255))
    # Where his body stands in a cell (the standing frame's pixels), so he can
    # be centered by it rather than by the room the bubbles and props need.
    stand = sprites[0]
    ax, ay = anchors[0]
    xs = [i % stand["w"] for i, v in enumerate(frames(stand)[0]) if v != 255]
    ys = [i // stand["w"] for i, v in enumerate(frames(stand)[0]) if v != 255]
    body = [left - ax + min(xs), above - ay + min(ys), left - ax + max(xs) + 1, above - ay + max(ys) + 1]
    return png(width, height, pixels), cell_w, cell_h, cols, body


def main():
    for archive in archives():
        try:
            found = engine_source(archive)
        except (OSError, ValueError, struct.error, KeyError):
            continue
        if not found:
            continue
        # Named for the engine file, so a newer app's sprites make a new sheet;
        # one already painted is reused as it is.
        stem = re.sub(r"\W+", "-", Path(found[1]).stem)
        target, line = cache_dir("clawd") / (stem + ".png"), cache_dir("clawd") / (stem + ".json")
        if target.is_file():
            try:
                print(json.dumps(json.loads(line.read_text())), flush=True)
                return
            except (OSError, ValueError):
                pass  # its line's missing: painted again below
        try:
            table = sprite_table(found[0])
        except ValueError:
            continue
        if not table or any(name not in table for name in ANIMATIONS):
            continue
        sheet, cell_w, cell_h, cols, body = build(table)
        cache(target, sheet)
        out = json.dumps({"source": target.resolve().as_uri(), "cellW": cell_w, "cellH": cell_h,
                          "cols": cols, "rows": list(ANIMATIONS), "body": body})
        cache(line, out.encode())
        print(out, flush=True)
        return


if __name__ == "__main__":
    try:
        main()
    except Exception as error:  # the built-in Clawd stays when anything's off
        print(f"clawd.py: {error}", file=sys.stderr)

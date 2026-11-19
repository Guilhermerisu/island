#!/usr/bin/env python3
"""Relay a small, fixed set of Island actions to the Chromium extension."""

import fcntl
import json
import os
from pathlib import Path
import select
import socket
import struct
import sys


ORIGIN = "chrome-extension://dlfjjbecgohnomjcmcaeolpeeiiogick/"
HOST = "com.omarchy.island_youtube"
ACTIONS = {"status", "next", "previous", "shuffle", "open"}
MAX_BYTES = 8192
TIMEOUT = 2
HEADER = struct.Struct("=I")


def encode(message):
    return json.dumps(message, ensure_ascii=False).encode()


def read_exact(length):
    result = bytearray()
    while len(result) < length:
        if not select.select([0], [], [], TIMEOUT)[0]:
            raise TimeoutError("Extension did not reply")
        data = os.read(0, length - len(result))
        if not data:
            raise EOFError
        result.extend(data)
    return result


def exchange(request):
    action, title = request.get("action"), request.get("title")
    if not isinstance(action, str) or action not in ACTIONS or not isinstance(title, str) or not title.strip():
        return {}
    message = encode({"action": action, "title": title})
    sys.stdout.buffer.write(HEADER.pack(len(message)) + message)
    sys.stdout.buffer.flush()
    size = HEADER.unpack(read_exact(HEADER.size))[0]
    if size > MAX_BYTES:
        raise ValueError("Oversized extension response")
    result = json.loads(read_exact(size))
    return result if isinstance(result, dict) else {}


def serve(path):
    with path.with_suffix(".lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        path.unlink(missing_ok=True)
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_SEQPACKET) as server:
                server.bind(str(path))
                server.listen(4)
                while True:
                    ready, _, _ = select.select([server, 0], [], [])
                    if 0 in ready:
                        return
                    client, _ = server.accept()
                    with client:
                        client.settimeout(TIMEOUT)
                        try:
                            request = json.loads(client.recv(MAX_BYTES))
                            if not isinstance(request, dict):
                                continue
                        except (OSError, ValueError):
                            continue
                        result = exchange(request)
                        try:
                            client.sendall(encode(result))
                        except OSError:
                            pass
        finally:
            path.unlink(missing_ok=True)


def request(path, action, title):
    message = encode({"action": action, "title": title})
    if len(message) > MAX_BYTES:
        return {}
    with socket.socket(socket.AF_UNIX, socket.SOCK_SEQPACKET) as client:
        client.settimeout(TIMEOUT + 0.5)
        client.connect(str(path))
        client.sendall(message)
        return json.loads(client.recv(MAX_BYTES))


def install_host():
    config = Path(os.environ.get("XDG_CONFIG_HOME") or (Path.home() / ".config"))
    directory = config / "chromium" / "NativeMessagingHosts"
    directory.mkdir(parents=True, exist_ok=True)
    manifest = directory / (HOST + ".json")
    manifest.write_text(json.dumps({
        "name": HOST, "description": "Omarchy Island YouTube bridge",
        "path": str(Path(__file__).resolve()), "type": "stdio",
        "allowed_origins": [ORIGIN],
    }, indent=2) + "\n")
    print(manifest)


if __name__ == "__main__":
    os.umask(0o077)
    args = sys.argv[1:]
    if args == ["install-host"]:
        install_host()
    else:
        path = Path(os.environ["XDG_RUNTIME_DIR"]) / "omarchy-island-youtube.sock"
        if args and args[0] == ORIGIN:
            try:
                serve(path)
            except (OSError, EOFError, ValueError):
                pass
        elif len(args) == 2 and args[0] in ACTIONS:
            try:
                print(json.dumps(request(path, *args)))
            except (OSError, ValueError):
                print("{}")

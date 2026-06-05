"""Desktop notifications for kanata persistent-layer changes.

Connects to kanata's localhost TCP server and listens for the
{"LayerChange":{"new":"..."}} events it broadcasts. Only the persistent
layers selected through the ``` switcher (base / qwerty / gaming / basic)
trigger a notification; the momentary while-held layers (navigation, symbols,
numpad, funpad, layers-switcher) are ignored so the notification doesn't flicker
every time a layer key is held.

Configuration via environment:
  KANATA_PORT   TCP port kanata listens on (default 5829)
  KANATA_HOST   host to connect to            (default 127.0.0.1)
  NOTIFY_SEND   path to the notify-send binary (default "notify-send")
"""

import json
import os
import socket
import subprocess
import time

HOST = os.environ.get("KANATA_HOST", "127.0.0.1")
PORT = int(os.environ.get("KANATA_PORT", "5829"))
NOTIFY_SEND = os.environ.get("NOTIFY_SEND", "notify-send")

# Persistent layers -> human-friendly label shown in the notification.
# Any layer name not in this map is treated as momentary and ignored.
LAYERS = {
    "base": "Ergo-L",
    "qwerty": "Qwerty",
    "gaming": "Gaming",
    "ergol-no-mods": "Ergo-L Pass Through (no mods)",
}

RECONNECT_DELAY = 2.0


def notify(label):
    """Show a keyboard-layer notification."""
    subprocess.run(
        [
            NOTIFY_SEND,
            "--app-name=kanata",
            "--icon=input-keyboard",
            "--expire-time=1500",
            "Keyboard layer",
            label,
        ],
        check=False,
    )


def handle_message(text, state):
    """Parse one JSON line and notify on a real persistent-layer change."""
    try:
        msg = json.loads(text)
    except ValueError:
        return

    # Seed the current layer from the request we send on connect, silently,
    # so we don't fire a notification for the layer that was already active.
    seed = msg.get("CurrentLayerName")
    if seed:
        name = seed.get("name")
        if name in LAYERS:
            state["current"] = name
        return

    change = msg.get("LayerChange")
    if not change:
        return

    name = change.get("new")
    if name not in LAYERS or name == state.get("current"):
        return

    state["current"] = name
    notify(LAYERS[name])


def serve_connection(sock, state):
    """Read newline-delimited JSON from kanata until the socket closes."""
    sock.sendall(b'{"RequestCurrentLayerName":{}}\n')
    buf = b""
    while True:
        data = sock.recv(4096)
        if not data:
            return
        buf += data
        while b"\n" in buf:
            raw, buf = buf.split(b"\n", 1)
            text = raw.decode("utf-8", "replace").strip()
            if text:
                handle_message(text, state)


def main():
    state = {"current": None}
    while True:
        try:
            with socket.create_connection((HOST, PORT), timeout=5) as sock:
                sock.settimeout(None)
                serve_connection(sock, state)
        except OSError:
            # kanata not up yet, or the connection dropped (e.g. live reload).
            pass
        # Forget the cached layer so the next connection re-seeds it.
        state["current"] = None
        time.sleep(RECONNECT_DELAY)


if __name__ == "__main__":
    main()

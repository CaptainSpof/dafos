"""dafos OpenDeck plugin: keys whose image follows a Home Assistant entity.

One action, me.daf.dafos.hakey. Its settings (written by
~/.config/opendeck/dafos-gen-profiles.py) are:

  entity   HA entity whose state picks the image (optional)
  images   {state: image path}; "*" is the fallback
  rules    [[entity, state, image], ...]: first match wins, before `images`
           (keys that combine several entities)
  profile  profile to switch to on key down (optional)
  service  {"domain", "service", "data"} called on key down (optional)
  services [service, ...]; a service with "when": [entity, state] only runs
           while that entity is in that state
  clock    true: the key shows dafbox's local time and date instead

The plugin reads the HA server and token from the Home Assistant plugin's
global settings (settings/de.perdoctus.streamdeck.homeassistant.sdPlugin.json)
and polls the REST API: a handful of keys, a few seconds of latency is fine.
"""

import asyncio
import base64
import time
import json
import os
import sys
import urllib.request

import websockets

CFG = os.path.expanduser("~/.config/opendeck")
HA_SETTINGS = f"{CFG}/settings/de.perdoctus.streamdeck.homeassistant.sdPlugin.json"
POLL_SECONDS = 3


def args():
    a = sys.argv[1:]
    return {a[i].lstrip("-"): a[i + 1] for i in range(0, len(a) - 1, 2)}


def ha():
    with open(HA_SETTINGS) as f:
        s = json.load(f)
    return s["serverUrl"].rstrip("/"), s["accessToken"]


def ha_request(path, body=None):
    url, token = ha()
    req = urllib.request.Request(
        url + path,
        data=json.dumps(body).encode() if body is not None else None,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
    )
    with urllib.request.urlopen(req, timeout=10) as r:
        return json.load(r)


def pick(images, state):
    return images.get(state) or images.get("*")


def services(settings):
    return ([settings["service"]] if settings.get("service") else []) + settings.get(
        "services", []
    )


DAYS = ["LUN", "MAR", "MER", "JEU", "VEN", "SAM", "DIM"]
MONTHS = ["JANV", "FÉVR", "MARS", "AVR", "MAI", "JUIN", "JUIL", "AOÛT", "SEPT", "OCT", "NOV", "DÉC"]


def clock_svg(t=None):
    t = time.localtime(t)
    date = f"{DAYS[t.tm_wday]} {t.tm_mday} {MONTHS[t.tm_mon - 1]}"
    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 144 144">
<rect width="144" height="144" rx="16" fill="#1a1410"/>
<rect x="5" y="5" width="134" height="134" rx="13" fill="#c8251c"/>
<text x="72" y="82" text-anchor="middle" font-family="Liberation Sans, sans-serif" font-weight="bold" font-size="46" fill="#fbefd9" stroke="#1a1410" stroke-width="3" paint-order="stroke">{t.tm_hour:02d}:{t.tm_min:02d}</text>
<text x="72" y="114" text-anchor="middle" font-family="Liberation Sans, sans-serif" font-weight="bold" font-size="17" fill="#fbefd9">{date}</text>
</svg>"""
    return "data:image/svg+xml;base64," + base64.b64encode(svg.encode()).decode()


def data_uri(path):
    ext = os.path.splitext(path)[1].lstrip(".").replace("svg", "svg+xml") or "png"
    with open(path, "rb") as f:
        return f"data:image/{ext};base64," + base64.b64encode(f.read()).decode()


class Plugin:
    def __init__(self, ws, uuid):
        self.ws = ws
        self.uuid = uuid
        self.keys = {}  # context -> {"settings", "device", "image"}
        self.states = {}  # entity -> last polled state

    async def send(self, msg):
        await self.ws.send(json.dumps(msg))

    async def show(self, context, path):
        key = self.keys.get(context)
        if not key:
            return
        if not path or path == key.get("image"):
            return
        inline = path.startswith("data:")
        if inline or os.path.exists(path):
            key["image"] = path
            await self.send(
                {
                    "event": "setImage",
                    "context": context,
                    "payload": {"image": path if inline else data_uri(path)},
                }
            )

    def entities(self):
        out = set()
        for k in self.keys.values():
            st = k["settings"]
            out.add(st.get("entity"))
            out.update(r[0] for r in st.get("rules", []))
            out.update(svc["when"][0] for svc in services(st) if svc.get("when"))
        return out - {None, ""}

    def image_for(self, settings):
        if settings.get("clock"):
            return clock_svg()
        for entity, state, image in settings.get("rules", []):
            if self.states.get(entity) == state:
                return image
        return pick(
            settings.get("images", {}), self.states.get(settings.get("entity"), "*")
        )

    async def refresh(self):
        for entity in self.entities():
            try:
                self.states[entity] = (
                    await asyncio.to_thread(ha_request, f"/api/states/{entity}")
                )["state"]
            except (
                OSError,
                ValueError,
                KeyError,
            ) as e:  # HA down or entity missing: keep the fallback image
                self.states.pop(entity, None)
                print(f"dafos: {entity}: {e}", file=sys.stderr)
        for context, key in list(self.keys.items()):
            await self.show(context, self.image_for(key["settings"]))

    async def poll(self):
        while True:
            await self.refresh()
            await asyncio.sleep(POLL_SECONDS)

    async def key_down(self, context):
        key = self.keys.get(context)
        if not key:
            return
        s = key["settings"]
        for svc in services(s):
            when = svc.get("when")
            if when and self.states.get(when[0]) != when[1]:
                continue
            try:
                await asyncio.to_thread(
                    ha_request,
                    f"/api/services/{svc['domain']}/{svc['service']}",
                    svc.get("data", {}),
                )
            except (OSError, ValueError, KeyError) as e:
                print(f"dafos: service {svc}: {e}", file=sys.stderr)
                await self.send({"event": "showAlert", "context": context})
        if services(s):
            await self.refresh()
        if s.get("profile"):
            await self.send(
                {
                    "event": "switchProfile",
                    "device": key["device"],
                    "profile": s["profile"],
                }
            )

    async def handle(self, msg):
        event, context = msg.get("event"), msg.get("context")
        if event == "willAppear":
            self.keys[context] = {
                "settings": msg["payload"].get("settings", {}),
                "device": msg.get("device"),
                "image": None,
            }
            # Fallback image right away, the poll fills in the real state.
            await self.show(context, self.image_for(self.keys[context]["settings"]))
        elif event == "willDisappear":
            self.keys.pop(context, None)
        elif event == "didReceiveSettings" and context in self.keys:
            self.keys[context]["settings"] = msg["payload"].get("settings", {})
            self.keys[context]["image"] = None
        elif event == "keyDown":
            await self.key_down(context)


async def main():
    a = args()
    async with websockets.connect(f"ws://127.0.0.1:{a['port']}", max_size=None) as ws:
        await ws.send(
            json.dumps({"event": a["registerEvent"], "uuid": a["pluginUUID"]})
        )
        plugin = Plugin(ws, a["pluginUUID"])
        poller = asyncio.create_task(plugin.poll())
        try:
            async for raw in ws:
                await plugin.handle(json.loads(raw))
        finally:
            poller.cancel()


if __name__ == "__main__":
    asyncio.run(main())

#!/usr/bin/env python3
"""Legacy local mock API inherited from the pre-PixelLegends prototype.
DEVELOPMENT ONLY; it is not connected to the current guest-first UI.

The mock predates the PixelLegends 5v5 MOBA pivot. Its shooter-era identity,
room and matchmaking endpoints are retained as historical scaffolding only; do
not present them as working PixelLegends services or expose this server.

    python3 tools/mock_server.py
    # then, in the game: Settings ▸ Developer ▸ Backend base URL
    #   http://127.0.0.1:8787                    (desktop)
    #   http://<your-laptop-ip>:8787             (a phone on the same Wi-Fi)

  ⚠  IT VERIFIES NOTHING. `POST /v1/auth/google` accepts any string as an
     `id_token` and invents an account for it. That is the whole point — and it
     is exactly why this file must never run anywhere a real player can reach.
     It binds to 0.0.0.0 so a phone can reach it; keep it on a trusted network
     and stop it when you are done.

Endpoints
    GET    /health
    POST   /v1/auth/google          POST /v1/auth/guest
    GET    /v1/profile              PUT  /v1/profile
    GET    /v1/friends              POST /v1/friends/requests
    POST   /v1/friends/<uid>/invite
    GET    /v1/rooms                POST /v1/rooms
    POST   /v1/rooms/<code>/join
    POST   /v1/matchmaking/tickets
    GET    /v1/matchmaking/tickets/<id>
    POST   /v1/matchmaking/tickets/<id>/accept
    POST   /v1/matchmaking/tickets/<id>/decline
    DELETE /v1/matchmaking/tickets/<id>
"""

from __future__ import annotations

import argparse
import hashlib
import json
import random
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

STATE_PATH = Path(__file__).resolve().parent / ".mock_state.json"

WARNING = """
────────────────────────────────────────────────────────────────────────────
  PixelLegends legacy mock backend — DEVELOPMENT ONLY
  It accepts any id_token and trusts every request. Never expose this.
  Not connected to the current client UI; do not use for matches
────────────────────────────────────────────────────────────────────────────
"""

CALLSIGN_PREFIX = ["Vex", "Kilo", "Ozone", "Rift", "Halcyon", "Draco", "Zenith", "Mako"]
CALLSIGN_SUFFIX = ["", "_77", "-IR", "X", "2K", "_09", "Prime", "Hz"]
SAMPLE_FRIENDS = [
    ("Nova_Cipher", 42, 2140, "online"),
    ("Ronin.IR", 28, 1180, "online"),
    ("VantaFox", 61, 3320, "in_match"),
    ("Kestrel", 15, 420, "online"),
    ("M_Specter", 7, 150, "offline"),
]
MAPS = ["foundry", "meridian", "switchyard", "atrium"]

_LOCK = threading.Lock()


def now() -> int:
    return int(time.time())


# --------------------------------------------------------------------- state

def load_state() -> dict:
    if STATE_PATH.exists():
        try:
            return json.loads(STATE_PATH.read_text(encoding="utf-8"))
        except (ValueError, OSError):
            pass
    return {"profiles": {}, "tickets": {}, "rooms": {}}


def save_state(state: dict) -> None:
    try:
        STATE_PATH.write_text(json.dumps(state, indent=2), encoding="utf-8")
    except OSError:
        pass


def new_profile(uid: str, callsign: str, email: str = "") -> dict:
    return {
        "uid": uid,
        "display_name": callsign,
        "email": email,
        "avatar_url": "",
        "provider": 1,
        "region": 0,
        "clan_tag": "",
        "level": 1,
        "xp": 0,
        "rank_points": 0,
        "credits": 2500,
        "cores": 120,
        "matches_played": 0,
        "matches_won": 0,
        "kills": 0,
        "deaths": 0,
        "headshots": 0,
        "damage_dealt": 0,
        "longest_win_streak": 0,
        "current_win_streak": 0,
        "playtime_seconds": 0,
        "is_guest": True,
        "created_at": now(),
        "last_login_at": now(),
        "tutorial_complete": False,
        "accepted_terms_version": 1,
    }


def random_callsign() -> str:
    return f"{random.choice(CALLSIGN_PREFIX)}{random.choice(CALLSIGN_SUFFIX)}{random.randint(10, 99)}"


# ------------------------------------------------------------------ handlers

def handle_health(_body: dict) -> tuple[int, dict]:
    return 200, {
        "ok": True,
        "service": "hexora-mock",
        "time": now(),
        "warning": "development only — verifies nothing",
    }


def handle_google_auth(body: dict, state: dict) -> tuple[int, dict]:
    token = str(body.get("id_token", ""))
    if not token:
        return 400, {"error": "missing_id_token"}
    # A REAL server would verify the signature against Google's JWKS here, plus
    # aud/iss/exp, and reject anything that fails. This one hashes it and makes
    # up an account, which is fine on a laptop and catastrophic in production.
    digest = hashlib.sha256(token.encode("utf-8")).hexdigest()[:16]
    uid = f"google-{digest}"
    with _LOCK:
        profile = state["profiles"].get(uid)
        if profile is None:
            profile = new_profile(uid, str(body.get("callsign") or random_callsign()),
                                  f"{digest[:8]}@example.com")
            profile["is_guest"] = False
            state["profiles"][uid] = profile
            save_state(state)
        else:
            profile["last_login_at"] = now()
    return 200, {**profile, "access_token": f"mock-session-{digest}"}


def handle_guest_auth(body: dict, state: dict) -> tuple[int, dict]:
    device = str(body.get("device_id") or random_callsign())
    uid = "guest-" + hashlib.sha256(device.encode("utf-8")).hexdigest()[:12]
    with _LOCK:
        profile = state["profiles"].get(uid)
        if profile is None:
            profile = new_profile(uid, str(body.get("callsign") or random_callsign()))
            state["profiles"][uid] = profile
            save_state(state)
    return 200, {**profile, "access_token": f"mock-session-{uid}"}


def handle_friends(_body: dict, _state: dict) -> tuple[int, dict]:
    friends = [
        {
            "uid": "mock-" + name.lower(),
            "name": name,
            "level": level,
            "rank_points": rp,
            "status": status,
            "presence": status,
            "last_seen": now() - random.randint(60, 7200),
            "sample": True,
        }
        for name, level, rp, status in SAMPLE_FRIENDS
    ]
    return 200, {"friends": friends, "requests": []}


def handle_rooms(_body: dict, _state: dict) -> tuple[int, dict]:
    modes = ["tdm", "snd", "ffa", "br30"]
    rooms = [
        {
            "code": f"MOCK{i:02d}",
            "name": f"Mock lobby {i}",
            "host_name": random_callsign(),
            "mode_id": modes[i % len(modes)],
            "map_id": MAPS[i % len(MAPS)],
            "region": 4,
            "visibility": 0,
            "state": 0,
            "transport": 3,
            "players": [],
            "max_players": 12,
            "squad_size": 1,
            "password_protected": i == 3,
            "ping_ms": random.randint(28, 140),
            "is_lan": False,
            "ranked": i % 2 == 0,
            "player_count_hint": random.randint(1, 10),
        }
        for i in range(4)
    ]
    return 200, {"rooms": rooms}


def handle_enqueue(body: dict, state: dict) -> tuple[int, dict]:
    modes = body.get("modes") or ["tdm"]
    ticket_id = "t" + hashlib.sha256(
        f"{now()}{random.random()}".encode("utf-8")).hexdigest()[:12]
    # Every mock ticket resolves in ~8 s so the ready check can be seen.
    lobby_size = 10 if modes[0] == "tdm" else 8
    players = [
        {"name": random_callsign(), "level": random.randint(3, 60),
         "is_local": False, "simulated": False, "ready": False}
        for _ in range(lobby_size - 1)
    ]
    with _LOCK:
        state["tickets"][ticket_id] = {
            "created_at": now(),
            "found_at": now() + 8,
            "modes": modes,
            "region": body.get("region", 4),
            "ranked": bool(body.get("ranked", False)),
            "players": players,
            "mode_id": modes[0],
            "map_id": random.choice(MAPS),
        }
        save_state(state)
    return 200, {"ticket_id": ticket_id, "estimated_wait": 8, "pool_size": 34}


def handle_ticket_poll(ticket_id: str, state: dict) -> tuple[int, dict]:
    ticket = state["tickets"].get(ticket_id)
    if ticket is None:
        return 404, {"error": "no_such_ticket"}
    if now() < ticket["found_at"]:
        elapsed = now() - ticket["created_at"]
        return 200, {
            "state": "searching",
            "elapsed": elapsed,
            "pool_size": 20 + elapsed * 3,
            "expanding": elapsed > 4,
        }
    return 200, {
        "state": "found",
        "lobby": {
            "mode_id": ticket["mode_id"],
            "map_id": ticket["map_id"],
            "region": ticket["region"],
            "ranked": ticket["ranked"],
            "transport": 3,
            "players": ticket["players"],
        },
    }


def handle_ticket_action(ticket_id: str, state: dict) -> tuple[int, dict]:
    with _LOCK:
        state["tickets"].pop(ticket_id, None)
        save_state(state)
    return 200, {"ok": True}


# ------------------------------------------------------------------- routing

def route(method: str, path: str, body: dict, state: dict) -> tuple[int, dict]:
    parts = [part for part in path.split("/") if part]
    if path == "/health":
        return handle_health(body)
    if parts[:2] == ["v1", "auth"]:
        if method != "POST":
            return 405, {"error": "method_not_allowed"}
        if parts[2] == "google":
            return handle_google_auth(body, state)
        if parts[2] == "guest":
            return handle_guest_auth(body, state)
    if parts[:2] == ["v1", "profile"]:
        if method == "GET":
            uid = str(body.get("__uid", ""))
            profile = state["profiles"].get(uid)
            return (200, profile) if profile else (404, {"error": "no_profile"})
        if method == "PUT":
            uid = str(body.get("uid", ""))
            if uid:
                with _LOCK:
                    state["profiles"][uid] = body
                    save_state(state)
            return 200, body
    if parts[:2] == ["v1", "friends"]:
        if method == "GET":
            return handle_friends(body, state)
        if method == "POST" and len(parts) >= 3:
            if parts[2] == "requests" and len(parts) == 3:
                return 200, {"ok": True, "requested": body.get("handle", "")}
            if len(parts) >= 4 and parts[3] == "invite":
                # A real server would push this to the friend's device; the mock
                # has nowhere to push it, so it just acknowledges.
                return 200, {"ok": True, "delivered": False,
                             "note": "no push transport in the mock server"}
    if parts[:2] == ["v1", "rooms"]:
        if method == "GET" and len(parts) == 2:
            return handle_rooms(body, state)
        if method == "POST" and len(parts) == 2:
            code = "MOCK" + hashlib.sha256(
                f"{now()}{random.random()}".encode("utf-8")).hexdigest()[:2].upper()
            return 200, {"code": code, **body, "address": "", "port": 0}
        if method == "POST" and len(parts) == 4 and parts[3] == "join":
            return 200, {"ok": True, "code": parts[2], "transport": 3}
    if parts[:3] == ["v1", "matchmaking", "tickets"]:
        if method == "POST" and len(parts) == 3:
            return handle_enqueue(body, state)
        if len(parts) == 4:
            if method == "GET":
                return handle_ticket_poll(parts[3], state)
            return handle_ticket_action(parts[3], state)
        if len(parts) == 5 and method == "POST":
            return handle_ticket_action(parts[3], state)
    return 404, {"error": "not_implemented", "path": path, "method": method}


# -------------------------------------------------------------------- server

class Handler(BaseHTTPRequestHandler):
    server_version = "HexoraMock/1.0"
    state: dict = {}

    def log_message(self, fmt: str, *args) -> None:
        print(f"  {self.address_string():<15} {fmt % args}")

    def _read_body(self) -> dict:
        length = int(self.headers.get("Content-Length") or 0)
        if length <= 0:
            return {}
        raw = self.rfile.read(length)
        try:
            parsed = json.loads(raw.decode("utf-8"))
            return parsed if isinstance(parsed, dict) else {}
        except (ValueError, UnicodeDecodeError):
            return {}

    def _respond(self, status: int, payload: dict | None) -> None:
        body = json.dumps(payload if payload is not None else {}).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        # The client runs on another origin (and, on a phone, another host), so
        # the debug server answers permissively. Never do this in production.
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.send_header("Access-Control-Allow-Methods", "GET,POST,PUT,DELETE,OPTIONS")
        self.end_headers()
        self.wfile.write(body)

    def _dispatch(self, method: str) -> None:
        parsed = urlparse(self.path)
        body = self._read_body()
        status, payload = route(method, parsed.path, body, type(self).state)
        self._respond(status, payload)

    def do_GET(self) -> None:
        self._dispatch("GET")

    def do_POST(self) -> None:
        self._dispatch("POST")

    def do_PUT(self) -> None:
        self._dispatch("PUT")

    def do_DELETE(self) -> None:
        self._dispatch("DELETE")

    def do_OPTIONS(self) -> None:
        self._respond(204, {})


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--port", type=int, default=8787)
    parser.add_argument("--host", default="0.0.0.0",
                        help="0.0.0.0 so a phone on the same Wi-Fi can reach it")
    parser.add_argument("--reset", action="store_true", help="forget saved profiles")
    args = parser.parse_args()

    if args.reset and STATE_PATH.exists():
        STATE_PATH.unlink()
        print(f"cleared {STATE_PATH.name}")

    Handler.state = load_state()
    random.seed()
    print(WARNING)
    print(f"  state file : {STATE_PATH}")
    print(f"  listening  : http://{args.host}:{args.port}  (Ctrl+C to stop)\n")
    server = ThreadingHTTPServer((args.host, args.port), Handler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nstopped")
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

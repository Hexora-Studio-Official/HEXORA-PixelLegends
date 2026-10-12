# Architecture

This document separates **what exists in this checkout** from the approved target architecture. A class, mode resource or API wrapper is not evidence that the corresponding gameplay/backend feature works.

## 1. Current repository shape

```text
Godot client (current)
├── UI                 src/ui/              screens, menu pages, components
├── Client services    src/autoload/        settings, auth, rooms, matchmaking, etc.
├── Shared data        src/core/            profiles, room/mode models, enums
├── Local networking   src/net/             UDP LAN discovery
└── Tools/docs         tools/, docs/         static checks, mock API, project notes

Not implemented yet
├── Match runtime      player/world/weapon/damage/bot/mode controllers and maps
├── Dedicated server   Linux headless match process and server bootstrap
└── Production backend API, account verification, persistence and deployment
```

Godot is targeted at 4.4+ using GDScript and the Mobile renderer. The checkout contains four UI `.tscn` screens and eight `GameMode` `.tres` resources. It contains no match scene, map scene, player controller, weapon/damage system, bot controller, production backend or dedicated-server target.

## 2. Existing module ownership

| Area | Current owner | Responsibility / boundary |
| --- | --- | --- |
| UI | `src/ui/` | Draws screens and pages; calls services rather than owning low-level sockets. |
| Global events | `src/autoload/event_bus.gd` | Typed lifecycle, settings, auth, room, queue and UI signals. |
| User preferences | `src/autoload/settings_service.gd` | Local `user://settings.cfg`; not authoritative gameplay configuration. |
| Localization and theme | `loc.gd`, `design.gd` | English/Persian text, RTL, runtime Theme and UI design tokens. |
| Input/audio | `controls.gd`, `audio_service.gd` | InputMap actions and client-side audio. Actions are registered, but no match controller consumes them yet. |
| Account/session | `auth_service.gd`, `session.gd` | Google/guest client flow and local profile/session files. Online identity is not production-ready without a verifying backend. |
| Friends/rooms/queue | `friends_service.gd`, `room_service.gd`, `matchmaking.gd` | Client orchestration. RoomService currently owns both local lobby transport and room UI-facing state. |
| HTTP | `api_client.gd` | Central HTTP transport and typed endpoint wrappers. It is not a backend implementation. |
| Shared models | `src/core/` | Data objects and ruleset metadata used by client code. `GameMode.to_rules()` is a data conversion, not a running rules engine. |
| LAN discovery | `src/net/lan_discovery.gd` | UDP beacon advertisement/listening; manual IP entry is the fallback. |

Autoload order is in `project.godot`. `EventBus.services_ready` is declared but currently has no emitter; the boot screen marks its service step complete during its own build. Do not make a new subsystem depend on that signal until its lifecycle is implemented and tested.

## 3. Approved authority and transport model

### Friends-only local play

The Wi-Fi/hotspot room is for friends playing offline and casually. It requires no internet/account and is always unranked. “Friends-only” is the intended use, not account-based identity enforcement: the current implementation trusts the shared local network and does not verify who a friend is. The room host may act as authority for this local experience, but neither the host's result nor client-supplied stats are suitable for ranked progression, purchases or other valuable account state. Current local room capacity is eight devices; that cap has not been benchmarked on target phones.

`RoomService` opens an ENet server in the `45720–45740` range. `LanDiscovery` sends a small UDP beacon on ports `45710/45711`; users can also enter an address and port manually. The beacon marker mismatch found during Stage 0 was corrected in Stage 1. It has only been statically reviewed in this environment; Godot and real-device verification are still required.

### Online competitive play (target, not implemented)

```text
Godot client ── HTTPS control API ──> backend (identity, profile, friends,
      │                               private lobby, matchmaking, assignment)
      └── ENet/UDP gameplay ─────────> dedicated headless Godot match server
                                             │
                                             └── validated result ──> persistence
```

The dedicated server must own authoritative movement validation, hits, damage, health, eliminations, scoring, respawns, mode state and match results. Clients send bounded inputs/requests; they never choose damage, rank points, currencies, inventory or winners. The API handles control-plane operations; real-time movement/gameplay must not be implemented as per-frame HTTP calls.

Keep the first online deployment simple: one backend service, one persistence choice and a small number of match-server processes on a Linux VPS. Do not add Kubernetes, a microservice fleet, a paid relay or multiple regions without measured need and owner approval. The match server should be separable from the API later.

**Stage 2 execution method:** add a server-specific main scene/bootstrap and a Linux headless export; run that server target without the client UI/GPU, with bind port, capacity and log settings provided by validated command-line options or an external config file. Wrap it in systemd only at the deployment stage. No server scene/export/command exists yet, so the exact command must be added and tested with the Stage 2 deliverable rather than copied from a guess.

## 4. Configuration ownership

| Configuration | Current / intended source | Notes |
| --- | --- | --- |
| User preferences (language, audio, graphics, controls) | `Settings` → `user://settings.cfg` | Device-local and editable by the player; never a source of competitive truth. |
| Mode defaults and tunable rules | `GameMode` resources in `src/core/game_modes/` | Presently descriptive data only. Server-side validation/consumption is future work. |
| BR squad selection | Future mode/playlist configuration | Approved options are Solo and squads of 2, 3 or 5. The current model has one `squad_size` value per resource and does not yet model all choices. |
| Hard Mode loot scarcity | Future server-owned loot configuration | Hard Mode is a BR variant with very scarce weapons/supplies, not an unarmed mode. Exact spawn rates are not yet approved or measured. |
| Server ports, capacity, logging | Future server config/command-line options | No server bootstrap or production configuration file exists yet. |
| Credentials/secrets | Environment or deployment secret store (future) | Never commit OAuth secrets, server tokens or database credentials. |

Before an online service is built, reconcile the currently local-only auth/profile logic with server authority. In particular, review the remote-profile adoption and token-persistence path in `src/autoload/auth_service.gd`; do not expose it as production authentication as-is.

## 5. Persistence: actual local files

| File | Owner | Contents |
| --- | --- | --- |
| `user://settings.cfg` | `Settings` | Local preference/configuration values. |
| `user://profile.json` | `Session` | Local `PlayerProfile` data. |
| `user://auth.cfg` | `Auth` | Local auth metadata/token fields; not a secure server-side credential store. |
| `user://friends.json` | `Friends` | Local friend cache. |

There is no production database or server persistence in this repository. The backend must become the source of truth for ranked profile values and match outcomes.

## 6. LAN room flow

```text
Host: Rooms.host_room()
  ├─ ENet room server on the host device
  └─ LanDiscovery serializes a bounded JSON beacon and broadcasts it

Joiner:
  ├─ optional UDP discovery → use packet-header sender address → ENet connect
  └─ manual IP + port entry → ENet connect

Host accepts a lobby hello and broadcasts a roster. This is a lobby transport,
not a match/gameplay implementation.
```

The beacon's `magic` marker is a JSON field. The decoder now checks that field after parsing the bounded packet. Automatic discovery must still be exercised under Godot on desktop and on Android hotspot/Wi-Fi; Android multicast/broadcast behaviour varies by device and network.

`RoomInfo.generate_code()` and the room password digest are convenience measures for the casual local room. They are not cryptographic credentials and must not be reused for internet invitation security.

## 7. Online API and mock server

`src/autoload/api_client.gd` defines client endpoints such as authentication, profiles, friends, rooms and matchmaking. There is no production server source or database in this checkout. `tools/mock_server.py` is a laptop development stub; it accepts arbitrary Google ID tokens, uses permissive CORS and returns sample data. It must never be internet-exposed or used to validate security.

Some online room paths are explicit placeholders (for example, `RoomService._join_online()` reports that the backend is not wired). A configured URL or successful mock response does not mean a production online game exists.

## 8. Validation status and known documentation gaps

- `tools/check_i18n.py`, `tools/check_refs.py` and `gdlint` are static checks. `check_refs.py` uses heuristics, not the Godot parser/runtime.
- A GitHub Actions workflow is configured to run the static checks and verify one deliberate reference failure. It has not been observed on a remote run in this session and does not compile the Godot project or test network/gameplay behaviour.
- Godot is not installed in the current coding environment. Headless import, project boot, Android export, LAN device tests and load tests have not been run here.
- The local BR data still uses fixed `squad_size` values and has 30/50/100 player capacities; those values are not verified features and do not fit the current eight-device LAN cap.
- See `docs/TESTING.md` for commands and explicit untested items; see `docs/ROADMAP.md` for phase gates.

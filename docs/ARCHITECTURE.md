# Architecture

This document explains the shape of the codebase and, more usefully, *why* it
has that shape. If you are about to add a screen or a service, read §2 and §5
first.

---

## 1. Layers

```
        ┌──────────────────────────────────────────────────────┐
        │  UI        screens/ · pages/ · components/ · ui_kit   │  draws, never decides
        ├──────────────────────────────────────────────────────┤
        │  Services  src/autoload/*.gd  (14 singletons)         │  state + rules
        ├──────────────────────────────────────────────────────┤
        │  Core      src/core/*.gd  + game_modes/*.tres         │  data, no side effects
        ├──────────────────────────────────────────────────────┤
        │  Transport src/net/  ·  HTTP via Api                  │  sockets and bytes
        └──────────────────────────────────────────────────────┘
```

The dependency arrow only ever points **down**. A `.tres` gameplay resource has
never heard of a UI page; a UI page never opens a socket. This is what makes it
possible to run the whole game offline: `Api` returning `{ok = false}` degrades
the services to local behaviour, and the UI does not need to know which mode it
is in beyond showing the truth in the status strip.

## 2. The services, and the order they load in

`project.godot` lists them in dependency order. **A service may only reference
services above it in this list.**

| # | Autoload | Owns | Depends on |
| --- | --- | --- | --- |
| 1 | `EventBus` | every global signal | nothing |
| 2 | `Settings` | `user://settings.cfg`, defaults, quality presets | nothing |
| 3 | `Loc` | `en`/`fa` tables, direction, interpolation | Settings |
| 4 | `Design` | the palette, the type scale, the runtime `Theme` | Settings |
| 5 | `Controls` | `InputMap` actions for every scheme | Settings |
| 6 | `Session` | the signed-in `PlayerProfile`, local progression | Settings, Api |
| 7 | `Audio` | buses, music, synthesised UI cues | Settings |
| 8 | `Api` | the only HTTP in the codebase | Settings |
| 9 | `Auth` | Google / guest sign-in, credential storage | Api, Session, Settings |
| 10 | `Friends` | friends, requests, party | Api, Session |
| 11 | `Rooms` | custom lobbies, LAN discovery, host & join | Api, Session, Friends |
| 12 | `Matchmaking` | the competitive queue | Api, Rooms, Friends |
| 13 | `Toasts` | transient UI messages | Design, Loc |
| 14 | `Router` | screen navigation + transitions | everything |

Why autoloads and not a service locator: GDScript resolves autoload names at
parse time, so `Rooms.host_room(...)` is checked by the analyzer. A string-keyed
lookup would move that error to runtime, on a phone, in a lobby.

Late-bound cross-references (11 → 10 → 9) are why services read each other
*lazily inside functions* rather than caching references in `_init()`.

## 3. The signal bus

Services never call each other's UI callbacks and UI never polls. Everything
crosses through `EventBus`:

```gdscript
# service                        # screen
EventBus.room_updated.emit(room)   EventBus.room_updated.connect(_on_room_changed)
```

Rules that keep this honest:

- Payloads are **primitives, Dictionaries, Arrays or core Resources — never
  Nodes**. A signal that carries a Node is how a freed object ends up in a
  toast three frames later.
- One emit per state change, named for the fact (`room_closed`), not for the
  reaction (`refresh_rooms_button`).
- `EventBus.services_ready` is emitted once at boot, after all 14 are `_ready`.
  Initialisation order is only guaranteed by the autoload list, so anything
  that needs a stable world waits for it.

## 4. Screens versus pages

- A **screen** is a scene in `src/ui/screens/`, extends `HexScreen`, and owns a
  route. There are four: boot, login, profile setup, main menu.
- A **page** extends `MenuPage` and lives inside the main menu's content area.
  There are eight, listed in `main_menu_screen.gd::NAV_ENTRIES`.

The menu is deliberately **one screen with swap-able pages**, not seven scenes:
switching tabs must be instant, the top bar (level, currencies) must stay alive
across switches, and the nav rail must not reset. Pages are created on first
open and then kept, so scroll position and half-typed form state survive.

Adding a page is two edits: write the script, add one `NAV_ENTRIES` row. A page
with `"placeholder": true` gets the honest "not built yet" treatment from
`PlaceholderPage` for free.

## 5. Conventions that are enforced, not suggested

| Convention | Enforced by |
| --- | --- |
| gdlint style (tabs, 150-byte lines, name casing, definition order) | `gdlint src/**/*.gd` |
| Both locales define the same keys, no empty values, placeholders match | `tools/check_i18n.py` |
| Every `Class.member` exists; every call has the right argument count | `tools/check_refs.py` |
| Every signal is emitted and connected with the right arity | `tools/check_refs.py` |
| Every theme variation a screen asks for is defined in `design.gd` | `tools/check_refs.py` |
| Every `res://` path in code, scene or `project.godot` exists | `tools/check_refs.py` |
| Screens never build `StyleBoxFlat` | review — `design.gd` is the only place |

`tools/check_refs.py` is the important one: without a Godot binary in CI, it is
what stands in for the analyzer. It is a heuristic (it parses with regexes, not
a real GDScript front end), and it was built by planting bugs — a typo'd method
name, a wrong argument count, a mistyped theme variation, a missing translation
key — and confirming each was caught.

## 6. Two data flows worth understanding

### Joining a room by six characters

```
code ──> Rooms.join_by_code()
          ├─ can we see it on the LAN?  → Rooms.join_lan()  → ENet connect
          └─ else if Api configured?    → backend lookup    → phase 2
```

The LAN path is the real one today. Discovery (`src/net/lan_discovery.gd`)
broadcasts a JSON beacon to every plausible broadcast address twice a second;
a searcher binds the same UDP port and learns the host's **address from the
packet header**, never from the payload, because a payload can claim any address
it likes. That detail is the difference between "works on a hotspot" and
"works on the developer's home router".

### Finding a match

```
Matchmaking.start_queue(modes, region, ranked)
  ├─ filter to modes this device can actually run (offline ⇒ hotspot-sized)
  ├─ estimate a wait from BASE_WAIT_SEC
  ├─ backend configured? → Api.enqueue() and poll the ticket
  └─ else → local search with the same tick/found/ready-check shape
```

The local search exists so the queue overlay, ready check and roster can be
built and *seen* before the backend lands. Every ticket it produces carries
`simulated: true`, and every screen that shows one says so. A fabricated lobby
that looks like real players is the one thing this codebase refuses to do.

## 7. Persistence

| File | Owner | Contents |
| --- | --- | --- |
| `user://settings.cfg` | `Settings` | flat `"section/key"` values, versioned, migrated on load |
| `user://session.cfg` | `Session` | the `PlayerProfile` dictionary |
| `user://auth.cfg` | `Auth` | provider, `sub`, tokens — deleted on sign-out |
| `user://friends.json` | `Friends` | friend list + requests, locally cached |

All four are tolerant of corruption: parse failure means "start empty and say
so in the log", never a crash on boot. Anything newer than the running build is
ignored field by field rather than rejected.

## 8. Performance notes, since this is a phone game

- The UI is drawn from a runtime `Theme`, not per-widget overrides, so style
  resolution is a pointer chase rather than a tree walk.
- `HexBackdrop` builds its lattice once and redraws only on resize.
- UI sounds are synthesised at boot into `AudioStreamWAV`s (`src/audio/tone_synth.gd`):
  no decode, no files, ~0 APK bytes.
- Nothing in the menu allocates per frame. The only `_process` loops that run
  are the ones whose feature is live (a queue, a scan, a hosted room).

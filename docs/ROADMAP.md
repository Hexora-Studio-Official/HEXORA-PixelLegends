# Roadmap

Every feature that was asked for, mapped to the phase that delivers it and to
the exact code that already exists for it. Nothing here is aspirational
hand-waving: if a row says "done", the code is in this repository and passes
`tools/check_refs.py`.

Legend: **done** — ships and works · **built, needs backend** — client side
complete, waiting on a server · **phase N** — not started.

---

## Stage 1 — the shell ✅ (this delivery)

| Requirement | State | Where |
| --- | --- | --- |
| Engine + language chosen and justified | done | Godot 4.4 + GDScript, `project.godot` |
| Android target, balanced graphics | done | `renderer/mobile`, `assets/art/README.md` budget |
| Login screen with **Google sign-in** | done | `src/ui/screens/login_screen.gd`, `src/core/auth/google_signin.gd` |
| Guest sign-in as a first-class option | done | login screen, no configuration required |
| **Main menu and its options** | done | `src/ui/screens/main_menu_screen.gd` + 8 pages |
| Settings reachable **before** sign-in | done | gear button → modal on the login screen |
| English + Persian, full RTL | done | `src/i18n/`, `Loc.layout_direction()`, 510 keys |
| **Hotspot room: create + invite friends** | done | `src/net/lan_discovery.gd`, `Rooms.host_room()` |
| Hotspot room: find + join | done | Discover tab, code entry, manual address |
| Honest UI about what is not built | done | `simulated` / `sample` / `phase_notice` flags |

## Stage 2 — the match (next)

| Feature | Plan |
| --- | --- |
| Match scene, movement, shooting, hit registration | Authoritative host over the existing ENet peer; `GameMode.to_rules()` already carries the ruleset |
| The four modes | `tdm.tres`, `snd.tres`, `ffa.tres`, `gunfight.tres` are already data-complete; the match script reads them |
| Battle Royale 30 / 50 / 100 | `br30/50/100.tres` exist with zone phases, loot tier and squad sizes; needs the zone system + bigger maps |
| Map greyboxes | `assets/art/maps/`, one per id in `GameMode.map_pool()` |
| Touch controls | `Controls` already registers every action for three schemes; the on-screen layer reads its layout from the same table |
| Roster, scoreboard, kill feed | `EventBus.match_*` signals + the existing `UiKit` primitives |
| **Online backend** | `/v1/auth/google`, `/v1/profile`, `/v1/friends`, `/v1/rooms`, `/v1/matchmaking/tickets` — all call sites are written and typed in `src/autoload/api_client.gd` |
| Online room browser + join | `Rooms` already routes `join_by_code` to the backend when configured |
| Random competitive matchmaking | `Matchmaking` already enqueues, polls, ticks, and runs the ready check against the backend contract |
| Ranked ladder | `PlayerProfile` already models rank points, tiers and the season |

## Stage 3 — progression and content

| Feature | Plan |
| --- | --- |
| Loadout / arsenal (8 slots) | `PlaceholderPage` already draws the real slot list; needs the item tables and unlock rules |
| Store (credits / cores) | Currency is modelled and displayed; needs the catalogue and receipt validation server-side |
| Ranked seasons + rewards | `rank.*` keys, tier floors and ceilings already exist |
| Cosmetics, battle pass | Later; the rarity ramp in `design.gd` is the hook |
| Native Android Google Sign-In SDK | Replaces the loopback flow behind `AuthService`, no screen changes (`docs/AUTH_SETUP.md` §4) |

## Stage 4 — launch readiness

| Feature | Plan |
| --- | --- |
| Anti-cheat | Server-authoritative movement and firing, input sanity bounds, no client-trusted hits |
| Android export + signing | `docs/BUILD_ANDROID.md` |
| Store listing, age rating, privacy policy | Needs the account deletion path: `Session.clear_profile()` + the profile reset button already exist |
| Localisation beyond en/fa | `tools/check_i18n.py` gates parity; add `strings_<locale>.gd` + one `Loc.LOCALES` entry |
| Playtesting instrumentation | `dev/verbose_net_log`, `dev/simulated_latency_ms` already exist |

---

## Deliberate non-goals for stage 1

- **No fake matches, ever.** Matchmaking may simulate a lobby to exercise the
  UI, and when it does the ticket carries `simulated: true` and the overlay
  prints it. Same for the seeded sample friends (`sample: true`, badged) and the
  seeded sample rooms.
- **No gameplay.** Stage 1 is the shell; a shooting prototype bolted on would
  have to be thrown away when the authoritative host lands.
- **No monetisation.** `credits` and `cores` are modelled because the UI needs
  them; nothing is purchasable and no store is wired to a payment provider.
- **No `.tres` theme, no downloaded asset packs.** Everything visual is either
  in `design.gd` or generated at runtime. It keeps the repository diffable and
  the licensing unambiguous.

## Definition of done for a phase

1. `gdlint` clean on `src/**/*.gd`.
2. `python3 tools/check_i18n.py` exit 0 — every locale has every key.
3. `python3 tools/check_refs.py` exit 0 — no dangling reference, no arity
   mismatch, every theme variation and every `res://` path real.
4. Every new key present in **both** locales, including the Persian one.
5. Any simulated or placeholder behaviour visible on screen, in the player's
   language, without needing to read the code.

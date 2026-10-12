# Development plan — Stage 1 foundation

**Status (2026-10-12):** Stage 0 was reported and approved. Stage 1 is authorized and in progress. Stage 2 and all later stages remain gated on the Stage 1 report and separate owner approval.

## Owner-approved requirements

- Hotspot/Wi-Fi rooms are for friends' casual offline play only: no internet/account requirement and no ranked results.
- Battle Royale offers Solo and Squads of 2, 3 and 5.
- Hard Mode is a BR variant with very scarce weapons and supplies, not a weaponless mode.

These are requirements for later implementation, not claims about current gameplay. See [`ROADMAP.md`](ROADMAP.md) for the stage gates and unresolved decisions.

## Current baseline

- Godot 4.4+ / GDScript; Mobile renderer; Android target and desktop development path.
- Client shell, local profile/settings, English/Persian localization, GameMode metadata, an HTTP client contract, mock API and local ENet/UDP room code exist.
- The project has no match runtime, production backend/database, dedicated server or measured player capacity.
- `GameMode` currently stores one `squad_size` per resource. Supporting the approved Solo/2/3/5 selection requires a deliberate playlist/configuration model in the BR phase; do not fake support by changing `max_players` alone.
- The LAN decoder's magic-marker mismatch was corrected in Stage 1. Actual Godot, two-client and mobile network tests remain outstanding.
- Online authentication has a known profile/token persistence issue in `src/autoload/auth_service.gd`. It must be corrected and tested before production online sign-in/lobbies; a mock response is not sufficient.

## Module and configuration plan

Keep the present client boundaries and extend only when a gated feature needs them:

1. **Client/UI:** pages and screens display state and gather input; no low-level network or authoritative match decisions.
2. **Client services:** existing autoloads own settings, auth/session, friends, rooms, matchmaking, audio and navigation. Avoid moving rules into UI callbacks.
3. **Shared core:** profile, room, enums and mode definitions. Keep data-only resources separate from server-side rule execution.
4. **Local transport:** ENet room host plus UDP discovery for the friends-only unranked path. Keep its trust model visibly separate from ranked play.
5. **Online control plane (future):** a small backend owns identity verification, profiles, friends, private lobbies, queue tickets and server assignment.
6. **Match runtime (future):** a Linux headless Godot server owns match simulation and results. It may share validated core data, but not client authority. Stage 2 will add a server-specific bootstrap/export and launch it without the client UI/GPU; validated CLI options or an external config will supply bind port/capacity/logging, with systemd deferred to deployment. No runnable server command exists yet, and the exact command must be tested when that target is implemented.

Configuration ownership:

- Player preferences: `Settings` / `user://settings.cfg`.
- Local profile/auth/friend cache: current local files documented in `ARCHITECTURE.md`; these are not online authority.
- Mode defaults: `GameMode` resources. Future server-owned match configuration must validate every option and include Solo/2/3/5 and normal/scarce BR loot profiles.
- Server bind/ports/logging: future external server config/arguments. Secrets belong in environment/deployment secret storage, never the repository.

For the first online prototype, prefer one simple backend and one database on one EU VPS, with a small number of dedicated match processes. Keep the game server separable. Do not select a provider or purchase infrastructure until target concurrency and a budget are approved. A very rough planning envelope for one low-tier EU VPS is €10–40/month, plus roughly €10–25/year for a domain; this is not a vendor quote, does not establish game-server capacity, and excludes backups, managed services and traffic beyond the plan. Current repository infrastructure spend is €0; no provider or paid service has been selected.

## Stage 1 work and gate

- Document current modules, future authority boundaries and configuration ownership.
- Align `MASTER PROMPT.txt`, README and project documentation with the owner's decisions.
- Keep static checks repeatable in local development and GitHub Actions.
- Record the LAN protocol fix and the auth/session blocker without claiming unrun tests.
- Define client and future headless-server build approach; do not create a production backend or gameplay system in this stage.
- Run Python checks and GDScript lint. Import/boot the actual project in Godot headless and verify no new engine errors when a Godot 4.4+ binary is available.

**Acceptance status:** documentation and static checks can be completed here. The Godot import/headless acceptance test is blocked in this environment because neither `godot` nor `godot4` is installed. Stage 1 must not be marked accepted until that check runs successfully (or the owner approves a documented alternative). Do not start Stage 2 before the Stage 1 report and owner approval.

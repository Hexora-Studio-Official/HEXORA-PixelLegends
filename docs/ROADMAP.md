# Roadmap and phase gates

This roadmap follows [`MASTER PROMPT.txt`](../MASTER%20PROMPT.txt). Finish and report one stage at a time; do not begin the next stage until the owner approves. A resource file or UI path is not a completed gameplay feature.

## Owner-approved product scope (2026-10-12)

- **Wi-Fi / hotspot:** intended for friends' offline, casual and unranked play. No internet, account or public matchmaking is needed for this path. “Friends-only” is not account-based identity verification; the shared local network is the trust boundary. A local host may be authoritative only for this noncompetitive play.
- **Battle Royale:** Solo plus Squads of **2, 3 and 5**. These choices must be represented by configuration and tested; each listed capacity is not automatically supported just because a number is configured.
- **Hard Mode:** a Battle Royale variant in which weapons and supplies on the map are very scarce. It is **not** weaponless/melee-only. Loot rates remain configurable; exact numbers require balance tests.

## Current phase

| Stage | Status | Evidence / gate |
| --- | --- | --- |
| 0 — Project audit | **Reported and owner-approved** | Baseline report and plan delivered in chat; owner authorized Stage 1. |
| 1 — Technical foundation and structure | **In progress / runtime-blocked** | Docs and static checks are being aligned. No Godot executable is available in the current environment, so the import/boot/headless acceptance check cannot yet be claimed. See `DEVELOPMENT_PLAN.md` and `TESTING.md`. |

The current code is a client shell. It has no match scene, playable movement/combat, production backend, database or dedicated server.

## Stages 1–13

| Stage | Goal and scope | Acceptance gate |
| --- | --- | --- |
| **1 — Technical foundation** | Confirm module boundaries and configuration ownership; align documents; establish repeatable static checks; define client/server build approach; verify Godot import and headless behaviour. Fix only foundation blockers; no gameplay feature work. | Project imports/runs without new errors; basic commands and config are documented; headless/server approach is explicit. Stop and report. **Engine verification is currently blocked.** |
| **2 — Initial Dedicated Server** | Add a Linux headless server bootstrap/export, port and capacity configuration, logs, and simple start/stop/health commands. No GPU or GUI dependency. | Server actually starts, stops and restarts; failures are visible in logs. Stop and report. |
| **3 — First online match connection** | Connect at least two real clients to the dedicated host; synchronize initial player state and movement; handle join, leave and basic network loss. | Two clients visibly agree on player state; connect/disconnect tests pass. Stop and report. |
| **4 — Combat and Team Deathmatch** | Server-validated shooting, hit registration, health/damage, death, respawn, team assignment, scoring and match end. | A complete TDM can be played; clients cannot authoritatively set hits or scores; mode tests pass. Stop and report. |
| **5 — Friends-only LAN / hotspot** | Repair and test room discovery/manual join, ready state and room lifecycle on Wi-Fi and hotspot. Add supported offline modes only after each is playable. Keep the path unranked and local. | Target phones connect without internet; discovery/manual fallback, lobby state and disconnect behaviour are recorded. Document any Android/iOS network limits. Stop and report. |
| **6 — Private internet lobbies** | Verified account/session flow, secure invite codes, backend-created private lobbies, ready state and assignment to an online match server. | Two clients on separate networks join through an invite; unauthorized joins fail. Stop and report. |
| **7 — Public matchmaking** | Queue, cancellation, match allocation, ready check, duplicate-queue prevention and disconnect handling. | Multiple clients reach one assigned match; failures and cancellation are tested. Stop and report. |
| **8 — Free for All and bots** | FFA scoring and respawns; bot controller, difficulty parameters and offline training. | FFA rules and bot behaviours are repeatably tested; bots do not use hidden information. Stop and report. |
| **9 — Search and Destroy** | Bomb plant/defuse, attack/defend sides, round timer, side swap and server-validated round/match results. | A full match works and rule/security tests pass. Hard Mode is deliberately not here because it depends on BR. Stop and report. |
| **10 — Battle Royale 30 and Hard Mode** | Base BR30 lifecycle, spawn/elimination/winner, map/configuration and Solo plus Squad sizes 2/3/5. Add Hard Mode as a scarce-loot BR variant after the base loop. | Each grouping choice and both loot profiles are tested; 30-player capacity is supported only after measured load/resource results. Stop and report. |
| **11 — BR 50/100 capacity** | Profile bottlenecks; test 50 then 100 separately; tune CPU, memory, network and synchronization. | Each capacity has real or clearly labelled simulated load-test evidence with CPU/RAM/bandwidth/latency/error results. No unsupported capacity claim. Obtain owner approval before extra infrastructure spend. Stop and report. |
| **12 — VPS deployment** | Reproducible Linux server output, sample configuration, install/run/status/log scripts, firewall/systemd guidance, backups and rollback notes. | Install on a clean VPS and verify start/stop/restart/health/logs; owner can follow the guide. Stop and report. |
| **13 — Final QA and handoff** | Regression, security, mode, performance and documentation review; record known limitations. | Tests and remaining critical issues are documented; no untested feature is labelled release-ready. Stop and report. |

## Requirements that remain open for a later gate

1. **Offline Battle Royale size:** the existing local room cap is eight. Decide whether friends play a reduced-cap BR, add bots to fill a small room, or defer BR offline. Do not claim a 30-player LAN match without evidence.
2. **Loot tuning:** the owner has approved the Hard Mode concept, but exact weapon/supply spawn rates and the map loot table still need playtesting.
3. **Release platforms:** the project is Android-first with desktop for development. Confirm iOS or other shipping platforms before platform-specific work.
4. **Online budget/provider and target concurrency:** no VPS, backend host, database or paid service has been chosen. Estimate again using measured requirements before purchase.

## Definition of done for every stage

- Run the checks appropriate to the stage and record the actual command/result.
- List tests not run; never present simulated clients as real-device tests.
- Record changed files, remaining risks, dependencies and costs.
- Mark every acceptance criterion confirmed, failed or blocked.
- Stop after the report and wait for the owner's next instruction.

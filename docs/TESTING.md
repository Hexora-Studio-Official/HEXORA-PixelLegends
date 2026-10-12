# Testing and verification

## Ground rules

- Report the exact command, environment and result. If a Godot/device/backend is unavailable, mark the test **not run/blocked**.
- A source-level check, simulated client or local mock server is not a real-device, security or capacity test.
- Never report 30/50/100-player support until that level is tested and its resource/network results are recorded.

## Static checks

Python 3.11+ and `gdtoolkit` 4.x are used. Install the pinned lint dependency and run:

```bash
python3 -m venv .venv
. .venv/bin/activate
python -m pip install -r requirements-dev.txt
python3 tools/check_i18n.py
python3 tools/check_refs.py
gdlint $(find src -name '*.gd' -print)
```

`check_refs.py` is a regex-based consistency checker, not Godot's parser. A GitHub Actions workflow is configured to run these checks and uses an isolated temporary tree to verify that a deliberately missing `res://` reference is detected; no remote workflow run was observed in this session.

### Results in the Stage 1 environment (2026-10-12)

| Check | Result |
| --- | --- |
| `python3 tools/check_i18n.py` | **PASS** — `en` and `fa`, 511 keys each. |
| `python3 tools/check_refs.py` | **PASS** — 55 classes, 41 scripts, 4 scenes; no dangling references according to the checker. |
| `gdlint $(find src -name '*.gd' -print)` | **PASS** — gdtoolkit 4.5.0; no lint problems. |
| Fault-sensitivity check (isolated temporary copy) | **PASS** — the planted missing `res://` asset was reported as an error. |
| Godot editor/import or headless launch | **BLOCKED / not run** — no `godot` or `godot4` binary is installed. |
| Android export / phone install | **NOT RUN** — no Godot build, Android SDK test or device test was performed. |
| LAN discovery/join on two clients | **NOT RUN** — the decoder fix is source-reviewed only. |
| Gameplay, bot and 2–100-player load tests | **NOT RUN** — match gameplay/server are not implemented. |

## Godot checks (when the engine is available)

Use Godot 4.4 or newer. From the repository root:

```bash
godot --headless --path . --editor --quit
```

This imports/opens the project in headless editor mode. Record all errors and warnings; a passing Python check is not a substitute. Then launch the client in the editor and verify the boot, login/guest, profile setup, settings, localization/RTL and main-menu navigation. The current project has no playable match scene.

The dedicated-server target does not exist yet. Stage 2 must add and verify its own headless export/bootstrap, start/stop/health commands and Linux logs before any server runtime test can pass.

## Manual LAN test matrix (Stage 5)

All cases are casual and unranked. Test at least two clients with no internet and record device/OS/Godot version, topology, address/port and result:

1. Same-machine two-instance discovery (primary and fallback discovery ports).
2. Two phones on one Wi-Fi router: automatic discovery and manual IP join.
3. Host phone hotspot plus one or more joiner phones: discovery and manual IP fallback.
4. Correct roster, room capacity, ready state, host close, client leave and dropped connection.
5. Wrong password, full room, malformed/version-mismatched beacon and network loss.
6. Confirm no ranked/profile rewards are produced in a local room.

The current room cap is eight devices. A successful eight-client room would not prove BR30, BR50 or BR100 capacity.

## Online, combat and capacity gates

- **Stage 2:** start/stop/restart the Linux headless server; health/logging; no GPU requirement.
- **Stage 3:** at least two real clients; joining/leaving, movement synchronization and network interruption.
- **Stage 4:** server-validated shots/hits/damage, death/respawn, score and match-end cases; malformed client requests rejected.
- **Stages 6–9:** auth verification, private invitations/permissions, queue cancellation and assignment, then mode-specific rules.
- **Stages 10–11:** BR group sizes and loot profiles; test capacity 30, then 50, then 100 only after each prior gate passes. Record player count, duration, CPU, RAM, bandwidth, average and P95 latency, disconnect/error rates, and whether clients were real or simulated.

`tools/mock_server.py` is development-only: it accepts arbitrary Google ID tokens and trusts requests. It can exercise UI/API plumbing but cannot validate production authentication, authorization or security.

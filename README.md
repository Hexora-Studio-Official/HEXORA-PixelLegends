# PixelLegends

**PixelLegends** is an original, mobile-first 5v5 MOBA built with **Godot 4.4**, with a fully 3D game target and a refined, high-resolution pixel-art identity.

> **Single source of truth:** [`docs/PROJECT_SPEC.txt`](docs/PROJECT_SPEC.txt) contains the product requirements, architecture, visual direction, authentication/networking targets, phase gates, and the live implementation handoff. Read it before planning or changing project behavior. The status block at the top is the progress record.

## Start here

1. Read [`AGENTS.md`](AGENTS.md) for repository-specific agent rules.
2. Read the full [`PROJECT_SPEC.txt`](docs/PROJECT_SPEC.txt), especially **LIVE PROJECT STATUS & AGENT HANDOFF** near the beginning.
3. Check the current working tree before editing. Preserve existing user work and make only the next approved, testable change.

## Current implementation snapshot

- The formal roadmap is at **Phase 0 — Foundation: in progress, not passed**. The exact status, completed work, blockers, and next steps are maintained in the project spec.
- The active workstream is the branded entrance and menu shell, local guest profile flow, visual environment, documentation, and validation.
- **Login As Guest** is the only active sign-in choice. **Play** and **Login With Google** are visible but inactive.
- No playable 3D match, hero, arena, or MOBA simulation is implemented. Nakama-backed accounts, active MOBA matchmaking, and a dedicated match server are not connected to the current UI.
- Inherited shooter-era scripts, data, and generic service autoloads remain in the repository. Do not treat them as active PixelLegends gameplay or reconnect them to the current UI without an approved task.

## Open and run

1. Install the standard/GDScript **Godot 4.4** editor.
2. Open `project.godot` and let Godot finish importing assets.
3. Press **F5** to run the project from its configured main scene.

The Android preset is a debug/testing configuration, not a store release. Godot import, runtime, Android export, and device validation status is recorded in the live handoff block inside [`docs/PROJECT_SPEC.txt`](docs/PROJECT_SPEC.txt).

## Static checks

```bash
python3 tools/check_i18n.py
python3 tools/check_refs.py
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements-dev.txt
.venv/bin/gdlint $(find src -name '*.gd' -print)
python3 -m py_compile tools/check_i18n.py tools/check_refs.py tools/mock_server.py tools/plant_fault.py
git diff --check
```

Static checks do not replace opening the project in Godot 4.4 or testing the screens and guest flow on target aspect ratios/devices.

## Repository map

```text
project.godot          Godot project configuration and main scene
assets/                Supplied PixelLegends artwork, fonts, and project assets
src/                   Current Godot source layout
  autoload/             Shared app services and routing
  core/                 Data models and retained legacy scaffolding
  ui/                   Screens, pages, and reusable UI components
tools/                 Static validation and development utilities
docs/PROJECT_SPEC.txt  Canonical product, architecture, phase, and progress reference
AGENTS.md              Instructions for coding agents
```

The client/server/shared tree shown as a long-term logical target in the specification is **not** the current physical folder layout. Evolve toward it only through small, approved steps; do not reorganize the repository wholesale.

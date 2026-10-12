# HEXORA

An Android-first 3D shooter prototype built with **Godot 4.4+ and GDScript**. Desktop is currently a development target. The project has a substantial client shell, but **there is no playable match yet**: no player controller, weapon/damage loop, match scene, production backend, or dedicated match server.

The local Wi-Fi / phone-hotspot path is intended **only for friends playing casually offline**. It needs no internet or account and is never ranked. “Friends-only” describes the product use, not account-based identity verification: the current LAN lobby trusts the shared local network and does not authenticate friend identities. Online competitive matches, when implemented, must use a server-authoritative dedicated server.

Approved Battle Royale scope: **Solo** and Squads of **2, 3, or 5**. **Hard Mode is a Battle Royale variant** with very scarce weapons and supplies on the map; it is not a weaponless/melee-only mode. These are product requirements, not features available in the current build.

> **Current phase: Stage 1 — technical foundation and project structure.** Login/guest flow, profile setup, settings, localization and the main-menu shell exist. Local-room networking code exists, but has not been validated on Godot or real devices. The Stage 1 report and acceptance gates are in [`docs/DEVELOPMENT_PLAN.md`](docs/DEVELOPMENT_PLAN.md) and [`docs/ROADMAP.md`](docs/ROADMAP.md).

## Current implementation status

| Area | Actual state |
| --- | --- |
| Client shell | Boot, Google/guest entry points, profile setup, main menu, settings and UI components are present in source. Engine/runtime validation is still pending. |
| Localization | English + Persian string tables, RTL handling and 511 matching keys. |
| Game-mode definitions | Eight `GameMode` resources describe intended rules. They do not implement gameplay. BR's approved Solo/2/3/5 grouping and Hard Mode scarcity still need their configuration/runtime work. |
| Friends-only LAN rooms | ENet room host/join, roster, UDP discovery and manual-IP fallback are present. Local rooms are unranked and capped at 8 devices. A beacon-decoder mismatch was corrected during Stage 1, but the fix still needs a Godot runtime and device test. |
| Online rooms / matchmaking | The client API contract and UI paths exist. There is no production backend or database. `tools/mock_server.py` is a development-only fake backend and must not be exposed to real players. |
| Match gameplay | Not implemented. There are no gameplay scenes, maps, movement, weapons, damage, bots or match results yet. |
| Android build tooling | An Android debug export preset and GitHub Actions workflow are configured but not yet validated by a remote run. |
| Dedicated server / deployment | Not implemented. No Linux server build, deployment scripts or VPS have been validated. |

The current LAN room capacity (8) is not evidence that BR30/50/100 can run locally. Before the LAN and BR phases, the owner must decide whether an offline BR room uses a smaller player cap, bots, or another explicitly tested configuration.

## Quick start and checks

Requirements: Godot **4.4 or newer** for the editor/runtime. Android export additionally needs the Android SDK/toolchain described in [`docs/BUILD_ANDROID.md`](docs/BUILD_ANDROID.md).

Run the repository's static checks (no Godot binary required):

```bash
python3 -m venv .venv
. .venv/bin/activate
python -m pip install -r requirements-dev.txt
python3 tools/check_i18n.py
python3 tools/check_refs.py
gdlint $(find src -name '*.gd' -print)
```

The GitHub Actions workflow is configured to run these static checks and verify that the reference checker catches a deliberately broken resource path. The workflow has not been observed on a remote run in this session. These checks are **not** a substitute for importing/running the project in Godot or testing on phones. See [`docs/TESTING.md`](docs/TESTING.md) for commands, status and the device test matrix.

With Godot installed, a headless editor/import smoke check can be run with:

```bash
godot --headless --path . --editor --quit
```

Then open the project in Godot and press F5 for the client shell. **A playable match is not available yet.**

### Optional mock backend

```bash
python3 tools/mock_server.py
```

This is for local development only. It accepts any Google `id_token`, trusts requests, returns sample data and enables permissive CORS. Do not expose it to the public internet or use it as an authentication/security test.

## Repository layout

```text
project.godot            Godot config, autoloads, layers and renderer
src/autoload/            client services (settings, auth, rooms, queue, etc.)
src/core/                data models and GameMode resources
src/core/game_modes/     eight intended rulesets; not gameplay implementations
src/net/                 local UDP discovery
src/ui/                  screens, pages, components and design system
src/i18n/                English and Persian string tables
assets/                  fonts, brand and art-direction resources
tools/                   static checkers, fault planter and mock backend
docs/                    architecture, development plan, testing and build notes
```

The visual theme is generated at runtime by `src/autoload/design.gd`; icons, the hex backdrop and UI sounds are procedurally drawn/synthesized. The fonts are binary assets: Chakra Petch and Vazirmatn are licensed under SIL Open Font License 1.1 (see [`assets/fonts/OFL-NOTICE.txt`](assets/fonts/OFL-NOTICE.txt)).

The future architecture and trust boundaries are documented in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md). No online service, paid provider or hosting budget has been selected.

## Documentation

- [`MASTER PROMPT.txt`](MASTER%20PROMPT.txt) — approved project requirements and phase gates.
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — current modules, proposed server boundary and configuration ownership.
- [`docs/DEVELOPMENT_PLAN.md`](docs/DEVELOPMENT_PLAN.md) — Stage 1 scope, assumptions and implementation plan.
- [`docs/ROADMAP.md`](docs/ROADMAP.md) — stages 0–13 and acceptance gates.
- [`docs/TESTING.md`](docs/TESTING.md) — static, runtime, LAN and load-test plans with current results.
- [`docs/AUTH_SETUP.md`](docs/AUTH_SETUP.md) — Google OAuth setup and security constraints.
- [`docs/BUILD_ANDROID.md`](docs/BUILD_ANDROID.md) — Android export prerequisites and device notes.
- [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) — third-party assets and licenses.

## License

The project code is © HEXORA Studio. No redistribution license has been selected yet. Third-party assets have their own licenses; see [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

---

### خلاصهٔ فارسی

**HEXORA** یک پروژهٔ شوتر سه‌بعدی با Godot 4.4+ است؛ فعلاً پوستهٔ کلاینت و منوها را دارد و **هنوز مسابقهٔ قابل‌بازی ندارد**. هدف Wi‑Fi/هات‌اسپات این است که چند دوست مودهای پیاده‌سازی‌شده را آفلاین و غیررقابتی بازی کنند؛ فعلاً گیم‌پلی‌ای برای اجرا وجود ندارد. بتل‌رویالِ برنامه‌ریزی‌شده حالت انفرادی و اسکوادهای ۲، ۳ و ۵ نفره دارد؛ Hard Mode گونه‌ای از بتل‌رویال با سلاح و منابع بسیار کمیاب است، نه مودِ بدون سلاح. این قابلیت‌ها هنوز پیاده‌سازی نشده‌اند.

**مرحلهٔ فعلی: مرحلهٔ ۱، پایهٔ فنی و ساختار پروژه.** کد لابی محلی وجود دارد، اما اجرای آن در Godot و آزمایش روی دستگاه واقعی هنوز انجام نشده است. وضعیت واقعی و برنامهٔ مراحل در `docs/DEVELOPMENT_PLAN.md` و `docs/ROADMAP.md` آمده است.

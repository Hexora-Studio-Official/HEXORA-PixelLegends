# Third-party notices and asset provenance

Keep this file accurate before distributing a build. The PixelLegends product, architecture, visual direction, and implementation plan are defined by [`docs/PROJECT_SPEC.txt`](docs/PROJECT_SPEC.txt); this file is limited to licensing and provenance records.

## Fonts — `assets/fonts/`

| Font | Use | Licence |
| --- | --- | --- |
| **Chakra Petch** (Medium, SemiBold, Bold) — Cadson Demak | Display typography | SIL Open Font License 1.1 |
| **Vazirmatn** (Latin Regular, Medium, SemiBold, Bold) — Saber Rastikerdar | Latin body typography | SIL Open Font License 1.1 |

The retained font files are distributed under the SIL Open Font License 1.1. The licence notice is in `assets/fonts/OFL-NOTICE.txt`; keep it with the font files in any redistribution. The Arabic/Persian subsets have been removed from the project.

## Engine and development tools

| Component | Licence / distribution |
| --- | --- |
| **Godot Engine 4.4** | MIT. The engine is installed separately and is not vendored here. Follow Godot's distribution requirements when exporting. |
| Project scripts in `tools/` | Original development utilities; not distributed as game content. |
| **gdtoolkit** (`gdlint`) | MIT; development-only dependency declared in `requirements-dev.txt`. |

## Supplied project art

The two PixelLegends PNG files under `assets/` were supplied for this project by the project owner. No external marketplace package or third-party attribution record was provided with them. Keep the originals and verify distribution rights before public release if ownership or licensing is not documented elsewhere.

All future characters, maps, UI artwork, effects, names, and other creative content must follow the originality requirements in `docs/PROJECT_SPEC.txt`. Do not rip, trace, or redistribute proprietary assets from another game.

## Audio

There are no shipped music files in the current UI-shell milestone. Future audio must be original or properly licensed, and every third-party item must be recorded here with its author, source, licence, and attribution requirements before inclusion.

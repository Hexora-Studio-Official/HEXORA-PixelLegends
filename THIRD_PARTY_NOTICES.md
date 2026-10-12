# Third-party notices

Everything in this repository that HEXORA did not write is listed here, with
its licence. Keep it accurate: a shipped APK is a distribution, and an
attribution that is missing from a build is a licence violation even if it is
present in the source tree.

## Fonts — `assets/fonts/`

| Font | Use | Licence |
| --- | --- | --- |
| **Chakra Petch** (Medium, SemiBold, Bold) — Cadson Demak | Display: titles, buttons, labels, numbers | SIL Open Font License 1.1 |
| **Vazirmatn** (Regular, Medium, SemiBold, Bold; Arabic + Latin subsets) — Saber Rastikerdar | Body text and the entire Persian UI | SIL Open Font License 1.1 |

Both are shipped as `.woff2` in `assets/fonts/`, with the full OFL 1.1 text in
`assets/fonts/OFL-NOTICE.txt`. The OFL requires that the copyright notice and
the licence travel with the font files — keep both files in any redistribution,
including a store build.

The OFL also forbids selling the fonts on their own and requires that modified
versions be renamed. Neither applies here: the fonts are used unmodified.

## Engine

| Component | Licence |
| --- | --- |
| **Godot Engine 4.x** | MIT. The engine is *not* vendored in this repository — the developer installs it. Its full licence text must be included in a shipped build; the Android export template already ships Godot's `LICENSE.txt` alongside the binary. |

## Development-only tools — `tools/`

| Tool | Licence |
| --- | --- |
| `check_i18n.py`, `check_refs.py`, `mock_server.py` | Original to this project; part of the repository, not shipped in a build. |
| `gdtoolkit` (`gdlint`) | MIT — used from a virtualenv during development, never bundled. |

## Asset policy

- **No downloaded asset packs.** Nothing in `assets/` came from a third-party
  marketplace or a "free models" site. Art is authored in-house or the game
  draws it procedurally (`design.gd` builds the theme, `HexIcon` draws the
  icons, `tone_synth.gd` synthesises the UI sounds).
- **Before adding an asset**, add a row here: what it is, where it came from,
  its licence, and whether attribution is required *in-game* (some CC-BY
  licences require an in-app credits screen, not just a README).
- **Sound and music**: `assets/audio/` is empty apart from the README. When
  tracks land, they must be original, CC0 or CC-BY, normalised to about
  −16 LUFS, and credited here.
- **What is never acceptable**: anything ripped from another game, anything
  whose licence you have not read, and anything whose provenance is "a friend
  sent it to me". A DMCA takedown on a store listing is unrecoverable.

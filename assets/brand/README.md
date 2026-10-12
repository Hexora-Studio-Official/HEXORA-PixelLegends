# Brand

| File | Use |
| --- | --- |
| `hexora_mark.svg` | Flat, square-safe mark: store listing, splash, social preview, one-colour stamp. |
| `../../icon.svg` | The app icon Godot imports (`application/config/icon`), a rounded-square variant with the reticle. |

Both are hand-written SVG using plain shapes only — no filters, no masks, no
foreign objects — so ThorVG (Godot's importer) and every browser render them
identically. Keep it that way: a gradient that renders in Chrome and fails in
the importer is a broken launcher icon nobody notices until release.

## Palette

Straight from `src/autoload/design.gd`. If you change a colour there, change it
here too — the logo sitting next to UI that uses a different orange looks like a
mistake, because it is one.

| Name | Hex | Where it is used |
| --- | --- | --- |
| Deep background | `#070B11` | App background, logo field |
| Surface | `#0C1219` | Cards, panels, logo plate |
| Line | `#2B3D4F` | Hairline borders, logo stroke |
| **Sodium** (warm accent) | `#FF7A1A` | Actions, the player acts. Primary in the mark. |
| Sodium bright | `#FFA53D` | Hover, highlights |
| **Instrument teal** (cold accent) | `#18E0C8` | Information, status. Secondary in the mark. |
| Text | `#E8EEF5` | Body copy |
| Muted text | `#8FA0B3` | Captions, secondary labels |

## Rules

- **Two accents, one meaning each.** Warm means *you can act*; cold means *the
  game is telling you something*. Never use teal for a primary button and never
  use orange for a status light.
- **Minimum sizes.** The mark must stay legible at 48 px: below that, use the
  icon without the inner reticle lines.
- **Clear space** of half the mark's width on every side.
- **Don't** recolour the mark, add a gradient, put it on a busy photo, or
  outline it. If it needs a background, use Deep background.
- **Wordmark**: "HEXORA" in Chakra Petch Bold, tracked slightly positive, upper
  case, text colour — never the accent colour, which stops it reading as a name
  and starts reading as a button.

## Naming

The studio is **HEXORA Studio**; the game is **HEXORA**. Don't write "Hexora" in
upper-case contexts or "HEXORA Studio" where the game is meant — the store
listing and the in-game title have to agree or the search result looks
unofficial.

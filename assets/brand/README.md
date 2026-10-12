# PixelField brand

| File | Use |
| --- | --- |
| `pixelfield_mark.svg` | Standalone block-built PF mark for store, splash and social artwork. |
| `../../icon.svg` | Rounded-square launcher icon imported by Godot. |
| `../../src/ui/components/pixel_field_mark.gd` | Shared runtime mark used on the boot and sign-in screens. |

The app icon, standalone mark and runtime drawing share the same PixelField
monogram. Keep the artwork legible at small launcher sizes and retain the plain
SVG shapes so Godot's importer and browsers render it consistently.

## Palette

The source of truth is `src/autoload/design.gd`. If a color changes there, update
the SVG and runtime mark to match.

| Name | Hex | Role |
| --- | --- | --- |
| Deep indigo | `#080D1D` | Background |
| Raised surface | `#101A30` | Panels and icon plate |
| Surface | `#141F38` | Cards |
| Blue-steel line | `#435D84` | Borders and icon frame |
| Electric lime | `#BAFF4A` | Primary actions and PF accent |
| Pixel cyan | `#47D9FF` | Information and PF accent |
| Text | `#F4F7FF` | Main copy |
| Muted text | `#C0CBE0` | Secondary copy |

## Rules

- Use lime for actions and cyan for information; keep both accents visible on
  the deep-indigo surfaces.
- Build marks from crisp, separated blocks so the PF monogram survives at
  48 px and below.
- Keep the PixelField wordmark in title case. HEXORA Studio is the studio name,
  not the game name.

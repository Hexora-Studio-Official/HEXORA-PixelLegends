# PixelField — art direction

**Target look: "medium / balanced".** Clean semi-realistic 3D — graphite and
machined aluminium, lit by sodium orange and instrument teal. Explicitly *not*
pixel art and *not* low-poly, and explicitly *not* a photoreal asset pipeline
that a small team cannot sustain on a phone.

## The three rules

1. **Silhouette before surface.** A weapon, a doorway or a character must be
   identifiable as a black shape at 40 m. Detail that does not survive that test
   is not worth its draw call.
2. **One accent per space.** A room gets one warm light source (orange) and one
   cold one (teal). Anything that is neither is neutral grey. This is what makes
   the maps read at a glance when the player is being shot at.
3. **Material honesty.** A surface's roughness tells the player what it is:
   metal is smooth and reflective, concrete is rough, glass is transparent and
   slightly tinted. No textured-in detail that lies about the physics.

## Budgets (target: 60 fps on a mid-range 2023 Android phone)

| Item | Budget |
| --- | --- |
| Renderer | `mobile` (see `project.godot`) |
| Draw calls per frame | ≤ 900 |
| Static mesh triangles per map | ≤ 250k |
| Character triangles | ≤ 18k LOD0, 8k LOD1, 3k LOD2 |
| Weapon triangles | ≤ 12k LOD0 |
| Texture size | 1024² for hero surfaces, 512² otherwise |
| Materials per map | ≤ 40 unique |
| Dynamic lights per room | ≤ 4 (1 shadowed directional + 3 unshadowed point/spot) |
| Realtime shadows | 1 directional, 2048², `soft_shadow_filter_quality = 1` |
| Post-processing | tonemap + depth fog + light glow — nothing screen-space |

`default_environment.tres` in this folder encodes those post-processing and fog
choices so every match scene starts from the same look.

## Textures

- Albedo + normal + packed ORM (occlusion/roughness/metallic) in **ETC2/ASTC**
  (`textures/vram_compression/import_etc2_astc=true`).
- Author at 1024², downscale per platform. A 2048² albedo on a phone costs a
  frame and buys nothing at this viewing distance.
- Trim sheets for architecture, separate materials only for hero props.

## UI

The interface is part of the art direction: deep indigo surfaces, vivid electric
lime for actions and pixel cyan for information, with hairline borders instead
of heavy chrome. All of it is built at runtime from `src/autoload/design.gd`
— there is no `.tres` theme to keep in sync, and no image assets for the UI to
load.

## What goes in this folder

| File | Purpose |
| --- | --- |
| `default_environment.tres` | The shared 3D `Environment` (sky, fog, tonemap, glow). |
| `materials/` (later) | Shared `StandardMaterial3D` resources for trim sheets. |
| `maps/` (later) | Greybox `.tscn` layouts per map id from `GameMode.map_pool()`. |

Placeholder art must be *honest placeholder art*: untextured greybox geometry
with correct scale and correct collision. Do not ship a downloaded asset set as
"temporary" — licensing mistakes in a shipped APK are unrecoverable.

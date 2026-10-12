# Music

`AudioService` streams menu and match music from this folder by id:

```gdscript
Audio.play_music(&"menu_lobby")   # -> res://assets/audio/music/menu_lobby.ogg
```

Ogg Vorbis (`.ogg`) only, and only the ids the game actually asks for. Files are
streamed, never preloaded, so a missing track is a silent menu rather than a
crash — `AudioService` logs which id it could not find.

| Id | Used by | Brief |
| --- | --- | --- |
| `menu_lobby` | Main menu, room browser | Slow, sparse, low-end pulse. Should survive being heard for an hour. |
| `match_intro` | Warmup, countdown | Short (≤ 20 s) build-up, ends on the round-start hit. |
| `match_tension` | Late round, 1v1 | Same key as the intro, fewer layers, no lead melody. |
| `results_win` | Results screen, victory | Bright, 6–10 s, no vocals. |
| `results_loss` | Results screen, defeat | Same motif, minor, 6–10 s. |

## Rules

- **Loudness:** normalise every track to about −16 LUFS integrated so the
  in-game SFX sit on top without the player touching the music slider.
- **Licensing:** every file here must be original, CC0, or CC-BY. CC-BY files
  need a row in the README with author and source URL, and the same credit must
  appear in the store listing. No "found it on a forum" tracks.
- **Size:** mono for anything short and percussive; stereo only for the menu bed.
  A 3-minute stereo OGG is roughly 3 MB — that is 3 MB off the APK budget.
- **Loop points:** set them in the OGG metadata. A track that clicks on loop is
  worse than no music.

UI cues are **not** files: `AudioService` synthesises every click, hover and
error tone at boot (see `src/audio/tone_synth.gd`), which keeps the APK small and
means the cue set can be re-tuned by changing numbers instead of re-exporting
audio.

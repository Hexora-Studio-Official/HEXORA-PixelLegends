# Building for Android

Stage 1 ships no gameplay, but the project is configured for Android from the
first commit — mobile renderer, ETC2/ASTC textures, landscape lock, touch
input — so the export path is exercised before there is anything expensive to
lose. This is how to get an APK/AAB out of this repository.

---

## 1. One-time setup

| Requirement | Notes |
| --- | --- |
| Godot **4.4 or newer** (4.7.2 is current stable) | Standard build; the .NET/C# build also works but nothing here uses C#. |
| Android SDK + build-tools | Easiest path: Android Studio → SDK Manager → *Android SDK Platform 34*, *Build-Tools 34*, *NDK 23c* (Godot 4.4 wants 23c or newer). |
| JDK 17 | Godot's Android export needs 17; 21 also works on 4.4+. |
| A keystore | `keytool -genkey -v -keystore hexora-release.keystore -alias hexora -keyalg RSA -keysize 2048 -validity 10000` |

Then in Godot: **Editor ▸ Editor Settings ▸ Export ▸ Android** and set *Android
SDK Path*, *Java SDK Path* and the debug keystore fields. The editor's
**Project ▸ Install Android Build Template** step is **not** needed — this
project has no native plugins.

## 2. Configure the export preset

**Project ▸ Export ▸ Add… ▸ Android**, then:

| Setting | Value | Why |
| --- | --- | --- |
| Package ▸ Unique Name | `com.hexorastudio.hexora` | Must match the OAuth client's package name if you later use the native Google Sign-In SDK. |
| Package ▸ Version Code / Name | `1` / `0.1.0` | Bump the code on every upload; Play rejects duplicates. |
| Graphics ▸ XR Mode | Regular | — |
| Graphics ▸ Renderer | **Mobile** | Matches `project.godot`; Forward+ costs 30–40 % on a mid-range phone for no visual gain at our density. |
| Textures ▸ Texture Format | ETC2 + ASTC (already the project default) | Covers essentially every Android device from 2016 on. |
| Permissions ▸ Internet | **On** for online play, **off** if you ship a hotspot-only build | A shooter that asks for internet before it has a backend is a red flag in review. |
| Permissions ▸ Access Network State / Access Wi-Fi State | On | Needed to read the local address for the hotspot lobby. |
| Permissions ▸ Access Fine Location | Off | Not needed: LAN discovery is a UDP beacon, not a Wi-Fi scan. Google Play asks for a justification for this one; don't request it. |
| Keystore ▸ Release | your keystore, alias `hexora` | Debug builds use the editor's debug key — fine for testing, rejected by Play. |
| Architectures | `arm64-v8a` (+ `armeabi-v7a` only if you care about pre-2018 devices) | 64-bit is mandatory on Play; the 32-bit slice doubles the download for a small audience. |

Export **AAB** for Play, **APK** for sideloading to a test phone.

## 3. Before every release build

```bash
# 1. Verify the tree without opening the editor.
python3 tools/check_i18n.py
python3 tools/check_refs.py
gdlint $(find src -name '*.gd')

# 2. Point the build at the real backend, not a laptop.
#    Either set it in Settings ▸ Developer on the build, or bake it in:
#      src/autoload/settings_service.gd →  "dev/api_base_url": "https://api.hexora.gg"
#    Leaving it empty is valid: the game runs offline and says so.

# 3. Bake in the Google client ID the same way, or the login button will tell
#    the player it is not configured. See docs/AUTH_SETUP.md §4.

# 4. Export, then install and actually launch it:
adb install -r build/hexora-release.apk
adb logcat -s godot:V
```

## 4. Things that only show up on a device

| Symptom | Cause / fix |
| --- | --- |
| Black screen on launch | Renderer mismatch. Check `renderer/rendering_method.mobile` in `project.godot` and the preset's *Renderer*. |
| Text shows as boxes | A font failed to import. `assets/fonts/*.woff2` must be present and imported; the fallback chain in `design.gd` covers Latin + Arabic script only. |
| Back button closes the game | `application/config/quit_on_go_back=false` is set, and `HexScreen.on_back_requested()` handles it. If a build quits, the current screen is not a `HexScreen`. |
| Hotspot discovery finds nothing | Some Android builds drop broadcast packets. Join by typing the host's address — the Rooms ▸ Join tab has the field, and it is a first-class path, not a workaround. |
| Sign-in opens the browser and comes back to nothing | Loopback redirects are handed to the app by Chrome on stock Android; some OEM browsers take it instead. See `docs/AUTH_SETUP.md` §4. |
| 60 fps on a flagship, 25 on a mid-range | `Settings ▸ Graphics ▸ Quality preset` already scales render resolution and caps fps by device tier (LOW/MEDIUM/HIGH, detected on first launch). Start there before touching the scene. |

## 5. Store checklist (for when there is something to sell)

- Privacy policy URL, and an in-app account deletion path that actually deletes
  server-side data. `Session.clear_profile()` covers the device.
- Content rating: a shooter with no gore still needs the questionnaire.
- Data safety form: the app collects an email address (Google sign-in) and
  nothing else; say so precisely.
- Target API level: whatever Play requires in the quarter you upload, not the
  SDK you happen to have installed.

# Building for Android

The current client shell has no gameplay yet, but the project is configured for
Android — mobile renderer, ETC2/ASTC textures, landscape orientation and touch
input — so the export path can be validated before there is anything expensive
to lose. `export_presets.cfg` contains a debug-only Android preset. The GitHub
Actions workflow at `.github/workflows/android-debug.yml` is configured to
import the project and produce a sideloadable APK; check the workflow run before
assuming an artifact exists. A successful export still does not prove that the
APK launches correctly on a physical phone.

---

## 1. One-time setup

| Requirement | Notes |
| --- | --- |
| Godot **4.4 or newer** (CI preset uses **4.4.1**) | Standard build; the .NET/C# build also works but nothing here uses C#. |
| Android SDK + build-tools | Android Studio → SDK Manager → *Android SDK Platform 34* and *Build-Tools 34*. The committed preset uses Godot's prebuilt template (no Gradle build); install NDK 23c+ and CMake only if you later build custom Android templates or enable the Gradle path. |
| JDK 17 | Godot's Android export needs 17; the CI workflow uses Temurin 17. |
| A keystore | `keytool -genkey -v -keystore pixelfield-release.keystore -alias pixelfield -keyalg RSA -keysize 2048 -validity 10000` |

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
| Permissions ▸ Internet | **On in this debug preset** | Android requires `INTERNET` for UDP/ENet sockets too; this permission does not mean a connection is needed. No backend or production online service is configured. Reassess the permission before a hotspot-only release. |
| Permissions ▸ Access Network State / Access Wi-Fi State | On in the debug preset | The local room path reads network state/address information. |
| Permissions ▸ Vibrate | **On in the debug preset** | `Controls.haptic()` calls Android's vibrator for button feedback; without the manifest permission, button taps can fail on device. |
| Permissions ▸ Access Fine Location | Off | Not needed: LAN discovery is a UDP beacon, not a Wi-Fi scan. Google Play asks for a justification for this one; don't request it. |
| Keystore ▸ Release | your keystore, alias `pixelfield` | Debug builds use the editor's debug key — fine for testing, rejected by Play. |
| Architectures | `arm64-v8a` (+ `armeabi-v7a` only if you care about pre-2018 devices) | 64-bit is mandatory on Play; the 32-bit slice doubles the download for a small audience. |

Export **AAB** for Play, **APK** for sideloading to a test phone.

## Debug APK from GitHub Actions

`.github/workflows/android-debug.yml` runs on pushes to the session branch and
can also be started with `workflow_dispatch`. It uses Godot 4.4.1, Java 17,
Android SDK/build-tools 34, and the `Android Debug` preset. The runner creates
a temporary debug keystore and uploads `pixelfield-debug-apk` for 14 days after a
successful build. Download it from the workflow run's **Artifacts** section.

This is a **debug/test build only**, signed with an ephemeral Android debug
key. It is not a release package and must not be submitted to a store. It
contains the current client shell (menus and profile flow), not a playable
match; online sign-in/backend services and real-device behaviour are not
verified by exporting it. The package ID is `com.hexorastudio.hexora`, and the
preset currently includes arm64-v8a only.

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
adb install -r build/PixelField-release.apk
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

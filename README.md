# HEXORA

A tactical 3D online shooter for **Android** (and desktop, for development).
Team Deathmatch, Search & Destroy, Free For All and Battle Royale 30/50/100 —
online, in private rooms, or over a phone hotspot with **no internet at all**.

Built with **Godot 4.4 + GDScript**. The renderer is `mobile`, and the art
direction is deliberately *medium*: semi-realistic, clean, readable — not pixel
art, not low-poly, not a photoreal pipeline a small team cannot sustain on a
phone.

> **Current stage: 1 of 4 — the shell.** Sign-in (Google / guest), profile
> setup, the full main menu, settings, and a *working* hotspot lobby. There is
> no match yet; every screen that would need one says so out loud instead of
> pretending. See [`docs/ROADMAP.md`](docs/ROADMAP.md) for what lands when.

---

## What actually works today

| Area | State |
| --- | --- |
| Google Sign-In | Real OAuth 2.0 loopback + PKCE flow (`docs/AUTH_SETUP.md`). Guest mode is a first-class button, not a hidden fallback. |
| Profile setup | Callsign, region, avatar colour, live preview. Reachable with **no account at all**. |
| Main menu | Top bar (level, XP, currencies, presence), nav rail, eight pages, live status strip. |
| Settings | Six tabs: game, graphics, audio, controls, language, developer. Writes straight through — no Apply button, nothing to forget. |
| Language | English + Persian at runtime, full RTL mirroring, 510 keys verified for parity by CI. |
| **Hotspot rooms** | **Real.** Host opens an ENet server and broadcasts a UDP discovery beacon; joiners find it, connect, and appear in a live roster with real ping. Works with no router and no account. |
| Online rooms / matchmaking | Client, queue UI, ready check and all the plumbing are built; the backend does not exist yet, so these paths report that they are offline rather than inventing data. |
| Match gameplay | Not started. Phase 2. |

## Quick start

```bash
# 1. Engine: Godot 4.4 or newer (4.7.2 is the current stable release)
#    https://godotengine.org/download — no plugins, no native modules required.

# 2. Verify the tree before you open the editor (no Godot binary needed):
python3 tools/check_i18n.py     # string-table parity + placeholders
python3 tools/check_refs.py     # cross-file references, arity, theme, scenes
gdlint $(find src -name '*.gd') # style + syntax (pip install gdtoolkit)

# 3. Open the project, press F5. The boot screen runs the whole sign-in flow.

# 4. Optional: a local backend so the online paths light up
python3 tools/mock_server.py    # then set Developer ▸ Backend base URL
```

The game is fully playable *without* step 4: with no backend configured it runs
offline, and it says so in the status strip rather than showing a spinner.

## Repository layout

```
project.godot            engine config (autoloads, layers, renderer)
src/autoload/            the 14 services — see docs/ARCHITECTURE.md
src/core/                data types + the eight GameMode .tres resources
src/core/game_modes/     one file per ruleset; tuning lives here, not in code
src/audio/               procedural UI cue synthesis (no audio assets)
src/net/                 LAN discovery (UDP beacon) — the hotspot feature
src/ui/                  screens, pages, components, and the design system
src/i18n/                en + fa string tables (plain dictionaries, no import)
assets/                  fonts, brand mark, art direction notes
tools/                   CI-able checkers + a mock backend
docs/                    architecture, auth setup, roadmap, build steps
```

Everything visual is generated at runtime from `src/autoload/design.gd`: there
is no `.tres` theme to drift, and no UI image assets at all. Icons are drawn as
vectors, the backdrop is a generated hex lattice, UI sounds are synthesised —
which is why the whole repository is text.

## Documentation

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — services, signals, conventions, and *why*.
- [`docs/AUTH_SETUP.md`](docs/AUTH_SETUP.md) — make the Gmail button work, step by step.
- [`docs/ROADMAP.md`](docs/ROADMAP.md) — every requested feature mapped to a phase.
- [`docs/BUILD_ANDROID.md`](docs/BUILD_ANDROID.md) — export a signed APK / AAB, and the device-only gotchas.
- [`assets/art/README.md`](assets/art/README.md) — the art direction and the performance budget.
- [`assets/brand/README.md`](assets/brand/README.md) — logo files, palette, and the rules that keep them consistent.
- [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) — every font and tool that is not ours, and its licence.

## Testing the hotspot feature

Discovery uses a fixed UDP port, so the *first* thing to try is two copies of the
game on one machine:

```bash
# 1. Run the project once, create a hotspot room, leave it open.
# 2. Run a second instance — a different export or `godot --path .` twice.
# 3. On the second instance: Rooms ▸ Browse ▸ Discover.
```

If both instances are browsing, the second one silently moves to the fallback
port (`45711`) and the browse tab says so. A blank list on two *real* phones
almost always means the hotspot is dropping broadcast packets — that is what the
"No discovery?" copy and the manual address field in Rooms ▸ Join are for.

## Credits

Chakra Petch (display) and Vazirmatn (Persian UI + body) — both SIL Open Font
License 1.1, full text in [`assets/fonts/OFL-NOTICE.txt`](assets/fonts/OFL-NOTICE.txt).
The complete list of third-party work is in
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

## License

The project code is © HEXORA Studio. No license is granted for redistribution
yet — pick one (`LICENSE`) before publishing a build. Third-party assets carry
their own licenses; see [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) and
each asset folder's README.

---

### خلاصهٔ فارسی

**HEXORA** یک شوتر سه‌بعدی آنلاین برای اندروید است: تیم‌دث‌مچ، جست‌وجو و نابودی،
همه‌دربرابرهمه و بتل‌رویال ۳۰/۵۰/۱۰۰ نفره — آنلاین، در روم خصوصی، یا با
هات‌اسپات گوشی و **بدون نیاز به اینترنت**. با Godot 4.4 و زبان GDScript ساخته
شده و گرافیک آن «متوسط و متعادل» است: نیمه‌واقع‌گرا و خوانا، نه پیکسلی و نه
فوق‌واقع‌گرا.

**مرحلهٔ فعلی: ۱ از ۴ — پوستهٔ بازی.** ورود با گوگل و حالت مهمان، صفحهٔ ساخت
پروفایل، منوی اصلی کامل، تنظیمات (شش تب) و زبان فارسی با راست‌به‌چپ کامل. روم
هات‌اسپات **واقعاً کار می‌کند**: میزبان سرور را روی گوشی بالا می‌آورد و بقیه از
طریق شبکهٔ محلی پیدا می‌کنند و به فهرست بازیکنان اضافه می‌شوند. صف آنلاین و
روم آنلاین ساخته شده‌اند اما چون هنوز سروری وجود ندارد، صادقانه می‌گویند
«آفلاین» و داده‌ی الکی نشان نمی‌دهند. گیم‌پلی مرحلهٔ ۲ است.

برای اجرا: پروژه را با Godot 4.4 یا بالاتر باز کن و F5 را بزن. برای بررسی
سالم بودن کد بدون نصب گودو، `python3 tools/check_refs.py` و
`python3 tools/check_i18n.py` را اجرا کن.

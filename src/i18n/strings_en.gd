extends RefCounted
## English-only string table (source of truth for the client UI).
##
## Why a dictionary instead of .po files? Because it cannot silently fail.
## The GDScript table is validated by `tools/check_i18n.py` at review time and
## ships directly in the client without a separate translation import step.
## The current product UI is English-only; named interpolation is handled by
## `Loc.t()`.
##
## Rules:
##   * Keys are `area.thing` and lower snake case.
##   * `{placeholder}` tokens are filled by Loc.t(key, args). Use named tokens,
##     not positional indices, so call sites stay self-documenting.

const TABLE := {
	# ---------------------------------------------------------------- meta
	"app.name": "PixelLegends",
	"app.tagline": "Choose a legend. Fight as one.",
	"app.version_label": "Version {version}",
	"app.build": "Build {build}",

	# -------------------------------------------------------------- common
	"common.ok": "OK",
	"common.cancel": "Cancel",
	"common.close": "Close",
	"common.back": "Back",
	"common.next": "Next",
	"common.confirm": "Confirm",
	"common.retry": "Retry",
	"common.refresh": "Refresh",
	"common.copy": "Copy",
	"common.copied": "Copied to clipboard",
	"common.search": "Search",
	"common.loading": "Loading…",
	"common.soon": "Coming soon",
	"common.phase_two": "Arrives in phase 2",
	"common.locked": "Locked",
	"common.leave": "Leave",
	"common.join": "Join",
	"common.create": "Create",
	"common.invite": "Invite",
	"common.share": "Share",
	"common.start": "Start",
	"common.send": "Send",
	"common.apply": "Apply",
	"common.reset": "Reset",
	"common.enabled": "On",
	"common.disabled": "Off",
	"common.yes": "Yes",
	"common.no": "No",
	"common.none": "None",
	"common.empty": "Nothing here yet",
	"common.online": "Online",
	"common.offline": "Offline",
	"common.you": "You",
	"common.level_short": "LVL {level}",
	"common.level": "Level",
	"common.players": "Players",
	"common.mode": "Mode",
	"common.map": "Map",
	"common.host": "Host",
	"common.max": "Max",
	"common.ping": "Ping",
	"common.ping_ms": "{ms} ms",
	"common.seconds_short": "{value}s",
	"common.minutes_short": "{value}m",
	"common.optional": "optional",
	"common.required": "required",
	"common.never": "Never",
	"common.unknown": "Unknown",
	"common.dismiss": "Dismiss",

	# ---------------------------------------------------------------- auth
	"auth.login.guest_hint": "No account needed. Progress stays on this device only.",

	"auth.state.signing_in": "Signing you in…",

	"auth.setup.callsign": "Player name",

	"auth.signout": "Sign out",
	"auth.guest.badge": "Guest",

	# ---------------------------------------------------------------- boot
	"splash.choose_path": "Choose your path",
	"splash.saved_account_unavailable": "This saved account cannot be opened in this visual-only build yet.",
	"splash.play": "Play",
	"splash.login.google": "Login With Google",
	"splash.login.guest": "Login As Guest",

	# ---------------------------------------------------------------- menu
	"menu.settings": "Settings",

	# ------------------------------------------------------------- battle hub
	"home.preview_badge": "UI PREVIEW · FEATURES IN DEVELOPMENT",
	"home.explore": "Explore",
	"home.modes": "5V5 ARENA",
	"home.heroes": "HEROES",
	"home.squad": "SQUAD",
	"home.collection": "COLLECTION",
	"home.feature_note": "Battle features will arrive one at a time in future updates.",
	"home.spotlight": "HERO SPOTLIGHT",
	"home.spotlight_title": "Your legend awaits",
	"home.spotlight_body": "Hero selection is a placeholder for a future update.",
	"home.battle_title": "THE ARENA IS BEING PREPARED",
	"home.battle_subtitle": "Original 5v5 team battles are planned for PixelLegends.",
	"home.battle_button": "PLAY 5V5",
	"home.coming_soon": "COMING SOON",
	"home.edit_name": "EDIT NAME",
	"home.edit_name_short": "EDIT",
	"home.guest_profile": "LOCAL GUEST PROFILE",
	"home.linked_profile": "LINKED ACCOUNT",
	"home.edit_title": "Edit your player name",
	"home.edit_hint": "Use 3–16 letters, numbers or underscores. Your name is saved on this device.",
	"home.edit_placeholder": "Enter a player name",
	"home.edit_save": "SAVE NAME",
	"home.edit_invalid": "Use 3–16 letters, numbers or underscores.",
	"home.edit_saved": "Player name updated.",

	# ------------------------------------------------------------- profile
	"profile.account": "Account",

	# ------------------------------------------------------------ settings
	"settings.title": "Settings",
	"settings.subtitle": "Tune the game to your device.",
	"settings.tab.game": "Game",
	"settings.tab.graphics": "Graphics",
	"settings.tab.audio": "Audio",

	"settings.show_ping": "Show ping during matches",
	"settings.show_fps": "Show FPS counter",
	"settings.vibration": "Haptic feedback",
	"settings.keep_screen_on": "Keep the screen awake",
	"settings.streamer_mode": "Hide player names (streamer mode)",

	"settings.graphics.quality": "Quality preset",
	"settings.graphics.quality.low": "Battery saver",
	"settings.graphics.quality.medium": "Balanced",
	"settings.graphics.quality.high": "High",
	"settings.graphics.quality.ultra": "Maximum",
	"settings.graphics.resolution_scale": "Render scale",
	"settings.graphics.fps": "Frame rate limit",
	"settings.graphics.shadows": "Shadows",
	"settings.graphics.shadow_quality": "Shadow quality",
	"settings.graphics.aa": "Anti-aliasing",
	"settings.graphics.aa.off": "Off",
	"settings.graphics.aa.fxaa": "FXAA",
	"settings.graphics.aa.msaa2": "MSAA 2×",
	"settings.graphics.aa.msaa4": "MSAA 4×",
	"settings.graphics.decals": "Bullet decals",
	"settings.graphics.bloom": "Bloom",
	"settings.graphics.ragdolls": "Ragdoll physics",
	"settings.graphics.hud_scale": "HUD scale",
	"settings.graphics.note_fps": "Battery saver targets 30 FPS and cuts dynamic shadows.",
	"settings.graphics.device_hint": "Detected tier: {tier}",

	"settings.audio.master": "Master",
	"settings.audio.music": "Music",
	"settings.audio.sfx": "Effects",
	"settings.audio.ui": "Interface",
	"settings.audio.voice": "Voice chat",
	"settings.audio.mic": "Microphone",
	"settings.audio.mic_push": "Push to talk",
	"settings.audio.test": "Test tone",
	"settings.audio.muted_when_bg": "Mute when the app is in the background",

	# ---------------------------------------------------------------- ranks
	"rank.bronze": "Bronze",
	"rank.silver": "Silver",
	"rank.gold": "Gold",
	"rank.platinum": "Platinum",
	"rank.diamond": "Diamond",
	"rank.ascendant": "Ascendant",
	"rank.hexcore": "Hexcore Elite",

	# --------------------------------------------------------------- toasts
	"toast.signed_out": "Signed out",
	"toast.guest_banner": "Playing as a guest — progress is local only",
	"toast.copied_clipboard": "{label} copied",

}

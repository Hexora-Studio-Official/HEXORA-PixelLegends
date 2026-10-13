class_name GameTypes
extends RefCounted
## Central enum warehouse for PixelLegends and retained legacy data.
##
## Every enum that crosses a module boundary lives here so that signals,
## services and UI can stay strongly typed without the autoloads having to
## reference each other. Keeping them in one file also means a reader can
## answer "what states exist in this game?" by opening exactly one file.
##
## Rules:
##   * Never reorder existing values — they are persisted in save files and
##     sent over the wire. Only append.
##   * Anything sent over the network is an `int`, never a raw enum reference.


## Lifecycle of the local account. Drives which screen the Router shows.
enum AuthState {
	UNKNOWN,        ## Boot: we have not looked at the stored token yet.
	RESTORING,      ## Reading user://session.cfg and validating the token.
	SIGNED_OUT,     ## No usable session.
	SIGNING_IN,     ## Google / guest flow in progress.
	SIGNED_IN,      ## We have a profile and a valid session.
	FAILED,         ## Last attempt failed; `Auth.last_error` explains why.
	SIGNING_OUT,    ## Tearing the session down.
	## Appended on purpose: the other values are persisted in
	## `user://session.cfg` and must never shift.
}

## How the current profile got here. Also decides what the UI may show:
## a guest profile has no cloud progression and is warned about it.
enum AuthProvider {
	NONE,
	GOOGLE,
	DEV,            ## Offline developer account (never leaves the device).
}

## Coarse region buckets used by matchmaking and by the room browser.
enum Region {
	ASIA,
	EUROPE,
	NORTH_AMERICA,
	SOUTH_AMERICA,
	MIDDLE_EAST,
	OCEANIA,
	AUTO,           ## Pick the lowest-ping bucket at queue time.
}

## Where a connection physically comes from. Shown as a trust badge, because
## "hotspot" and "dedicated server" have very different anti-cheat stories.
enum Transport {
	NONE,
	LAN_HOTSPOT,    ## Phone-to-phone over Wi-Fi Direct / hotspot, no internet.
	LAN_WIFI,       ## Both devices on the same normal Wi-Fi router.
	P2P_HOST,       ## One player's device is the authoritative host, online.
	DEDICATED,      ## Studio-hosted server. Competitive play.
}

## Matchmaking lifecycle for the local player.
enum MatchmakingState {
	IDLE,
	SEARCHING,
	FOUND,
	CONNECTING,
	IN_MATCH,
}

## High level phase of a live match. Drives HUD, music and input mode.
enum MatchPhase {
	LOBBY,
	WARMUP,
	COUNTDOWN,
	LIVE,
	INTERMISSION,
	OVERTIME,
	RESULTS,
}

## Which side a player is on. FFA and solo BR use NONE.
enum Team {
	NONE,
	ALPHA,
	BRAVO,
}

## Room visibility for the custom-room browser.
enum RoomVisibility {
	PUBLIC,         ## Anyone may join from the browser.
	FRIENDS,        ## Joinable by invite code / friend list only.
	PRIVATE,        ## Invite code required, never listed.
}

## Room lifecycle.
enum RoomState {
	FORMING,
	READY,
	IN_MATCH,
	CLOSED,
}

## What a room is advertising itself as, over LAN discovery.
enum DiscoveryState {
	STOPPED,
	ADVERTISING,    ## We are hosting and shouting our presence out.
	SCANNING,       ## We are looking for somebody else's room.
	ERROR,
}

## Coarse ping quality used for the little coloured bars in the UI.
enum PingQuality {
	UNKNOWN,
	EXCELLENT,
	GOOD,
	FAIR,
	POOR,
}

## Sound categories; the Settings screen exposes one slider per entry.
enum AudioChannel {
	MASTER,
	MUSIC,
	SFX,
	UI,
	VOICE,
}

## Individual keybindable actions. Mapped to Godot InputMap actions in
## `src/autoload/controls.gd`.
##
## Order is the save/wire order; append only. `GAME_ACTION_SLUGS` below is
## index-parallel with this enum and is what the controls service builds the
## InputMap action names from.
enum GameAction {
	MOVE_FORWARD,
	MOVE_BACK,
	MOVE_LEFT,
	MOVE_RIGHT,
	SPRINT,
	CROUCH,
	JUMP,
	FIRE,
	AIM,
	RELOAD,
	MELEE,
	GRENADE,
	INTERACT,
	SCOREBOARD,
	MAP,
	PING,
}

## Snake-case slug for every entry of `GameAction`, in enum order.
##
## Written out rather than derived from the enum at runtime: GDScript enums are
## backed by a Dictionary, but its key order is not a language contract, and an
## input action silently bound to the wrong limb is a bug that only surfaces in
## a live match. Index-parallel with `GameAction` — append to both, together.
const GAME_ACTION_SLUGS: Array[StringName] = [
	&"move_forward", &"move_back", &"move_left", &"move_right",
	&"sprint", &"crouch", &"jump", &"fire",
	&"aim", &"reload", &"melee", &"grenade",
	&"interact", &"scoreboard", &"map", &"ping",
]


## Slug for an action index, clamped so that a corrupt settings file cannot
## index out of bounds during boot and take the whole input layer down.
static func action_slug(action: int) -> StringName:
	if action < 0 or action >= GAME_ACTION_SLUGS.size():
		push_warning("GameTypes.action_slug: %d out of range." % action)
		return GAME_ACTION_SLUGS[0]
	return GAME_ACTION_SLUGS[action]


## Every slug, in enum order — the canonical iteration order for the controls
## settings page and for `Controls.register_actions()`.
static func action_slugs() -> Array[StringName]:
	return GAME_ACTION_SLUGS.duplicate()


## Human readable key for a Region, resolved through Loc.
static func region_key(region: Region) -> StringName:
	match region:
		Region.ASIA: return &"region.asia"
		Region.EUROPE: return &"region.europe"
		Region.NORTH_AMERICA: return &"region.north_america"
		Region.SOUTH_AMERICA: return &"region.south_america"
		Region.MIDDLE_EAST: return &"region.middle_east"
		Region.OCEANIA: return &"region.oceania"
		_: return &"region.auto"


## Order used by the region picker. `AUTO` is always first.
static func selectable_regions() -> Array[Region]:
	return [
		Region.AUTO,
		Region.MIDDLE_EAST,
		Region.ASIA,
		Region.EUROPE,
		Region.NORTH_AMERICA,
		Region.SOUTH_AMERICA,
		Region.OCEANIA,
	]


## Bucket a raw millisecond reading so the UI does not flicker on noise.
static func ping_quality(ping_ms: int) -> PingQuality:
	if ping_ms <= 0:
		return PingQuality.UNKNOWN
	if ping_ms < 60:
		return PingQuality.EXCELLENT
	if ping_ms < 110:
		return PingQuality.GOOD
	if ping_ms < 180:
		return PingQuality.FAIR
	return PingQuality.POOR


## Colour for a ping reading. Kept here (not in Design) because gameplay
## code — scoreboards, kill feed — also needs it and must not depend on UI.
static func ping_color(quality: PingQuality) -> Color:
	match quality:
		PingQuality.EXCELLENT: return Color("83d43d")
		PingQuality.GOOD: return Color("49bdff")
		PingQuality.FAIR: return Color("ff9f28")
		PingQuality.POOR: return Color("f4513c")
		_: return Color("9eb5bb")


## Stable team accent colours shared by world markers and the HUD.
static func team_color(team: Team) -> Color:
	match team:
		Team.ALPHA: return Color("42b7ff")
		Team.BRAVO: return Color("f45b42")
		_: return Color("fff8e8")


static func team_key(team: Team) -> StringName:
	match team:
		Team.ALPHA: return &"team.alpha"
		Team.BRAVO: return &"team.bravo"
		_: return &"team.none"

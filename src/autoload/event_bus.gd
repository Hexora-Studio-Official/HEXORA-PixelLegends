extends Node
## Global signal hub.
##
## Systems never hold references to each other's UI. A service announces that
## something happened; whoever cares subscribes. That keeps the menu screen
## and the (future) match scene swappable without touching the services, and
## it keeps autoloads free of circular dependencies.
##
## Convention: past tense for things that happened, `*_changed` for state,
## `*_requested` for intent that a listener is expected to fulfil.
##
## Payloads are primitives, Dictionaries or core Resources (`PlayerProfile`,
## `RoomInfo`, `GameMode`). Never pass a Node through the bus — that would
## re-couple the modules this exists to keep apart.

# ------------------------------------------------------------------ lifecycle
## Emitted once all services finished booting. Boot screen waits for this.
signal services_ready()

# ----------------------------------------------------------------------- auth
## GameTypes.AuthState
signal auth_state_changed(state: int)
signal auth_signed_in(profile: PlayerProfile)
signal auth_signed_out()
signal auth_failed(message: String)

# -------------------------------------------------------------------- session
signal profile_changed(profile: PlayerProfile)
signal profile_persisted()

# ------------------------------------------------------------------- settings
## The section that changed, e.g. "graphics" — listeners re-read Settings.
signal settings_changed(section: StringName)
signal graphics_settings_applied()
signal language_changed(locale: String)

# ---------------------------------------------------------------- matchmaking
## GameTypes.MatchmakingState
signal matchmaking_state_changed(state: int)
signal matchmaking_tick(elapsed: float, eta: float, players: int, expanding: bool)
signal matchmaking_found(ticket: Dictionary)
signal matchmaking_cancelled()

# ---------------------------------------------------------------------- rooms
signal room_created(room: RoomInfo)
signal room_updated(room: RoomInfo)
signal room_closed(reason: String)
signal room_list_changed(rooms: Array)
## GameTypes.DiscoveryState, human-readable status
signal discovery_state_changed(state: int, message: String)
signal lan_room_seen(room: RoomInfo)

# -------------------------------------------------------------------- friends
signal friends_changed(friends: Array)
signal friend_requests_changed(requests: Array)
signal party_changed(party: Array)
signal room_invite_received(invite: Dictionary)

# ------------------------------------------------------------------- presence
signal network_availability_changed(online: bool)

# ------------------------------------------------------------------------- ui
## kind: "info" | "success" | "warning" | "error"
signal toast_requested(message: String, kind: StringName)
signal route_changed(route: StringName)
signal loading_started(label: String)
signal loading_finished()

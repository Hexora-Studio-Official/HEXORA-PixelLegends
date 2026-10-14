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
## Payloads are primitives, Dictionaries or core Resources (`PlayerProfile`).
## Never pass a Node through the bus — that would re-couple the modules this
## exists to keep apart.
##
## Scope note (2026-10-14): the matchmaking, room, LAN-discovery, friend and
## party signals were removed along with the services that emitted them. A
## signal nobody emits and nobody listens to is not architecture, it is debt;
## the MOBA phases in docs/PROJECT_SPEC.txt will add back what they need.

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

# ------------------------------------------------------------------------- ui
## kind: "info" | "success" | "warning" | "error"
signal toast_requested(message: String, kind: StringName)
signal route_changed(route: StringName)
signal loading_started(label: String)
signal loading_finished()

class_name GameTypes
extends RefCounted
## Central enum warehouse for PixelLegends.
##
## Every enum that crosses a module boundary lives here so that signals,
## services and UI can stay strongly typed without the autoloads having to
## reference each other. Keeping them in one file also means a reader can
## answer "what states exist in this game?" by opening exactly one file.
##
## Rules:
##   * Never reorder existing values — they are persisted in save files.
##     Only append.
##   * Anything sent over the network is an `int`, never a raw enum reference.
##
## Scope note (2026-10-14): this file now carries only the enums the current
## client shell actually uses. The earlier shooter-era enums (regions,
## transports, matchmaking/match phases, room visibility and state, LAN
## discovery, ping buckets and the first-person keybindable actions) were
## removed together with the services that consumed them. The MOBA phases in
## docs/PROJECT_SPEC.txt will reintroduce what they need, when something
## really uses it — an enum kept "just in case" is a design decision nobody
## made.


## Lifecycle of the local account. Drives which screen the Router shows.
enum AuthState {
	UNKNOWN,        ## Boot: we have not looked at the stored token yet.
	RESTORING,      ## Reading user://auth.cfg and validating the credential.
	SIGNED_OUT,     ## No usable session.
	SIGNING_IN,     ## Guest flow in progress.
	SIGNED_IN,      ## We have a local profile and a session.
	FAILED,         ## Last attempt failed; `Auth.last_error` explains why.
	SIGNING_OUT,    ## Tearing the session down.
	## Appended on purpose: the other values are persisted in
	## `user://auth.cfg` and must never shift.
}

## How the current profile got here. Also decides what the UI may show:
## a guest profile has no cloud progression and is warned about it.
enum AuthProvider {
	NONE,
	GOOGLE,         ## Reserved for the Nakama-backed Google phase; unused today.
	DEV,            ## Offline developer account (never leaves the device).
}

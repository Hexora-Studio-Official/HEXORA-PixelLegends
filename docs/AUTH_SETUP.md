# Google Sign-In — setup

The login screen's **Continue with Google** button is a real OAuth 2.0 flow, not
a mock-up. This document is what you have to do in the Google Cloud Console
before it will work, plus the security rule that decides whether it is allowed
to gate anything.

You can skip all of this and still use the whole app: **Continue as guest**
works on a fresh install with no configuration, and the Developer settings tab
is reachable from the login screen, so the client ID can be pasted in without
signing in first.

---

## 1. Create the OAuth client

1. <https://console.cloud.google.com/> → create (or pick) a project.
2. **APIs & Services ▸ OAuth consent screen** → *External* → fill in the app
   name, your support email, and the developer contact. Add the scopes
   `openid`, `email`, `profile`. Publish it, or add yourself as a *test user*
   while it is in testing mode.
3. **APIs & Services ▸ Credentials ▸ Create credentials ▸ OAuth client ID**
   → application type **Desktop app**. (Yes, even for Android — see §4.)
4. Copy the **Client ID**. Copy the **Client secret** too; Google wants it at the
   token endpoint even for a public client, and PixelField will send it if you paste
   it in.

## 2. Tell PixelField about it

In the game: **Settings ▸ Developer** (the gear button, top right of the main
menu — or the gear on the login screen before you sign in).

| Field | Value |
| --- | --- |
| Google OAuth client ID | the `....apps.googleusercontent.com` string |
| Google OAuth client secret | the `GOCSPX-...` string (optional, see below) |
| Expected redirect URI | **read-only** — copy the value shown and register it in the console |

The redirect URI is `http://127.0.0.1:8712/` by default. Register it under
**Authorized redirect URIs** on the OAuth client. For loopback redirects Google
ignores the port, so `http://127.0.0.1:8712/` also covers the fallback ports
PixelField tries if 8712 is busy. If you would rather not think about it, register
`http://127.0.0.1/` and `http://localhost/` as well.

> **Why the client secret is in a client.** For an installed app it is not a
> secret: it ships inside every copy of the APK. PKCE is what actually protects
> the exchange (the code is useless without the one-time verifier, which never
> leaves the device). Google still requires the field for this client type,
> which is why the setting exists — paste it if the exchange fails with
> `invalid_request: client_secret is missing`, leave it empty otherwise.

## 3. How the flow works

```
┌─────────┐  1. generate PKCE verifier + challenge
│ PixelField  │  2. TCPServer.listen(127.0.0.1:8712)
│ (phone) │  3. OS.shell_open(auth URL)
└────┬────┘
     │ 4. browser → accounts.google.com (user signs in)
     │ 5. Google → 302 http://127.0.0.1:8712/?code=...&state=...
     ▼
┌─────────┐  6. read the loopback socket, answer with a "you can close this" page
│ PixelField  │  7. POST /token {code, code_verifier, redirect_uri, [client_secret]}
│         │  8. GET /v1/userinfo with the access token
│         │  9. hand {sub, email, name, picture, id_token} to AuthService
└─────────┘
```

Nothing leaves the device except the two requests to Google. There is no
intermediate server, no embedded browser, and the `state` parameter is checked
on the way back so a stray request cannot be mistaken for a real one.

The implementation lives in `src/core/auth/google_signin.gd` and is documented
line by line; `AuthService` is the only thing the UI talks to, which is why
swapping this for the native Android SDK later touches no screen.

## 4. Android specifics

**This is the part worth reading twice.**

- Google's current guidance for Android apps is the native *Google Sign-In SDK*
  with an **Android app** OAuth client (package name + SHA-1 signing
  fingerprint). That needs a Godot Android plugin.
- The loopback flow used here needs a **Desktop app** client. It is the current
  prototype flow and is intended to work on desktop; Android behaviour depends
  on the browser/OEM and has not been device-validated in this checkout.
- Google Play policy does not forbid it, but the native SDK gives you better
  UX (no browser switch) and Android's credential manager. Treat swapping it in
  as a later, separately approved release-readiness task: `AuthService` is the
  seam, and no screen changes should be needed.

Whichever client type you use, `dev/google_client_id` is a per-install setting:
a build for a friend needs it configured on their install or baked in as a
default. For a release, bake it in — `Settings.default_of("dev/google_client_id")`.

## 5. The rule that actually matters

**The `id_token` must be verified on the server.**

The client cannot verify it: the client is the thing being trusted. A modified
APK can hand `AuthService` any account dictionary it likes — that is true of
every OAuth client that ever shipped, and it is why
`AuthService.unverified_remote` exists.

What PixelField does about it today:

- With no backend configured, the Google account becomes a **local-only
  profile** (`uid = "google-local-<sub>"`), `unverified_remote` is set, and the
  game says *"Signed in on this device — the backend has not confirmed this
  account yet"* on screen.
- That profile is fine for progression on that device and **must never** be
  trusted for anything valuable: purchases, rankings, inventoring, or access to
  another player's data.
- When the backend lands, `POST /v1/auth/google {id_token}` returns the
  authoritative profile. The server must check the signature against Google's
  JWKS, the `aud` claim, `iss`, `exp`, and that the account is not banned, before
  it returns anything.

**Stage 1 blocker for a real backend:** static review found that
`src/autoload/auth_service.gd` currently saves the Google OAuth access token
where the backend session token should be saved, and its remote-profile merge
is overwritten by a newly created local profile. Do not treat the configured
client flow as production-ready until both behaviours are fixed and tested
against a verifying backend. No live credentials or backend are included here.

## 6. Backend contract (future private-online/auth stages)

```
POST /v1/auth/google
  { "id_token": "<JWT>", "callsign": "Nova", "region": 4 }
→ 200 { "uid": "...", "access_token": "<session>", "display_name": "...",
        "level": 12, "rank_points": 1180, "credits": 2500, "cores": 120, ... }
→ 401 { "error": "invalid_token" }
```

`access_token` is the backend's own session token. It is what `Api.auth_token`
carries afterwards; the Google token is never reused as a session.

## 7. Troubleshooting

| Symptom | Cause |
| --- | --- |
| `redirect_uri_mismatch` | The URI in Developer settings is not registered on the client. Copy it exactly. |
| `invalid_request: client_secret is missing` | Paste the client secret in Developer settings. |
| The browser opens, nothing happens | Port 8712 is blocked or the redirect went to a different interface. Try again — PixelField walks up to 12 ports and reports the URI it actually used. |
| `access_denied` | The consent screen is in testing mode and your account is not a test user. |
| Works on desktop, not on the phone | Some Android builds hand loopback redirects to the *browser*, not the app. Use the native SDK client (see §4) for production. |
| Signs in, then says "not confirmed" | Working as intended: no backend is configured, so the account is local-only (§5). |

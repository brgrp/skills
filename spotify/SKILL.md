---
name: spotify
description: |
  Control Spotify playback via CLI. Requires Spotify Premium for playback control.
  USE FOR: play song, play music, play [song name], play [artist], play [album], play [playlist], pause, stop music, resume, skip, next song, previous song, what's playing, now playing, current song, volume up, volume down, set volume, shuffle on, shuffle off, repeat, queue, add to queue, list devices, transfer playback, play on [device].
  DO NOT USE FOR: downloading music, editing playlists, creating playlists.
license: MIT
metadata:
  author: brgrp
  version: "0.5.0"
compatibility: Requires Spotify Premium for playback. Needs curl, jq, and openssl. python3 is only the login listener on 127.0.0.1:17823.
---

# Spotify Control

**When activated, get music playing. Check auth first — do not ask the user to read setup docs.**

Never print Client Secret, access/refresh tokens, or callback URLs that contain `code=` into chat. `spotify-auth.sh token` is for scripts only.

All commands below assume this skill folder (`./scripts/...`). From the `git/skills` repo root, use `./spotify/scripts/...` instead.

## Step 0 — Auth preflight (mandatory)

```bash
./scripts/spotify-auth.sh status
```

- Authenticated → continue.
- Not authenticated → run **First-time auth** below. Do not search/play until status is OK.

### First-time auth (agent runs this)

1. **Ensure a Spotify app exists** (one-time per user). If the user has no Client ID/Secret yet, tell them exactly:
   - Open https://developer.spotify.com/dashboard → Create App → Web API
   - Redirect URI must be exactly: `http://127.0.0.1:17823/callback`
   - Copy **Client ID** and **Client Secret**
   - Playback needs **Spotify Premium**; open the Spotify app on a device before playing

2. **Collect credentials** — ask the user for Client ID and Client Secret (do not invent them). Then save:

```bash
mkdir -p ~/.config/spotify && chmod 700 ~/.config/spotify
(umask 077 && jq -n --arg id 'PLACEHOLDER_CLIENT_ID' --arg secret 'PLACEHOLDER_CLIENT_SECRET' \
  '{client_id:$id, client_secret:$secret}' > ~/.config/spotify/credentials.json)
```

Or export `SPOTIFY_CLIENT_ID` and `SPOTIFY_CLIENT_SECRET` for this shell only.

3. **Start OAuth.**

On the same machine as the browser:

```bash
./scripts/spotify-auth.sh login
```

Open **`http://127.0.0.1:17823/`** (do not paste the long authorize URL; `&` gets truncated). Approve access.

From a remote machine or sandbox, `login` prints an authorize URL instead of listening. The user opens that URL, approves, and copies the address bar after the failed redirect to `127.0.0.1`. Then:

```bash
./scripts/spotify-auth.sh login --callback 'PASTED_URL'
./scripts/spotify-auth.sh status
```

4. If login fails with missing credentials, you skipped step 2 — ask again. If callback times out, re-run `login` and ensure the redirect URI matches exactly.

## One CLI: `spotify.sh`

```bash
./scripts/spotify.sh search "bohemian rhapsody" --type track
./scripts/spotify.sh play "spotify:track:xxx" --device "Kitchen Echo"
./scripts/spotify.sh pause|resume|next|prev
./scripts/spotify.sh now|queue|devices
./scripts/spotify.sh device "Echo Wohnzimmer"    # default device
./scripts/spotify.sh transfer "Echo Wohnzimmer"
./scripts/spotify.sh volume 50|up|down
./scripts/spotify.sh shuffle on|off
./scripts/spotify.sh repeat track|context|off
./scripts/spotify.sh seek 60
./scripts/spotify.sh add-queue spotify:track:xxx
```

Infer `--type` from the user (`track` / `playlist` / `album` / `artist`). Default `track` if unsure. `"song by artist"` is a normal track search (e.g. `bohemian rhapsody by queen`).

| `match` / `status` | Agent action |
|--------------------|--------------|
| `auto` | Report **title, artist, device, volume** from the response `now` object (no extra `now` call). If volume is under ~15, warn it may be inaudible |
| `unclear` | Pick best `results[]` URI, or ask if ambiguous; then `play`. Mood / "something else" / "more like that" stay unclear — do not invent a playlist |
| `none` | Tell user nothing found |
| `status: error` | Follow `code` + `solution` (table below). `AUTH_*` → Step 0 |

Short/ambiguous queries stay `unclear` (e.g. `"rock"`). Do not force auto-play.

`now` returns JSON: `status` (`playing`/`paused`/`none`), `name`, `artist`, `album`, `device`, `volume`. Prefer `search`/`play`/`next` output `now` when present.

`next` after a single-track play may stay on the same song; use album/playlist context or `add-queue` when skip must advance.

## Errors

Stdout JSON on failure: `{"status":"error","code":"...","error":"...","solution":"..."}` (human text on stderr).

| Code | Agent next step |
|------|-----------------|
| `AUTH_REQUIRED` / `AUTH_EXPIRED` | Step 0 (save credentials if needed, then `login`) |
| `PREMIUM_REQUIRED` | Tell user Premium is required |
| `NO_DEVICE` | Ask user to open Spotify on a device; `devices` / `--device` / `device NAME` |
| `DEVICE_NOT_FOUND` | List devices; ask which name |
| `INVALID_URI` | Fix URI shape `spotify:track:<id>` (or playlist/album/artist) |
| `SEARCH_FAILED` / `API_ERROR` | Retry or rephrase |

## Files

`~/.config/spotify/` (`credentials.json`, `tokens.json`, `config.json`) — mode 700/600. Tokens refresh automatically.

Deps: `curl`, `jq`, `openssl`. `python3` only for `login` (loopback redirect).

`spotify-play.sh` / `spotify-ctl.sh` are thin compatibility wrappers around `spotify.sh`.

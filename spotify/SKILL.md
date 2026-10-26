---
name: spotify
description: |
  Control Spotify playback via CLI. Requires Spotify Premium for playback control.
  USE FOR: play song, play music, play [song name], play [artist], play [album], play [playlist], pause, stop music, resume, skip, next song, previous song, what's playing, now playing, current song, volume up, volume down, set volume, shuffle on, shuffle off, repeat, queue, add to queue, list devices, transfer playback, play on [device].
  DO NOT USE FOR: downloading music, editing playlists, creating playlists.
license: MIT
metadata:
  author: brgrp
  version: "0.4.0"
compatibility: Requires Spotify Premium for playback. Needs curl, jq, and openssl. python3 is only the login listener on 127.0.0.1:17823.
---

# Spotify Control

**When activated, get music playing. Check auth first — do not ask the user to read setup docs.**

Never print Client Secret, access/refresh tokens, or callback URLs that contain `code=` into chat. `spotify-auth.sh token` is for scripts only.

All commands below assume repo root. From this skill folder, use `./scripts/...` instead of `./spotify/scripts/...`.

## Step 0 — Auth preflight (mandatory)

```bash
./spotify/scripts/spotify-auth.sh status
```

- Authenticated → continue to Play.
- Not authenticated → run **First-time auth** below, then continue. Do not search/play until status is OK.

### First-time auth (agent runs this)

1. **Ensure a Spotify app exists** (one-time per user). If the user has no Client ID/Secret yet, tell them exactly:
   - Open https://developer.spotify.com/dashboard → Create App → Web API
   - Redirect URI must be exactly: `http://127.0.0.1:17823/callback`
   - Copy **Client ID** and **Client Secret**
   - Playback needs **Spotify Premium**; open the Spotify app on a device before playing

2. **Collect credentials** — ask the user for Client ID and Client Secret (do not invent them). Then save:

```bash
mkdir -p ~/.config/spotify && chmod 700 ~/.config/spotify
# Replace PLACEHOLDERS with the values the user provided:
(umask 077 && jq -n --arg id 'PLACEHOLDER_CLIENT_ID' --arg secret 'PLACEHOLDER_CLIENT_SECRET' \
  '{client_id:$id, client_secret:$secret}' > ~/.config/spotify/credentials.json)
```

Or export `SPOTIFY_CLIENT_ID` and `SPOTIFY_CLIENT_SECRET` for this shell only.

3. **Start OAuth.**

On the same machine as the browser:

```bash
./spotify/scripts/spotify-auth.sh login
```

Open **`http://127.0.0.1:17823/`** (do not paste the long authorize URL; `&` gets truncated). Approve access.

From a remote machine or sandbox, `login` prints an authorize URL instead of listening. The user opens that URL, approves, and copies the address bar after the failed redirect to `127.0.0.1`. Then:

```bash
./spotify/scripts/spotify-auth.sh login --callback 'PASTED_URL'
```

```bash
./spotify/scripts/spotify-auth.sh status
```

4. If login fails with missing credentials, you skipped step 2 — ask again. If callback times out, re-run `login` and ensure the redirect URI matches exactly.

## Play

```bash
./spotify/scripts/spotify-play.sh search "bohemian rhapsody" --type track
```

Infer `--type` from the user (`track` / `playlist` / `album` / `artist`). Default `track` if unsure. `"song by artist"` is a normal track search (e.g. `bohemian rhapsody by queen`).

| `match` / `status` | Agent action |
|--------------------|--------------|
| `auto` | Confirm with `now` — report **title, artist, device, volume**. If volume is very low (under ~15), warn it may be inaudible |
| `unclear` | Pick best `results[]` URI, or ask if ambiguous; then `play`. Mood / "something else" / "more like that" stay unclear — do not invent a playlist |
| `none` | Tell user nothing found |
| `status: error` | Follow `code` + `solution` (table below). `AUTH_*` → Step 0 |

```bash
./spotify/scripts/spotify-play.sh play "spotify:track:xxx"
./spotify/scripts/spotify-play.sh play "spotify:playlist:xxx" --device "Kitchen Echo"
```

Short/ambiguous queries stay `unclear` (e.g. `"rock"`). Do not force auto-play.

## Controls

```bash
./spotify/scripts/spotify-ctl.sh pause|play|next|prev
./spotify/scripts/spotify-ctl.sh volume 50|up|down
./spotify/scripts/spotify-ctl.sh shuffle on|off
./spotify/scripts/spotify-ctl.sh repeat track|context|off
./spotify/scripts/spotify-ctl.sh now|queue|devices
./spotify/scripts/spotify-ctl.sh transfer Echo
./spotify/scripts/spotify-ctl.sh seek 60
./spotify/scripts/spotify-ctl.sh add-queue spotify:track:xxx
```

`now` reports `playing` or `paused`, plus device and volume. `next` after a single-track play may stay on the same song; use album/playlist context or `add-queue` when skip must advance.

Devices:

```bash
./spotify/scripts/spotify-play.sh --devices
./spotify/scripts/spotify-play.sh --set-device "Echo"
```

## Errors

Stdout JSON on failure: `{"status":"error","code":"...","error":"...","solution":"..."}` (human text on stderr).

| Code | Agent next step |
|------|-----------------|
| `AUTH_REQUIRED` / `AUTH_EXPIRED` | Step 0 (save credentials if needed, then `login`) |
| `PREMIUM_REQUIRED` | Tell user Premium is required |
| `NO_DEVICE` | Ask user to open Spotify on a device; `--devices` / `--device` / `--set-device` |
| `DEVICE_NOT_FOUND` | List devices; ask which name |
| `INVALID_URI` | Fix URI shape `spotify:track:<id>` (or playlist/album/artist) |
| `SEARCH_FAILED` / `API_ERROR` | Retry or rephrase |

## Files

`~/.config/spotify/` (`credentials.json`, `tokens.json`, `config.json`) — mode 700/600. Tokens refresh automatically.

Deps: `curl`, `jq`, `openssl`. `python3` only for `login` (loopback redirect).

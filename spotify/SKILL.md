---
name: spotify
description: |
  Control Spotify playback via CLI. Requires Spotify Premium for playback control.
  USE FOR: play song, play music, play [song name], play [artist], play [album], play [playlist], pause, stop music, resume, skip, next song, previous song, what's playing, now playing, current song, volume up, volume down, set volume, shuffle on, shuffle off, repeat, queue, add to queue, list devices, transfer playback, play on [device].
  DO NOT USE FOR: downloading music, editing playlists, creating playlists.
---

# Spotify Control

## Agent Workflow

### Playing Music

Use the two-step search → play workflow:

```bash
# Step 1: Search (returns JSON)
./scripts/spotify-play.sh search "bohemian rhapsody" --type track
```

**Response types:**

1. **Clean match** (`"match": "auto"`) - Already playing, done!
```json
{"query":"bohemian rhapsody","type":"track","match":"auto",
 "playing":{"name":"Bohemian Rhapsody","artist":"Queen","uri":"spotify:track:xxx"},
 "results":[...]}
```

2. **Unclear match** (`"match": "unclear"`) - Review results, pick best one:
```json
{"query":"rock classics","type":"playlist","match":"unclear",
 "results":[
   {"name":"Rock Classics","owner":"Spotify","uri":"spotify:playlist:xxx"},
   {"name":"Classic Rock Hits","owner":"Someone","uri":"spotify:playlist:yyy"}
 ]}
```
Then call:
```bash
./scripts/spotify-play.sh play "spotify:playlist:xxx"
```

3. **No results** (`"match": "none"`) - Tell user nothing found

### Decision Rules

When `match` is `"unclear"`:
1. Review the `results` array
2. Pick the best match based on name similarity to original query
3. If genuinely ambiguous, ask the user which one they want
4. Call `play` with the chosen URI

## Quick Start

```bash
# Search and play (auto-plays if clean match)
./scripts/spotify-play.sh search "bohemian rhapsody"

# Play specific URI
./scripts/spotify-play.sh play "spotify:track:4u7EnebtmKWzUH433cf5Qv"

# Playback controls
./scripts/spotify-ctl.sh pause
./scripts/spotify-ctl.sh play
./scripts/spotify-ctl.sh next
```

## Setup

### Dependencies

Requires `jq` for JSON processing. Other tools are built-in on macOS/Linux.

```bash
# macOS
brew install jq

# Linux (Debian/Ubuntu)
sudo apt install jq
```

### Spotify Developer Account (one-time)

1. Go to https://developer.spotify.com/dashboard
2. Log in with your Spotify account
3. Click **Create App** → name it anything → select "Web API"
4. Add redirect URI: `http://127.0.0.1:17823/callback`
5. Copy your **Client ID** and **Client Secret**

**Note**: Requires Spotify Premium for playback control. Free accounts can only search.

### First Run

```bash
./scripts/spotify-auth.sh login
```

Credentials loaded from: env vars → `~/.config/spotify/credentials.json` → interactive prompt

## Commands

### spotify-play.sh

```bash
# Search (returns JSON, auto-plays if clean match)
./scripts/spotify-play.sh search "song name"
./scripts/spotify-play.sh search "playlist name" --type playlist
./scripts/spotify-play.sh search "artist" --type artist
./scripts/spotify-play.sh search "album" --type album

# Play specific URI
./scripts/spotify-play.sh play "spotify:track:xxx"
./scripts/spotify-play.sh play "spotify:playlist:xxx" --device "Kitchen Echo"

# Device management
./scripts/spotify-play.sh --devices              # List devices (JSON)
./scripts/spotify-play.sh --set-device "Echo"    # Set default device
```

### spotify-ctl.sh

```bash
./scripts/spotify-ctl.sh pause
./scripts/spotify-ctl.sh play
./scripts/spotify-ctl.sh next
./scripts/spotify-ctl.sh prev
./scripts/spotify-ctl.sh seek 60              # Seek to 60 seconds
./scripts/spotify-ctl.sh volume 50
./scripts/spotify-ctl.sh shuffle on|off
./scripts/spotify-ctl.sh repeat track|context|off
./scripts/spotify-ctl.sh devices        # List devices
./scripts/spotify-ctl.sh transfer Echo  # Move playback to device
./scripts/spotify-ctl.sh now            # What's playing
./scripts/spotify-ctl.sh queue          # Show queue
./scripts/spotify-ctl.sh add-queue <uri>
```

## Error Handling

| Error | Solution |
|-------|----------|
| No token | Run `./scripts/spotify-auth.sh login` |
| No active device | Use `--device` flag or `--set-device` |
| 403 Premium required | Playback needs Spotify Premium |
| 401 Unauthorized | Re-run `./scripts/spotify-auth.sh login` |

## Files

```
~/.config/spotify/           # or $XDG_CONFIG_HOME/spotify/
├── credentials.json         # Client ID/Secret (chmod 600)
├── tokens.json              # Access/refresh tokens (chmod 600)
└── config.json              # Default device, preferences
```

## Security

- Credentials stored in `~/.config/spotify/` (owner-only access)
- Tokens auto-refresh when expired

## Error Codes

| Code | Description | Solution |
|------|-------------|----------|
| `AUTH_REQUIRED` | No token found | Run `./scripts/spotify-auth.sh login` |
| `AUTH_EXPIRED` | Token invalid/expired | Run `./scripts/spotify-auth.sh login` |
| `PREMIUM_REQUIRED` | Playback needs Premium | Upgrade to Spotify Premium |
| `NO_DEVICE` | No active playback device | Open Spotify app or use `--device` flag |
| `DEVICE_NOT_FOUND` | Named device not available | Check `./scripts/spotify-ctl.sh devices` |
| `INVALID_URI` | Malformed Spotify URI | Use format `spotify:track:<id>` |
| `RATE_LIMITED` | Too many requests | Wait and retry |
| `SEARCH_FAILED` | Search returned no results | Try different query |

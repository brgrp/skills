#!/bin/bash
# spotify-play.sh - Search and play on Spotify
#
# Usage:
#   ./spotify-play.sh search "query" [--type track|playlist|album|artist]
#   ./spotify-play.sh play <spotify:uri> [--device "name"]
#   ./spotify-play.sh --devices
#   ./spotify-play.sh --set-device "name"
#
# Search behavior:
#   - If a clean match is found, auto-plays and returns success
#   - If no clean match, returns JSON results for agent to review and pick

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SPOTIFY_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/spotify"
CONFIG_FILE="$SPOTIFY_DIR/config.json"

# Colors (only for stderr messages)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Cached token
_TOKEN=""
get_token() {
    if [ -z "$_TOKEN" ]; then
        _TOKEN=$("$SCRIPT_DIR/spotify-auth.sh" token 2>/dev/null)
        if [ -z "$_TOKEN" ]; then
            log_error "Failed to get token. Run: spotify-auth.sh login"
            exit 1
        fi
    fi
    echo "$_TOKEN"
}

# API call with retry logic
# Uses curl -K - to hide Bearer token from process list (security)
api_call() {
    local method="$1"
    local url="$2"
    local data="$3"
    local max_retries=3
    local retry_delay=1
    local token=$(get_token)
    
    for ((i=1; i<=max_retries; i++)); do
        local response
        if [ -n "$data" ]; then
            response=$(echo "header = \"Authorization: Bearer $token\"" | \
                curl -K - -s -w "\n%{http_code}" -X "$method" "$url" \
                -H "Content-Type: application/json" -d "$data")
        else
            response=$(echo "header = \"Authorization: Bearer $token\"" | \
                curl -K - -s -w "\n%{http_code}" -X "$method" "$url")
        fi
        local http_code=$(echo "$response" | tail -1)
        local body=$(echo "$response" | sed '$d')
        
        case "$http_code" in
            200|201|202|204)
                echo "$body"
                return 0
                ;;
            429)
                local retry_after=$(echo "$body" | jq -r '.retry_after // 1')
                log_warn "Rate limited. Waiting ${retry_after}s..."
                sleep "$retry_after"
                ;;
            401)
                log_error "Unauthorized. Run: spotify-auth.sh login"
                return 1
                ;;
            403)
                log_error "Forbidden. Spotify Premium required"
                return 1
                ;;
            404)
                return 44
                ;;
            *)
                if [ $i -lt $max_retries ]; then
                    sleep "$retry_delay"
                    retry_delay=$((retry_delay * 2))
                else
                    log_error "Request failed (HTTP $http_code)"
                    return 1
                fi
                ;;
        esac
    done
    return 1
}

# Config helpers
load_config() { [ -f "$CONFIG_FILE" ] && cat "$CONFIG_FILE" || echo '{}'; }

save_config() {
    mkdir -p "$SPOTIFY_DIR" && chmod 700 "$SPOTIFY_DIR"
    # Use umask for atomic secure file creation (security: prevents race condition)
    (umask 077 && echo "$1" > "$CONFIG_FILE")
}

get_default_device() { load_config | jq -r '.default_device // empty'; }

set_default_device() {
    save_config "$(load_config | jq --arg dev "$1" '.default_device = $dev')"
    log_info "Default device set to: $1"
}

# Validate device ID (40-char hex or UUID_amzn_N for Echo)
validate_device_id() {
    [[ "$1" =~ ^[a-fA-F0-9]{40}$ ]] || [[ "$1" =~ ^[a-f0-9-]{36}_amzn_[0-9]+$ ]]
}

# Get device ID by name
get_device_id() {
    local result=$(api_call GET "https://api.spotify.com/v1/me/player/devices")
    local device_id=$(echo "$result" | jq -r --arg name "$1" \
        '.devices[]? | select(.name | ascii_downcase | contains($name | ascii_downcase)) | .id' | head -1)
    
    [ -z "$device_id" ] && return 1
    validate_device_id "$device_id" || { log_error "Invalid device ID"; return 1; }
    echo "$device_id"
}

# List devices as JSON
list_devices_json() {
    api_call GET "https://api.spotify.com/v1/me/player/devices" | jq '{
        devices: [.devices[]? | {name, type, id, is_active, volume: .volume_percent}]
    }'
}

# URL encode using jq
url_encode() {
    printf '%s' "$1" | jq -sRr @uri
}

# Validate Spotify URI
validate_uri() { [[ "$1" =~ ^spotify:[a-z_]+:[a-zA-Z0-9]+$ ]]; }

# Wake device
wake_device() {
    log_info "Waking device..."
    api_call PUT "https://api.spotify.com/v1/me/player" \
        "$(jq -n --arg id "$1" '{"device_ids": [$id], "play": true}')" >/dev/null 2>&1 || true
    sleep 2
}

# Normalize string for matching (lowercase, alphanumeric only)
normalize() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 ]//g' | xargs
}

# Check if query is a clean match for result name
# Returns 0 if clean match, 1 otherwise
is_clean_match() {
    local query="$1"
    local name="$2"
    local norm_query=$(normalize "$query")
    local norm_name=$(normalize "$name")
    
    # Exact match
    [[ "$norm_query" == "$norm_name" ]] && return 0
    
    # Name contains full query
    [[ "$norm_name" == *"$norm_query"* ]] && return 0
    
    # Query contains full name (for short names like "Queen")
    [[ "$norm_query" == *"$norm_name"* ]] && [[ ${#norm_name} -ge 4 ]] && return 0
    
    # Word-based matching for longer queries
    local -a query_words name_words
    read -ra query_words <<< "$norm_query"
    read -ra name_words <<< "$norm_name"
    
    # Count significant words (3+ chars) that match
    local matches=0 significant=0
    for qw in "${query_words[@]}"; do
        [[ ${#qw} -lt 3 ]] && continue
        ((significant++))
        for nw in "${name_words[@]}"; do
            [[ "$qw" == "$nw" ]] && { ((matches++)); break; }
        done
    done
    
    # Need all significant words to match for "clean"
    [[ $significant -gt 0 && $matches -eq $significant ]] && return 0
    
    return 1
}

#############################################
# PLAY URI - Internal function
#############################################
do_play_uri() {
    local uri="$1"
    local device_id="$2"
    
    uri=$(echo "$uri" | sed 's/:playlist_v2:/:playlist:/')
    validate_uri "$uri" || { log_error "Invalid URI: $uri"; return 1; }
    
    local body
    [[ "$uri" == *":track:"* ]] && body=$(jq -n --arg u "$uri" '{"uris":[$u]}') \
                                || body=$(jq -n --arg u "$uri" '{"context_uri":$u}')
    
    local url="https://api.spotify.com/v1/me/player/play"
    [ -n "$device_id" ] && url="$url?device_id=$device_id"
    
    api_call PUT "$url" "$body"
    local status=$?
    
    if [ $status -eq 44 ] && [ -n "$device_id" ]; then
        wake_device "$device_id"
        api_call PUT "$url" "$body" >/dev/null
        status=$?
    fi
    
    return $status
}

# Get device ID from args or default
resolve_device() {
    local device_name="$1"
    if [ -n "$device_name" ]; then
        get_device_id "$device_name"
    else
        local default=$(get_default_device)
        [ -n "$default" ] && get_device_id "$default" || true
    fi
}

#############################################
# SEARCH COMMAND
#############################################
cmd_search() {
    local query="" type="track" device_name=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --type|-t) type="$2"; shift 2 ;;
            --device|-d) device_name="$2"; shift 2 ;;
            -*) log_error "Unknown option: $1"; exit 1 ;;
            *) query="$1"; shift ;;
        esac
    done
    
    [ -z "$query" ] && { log_error "Usage: $0 search \"query\" [--type TYPE]"; exit 1; }
    
    case "$type" in
        track|playlist|album|artist) ;;
        *) log_error "Invalid type. Use: track, playlist, album, artist"; exit 1 ;;
    esac
    
    # Search Spotify (10 results - API limit)
    local encoded=$(url_encode "$query")
    local raw=$(api_call GET "https://api.spotify.com/v1/search?q=$encoded&type=$type&limit=10")
    [ -z "$raw" ] && { echo '{"error":"Search failed","results":[]}'; exit 1; }
    
    # Extract items path
    local items_path
    case "$type" in
        track) items_path=".tracks.items" ;;
        playlist) items_path=".playlists.items" ;;
        album) items_path=".albums.items" ;;
        artist) items_path=".artists.items" ;;
    esac
    
    # Format results
    local jq_filter
    case "$type" in
        track)
            jq_filter='[.[]? | select(. != null) | {
                name, artist: (.artists[0].name // "Unknown"),
                album: (.album.name // "Unknown"), uri, duration_ms
            }]' ;;
        playlist)
            jq_filter='[.[]? | select(. != null) | {
                name, owner: (.owner.display_name // "Unknown"),
                tracks: (.tracks.total // 0), uri
            }]' ;;
        album)
            jq_filter='[.[]? | select(. != null) | {
                name, artist: (.artists[0].name // "Unknown"),
                year: (.release_date // "" | split("-")[0]),
                tracks: (.total_tracks // 0), uri
            }]' ;;
        artist)
            jq_filter='[.[]? | select(. != null) | {
                name, genres: (.genres[:3] // []),
                followers: (.followers.total // 0), uri
            }]' ;;
    esac
    
    local results=$(echo "$raw" | jq "$items_path | $jq_filter")
    local count=$(echo "$results" | jq 'length')
    
    if [ "$count" -eq 0 ]; then
        jq -n --arg q "$query" --arg t "$type" '{query:$q, type:$t, match:"none", results:[]}'
        exit 0
    fi
    
    # Check if first result is a clean match
    local first_name=$(echo "$results" | jq -r '.[0].name // ""')
    local first_uri=$(echo "$results" | jq -r '.[0].uri // ""')
    
    if is_clean_match "$query" "$first_name"; then
        # Clean match - auto-play!
        local device_id=$(resolve_device "$device_name")
        
        if do_play_uri "$first_uri" "$device_id"; then
            # Return success with what's playing
            local first_artist=$(echo "$results" | jq -r '.[0].artist // .[0].owner // "Unknown"')
            log_info "Playing: $first_name by $first_artist"
            echo "$results" | jq --arg q "$query" --arg t "$type" \
                '{query:$q, type:$t, match:"auto", playing:.[0], results:.}'
        else
            log_error "Playback failed"
            echo "$results" | jq --arg q "$query" --arg t "$type" \
                '{query:$q, type:$t, match:"failed", results:.}'
            exit 1
        fi
    else
        # No clean match - return results for agent to pick
        log_warn "No exact match for '$query'. Review results and pick one."
        echo "$results" | jq --arg q "$query" --arg t "$type" \
            '{query:$q, type:$t, match:"unclear", results:.}'
    fi
}

#############################################
# PLAY COMMAND
#############################################
cmd_play() {
    local uri="" device_name=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --device|-d) device_name="$2"; shift 2 ;;
            -*) log_error "Unknown option: $1"; exit 1 ;;
            *) uri="$1"; shift ;;
        esac
    done
    
    [ -z "$uri" ] && { log_error "Usage: $0 play <spotify:uri> [--device NAME]"; exit 1; }
    
    local device_id=$(resolve_device "$device_name")
    
    if do_play_uri "$uri" "$device_id"; then
        log_info "Playback started"
        jq -n --arg u "$uri" '{status:"playing", uri:$u}'
    else
        jq -n --arg u "$uri" '{status:"error", uri:$u}'
        exit 1
    fi
}

#############################################
# MAIN
#############################################
case "${1:-}" in
    search) shift; cmd_search "$@" ;;
    play) shift; cmd_play "$@" ;;
    --devices) list_devices_json ;;
    --set-device)
        [ -z "$2" ] && { log_error "Usage: $0 --set-device <name>"; exit 1; }
        set_default_device "$2" ;;
    -h|--help|"")
        cat << 'EOF'
Spotify Search & Play

Usage:
  spotify-play.sh search "query" [--type track|playlist|album|artist] [--device NAME]
  spotify-play.sh play <spotify:uri> [--device NAME]
  spotify-play.sh --devices
  spotify-play.sh --set-device NAME

Search behavior:
  - Clean match found    → Auto-plays, returns {match:"auto", playing:{...}}
  - No clean match       → Returns {match:"unclear", results:[...]} for agent to pick
  - No results           → Returns {match:"none", results:[]}

Then agent calls 'play' with chosen URI if needed.
EOF
        ;;
    *) log_error "Unknown command: $1"; exit 1 ;;
esac

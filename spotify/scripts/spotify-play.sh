#!/bin/bash
# spotify-play.sh - Search and play on Spotify
#
# Usage:
#   ./spotify-play.sh "song name"              # Play track
#   ./spotify-play.sh "playlist" --type playlist
#   ./spotify-play.sh "artist" --type artist   # Play artist's top tracks
#   ./spotify-play.sh "song" --device "Echo"   # Play on device
#   ./spotify-play.sh --set-device "Echo"      # Set default device
#   ./spotify-play.sh --devices                # List devices

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SPOTIFY_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/spotify"
CONFIG_FILE="$SPOTIFY_DIR/config.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Cached token (avoid multiple fetches)
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
api_call() {
    local method="$1"
    local url="$2"
    local data="$3"
    local max_retries=3
    local retry_delay=1
    
    local args=(-s -w "\n%{http_code}" -X "$method" "$url" -H "Authorization: Bearer $(get_token)")
    [ -n "$data" ] && args+=(-H "Content-Type: application/json" -d "$data")
    
    for ((i=1; i<=max_retries; i++)); do
        local response=$(curl "${args[@]}")
        local http_code=$(echo "$response" | tail -1)
        local body=$(echo "$response" | sed '$d')
        
        case "$http_code" in
            200|201|202|204)
                echo "$body"
                return 0
                ;;
            429)
                local retry_after=$(echo "$body" | jq -r '.retry_after // 1')
                log_warn "Rate limited. Waiting ${retry_after}s... (attempt $i/$max_retries)"
                sleep "$retry_after"
                ;;
            401)
                log_error "Unauthorized. Token may be invalid. Run: spotify-auth.sh login"
                return 1
                ;;
            403)
                log_error "Forbidden. Spotify Premium required for playback control"
                return 1
                ;;
            404)
                # Return 404 for caller to handle (device wake)
                echo "$body"
                return 44  # Special code for 404
                ;;
            *)
                if [ $i -lt $max_retries ]; then
                    log_warn "Request failed (HTTP $http_code). Retrying in ${retry_delay}s... (attempt $i/$max_retries)"
                    sleep "$retry_delay"
                    retry_delay=$((retry_delay * 2))
                else
                    log_error "Request failed after $max_retries attempts (HTTP $http_code)"
                    return 1
                fi
                ;;
        esac
    done
    return 1
}

# Load config
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        cat "$CONFIG_FILE"
    else
        echo '{}'
    fi
}

# Save config
save_config() {
    mkdir -p "$SPOTIFY_DIR"
    chmod 700 "$SPOTIFY_DIR"
    echo "$1" > "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
}

# Get default device from config
get_default_device() {
    load_config | jq -r '.default_device // empty'
}

# Set default device
set_default_device() {
    local device_name="$1"
    local config=$(load_config)
    local new_config=$(echo "$config" | jq --arg dev "$device_name" '.default_device = $dev')
    save_config "$new_config"
    log_info "Default device set to: $device_name"
}

# List available devices
list_devices() {
    local result=$(api_call GET "https://api.spotify.com/v1/me/player/devices")
    local devices=$(echo "$result" | jq -r '.devices[]? | "\(.name) (\(.type))"')
    if [ -z "$devices" ]; then
        log_warn "No devices found. Open Spotify on a device first."
    else
        echo "$devices"
    fi
}

# Get device ID by name (partial match)
get_device_id() {
    local device_name="$1"
    local result=$(api_call GET "https://api.spotify.com/v1/me/player/devices")
    local device_id=$(echo "$result" | jq -r --arg name "$device_name" \
        '.devices[]? | select(.name | ascii_downcase | contains($name | ascii_downcase)) | .id' | head -1)
    
    if [ -z "$device_id" ]; then
        log_warn "Device '$device_name' not found. Available devices:"
        echo "$result" | jq -r '.devices[]? | "  - \(.name)"'
        return 1
    fi
    echo "$device_id"
}

# Wake device and wait
wake_device() {
    local device_id="$1"
    log_info "Waking device..."
    api_call PUT "https://api.spotify.com/v1/me/player" \
        "{\"device_ids\": [\"$device_id\"], \"play\": true}" > /dev/null 2>&1 || true
    sleep 2
}

# URL encode
url_encode() {
    python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.stdin.read().strip(), safe=''))" <<< "$1"
}

# Search Spotify
search() {
    local query="$1"
    local type="${2:-track}"
    local encoded=$(url_encode "$query")
    
    api_call GET "https://api.spotify.com/v1/search?q=$encoded&type=$type&limit=1"
}

# Play URI on device
play_uri() {
    local uri="$1"
    local device_id="$2"
    
    # Normalize playlist_v2 URIs
    uri=$(echo "$uri" | sed 's/:playlist_v2:/:playlist:/')
    
    local body
    if [[ "$uri" == *":track:"* ]]; then
        body="{\"uris\": [\"$uri\"]}"
    else
        body="{\"context_uri\": \"$uri\"}"
    fi
    
    local url="https://api.spotify.com/v1/me/player/play"
    [ -n "$device_id" ] && url="$url?device_id=$device_id"
    
    api_call PUT "$url" "$body"
    local status=$?
    
    # Handle device wake on 404
    if [ $status -eq 44 ] && [ -n "$device_id" ]; then
        wake_device "$device_id"
        api_call PUT "$url" "$body" > /dev/null
        return $?
    fi
    
    return $status
}

# Main
main() {
    local query=""
    local type="track"
    local device_name=""
    
    # Parse args
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --type|-t)
                type="$2"
                shift 2
                ;;
            --device|-d)
                device_name="$2"
                shift 2
                ;;
            --set-device)
                set_default_device "$2"
                exit 0
                ;;
            --devices)
                list_devices
                exit 0
                ;;
            -h|--help)
                echo "Usage: $0 <query> [--type track|playlist|album|artist] [--device <name>]"
                echo "       $0 --set-device <name>"
                echo "       $0 --devices"
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                exit 1
                ;;
            *)
                query="$1"
                shift
                ;;
        esac
    done
    
    if [ -z "$query" ]; then
        log_error "No search query provided. Usage: $0 \"song name\""
        exit 1
    fi
    
    # Validate type
    case "$type" in
        track|playlist|album|artist) ;;
        *)
            log_error "Invalid type '$type'. Use: track, playlist, album, or artist"
            exit 1
            ;;
    esac
    
    # Get device ID
    local device_id=""
    if [ -n "$device_name" ]; then
        device_id=$(get_device_id "$device_name") || exit 1
    else
        local default_device=$(get_default_device)
        if [ -n "$default_device" ]; then
            device_id=$(get_device_id "$default_device") || true
        fi
    fi
    
    # Search
    log_info "Searching for: $query ($type)"
    local result=$(search "$query" "$type")
    
    if [ -z "$result" ]; then
        log_error "Search failed. Check your connection and try again."
        exit 1
    fi
    
    local uri name artist
    case "$type" in
        track)
            uri=$(echo "$result" | jq -r '.tracks.items[0].uri // empty')
            name=$(echo "$result" | jq -r '.tracks.items[0].name // empty')
            artist=$(echo "$result" | jq -r '.tracks.items[0].artists[0].name // empty')
            ;;
        playlist)
            uri=$(echo "$result" | jq -r '.playlists.items[0].uri // empty')
            name=$(echo "$result" | jq -r '.playlists.items[0].name // empty')
            artist=$(echo "$result" | jq -r '.playlists.items[0].owner.display_name // empty')
            ;;
        album)
            uri=$(echo "$result" | jq -r '.albums.items[0].uri // empty')
            name=$(echo "$result" | jq -r '.albums.items[0].name // empty')
            artist=$(echo "$result" | jq -r '.albums.items[0].artists[0].name // empty')
            ;;
        artist)
            uri=$(echo "$result" | jq -r '.artists.items[0].uri // empty')
            name=$(echo "$result" | jq -r '.artists.items[0].name // empty')
            artist="(artist)"
            ;;
    esac
    
    if [ -z "$uri" ]; then
        log_error "No $type found for: '$query'"
        exit 1
    fi
    
    log_info "Playing: $name by $artist"
    if play_uri "$uri" "$device_id"; then
        return 0
    else
        log_error "Playback failed. Try: spotify-ctl.sh devices"
        exit 1
    fi
}

main "$@"

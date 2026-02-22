#!/bin/bash
# spotify-ctl.sh - Spotify playback control
#
# Usage:
#   ./spotify-ctl.sh pause|play|next|prev
#   ./spotify-ctl.sh volume 50
#   ./spotify-ctl.sh shuffle on|off
#   ./spotify-ctl.sh repeat track|context|off
#   ./spotify-ctl.sh devices|now|queue
#   ./spotify-ctl.sh transfer <device>
#   ./spotify-ctl.sh add-queue <uri>

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
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

# API call with error handling and retry
api() {
    local method="$1"
    local endpoint="$2"
    local data="$3"
    local max_retries=3
    
    local args=(-s -w "\n%{http_code}" -X "$method" "https://api.spotify.com/v1$endpoint" -H "Authorization: Bearer $(get_token)")
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
                local retry_after=$(echo "$body" | jq -r '.retry_after // 1' 2>/dev/null || echo 1)
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
                log_error "No active device. Open Spotify on a device or use: spotify-ctl.sh devices"
                return 1
                ;;
            *)
                if [ $i -lt $max_retries ]; then
                    sleep 1
                else
                    log_error "API error (HTTP $http_code)"
                    return 1
                fi
                ;;
        esac
    done
    return 1
}

case "${1:-}" in
    pause)
        api PUT "/me/player/pause" > /dev/null && log_info "Paused"
        ;;
    play|resume)
        api PUT "/me/player/play" > /dev/null && log_info "Playing"
        ;;
    next|skip)
        api POST "/me/player/next" > /dev/null && log_info "Skipped to next"
        ;;
    prev|previous)
        api POST "/me/player/previous" > /dev/null && log_info "Back to previous"
        ;;
    volume|vol)
        if [ -z "$2" ]; then
            log_error "Usage: $0 volume <0-100>"
            exit 1
        fi
        if ! [[ "$2" =~ ^[0-9]+$ ]] || [ "$2" -lt 0 ] || [ "$2" -gt 100 ]; then
            log_error "Volume must be a number between 0-100"
            exit 1
        fi
        api PUT "/me/player/volume?volume_percent=$2" > /dev/null && log_info "Volume set to $2%"
        ;;
    shuffle)
        if [ -z "$2" ]; then
            log_error "Usage: $0 shuffle on|off"
            exit 1
        fi
        case "$2" in
            on)  api PUT "/me/player/shuffle?state=true" > /dev/null && log_info "Shuffle on" ;;
            off) api PUT "/me/player/shuffle?state=false" > /dev/null && log_info "Shuffle off" ;;
            *)   log_error "Invalid value '$2'. Use: on or off"; exit 1 ;;
        esac
        ;;
    repeat)
        if [ -z "$2" ]; then
            log_error "Usage: $0 repeat track|context|off"
            exit 1
        fi
        case "$2" in
            track|context|off)
                api PUT "/me/player/repeat?state=$2" > /dev/null && log_info "Repeat: $2"
                ;;
            *)
                log_error "Invalid mode '$2'. Use: track, context, or off"
                exit 1
                ;;
        esac
        ;;
    devices)
        result=$(api GET "/me/player/devices")
        if [ -n "$result" ]; then
            devices=$(echo "$result" | jq -r '.devices[]? | "[\(if .is_active then "▶" else " " end)] \(.name) (\(.type))"')
            if [ -z "$devices" ]; then
                log_warn "No devices found. Open Spotify on a device."
            else
                echo "$devices"
            fi
        fi
        ;;
    now|current|playing)
        result=$(api GET "/me/player/currently-playing")
        if [ -n "$result" ] && [ "$result" != "null" ]; then
            echo "$result" | jq -r 'if .item then "\(.item.name) - \(.item.artists[0].name)\n\(.item.album.name)" else "Nothing playing" end'
        else
            echo "Nothing playing"
        fi
        ;;
    queue)
        result=$(api GET "/me/player/queue")
        if [ -n "$result" ]; then
            queue=$(echo "$result" | jq -r '.queue[:10][]? | "• \(.name) - \(.artists[0].name)"')
            if [ -z "$queue" ]; then
                log_info "Queue is empty"
            else
                echo "$queue"
            fi
        fi
        ;;
    add-queue|add)
        if [ -z "$2" ]; then
            log_error "Usage: $0 add-queue <spotify:track:xxx>"
            exit 1
        fi
        if [[ ! "$2" =~ ^spotify:(track|episode): ]]; then
            log_error "Invalid URI. Must be spotify:track:xxx or spotify:episode:xxx"
            exit 1
        fi
        api POST "/me/player/queue?uri=$2" && log_info "Added to queue"
        ;;
    seek)
        if [ -z "$2" ]; then
            log_error "Usage: $0 seek <seconds>"
            exit 1
        fi
        if ! [[ "$2" =~ ^[0-9]+$ ]]; then
            log_error "Seek position must be a number (seconds)"
            exit 1
        fi
        ms=$(($2 * 1000))
        api PUT "/me/player/seek?position_ms=$ms" && log_info "Seeked to ${2}s"
        ;;
    transfer)
        if [ -z "$2" ]; then
            log_error "Usage: $0 transfer <device_name>"
            exit 1
        fi
        devices_json=$(api GET "/me/player/devices")
        device_id=$(echo "$devices_json" | jq -r --arg name "$2" \
            '.devices[]? | select(.name | ascii_downcase | contains($name | ascii_downcase)) | .id' | head -1)
        if [ -z "$device_id" ]; then
            log_error "Device '$2' not found. Available devices:"
            echo "$devices_json" | jq -r '.devices[]? | "  - \(.name)"'
            exit 1
        fi
        api PUT "/me/player" "{\"device_ids\": [\"$device_id\"], \"play\": true}" > /dev/null && log_info "Transferred to $2"
        ;;
    -h|--help|"")
        echo "Spotify Control"
        echo ""
        echo "Usage: $0 <command> [args]"
        echo ""
        echo "Playback:"
        echo "  pause              Pause playback"
        echo "  play               Resume playback"
        echo "  next               Skip to next track"
        echo "  prev               Go to previous track"
        echo "  seek <seconds>     Seek to position"
        echo ""
        echo "Settings:"
        echo "  volume <0-100>     Set volume"
        echo "  shuffle on|off     Toggle shuffle"
        echo "  repeat <mode>      Set repeat (track|context|off)"
        echo ""
        echo "Info:"
        echo "  now                Show current track"
        echo "  queue              Show upcoming tracks"
        echo "  devices            List available devices"
        echo ""
        echo "Other:"
        echo "  transfer <device>  Move playback to device"
        echo "  add-queue <uri>    Add track to queue"
        ;;
    *)
        log_error "Unknown command: $1"
        echo "Run '$0 --help' for usage"
        exit 1
        ;;
esac

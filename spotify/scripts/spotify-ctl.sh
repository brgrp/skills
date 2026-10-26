#!/bin/bash
# spotify-ctl.sh - Spotify playback control
#
# Usage:
#   ./spotify-ctl.sh pause|play|next|prev
#   ./spotify-ctl.sh volume <0-100>|up|down
#   ./spotify-ctl.sh shuffle on|off
#   ./spotify-ctl.sh repeat track|context|off
#   ./spotify-ctl.sh devices|now|queue
#   ./spotify-ctl.sh transfer <device>
#   ./spotify-ctl.sh add-queue <uri>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

emit_error() {
    local code="$1" error="$2" solution="$3"
    log_error "$error"
    jq -n --arg c "$code" --arg e "$error" --arg s "$solution" \
        '{status:"error", code:$c, error:$e, solution:$s}'
}

validate_device_id() {
    local id="$1"
    [[ "$id" =~ ^[a-fA-F0-9]{40}$ ]] || [[ "$id" =~ ^[a-f0-9-]{36}_amzn_[0-9]+$ ]]
}

_TOKEN=""
get_token() {
    if [ -z "$_TOKEN" ]; then
        _TOKEN=$("$SCRIPT_DIR/spotify-auth.sh" token 2>/dev/null) || true
        if [ -z "$_TOKEN" ]; then
            return 1
        fi
    fi
    echo "$_TOKEN"
}

# Resolve device: exact name first, then unique contains.
resolve_device_id() {
    local name="$1"
    local devices_json="$2"
    local exact contains count

    exact=$(echo "$devices_json" | jq -r --arg n "$name" \
        '[.devices[]? | select((.name | ascii_downcase) == ($n | ascii_downcase)) | .id] | .[]')
    count=$(printf '%s\n' "$exact" | grep -c . || true)
    if [ "$count" -eq 1 ]; then
        echo "$exact"
        return 0
    fi
    if [ "$count" -gt 1 ]; then
        return 1
    fi

    contains=$(echo "$devices_json" | jq -r --arg n "$name" \
        '[.devices[]? | select(.name | ascii_downcase | contains($n | ascii_downcase)) | .id] | .[]')
    count=$(printf '%s\n' "$contains" | grep -c . || true)
    if [ "$count" -eq 1 ]; then
        echo "$contains"
        return 0
    fi
    return 1
}

api() {
    local method="$1"
    local endpoint="$2"
    local data="${3:-}"
    local max_retries=3
    local token
    if ! token=$(get_token); then
        emit_error "AUTH_REQUIRED" "No valid Spotify token" \
            "Ask user for Spotify Client ID/Secret if needed, save to ~/.config/spotify/credentials.json, then run ./spotify/scripts/spotify-auth.sh login"
        return 1
    fi

    local hdr body_file
    hdr=$(mktemp)
    body_file=$(mktemp)
    # shellcheck disable=SC2064
    trap "rm -f '$hdr' '$body_file'" RETURN

    local i
    for ((i=1; i<=max_retries; i++)); do
        local http_code
        if [ -n "$data" ]; then
            http_code=$(echo "header = \"Authorization: Bearer $token\"" | \
                curl -K - -s -D "$hdr" -o "$body_file" -w "%{http_code}" -X "$method" \
                "https://api.spotify.com/v1$endpoint" \
                -H "Content-Type: application/json" -d "$data")
        else
            http_code=$(echo "header = \"Authorization: Bearer $token\"" | \
                curl -K - -s -D "$hdr" -o "$body_file" -w "%{http_code}" -X "$method" \
                "https://api.spotify.com/v1$endpoint")
        fi
        local body
        body=$(cat "$body_file")

        case "$http_code" in
            200|201|202|204)
                echo "$body"
                return 0
                ;;
            429)
                local retry_after
                retry_after=$(awk 'BEGIN{IGNORECASE=1} /^Retry-After:/ {print $2}' "$hdr" | tr -d '\r' | head -1)
                retry_after=${retry_after:-1}
                [[ "$retry_after" =~ ^[0-9]+$ ]] || retry_after=1
                log_warn "Rate limited. Waiting ${retry_after}s..."
                sleep "$retry_after"
                ;;
            401)
                emit_error "AUTH_EXPIRED" "Unauthorized (token invalid or expired)" \
                    "Re-run ./spotify/scripts/spotify-auth.sh login (refresh credentials if login still fails)"
                return 1
                ;;
            403)
                emit_error "PREMIUM_REQUIRED" "Forbidden — Spotify Premium required for playback" \
                    "Upgrade to Spotify Premium"
                return 1
                ;;
            404)
                emit_error "NO_DEVICE" "No active playback device" \
                    "Open Spotify on a device or use: ./spotify/scripts/spotify-ctl.sh devices"
                return 1
                ;;
            *)
                if [ "$i" -lt "$max_retries" ]; then
                    sleep 1
                else
                    emit_error "API_ERROR" "API error (HTTP $http_code)" \
                        "Retry later or check Spotify API status"
                    return 1
                fi
                ;;
        esac
    done
    return 1
}

set_volume() {
    local percent="$1"
    if ! [[ "$percent" =~ ^[0-9]+$ ]] || [ "$percent" -lt 0 ] || [ "$percent" -gt 100 ]; then
        log_error "Volume must be a number between 0-100"
        exit 1
    fi
    api PUT "/me/player/volume?volume_percent=$percent" > /dev/null && log_info "Volume set to ${percent}%"
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
        if [ -z "${2:-}" ]; then
            log_error "Usage: $0 volume <0-100>|up|down"
            exit 1
        fi
        case "$2" in
            up|down)
                player_json=""
                if ! player_json=$(api GET "/me/player"); then
                    printf '%s\n' "$player_json"
                    exit 1
                fi
                cur=$(echo "$player_json" | jq -r '.device.volume_percent // 50')
                if [ "$2" = up ]; then
                    new=$((cur + 10))
                    [ "$new" -gt 100 ] && new=100
                else
                    new=$((cur - 10))
                    [ "$new" -lt 0 ] && new=0
                fi
                set_volume "$new"
                ;;
            *)
                set_volume "$2"
                ;;
        esac
        ;;
    shuffle)
        if [ -z "${2:-}" ]; then
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
        if [ -z "${2:-}" ]; then
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
        # /me/player includes is_playing + device volume; currently-playing alone hides pause.
        result=$(api GET "/me/player")
        if [ -n "$result" ] && [ "$result" != "null" ]; then
            echo "$result" | jq -r '
                if (.item == null) then "Nothing playing"
                else
                  (if .is_playing then "playing" else "paused" end) as $st
                  | "\($st): \(.item.name) - \(.item.artists[0].name)\n\(.item.album.name) | \(.device.name // "unknown") @ \(.device.volume_percent // "?")%"
                end'
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
        if [ -z "${2:-}" ]; then
            log_error "Usage: $0 add-queue <spotify:track:xxx>"
            exit 1
        fi
        if [[ ! "$2" =~ ^spotify:(track|episode):[a-zA-Z0-9]+$ ]]; then
            emit_error "INVALID_URI" "Invalid URI" \
                "Must be spotify:track:<id> or spotify:episode:<id>"
            exit 1
        fi
        encoded_uri=$(printf '%s' "$2" | jq -sRr @uri)
        api POST "/me/player/queue?uri=$encoded_uri" > /dev/null && log_info "Added to queue"
        ;;
    seek)
        if [ -z "${2:-}" ]; then
            log_error "Usage: $0 seek <seconds>"
            exit 1
        fi
        if ! [[ "$2" =~ ^[0-9]+$ ]]; then
            log_error "Seek position must be a number (seconds)"
            exit 1
        fi
        ms=$(($2 * 1000))
        api PUT "/me/player/seek?position_ms=$ms" > /dev/null && log_info "Seeked to ${2}s"
        ;;
    transfer)
        if [ -z "${2:-}" ]; then
            log_error "Usage: $0 transfer <device_name>"
            exit 1
        fi
        devices_json=$(api GET "/me/player/devices")
        if ! device_id=$(resolve_device_id "$2" "$devices_json"); then
            emit_error "DEVICE_NOT_FOUND" "Device '$2' not found or ambiguous" \
                "Check ./spotify/scripts/spotify-ctl.sh devices"
            echo "$devices_json" | jq -r '.devices[]? | "  - \(.name)"' >&2
            exit 1
        fi
        if ! validate_device_id "$device_id"; then
            emit_error "DEVICE_NOT_FOUND" "Invalid device ID format from API" \
                "Check ./spotify/scripts/spotify-ctl.sh devices"
            exit 1
        fi
        transfer_body=$(jq -n --arg id "$device_id" '{"device_ids": [$id], "play": true}')
        api PUT "/me/player" "$transfer_body" > /dev/null && log_info "Transferred to $2"
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
        echo "  volume up|down     Adjust volume by 10%"
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
        echo "Run '$0 --help' for usage" >&2
        exit 1
        ;;
esac

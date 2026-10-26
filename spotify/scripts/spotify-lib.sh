#!/bin/bash
# Shared helpers for Spotify CLI. Sourced by spotify.sh — not run directly.

SPOTIFY_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/spotify"
CONFIG_FILE="$SPOTIFY_DIR/config.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# API call with retry. Bearer token via curl -K (not argv).
# 404 → return 44 (caller may wake device or emit NO_DEVICE).
api_call() {
    local method="$1"
    local url="$2"
    local data="${3:-}"
    local max_retries=3
    local retry_delay=1
    local token
    if ! token=$(get_token); then
        emit_error "AUTH_REQUIRED" "No valid Spotify token" \
            "Ask user for Spotify Client ID/Secret if needed, save to ~/.config/spotify/credentials.json, then run ./scripts/spotify-auth.sh login"
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
                curl -K - -s -D "$hdr" -o "$body_file" -w "%{http_code}" -X "$method" "$url" \
                -H "Content-Type: application/json" -d "$data")
        else
            http_code=$(echo "header = \"Authorization: Bearer $token\"" | \
                curl -K - -s -D "$hdr" -o "$body_file" -w "%{http_code}" -X "$method" "$url")
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
                    "Re-run ./scripts/spotify-auth.sh login (refresh credentials if login still fails)"
                return 1
                ;;
            403)
                emit_error "PREMIUM_REQUIRED" "Forbidden — Spotify Premium required for playback" \
                    "Upgrade to Spotify Premium"
                return 1
                ;;
            404)
                return 44
                ;;
            *)
                if [ "$i" -lt "$max_retries" ]; then
                    sleep "$retry_delay"
                    retry_delay=$((retry_delay * 2))
                else
                    emit_error "API_ERROR" "Request failed (HTTP $http_code)" \
                        "Retry later or check Spotify API status"
                    return 1
                fi
                ;;
        esac
    done
    return 1
}

api() {
    local method="$1"
    local endpoint="$2"
    local data="${3:-}"
    local status=0
    local out
    out=$(api_call "$method" "https://api.spotify.com/v1$endpoint" "$data") || status=$?
    if [ "$status" -eq 44 ]; then
        emit_error "NO_DEVICE" "No active playback device" \
            "Open Spotify on a device, or: ./scripts/spotify.sh devices / device NAME"
        return 1
    fi
    if [ "$status" -ne 0 ]; then
        printf '%s\n' "$out"
        return "$status"
    fi
    printf '%s\n' "$out"
}

load_config() { [ -f "$CONFIG_FILE" ] && cat "$CONFIG_FILE" || echo '{}'; }

save_config() {
    mkdir -p "$SPOTIFY_DIR" && chmod 700 "$SPOTIFY_DIR"
    (umask 077 && echo "$1" > "$CONFIG_FILE")
}

get_default_device() { load_config | jq -r '.default_device // empty'; }

set_default_device() {
    save_config "$(load_config | jq --arg dev "$1" '.default_device = $dev')"
    log_info "Default device set to: $1"
}

validate_device_id() {
    [[ "$1" =~ ^[a-fA-F0-9]{40}$ ]] || [[ "$1" =~ ^[a-f0-9-]{36}_amzn_[0-9]+$ ]]
}

validate_uri() { [[ "$1" =~ ^spotify:[a-z_]+:[a-zA-Z0-9]+$ ]]; }

url_encode() {
    printf '%s' "$1" | jq -sRr @uri
}

# Prefer exact case-insensitive name; contains only if unique.
get_device_id() {
    local name="$1"
    local result
    result=$(api_call GET "https://api.spotify.com/v1/me/player/devices") || return 1

    local exact contains count device_id
    exact=$(echo "$result" | jq -r --arg n "$name" \
        '[.devices[]? | select((.name | ascii_downcase) == ($n | ascii_downcase)) | .id] | .[]')
    count=$(printf '%s\n' "$exact" | grep -c . || true)
    if [ "$count" -eq 1 ]; then
        device_id="$exact"
    elif [ "$count" -gt 1 ]; then
        emit_error "DEVICE_NOT_FOUND" "Multiple devices named '$name'" \
            "Check ./scripts/spotify.sh devices and use a unique name"
        return 1
    else
        contains=$(echo "$result" | jq -r --arg n "$name" \
            '[.devices[]? | select(.name | ascii_downcase | contains($n | ascii_downcase)) | .id] | .[]')
        count=$(printf '%s\n' "$contains" | grep -c . || true)
        if [ "$count" -eq 1 ]; then
            device_id="$contains"
        else
            emit_error "DEVICE_NOT_FOUND" "Device '$name' not found or ambiguous" \
                "Check ./scripts/spotify.sh devices"
            return 1
        fi
    fi

    validate_device_id "$device_id" || {
        emit_error "DEVICE_NOT_FOUND" "Invalid device ID format from API" \
            "Check ./scripts/spotify.sh devices"
        return 1
    }
    echo "$device_id"
}

resolve_device() {
    local device_name="${1:-}"
    if [ -n "$device_name" ]; then
        # get_device_id already emits DEVICE_NOT_FOUND on failure
        get_device_id "$device_name" || return 1
    else
        local default
        default=$(get_default_device)
        if [ -n "$default" ]; then
            get_device_id "$default" || true
        fi
    fi
}

list_devices_json() {
    local status=0
    local result
    result=$(api_call GET "https://api.spotify.com/v1/me/player/devices") || status=$?
    if [ "$status" -ne 0 ]; then
        printf '%s\n' "$result"
        return "$status"
    fi
    echo "$result" | jq '{
        devices: [.devices[]? | {name, type, id, is_active, volume: .volume_percent}]
    }'
}

wake_device() {
    log_info "Waking device..."
    api_call PUT "https://api.spotify.com/v1/me/player" \
        "$(jq -n --arg id "$1" '{"device_ids": [$id], "play": true}')" >/dev/null 2>&1 || true
    sleep 2
}

do_play_uri() {
    local uri="$1"
    local device_id="${2:-}"

    uri=$(echo "$uri" | sed 's/:playlist_v2:/:playlist:/')
    if ! validate_uri "$uri"; then
        emit_error "INVALID_URI" "Invalid URI: $uri" "Use format spotify:track:<id> (or playlist/album/artist)"
        return 1
    fi

    local body
    if [[ "$uri" == *":track:"* ]]; then
        body=$(jq -n --arg u "$uri" '{"uris":[$u]}')
    else
        body=$(jq -n --arg u "$uri" '{"context_uri":$u}')
    fi

    local url="https://api.spotify.com/v1/me/player/play"
    [ -n "$device_id" ] && url="$url?device_id=$device_id"

    local status=0
    api_call PUT "$url" "$body" >/dev/null || status=$?

    if [ "$status" -eq 44 ]; then
        if [ -z "$device_id" ]; then
            emit_error "NO_DEVICE" "No active playback device" \
                "Open Spotify on a device, or: ./scripts/spotify.sh device NAME"
            return 1
        fi
        wake_device "$device_id"
        if ! api_call PUT "$url" "$body" >/dev/null; then
            emit_error "NO_DEVICE" "No active playback device" \
                "Open Spotify on a device, or: ./scripts/spotify.sh device NAME"
            return 1
        fi
        return 0
    fi

    return "$status"
}

# Current playback as JSON (for auto-play confirm and `now`).
# Optional first arg: expected track/episode URI — retry until player catches up.
# Album/playlist/artist URIs are ignored (playing item is always a track/episode).
now_json() {
    local expect_uri="${1:-}"
    local status=0
    local result
    local attempt
    local max_attempts=1

    if [[ "$expect_uri" == spotify:track:* || "$expect_uri" == spotify:episode:* ]]; then
        max_attempts=5
    else
        expect_uri=""
    fi

    for ((attempt=1; attempt<=max_attempts; attempt++)); do
        status=0
        result=$(api_call GET "https://api.spotify.com/v1/me/player") || status=$?
        if [ "$status" -eq 44 ] || [ -z "$result" ] || [ "$result" = "null" ]; then
            if [ -n "$expect_uri" ] && [ "$attempt" -lt "$max_attempts" ]; then
                sleep 0.4
                continue
            fi
            jq -n '{status:"none"}'
            return 0
        fi
        if [ "$status" -ne 0 ]; then
            printf '%s\n' "$result"
            return "$status"
        fi
        if [ -n "$expect_uri" ]; then
            local got
            got=$(echo "$result" | jq -r '.item.uri // empty')
            if [ "$got" != "$expect_uri" ] && [ "$attempt" -lt "$max_attempts" ]; then
                sleep 0.4
                continue
            fi
        fi
        echo "$result" | jq '{
            status: (if .item == null then "none"
                     elif .is_playing then "playing"
                     else "paused" end),
            name: (.item.name // null),
            artist: (.item.artists[0].name // null),
            album: (.item.album.name // null),
            uri: (.item.uri // null),
            device: (.device.name // null),
            volume: (.device.volume_percent // null)
        }'
        return 0
    done
}

normalize() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 ]//g' | xargs
}

core_name() {
    echo "$1" | sed -E 's/ (remaster(ed)?([0-9 ]*)?|feat|ft|with|live|radio edit|extended|deluxe|anniversary).*$//' | xargs
}

without_artist_words() {
    local query="$1"
    local artist="$2"
    local -a query_words artist_words kept
    local word artist_word skip
    read -ra query_words <<< "$query"
    read -ra artist_words <<< "$artist"
    for word in "${query_words[@]}"; do
        skip=0
        for artist_word in "${artist_words[@]}"; do
            if [[ -n "$artist_word" && "$word" == "$artist_word" ]]; then
                skip=1
                break
            fi
        done
        [[ "$skip" -eq 0 ]] && kept+=("$word")
    done
    echo "${kept[*]:-}"
}

is_clean_match() {
    local query="$1"
    local name="$2"
    local artist="${3:-}"
    local norm_query norm_name core
    norm_query=$(normalize "$query")
    norm_name=$(normalize "$name")
    core=$(core_name "$norm_name")

    [[ -z "$norm_query" || -z "$norm_name" ]] && return 1

    [[ "$norm_query" == "$norm_name" ]] && return 0
    [[ "$norm_query" == "$core" ]] && return 0

    local -a query_words name_words
    read -ra query_words <<< "$norm_query"
    read -ra name_words <<< "$core"

    local matches=0 significant=0
    local qw nw
    for qw in "${query_words[@]}"; do
        [[ ${#qw} -lt 4 ]] && continue
        significant=$((significant + 1))
        for nw in "${name_words[@]}"; do
            if [[ "$qw" == "$nw" ]]; then
                matches=$((matches + 1))
                break
            fi
        done
    done

    if [[ $significant -ge 2 && $matches -eq $significant ]]; then
        local name_sig=0
        for nw in "${name_words[@]}"; do
            [[ ${#nw} -ge 4 ]] && name_sig=$((name_sig + 1))
        done
        [[ $name_sig -le $((significant + 1)) ]] && return 0
    fi

    if [[ -n "$artist" ]]; then
        local norm_artist reduced
        norm_artist=$(normalize "$artist")
        reduced=$(without_artist_words "$norm_query" "$norm_artist")
        if [[ -n "$reduced" && "$reduced" != "$norm_query" ]]; then
            is_clean_match "$reduced" "$name" && return 0
        fi
    fi

    return 1
}

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
#   - High-confidence match → auto-plays, returns {match:"auto", ...}
#   - Otherwise → {match:"unclear", results:[...]} for the agent to pick

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SPOTIFY_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/spotify"
CONFIG_FILE="$SPOTIFY_DIR/config.json"

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

# API call with retry. Uses curl -K - so the Bearer token is not on argv.
# Captures Retry-After header on 429.
api_call() {
    local method="$1"
    local url="$2"
    local data="${3:-}"
    local max_retries=3
    local retry_delay=1
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
                    "Re-run ./spotify/scripts/spotify-auth.sh login (refresh credentials if login still fails)"
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
        log_error "Multiple devices named '$name'"
        return 1
    else
        contains=$(echo "$result" | jq -r --arg n "$name" \
            '[.devices[]? | select(.name | ascii_downcase | contains($n | ascii_downcase)) | .id] | .[]')
        count=$(printf '%s\n' "$contains" | grep -c . || true)
        if [ "$count" -eq 1 ]; then
            device_id="$contains"
        else
            return 1
        fi
    fi

    validate_device_id "$device_id" || { log_error "Invalid device ID"; return 1; }
    echo "$device_id"
}

list_devices_json() {
    api_call GET "https://api.spotify.com/v1/me/player/devices" | jq '{
        devices: [.devices[]? | {name, type, id, is_active, volume: .volume_percent}]
    }'
}

url_encode() {
    printf '%s' "$1" | jq -sRr @uri
}

validate_uri() { [[ "$1" =~ ^spotify:[a-z_]+:[a-zA-Z0-9]+$ ]]; }

wake_device() {
    log_info "Waking device..."
    api_call PUT "https://api.spotify.com/v1/me/player" \
        "$(jq -n --arg id "$1" '{"device_ids": [$id], "play": true}')" >/dev/null 2>&1 || true
    sleep 2
}

normalize() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 ]//g' | xargs
}

# Strip common suffixes so "Bohemian Rhapsody - Remastered" can exact-match the query.
core_name() {
    echo "$1" | sed -E 's/ (remaster(ed)?([0-9 ]*)?|feat|ft|with|live|radio edit|extended|deluxe|anniversary).*$//' | xargs
}

# Remove whole words that are the result's artist so
# "bohemian rhapsody by queen" can match the title Bohemian Rhapsody.
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

# High-confidence only. Short / substring queries must return unclear.
# artist is optional; its words are not required to appear in the title.
is_clean_match() {
    local query="$1"
    local name="$2"
    local artist="${3:-}"
    local norm_query norm_name core
    norm_query=$(normalize "$query")
    norm_name=$(normalize "$name")
    core=$(core_name "$norm_name")

    [[ -z "$norm_query" || -z "$norm_name" ]] && return 1

    # Exact (full or core name — core strips remaster/feat suffixes)
    [[ "$norm_query" == "$norm_name" ]] && return 0
    [[ "$norm_query" == "$core" ]] && return 0

    # Multi-word: ≥2 significant tokens (4+ chars), all present, name not much longer
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
        # Reject when the result title is much longer than the query
        # ("best songs" must not auto-play "Best Songs of the 80s Forever Hits").
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
                "Open Spotify on a device, or pass --device / --set-device"
            return 1
        fi
        wake_device "$device_id"
        if ! api_call PUT "$url" "$body" >/dev/null; then
            emit_error "NO_DEVICE" "No active playback device" \
                "Open Spotify on a device, or pass --device / --set-device"
            return 1
        fi
        return 0
    fi

    return "$status"
}

resolve_device() {
    local device_name="${1:-}"
    if [ -n "$device_name" ]; then
        get_device_id "$device_name" || {
            emit_error "DEVICE_NOT_FOUND" "Device '$device_name' not found" \
                "Check ./spotify/scripts/spotify-ctl.sh devices"
            return 1
        }
    else
        local default
        default=$(get_default_device)
        if [ -n "$default" ]; then
            get_device_id "$default" || true
        fi
    fi
}

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

    local encoded raw
    encoded=$(url_encode "$query")
    if ! raw=$(api_call GET "https://api.spotify.com/v1/search?q=$encoded&type=$type&limit=10"); then
        printf '%s\n' "$raw"
        exit 1
    fi
    [ -z "$raw" ] && {
        emit_error "SEARCH_FAILED" "Search returned empty response" "Try a different query"
        exit 1
    }

    local items_path jq_filter
    case "$type" in
        track)
            items_path=".tracks.items"
            jq_filter='[.[]? | select(. != null) | {
                name, artist: (.artists[0].name // "Unknown"),
                album: (.album.name // "Unknown"), uri, duration_ms
            }]'
            ;;
        playlist)
            items_path=".playlists.items"
            jq_filter='[.[]? | select(. != null) | {
                name, owner: (.owner.display_name // "Unknown"),
                tracks: (.tracks.total // 0), uri
            }]'
            ;;
        album)
            items_path=".albums.items"
            jq_filter='[.[]? | select(. != null) | {
                name, artist: (.artists[0].name // "Unknown"),
                year: (.release_date // "" | split("-")[0]),
                tracks: (.total_tracks // 0), uri
            }]'
            ;;
        artist)
            items_path=".artists.items"
            jq_filter='[.[]? | select(. != null) | {
                name, genres: (.genres[:3] // []),
                followers: (.followers.total // 0), uri
            }]'
            ;;
    esac

    local results count
    results=$(echo "$raw" | jq "$items_path | $jq_filter")
    count=$(echo "$results" | jq 'length')

    if [ "$count" -eq 0 ]; then
        jq -n --arg q "$query" --arg t "$type" '{query:$q, type:$t, match:"none", results:[]}'
        exit 0
    fi

    local first_name first_uri first_artist
    first_name=$(echo "$results" | jq -r '.[0].name // ""')
    first_uri=$(echo "$results" | jq -r '.[0].uri // ""')
    first_artist=$(echo "$results" | jq -r '.[0].artist // ""')

    if is_clean_match "$query" "$first_name" "$first_artist"; then
        local device_id=""
        if ! device_id=$(resolve_device "$device_name"); then
            printf '%s\n' "$device_id"
            exit 1
        fi

        if do_play_uri "$first_uri" "$device_id"; then
            local shown_artist
            shown_artist=$(echo "$results" | jq -r '.[0].artist // .[0].owner // "Unknown"')
            log_info "Playing: $first_name by $shown_artist"
            echo "$results" | jq --arg q "$query" --arg t "$type" \
                '{query:$q, type:$t, match:"auto", playing:.[0], results:.}'
        else
            exit 1
        fi
    else
        log_warn "No high-confidence match for '$query'. Review results and pick one."
        echo "$results" | jq --arg q "$query" --arg t "$type" \
            '{query:$q, type:$t, match:"unclear", results:.}'
    fi
}

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

    local device_id=""
    if ! device_id=$(resolve_device "$device_name"); then
        printf '%s\n' "$device_id"
        exit 1
    fi

    if do_play_uri "$uri" "$device_id"; then
        log_info "Playback started"
        jq -n --arg u "$uri" '{status:"playing", uri:$u}'
    else
        exit 1
    fi
}

case "${1:-}" in
    search) shift; cmd_search "$@" ;;
    play) shift; cmd_play "$@" ;;
    --devices) list_devices_json ;;
    --set-device)
        [ -z "${2:-}" ] && { log_error "Usage: $0 --set-device <name>"; exit 1; }
        set_default_device "$2"
        ;;
    -h|--help|"")
        cat << 'EOF'
Spotify Search & Play

Usage:
  spotify-play.sh search "query" [--type track|playlist|album|artist] [--device NAME]
  spotify-play.sh play <spotify:uri> [--device NAME]
  spotify-play.sh --devices
  spotify-play.sh --set-device NAME

Search behavior:
  - High-confidence match → Auto-plays, returns {match:"auto", playing:{...}}
  - Otherwise             → Returns {match:"unclear", results:[...]} for agent to pick
  - No results            → Returns {match:"none", results:[]}
EOF
        ;;
    *) log_error "Unknown command: $1"; exit 1 ;;
esac

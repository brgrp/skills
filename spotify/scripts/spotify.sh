#!/bin/bash
# spotify.sh — single CLI for search, play, and playback control
#
# Usage:
#   ./spotify.sh search "query" [--type track|playlist|album|artist] [--device NAME]
#   ./spotify.sh play <spotify:uri> [--device NAME]
#   ./spotify.sh pause|resume|next|prev
#   ./spotify.sh now|queue|devices
#   ./spotify.sh device NAME          # set default device
#   ./spotify.sh transfer NAME
#   ./spotify.sh volume <0-100>|up|down
#   ./spotify.sh shuffle on|off
#   ./spotify.sh repeat track|context|off
#   ./spotify.sh seek <seconds>
#   ./spotify.sh add-queue <uri>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=spotify-lib.sh
source "$SCRIPT_DIR/spotify-lib.sh"

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

    [ -z "$query" ] && { log_error "Usage: $0 search \"query\" [--type TYPE] [--device NAME]"; exit 1; }

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
            local shown_artist playing
            shown_artist=$(echo "$results" | jq -r '.[0].artist // .[0].owner // "Unknown"')
            log_info "Playing: $first_name by $shown_artist"
            playing=$(now_json "$first_uri")
            echo "$results" | jq --arg q "$query" --arg t "$type" --argjson p "$playing" \
                '{query:$q, type:$t, match:"auto", playing:.[0], now:$p, results:.}'
        else
            exit 1
        fi
    else
        log_warn "No high-confidence match for '$query'. Review results and pick one."
        echo "$results" | jq --arg q "$query" --arg t "$type" \
            '{query:$q, type:$t, match:"unclear", results:.}'
    fi
}

cmd_play_uri() {
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
        local playing
        playing=$(now_json "$uri")
        jq -n --arg u "$uri" --argjson p "$playing" '{status:"playing", uri:$u, now:$p}'
    else
        exit 1
    fi
}

cmd_volume() {
    if [ -z "${1:-}" ]; then
        log_error "Usage: $0 volume <0-100>|up|down"
        exit 1
    fi
    local percent
    case "$1" in
        up|down)
            local player_json cur new
            if ! player_json=$(api GET "/me/player"); then
                printf '%s\n' "$player_json"
                exit 1
            fi
            cur=$(echo "$player_json" | jq -r '.device.volume_percent // 50')
            if [ "$1" = up ]; then
                new=$((cur + 10))
                [ "$new" -gt 100 ] && new=100
            else
                new=$((cur - 10))
                [ "$new" -lt 0 ] && new=0
            fi
            percent=$new
            ;;
        *)
            percent="$1"
            ;;
    esac
    if ! [[ "$percent" =~ ^[0-9]+$ ]] || [ "$percent" -lt 0 ] || [ "$percent" -gt 100 ]; then
        log_error "Volume must be a number between 0-100"
        exit 1
    fi
    api PUT "/me/player/volume?volume_percent=$percent" > /dev/null && log_info "Volume set to ${percent}%"
    jq -n --argjson v "$percent" '{status:"ok", volume:$v}'
}

usage() {
    cat << 'EOF'
Spotify — search, play, and control

Auth (separate):
  ./scripts/spotify-auth.sh status|login

Play:
  spotify.sh search "query" [--type track|playlist|album|artist] [--device NAME]
  spotify.sh play <spotify:uri> [--device NAME]

Control:
  spotify.sh pause|resume|next|prev
  spotify.sh volume <0-100>|up|down
  spotify.sh shuffle on|off
  spotify.sh repeat track|context|off
  spotify.sh seek <seconds>
  spotify.sh add-queue <spotify:track:xxx>

Info / device:
  spotify.sh now
  spotify.sh queue
  spotify.sh devices
  spotify.sh device NAME       Set default device
  spotify.sh transfer NAME     Move playback to device

Search: auto → plays + returns {match:"auto", playing, now}; unclear → pick a URI then play.
EOF
}

case "${1:-}" in
    search) shift; cmd_search "$@" ;;
    play)
        shift
        if [ $# -eq 0 ]; then
            api PUT "/me/player/play" > /dev/null && log_info "Playing"
            now_json
        else
            cmd_play_uri "$@"
        fi
        ;;
    resume)
        api PUT "/me/player/play" > /dev/null && log_info "Playing"
        now_json
        ;;
    pause)
        api PUT "/me/player/pause" > /dev/null && log_info "Paused"
        now_json
        ;;
    next|skip)
        api POST "/me/player/next" > /dev/null && log_info "Skipped to next"
        sleep 1
        now_json
        ;;
    prev|previous)
        api POST "/me/player/previous" > /dev/null && log_info "Back to previous"
        sleep 1
        now_json
        ;;
    volume|vol) shift; cmd_volume "$@" ;;
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
        jq -n --arg s "$2" '{status:"ok", shuffle:$s}'
        ;;
    repeat)
        if [ -z "${2:-}" ]; then
            log_error "Usage: $0 repeat track|context|off"
            exit 1
        fi
        case "$2" in
            track|context|off)
                api PUT "/me/player/repeat?state=$2" > /dev/null && log_info "Repeat: $2"
                jq -n --arg s "$2" '{status:"ok", repeat:$s}'
                ;;
            *)
                log_error "Invalid mode '$2'. Use: track, context, or off"
                exit 1
                ;;
        esac
        ;;
    devices|--devices)
        list_devices_json
        ;;
    device|--set-device)
        [ -z "${2:-}" ] && { log_error "Usage: $0 device <name>"; exit 1; }
        set_default_device "$2"
        jq -n --arg d "$2" '{status:"ok", default_device:$d}'
        ;;
    now|current|playing)
        now_json
        ;;
    queue)
        result=$(api GET "/me/player/queue")
        echo "$result" | jq '{
            current: (if .currently_playing then {
                name: .currently_playing.name,
                artist: .currently_playing.artists[0].name,
                uri: .currently_playing.uri
            } else null end),
            queue: [.queue[:10][]? | {name, artist: .artists[0].name, uri}]
        }'
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
        jq -n --arg u "$2" '{status:"ok", queued:$u}'
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
        jq -n --argjson s "$2" '{status:"ok", seek_seconds:$s}'
        ;;
    transfer)
        if [ -z "${2:-}" ]; then
            log_error "Usage: $0 transfer <device_name>"
            exit 1
        fi
        if ! device_id=$(get_device_id "$2"); then
            printf '%s\n' "$device_id"
            exit 1
        fi
        transfer_body=$(jq -n --arg id "$device_id" '{"device_ids": [$id], "play": true}')
        api PUT "/me/player" "$transfer_body" > /dev/null && log_info "Transferred to $2"
        now_json
        ;;
    -h|--help|"")
        usage
        ;;
    *)
        log_error "Unknown command: $1"
        echo "Run '$0 --help' for usage" >&2
        exit 1
        ;;
esac

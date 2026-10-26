#!/bin/bash
# spotify-auth.sh - OAuth helper for Spotify Web API
#
# Usage:
#   ./spotify-auth.sh login     - Start OAuth (open http://127.0.0.1:17823/)
#   ./spotify-auth.sh token     - Get current access token (refreshes if needed)
#   ./spotify-auth.sh status    - Check authentication status
#   ./spotify-auth.sh refresh   - Force token refresh
#
# Prerequisites:
#   - Create app at https://developer.spotify.com/dashboard
#   - Set redirect URI to http://127.0.0.1:17823/callback
#   - Credentials via SPOTIFY_CLIENT_ID / SPOTIFY_CLIENT_SECRET,
#     ~/.config/spotify/credentials.json, or interactive prompt

set -euo pipefail

SPOTIFY_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/spotify"
TOKEN_FILE="$SPOTIFY_DIR/tokens.json"
CREDENTIALS_FILE="$SPOTIFY_DIR/credentials.json"
STATE_FILE="$SPOTIFY_DIR/.oauth_state"
REDIRECT_URI="http://127.0.0.1:17823/callback"
SCOPES="user-read-playback-state user-modify-playback-state user-read-currently-playing user-read-private playlist-read-private user-library-read"
OAUTH_PORT=17823
OAUTH_TIMEOUT=300
OAUTH_BIND="127.0.0.1"

SPOTIFY_CLIENT_ID="${SPOTIFY_CLIENT_ID:-}"
SPOTIFY_CLIENT_SECRET="${SPOTIFY_CLIENT_SECRET:-}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

check_dependencies() {
    local missing=0
    for cmd in curl jq openssl python3; do
        if ! command -v "$cmd" &> /dev/null; then
            log_error "Required command '$cmd' not found. Please install it."
            missing=1
        fi
    done
    [ "$missing" -eq 0 ] || exit 1
}

load_credentials() {
    if [ -n "$SPOTIFY_CLIENT_ID" ] && [ -n "$SPOTIFY_CLIENT_SECRET" ]; then
        return 0
    fi

    if [ -f "$CREDENTIALS_FILE" ]; then
        SPOTIFY_CLIENT_ID=$(jq -r '.client_id // empty' "$CREDENTIALS_FILE" 2>/dev/null)
        SPOTIFY_CLIENT_SECRET=$(jq -r '.client_secret // empty' "$CREDENTIALS_FILE" 2>/dev/null)

        if [ -n "$SPOTIFY_CLIENT_ID" ] && [ -n "$SPOTIFY_CLIENT_SECRET" ]; then
            return 0
        fi
    fi

    return 1
}

prompt_credentials() {
    log_info "Spotify credentials not found."
    log_info "Get your Client ID and Secret from https://developer.spotify.com/dashboard"
    echo "" >&2

    read -r -p "Enter Spotify Client ID: " SPOTIFY_CLIENT_ID
    if [ -z "$SPOTIFY_CLIENT_ID" ]; then
        log_error "Client ID cannot be empty"
        exit 1
    fi

    read -r -s -p "Enter Spotify Client Secret: " SPOTIFY_CLIENT_SECRET
    echo "" >&2
    if [ -z "$SPOTIFY_CLIENT_SECRET" ]; then
        log_error "Client Secret cannot be empty"
        exit 1
    fi

    mkdir -p "$SPOTIFY_DIR"
    chmod 700 "$SPOTIFY_DIR"
    (umask 077 && jq -n \
        --arg id "$SPOTIFY_CLIENT_ID" \
        --arg secret "$SPOTIFY_CLIENT_SECRET" \
        '{client_id: $id, client_secret: $secret}' > "$CREDENTIALS_FILE")
    log_info "Credentials saved to $CREDENTIALS_FILE"
}

check_credentials() {
    if ! load_credentials; then
        if [ -t 0 ]; then
            prompt_credentials
        else
            log_error "Missing credentials (non-interactive). Set SPOTIFY_CLIENT_ID and SPOTIFY_CLIENT_SECRET, or create $CREDENTIALS_FILE"
            exit 1
        fi
    fi

    if [ -z "$SPOTIFY_CLIENT_ID" ] || [ -z "$SPOTIFY_CLIENT_SECRET" ]; then
        log_error "Missing credentials. Provide Client ID and Secret."
        exit 1
    fi
}

ensure_token_dir() {
    mkdir -p "$SPOTIFY_DIR"
    chmod 700 "$SPOTIFY_DIR"
}

url_encode() {
    printf '%s' "$1" | jq -sRr @uri
}

generate_random_string() {
    openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 16
}

get_auth_url() {
    local state
    state=$(generate_random_string)
    (umask 077 && printf '%s' "$state" > "$STATE_FILE")

    # jq @uri so redirect_uri cannot be dropped by shell concatenation.
    jq -nr \
        --arg client_id "$SPOTIFY_CLIENT_ID" \
        --arg redirect_uri "$REDIRECT_URI" \
        --arg scope "$SCOPES" \
        --arg state "$state" \
        '"https://accounts.spotify.com/authorize?response_type=code&client_id=\($client_id|@uri)&scope=\($scope|@uri)&redirect_uri=\($redirect_uri|@uri)&state=\($state|@uri)"'
}

exchange_code() {
    local code="$1"

    local response
    response=$(printf '%s' "grant_type=authorization_code&code=$code&redirect_uri=$REDIRECT_URI&client_id=$SPOTIFY_CLIENT_ID&client_secret=$SPOTIFY_CLIENT_SECRET" | \
        curl -s -X POST "https://accounts.spotify.com/api/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        --data-binary @-)

    if echo "$response" | jq -e '.access_token' > /dev/null 2>&1; then
        local access_token refresh_token expires_in expires_at
        access_token=$(echo "$response" | jq -r '.access_token')
        refresh_token=$(echo "$response" | jq -r '.refresh_token')
        expires_in=$(echo "$response" | jq -r '.expires_in')
        expires_at=$(($(date +%s) + expires_in))

        (umask 077 && jq -n \
            --arg at "$access_token" \
            --arg rt "$refresh_token" \
            --argjson exp "$expires_at" \
            '{access_token: $at, refresh_token: $rt, expires_at: $exp}' > "$TOKEN_FILE")

        log_info "Tokens saved to $TOKEN_FILE"
        return 0
    else
        log_error "Failed to exchange code (API error)"
        return 1
    fi
}

refresh_token() {
    if [ ! -f "$TOKEN_FILE" ]; then
        log_error "No token file found. Run './spotify/scripts/spotify-auth.sh login' first."
        return 1
    fi

    local refresh
    refresh=$(jq -r '.refresh_token' "$TOKEN_FILE")

    if [ -z "$refresh" ] || [ "$refresh" = "null" ]; then
        log_error "No refresh token found. Run './spotify/scripts/spotify-auth.sh login' first."
        return 1
    fi

    local response
    response=$(printf '%s' "grant_type=refresh_token&refresh_token=$refresh&client_id=$SPOTIFY_CLIENT_ID&client_secret=$SPOTIFY_CLIENT_SECRET" | \
        curl -s -X POST "https://accounts.spotify.com/api/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        --data-binary @-)

    if echo "$response" | jq -e '.access_token' > /dev/null 2>&1; then
        local access_token new_refresh expires_in expires_at
        access_token=$(echo "$response" | jq -r '.access_token')
        new_refresh=$(echo "$response" | jq -r '.refresh_token // empty')
        expires_in=$(echo "$response" | jq -r '.expires_in')
        expires_at=$(($(date +%s) + expires_in))

        if [ -z "$new_refresh" ]; then
            new_refresh="$refresh"
        fi

        (umask 077 && jq -n \
            --arg at "$access_token" \
            --arg rt "$new_refresh" \
            --argjson exp "$expires_at" \
            '{access_token: $at, refresh_token: $rt, expires_at: $exp}' > "$TOKEN_FILE")

        log_info "Token refreshed successfully"
        return 0
    else
        log_error "Failed to refresh token (API error)"
        return 1
    fi
}

get_token() {
    if [ ! -f "$TOKEN_FILE" ]; then
        log_error "No token file found. Run './spotify/scripts/spotify-auth.sh login' first."
        return 1
    fi

    local expires_at now
    expires_at=$(jq -r '.expires_at' "$TOKEN_FILE")
    now=$(date +%s)

    if [ $((expires_at - now)) -lt 300 ]; then
        log_info "Token expired or expiring soon, refreshing..."
        refresh_token
    fi

    jq -r '.access_token' "$TOKEN_FILE"
}

check_status() {
    if [ ! -f "$TOKEN_FILE" ]; then
        log_warn "Not authenticated. Run './spotify/scripts/spotify-auth.sh login'"
        return 1
    fi

    local expires_at now remaining
    expires_at=$(jq -r '.expires_at' "$TOKEN_FILE")
    now=$(date +%s)
    remaining=$((expires_at - now))

    if [ "$remaining" -lt 0 ]; then
        log_warn "Token expired. Run './spotify/scripts/spotify-auth.sh refresh' or './spotify/scripts/spotify-auth.sh token'"
    else
        log_info "Authenticated. Token expires in $((remaining / 60)) minutes"

        local token response
        token=$(jq -r '.access_token' "$TOKEN_FILE")
        response=$(echo "header = \"Authorization: Bearer $token\"" | \
            curl -K - -s -w "%{http_code}" -o /dev/null \
            "https://api.spotify.com/v1/me")

        if [ "$response" = "200" ]; then
            log_info "Token is valid"
        elif [ "$response" = "401" ]; then
            log_warn "Token invalid, needs refresh"
        else
            log_warn "API returned status $response"
        fi
    fi
}

# Loopback only. GET / redirects to Spotify so the user never copies a URL with '&'.
# GET /callback receives the authorization code.
wait_for_oauth_callback() {
    local auth_url="$1"
    python3 - "$OAUTH_PORT" "$OAUTH_TIMEOUT" "$auth_url" "$OAUTH_BIND" <<'PY'
import json
import sys
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs, urlparse

port = int(sys.argv[1])
timeout = int(sys.argv[2])
authorize_url = sys.argv[3]
bind_host = sys.argv[4]
deadline = time.time() + timeout
result = {"code": None, "state": None, "error": None, "done": False}

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path in ("/", ""):
            self.send_response(302)
            self.send_header("Location", authorize_url)
            self.end_headers()
            return
        if parsed.path == "/callback":
            qs = parse_qs(parsed.query)
            result["code"] = (qs.get("code") or [None])[0]
            result["state"] = (qs.get("state") or [None])[0]
            result["error"] = (qs.get("error") or [None])[0]
            result["done"] = True
            body = (
                b"<html><body><h1>Success!</h1>"
                b"<p>You can close this window.</p></body></html>"
            )
            self.send_response(200)
            self.send_header("Content-Type", "text/html")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        self.send_response(404)
        self.end_headers()

    def log_message(self, *_args):
        pass

server = HTTPServer((bind_host, port), Handler)
server.timeout = 1
while not result["done"] and time.time() < deadline:
    server.handle_request()
print(json.dumps({k: result[k] for k in ("code", "state", "error")}))
PY
}

complete_authorization() {
    local code="$1"
    local returned_state="$2"
    local error="${3:-}"

    if [ -n "$error" ]; then
        log_error "Authorization failed: $error"
        rm -f "$STATE_FILE"
        return 1
    fi

    if [ ! -f "$STATE_FILE" ]; then
        log_error "No state file found - cannot validate callback. Run login again, then paste that attempt's redirect URL."
        return 1
    fi

    local expected_state
    expected_state=$(cat "$STATE_FILE")
    rm -f "$STATE_FILE"

    if [ "$returned_state" != "$expected_state" ]; then
        log_error "State mismatch - possible CSRF attack"
        return 1
    fi

    if [ -z "$code" ]; then
        log_error "Failed to get authorization code"
        return 1
    fi

    log_info "Got authorization code, exchanging for tokens..."
    exchange_code "$code"
}

# Remote browser cannot reach this machine's 127.0.0.1. User pastes the failed redirect URL.
do_login_remote() {
    check_credentials
    ensure_token_dir

    local auth_url url_file
    auth_url=$(get_auth_url)
    url_file="$SPOTIFY_DIR/authorize.url"
    (umask 077 && printf '%s\n' "$auth_url" > "$url_file")

    if [[ "$auth_url" != *"redirect_uri="* ]]; then
        log_error "Internal error: authorize URL missing redirect_uri"
        return 1
    fi

    log_info "Open the URL in $url_file in your browser and approve access."
    log_info "The redirect to 127.0.0.1 will fail to load. Copy the entire address bar."
    log_info "Then run: $0 login --callback 'PASTED_URL'"
    echo "$auth_url"
}

complete_from_url() {
    local url="$1"
    local code returned_state error
    code=$(printf '%s' "$url" | sed -n 's/.*[?&]code=\([^&]*\).*/\1/p')
    returned_state=$(printf '%s' "$url" | sed -n 's/.*[?&]state=\([^&]*\).*/\1/p')
    error=$(printf '%s' "$url" | sed -n 's/.*[?&]error=\([^&]*\).*/\1/p')
    check_credentials
    complete_authorization "$code" "$returned_state" "$error"
}

do_login() {
    check_credentials
    ensure_token_dir

    local auth_url
    auth_url=$(get_auth_url)

    if [[ "$auth_url" != *"redirect_uri="* ]]; then
        log_error "Internal error: authorize URL missing redirect_uri"
        return 1
    fi

    local result_file listener_pid callback_json code returned_state error
    result_file=$(mktemp)
    wait_for_oauth_callback "$auth_url" > "$result_file" &
    listener_pid=$!

    local i
    for i in 1 2 3 4 5 6 7 8 9 10; do
        if (echo >/dev/tcp/127.0.0.1/"$OAUTH_PORT") >/dev/null 2>&1; then
            break
        fi
        sleep 0.1
    done

    log_info "Open this URL in your browser and approve access:"
    echo "http://127.0.0.1:${OAUTH_PORT}/" >&2
    log_info "Waiting up to ${OAUTH_TIMEOUT}s. Press Ctrl+C to cancel."

    wait "$listener_pid" || true
    callback_json=$(cat "$result_file")
    rm -f "$result_file"
    code=$(echo "$callback_json" | jq -r '.code // empty')
    returned_state=$(echo "$callback_json" | jq -r '.state // empty')
    error=$(echo "$callback_json" | jq -r '.error // empty')

    complete_authorization "$code" "$returned_state" "$error"
}

check_dependencies

case "${1:-}" in
    login)
        if [ "${2:-}" = "--callback" ]; then
            if [ -z "${3:-}" ]; then
                log_error "Usage: $0 login --callback '<redirect url from the address bar>'"
                exit 1
            fi
            complete_from_url "$3"
        elif [ -n "${SANDBOX_NAME:-}" ]; then
            do_login_remote
        else
            check_credentials
            do_login
        fi
        ;;
    token)
        check_credentials
        get_token
        ;;
    refresh)
        check_credentials
        refresh_token
        ;;
    status)
        check_status
        ;;
    *)
        echo "Spotify OAuth Helper"
        echo ""
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  login              - Start OAuth (local listener, or print a URL in a sandbox)"
        echo "  login --callback   - Finish login by pasting the redirect URL"
        echo "  token    - Get current access token (refreshes if needed)"
        echo "  refresh  - Force token refresh"
        echo "  status   - Check authentication status"
        echo ""
        echo "Credentials are loaded in this order:"
        echo "  1. Environment variables (SPOTIFY_CLIENT_ID, SPOTIFY_CLIENT_SECRET)"
        echo "  2. Credentials file (~/.config/spotify/credentials.json)"
        echo "  3. Interactive prompt (TTY only; saves to credentials file)"
        echo ""
        echo "Dependencies: curl, jq, openssl, python3"
        echo "Get credentials from https://developer.spotify.com/dashboard"
        ;;
esac

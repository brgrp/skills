#!/bin/bash
# spotify-auth.sh - OAuth helper for Spotify Web API
# 
# Usage:
#   ./spotify-auth.sh login     - Start OAuth flow (opens browser)
#   ./spotify-auth.sh token     - Get current access token (refreshes if needed)
#   ./spotify-auth.sh status    - Check authentication status
#   ./spotify-auth.sh refresh   - Force token refresh
#
# Prerequisites:
#   - Create app at https://developer.spotify.com/dashboard
#   - Set redirect URI to http://127.0.0.1:17823/callback
#   - Set environment variables or edit this script:
#     SPOTIFY_CLIENT_ID, SPOTIFY_CLIENT_SECRET

set -e

# Configuration
SPOTIFY_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/spotify"
TOKEN_FILE="$SPOTIFY_DIR/tokens.json"
CREDENTIALS_FILE="$SPOTIFY_DIR/credentials.json"
STATE_FILE="$SPOTIFY_DIR/.oauth_state"
REDIRECT_URI="http://127.0.0.1:17823/callback"
SCOPES="user-read-playback-state user-modify-playback-state user-read-currently-playing user-read-private playlist-read-private user-library-read"

# Will be loaded from env, file, or prompted
SPOTIFY_CLIENT_ID="${SPOTIFY_CLIENT_ID:-}"
SPOTIFY_CLIENT_SECRET="${SPOTIFY_CLIENT_SECRET:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_dependencies() {
    for cmd in curl jq nc; do
        if ! command -v "$cmd" &> /dev/null; then
            log_error "Required command '$cmd' not found. Please install it."
            exit 1
        fi
    done
}

load_credentials() {
    # Already set via environment variables?
    if [ -n "$SPOTIFY_CLIENT_ID" ] && [ -n "$SPOTIFY_CLIENT_SECRET" ]; then
        return 0
    fi
    
    # Try loading from credentials file
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
    echo ""
    
    read -p "Enter Spotify Client ID: " SPOTIFY_CLIENT_ID
    if [ -z "$SPOTIFY_CLIENT_ID" ]; then
        log_error "Client ID cannot be empty"
        exit 1
    fi
    
    read -p "Enter Spotify Client Secret: " SPOTIFY_CLIENT_SECRET
    if [ -z "$SPOTIFY_CLIENT_SECRET" ]; then
        log_error "Client Secret cannot be empty"
        exit 1
    fi
    
    # Save credentials (secure directory permissions)
    mkdir -p "$SPOTIFY_DIR"
    chmod 700 "$SPOTIFY_DIR"
    cat > "$CREDENTIALS_FILE" << EOF
{
  "client_id": "$SPOTIFY_CLIENT_ID",
  "client_secret": "$SPOTIFY_CLIENT_SECRET"
}
EOF
    chmod 600 "$CREDENTIALS_FILE"
    log_info "Credentials saved to $CREDENTIALS_FILE"
}

check_credentials() {
    if ! load_credentials; then
        prompt_credentials
    fi
    
    if [ -z "$SPOTIFY_CLIENT_ID" ] || [ -z "$SPOTIFY_CLIENT_SECRET" ]; then
        log_error "Missing credentials. Please provide valid Client ID and Secret."
        exit 1
    fi
}

ensure_token_dir() {
    mkdir -p "$SPOTIFY_DIR"
    chmod 700 "$SPOTIFY_DIR"
}

url_encode() {
    python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.stdin.read().strip(), safe=''))" <<< "$1"
}

generate_random_string() {
    openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 16
}

# Get authorization URL and save state for CSRF validation
get_auth_url() {
    local state=$(generate_random_string)
    local encoded_scopes=$(url_encode "$SCOPES")
    local encoded_redirect=$(url_encode "$REDIRECT_URI")
    
    # Save state for validation on callback
    echo "$state" > "$STATE_FILE"
    chmod 600 "$STATE_FILE"
    
    echo "https://accounts.spotify.com/authorize?response_type=code&client_id=$SPOTIFY_CLIENT_ID&scope=$encoded_scopes&redirect_uri=$encoded_redirect&state=$state"
}

# Exchange authorization code for tokens
exchange_code() {
    local code="$1"
    
    local response=$(curl -s -X POST "https://accounts.spotify.com/api/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=authorization_code&code=$code&redirect_uri=$REDIRECT_URI&client_id=$SPOTIFY_CLIENT_ID&client_secret=$SPOTIFY_CLIENT_SECRET")
    
    if echo "$response" | jq -e '.access_token' > /dev/null 2>&1; then
        local access_token=$(echo "$response" | jq -r '.access_token')
        local refresh_token=$(echo "$response" | jq -r '.refresh_token')
        local expires_in=$(echo "$response" | jq -r '.expires_in')
        local expires_at=$(($(date +%s) + expires_in))
        
        # Save tokens
        echo "{
  \"access_token\": \"$access_token\",
  \"refresh_token\": \"$refresh_token\",
  \"expires_at\": $expires_at
}" > "$TOKEN_FILE"
        
        chmod 600 "$TOKEN_FILE"
        log_info "Tokens saved to $TOKEN_FILE"
        return 0
    else
        log_error "Failed to exchange code (API error)"
        return 1
    fi
}

# Refresh access token
refresh_token() {
    if [ ! -f "$TOKEN_FILE" ]; then
        log_error "No token file found. Run './spotify-auth.sh login' first."
        return 1
    fi
    
    local refresh=$(jq -r '.refresh_token' "$TOKEN_FILE")
    
    if [ -z "$refresh" ] || [ "$refresh" = "null" ]; then
        log_error "No refresh token found. Run './spotify-auth.sh login' first."
        return 1
    fi
    
    local response=$(curl -s -X POST "https://accounts.spotify.com/api/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=refresh_token&refresh_token=$refresh&client_id=$SPOTIFY_CLIENT_ID&client_secret=$SPOTIFY_CLIENT_SECRET")
    
    if echo "$response" | jq -e '.access_token' > /dev/null 2>&1; then
        local access_token=$(echo "$response" | jq -r '.access_token')
        local new_refresh=$(echo "$response" | jq -r '.refresh_token // empty')
        local expires_in=$(echo "$response" | jq -r '.expires_in')
        local expires_at=$(($(date +%s) + expires_in))
        
        # Use new refresh token if provided, otherwise keep old one
        if [ -z "$new_refresh" ]; then
            new_refresh="$refresh"
        fi
        
        # Update tokens
        echo "{
  \"access_token\": \"$access_token\",
  \"refresh_token\": \"$new_refresh\",
  \"expires_at\": $expires_at
}" > "$TOKEN_FILE"
        
        log_info "Token refreshed successfully"
        return 0
    else
        log_error "Failed to refresh token (API error)"
        return 1
    fi
}

# Get valid access token (refresh if needed)
get_token() {
    if [ ! -f "$TOKEN_FILE" ]; then
        log_error "No token file found. Run './spotify-auth.sh login' first." >&2
        return 1
    fi
    
    local expires_at=$(jq -r '.expires_at' "$TOKEN_FILE")
    local now=$(date +%s)
    
    # Refresh if token expires in less than 5 minutes
    if [ $((expires_at - now)) -lt 300 ]; then
        log_info "Token expired or expiring soon, refreshing..." >&2
        refresh_token >&2
    fi
    
    jq -r '.access_token' "$TOKEN_FILE"
}

# Check authentication status
check_status() {
    if [ ! -f "$TOKEN_FILE" ]; then
        log_warn "Not authenticated. Run './spotify-auth.sh login'"
        return 1
    fi
    
    local expires_at=$(jq -r '.expires_at' "$TOKEN_FILE")
    local now=$(date +%s)
    local remaining=$((expires_at - now))
    
    if [ $remaining -lt 0 ]; then
        log_warn "Token expired. Run './spotify-auth.sh refresh' or './spotify-auth.sh token'"
    else
        log_info "Authenticated. Token expires in $((remaining / 60)) minutes"
        
        # Test the token
        local token=$(jq -r '.access_token' "$TOKEN_FILE")
        local response=$(curl -s -w "%{http_code}" -o /dev/null \
            -H "Authorization: Bearer $token" \
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

# Start OAuth flow with temporary local server
do_login() {
    check_credentials
    ensure_token_dir
    
    local auth_url=$(get_auth_url)
    
    log_info "Opening browser for Spotify authorization..."
    log_info "If browser doesn't open, visit this URL:"
    echo ""
    echo "$auth_url"
    echo ""
    
    # Try to open browser
    if command -v open &> /dev/null; then
        open "$auth_url"
    elif command -v xdg-open &> /dev/null; then
        xdg-open "$auth_url"
    fi
    
    log_info "Waiting for callback on http://127.0.0.1:17823/callback ..."
    log_info "Press Ctrl+C to cancel"
    
    # Start simple HTTP server to catch callback
    # Using netcat for simplicity
    local response=""
    local code=""
    local returned_state=""
    
    while true; do
        # Listen for one connection
        response=$(echo -e "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n<html><body><h1>Success!</h1><p>You can close this window.</p><script>window.close()</script></body></html>" | nc -l 17823 2>/dev/null | head -1)
        
        # Extract code from request
        if echo "$response" | grep -q "code="; then
            code=$(echo "$response" | sed -n 's/.*code=\([^& ]*\).*/\1/p')
            returned_state=$(echo "$response" | sed -n 's/.*state=\([^& ]*\).*/\1/p')
            break
        fi
        
        # Check for error
        if echo "$response" | grep -q "error="; then
            local error=$(echo "$response" | sed -n 's/.*error=\([^& ]*\).*/\1/p')
            log_error "Authorization failed: $error"
            return 1
        fi
    done
    
    # Validate state to prevent CSRF attacks
    if [ -f "$STATE_FILE" ]; then
        local expected_state=$(cat "$STATE_FILE")
        rm -f "$STATE_FILE"
        
        if [ "$returned_state" != "$expected_state" ]; then
            log_error "State mismatch - possible CSRF attack"
            return 1
        fi
    else
        log_error "No state file found - cannot validate callback"
        return 1
    fi
    
    if [ -n "$code" ]; then
        log_info "Got authorization code, exchanging for tokens..."
        exchange_code "$code"
    else
        log_error "Failed to get authorization code"
        return 1
    fi
}

# Main
check_dependencies

case "${1:-}" in
    login)
        check_credentials
        do_login
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
        echo "  login    - Start OAuth flow (opens browser)"
        echo "  token    - Get current access token (refreshes if needed)"
        echo "  refresh  - Force token refresh"
        echo "  status   - Check authentication status"
        echo ""
        echo "Credentials are loaded in this order:"
        echo "  1. Environment variables (SPOTIFY_CLIENT_ID, SPOTIFY_CLIENT_SECRET)"
        echo "  2. Credentials file (~/.spotify/credentials.json)"
        echo "  3. Interactive prompt (will save to credentials file)"
        echo ""
        echo "Get credentials from https://developer.spotify.com/dashboard"
        ;;
esac

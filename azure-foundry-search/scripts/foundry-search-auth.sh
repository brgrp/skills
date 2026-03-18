#!/bin/bash
# foundry-search-auth.sh - Azure AI Foundry Search configuration and authentication
#
# Usage:
#   ./foundry-search-auth.sh configure  - Interactive setup (saves to config file)
#   ./foundry-search-auth.sh status     - Check configuration and API access
#   ./foundry-search-auth.sh show       - Show current configuration
#
# Configuration Priority:
#   1. Environment variables (if set)
#   2. Config file (~/.config/azure-foundry-search/config.json)
#
# Environment Variables (optional, override config file):
#   AZURE_FOUNDRY_ENDPOINT   - Azure AI Services endpoint
#   AZURE_FOUNDRY_API_KEY    - API key for authentication
#   AZURE_FOUNDRY_MODEL      - Model deployment name

set -e

# Config directory and file
FOUNDRY_SEARCH_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/azure-foundry-search"
CONFIG_FILE="$FOUNDRY_SEARCH_DIR/config.json"

# Configuration (loaded from env or file)
AZURE_FOUNDRY_ENDPOINT="${AZURE_FOUNDRY_ENDPOINT:-}"
AZURE_FOUNDRY_API_KEY="${AZURE_FOUNDRY_API_KEY:-}"
AZURE_FOUNDRY_MODEL="${AZURE_FOUNDRY_MODEL:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Temp file cleanup
tmp_file=""
cleanup() {
    rm -f "$tmp_file" 2>/dev/null
}
trap cleanup EXIT

check_dependencies() {
    local missing=()
    for cmd in curl jq; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing required commands: ${missing[*]}"
        echo '{"status":"error","code":"DEPENDENCY_ERROR","error":"Missing required commands","missing":["'"$(IFS=','; echo "${missing[*]}" | sed 's/,/","/g')"'"],"solution":"Install missing commands: '"${missing[*]}"'"}'
        exit 1
    fi
}

# Ensure config directory exists with secure permissions (always enforced)
ensure_config_dir() {
    mkdir -p "$FOUNDRY_SEARCH_DIR"
    chmod 700 "$FOUNDRY_SEARCH_DIR"
}

# Load config from file (env vars take priority - they're already set above)
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        [ -z "$AZURE_FOUNDRY_ENDPOINT" ] && AZURE_FOUNDRY_ENDPOINT=$(jq -r '.endpoint // empty' "$CONFIG_FILE" 2>/dev/null)
        [ -z "$AZURE_FOUNDRY_API_KEY" ] && AZURE_FOUNDRY_API_KEY=$(jq -r '.api_key // empty' "$CONFIG_FILE" 2>/dev/null)
        [ -z "$AZURE_FOUNDRY_MODEL" ] && AZURE_FOUNDRY_MODEL=$(jq -r '.model // empty' "$CONFIG_FILE" 2>/dev/null)
    fi
}

# Save config to file with secure permissions (atomic with umask)
save_config() {
    local endpoint="$1"
    local api_key="$2"
    local model="$3"
    
    ensure_config_dir
    # Use umask to ensure file is created with 600 permissions atomically
    (umask 077 && jq -n \
        --arg endpoint "$endpoint" \
        --arg api_key "$api_key" \
        --arg model "$model" \
        '{endpoint: $endpoint, api_key: $api_key, model: $model}' > "$CONFIG_FILE")
}

# Validate endpoint URL (must be HTTPS, warn if not Azure domain)
validate_endpoint() {
    local endpoint="$1"
    
    if [ -z "$endpoint" ]; then
        return 0  # Empty check handled elsewhere
    fi
    
    # Must be HTTPS
    if [[ ! "$endpoint" =~ ^https:// ]]; then
        log_error "Endpoint must use HTTPS"
        jq -n --arg e "$endpoint" '{
            "status": "error",
            "code": "INVALID_ENDPOINT",
            "error": "Endpoint must use HTTPS",
            "endpoint": $e,
            "solution": "Use https:// URL for the endpoint"
        }'
        return 1
    fi
    
    # Warn if not Azure domain (but allow it)
    if [[ ! "$endpoint" =~ \.azure\.com$ ]] && [[ ! "$endpoint" =~ \.azure\.us$ ]] && [[ ! "$endpoint" =~ \.azure\.cn$ ]]; then
        log_warn "Endpoint is not a recognized Azure domain - verify this is intended"
    fi
    
    return 0
}

# Validate model name (alphanumeric, dots, underscores, hyphens only)
validate_model() {
    local model="$1"
    
    if [ -z "$model" ]; then
        return 0  # Empty check handled elsewhere
    fi
    
    if [[ ! "$model" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        log_error "Invalid model name: $model"
        jq -n --arg m "$model" '{
            "status": "error",
            "code": "INVALID_MODEL",
            "error": ("Invalid model name: " + $m),
            "solution": "Model names should only contain letters, numbers, dots, underscores, and hyphens"
        }'
        return 1
    fi
    
    return 0
}

# Mask API key for display (show first 4 and last 4 chars)
mask_key() {
    local key="$1"
    local len=${#key}
    if [ -z "$key" ]; then
        echo "<not set>"
    elif [ "$len" -le 8 ]; then
        echo "***"
    else
        echo "${key:0:4}...${key: -4}"
    fi
}

# Interactive configuration with pre-filled defaults (Option C)
cmd_configure() {
    log_info "Azure AI Foundry Search - Configuration"
    echo "" >&2
    echo "Get your endpoint and API key from Azure Portal:" >&2
    echo "  1. Go to portal.azure.com" >&2
    echo "  2. Navigate to your Azure AI Services resource" >&2
    echo "  3. Copy Endpoint and Key from 'Keys and Endpoint' section" >&2
    echo "" >&2
    
    # Load existing config for defaults
    load_config
    
    local current_endpoint="$AZURE_FOUNDRY_ENDPOINT"
    local current_key="$AZURE_FOUNDRY_API_KEY"
    local current_model="$AZURE_FOUNDRY_MODEL"
    local masked_key=$(mask_key "$current_key")
    
    # Prompt with defaults
    local new_endpoint new_key new_model
    
    if [ -n "$current_endpoint" ]; then
        read -p "Endpoint [$current_endpoint]: " new_endpoint
        new_endpoint="${new_endpoint:-$current_endpoint}"
    else
        read -p "Endpoint (https://<resource>.services.ai.azure.com): " new_endpoint
    fi
    
    # Use silent mode for API key input (security fix #2)
    if [ -n "$current_key" ]; then
        read -s -p "API Key [$masked_key]: " new_key
        echo ""  # Add newline after silent input
        new_key="${new_key:-$current_key}"
    else
        read -s -p "API Key: " new_key
        echo ""  # Add newline after silent input
    fi
    
    if [ -n "$current_model" ]; then
        read -p "Model [$current_model]: " new_model
        new_model="${new_model:-$current_model}"
    else
        read -p "Model (e.g., gpt-4o, gpt-5-mini): " new_model
    fi
    
    # Validate required fields
    if [ -z "$new_endpoint" ] || [ -z "$new_key" ]; then
        log_error "Endpoint and API key are required"
        jq -n '{
            "status": "error",
            "code": "CONFIG_ERROR",
            "error": "Endpoint and API key are required",
            "solution": "Run configure again and provide both values"
        }'
        exit 1
    fi
    
    if [ -z "$new_model" ]; then
        log_error "Model is required"
        jq -n '{
            "status": "error",
            "code": "CONFIG_ERROR",
            "error": "Model deployment name is required",
            "solution": "Run configure again and provide a model name (e.g., gpt-4o, gpt-5-mini)"
        }'
        exit 1
    fi
    
    # Validate endpoint and model format
    if ! validate_endpoint "$new_endpoint"; then
        exit 1
    fi
    
    if ! validate_model "$new_model"; then
        exit 1
    fi
    
    # Save configuration
    save_config "$new_endpoint" "$new_key" "$new_model"
    log_info "Configuration saved to $CONFIG_FILE"
    
    # Update current values for testing
    AZURE_FOUNDRY_ENDPOINT="$new_endpoint"
    AZURE_FOUNDRY_API_KEY="$new_key"
    AZURE_FOUNDRY_MODEL="$new_model"
    
    # Test connection
    echo "" >&2
    log_info "Testing connection..."
    if test_connection; then
        log_info "Success! Web search is ready."
        jq -n \
            --arg endpoint "$new_endpoint" \
            --arg model "$new_model" \
            --arg config_file "$CONFIG_FILE" \
            '{
                "status": "ok",
                "message": "Configuration saved and verified",
                "config_file": $config_file,
                "endpoint": $endpoint,
                "model": $model
            }'
    else
        log_warn "Configuration saved but connection test failed. Check your credentials."
        return 1
    fi
}

# Show current configuration
cmd_show() {
    load_config
    
    local source="not configured"
    if [ -f "$CONFIG_FILE" ]; then
        source="$CONFIG_FILE"
    fi
    
    # Check if any env vars are overriding
    local env_override=""
    [ -n "${AZURE_FOUNDRY_ENDPOINT+x}" ] && [ -n "$AZURE_FOUNDRY_ENDPOINT" ] && env_override="yes"
    [ -n "${AZURE_FOUNDRY_API_KEY+x}" ] && [ -n "$AZURE_FOUNDRY_API_KEY" ] && env_override="yes"
    [ -n "${AZURE_FOUNDRY_MODEL+x}" ] && [ -n "$AZURE_FOUNDRY_MODEL" ] && env_override="yes"
    
    log_info "Current Configuration"
    echo "" >&2
    echo "  Config file: $CONFIG_FILE" >&2
    echo "  Endpoint: ${AZURE_FOUNDRY_ENDPOINT:-<not set>}" >&2
    echo "  API Key: $(mask_key "$AZURE_FOUNDRY_API_KEY")" >&2
    echo "  Model: ${AZURE_FOUNDRY_MODEL:-<not set>}" >&2
    
    if [ -n "$env_override" ]; then
        echo "" >&2
        echo "  Note: Environment variables may be overriding config file values" >&2
    fi
    
    jq -n \
        --arg config_file "$CONFIG_FILE" \
        --arg endpoint "${AZURE_FOUNDRY_ENDPOINT:-}" \
        --arg api_key "$(mask_key "$AZURE_FOUNDRY_API_KEY")" \
        --arg model "${AZURE_FOUNDRY_MODEL:-}" \
        --argjson configured "$([ -f "$CONFIG_FILE" ] && echo true || echo false)" \
        '{
            "config_file": $config_file,
            "configured": $configured,
            "endpoint": $endpoint,
            "api_key": $api_key,
            "model": $model
        }'
}

# Test API connection (returns 0 on success, 1 on failure)
# Uses curl -K - to hide API key from process list (security fix #1)
test_connection() {
    local test_url="${AZURE_FOUNDRY_ENDPOINT}/openai/v1/responses"
    
    # Create temp file with secure permissions (security fix #7)
    tmp_file=$(umask 077 && mktemp)
    
    local http_code
    # Use curl -K - to read headers from stdin (hides API key from ps)
    http_code=$(echo "header = \"api-key: $AZURE_FOUNDRY_API_KEY\"" | \
        curl -K - -s -w "%{http_code}" -o "$tmp_file" \
        --connect-timeout 10 \
        --max-time 30 \
        --request POST \
        --url "$test_url" \
        -H "Content-Type: application/json" \
        --data '{"model":"'"$AZURE_FOUNDRY_MODEL"'","input":"test","tools":[{"type":"web_search_preview"}],"max_output_tokens":100}' \
        2>/dev/null) || true
    
    local response
    response=$(cat "$tmp_file")
    rm -f "$tmp_file"
    tmp_file=""
    
    [ "$http_code" = "200" ] || [ "$http_code" = "201" ]
}

# Check configuration is valid
check_config() {
    local missing=()
    
    if [ -z "$AZURE_FOUNDRY_ENDPOINT" ]; then
        missing+=("AZURE_FOUNDRY_ENDPOINT")
    fi
    
    if [ -z "$AZURE_FOUNDRY_API_KEY" ]; then
        missing+=("AZURE_FOUNDRY_API_KEY")
    fi
    
    if [ -z "$AZURE_FOUNDRY_MODEL" ]; then
        missing+=("AZURE_FOUNDRY_MODEL")
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing configuration: ${missing[*]}"
        jq -n \
            --arg missing "${missing[*]}" \
            --arg config_file "$CONFIG_FILE" \
            '{
                "status": "error",
                "code": "CONFIG_ERROR",
                "configured": false,
                "error": "Missing required configuration",
                "missing": ($missing | split(" ")),
                "solution": ("Run: ./foundry-search.sh configure")
            }'
        return 1
    fi
    
    # Validate endpoint format
    if ! validate_endpoint "$AZURE_FOUNDRY_ENDPOINT"; then
        return 1
    fi
    
    # Validate model format
    if ! validate_model "$AZURE_FOUNDRY_MODEL"; then
        return 1
    fi
    
    return 0
}

# Full status check with API test
cmd_status() {
    load_config
    
    if ! check_config; then
        return 1
    fi
    
    local masked_key
    masked_key=$(mask_key "$AZURE_FOUNDRY_API_KEY")
    
    log_info "Endpoint: $AZURE_FOUNDRY_ENDPOINT"
    log_info "API Key: $masked_key"
    log_info "Model: $AZURE_FOUNDRY_MODEL"
    log_info "Testing API connection..."
    
    local test_url="${AZURE_FOUNDRY_ENDPOINT}/openai/v1/responses"
    
    # Create temp file with secure permissions (security fix #7)
    tmp_file=$(umask 077 && mktemp)
    
    local http_code
    # Use curl -K - to read headers from stdin (hides API key from ps)
    http_code=$(echo "header = \"api-key: $AZURE_FOUNDRY_API_KEY\"" | \
        curl -K - -s -w "%{http_code}" -o "$tmp_file" \
        --connect-timeout 10 \
        --max-time 30 \
        --request POST \
        --url "$test_url" \
        -H "Content-Type: application/json" \
        --data '{"model":"'"$AZURE_FOUNDRY_MODEL"'","input":"test","tools":[{"type":"web_search_preview"}],"max_output_tokens":100}' \
        2>/dev/null) || true
    
    local response
    response=$(cat "$tmp_file")
    rm -f "$tmp_file"
    tmp_file=""
    
    case "$http_code" in
        200|201)
            log_info "API connection successful"
            log_info "Web search is available"
            jq -n \
                --arg endpoint "$AZURE_FOUNDRY_ENDPOINT" \
                --arg model "$AZURE_FOUNDRY_MODEL" \
                --arg key "$masked_key" \
                --arg config_file "$CONFIG_FILE" \
                '{
                    "status": "ok",
                    "configured": true,
                    "config_file": $config_file,
                    "endpoint": $endpoint,
                    "model": $model,
                    "api_key": $key,
                    "web_search": true
                }'
            ;;
        401)
            log_error "Authentication failed - invalid API key"
            jq -n --arg key "$masked_key" '{
                "status": "error",
                "code": "AUTH_ERROR",
                "configured": true,
                "error": "Invalid API key",
                "api_key": $key,
                "solution": "Run: ./foundry-search.sh configure"
            }'
            return 1
            ;;
        403)
            local error_msg
            error_msg=$(echo "$response" | jq -r '.error.message // "Access denied"' 2>/dev/null | head -c 200)
            log_error "Access denied: $error_msg"
            jq -n --arg e "$error_msg" '{
                "status": "error",
                "code": "ACCESS_DENIED",
                "configured": true,
                "error": $e,
                "solution": "Check Azure RBAC permissions for your API key"
            }'
            return 1
            ;;
        404)
            local error_msg
            error_msg=$(echo "$response" | jq -r '.error.message // "Not found"' 2>/dev/null | head -c 200)
            log_error "Model or API not found: $error_msg"
            jq -n --arg e "$error_msg" --arg m "$AZURE_FOUNDRY_MODEL" '{
                "status": "error",
                "code": "NOT_FOUND",
                "configured": true,
                "error": $e,
                "model": $m,
                "solution": "Verify model is deployed. Run: ./foundry-search.sh configure"
            }'
            return 1
            ;;
        000)
            log_error "Connection failed - could not reach endpoint"
            jq -n --arg endpoint "$AZURE_FOUNDRY_ENDPOINT" '{
                "status": "error",
                "code": "CONNECTION_ERROR",
                "configured": true,
                "error": "Could not connect to endpoint",
                "endpoint": $endpoint,
                "solution": "Check network connectivity and endpoint URL"
            }'
            return 1
            ;;
        *)
            local error_msg
            error_msg=$(echo "$response" | jq -r '.error.message // .error // "Unknown error"' 2>/dev/null | head -c 200)
            log_error "API error (HTTP $http_code): $error_msg"
            jq -n --arg e "$error_msg" --argjson c "$http_code" '{
                "status": "error",
                "code": "API_ERROR",
                "configured": true,
                "error": $e,
                "http_code": $c,
                "solution": "Check error message for details"
            }'
            return 1
            ;;
    esac
}

# Main
check_dependencies

case "${1:-}" in
    configure)
        cmd_configure
        ;;
    status)
        cmd_status
        ;;
    show)
        cmd_show
        ;;
    *)
        cat << 'EOF'
Azure AI Foundry Search - Configuration Helper

Usage: foundry-search-auth.sh <command>

Commands:
  configure  - Interactive setup (saves to config file)
  status     - Check configuration and verify API access
  show       - Show current configuration

Configuration:
  Config file: ~/.config/azure-foundry-search/config.json
  Permissions: Directory 700, File 600
  
  Environment variables (optional, override config file):
    AZURE_FOUNDRY_ENDPOINT   Azure AI Services endpoint
    AZURE_FOUNDRY_API_KEY    API key for authentication
    AZURE_FOUNDRY_MODEL      Model deployment name

Setup:
  1. Get your API key from Azure Portal
  2. Run: ./foundry-search-auth.sh configure
  3. Follow the prompts to enter endpoint, API key, and model
  4. Verify: ./foundry-search-auth.sh status
EOF
        ;;
esac

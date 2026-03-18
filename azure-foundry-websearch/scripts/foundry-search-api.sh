#!/bin/bash
# foundry-search-api.sh - Azure AI Foundry Search API
#
# Usage:
#   ./foundry-search-api.sh search "query" [options]
#
# Options:
#   --country CODE      ISO 3166-1 alpha-2 country code (e.g., US, DE, GB)
#   --context SIZE      Context size: low, medium (default), high
#   --model NAME        Model deployment name
#
# Configuration Priority:
#   1. Environment variables (if set)
#   2. Config file (~/.config/azure-foundry-websearch/config.json)

set -e

# Config directory and file
FOUNDRY_SEARCH_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/azure-foundry-websearch"
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

# Load config from file (env vars take priority - they're already set above)
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        [ -z "$AZURE_FOUNDRY_ENDPOINT" ] && AZURE_FOUNDRY_ENDPOINT=$(jq -r '.endpoint // empty' "$CONFIG_FILE" 2>/dev/null)
        [ -z "$AZURE_FOUNDRY_API_KEY" ] && AZURE_FOUNDRY_API_KEY=$(jq -r '.api_key // empty' "$CONFIG_FILE" 2>/dev/null)
        [ -z "$AZURE_FOUNDRY_MODEL" ] && AZURE_FOUNDRY_MODEL=$(jq -r '.model // empty' "$CONFIG_FILE" 2>/dev/null)
    fi
}

check_config() {
    local missing=()
    
    if [ -z "$AZURE_FOUNDRY_ENDPOINT" ]; then
        missing+=("endpoint")
    fi
    
    if [ -z "$AZURE_FOUNDRY_API_KEY" ]; then
        missing+=("api_key")
    fi
    
    if [ -z "$AZURE_FOUNDRY_MODEL" ]; then
        missing+=("model")
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing configuration: ${missing[*]}"
        jq -n \
            --arg missing "${missing[*]}" \
            '{
                "status": "error",
                "code": "CONFIG_ERROR",
                "error": "Missing required configuration",
                "missing": ($missing | split(" ")),
                "solution": "Run: ./foundry-search.sh configure"
            }'
        exit 1
    fi
}

# Validate country code (ISO 3166-1 alpha-2: 2 uppercase letters)
validate_country() {
    local country="$1"
    if [ -n "$country" ] && [[ ! "$country" =~ ^[A-Z]{2}$ ]]; then
        log_error "Invalid country code: $country"
        jq -n --arg c "$country" '{
            "status": "error",
            "code": "INVALID_COUNTRY",
            "error": ("Invalid country code: " + $c),
            "solution": "Use 2-letter uppercase ISO country code (e.g., US, DE, GB, FR)"
        }'
        exit 1
    fi
}

# Validate context size
validate_context() {
    local context="$1"
    case "$context" in
        low|medium|high) ;;
        *)
            log_error "Invalid context size: $context"
            jq -n --arg c "$context" '{
                "status": "error",
                "code": "INVALID_CONTEXT",
                "error": ("Invalid context size: " + $c),
                "solution": "Use: low, medium, or high"
            }'
            exit 1
            ;;
    esac
}

# Build tool config using jq for safe JSON construction (security fix #5)
build_tool_config() {
    local country="$1"
    local context_size="${2:-medium}"
    
    if [ -n "$country" ]; then
        jq -n \
            --arg context_size "$context_size" \
            --arg country "$country" \
            '{
                type: "web_search_preview",
                search_context_size: $context_size,
                user_location: {
                    type: "approximate",
                    country: $country
                }
            }'
    else
        jq -n \
            --arg context_size "$context_size" \
            '{
                type: "web_search_preview",
                search_context_size: $context_size
            }'
    fi
}

do_search() {
    local query="$1"
    local country="$2"
    local context_size="${3:-medium}"
    local model="${4:-$AZURE_FOUNDRY_MODEL}"
    
    local api_url="${AZURE_FOUNDRY_ENDPOINT}/openai/v1/responses"
    local tool_config
    tool_config=$(build_tool_config "$country" "$context_size")
    
    local request_body
    request_body=$(jq -n \
        --arg model "$model" \
        --arg input "$query" \
        --argjson tools "[$tool_config]" \
        '{model: $model, input: $input, tools: $tools}')
    
    # Create temp file with secure permissions (security fix #7)
    tmp_file=$(umask 077 && mktemp)
    
    local http_code
    # Use curl -K - to read headers from stdin (hides API key from ps) (security fix #1)
    http_code=$(echo "header = \"api-key: $AZURE_FOUNDRY_API_KEY\"" | \
        curl -K - -s -w "%{http_code}" -o "$tmp_file" \
        --connect-timeout 10 \
        --max-time 120 \
        --request POST \
        --url "$api_url" \
        -H "Content-Type: application/json" \
        --data "$request_body" 2>/dev/null) || true
    
    local response
    response=$(cat "$tmp_file")
    rm -f "$tmp_file"
    tmp_file=""
    
    case "$http_code" in
        200|201)
            parse_response "$response" "$query"
            ;;
        401)
            jq -n --arg q "$query" '{
                "status": "error",
                "query": $q,
                "error": "Authentication failed - invalid API key",
                "code": "AUTH_ERROR",
                "solution": "Run: ./foundry-search.sh configure"
            }'
            return 1
            ;;
        403)
            local error_msg
            error_msg=$(echo "$response" | jq -r '.error.message // "Access denied"' 2>/dev/null)
            jq -n --arg q "$query" --arg e "$error_msg" '{
                "status": "error",
                "query": $q,
                "error": $e,
                "code": "ACCESS_DENIED",
                "solution": "Check Azure RBAC permissions for your API key"
            }'
            return 1
            ;;
        404)
            local error_msg
            error_msg=$(echo "$response" | jq -r '.error.message // "Not found"' 2>/dev/null)
            jq -n --arg q "$query" --arg e "$error_msg" --arg m "$model" '{
                "status": "error",
                "query": $q,
                "error": $e,
                "code": "NOT_FOUND",
                "model": $m,
                "solution": "Verify model is deployed. Run: ./foundry-search.sh configure"
            }'
            return 1
            ;;
        429)
            local retry_after
            retry_after=$(echo "$response" | jq -r '.error.retry_after // 60' 2>/dev/null)
            jq -n --arg q "$query" --argjson r "$retry_after" '{
                "status": "error",
                "query": $q,
                "error": "Rate limited - too many requests",
                "code": "RATE_LIMITED",
                "retry_after": $r,
                "solution": "Wait and retry after the specified time"
            }'
            return 1
            ;;
        000)
            jq -n --arg q "$query" --arg endpoint "$AZURE_FOUNDRY_ENDPOINT" '{
                "status": "error",
                "query": $q,
                "error": "Connection failed - could not reach endpoint",
                "code": "CONNECTION_ERROR",
                "endpoint": $endpoint,
                "solution": "Check network connectivity and endpoint URL"
            }'
            return 1
            ;;
        *)
            local error_msg
            error_msg=$(echo "$response" | jq -r '.error.message // .error // "Unknown error"' 2>/dev/null)
            jq -n --arg q "$query" --arg e "$error_msg" --argjson c "$http_code" '{
                "status": "error",
                "query": $q,
                "error": $e,
                "code": "API_ERROR",
                "http_code": $c,
                "solution": "Check error message for details"
            }'
            return 1
            ;;
    esac
}

parse_response() {
    local response="$1"
    local original_query="$2"
    
    local search_queries
    search_queries=$(echo "$response" | jq -c '[.output[]? | select(.type == "web_search_call") | .action.queries[]?] | unique // []' 2>/dev/null)
    
    local answer
    answer=$(echo "$response" | jq -r '[.output[]? | select(.type == "message") | .content[]? | select(.type == "output_text") | .text] | join("\n") // ""' 2>/dev/null)
    
    local citations
    citations=$(echo "$response" | jq -c '[.output[]? | select(.type == "message") | .content[]? | .annotations[]? | select(.type == "url_citation") | {title: .title, url: .url}] | unique // []' 2>/dev/null)
    
    local usage
    usage=$(echo "$response" | jq -c '.usage // {}' 2>/dev/null)
    
    if [ -z "$answer" ] || [ "$answer" = "null" ] || [ "$answer" = "" ]; then
        jq -n --arg q "$original_query" '{
            "status": "no_results",
            "query": $q,
            "answer": "",
            "citations": [],
            "solution": "Try rephrasing your query or using different search terms"
        }'
        return 0
    fi
    
    jq -n \
        --arg status "success" \
        --arg query "$original_query" \
        --arg answer "$answer" \
        --argjson citations "$citations" \
        --argjson search_queries "$search_queries" \
        --argjson usage "$usage" \
        '{status: $status, query: $query, answer: $answer, citations: $citations, search_queries: $search_queries, usage: $usage}'
}

# Main
check_dependencies
load_config
check_config

case "${1:-}" in
    search)
        shift
        
        query=""
        country=""
        context_size="medium"
        model=""
        
        while [ $# -gt 0 ]; do
            case "$1" in
                --country)
                    country="$2"
                    shift 2
                    ;;
                --context)
                    context_size="$2"
                    shift 2
                    ;;
                --model)
                    model="$2"
                    shift 2
                    ;;
                -*)
                    log_error "Unknown option: $1"
                    jq -n --arg opt "$1" '{
                        "status": "error",
                        "code": "INVALID_OPTION",
                        "error": ("Unknown option: " + $opt),
                        "solution": "Run: ./foundry-search.sh help"
                    }'
                    exit 1
                    ;;
                *)
                    if [ -z "$query" ]; then
                        query="$1"
                    else
                        query="$query $1"
                    fi
                    shift
                    ;;
            esac
        done
        
        if [ -z "$query" ]; then
            log_error "No search query provided"
            jq -n '{
                "status": "error",
                "code": "MISSING_QUERY",
                "error": "No search query provided",
                "solution": "Usage: ./foundry-search.sh search \"your question here\""
            }'
            exit 1
        fi
        
        # Validate inputs
        [ -n "$country" ] && validate_country "$country"
        validate_context "$context_size"
        
        do_search "$query" "$country" "$context_size" "$model"
        ;;
    *)
        cat << 'EOF'
Azure AI Foundry Search API

Usage: foundry-search-api.sh search "query" [options]

Options:
  --country CODE    ISO country code (US, DE, GB, etc.)
  --context SIZE    low, medium, or high
  --model NAME      Model deployment name

Configuration:
  Run ./foundry-search.sh configure to set up credentials.
  Config file: ~/.config/azure-foundry-websearch/config.json

This is the low-level API script. Use foundry-search.sh instead.
EOF
        ;;
esac

#!/bin/bash
# foundry-search.sh - Azure AI Foundry Search CLI
#
# Usage:
#   foundry-search configure                   Interactive setup
#   foundry-search search "query"              Search the web
#   foundry-search search "q" --country DE     Localized search
#   foundry-search search "q" --context high   More detailed results
#   foundry-search search "q" --text-only      Output only answer text
#   foundry-search status                      Check configuration
#   foundry-search show                        Show current config
#
# Configuration:
#   Config file: ~/.config/azure-foundry-websearch/config.json
#   Run 'configure' for first-time setup
#
# Exit Codes:
#   0 - Success
#   1 - Error (missing config, API error, etc.)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

case "${1:-help}" in
    configure)
        "$SCRIPT_DIR/foundry-search-auth.sh" configure
        ;;
    search)
        shift
        
        text_only=false
        citations_only=false
        args=()
        
        while [ $# -gt 0 ]; do
            case "$1" in
                --text-only)
                    text_only=true
                    shift
                    ;;
                --citations)
                    citations_only=true
                    shift
                    ;;
                *)
                    args+=("$1")
                    shift
                    ;;
            esac
        done
        
        # Call API and capture both output and exit code
        result=$("$SCRIPT_DIR/foundry-search-api.sh" search "${args[@]}" 2>&1) && api_success=true || api_success=false
        
        # Format and output based on flags
        if [ "$text_only" = true ]; then
            echo "$result" | jq -r '.answer // .error // "No results"' 2>/dev/null || echo "$result"
        elif [ "$citations_only" = true ]; then
            echo "$result" | jq -c '.citations // []' 2>/dev/null || echo "[]"
        else
            echo "$result"
        fi
        
        # Exit with appropriate code
        if [ "$api_success" = false ]; then
            exit 1
        fi
        
        # Also check for error status in JSON response
        if echo "$result" | jq -e '.status == "error"' > /dev/null 2>&1; then
            exit 1
        fi
        ;;
    status)
        "$SCRIPT_DIR/foundry-search-auth.sh" status
        ;;
    show)
        "$SCRIPT_DIR/foundry-search-auth.sh" show
        ;;
    help|--help|-h|"")
        cat << 'EOF'
Azure AI Foundry Search

Search the web using Azure AI Foundry's Responses API with Grounding with Bing.

Commands:
  configure            Interactive setup (first-time configuration)
  search "query"       Search the web for current information
  status               Check configuration and API access
  show                 Show current configuration

Search Options:
  --country CODE       ISO country code for regional results (US, DE, GB, etc.)
  --context SIZE       Search depth: low, medium (default), high
  --model NAME         Model deployment name (overrides config)
  --text-only          Output only the answer text
  --citations          Output only citations as JSON

Examples:
  foundry-search configure
  foundry-search search "latest AI news"
  foundry-search search "weather in Berlin" --country DE
  foundry-search search "quantum computing" --context high --text-only

Response Format (JSON):
  status=success    -> answer contains the result, citations has sources
  status=error      -> check error and code fields
  status=no_results -> try rephrasing the query

Configuration:
  Config file: ~/.config/azure-foundry-websearch/config.json
  Permissions: Directory 700, File 600

  First-time setup:
    ./foundry-search.sh configure

  Environment variables (optional, override config file):
    AZURE_FOUNDRY_ENDPOINT   Azure AI Services endpoint
    AZURE_FOUNDRY_API_KEY    API key for authentication
    AZURE_FOUNDRY_MODEL      Model deployment name

Exit Codes:
  0 - Success
  1 - Error (missing config, auth failure, model not found, etc.)
EOF
        ;;
    *)
        echo "Unknown command: $1" >&2
        echo "Run 'foundry-search help' for usage" >&2
        exit 1
        ;;
esac

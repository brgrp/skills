#!/bin/bash
# Compatibility wrapper → spotify.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
case "${1:-}" in
    --devices) exec "$SCRIPT_DIR/spotify.sh" devices ;;
    --set-device) shift; exec "$SCRIPT_DIR/spotify.sh" device "$@" ;;
    *) exec "$SCRIPT_DIR/spotify.sh" "$@" ;;
esac

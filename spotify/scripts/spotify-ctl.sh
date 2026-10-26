#!/bin/bash
# Compatibility wrapper → spotify.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# Old ctl used `play` for resume
if [ "${1:-}" = "play" ] && [ -z "${2:-}" ]; then
    exec "$SCRIPT_DIR/spotify.sh" resume
fi
exec "$SCRIPT_DIR/spotify.sh" "$@"

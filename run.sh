#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

# Detect host git directory (parent of this repo)
HOST_GIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Galaxy API key: try macOS Keychain first, fall back to env var
if command -v security &>/dev/null; then
    GALAXY_API_KEY="${GALAXY_API_KEY:-$(security find-generic-password -s "galaxy-api-key" -w 2>/dev/null || echo "")}"
fi
GALAXY_URL="${GALAXY_URL:-https://usegalaxy.org}"

# Write .env file
cat > "$ENV_FILE" <<EOF
GALAXY_URL=${GALAXY_URL}
GALAXY_API_KEY=${GALAXY_API_KEY}
HOST_GIT_DIR=${HOST_GIT_DIR}
EOF

# Pass any extra env vars the user has set
[ -n "$ANTHROPIC_API_KEY" ] && echo "ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}" >> "$ENV_FILE"

# Open Sublime Text with the working directory
SUBL="$(command -v subl 2>/dev/null || echo "/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl")"
[ -x "$SUBL" ] && "$SUBL" --add "$HOST_GIT_DIR"

# Build if needed, then run
cd "$SCRIPT_DIR"

if [ "$1" = "-p" ]; then
    shift
    docker compose run --rm claude -p "$*"
else
    docker compose run --rm claude "$@"
fi

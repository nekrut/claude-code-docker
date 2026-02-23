#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Write Claude credentials from Keychain ONLY if file doesn't already exist
# (container-side `claude login` creates this file with correct scopes)
if [ ! -f "$HOME/.claude/.credentials.json" ]; then
    CREDS=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null || true)
    if [ -n "$CREDS" ]; then
        echo "$CREDS" > "$HOME/.claude/.credentials.json"
    fi
fi

# Galaxy API key: try macOS Keychain first, fall back to env var
if command -v security &>/dev/null; then
    GALAXY_API_KEY="${GALAXY_API_KEY:-$(security find-generic-password -s "galaxy-api-key" -w 2>/dev/null || echo "")}"
fi

# Write .env file
cat > "$SCRIPT_DIR/.env" <<EOF
GALAXY_URL=${GALAXY_URL:-}
GALAXY_API_KEY=${GALAXY_API_KEY:-}
EOF
[ -n "$GH_TOKEN" ] && echo "GH_TOKEN=${GH_TOKEN}" >> "$SCRIPT_DIR/.env"
[ -n "$ANTHROPIC_API_KEY" ] && echo "ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}" >> "$SCRIPT_DIR/.env"

# Ensure galaxy-skills cloned on host (persists via bind mount)
SKILLS_DIR="$HOME/.claude/skills/galaxy"
if [ ! -d "$SKILLS_DIR" ]; then
    echo "Cloning galaxy-skills..."
    mkdir -p "$HOME/.claude/skills"
    git clone https://github.com/galaxyproject/galaxy-skills.git "$SKILLS_DIR" 2>/dev/null || echo "Warning: could not clone galaxy-skills"
fi

# Handle --service-ports flag
DOCKER_ARGS="--rm"
if [ "$1" = "--service-ports" ]; then
    DOCKER_ARGS="--rm --service-ports"
    shift
fi

# Run claude container
cd "$SCRIPT_DIR"
docker compose run $DOCKER_ARGS claude "$@"

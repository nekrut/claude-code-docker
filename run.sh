#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

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

# Open editor
subl --add ~/git 2>/dev/null || true

# Run claude container
cd "$SCRIPT_DIR"
docker compose run --rm claude "$@"

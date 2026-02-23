#!/bin/bash
set -e

# Fix SSH key permissions (bind-mounted as ro, may have wrong perms)
if [ -d "$HOME/.ssh" ]; then
    mkdir -p /tmp/.ssh
    cp "$HOME/.ssh/"* /tmp/.ssh/ 2>/dev/null || true
    chmod 700 /tmp/.ssh
    chmod 600 /tmp/.ssh/* 2>/dev/null || true
    chmod 644 /tmp/.ssh/*.pub 2>/dev/null || true
    export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no -i /tmp/.ssh/id_ed25519 -i /tmp/.ssh/id_rsa 2>/dev/null"
fi

# Seed conda volume on first run (named volume starts empty)
if [ ! -f /opt/conda/bin/conda ]; then
    echo "Seeding conda volume from image..."
    cp -a /opt/conda.seed/. /opt/conda/
fi

# Clone or update galaxy-skills
SKILLS_DIR="$HOME/.claude/skills/galaxy"
if [ -d "$SKILLS_DIR/.git" ]; then
    git -C "$SKILLS_DIR" pull --ff-only 2>/dev/null || true
else
    mkdir -p "$HOME/.claude/skills"
    git clone https://github.com/galaxyproject/galaxy-skills.git "$SKILLS_DIR" 2>/dev/null || true
fi

# Register Galaxy MCP server if not already configured
if ! claude mcp list 2>/dev/null | grep -q "galaxy"; then
    echo "Registering Galaxy MCP server..."
    claude mcp add galaxy -- uvx galaxy-mcp 2>/dev/null || true
fi

# Skip auto-updates by default — they can interfere with startup.
# Set UPDATE=1 to update claude-code and galaxy-mcp before launch.
if [ "${UPDATE:-}" = "1" ]; then
    echo "Updating claude-code..."
    sudo npm install -g @anthropic-ai/claude-code@latest 2>/dev/null || true
    echo "Updating galaxy-mcp..."
    uvx --from galaxy-mcp galaxy-mcp --help >/dev/null 2>&1 || true
fi

exec claude --dangerously-skip-permissions "$@"

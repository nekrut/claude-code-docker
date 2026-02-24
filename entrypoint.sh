#!/bin/bash
set -e

# Persist .claude.json inside ~/.claude/ (which is bind-mounted rw).
# Single-file bind mounts corrupt on rewrite, so we store in the dir and symlink.
if [ -f /tmp/.claude.json.host ] && [ ! -f "$HOME/.claude/.claude.json" ]; then
    cp /tmp/.claude.json.host "$HOME/.claude/.claude.json"
fi
ln -sf "$HOME/.claude/.claude.json" "$HOME/.claude.json"

# Fix SSH key permissions (bind-mounted as ro, may have wrong perms)
if [ -d "$HOME/.ssh" ]; then
    mkdir -p /tmp/.ssh
    cp "$HOME/.ssh/"* /tmp/.ssh/ 2>/dev/null || true
    chmod 700 /tmp/.ssh
    chmod 600 /tmp/.ssh/* 2>/dev/null || true
    chmod 644 /tmp/.ssh/*.pub 2>/dev/null || true
    export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no -i /tmp/.ssh/id_ed25519 -i /tmp/.ssh/id_rsa 2>/dev/null"
fi

# Configure git to use GH_TOKEN for HTTPS push
if [ -n "$GH_TOKEN" ]; then
    echo -e "[credential]\n\thelper = !f() { echo username=x-access-token; echo password=\$GH_TOKEN; }; f" > /tmp/.gitconfig-credentials
    export GIT_CONFIG_COUNT=1
    export GIT_CONFIG_KEY_0=credential.helper
    export GIT_CONFIG_VALUE_0='!f() { echo "username=x-access-token"; echo "password=$GH_TOKEN"; }; f'
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
if [ -f "$HOME/.claude/settings.json" ] && ! grep -q "galaxy" "$HOME/.claude/settings.json" 2>/dev/null; then
    claude mcp add galaxy -- uvx galaxy-mcp 2>/dev/null || true
elif [ ! -f "$HOME/.claude/settings.json" ]; then
    claude mcp add galaxy -- uvx galaxy-mcp 2>/dev/null || true
fi

# Auto-update claude-code and galaxy-mcp on every startup.
# Set SKIP_UPDATES=1 to skip.
if [ "${SKIP_UPDATES:-}" != "1" ]; then
    echo "Updating claude-code..."
    sudo npm install -g @anthropic-ai/claude-code@latest 2>/dev/null || true
    echo "Updating galaxy-mcp..."
    uvx --from galaxy-mcp galaxy-mcp --help >/dev/null 2>&1 || true
fi

exec claude --dangerously-skip-permissions "$@"

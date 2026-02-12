#!/bin/bash
set -e

# Fix SSH key permissions (bind mounts inherit host perms which may be too open)
if [ -d "$HOME/.ssh" ]; then
    # Copy to a writable location to fix perms (original mount is ro)
    cp -r "$HOME/.ssh" "$HOME/.ssh_fixed"
    chmod 700 "$HOME/.ssh_fixed"
    chmod 600 "$HOME/.ssh_fixed"/* 2>/dev/null || true
    chmod 644 "$HOME/.ssh_fixed"/*.pub 2>/dev/null || true
    chmod 644 "$HOME/.ssh_fixed/known_hosts" 2>/dev/null || true
    # Point git/ssh to fixed dir
    export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new -i $HOME/.ssh_fixed/id_ed25519"
fi

# Register Galaxy MCP server if not already configured
if ! grep -q "galaxy" "$HOME/.claude/settings.json" 2>/dev/null; then
    echo "Registering Galaxy MCP server..."
    claude mcp add galaxy -- uvx galaxy-mcp 2>/dev/null || true
fi

# If args passed, run claude with those args
if [ $# -gt 0 ]; then
    exec claude --dangerously-skip-permissions "$@"
fi

# Default: interactive session
exec claude --dangerously-skip-permissions

# Claude Code in Docker

Run [Claude Code](https://docs.anthropic.com/en/docs/claude-code) inside a Docker container for filesystem isolation. Claude gets full internet access and can read/write your project files, but cannot touch anything else on your machine.

## What's in the container

- Node.js 20 (required by Claude Code)
- Claude Code CLI
- git + GitHub CLI (`gh`)
- Python 3, `uv`, Miniconda
- [Galaxy MCP server](https://github.com/galaxyproject/galaxy-mcp) (pre-cached)

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- Claude Code account (authenticated on host — see [First-time setup](#first-time-setup))
- GitHub CLI authenticated on host (`gh auth login`)
- SSH keys in `~/.ssh/` (for git push)

## Quick start

```bash
git clone https://github.com/nekrut/claude-code-docker.git
cd claude-code-docker
./run.sh              # interactive session + opens Sublime Text
./run.sh -p "prompt"  # one-shot
```

## First-time setup

### 1. Authenticate Claude Code on your host

```bash
npm install -g @anthropic-ai/claude-code
claude login
```

This stores your auth token in `~/.claude/`, which gets bind-mounted into the container.

### 2. Clone and place this repo inside your working directory

The container mounts the **parent directory** of this repo as `/workspace`. So if your projects live in `~/git/`:

```bash
cd ~/git
git clone https://github.com/nekrut/claude-code-docker.git
```

Now `~/git/` is mounted at `/workspace` inside the container, and all your repos are accessible.

### 3. Galaxy API key (optional)

If you use Galaxy, set your API key. On macOS you can store it in Keychain:

```bash
security add-generic-password -s "galaxy-api-key" -a galaxy -w "YOUR_KEY"
```

Or export it before running:

```bash
export GALAXY_API_KEY="your-key"
./run.sh
```

### 4. Build and run

```bash
./run.sh
```

First run builds the image (~1 min). Subsequent runs start instantly.

## How it works

### Volume mounts

| Host | Container | Mode | Purpose |
|------|-----------|------|---------|
| Parent dir (e.g. `~/git`) | `/workspace` | rw | Your project files |
| Parent dir | Original host path | ro | Resolves absolute symlinks |
| `~/.claude` | `/home/node/.claude` | rw | Auth tokens, config, MCP settings |
| `~/.gitconfig` | `/home/node/.gitconfig` | ro | Git identity |
| `~/.config/gh` | `/home/node/.config/gh` | ro | GitHub CLI auth |
| `~/.ssh` | `/home/node/.ssh` | ro | SSH keys |

### Security model

- Container provides filesystem isolation — Claude can only access mounted directories
- `--dangerously-skip-permissions` is used because the container boundary **is** the sandbox
- Secrets are passed as env vars at runtime, never baked into the image
- SSH keys and git config are mounted read-only

### What Claude can do inside the container

- Read/write files in `/workspace` (your projects)
- Git commit, push, pull via SSH
- Access the internet (web search, API calls)
- Use Galaxy MCP tools (search tools, run workflows, etc.)
- Use GitHub CLI (`gh pr create`, etc.)

### What Claude cannot do

- Access files outside mounted directories
- Modify your SSH keys or git config
- Read other directories on your host machine

## Customization

### Mount additional directories

Edit `docker-compose.yml` to add more volumes:

```yaml
volumes:
  - ~/data:/data:ro  # read-only data directory
```

### Environment variables

Set in `.env` or export before running:

| Variable | Default | Purpose |
|----------|---------|---------|
| `GALAXY_URL` | `https://usegalaxy.org` | Galaxy server URL |
| `GALAXY_API_KEY` | (empty) | Galaxy API key |
| `ANTHROPIC_API_KEY` | (empty) | Only needed if not using `claude login` |

### Sublime Text

`run.sh` automatically opens Sublime Text with the working directory added as a project. It looks for `subl` on PATH, falling back to `/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl` on macOS. Skips silently if Sublime isn't installed.

### Rebuild after changes

```bash
docker compose build
```

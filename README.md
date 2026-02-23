# Claude Code in Docker (macOS)

Run [Claude Code](https://docs.anthropic.com/en/docs/claude-code) in an isolated Docker container on macOS. Only `~/git` is visible to the container. Auth via bind-mounted `~/.claude` (OAuth from `claude login`, no API key needed).

Based on [nekrut/claude-docker-linux](https://github.com/nekrut/claude-docker-linux), adapted for macOS.

## Prerequisites

- [Docker Desktop for Mac](https://www.docker.com/products/docker-desktop/)
- `claude login` completed on host (creates `~/.claude/.credentials.json`)
- GitHub CLI authenticated on host (`gh auth login`)
- SSH keys in `~/.ssh/` (for git push)
- GitHub personal access token with `repo` scope ([create here](https://github.com/settings/tokens)) for in-container `gh` usage

## Setup

1. Clone and build:
```bash
git clone https://github.com/nekrut/claude-code-docker.git ~/git/claude-code-docker
cd ~/git/claude-code-docker
cp .env.example .env
docker compose build
```

2. Add credentials to `.env`:
```
GALAXY_URL=https://...
GALAXY_API_KEY=sk-...
GH_TOKEN=ghp_...
```

Or store Galaxy API key in macOS Keychain:
```bash
security add-generic-password -s "galaxy-api-key" -a galaxy -w "YOUR_KEY"
```

3. Add shell shortcuts to `~/.zshrc`:
```bash
cdl() { subl --new-window "$(pwd)" & docker compose -f ~/git/claude-code-docker/docker-compose.yml run --rm claude "$@"; }
cdlp() { subl --new-window "$(pwd)" & docker compose -f ~/git/claude-code-docker/docker-compose.yml run --rm --service-ports claude "$@"; }
```

4. `source ~/.zshrc`

## Usage

```bash
cd ~/git/myproject
cdl                          # opens Sublime + interactive Claude (no port mapping, can run multiple)
cdl -p "explain this repo"   # one-shot
cdlp                         # with ports 9090 + 4200 mapped (only one at a time)
```

Or without the shortcut:
```bash
cd ~/git/claude-code-docker
./run.sh                     # interactive session + opens Sublime Text
./run.sh -p "prompt"         # one-shot
```

## What's in the container

- **Base**: node:20-bookworm
- **Tools**: git, python3, gh, jq, curl, wget, sudo
- **Python**: uv, Miniconda3
- **AI**: claude-code (latest), galaxy-mcp (via uvx)

Claude runs with `--dangerously-skip-permissions` (container IS the sandbox).

## Updating

Update claude-code and galaxy-mcp inside the container without rebuilding:
```bash
UPDATE=1 ./run.sh
```

Or rebuild the image entirely:
```bash
docker compose build
```

## GitHub auth

The `gh` CLI inside the container uses `GH_TOKEN` from `.env`. Host-side keyring auth (default for `gh auth login`) is not accessible from the container — use a personal access token instead.

## Volumes

### Bind mounts (host filesystem)

| Host | Container | Mode |
|------|-----------|------|
| `~/git` | `/workspace` | rw |
| `~/.claude` | `/home/node/.claude` | rw |
| `~/.claude.json` | `/home/node/.claude.json` | rw |
| `~/.gitconfig` | `/home/node/.gitconfig` | ro |
| `~/.config/gh/hosts.yml` | `/home/node/.config/gh/hosts.yml` | ro |
| `~/.config/gh/config.yml` | `/home/node/.config/gh/config.yml` | ro |
| `~/.ssh` | `/home/node/.ssh` | ro |

### Named volumes (persist across container restarts)

| Volume | Path | Purpose |
|--------|------|---------|
| `pip-local` | `/home/node/.local` | pip user packages |
| `conda` | `/opt/conda` | conda environments |
| `uv-cache` | `/home/node/.cache/uv` | uv/uvx cache |

Packages installed via `pip install`, `conda install`, or `uv` persist across container restarts.

## Entrypoint

On each container start, `entrypoint.sh`:
1. Copies SSH keys to writable dir with correct permissions
2. Seeds conda volume from image (first run only)
3. Clones or pulls latest galaxy-skills
4. Registers Galaxy MCP server (if not already configured)
5. Optionally updates claude-code and galaxy-mcp (when `UPDATE=1`)
6. Launches `claude --dangerously-skip-permissions`

## Ports

| Port | Purpose |
|------|---------|
| 9090 | Galaxy web UI |
| 4200 | Quarto preview |

Ports are defined in `docker-compose.yml` but only mapped when using `--service-ports` (i.e., `cdlp`). Without it, multiple containers can run in parallel without port conflicts.

## Multiple agents

Each `docker compose run --rm claude` starts a separate container. Run multiple in parallel from different terminals. All share the same `~/git` workspace — coordinate by having agents work on different repos or branches.

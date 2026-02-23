# Claude Docker macOS

## Project overview
Dockerized Claude Code for macOS. Runs claude-code in isolated container with host filesystem access limited to `~/git`.

## Key architecture decisions
- **Auth**: OAuth via bind-mounted `~/.claude/.credentials.json` (from `claude login` on host). No API key.
- **GitHub auth**: `GH_TOKEN` env var from `.env` file. Host keyring not accessible from container, so `gh auth login` tokens don't work — must use personal access token with `repo` scope.
- **Config**: Both `~/.claude/` (dir) and `~/.claude.json` (file) must be mounted — claude-code uses both.
- **Persistence**: Named Docker volumes for pip (`~/.local`), conda (`/opt/conda`), uv cache. Survives container restarts.
- **Conda seed**: `/opt/conda` is a named volume (starts empty). Image keeps a copy at `/opt/conda.seed`, entrypoint seeds volume on first run.
- **SSH**: Host `~/.ssh` mounted read-only. Entrypoint copies to `/tmp/.ssh` with correct perms.
- **Permissions**: Container runs as `node` (uid 1000). Has passwordless sudo. Claude runs with `--dangerously-skip-permissions`.
- **Auto-update**: Opt-in via `UPDATE=1 ./run.sh`. Runs `sudo npm install -g` and refreshes galaxy-mcp. Skipped by default for fast startup.
- **Galaxy API key**: macOS Keychain lookup in `run.sh` (`security find-generic-password -s "galaxy-api-key"`), env var fallback.
- **gh config**: Must mount individual files (`hosts.yml`, `config.yml`) not the directory — directory mount fails due to host dir permissions.

## File structure
- `Dockerfile` — image definition (node:20-bookworm base)
- `docker-compose.yml` — service config, volumes, bind mounts
- `entrypoint.sh` — runtime setup (SSH, conda seed, galaxy-skills, MCP registration, optional updates)
- `run.sh` — host-side launcher (writes .env from Keychain, clones skills, opens editor, runs container)
- `.env` / `.env.example` — Galaxy credentials + GH_TOKEN (gitignored)

## Shell shortcuts (in ~/.zshrc)
- `cdl` — opens Sublime on current dir + launches container. No port mapping, can run multiple in parallel.
- `cdlp` — same but with `--service-ports` to expose ports 9090 (Galaxy) and 4200 (Quarto). Only one at a time (port conflict otherwise).

## Gotchas
- `docker-compose.yml` `env_file` must be `required: false` — `.env` may not exist if user runs `docker compose` directly without `run.sh`
- Host user needs Docker Desktop for Mac installed and running.
- After changing Dockerfile or entrypoint.sh, must `docker compose build` — entrypoint is COPYed into image.
- `docker compose run` does NOT map ports by default — must use `--service-ports` flag for Galaxy (9090) and Quarto preview (4200).
- gh config directory mount shows empty inside container. Mount individual files instead.
- Shell shortcuts (`cdl`/`cdlp`) require `source ~/.zshrc` or new terminal after adding to zshrc.

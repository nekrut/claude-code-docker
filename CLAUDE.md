# Claude Docker macOS

## Project overview
Dockerized Claude Code for macOS. Runs claude-code in isolated container with host filesystem access limited to `~/git`.

## Key architecture decisions
- **Auth**: OAuth credentials extracted from macOS Keychain (`Claude Code-credentials`) by `run.sh` and written to `~/.claude/.credentials.json` before container start. Newer Claude Code versions store creds in Keychain, not file.
- **GitHub auth**: `GH_TOKEN` extracted from macOS Keychain (`gh-token`) by `run.sh`, written to `.env`. Used by `gh` CLI and git HTTPS push. Credential helper set via `GIT_CONFIG_COUNT`/`GIT_CONFIG_KEY_0`/`GIT_CONFIG_VALUE_0` env vars (since `~/.gitconfig` is mounted ro).
- **`.claude.json` persistence**: Single-file Docker bind mounts corrupt when the file is rewritten. Solution: mount `~/.claude.json` ro to `/tmp/.claude.json.host`, copy into `~/.claude/.claude.json` on first run, symlink `~/.claude.json` → `~/.claude/.claude.json`. Onboarding state (theme, login) persists via the rw `~/.claude/` bind mount.
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
- `entrypoint.sh` — runtime setup (.claude.json symlink, SSH, conda seed, galaxy-skills, MCP registration, optional updates)
- `run.sh` — host-side launcher (extracts Keychain creds, writes .env, clones skills, runs container)
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
- `~/.gitconfig` is mounted ro — cannot `git config --global`. Use `GIT_CONFIG_*` env vars instead.
- Shell shortcuts (`cdl`/`cdlp`) require `source ~/.zshrc` or new terminal after adding to zshrc.
- First interactive run requires onboarding (theme + login). State persists in `~/.claude/.claude.json` after that.
- Single-file bind mounts (like `~/.claude.json`) corrupt when Docker rewrites them. Always mount ro and copy/symlink.

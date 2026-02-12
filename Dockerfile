FROM node:20-bookworm

# System deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    openssh-client \
    python3 \
    python3-pip \
    python3-venv \
    curl \
    wget \
    jq \
    && rm -rf /var/lib/apt/lists/*

# GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update && apt-get install -y gh && rm -rf /var/lib/apt/lists/*

# Claude Code
RUN npm install -g @anthropic-ai/claude-code@latest

# Switch to node user for remaining setup
USER node
WORKDIR /home/node

# uv (Python package manager)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/home/node/.local/bin:$PATH"

# Miniconda
RUN wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-$(uname -m).sh -O miniconda.sh \
    && bash miniconda.sh -b -p /home/node/miniconda3 \
    && rm miniconda.sh
ENV PATH="/home/node/miniconda3/bin:$PATH"

# Pre-cache galaxy-mcp so first run is fast
RUN uvx --from galaxy-mcp galaxy-mcp --help 2>/dev/null || true

WORKDIR /workspace

COPY --chown=node:node entrypoint.sh /home/node/entrypoint.sh
RUN chmod +x /home/node/entrypoint.sh

ENTRYPOINT ["/home/node/entrypoint.sh"]

FROM node:20-bookworm

# System deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    git openssh-client python3 python3-pip python3-venv \
    curl wget jq sudo \
    && rm -rf /var/lib/apt/lists/*

# GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# Claude Code
RUN npm install -g @anthropic-ai/claude-code@latest

# uv (Python package manager)
RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh

# Miniconda
RUN wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-aarch64.sh -O /tmp/miniconda.sh \
    && bash /tmp/miniconda.sh -b -p /opt/conda \
    && rm /tmp/miniconda.sh
ENV PATH="/opt/conda/bin:$PATH"

# Keep seed copy of conda (named volume mounts over /opt/conda)
RUN cp -a /opt/conda /opt/conda.seed

# Let node user use sudo (for in-container package installs)
RUN echo "node ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/node

# Create dirs for bind-mounted config files
RUN mkdir -p /home/node/.config/gh /home/node/.ssh && chown -R node:node /home/node/.config /home/node/.ssh

# Switch to node user
USER node
WORKDIR /workspace

# Pre-cache galaxy-mcp
RUN uvx --from galaxy-mcp galaxy-mcp --help 2>/dev/null || true

# Entrypoint
COPY --chown=node:node entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["entrypoint.sh"]

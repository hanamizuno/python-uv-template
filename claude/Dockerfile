ARG PYTHON_VERSION=3.14
ARG DEBIAN_VERSION=bookworm

FROM ghcr.io/astral-sh/uv:python${PYTHON_VERSION}-${DEBIAN_VERSION}-slim

# GitHub CLI (gh) — add apt repository before install
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list

# curl: Claude Code native installer
# git, gh, sudo: development essentials
# iptables, ipset, iproute2, dnsutils, aggregate, jq: firewall
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git gh sudo ca-certificates \
    iptables ipset iproute2 dnsutils aggregate jq \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

ARG USERNAME=claude
ARG USER_UID=1000
ARG USER_GID=$USER_UID
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && mkdir -p /workspace /home/${USERNAME}/.claude /commandhistory \
    && chown -R ${USERNAME}:${USERNAME} /workspace /home/${USERNAME}/.claude /commandhistory

# Persist bash history across container restarts
RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
    && echo "$SNIPPET" >> /home/${USERNAME}/.bashrc \
    && touch /commandhistory/.bash_history \
    && chown -R ${USERNAME} /commandhistory

# Firewall and entrypoint scripts (sudo allowed only for firewall)
COPY claude/init-firewall.sh claude/entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/init-firewall.sh /usr/local/bin/entrypoint.sh \
    && echo "${USERNAME} ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" \
       > /etc/sudoers.d/${USERNAME}-firewall \
    && chmod 0440 /etc/sudoers.d/${USERNAME}-firewall

ENV PATH="/home/claude/.local/bin:${PATH}"
WORKDIR /workspace
USER ${USERNAME}

# Install Claude Code at build time so it is available immediately on container start
RUN curl -fsSL https://claude.ai/install.sh | bash

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

ARG PYTHON_VERSION=3.14
ARG DEBIAN_VERSION=bookworm

FROM ghcr.io/astral-sh/uv:python${PYTHON_VERSION}-${DEBIAN_VERSION}-slim

# curl: Claude Code native installer
# git, sudo: development essentials
# iptables, ipset, iproute2, dnsutils, aggregate, jq: firewall
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git sudo ca-certificates \
    iptables ipset iproute2 dnsutils aggregate jq \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

ARG USERNAME=claude
ARG USER_UID=1000
ARG USER_GID=$USER_UID
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && mkdir -p /workspace /commandhistory \
    && chown -R ${USERNAME}:${USERNAME} /workspace /commandhistory

# Persist bash history across container restarts
RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
    && echo "$SNIPPET" >> /home/${USERNAME}/.bashrc \
    && touch /commandhistory/.bash_history \
    && chown -R ${USERNAME} /commandhistory

# Firewall script (sudo allowed only for this)
COPY .devcontainer/claude/init-firewall.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/init-firewall.sh \
    && echo "${USERNAME} ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" \
       > /etc/sudoers.d/${USERNAME}-firewall \
    && chmod 0440 /etc/sudoers.d/${USERNAME}-firewall

ENV DEVCONTAINER=true
WORKDIR /workspace
USER ${USERNAME}
CMD ["sleep", "infinity"]

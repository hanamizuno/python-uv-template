# cf. https://github.com/astral-sh/uv-docker-example/blob/main/Dockerfile
ARG PYTHON_VERSION=3.14
ARG DEBIAN_VERSION=bookworm
ARG UV_VERSION=python${PYTHON_VERSION}-${DEBIAN_VERSION}-slim

# ===== Stage 1: development =====
FROM ghcr.io/astral-sh/uv:$UV_VERSION AS dev

WORKDIR /workspace

ENV UV_COMPILE_BYTECODE=1
ENV UV_LINK_MODE=copy

RUN --mount=type=cache,target=/root/.cache/uv \
  --mount=type=bind,source=uv.lock,target=uv.lock \
  --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
  uv sync --frozen

COPY . /workspace
RUN --mount=type=cache,target=/root/.cache/uv \
  uv sync --frozen

ENV PATH="/workspace/.venv/bin:$PATH"

# Install pyright dependencies (pyright's bundled Node.js requires libatomic1 on slim images)
RUN apt-get update \
  && apt-get install -y --no-install-recommends libatomic1 \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* \
  && pyright --version

CMD ["python"]

# ===== Stage 2: production =====
FROM ghcr.io/astral-sh/uv:$UV_VERSION AS prod

WORKDIR /app

ENV UV_COMPILE_BYTECODE=1
ENV UV_LINK_MODE=copy

RUN --mount=type=cache,target=/root/.cache/uv \
  --mount=type=bind,source=uv.lock,target=uv.lock \
  --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
  uv sync --frozen --no-install-project --no-dev

COPY . /app
RUN --mount=type=cache,target=/root/.cache/uv \
  uv sync --frozen --no-dev

ENV PATH="/app/.venv/bin:$PATH"

ENTRYPOINT []

CMD ["python", "--version"]

# ===== Stage 3: devcontainer =====
FROM mcr.microsoft.com/vscode/devcontainers/base:$DEBIAN_VERSION AS devcontainer

ENV UV_COMPILE_BYTECODE=1
ENV UV_LINK_MODE=copy

COPY --from=dev --chown=vscode: /usr/local/bin/uv /usr/local/bin/

RUN mkdir -p /commandhistory /home/vscode/.claude /home/vscode/.codex /home/vscode/.hermes /home/vscode/.config/gh \
  && chown -R vscode:vscode /commandhistory /home/vscode/.claude /home/vscode/.codex /home/vscode/.hermes /home/vscode/.config \
  && ln -sf /home/vscode/.claude/.claude.json /home/vscode/.claude.json \
  && chown -h vscode:vscode /home/vscode/.claude.json

CMD ["sleep", "infinity"]

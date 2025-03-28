# cf. https://github.com/astral-sh/uv-docker-example/blob/main/Dockerfile
ARG UV_VERSION=python3.12-bookworm-slim

# ===== Stage 1: development =====
FROM ghcr.io/astral-sh/uv:$UV_VERSION AS dev

WORKDIR /workspace

ENV UV_COMPILE_BYTECODE=1
ENV UV_LINK_MODE=copy

RUN --mount=type=cache,target=/root/.cache/uv \
  --mount=type=bind,source=uv.lock,target=uv.lock \
  --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
  uv sync --frozen

ADD . /workspace
RUN --mount=type=cache,target=/root/.cache/uv \
  uv sync --frozen

ENV PATH="/workspace/.venv/bin:$PATH"

# Install pyright dependencies
RUN pyright --version

# Install git for devcontainer
RUN apt-get update && \
  apt-get install -y git && \
  rm -rf /var/lib/apt/lists/*

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

ADD . /app
RUN --mount=type=cache,target=/root/.cache/uv \
  uv sync --frozen --no-dev

ENV PATH="/app/.venv/bin:$PATH"

ENTRYPOINT []

CMD ["python", "--version"]

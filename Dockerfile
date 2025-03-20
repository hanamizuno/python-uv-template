# cf. https://github.com/astral-sh/uv-docker-example/blob/main/Dockerfile
ARG UV_VERSION=python3.12-bookworm-slim

# ===== Stage 1: development =====
FROM ghcr.io/astral-sh/uv:$UV_VERSION AS dev

WORKDIR /app

ENV UV_COMPILE_BYTECODE=1
ENV UV_LINK_MODE=copy

RUN --mount=type=cache,target=/root/.cache/uv \
  --mount=type=bind,source=uv.lock,target=uv.lock \
  --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
  uv sync --frozen

ADD . /app
RUN --mount=type=cache,target=/root/.cache/uv \
  uv sync --frozen

ENV PATH="/app/.venv/bin:$PATH"

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

# cf. https://github.com/astral-sh/uv-docker-example/blob/main/Dockerfile
# Base images are digest-pinned for reproducible builds; Dependabot (docker ecosystem)
# keeps the digests up to date.
FROM ghcr.io/astral-sh/uv:python3.14-bookworm-slim@sha256:7cf77f594be8042dab6daa9fe326f90962252268b4f120a7f5dccce4d947e6c1 AS base

ENV UV_COMPILE_BYTECODE=1
ENV UV_LINK_MODE=copy

# ===== Stage 1: development =====
FROM base AS dev

WORKDIR /workspace

# --no-install-project: only uv.lock / pyproject.toml are mounted in this layer, so
# building the project itself fails (missing README.md / sources) once a derived
# project becomes a package (`package = true`). The project is installed by the
# second uv sync below, after COPY.
RUN --mount=type=cache,target=/root/.cache/uv \
  --mount=type=bind,source=uv.lock,target=uv.lock \
  --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
  uv sync --frozen --no-install-project

COPY . /workspace
RUN --mount=type=cache,target=/root/.cache/uv \
  uv sync --frozen

ENV PATH="/workspace/.venv/bin:$PATH"

# Install pyright dependencies (pyright's bundled Node.js requires libatomic1 on slim images)
# DL3008: Debian point releases drop old package versions, so pinning breaks builds
# hadolint ignore=DL3008
RUN apt-get update \
  && apt-get install -y --no-install-recommends libatomic1 \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* \
  && pyright --version

CMD ["python"]

# ===== Stage 2: production =====
FROM base AS prod

WORKDIR /app

RUN --mount=type=cache,target=/root/.cache/uv \
  --mount=type=bind,source=uv.lock,target=uv.lock \
  --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
  uv sync --frozen --no-install-project --no-dev

COPY . /app
RUN --mount=type=cache,target=/root/.cache/uv \
  uv sync --frozen --no-dev

ENV PATH="/app/.venv/bin:$PATH"

# Run as a non-root user; /app stays root-owned (read-only for the app).
# The uid/gid are fixed and USER is numeric so the id stays resolvable outside the
# image (host bind mounts, Kubernetes runAsNonRoot, ...) — hadolint DL3066.
RUN groupadd --gid 10001 app \
  && useradd --uid 10001 --gid 10001 --home-dir /app --no-create-home app
USER 10001:10001

ENTRYPOINT []

CMD ["python", "--version"]

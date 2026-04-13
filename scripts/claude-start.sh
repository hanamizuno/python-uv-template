#!/bin/bash
set -euo pipefail

GIT_USER_NAME=$(git config user.name) \
GIT_USER_EMAIL=$(git config user.email) \
docker compose -f compose.claude.yml "$@"

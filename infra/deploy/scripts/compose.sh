#!/usr/bin/env bash
# Shared docker compose invocation for SIS27 + Supabase (run from repository root).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"
export SIS27_ROOT="$ROOT"
export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-sis27}"
export DOCKER_BUILDKIT="${DOCKER_BUILDKIT:-1}"
export SIS27_DOCKER_BUILD_CACHE_DIR="${SIS27_DOCKER_BUILD_CACHE_DIR:-$ROOT/.docker-build-cache}"
ENV_FILE="${ENV_FILE:-$ROOT/infra/supabase/docker/.env}"
mkdir -p "$SIS27_DOCKER_BUILD_CACHE_DIR/web" "$SIS27_DOCKER_BUILD_CACHE_DIR/contact"
exec docker compose --env-file "$ENV_FILE" \
  -f infra/supabase/docker/docker-compose.yml \
  -f infra/deploy/docker-compose.sis27.yml \
  "$@"

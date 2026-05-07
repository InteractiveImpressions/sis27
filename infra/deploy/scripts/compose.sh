#!/usr/bin/env bash
# Shared docker compose invocation for SIS27 + Supabase (run from repository root).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"
export SIS27_ROOT="$ROOT"
export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-sis27}"
ENV_FILE="${ENV_FILE:-$ROOT/infra/supabase/docker/.env}"
exec docker compose --env-file "$ENV_FILE" \
  -f infra/supabase/docker/docker-compose.yml \
  -f infra/deploy/docker-compose.sis27.yml \
  "$@"

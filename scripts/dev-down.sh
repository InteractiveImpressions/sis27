#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PROJECT_NAME="${SIS27_DEV_PROJECT_NAME:-sis27-dev}"
ENV_FILE="${SIS27_DEV_ENV_FILE:-$ROOT/infra/supabase/docker/.env}"

if [[ ! -f "$ENV_FILE" ]]; then
  ENV_FILE="$ROOT/infra/supabase/docker/.env.example"
fi

echo "Stopping local SIS27 Docker stack ($PROJECT_NAME)..."
docker compose \
  --env-file "$ENV_FILE" \
  -f infra/supabase/docker/docker-compose.yml \
  -p "$PROJECT_NAME" \
  down

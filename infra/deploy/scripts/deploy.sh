#!/usr/bin/env bash
# Run on the VM inside a clone of this repository (see README).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"
export SIS27_ROOT="$ROOT"
export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-sis27}"
ENV_FILE="${ENV_FILE:-$ROOT/infra/supabase/docker/.env}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE — copy infra/supabase/docker/.env.example and configure keys."
  exit 1
fi

COMPOSE=(docker compose --env-file "$ENV_FILE" \
  -f infra/supabase/docker/docker-compose.yml \
  -f infra/deploy/docker-compose.sis27.yml)

"${COMPOSE[@]}" up -d --build

echo "Waiting for Postgres..."
for _ in {1..45}; do
  if "${COMPOSE[@]}" exec -T db pg_isready -U postgres -d postgres >/dev/null 2>&1; then
    echo "Postgres is ready."
    break
  fi
  sleep 2
done

"$ROOT/infra/deploy/scripts/migrate.sh"
echo "Deploy complete."

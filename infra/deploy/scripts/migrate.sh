#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"
export SIS27_ROOT="$ROOT"
export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-sis27}"
ENV_FILE="${ENV_FILE:-$ROOT/infra/supabase/docker/.env}"

COMPOSE=(docker compose --env-file "$ENV_FILE" \
  -f infra/supabase/docker/docker-compose.yml \
  -f infra/deploy/docker-compose.sis27.yml)

shopt -s nullglob
files=("$ROOT"/supabase/migrations/*.sql)
if ((${#files[@]} == 0)); then
  echo "No migration files in supabase/migrations."
  exit 0
fi

for f in "${files[@]}"; do
  echo "Applying $(basename "$f")"
  "${COMPOSE[@]}" exec -T db psql -v ON_ERROR_STOP=1 -U postgres -d postgres <"$f"
done

echo "Migrations finished."

#!/usr/bin/env bash
# Apply satellite app SQL migrations from apps/*/supabase/migrations (local or VM).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

COMPOSE_ENV_FILE="${ENV_FILE:-$ROOT/infra/supabase/docker/.env}"
COMPOSE_PROJECT="${COMPOSE_PROJECT_NAME:-sis27}"
COMPOSE_FILES=(-f infra/supabase/docker/docker-compose.yml)

if [[ "${SIS27_MIGRATE_USE_DEPLOY_COMPOSE:-}" == "1" && -f "$ROOT/infra/deploy/docker-compose.sis27.yml" ]]; then
  COMPOSE_FILES+=(-f infra/deploy/docker-compose.sis27.yml)
fi

COMPOSE=(docker compose --env-file "$COMPOSE_ENV_FILE" "${COMPOSE_FILES[@]}" -p "$COMPOSE_PROJECT")

shopt -s nullglob
app_dirs=("$ROOT"/apps/*/)
if ((${#app_dirs[@]} == 0)); then
  echo "No apps under apps/ — skipping app migrations."
  exit 0
fi

found=0
for app_dir in "${app_dirs[@]}"; do
  migrations_dir="$app_dir/supabase/migrations"
  if [[ ! -d "$migrations_dir" ]]; then
    continue
  fi

  app_name="$(basename "$app_dir")"
  files=("$migrations_dir"/*.sql)
  if ((${#files[@]} == 0)); then
    continue
  fi

  for migration in "${files[@]}"; do
    found=1
    echo "Applying $app_name migration $(basename "$migration")"
    "${COMPOSE[@]}" exec -T db psql -v ON_ERROR_STOP=1 -U postgres -d postgres <"$migration"
  done
done
shopt -u nullglob

if [[ "$found" -eq 0 ]]; then
  echo "No app migration files under apps/*/supabase/migrations — skipping."
  exit 0
fi

echo "App migrations finished."

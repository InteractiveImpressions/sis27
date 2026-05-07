#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PROJECT_NAME="${SIS27_DEV_PROJECT_NAME:-sis27-dev}"
ENV_FILE="${SIS27_DEV_ENV_FILE:-$ROOT/infra/supabase/docker/.env}"

if [[ ! -f "$ENV_FILE" ]]; then
  ENV_FILE="$ROOT/infra/supabase/docker/.env.example"
  export ENABLE_EMAIL_AUTOCONFIRM="${ENABLE_EMAIL_AUTOCONFIRM:-true}"
  echo "Using Supabase example env for local dev. Create infra/supabase/docker/.env for persistent secrets."
fi

COMPOSE=(
  docker compose
  --env-file "$ENV_FILE"
  -f infra/supabase/docker/docker-compose.yml
  -p "$PROJECT_NAME"
)

CLEANED_UP=0

cleanup() {
  trap - INT TERM EXIT
  if [[ "$CLEANED_UP" == "1" ]]; then
    return
  fi
  CLEANED_UP=1
  echo
  echo "Stopping local SIS27 Docker stack ($PROJECT_NAME)..."
  "${COMPOSE[@]}" down
}

trap cleanup EXIT

echo "Starting local Supabase stack ($PROJECT_NAME)..."
"${COMPOSE[@]}" up -d

echo "Waiting for Postgres..."
for _ in {1..60}; do
  if "${COMPOSE[@]}" exec -T db pg_isready -U postgres -d postgres >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

"${COMPOSE[@]}" exec -T db pg_isready -U postgres -d postgres >/dev/null

echo "Applying local migrations..."
shopt -s nullglob
for migration in "$ROOT"/supabase/migrations/*.sql; do
  echo "  -> $(basename "$migration")"
  "${COMPOSE[@]}" exec -T db psql -v ON_ERROR_STOP=1 -U postgres -d postgres <"$migration" >/dev/null
done

echo "Waiting for Supabase API gateway..."
for _ in {1..60}; do
  status="$(curl -sS --max-time 2 -o /dev/null -w "%{http_code}" http://127.0.0.1:8000/auth/v1/health || true)"
  if [[ "$status" =~ ^(200|401)$ ]]; then
    break
  fi
  sleep 2
done

if [[ "$status" != "200" && "$status" != "401" ]]; then
  echo "Supabase API gateway did not become ready (last HTTP status: ${status:-none})."
  exit 1
fi

echo "Starting Nuxt dev server..."
set +e
pnpm --filter @sis27/web dev
DEV_EXIT_CODE="$?"
set -e

# 130 = 128 + SIGINT (Ctrl+C), 143 = 128 + SIGTERM — normal ways to stop a dev server.
# After EXIT trap runs `docker compose down`, treat these as a clean shutdown (exit 0).
if [[ "$DEV_EXIT_CODE" -eq 130 || "$DEV_EXIT_CODE" -eq 143 ]]; then
  exit 0
fi

exit "$DEV_EXIT_CODE"

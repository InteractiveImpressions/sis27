#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SIS27_DEV_FRONTEND="${SIS27_DEV_FRONTEND:-web}"
CONTACT_DIR="${SIS27_CONTACT_APP_DIR:-$ROOT/apps/contact}"
CONTACT_MIGRATIONS="${SIS27_CONTACT_MIGRATIONS:-}"
if [[ -z "$CONTACT_MIGRATIONS" && -d "$ROOT/apps/contact/supabase/migrations" ]]; then
  CONTACT_MIGRATIONS="$ROOT/apps/contact/supabase/migrations"
fi

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

if [[ -n "$CONTACT_MIGRATIONS" && -d "$CONTACT_MIGRATIONS" ]]; then
  for migration in "$CONTACT_MIGRATIONS"/*.sql; do
    echo "  -> contact/$(basename "$migration")"
    "${COMPOSE[@]}" exec -T db psql -v ON_ERROR_STOP=1 -U postgres -d postgres <"$migration" >/dev/null
  done
fi
shopt -u nullglob

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

set +e
if [[ "$SIS27_DEV_FRONTEND" == "contact" ]]; then
  if [[ ! -f "$CONTACT_DIR/package.json" ]]; then
    echo "Contact app not found at $CONTACT_DIR. Set SIS27_CONTACT_APP_DIR to the Contact package root." >&2
    exit 1
  fi
  echo "Starting Contact dev server (Next.js on port 3001)..."
  cd "$CONTACT_DIR"
  pnpm exec next dev --turbopack -p 3001
  DEV_EXIT_CODE="$?"
else
  echo "Starting Nuxt dev server..."
  cd "$ROOT"
  pnpm --filter @sis27/web dev
  DEV_EXIT_CODE="$?"
fi
set -e

# 130 = 128 + SIGINT (Ctrl+C), 143 = 128 + SIGTERM — normal ways to stop a dev server.
# After EXIT trap runs `docker compose down`, treat these as a clean shutdown (exit 0).
if [[ "$DEV_EXIT_CODE" -eq 130 || "$DEV_EXIT_CODE" -eq 143 ]]; then
  exit 0
fi

exit "$DEV_EXIT_CODE"

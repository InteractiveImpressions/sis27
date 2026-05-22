#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# all = Nuxt + Contact (default). web = stack + Nuxt only. contact = stack + Contact only.
SIS27_DEV_FRONTEND="${SIS27_DEV_FRONTEND:-all}"
CONTACT_DIR="${SIS27_CONTACT_APP_DIR:-$ROOT/apps/contact}"
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
  # After `cd` into apps/contact (standalone or submodule), return to platform root so the
  # shared stack-down helper (@sis27/platform) resolves compose paths correctly.
  cd "$ROOT"
  export SIS27_ROOT="$ROOT"
  pnpm exec sis27-stack-down
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

for app_dir in "$ROOT"/apps/*/; do
  migrations_dir="$app_dir/supabase/migrations"
  if [[ ! -d "$migrations_dir" ]]; then
    continue
  fi
  app_name="$(basename "$app_dir")"
  for migration in "$migrations_dir"/*.sql; do
    echo "  -> $app_name/$(basename "$migration")"
    "${COMPOSE[@]}" exec -T db psql -v ON_ERROR_STOP=1 -U postgres -d postgres <"$migration" >/dev/null
  done
done
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
elif [[ "$SIS27_DEV_FRONTEND" == "web" ]]; then
  echo "Starting Nuxt dev server..."
  cd "$ROOT"
  pnpm --filter @sis27/web dev
  DEV_EXIT_CODE="$?"
else
  # Default "all": dashboard + Contact (split ports; see README / @sis27/platform dev origins).
  if [[ ! -f "$CONTACT_DIR/package.json" ]]; then
    echo "Contact app not found at $CONTACT_DIR — starting Nuxt only. Initialize apps/contact (submodule) for full stack." >&2
    cd "$ROOT"
    pnpm --filter @sis27/web dev
    DEV_EXIT_CODE="$?"
  else
    echo "Starting Nuxt (3000) and Contact (3001) dev servers..."
    cd "$ROOT"
    pnpm exec concurrently --kill-others-on-fail -n web,contact -c blue,magenta \
      "pnpm --filter @sis27/web dev" \
      "pnpm --filter @sis27/contact dev:next"
    DEV_EXIT_CODE="$?"
  fi
fi
set -e

# 130 = 128 + SIGINT (Ctrl+C), 143 = 128 + SIGTERM — normal ways to stop a dev server.
# After EXIT trap runs `docker compose down`, treat these as a clean shutdown (exit 0).
if [[ "$DEV_EXIT_CODE" -eq 130 || "$DEV_EXIT_CODE" -eq 143 ]]; then
  exit 0
fi

exit "$DEV_EXIT_CODE"

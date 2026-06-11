#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# all = Nuxt + Contact + Goals (default). web | contact | goals = stack + one app.
SIS27_DEV_FRONTEND="${SIS27_DEV_FRONTEND:-all}"
CONTACT_DIR="${SIS27_CONTACT_APP_DIR:-$ROOT/apps/contact}"
GOALS_DIR="${SIS27_GOALS_APP_DIR:-$ROOT/apps/goals}"
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
  -f infra/supabase/docker/docker-compose.dbport.yml
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

echo "Applying migrations via Supabase CLI (platform + apps, one shared history)..."
SIS27_ROOT="$ROOT" ENV_FILE="$ENV_FILE" source "$ROOT/scripts/lib-db.sh"
push_all

echo "Waiting for Supabase API gateway..."
status=""
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

has_contact=0
has_goals=0
[[ -f "$CONTACT_DIR/package.json" ]] && has_contact=1
[[ -f "$GOALS_DIR/package.json" ]] && has_goals=1

run_single_frontend() {
  local which="$1"
  case "$which" in
    contact)
      if [[ "$has_contact" -eq 0 ]]; then
        echo "Contact app not found at $CONTACT_DIR. Set SIS27_CONTACT_APP_DIR or init apps/contact submodule." >&2
        exit 1
      fi
      echo "Starting Contact dev server (Next.js on port 3001)..."
      cd "$CONTACT_DIR"
      pnpm exec next dev --turbopack -p 3001
      ;;
    goals)
      if [[ "$has_goals" -eq 0 ]]; then
        echo "Goals app not found at $GOALS_DIR. Set SIS27_GOALS_APP_DIR or init apps/goals submodule." >&2
        exit 1
      fi
      echo "Starting Goals dev server (Next.js on port 3002)..."
      cd "$GOALS_DIR"
      pnpm exec next dev --turbopack -p 3002
      ;;
    web)
      echo "Starting Nuxt dev server..."
      cd "$ROOT"
      pnpm --filter @sis27/web dev
      ;;
    *)
      echo "Unknown frontend: $which" >&2
      exit 1
      ;;
  esac
}

set +e
if [[ "$SIS27_DEV_FRONTEND" == "contact" ]]; then
  run_single_frontend contact
  DEV_EXIT_CODE="$?"
elif [[ "$SIS27_DEV_FRONTEND" == "goals" ]]; then
  run_single_frontend goals
  DEV_EXIT_CODE="$?"
elif [[ "$SIS27_DEV_FRONTEND" == "web" ]]; then
  run_single_frontend web
  DEV_EXIT_CODE="$?"
else
  cd "$ROOT"
  concurrent_args=()
  concurrent_names=()
  concurrent_colors=()

  concurrent_args+=("pnpm --filter @sis27/web dev")
  concurrent_names+=("web")
  concurrent_colors+=("blue")

  if [[ "$has_contact" -eq 1 ]]; then
    concurrent_args+=("pnpm --filter @sis27/contact dev:next")
    concurrent_names+=("contact")
    concurrent_colors+=("magenta")
  else
    echo "Contact app not found at $CONTACT_DIR — skipping Contact dev server." >&2
  fi

  if [[ "$has_goals" -eq 1 ]]; then
    concurrent_args+=("pnpm --filter @sis27/goals dev:next")
    concurrent_names+=("goals")
    concurrent_colors+=("green")
  else
    echo "Goals app not found at $GOALS_DIR — skipping Goals dev server." >&2
  fi

  if ((${#concurrent_args[@]} == 1)); then
    eval "${concurrent_args[0]}"
    DEV_EXIT_CODE="$?"
  else
    names_csv="$(IFS=,; echo "${concurrent_names[*]}")"
    colors_csv="$(IFS=,; echo "${concurrent_colors[*]}")"
    echo "Starting dev servers: ${names_csv}"
    pnpm exec concurrently --kill-others-on-fail -n "$names_csv" -c "$colors_csv" "${concurrent_args[@]}"
    DEV_EXIT_CODE="$?"
  fi
fi
set -e

if [[ "$DEV_EXIT_CODE" -eq 130 || "$DEV_EXIT_CODE" -eq 143 ]]; then
  exit 0
fi

exit "$DEV_EXIT_CODE"

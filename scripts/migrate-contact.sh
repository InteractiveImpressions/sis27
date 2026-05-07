#!/usr/bin/env bash
# Apply contact app SQL migrations (apps/contact/supabase/migrations) on the VM / deploy stack.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
export SIS27_ROOT="$ROOT"
export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-sis27}"
ENV_FILE="${ENV_FILE:-$ROOT/infra/supabase/docker/.env}"

COMPOSE=(docker compose --env-file "$ENV_FILE" \
  -f infra/supabase/docker/docker-compose.yml \
  -f infra/deploy/docker-compose.sis27.yml)

CONTACT_DIR="$ROOT/apps/contact/supabase/migrations"
if [[ ! -d "$CONTACT_DIR" ]]; then
  echo "No contact migrations directory at $CONTACT_DIR — skipping."
  exit 0
fi

shopt -s nullglob
files=("$CONTACT_DIR"/*.sql)
if ((${#files[@]} == 0)); then
  echo "No *.sql files in $CONTACT_DIR — skipping."
  exit 0
fi

for f in "${files[@]}"; do
  echo "Applying contact migration $(basename "$f")"
  {
    printf 'set role contact_migrator;\n'
    cat "$f"
    printf '\nreset role;\n'
  } | "${COMPOSE[@]}" exec -T db psql -v ON_ERROR_STOP=1 -U postgres -d postgres
done

echo "Contact migrations finished."

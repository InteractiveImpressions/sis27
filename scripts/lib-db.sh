#!/usr/bin/env bash
# Shared helpers for applying Supabase migrations via the CLI against the vendored
# Docker stack. Source this file; it sets SIS27_ROOT, DB_URL and SUPABASE_CMD, and
# defines assemble_migrations / push_all.
#
# The CLI connects straight to the `db` container (published on the host by
# infra/supabase/docker/docker-compose.dbport.yml) as the `postgres` superuser with
# sslmode=disable — the supavisor pooler does not accept that without TLS.

if [[ -z "${SIS27_ROOT:-}" ]]; then
  SIS27_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# Env file holding POSTGRES_* — mirror scripts/dev.sh fallback order.
: "${ENV_FILE:=$SIS27_ROOT/infra/supabase/docker/.env}"
if [[ ! -f "$ENV_FILE" ]]; then
  ENV_FILE="$SIS27_ROOT/infra/supabase/docker/.env.example"
fi

_env_get() { sed -n "s/^$1=//p" "$ENV_FILE" | head -n1; }

POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-$(_env_get POSTGRES_PASSWORD)}"
POSTGRES_DB="${POSTGRES_DB:-$(_env_get POSTGRES_DB)}"
POSTGRES_DB="${POSTGRES_DB:-postgres}"

# Host endpoint that publishes the db container for the CLI (docker-compose.dbport.yml).
SIS27_DB_MIGRATE_HOST="${SIS27_DB_MIGRATE_HOST:-127.0.0.1}"
SIS27_DB_MIGRATE_PORT="${SIS27_DB_MIGRATE_PORT:-54322}"

# Percent-encode (pure bash, no node/jq dependency — works on the VM host too).
_url_encode() {
  local s="$1" out='' i c q="'"
  for (( i=0; i<${#s}; i++ )); do
    c="${s:i:1}"
    case "$c" in
      [a-zA-Z0-9.~_-]) out+="$c" ;;
      *) printf -v c '%%%02X' "${q}${c}"; out+="$c" ;;
    esac
  done
  printf '%s' "$out"
}

DB_URL="postgresql://postgres:$(_url_encode "$POSTGRES_PASSWORD")@${SIS27_DB_MIGRATE_HOST}:${SIS27_DB_MIGRATE_PORT}/${POSTGRES_DB}?sslmode=disable"

SUPABASE_CMD=("$("$SIS27_ROOT/scripts/ensure-supabase-cli.sh")")

# The Supabase CLI allows exactly one migration history per database, and refuses to
# apply when that table has versions absent from the local folder. So all projects
# (platform + each app) are combined into ONE staging folder and pushed as a single
# history. Each project still authors/owns its own supabase/migrations folder and
# schema; only application is unified. Files keep their timestamped names and apply in
# global timestamp order — cross-project dependencies must respect that order.
SIS27_MIGRATE_STAGE="${SIS27_MIGRATE_STAGE:-$SIS27_ROOT/.cache/supabase-combined}"

# assemble_migrations — copy platform + every app's migrations into the staging folder.
assemble_migrations() {
  local stage="$SIS27_MIGRATE_STAGE" mig
  mig="$stage/supabase/migrations"
  rm -rf "$stage"
  mkdir -p "$mig"
  cp "$SIS27_ROOT/supabase/config.toml" "$stage/supabase/config.toml"

  shopt -s nullglob
  local src base
  for src in "$SIS27_ROOT"/supabase/migrations/*.sql \
             "$SIS27_ROOT"/apps/*/supabase/migrations/*.sql; do
    base="$(basename "$src")"
    if [[ -e "$mig/$base" ]]; then
      echo "ERROR: duplicate migration filename across projects: $base" >&2
      echo "  Migration basenames must be globally unique (timestamp + name)." >&2
      shopt -u nullglob
      return 1
    fi
    cp "$src" "$mig/$base"
  done
  shopt -u nullglob
}

# push_all — assemble then apply platform + all app migrations as one history.
push_all() {
  assemble_migrations || return 1
  echo "==> Applying all migrations (platform + apps) as one shared history"
  "${SUPABASE_CMD[@]}" db push \
    --workdir "$SIS27_MIGRATE_STAGE" \
    --db-url "$DB_URL" \
    --include-all \
    --yes
}

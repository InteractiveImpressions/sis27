#!/usr/bin/env bash
# Apply all SIS27 migrations (platform + every app) via the Supabase CLI as one shared
# history, tracked in supabase_migrations.schema_migrations. Requires the stack running
# with the db port published (deploy publishes it via the dbport overlay; see
# infra/deploy/scripts/deploy.sh).
set -euo pipefail
SIS27_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
export SIS27_ROOT
export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-sis27}"
ENV_FILE="${ENV_FILE:-$SIS27_ROOT/infra/supabase/docker/.env}"
export ENV_FILE

source "$SIS27_ROOT/scripts/lib-db.sh"

push_all
echo "Migrations finished."

#!/usr/bin/env bash
# Create a new, empty migration scoped to one project (platform or an app).
#   scripts/db-new.sh <platform|<app-name>> <migration_name>
#   e.g. scripts/db-new.sh goals add_goal_status
#        scripts/db-new.sh platform add_audit_log
# The file lands in <project>/supabase/migrations/<timestamp>_<name>.sql.
set -euo pipefail
SIS27_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

target="${1:-}"; name="${2:-}"
if [[ -z "$target" || -z "$name" ]]; then
  echo "Usage: $0 <platform|<app-name>> <migration_name>" >&2
  echo "  e.g. $0 goals add_goal_status" >&2
  exit 1
fi

case "$target" in
  platform|root|sis27) workdir="$SIS27_ROOT" ;;
  *)
    workdir="$SIS27_ROOT/apps/$target"
    if [[ ! -f "$workdir/supabase/config.toml" ]]; then
      echo "No Supabase project at apps/$target (expected apps/$target/supabase/config.toml)." >&2
      exit 1
    fi
    ;;
esac

SUPABASE_BIN="$("$SIS27_ROOT/scripts/ensure-supabase-cli.sh")"
"$SUPABASE_BIN" migration new --workdir "$workdir" "$name"

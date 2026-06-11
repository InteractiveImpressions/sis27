#!/usr/bin/env bash
# Apply all pending migrations (platform + every app) against the running stack via the
# Supabase CLI, as one shared history. Requires the stack up with the db port published
# (scripts/dev.sh and the deploy do this). For ad-hoc local pushes: pnpm db:push.
set -euo pipefail
SIS27_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SIS27_ROOT/scripts/lib-db.sh"

push_all
echo "All migrations applied."

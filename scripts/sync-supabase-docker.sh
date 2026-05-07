#!/usr/bin/env sh
# Re-vendor the official Supabase docker directory (pinned to latest master tip).
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="${TMPDIR:-/tmp}/sis27-supabase-docker-sync"
rm -rf "$TMP"
git clone --depth 1 --filter=blob:none --sparse https://github.com/supabase/supabase.git "$TMP"
(cd "$TMP" && git sparse-checkout set docker)
rm -rf "$ROOT/infra/supabase/docker"
cp -a "$TMP/docker" "$ROOT/infra/supabase/docker"
echo "Updated $ROOT/infra/supabase/docker from supabase/supabase (sparse checkout)."

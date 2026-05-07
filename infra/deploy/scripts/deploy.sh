#!/usr/bin/env bash
# Run on the VM inside a clone of this repository (see README).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"
export SIS27_ROOT="$ROOT"
export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-sis27}"
export DOCKER_BUILDKIT="${DOCKER_BUILDKIT:-1}"
export SIS27_DOCKER_BUILD_CACHE_DIR="${SIS27_DOCKER_BUILD_CACHE_DIR:-$ROOT/.docker-build-cache}"
ENV_FILE="${ENV_FILE:-$ROOT/infra/supabase/docker/.env}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE — copy infra/supabase/docker/.env.example and configure keys."
  exit 1
fi

COMPOSE=(docker compose --env-file "$ENV_FILE" \
  -f infra/supabase/docker/docker-compose.yml \
  -f infra/deploy/docker-compose.sis27.yml)

mkdir -p "$SIS27_DOCKER_BUILD_CACHE_DIR/web" "$SIS27_DOCKER_BUILD_CACHE_DIR/contact"
"${COMPOSE[@]}" up -d --build

# Caddy bind-mounts `infra/deploy/Caddyfile`. If that file is replaced on disk (git pull, tar
# extract) the inode can change; the old container keeps reading the stale file. Recreate
# Caddy so the mount always matches the current Caddyfile (e.g. new `/contact` routes).
"${COMPOSE[@]}" up -d --no-deps --force-recreate sis27-caddy

echo "Waiting for Postgres..."
for _ in {1..45}; do
  if "${COMPOSE[@]}" exec -T db pg_isready -U postgres -d postgres >/dev/null 2>&1; then
    echo "Postgres is ready."
    break
  fi
  sleep 2
done

"$ROOT/infra/deploy/scripts/migrate.sh"
"$ROOT/scripts/migrate-contact.sh"
echo "Deploy complete."

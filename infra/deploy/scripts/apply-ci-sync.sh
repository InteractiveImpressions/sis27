#!/usr/bin/env bash
# Invoked on the VM by GitHub Actions after `sis27-sync.tgz` is uploaded to $HOME.
# Expands the tarball into DEPLOY_PATH, preserves existing Supabase .env, then runs deploy.sh.
set -euo pipefail

DEPLOY="${1:?Usage: apply-ci-sync.sh DEPLOY_PATH}"
TGZ="${HOME}/sis27-sync.tgz"
ENV="${DEPLOY}/infra/supabase/docker/.env"

if [[ ! -f "$TGZ" ]]; then
  echo "Missing tarball: $TGZ"
  exit 1
fi

if sudo test -f "$ENV"; then
  sudo cp "$ENV" /tmp/sis27-env-backup
fi

sudo mkdir -p "$DEPLOY"
sudo tar -xzf "$TGZ" -C "$DEPLOY"
sudo chown -R "$(whoami):$(id -gn)" "$DEPLOY"

if test -f /tmp/sis27-env-backup; then
  sudo install -m 600 /tmp/sis27-env-backup "$ENV"
fi

cd "$DEPLOY"
export SIS27_ROOT="$DEPLOY"
chmod +x infra/deploy/scripts/*.sh scripts/*.sh 2>/dev/null || true
./infra/deploy/scripts/deploy.sh

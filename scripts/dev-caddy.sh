#!/usr/bin/env bash
# Optional prod-like reverse proxy: same path split as production Caddy (:80 → apps).
# Requires Caddy v2 on PATH: https://caddyserver.com/docs/install
#
# 1. Start stack + apps: pnpm dev  (or stack + Nuxt/Contact separately on 3000/3001/8000)
# 2. In another terminal: pnpm dev:caddy
# 3. Open http://127.0.0.1:8888/ and http://127.0.0.1:8888/contact
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
if ! command -v caddy >/dev/null 2>&1; then
  echo "Install Caddy (v2) and ensure it is on PATH: https://caddyserver.com/docs/install" >&2
  exit 1
fi
export SIS27_PROXY_KONG="${SIS27_PROXY_KONG:-127.0.0.1:8000}"
export SIS27_PROXY_WEB="${SIS27_PROXY_WEB:-127.0.0.1:3000}"
export SIS27_PROXY_CONTACT="${SIS27_PROXY_CONTACT:-127.0.0.1:3001}"
export SIS27_PROXY_GOALS="${SIS27_PROXY_GOALS:-127.0.0.1:3002}"
exec caddy run --config "$ROOT/infra/dev/Caddyfile"

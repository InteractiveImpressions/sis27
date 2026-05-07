#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
export SIS27_ROOT="$ROOT"
exec pnpm exec sis27-stack-down

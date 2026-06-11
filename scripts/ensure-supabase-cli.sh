#!/usr/bin/env bash
# Resolve a usable `supabase` CLI binary and print its path to stdout (logs go to stderr).
# Resolution order:
#   1. $SUPABASE_BIN, if set and executable
#   2. the repo's pnpm-installed binary (node_modules/.bin/supabase)
#   3. a pinned standalone binary downloaded to .cache/ (for hosts without pnpm, e.g. the VM)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PINNED_VERSION="${SIS27_SUPABASE_CLI_VERSION:-2.105.0}"

log() { echo "$@" >&2; }

if [[ -n "${SUPABASE_BIN:-}" && -x "${SUPABASE_BIN}" ]]; then
  echo "$SUPABASE_BIN"; exit 0
fi

if [[ -x "$ROOT/node_modules/.bin/supabase" ]]; then
  echo "$ROOT/node_modules/.bin/supabase"; exit 0
fi

# Fallback: download a pinned standalone binary (release asset:
# supabase_<version>_<os>_<arch>.tar.gz).
case "$(uname -s)" in
  Linux) os=linux ;;
  Darwin) os=darwin ;;
  *) log "Unsupported OS $(uname -s) — install the Supabase CLI manually and set SUPABASE_BIN."; exit 1 ;;
esac
case "$(uname -m)" in
  x86_64|amd64) arch=amd64 ;;
  arm64|aarch64) arch=arm64 ;;
  *) log "Unsupported arch $(uname -m) — install the Supabase CLI manually and set SUPABASE_BIN."; exit 1 ;;
esac

cache_dir="$ROOT/.cache/supabase/$PINNED_VERSION"
bin="$cache_dir/supabase"
if [[ -x "$bin" ]]; then echo "$bin"; exit 0; fi

mkdir -p "$cache_dir"
asset="supabase_${PINNED_VERSION}_${os}_${arch}.tar.gz"
url="https://github.com/supabase/cli/releases/download/v${PINNED_VERSION}/${asset}"
log "Downloading Supabase CLI ${PINNED_VERSION} ($os/$arch)..."
curl -fsSL "$url" -o "$cache_dir/cli.tar.gz"
tar -xzf "$cache_dir/cli.tar.gz" -C "$cache_dir" supabase
rm -f "$cache_dir/cli.tar.gz"
chmod +x "$bin"
echo "$bin"

#!/usr/bin/env bash
# Paket doğrulayıcı sarmalayıcı: chmod +x ve node tool/verify_pack.js. Ek argümanlar iletilir (--no-hash, --quick, --json).
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
chmod +x "$DIR"/*.sh "$DIR"/hooks/*.sh 2>/dev/null || true
exec node "$DIR/verify_pack.js" "$@"

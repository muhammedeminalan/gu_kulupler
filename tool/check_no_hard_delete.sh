#!/usr/bin/env bash
# check_no_hard_delete.js sarmalayıcısı (bash 3.2 / macOS uyumlu). Tüm argümanları iletir.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec node "$DIR/check_no_hard_delete.js" "$@"

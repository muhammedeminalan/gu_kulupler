#!/usr/bin/env bash
# Kod üretimi: pub get → build_runner (kök + packages/*) → gen-l10n. Üretilen dosyalar commit EDİLMEZ (D-08).
#   bash tool/codegen.sh            # tek seferlik
#   bash tool/codegen.sh --watch    # build_runner watch (kök paket)
#   bash tool/codegen.sh --clean    # build_runner clean + yeniden üret
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
cd "$ROOT"

MODE="build"
for a in "$@"; do
  case "$a" in
    --watch) MODE="watch" ;;
    --clean) MODE="clean" ;;
    -h|--help) sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "bilinmeyen argüman: $a"; exit 2 ;;
  esac
done

echo "== flutter pub get"
flutter pub get

has_runner() { grep -q 'build_runner' "$1/pubspec.yaml" 2>/dev/null; }

run_runner() {
  local dir="$1"
  echo "== build_runner ($dir)"
  case "$MODE" in
    watch) ( cd "$dir" && dart run build_runner watch --delete-conflicting-outputs ) ;;
    clean) ( cd "$dir" && dart run build_runner clean && dart run build_runner build --delete-conflicting-outputs ) ;;
    *)     ( cd "$dir" && dart run build_runner build --delete-conflicting-outputs ) ;;
  esac
}

if has_runner "."; then run_runner "."; fi
for p in packages/*/; do
  p="${p%/}"
  if [ -f "$p/pubspec.yaml" ] && has_runner "$p"; then run_runner "$p"; fi
done

if [ -f l10n.yaml ]; then
  echo "== flutter gen-l10n"
  flutter gen-l10n
fi
echo "codegen: tamam"

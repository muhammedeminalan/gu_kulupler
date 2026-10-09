#!/usr/bin/env bash
# PostToolUse (Edit|Write|MultiEdit) — yazılan dosyada hardcode / hard delete / katman sınırı taraması.
# Girdi: stdin'de Claude Code hook JSON'u (tool_input.file_path). Çıkış 2 + stderr => ihlal Claude'a geri beslenir.
# bash 3.2 (macOS) uyumlu; Node >= 18 gerekir. Node yoksa sessizce geçer (kapı zaten yakalar).
set -u
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_DIR="$(cd "$HOOK_DIR/.." && pwd)"
ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$TOOL_DIR/.." && pwd)}"

command -v node >/dev/null 2>&1 || exit 0

INPUT="$(cat 2>/dev/null || true)"
[ -z "$INPUT" ] && exit 0
FILE="$(printf '%s' "$INPUT" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const j=JSON.parse(s);const t=j.tool_input||{};process.stdout.write(String(t.file_path||t.path||""))}catch(e){}})' 2>/dev/null || true)"
[ -z "$FILE" ] && exit 0

case "$FILE" in
  "$ROOT"/*) REL="${FILE#"$ROOT"/}"; ABS="$FILE" ;;
  /*) exit 0 ;;                       # proje dışı mutlak yol
  *) REL="$FILE"; ABS="$ROOT/$FILE" ;;
esac
[ -f "$ABS" ] || exit 0

RC=0
OUT=""
run() {
  local o
  o="$("$@" 2>&1)"
  if [ $? -ne 0 ]; then OUT="${OUT}${o}"$'\n'; RC=2; fi
}

case "$REL" in
  *.g.dart|*.gen.dart|*.freezed.dart|lib/l10n/app_localizations*|*/firebase_options.dart|lib/firebase_options.dart) exit 0 ;;
  lib/*.dart|packages/*/lib/*.dart)
    run node "$TOOL_DIR/check_hardcode.js" --root "$ROOT" --files "$ABS"
    run node "$TOOL_DIR/check_no_hard_delete.js" --root "$ROOT" --files "$ABS"
    run node "$TOOL_DIR/check_boundaries.js" --root "$ROOT" --files "$ABS"
    ;;
  tool/*.dart|tool/*/*.dart)
    run node "$TOOL_DIR/check_no_hard_delete.js" --root "$ROOT" --files "$ABS"
    ;;
  functions/src/*.ts|functions/src/*.js|functions/src/*/*.ts|tool/admin/*.js|tool/seed/*.js|firebase/*.rules|*.rules)
    run node "$TOOL_DIR/check_no_hard_delete.js" --root "$ROOT" --files "$ABS"
    ;;
  assets/*.svg|assets/*/*.svg|assets/*/*/*.svg)
    run node "$TOOL_DIR/check_hardcode.js" --root "$ROOT" --files "$ABS"
    ;;
  packages/*/pubspec.yaml)
    run node "$TOOL_DIR/check_boundaries.js" --root "$ROOT"
    ;;
  *) exit 0 ;;
esac

if [ "$RC" -ne 0 ]; then
  {
    echo "Kalite hook'u: $REL dosyasında ihlal var. Düzelt (susturma, kural dışı istisna yok):"
    printf '%s' "$OUT"
    echo "Kurallar: CLAUDE.md §6 (hardcode, hard delete), §1 (katmanlar), §9 (soft delete). Kural listesi: node tool/check_hardcode.js --list"
  } >&2
  exit 2
fi
exit 0

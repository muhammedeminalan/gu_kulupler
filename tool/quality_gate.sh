#!/usr/bin/env bash
# GÜ Kulüpler — kalite kapısı. Kırmızıyken commit yok, task bitmez (CLAUDE.md §9, docs/testing.md §9).
#
#   bash tool/quality_gate.sh --task T-17      # task bitişi: TAM kapı + o task'ın tasarım kapsamı  (done için zorunlu)
#   bash tool/quality_gate.sh --fast           # ara kontrol: format + analyze + taramalar + hızlı matris (done için GEÇERSİZ)
#   bash tool/quality_gate.sh --static         # yalnızca statik: format + analyze + taramalar + ARB + tasarım (test yok)
#   bash tool/quality_gate.sh                  # tam kapı (biten task'ların kapsamı)
#   bash tool/quality_gate.sh --final          # nihai (T-47): her şey + tüm kimlikler/aksiyonlar + kullanılmayan ARB + borç 0
#   ek: --check-format (biçimlendirmeyi uygulama, yalnızca doğrula) · --verbose (çıktıyı akıt)
#   ortam: GU_GATE_STATIC_ONLY=1 (flutter/dart adımlarını atla) · GU_GATE_VERBOSE=1
#
# Adımlar: format → codegen → analyze → sınırlar → hardcode → hard-delete → ARB → tasarım kapsamı → test(+kapsam) → Rules.
# Başarısız adımın logunun son satırları gösterilir; tam log: tool/.cache/gate-logs/.
# Not (Claude Code): Bash aracının varsayılan zaman aşımı 2 dk'dır; tam kapı için timeout=600000 ver ya da arka planda çalıştır.
# bash 3.2 (macOS) uyumludur.

set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
cd "$ROOT" || exit 2

TASK=""; FAST=0; STATIC=0; FINAL=0; CHECK_FMT=0
VERBOSE="${GU_GATE_VERBOSE:-0}"
STATIC_ONLY="${GU_GATE_STATIC_ONLY:-0}"

usage() { sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
    --task) TASK="${2:-}"; shift 2 || { echo "--task değer ister"; exit 2; } ;;
    --fast) FAST=1; shift ;;
    --static) STATIC=1; shift ;;
    --final) FINAL=1; shift ;;
    --check-format) CHECK_FMT=1; shift ;;
    --verbose) VERBOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "bilinmeyen argüman: $1"; usage; exit 2 ;;
  esac
done

if [ -n "$TASK" ] && ! printf '%s' "$TASK" | grep -Eq '^T-[0-9]{2}$'; then echo "geçersiz task: $TASK (T-00 … T-47)"; exit 2; fi
if [ "$FINAL" = 1 ] && { [ "$FAST" = 1 ] || [ "$STATIC" = 1 ]; }; then echo "--final, --fast/--static ile birlikte kullanılamaz"; exit 2; fi
if ! command -v node >/dev/null 2>&1; then echo "node bulunamadı (>= 18 gerekli)"; exit 2; fi

MODE="full"; [ "$FAST" = 1 ] && MODE="fast"; [ "$STATIC" = 1 ] && MODE="static"
LABEL="${TASK:-tümü}"; [ "$FINAL" = 1 ] && LABEL="NİHAİ"

LOGDIR="$ROOT/tool/.cache/gate-logs"
mkdir -p "$LOGDIR" && rm -f "$LOGDIR"/*.log 2>/dev/null

if [ "$STATIC_ONLY" != 1 ]; then
  for t in flutter dart; do
    command -v "$t" >/dev/null 2>&1 || { echo "$t bulunamadı. Flutter SDK PATH'te olmalı (ya da GU_GATE_STATIC_ONLY=1)."; exit 2; }
  done
  [ -f pubspec.yaml ] || { echo "pubspec.yaml yok — T-00 (prompts/02-faz0-kurulum.md) tamamlanmadan kapı çalışmaz."; exit 2; }
fi

N=0; PASSED=0; FAILED=""; WARNINGS=""; BLOCKING_FAILED=0; LAST_RC=0
T_START=$(date +%s)

# step <ad> <blocking:0|1> <komut ...>
step() {
  local name="$1" blocking="$2"; shift 2
  N=$((N + 1))
  local log; log="$LOGDIR/$(printf '%02d' "$N")-$name.log"
  local t0; t0=$(date +%s)
  local rc
  if [ "$VERBOSE" = 1 ]; then
    "$@" 2>&1 | tee "$log"; rc=${PIPESTATUS[0]}
  else
    "$@" >"$log" 2>&1; rc=$?
  fi
  local dt=$(( $(date +%s) - t0 ))
  LAST_RC=$rc
  if [ "$rc" -eq 0 ]; then
    printf '  ✓ %-24s %4ss\n' "$name" "$dt"
    PASSED=$((PASSED + 1))
    # uyarı satırlarını göster
    grep -E '^(UYARI|warning:)' "$log" 2>/dev/null | head -5 | sed 's/^/      /'
  else
    printf '  ✗ %-24s %4ss   log: tool/.cache/gate-logs/%s\n' "$name" "$dt" "$(basename "$log")"
    if [ "$VERBOSE" != 1 ]; then tail -n 45 "$log" | sed 's/^/      /'; fi
    FAILED="$FAILED $name"
    [ "$blocking" = 1 ] && BLOCKING_FAILED=1
  fi
  return 0
}
skip() { printf '  – %-24s atlandı (%s)\n' "$1" "$2"; }
warn() { printf '  ! %s\n' "$1"; WARNINGS="$WARNINGS|$1"; }

# ── adım gövdeleri ─────────────────────────────────────────
fmt_dirs() { local d out=""; for d in lib test integration_test packages; do [ -d "$d" ] && out="$out $d"; done; printf '%s' "$out"; }

do_format() {
  local dirs; dirs="$(fmt_dirs)"
  [ -z "$dirs" ] && { echo "biçimlendirilecek dizin yok"; return 0; }
  # design/ ve reference/ asla biçimlendirilmez (salt okunur)
  if [ "$CHECK_FMT" = 1 ]; then
    # shellcheck disable=SC2086
    dart format --output=none --set-exit-if-changed $dirs
  else
    # shellcheck disable=SC2086
    dart format $dirs
  fi
}

do_analyze() {
  local rc=0 p
  flutter analyze --fatal-infos --fatal-warnings . || rc=1
  for p in packages/*/; do
    if [ -f "${p}pubspec.yaml" ]; then
      ( cd "$p" && flutter analyze --fatal-infos --fatal-warnings . ) || rc=1
    fi
  done
  return $rc
}

do_tests() {
  local rc=0 dir ran=0 cov="" matrix="full"
  [ "$MODE" = "full" ] && cov="--coverage"
  [ "$MODE" = "fast" ] && matrix="fast"
  for dir in . packages/*; do
    [ -d "$dir/test" ] || continue
    [ -f "$dir/pubspec.yaml" ] || continue
    ran=1
    echo "== flutter test ($dir) matrix=$matrix"
    # shellcheck disable=SC2086
    ( cd "$dir" && flutter test $cov --dart-define=GU_MATRIX="$matrix" ) || rc=1
  done
  if [ "$ran" = 0 ]; then
    if [ "$TASK" = "T-00" ]; then echo "UYARI: hiç test dizini yok (T-00 için kabul; test/smoke_test.dart önerilir)"; return 0; fi
    echo "HATA: hiç test dizini yok — her widget/servis/ViewModel için test zorunlu (D-33)"; return 1
  fi
  return $rc
}

do_rules() {
  local rc=0
  if [ -f firebase/package.json ]; then
    if [ ! -d firebase/node_modules ]; then echo "HATA: firebase/node_modules yok — (cd firebase && npm ci)"; return 1; fi
    command -v firebase >/dev/null 2>&1 || { echo "HATA: firebase CLI yok (emülatör gerekli) — npm i -g firebase-tools"; return 1; }
    ( cd firebase && npm test ) || rc=1
  fi
  if [ -f functions/package.json ] && grep -q '"test"' functions/package.json; then
    if [ ! -d functions/node_modules ]; then echo "HATA: functions/node_modules yok — (cd functions && npm ci)"; return 1; fi
    ( cd functions && npm test ) || rc=1
  fi
  return $rc
}

# ── çalıştır ───────────────────────────────────────────────
echo "KALİTE KAPISI — ${LABEL} · mod: ${MODE}$([ "$FINAL" = 1 ] && echo ' · nihai')"

if [ "$STATIC_ONLY" != 1 ]; then
  step format 0 do_format
  if [ "$MODE" = "full" ]; then
    if [ -f tool/codegen.sh ]; then step codegen 1 bash tool/codegen.sh; else skip codegen "tool/codegen.sh yok"; fi
  else
    skip codegen "$MODE modunda atlanır (gerekirse: bash tool/codegen.sh)"
  fi
  if [ "$BLOCKING_FAILED" = 0 ]; then step analyze 1 do_analyze; else skip analyze "codegen başarısız"; fi
else
  skip "format/codegen/analyze" "GU_GATE_STATIC_ONLY=1"
fi

step sinirlar 0 node tool/check_boundaries.js
step hardcode 0 node tool/check_hardcode.js
step hard-delete 0 node tool/check_no_hard_delete.js

if [ -f lib/l10n/app_tr.arb ] || [ -f lib/l10n/app_en.arb ]; then
  if [ "$FINAL" = 1 ]; then step arb 0 node tool/check_arb_parity.js --strict --unused; else step arb 0 node tool/check_arb_parity.js --strict; fi
else
  skip arb "lib/l10n/*.arb yok"
fi

step tasarim-harita 0 node tool/check_design_coverage.js --map
if [ "$FINAL" = 1 ]; then
  step tasarim-kapsam 0 node tool/check_design_coverage.js --all
elif [ -n "$TASK" ]; then
  step tasarim-kapsam 0 node tool/check_design_coverage.js --task "$TASK" --actions
else
  step tasarim-kapsam 0 node tool/check_design_coverage.js --actions
fi

if [ "$MODE" = "static" ] || [ "$STATIC_ONLY" = 1 ]; then
  skip test "$([ "$STATIC_ONLY" = 1 ] && echo GU_GATE_STATIC_ONLY || echo '--static')"
elif [ "$BLOCKING_FAILED" = 1 ]; then
  skip test "analiz/codegen kırmızı"
else
  step test 0 do_tests
  if [ "$MODE" = "full" ]; then
    if [ "$LAST_RC" -eq 0 ]; then step kapsam 0 node tool/check_coverage.js; else skip kapsam "test kırmızı"; fi
    step rules 0 do_rules
  else
    skip kapsam "--fast"; skip rules "--fast"
  fi
fi

# ── özet ────────────────────────────────────────────────────
DT=$(( $(date +%s) - T_START ))
STATUS="pass"; [ -n "$FAILED" ] && STATUS="fail"
echo
if [ "$STATUS" = "pass" ]; then
  echo "KAPI: GEÇTİ ✓  (${PASSED} adım, ${DT}s, mod ${MODE})"
  if [ "$MODE" != "full" ]; then echo "      Bu mod task bitişi için GEÇERLİ DEĞİL; tam kapı: bash tool/quality_gate.sh --task ${TASK:-T-xx}"; fi
else
  echo "KAPI: KALDI ✗  (başarısız:${FAILED})"
  echo "      Ayrıntı: tool/.cache/gate-logs/ · hook/skill: gu-quality-gate"
fi

# kayıt (progress.js done tam yeşil kaydı arar)
if [ -f docs/progress.json ]; then
  REC_TASK="${TASK:-ALL}"; [ "$FINAL" = 1 ] && REC_TASK="FINAL"
  if [ "$STATIC_ONLY" = 1 ]; then REC_MODE="static"; else REC_MODE="$MODE"; fi
  node tool/progress.js record-gate --task "$REC_TASK" --status "$STATUS" --mode "$REC_MODE" >/dev/null 2>&1 || true
fi
[ "$STATUS" = "pass" ] && exit 0 || exit 1

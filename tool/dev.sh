#!/usr/bin/env bash
# GÜ Kulüpler — emülatörle geliştirme: emülatörü başlat → demo veriyi yükle → uygulamayı çalıştır.
#
#   bash tool/dev.sh                    # emülatör + demo veri + flutter run (çıkınca emülatör kapanır)
#   bash tool/dev.sh -d "iPhone 13"     # kalan argümanlar flutter run'a geçer
#   bash tool/dev.sh --no-run           # yalnızca emülatör + demo veri (açık kalır)
#   bash tool/dev.sh --keep             # flutter run bitince emülatörü açık bırak
#   bash tool/dev.sh --reseed           # açık emülatöre demo veriyi yeniden yükle
#   bash tool/dev.sh --stop             # emülatörü kapat
#
# Yalnızca yerel emülatör ve `demo-gu-kulupler` projesiyle çalışır; gerçek Firebase projesine
# hiçbir komut göndermez. Uygulama `--dart-define=ENV=emulator` ile (yalnızca debug) açılır.
set -euo pipefail
cd "$(dirname "$0")/.."

PROJECT="demo-gu-kulupler"
HOST="127.0.0.1"
FIRESTORE_PORT=8080
AUTH_PORT=9099
STORAGE_PORT=9199
CACHE_DIR="tool/.cache"
LOG="$CACHE_DIR/emulator.log"
EMULATOR_CMD="emulators:start --only auth,firestore,storage --project $PROJECT"

RUN_APP=1; KEEP=0; RESEED=0; STOP_ONLY=0
FLUTTER_ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --no-run) RUN_APP=0; KEEP=1 ;;
    --keep) KEEP=1 ;;
    --reseed) RESEED=1 ;;
    --stop) STOP_ONLY=1 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) FLUTTER_ARGS+=("$1") ;;
  esac
  shift
done

say() { printf '\n▸ %s\n' "$*"; }

port_open() { curl -s -o /dev/null --max-time 2 "http://$HOST:$1/"; }
emulator_up() { port_open "$FIRESTORE_PORT" && port_open "$AUTH_PORT"; }

stop_emulator() {
  pkill -INT -f "$EMULATOR_CMD" 2>/dev/null || true
  for _ in $(seq 1 30); do
    if ! port_open "$FIRESTORE_PORT" && ! port_open "$AUTH_PORT"; then return 0; fi
    sleep 1
  done
  echo "UYARI: emülatör 30 sn içinde kapanmadı" >&2
}

if [ "$STOP_ONLY" = 1 ]; then
  say "Emülatör kapatılıyor"
  stop_emulator
  echo "Kapandı."
  exit 0
fi

command -v firebase >/dev/null 2>&1 || { echo "HATA: firebase CLI yok — npm i -g firebase-tools" >&2; exit 1; }
command -v java >/dev/null 2>&1 || { echo "HATA: Java yok (emülatör için gerekli)" >&2; exit 1; }
command -v node >/dev/null 2>&1 || { echo "HATA: Node.js yok" >&2; exit 1; }

STARTED_HERE=0
if emulator_up; then
  say "Emülatör zaten açık"
else
  say "Emülatör başlatılıyor (günlük: $LOG)"
  mkdir -p "$CACHE_DIR"
  # shellcheck disable=SC2086
  nohup firebase $EMULATOR_CMD >"$LOG" 2>&1 &
  STARTED_HERE=1
  for _ in $(seq 1 90); do
    if emulator_up; then break; fi
    sleep 1
  done
  if ! emulator_up; then
    echo "HATA: emülatör 90 sn içinde açılmadı. Son satırlar:" >&2
    tail -15 "$LOG" >&2 || true
    exit 1
  fi
fi

cleanup() {
  if [ "$STARTED_HERE" = 1 ] && [ "$KEEP" = 0 ]; then
    say "Emülatör kapatılıyor"
    stop_emulator
  fi
}
trap cleanup EXIT

seeded() {
  curl -s --max-time 5 -H "Authorization: Bearer owner" \
    "http://$HOST:$FIRESTORE_PORT/v1/projects/$PROJECT/databases/(default)/documents/clubs?pageSize=1" \
    | grep -q '"documents"'
}

if [ "$RESEED" = 1 ] || ! seeded; then
  say "Demo veri yükleniyor"
  FIRESTORE_EMULATOR_HOST="$HOST:$FIRESTORE_PORT" \
  FIREBASE_AUTH_EMULATOR_HOST="$HOST:$AUTH_PORT" \
  FIREBASE_STORAGE_EMULATOR_HOST="$HOST:$STORAGE_PORT" \
    node tool/seed/seed_emulator.js --project "$PROJECT" | tail -3
else
  say "Demo veri zaten yüklü (yeniden yüklemek için --reseed)"
fi

if [ "$RUN_APP" = 0 ]; then
  say "Hazır. Emülatör açık kalıyor."
  echo "  Uygulama : flutter run --dart-define=ENV=emulator"
  echo "  Arayüz   : http://$HOST:4000"
  echo "  Kapatmak : bash tool/dev.sh --stop"
  exit 0
fi

say "Kod üretimi (l10n, riverpod, rotalar)"
bash tool/codegen.sh >/dev/null

say "Uygulama başlatılıyor (ENV=emulator)"
flutter run --dart-define=ENV=emulator ${FLUTTER_ARGS[@]+"${FLUTTER_ARGS[@]}"}

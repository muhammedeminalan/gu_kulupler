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
# T-42 (Mod F): Cloud Functions emülatörü de açılır (functions/ önce derlenir; push gerçek FCM'e gitmez —
# LoggingPushSender). Demo veri tetikleyiciler KAPALIYKEN yüklenir (seed bildirim / terfi üretmez).
set -euo pipefail
cd "$(dirname "$0")/.."

PROJECT="demo-gu-kulupler"
HOST="127.0.0.1"
FIRESTORE_PORT=8080
AUTH_PORT=9099
STORAGE_PORT=9199
FUNCTIONS_PORT=5001
HUB_PORT=4400   # firebase.json emulators.hub — tetikleyicileri seed sırasında kapatmak için
CACHE_DIR="tool/.cache"
LOG="$CACHE_DIR/emulator.log"
EMULATOR_CMD="emulators:start --only auth,firestore,storage,functions --project $PROJECT"
# Kapatma kalıbı T-42 öncesi (functions'sız) başlatılmış oturumu da yakalar (pkill -f: genişletilmiş regex).
EMULATOR_PATTERN="emulators:start --only auth,firestore,storage(,functions)? --project $PROJECT"

RUN_APP=1; KEEP=0; RESEED=0; STOP_ONLY=0
FLUTTER_ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --no-run) RUN_APP=0; KEEP=1 ;;
    --keep) KEEP=1 ;;
    --reseed) RESEED=1 ;;
    --stop) STOP_ONLY=1 ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    *) FLUTTER_ARGS+=("$1") ;;
  esac
  shift
done

say() { printf '\n▸ %s\n' "$*"; }

port_open() { curl -s -o /dev/null --max-time 2 "http://$HOST:$1/"; }
emulator_up() { port_open "$FIRESTORE_PORT" && port_open "$AUTH_PORT"; }
functions_up() { port_open "$FUNCTIONS_PORT"; }
# Bu betiğin başlattığı oturum: tüm emülatörler (functions tetikleyicileri dahil) yüklendi.
emulator_ready() { emulator_up && functions_up && grep -q "All emulators ready" "$LOG" 2>/dev/null; }

# functions/ derlemesi (lib/ — firebase.json `functions.source`, package.json `main`). node_modules yoksa önce
# kilit dosyasından kurulur (npm ci). Yalnızca emülatörü bu betik başlatırken koşar.
build_functions() {
  if [ ! -d functions/node_modules ]; then
    say "Functions bağımlılıkları kuruluyor (npm ci)"
    npm --prefix functions ci
  fi
  say "Functions derleniyor"
  npm --prefix functions run build >/dev/null
}

# Emülatör merkezinin (hub) tetikleyici anahtarı: `disable` / `enable` (yalnızca olay tetikleyicileri; HTTP değil).
TRIGGERS_OFF=0
set_triggers() {
  curl -s -o /dev/null -w '%{http_code}' --max-time 10 -X PUT "http://$HOST:$HUB_PORT/functions/${1}BackgroundTriggers" || true
}
enable_triggers() {
  if [ "$TRIGGERS_OFF" = 1 ]; then
    set_triggers enable >/dev/null
    TRIGGERS_OFF=0
  fi
}

# CLI kapanırken Firestore emülatörünün Java süreci bazen geride kalır ve portu tutar;
# yalnızca komut satırında emülatör JAR'ı geçen süreç sonlandırılır.
kill_orphan_firestore() {
  local pid
  for pid in $(lsof -tiTCP:"$FIRESTORE_PORT" -sTCP:LISTEN 2>/dev/null); do
    if ps -o command= -p "$pid" 2>/dev/null | grep -q "cloud-firestore-emulator"; then
      kill "$pid" 2>/dev/null || true
    fi
  done
}

stop_emulator() {
  pkill -INT -f "$EMULATOR_PATTERN" 2>/dev/null || true
  for i in $(seq 1 30); do
    if ! port_open "$FIRESTORE_PORT" && ! port_open "$AUTH_PORT" && ! functions_up; then return 0; fi
    if [ "$i" = 10 ]; then kill_orphan_firestore; fi
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
command -v npm >/dev/null 2>&1 || { echo "HATA: npm yok (functions derlemesi için gerekli)" >&2; exit 1; }

STARTED_HERE=0
if emulator_up; then
  say "Emülatör zaten açık"
  if ! functions_up; then
    # Açık oturum yeniden BAŞLATILMAZ (veri ve oturum korunur); push / terfi / new_report tetikleyicileri için:
    echo "  Not: Functions emülatörü kapalı (T-42 öncesi oturum) — tetikleyiciler çalışmaz."
    echo "       Açmak için: bash tool/dev.sh --stop && bash tool/dev.sh --no-run"
  fi
else
  build_functions
  say "Emülatör başlatılıyor (günlük: $LOG)"
  mkdir -p "$CACHE_DIR"
  # shellcheck disable=SC2086
  nohup firebase $EMULATOR_CMD >"$LOG" 2>&1 &
  STARTED_HERE=1
  for _ in $(seq 1 120); do
    if emulator_ready; then break; fi
    sleep 1
  done
  if ! emulator_ready; then
    echo "HATA: emülatör 120 sn içinde hazır olmadı. Son satırlar:" >&2
    tail -15 "$LOG" >&2 || true
    exit 1
  fi
fi

cleanup() {
  enable_triggers
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
  # Seed yazımları tetikleyicileri ateşlemesin (bildirim → push makbuzu, rapor → new_report, rsvp → terfi):
  # demo veri deterministik kalır. Functions kapalıysa (eski oturum) adım atlanır.
  if functions_up; then
    if [ "$(set_triggers disable)" = 200 ]; then
      TRIGGERS_OFF=1
    else
      echo "UYARI: Functions tetikleyicileri kapatılamadı (hub $HOST:$HUB_PORT) — seed tetikleyicileri ateşleyebilir" >&2
    fi
  fi
  say "Demo veri yükleniyor"
  FIRESTORE_EMULATOR_HOST="$HOST:$FIRESTORE_PORT" \
  FIREBASE_AUTH_EMULATOR_HOST="$HOST:$AUTH_PORT" \
  FIREBASE_STORAGE_EMULATOR_HOST="$HOST:$STORAGE_PORT" \
    node tool/seed/seed_emulator.js --project "$PROJECT" | tail -3
  enable_triggers
else
  say "Demo veri zaten yüklü (yeniden yüklemek için --reseed)"
fi

if [ "$RUN_APP" = 0 ]; then
  say "Hazır. Emülatör açık kalıyor."
  echo "  Uygulama : flutter run --dart-define=ENV=emulator"
  echo "  Arayüz   : http://$HOST:4000"
  echo "  Functions: functions/ değişince 'npm --prefix functions run build' (emülatör lib/'i yeniden yükler)"
  echo "  Kapatmak : bash tool/dev.sh --stop"
  exit 0
fi

say "Kod üretimi (l10n, riverpod, rotalar)"
bash tool/codegen.sh >/dev/null

say "Uygulama başlatılıyor (ENV=emulator)"
flutter run --dart-define=ENV=emulator ${FLUTTER_ARGS[@]+"${FLUTTER_ARGS[@]}"}

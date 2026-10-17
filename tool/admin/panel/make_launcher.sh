#!/usr/bin/env bash
# Masaüstüne "GÜ Admin Paneli" uygulamasını kurar: çift tık → panel arka planda başlar → tarayıcıda açılır.
# Panel zaten açıksa yalnızca tarayıcıyı açar. Bir kez çalıştırman yeter (repo / node / anahtar yolu değişirse yeniden).
#
#   bash tool/admin/panel/make_launcher.sh [anahtar-yolu]     # varsayılan: ~/.secrets/gu-kulupler-admin.json
#
# Uygulama yalnızca yolları içerir; anahtarın kendisini içermez. Günlük: ~/Library/Logs/gu-admin-panel.log
set -euo pipefail
cd "$(dirname "$0")/../../.."
REPO="$(pwd)"
NODE="$(command -v node)"
KEY="${1:-$HOME/.secrets/gu-kulupler-admin.json}"
DEST="$HOME/Desktop/GÜ Admin Paneli.app"
# Paket geçici klasörde kurulup imzalanır (masaüstü iCloud'la eşleniyorsa ek öznitelikler imzayı bozar), sonra taşınır.
WORK="$(mktemp -d)"
APP="$WORK/GÜ Admin Paneli.app"
PORT=4848

[ -x "$NODE" ] || { echo "node bulunamadı"; exit 1; }
[ -f "$KEY" ] || { echo "anahtar yok: $KEY"; exit 1; }
case "$KEY" in "$REPO"/*) echo "anahtar repo içinde olamaz (D-36)"; exit 1 ;; esac

SCRIPT="$(mktemp -t gu-admin-panel).applescript"
cat > "$SCRIPT" <<APPLESCRIPT
set panelUrl to "http://127.0.0.1:$PORT/"
try
  do shell script "/usr/bin/curl -s -o /dev/null -m 1 " & panelUrl & "health"
on error
  do shell script "cd " & quoted form of "$REPO" & " && GOOGLE_APPLICATION_CREDENTIALS=" & quoted form of "$KEY" & " " & quoted form of "$NODE" & " tool/admin/panel.js --port $PORT > \$HOME/Library/Logs/gu-admin-panel.log 2>&1 &"
  repeat 20 times
    delay 0.25
    try
      do shell script "/usr/bin/curl -s -o /dev/null -m 1 " & panelUrl & "health"
      exit repeat
    end try
  end repeat
end try
open location panelUrl
APPLESCRIPT

osacompile -o "$APP" "$SCRIPT"
rm -f "$SCRIPT"

# Simge: uygulama ikonu (assets/logo/app-icon-ios-1024.png).
ICONSET="$(mktemp -d)/panel.iconset"
mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z $s $s assets/logo/app-icon-ios-1024.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  d=$((s * 2)); sips -z $d $d assets/logo/app-icon-ios-1024.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/applet.icns"
# Simge değişince paket imzası yenilenir (yerel, ad-hoc).
xattr -cr "$APP"
codesign --force --deep --sign - "$APP"
rm -rf "$DEST"
ditto "$APP" "$DEST"
rm -rf "$WORK"
echo "kuruldu: $DEST"

#!/usr/bin/env bash
# Google Play yükleme anahtarını (upload key) bir kez kurar — yalnızca bu bilgisayarda.
#
#   bash tool/android/setup_release_key.sh
#
# 1. Anahtar deposunu REPO DIŞINDA oluşturur: ~/.secrets/gu-kulupler-upload.jks (varsa dokunmaz).
# 2. android/key.properties yazar (git dışı; .gitignore'da) → `flutter build appbundle --release`
#    bu anahtarla imzalar.
# Parola yalnızca bu terminalde sorulur; hiçbir yere gönderilmez, ekrana yazılmaz.
# ÖNEMLİ: .jks dosyasını ve parolayı yedekle (ör. parola yöneticisi). Kaybolursa Play'de anahtar
# sıfırlama başvurusu gerekir.
set -euo pipefail
cd "$(dirname "$0")/../.."

KEYSTORE="$HOME/.secrets/gu-kulupler-upload.jks"
ALIAS="upload"
PROPS="android/key.properties"

command -v keytool >/dev/null || { echo "keytool yok: Java 17 kur (ör. brew install openjdk@17)"; exit 1; }
mkdir -p "$(dirname "$KEYSTORE")"
chmod 700 "$(dirname "$KEYSTORE")"

read -r -s -p "Anahtar parolası (en az 6 karakter): " PW; echo
if [ ${#PW} -lt 6 ]; then echo "Parola en az 6 karakter olmalı."; exit 1; fi

if [ -f "$KEYSTORE" ]; then
  echo "▸ Anahtar deposu zaten var: $KEYSTORE (yeniden oluşturulmadı; parolası bu olmalı)"
  keytool -list -keystore "$KEYSTORE" -storepass "$PW" -alias "$ALIAS" >/dev/null \
    || { echo "Parola yanlış ya da '$ALIAS' anahtarı yok."; exit 1; }
else
  read -r -s -p "Parola (tekrar): " PW2; echo
  [ "$PW" = "$PW2" ] || { echo "Parolalar aynı değil."; exit 1; }
  keytool -genkeypair -v -keystore "$KEYSTORE" -storetype JKS -keyalg RSA -keysize 2048 \
    -validity 10000 -alias "$ALIAS" -storepass "$PW" -keypass "$PW" \
    -dname "CN=GU Kulupler, O=Gumushane Universitesi, C=TR" >/dev/null
  chmod 600 "$KEYSTORE"
  echo "▸ Anahtar deposu oluşturuldu: $KEYSTORE"
fi

umask 077
cat > "$PROPS" <<PROPS_EOF
storePassword=$PW
keyPassword=$PW
keyAlias=$ALIAS
storeFile=$KEYSTORE
PROPS_EOF
echo "▸ $PROPS yazıldı (git dışı)."
echo
echo "Sıradaki: flutter build appbundle --release"
echo "Çıktı   : build/app/outputs/bundle/release/app-release.aab → Play Console'a yükle."
echo "Yedekle : $KEYSTORE + parola."

#!/usr/bin/env bash
# Web uygulamasını Firebase Hosting'in /app/ yoluna hazırlar (firebase.json `hosting.predeploy`).
#
#   bash tool/build_web_hosting.sh        # release web derlemesi → hosting/public/app/
#
# `firebase deploy --only hosting` bunu kendiliğinden çalıştırır. Çıktı (hosting/public/app/) commit
# EDİLMEZ (.gitignore). Tanıtım / gizlilik / destek sayfaları kökte aynen kalır (App Store bağlantıları).
set -euo pipefail
cd "$(dirname "$0")/.."

OUT="hosting/public/app"
flutter build web --release --base-href /app/ --no-wasm-dry-run
rm -rf "$OUT"
mkdir -p "$OUT"
cp -R build/web/. "$OUT/"
echo "build_web_hosting: $(du -sh "$OUT" | cut -f1) → $OUT"

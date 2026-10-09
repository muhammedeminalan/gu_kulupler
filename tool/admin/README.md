# tool/admin — yönetici betikleri

Yalnızca **senin makinende**, **senin terminalinde** çalışır. Claude Code bu klasördeki betikleri çalıştırmadan önce her seferinde izin ister; gerçek projede ayrıca TTY ve proje-kimliği onayı gerekir (betik bunu zorlar).

## Süper admin atama (`set_superadmin.js`)

1. Firebase Console → Proje ayarları → **Hizmet hesapları** → "Yeni özel anahtar oluştur". JSON'u **repo dışında** sakla (ör. `~/.secrets/gu-kulupler-admin.json`). Repo içindeki yol reddedilir; `.gitignore` zaten `*-adminsdk-*.json` ve `serviceAccount*.json`'u yok sayar.
2. Bir kez: `cd tool/admin && npm install`
3. Kullanıcıyı önce uygulamadan **kayıt ol** ve e-postasını doğrula (Auth'ta var olmalı).
4. Önce bak, uygulama:
   ```bash
   export GOOGLE_APPLICATION_CREDENTIALS=~/.secrets/gu-kulupler-admin.json
   node tool/admin/set_superadmin.js --email sen@ogr.gumushane.edu.tr          # planı gösterir, değiştirmez
   node tool/admin/set_superadmin.js --email sen@ogr.gumushane.edu.tr --yes    # TTY'de proje kimliğini yazarak onayla
   node tool/admin/set_superadmin.js --list                                    # mevcut süper adminler
   node tool/admin/set_superadmin.js --email sen@… --revoke --yes              # geri al
   ```
5. Uygulamada çıkış yapıp tekrar gir (token yenilenir). Rules `request.auth.token.superadmin == true` olarak okur.

Emülatör için: `node tool/admin/set_superadmin.js --emulator --project demo-gu --email ayse.demir@ogr.gumushane.edu.tr --yes` (Auth emülatörü `127.0.0.1:9099`).

**Neden Firestore alanı değil?** İstemci kendi belgesini yazabildiği için alan tabanlı yetki yükseltilebilir; custom claim yalnızca Admin SDK ile yazılır (D-28).

# tool/admin — yönetici betikleri

Yalnızca **senin makinende**, **senin terminalinde** çalışır. Claude Code bu klasördeki betikleri çalıştırmadan önce her seferinde izin ister; gerçek projede ayrıca TTY ve proje-kimliği onayı gerekir (betik bunu zorlar).

## Süper admin atama (`set_superadmin.js`)

1. Firebase Console → Proje ayarları → **Hizmet hesapları** → "Yeni özel anahtar oluştur". JSON'u **repo dışında** sakla (ör. `~/.secrets/gu-kulupler-admin.json`). Repo içindeki yol reddedilir; `.gitignore` zaten `*-adminsdk-*.json` ve `serviceAccount*.json`'u yok sayar.
2. Bir kez: `cd tool/admin && npm ci --ignore-scripts` — sürümler commit edilmiş `package-lock.json`'dan birebir (bütünlük karmasıyla) kurulur, kurulum betiği çalışmaz (T-45 · S4-02). Bağımlılık güncellemesi bilinçli yapılır: `npm install --package-lock-only --ignore-scripts` → `npm audit` → kilit dosyası commit edilir (CD-40).
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

**Süper adminin askısı = claim geri alımı.** Uygulamada bir süper adminin hesabını askıya almak (ADM-05) yetkisini KALDIRMAZ — Rules yetkiyi yalnızca jetondan okur (D-28). Önce `--revoke`, sonra askı. Süper admin kendi hesabını askıya alamaz / askısını kaldıramaz (Rules `uid != request.auth.uid`; güvenlik incelemesi T-37).

**Geri alma ne zaman etkili olur?** Rules yetkiyi kimlik jetonundan okur. `--revoke` sonrası: uygulama öne geldiğinde (en çok 10 dakikada bir — `SessionViewModel.onAppResumed`) ya da süper admin ekranı `permissionDenied` aldığında jeton sunucudan yenilenir; en geç jetonun kendi yenilenmesinde (≤ 1 saat) eski yetki biter. Acil durumda Console'dan hesabı **devre dışı bırak** (oturum hemen düşer, TST-22) — hesap silinmez.

## Ortak kalıp (T-37 betikleri)

`set_advisor.js`, `send_system_notification.js` ve `finish_account_deletion.js` `set_superadmin.js` ile aynı korumaları taşır (kod: `lib/admin_cli.js`, `lib/admin_runtime.js`):

- **Kuru çalıştırma varsayılandır:** plan / yazımlar basılır, hiçbir şey yazılmaz. `--yes` uygular.
- **Gerçek proje:** anahtar `--key` ya da `GOOGLE_APPLICATION_CREDENTIALS`, **repo dışında** (repo içi yol reddedilir); `--project` verilirse anahtardaki projeyle aynı olmalı; yazım yalnızca etkileşimli terminalde (TTY) ve **proje kimliği yazılarak** onaylanır (TTY yoksa çıkış 3).
- **Emülatör:** `--emulator --project demo-gu-kulupler` (proje kimliği `demo-` ile başlamalı; `FIRESTORE_EMULATOR_HOST` / `FIREBASE_AUTH_EMULATOR_HOST` yerel olmalı — varsayılan `127.0.0.1:8080` / `:9099`).
- **Silme yok (D-10):** betikler yalnızca `set` / `update` yazar; belge, dosya ya da Auth kimliği silinmez. Sayaçlar asıl yazımla aynı batch / transaction'dadır.
- Saf planlayıcılar `lib/*.js`'dedir ve `firebase-admin`'i yüklemez; öz-test: `node --test tool/test/admin_scripts.test.js` (betik çalıştırılmaz).

Çıkış kodları: 0 tamam · 1 hata · 2 kullanım / koruma reddi · 3 onay yok.

## Danışman hesabı bağlama (`set_advisor.js` — K-A, M13)

Uygulamadaki `AdminRepository.setAdvisor` ile **aynı belgeleri** yazar (tek transaction): `memberships/{clubId}_{uid}` → `active` + `advisor`, iletişim belgesi (hesap e-postası), `clubs/{clubId}.advisor.userId`. `memberCount` değişmez (danışman sayılmaz). Kulübün danışman kaydı (ad + unvan) önce ADM-03'te girilmiş olmalı; danışmanın hesabı etkin olmalı.

```bash
node tool/admin/set_advisor.js --club c01 --email danisman@gumushane.edu.tr            # plan
node tool/admin/set_advisor.js --club c01 --email danisman@gumushane.edu.tr --yes      # bağla
node tool/admin/set_advisor.js --club c01 --email danisman@gumushane.edu.tr --remove --yes   # bağı kaldır (üyelik left)
```

Başka bir hesap bağlıysa önce `--remove`. Hedefin etkin / bekleyen başka bir üyeliği varsa reddedilir. **Bayat bağ** (danışman hesabını sildi; üyelik zaten `left` ama kulüp hâlâ onu gösteriyor): `--remove` yalnızca kulübün `advisor.userId` bağını ayırır — uygulamada ADM-03'ün kaldır eylemi de aynısını yapar.

## Sistem bildirimi (`send_system_notification.js` — PLAN §21.1 #14b)

Mod C'de `system` türünü yalnızca bu betik yazar (istemci dalı Rules'ta kapalı). Metin uygulamanın ARB'sindedir; betik yalnızca anahtarı yazar.

```bash
node tool/admin/send_system_notification.js --text-key maintenance --all            # alıcı sayısı + örnek
node tool/admin/send_system_notification.js --text-key maintenance --all --yes      # etkin, silinmemiş tüm hesaplar
node tool/admin/send_system_notification.js --text-key welcome --email sen@ogr.gumushane.edu.tr --yes
```

`--text-key`: `welcome` | `maintenance`. Belge kimliği `system_{olay anahtarı}_{uid}` (koşum başına tek anahtar).

## Serbest metinli push (`send_push.js`)

Yazdığın başlık ve metni **telefonlara push** olarak gönderir (FCM, Admin SDK). Uygulama içi bildirim kutusuna yazmaz; kutuya da düşsün istiyorsan hazır metinler için `send_system_notification.js` kullan. Jetonlar `users/{uid}/private/account.fcmTokens`'tan okunur: uygulamaya giriş yapıp bildirim izni vermemiş kullanıcıya gitmez. Sınırlar: başlık 60, metin 300 karakter. Emülatörde çalışmaz.

```bash
node tool/admin/send_push.js --title "GÜ Kulüpler" --body "Batu, Kerime'ye APK'yı at, denesin." --all            # kuru: hesap ve cihaz sayısı
node tool/admin/send_push.js --title "GÜ Kulüpler" --body "Batu, Kerime'ye APK'yı at, denesin." --all --yes      # gönder
node tool/admin/send_push.js --title "GÜ Kulüpler" --body "Merhaba" --email kisi@ogr.gumushane.edu.tr --yes       # tek kişi
```

## Demo içerik (`seed_demo_content.js`)

Gerçek projeye demo içerik yazar (App Store incelemesi / tanıtım): `tool/seed/demo-data.json`'daki kulüpler, üyelikler, gönderiler, yorumlar, etkinlikler, katılımlar ve demo profiller, tarihleri bugüne kaydırılarak (emülatör tohumlayıcısıyla aynı dönüşüm, `tool/seed/lib/convert.js`). Kulüp logo / kapak ve gönderi görselleri yer tutucu PNG olarak Storage'a yüklenir.

- **Yazılmaz:** bildirim ve şikayet (Functions gerçek cihazlara push gönderirdi), silinmiş hesap dizisi, destek talepleri.
- **Auth kullanıcısı açılmaz:** demo profiller içerik sahibi olarak görünür, onlarla giriş yapılamaz. İnceleme hesabını uygulamadan kendin aç; açık kulüplere katılabilir.
- **Çift tohum yok:** demo kulüplerinden biri zaten varsa hiçbir şey yazmadan durur.

```bash
node tool/admin/seed_demo_content.js          # kuru: belge ve görsel sayıları
node tool/admin/seed_demo_content.js --yes    # yaz (proje kimliği sorulur)
```

## Yarım kalan hesap silme temizliği (`finish_account_deletion.js` — W-91)

> **T-42 (Mod F, CD-165) sonrası bu betik YEDEKTİR.** Functions yüklendikten sonra `finishAccountDeletions` zamanlanmış fonksiyonu her gün 03:30'da (Europe/Istanbul) `deletedAt`'i son 1–72 saat içindeki silinmiş hesapları aynı planlayıcıyla (`functions/src/lib/account_cleanup.ts` — bu dizindeki `lib/account_cleanup.js`'in TS portu; parite testi `functions/test/account_cleanup.test.ts`) kendiliğinden tamamlar (koşu başına ≤ 50). Betiği yalnızca şu durumlarda çalıştır: 72 saatten eski hesap, etkin başkan uyarısı (aşağıda) sonrası yeniden koşum, Functions henüz yüklenmemiş / devre dışı. Fonksiyon ve betik (T-45, `lib/account_cleanup_runner.js`) aynı ilkeyle yazar: **iki geçiş** (önce tüm hesapların kritik temizliği — hesap belgesi, katılım, üyelik, iletişim — sonra kişisel belgeler), **sayfalı okuma** (kişisel belgeler ve `--all-deleted` listesi `documentId()` sırasıyla sayfa sayfa; kuru çalıştırma kişisel belgeleri yalnızca sayar), kişisel yazımlar **≤ 450'lik gruplu batch** ve her yazım okunduğu andaki `lastUpdateTime` **önkoşuluyla** (kritik birimde ilk yazım). Araya giren yazımda (fonksiyonun ya da istemcinin eşzamanlı temizliği) batch bütünüyle reddedilir, yarım yazım ve çift sayaç düşüşü olmaz; çıktı `! … önkoşul` der → betiği yeniden çalıştır. Yine de fonksiyonun koşu saatinde (03:30 civarı) çalıştırmamak reddi azaltır.

Hesap silme (SET-03) istemcide en iyi çabayla koşar: `markDeleted` sonrası parçalar yarım kalırsa (ağ, Rules reddi) ve kullanıcı hiç geri dönmezse üyelik anlık görüntüsü / iletişim belgesi / açık katılımı kalabilir. Betik `users.status == 'deleted'` hesaplar için T-29 dizisinin eşdeğerini tamamlar (`lib/account_cleanup.js`):

- açık katılım → `cancelled` + etkinlik sayacı −1 (biten etkinliğin kaydı korunur — W-80);
- üyelik (M14): etkin üye / kurul → `left` + `memberCount −1`; bekleyen → `cancelled`; danışman → `left` (+ kulübün `advisor.userId` bağı ayrılır; üyelik uygulamada zaten `left` olduysa da); hepsinde `applicant` anonim, iletişim belgesi boş;
- hesap belgesindeki e-posta / FCM jetonları boşalır; bildirim, kayıtlı gönderi ve engeller soft delete;
- **etkin başkan üyeliği kapatılmaz:** çıktıdaki `! … etkin BAŞKAN` uyarısında önce uygulamada ADM-03 → **Başkan ata** (W-90; silinmiş eski başkan `board` olur), sonra betiği yeniden çalıştır — o üyelik `left` olur (sayaç −1).

```bash
node tool/admin/finish_account_deletion.js --all-deleted          # tüm silinmiş hesapların planı
node tool/admin/finish_account_deletion.js --uid <uid> --yes      # tek hesap
```

Yeniden çalıştırmak güvenlidir (idempotent): yalnızca nihai olmayan durumlar ve boşalmamış alanlar yazılır. Auth kimliği kalır (Q-11).

## Zararlı görsel yordamı (W-74 — betik YOK)

Gizlenen / kaldırılan gönderinin görseli Storage'da kalır; jetonlu indirme adresi oturumsuz açılabilir (rules-spec §9.11d). Otomatik dosya silme aracı **yazılmadı**: D-10 (hard delete yok) ve `check_no_hard_delete` ile çelişir, ayrıca insan kararı ister. Yordam:

1. **İçeriği gizle:** uygulamada ADM-04 → şikayeti **İçeriği kaldır** ile çöz (`resolveReports(removed)` — gönderi / yorum aynı batch'te gizlenir, şikayetçilere `report_resolved`).
2. **Eski bağlantıları öldür:** Firebase Console → Storage → dosya (`posts/{postId}/…` ya da `clubs/{clubId}/…`) → *File location* → **Erişim jetonunu iptal et** (revoke / yeni jeton). Dosya kalır, eski indirme adresleri çalışmaz. Yükleyen: dosyanın özel üst verisi `uploaderId` (gerekirse DLG-30 ile askıya al).
3. **Yalnızca yasal zorunluluk ya da açıkça zararlı içerikte** dosyayı Console'dan **elle** sil ve `docs/decisions.md`'ye (tarih, yol, gerekçe) kaydet — D-10'un tek istisnası; betik ya da uygulama bunu yapmaz.

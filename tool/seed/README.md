# tool/seed — demo verisi

`demo-data.json` Claude Design prototipinin **kurgusal** veri kümesidir (hiçbir kayıt gerçek kişiye ait değildir). Amaç: **yalnızca yerel Firebase emülatörünü** gerçekçi veriyle doldurmak ve ekran/test örneklemesi. Gerçek projeye **asla** yazılmaz.

| Alan | İçerik | Not |
|---|---|---|
| `meta.today` | göreli tarihlerin referans günü (`2026-10-07T21:00Z` = Istanbul 8 Ekim 00:00) | `*_rel_days` = `today`'e göre gün farkı; tohumlayıcı her anı referans günden bugüne **tam gün** kaydırır (saat korunur) |
| `meta.demoPassword` | demo hesapların yerel parolası (T-10'da eklendi; PLAN §9.12) | **tek kaynak**: tohumlayıcı ve DebugMenu `signInAs` bu alanı okur; prototipteki `DEMO_PASSWORD` ile aynıdır, sır değildir |
| `categories`(8) `interests`(16) `departments`(24) `places`(10) | referans listeleri | uygulamadaki sabit/katalog verisiyle eşleşir (`domain-model.md`) |
| `users`(226) `settings`(226) | kullanıcılar ve bildirim tercihleri | e-postalar sahte `@ogr.gumushane.edu.tr`; demo hesaplar `u_ayse, u_mehmet, u_zeynep, u_burak, u_elif, u_admin` |
| `clubs`(14) `memberships`(515) | kulüpler, üyelik/başvurular | `memberships` anahtarı `<clubId>_<userId>` |
| `posts`(36) `comments`(41) `saved` | akış | `likes` dizileri **sayaç + oy belgesine** çevrilir |
| `events`(22) `rsvps`(944) | etkinlikler, katılım, bilet kodu | `ticketCode` bilet; `scannedAt` yoklama |
| `notifications`(40) `reports`(8) `activity`(222) `dailyAnnouncementCount` | bildirim, şikayet, faaliyet, günlük duyuru sayacı | bildirimler T-25 şemasına dönüşür (aşağıda); örneği olmayan 4 tür `demo-notifications.json`'da (+5) |

## Kurallar (tohumlayıcıyı yazan task: T-10, genişleme: T-45)
1. **Prototip biçimi ≠ Firestore modeli.** Tohumlayıcı (`tool/seed/seed_emulator.js`) bu JSON'u `docs/domain-model.md` şemasına **dönüştürür**: düz koleksiyonlar, soft delete alanları (`deletedAt/deletedBy/...`), sayaçlar (`memberCount` vb. üyelik belgelerinden tutarlı hesaplanır), iletişim bilgisi ve başvuru notu (CD-137) `memberships/{id}/private/contact` alt belgesine, `createdAt/updatedAt` sunucu biçimi.
2. **Yalnızca emülatör:** `FIRESTORE_EMULATOR_HOST` ve `FIREBASE_AUTH_EMULATOR_HOST` tanımlı değilse betik **durur**; adresler yerel (`127.0.0.1` / `localhost`) olmalı ve proje kimliği `demo-` ile başlamalıdır. Gerçek proje kimliği görürse hata verir (çıkış 2, hiçbir şey yazılmaz).
3. Auth kullanıcıları emülatörde sabit, yalnızca-yerel bir parolayla oluşturulur: `demo-data.json#meta.demoPassword` (tek kaynak; betikte ayrı parola sabiti yoktur; sır değildir, gerçek hesaplara bağlı değildir). UI'da "demo hesap" bölümü **uygulanmaz** (K-02).
4. Veri değişirse bu dosya `design/` gibi salt okunur sayılır; yeni senaryo için ayrı dosya ekle (`tool/seed/*.json`). (Tek istisna: T-10'da eklenen `meta.demoPassword` alanı; `PACK_MANIFEST.json` özeti aynı commit'te güncellendi.)
5. **Hard delete yok:** tohumlayıcı temizlik için belge silmez; emülatörü yeniden başlatır (`firebase emulators:start --import … ` / veri dizinini yenile).

## Kullanım (`seed_emulator.js`, T-10)

Bağımlılık yoktur (Node ≥ 20, `npm install` gerekmez): betik emülatörlerin yerel REST uçlarına yazar.

```bash
# 1) Tek seferlik doğrulama: emülatörü aç → tohumla → sayıları karşılaştır → kapat
firebase emulators:exec --only auth,firestore --project demo-gu-kulupler "node tool/seed/seed_emulator.js --check"

# 2) Geliştirme: emülatör açık dursun (ayrı terminal), sonra tohumla
firebase emulators:start --only auth,firestore,storage --project demo-gu-kulupler
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
FIREBASE_STORAGE_EMULATOR_HOST=127.0.0.1:9199 node tool/seed/seed_emulator.js --project demo-gu-kulupler

# 3) Ağa çıkmadan dönüşümü ve sayıları gör
node tool/seed/seed_emulator.js --dry-run
```

| Seçenek | Anlamı |
|---|---|
| `--project <id>` | proje kimliği; `demo-` ile başlamalı (`emulators:exec` `GCLOUD_PROJECT` verir, o zaman gerekmez) |
| `--check` | yazdıktan sonra emülatördeki belge / Auth kullanıcısı / dosya sayılarını `demo-data.json` ile karşılaştırır; fark = çıkış 1. **Boş emülatör bekler.** |
| `--now <ISO>` | "şimdi" (varsayılan: çalıştırma anı). Zaman kuralı (tek yer: `convert.js` `dayShiftMs`): her an `ISO + D`, D = `meta.today`'in Istanbul gününden `now`'ın Istanbul gününe **tam gün** farkı — saat korunur (demo'da "yarın 18:00" olan etkinlik her gün yeniden tohumlandığında yine yarın 18:00'dedir); duyuru sayacının günü bugündür; `*_rel_days` yazılmaz. Uzun açık kalan emülatörde veri eskir: `bash tool/dev.sh --reseed` |
| `--bucket <ad>` | Storage kovası (varsayılan `<proje>.firebasestorage.app`) |
| `--dry-run` | yalnızca dönüştürür ve doğrular |

- **Ne yazar:** 17 koleksiyon / alt koleksiyon, **3 297 belge** (users 226 · private/account 226 · blocks 1 · clubs 14 · memberships 515 · private/contact 515 · posts 36 · votes 250 · comments 41 · events 22 · rsvps 944 · notifications 45 (40 + `demo-notifications.json` 5) · reports 11 · activity 222 · settings 226 · savedPosts 2 · announcementCounters 1) + **5 destek talebi** (`supportTickets/{ticketNo}`, `demo-support.json`; T-28 — açık / kapalı karışık, eksiz; süper admin destek kutusu T-40) + **1 silinmiş (anonim) hesap** (`demo-deleted.json`; T-29 — hesap silme dizisinin sonucu: `users/u_deleted` "Silinmiş kullanıcı" + `status: deleted` + soft delete alanları, boş `private/account`, `c01` üyeliği `left` + anonim `applicant` + boş contact, eski gönderisi `p_del01` ve yorumu `cm_del01` kalır; 6 belge, `--check` ilgili koleksiyon sayımlarına eklenir) + **227 Auth kullanıcısı** (226 + `u_deleted`: Auth kimliği silinmez — Q-11; demo parolasıyla giriş denemesi oturum çözümünde kapatılır, TST-22) (`uid = id`, e-posta doğrulanmış; `u_admin` → `superadmin: true` claim'i) + Storage emülatörü açıksa **17 yer tutucu görsel**: 15 gönderi görseli (`posts/{postId}/<damga>_<16 hex>.png`) + `c03` kulübünün logosu ve kapağı (T-36; `clubs/c03/<damga>_<16 hex>.png`, belgede `logoPath` / `coverPath`; diğer kulüpler şablon kapakla kalır), üst veri `clubId` + `uploaderId` (gönderinin yazarı / kulübün başkanı). `categories/interests/departments/places` yazılmaz; Dart `StaticTables` ile karşılaştırılır (fark = betik durur).
- **Yönetici geçmişi (T-30, `demo-management.json`; 9 belge, `--check` ilgili koleksiyon sayımlarına eklenir):** `c01`'de `u_elif` (yönetim kurulu) kararları — `u002` başvurusu **reddedilmiş** (`quota`, ret notu, `retryAfter` = karar + 7 gün, iletişim belgesinde başvuru notu, günlük `application_rejected`), `u003` başvurusunun onayı **30 sn içinde geri alınmış** (üyelik yeniden `pending`, karar alanları boş; günlük `application_approved` kalır — kabul edilen sınırlama, rules-spec §9); başkanın `u_elif`'i yönetim kuruluna aldığı **rol günlüğü** (`role_changed`); **yan sayaç belgeleri** `clubs/c01/private/counter` (son yönetici geçişi: `u154` çıkarması) ve `events/e18/private/counter` (yoklaması alınmış geçmiş etkinlik — W-64). Günlük kimlikleri `FirestoreIds.managerActivity` / `roleActivity` biçimindedir; sayaçlar değişmez. Bekleyen başvurular, çıkarılmış üye ve yoklama alınmış etkinlikler `demo-data.json`'dadır. Yazmadan önce `validateManagement` (aktör kulübün etkin yöneticisi, işaretçi kendi kulübünün / etkinliğinin belgesini gösterir).
- **Bildirimler (T-25, `docs/plans/T-25.md` §6 a–b):** kimlik `{type}_{eventKey}_{userId}` (`eventKey` = `seed` + demo kimliğinin harf / rakamları, `0` ile 20 karaktere — yeniden tohumlama aynı belgeye yazar; tek seferlik olaylarda dağıtıcıyla aynı: `announcement` → postId, `event_cancelled` → eventId, `application_received` → `{clubId}_{applicantId}_{priorCount}` — CD-148 (9)), hatırlatıcı `event_reminder_{eventId}_{userId}` (cihazın `createSelf`'i ikinci belge açmaz); `refs` yalnızca türün zorunluları (eksik `clubId` etkinlikten), `read` bool; metin / aktör alanı yok. 13 türün hepsi, okunmuş ve okunmamış örnekleriyle. Biçim yazmadan önce doğrulanır (`validate`).
- **Dönüşüm kuralları:** `docs/PLAN.md §9.12`; kod `tool/seed/lib/convert.js`. Aynı kuralların Dart kopyası `packages/gu_data/test/fixtures/demo_data.dart`'tır — biri değişirse ikisi birlikte değişir. **İstisna (T-25, CD-148):** tam gün kayması, bildirim kimliği / `refs` dönüşümü, `demo-notifications.json` ve `demo-support.json` (T-28; `COLLECTIONS` 17'nin dışında) yalnızca emülatör tohumlayıcısındadır; Dart fixture'ı sabit saatte (`meta.today`) ve demo kimlikleriyle (`n001`…) kalır (birim testlerin girdisi). `nameLower` için `tool/seed/lib/tr_lower.js` (CD-11).
- **Yazmadan önce doğrulama (hata = çıkış 1, yazım yok):** başkan üyeliği, `memberCount`, etkinlik sayaçları (`goingCount` = going + attended, CD-130), `likeCount`, `commentCount`, bilet kodu deseni, şikayet kimliği, duyuru sayacı ≤ `Limits.announcementDailyLimit`; T-19 içerik biçimi (Security Rules ile aynı değişmezler): başlık yalnızca duyuruda, anket yalnızca ankette (seçenek kimlikleri `o1…oN`), `pushSent` yalnızca duyuruda, görsel yolu `posts/{postId}/…`, `posts.pinned` ↔ `clubs.pinnedPostId`, oyun seçeneği ankette var, yorum / kayıt `clubId` = gönderinin kulübü, sayaç kimliği ↔ `day`.
- **Yeniden koşum:** belgeler aynı kimlikle üzerine yazılır, Auth kullanıcıları güncellenir; hiçbir şey silinmez (madde 5). Gönderi görselleri her koşumda yeni adla yüklenir (eskiler yetim kalır). Temiz başlangıç = emülatörü yeniden başlat.
- **Storage:** `FIREBASE_STORAGE_EMULATOR_HOST` yoksa görseller atlanır (uyarı); belgelerdeki `images[].path` yine yazılır.
- **Uygulama tarafı:** veri `demo-gu-kulupler` proje ad alanına yazılır (emülatör verisi proje kimliğine göre ayrılır). Uygulama `flutter run --dart-define=ENV=emulator` ile aynı kimliğe bağlanır: `AppEnvironment.configure()` (`lib/core/env/app_environment.dart`) `gu-emulator` adlı ikinci Firebase uygulamasını `demo-gu-kulupler` kimliği ve `demo-gu-kulupler.firebasestorage.app` kovasıyla açar, Auth/Firestore/Storage'ı `firebase.json` portlarına bağlar (Android emülatörü `10.0.2.2`, iOS simülatörü `localhost`; gerçek cihaz: `--dart-define=EMULATOR_HOST=<LAN-IP>`). `EMULATOR_HOST` yalnızca `localhost`, `.local` adı ya da özel ağ IPv4 adresi olabilir; emülatör uygulaması gerçek projenin API anahtarını taşımaz; release derlemesi `ENV=emulator` ile açılmaz (CD-131).
- Öz-test: `node --test tool/test/seed_emulator.test.js` (korumalar + dönüşüm; emülatör gerekmez).

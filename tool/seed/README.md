# tool/seed — demo verisi

`demo-data.json` Claude Design prototipinin **kurgusal** veri kümesidir (hiçbir kayıt gerçek kişiye ait değildir). Amaç: **yalnızca yerel Firebase emülatörünü** gerçekçi veriyle doldurmak ve ekran/test örneklemesi. Gerçek projeye **asla** yazılmaz.

| Alan | İçerik | Not |
|---|---|---|
| `meta.today` | göreli tarihlerin referans günü (`2026-10-07T21:00Z`) | `*_rel_days` = `today`'e göre gün farkı; tohumlayıcı bugüne kaydırır |
| `meta.demoPassword` | demo hesapların yerel parolası (T-10'da eklendi; PLAN §9.12) | **tek kaynak**: tohumlayıcı ve DebugMenu `signInAs` bu alanı okur; prototipteki `DEMO_PASSWORD` ile aynıdır, sır değildir |
| `categories`(8) `interests`(16) `departments`(24) `places`(10) | referans listeleri | uygulamadaki sabit/katalog verisiyle eşleşir (`domain-model.md`) |
| `users`(226) `settings`(226) | kullanıcılar ve bildirim tercihleri | e-postalar sahte `@ogr.gumushane.edu.tr`; demo hesaplar `u_ayse, u_mehmet, u_zeynep, u_burak, u_elif, u_admin` |
| `clubs`(14) `memberships`(515) | kulüpler, üyelik/başvurular | `memberships` anahtarı `<clubId>_<userId>` |
| `posts`(36) `comments`(41) `saved` | akış | `likes` dizileri **sayaç + oy belgesine** çevrilir |
| `events`(22) `rsvps`(944) | etkinlikler, katılım, bilet kodu | `ticketCode` bilet; `scannedAt` yoklama |
| `notifications`(40) `reports`(8) `activity`(222) `dailyAnnouncementCount` | bildirim, şikayet, faaliyet, günlük duyuru sayacı | |

## Kurallar (tohumlayıcıyı yazan task: T-10, genişleme: T-45)
1. **Prototip biçimi ≠ Firestore modeli.** Tohumlayıcı (`tool/seed/seed_emulator.js`) bu JSON'u `docs/domain-model.md` şemasına **dönüştürür**: düz koleksiyonlar, soft delete alanları (`deletedAt/deletedBy/...`), sayaçlar (`memberCount` vb. üyelik belgelerinden tutarlı hesaplanır), iletişim bilgisi `memberships/{id}/private/contact` alt belgesine, `createdAt/updatedAt` sunucu biçimi.
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
| `--now <ISO>` | "şimdi" (varsayılan: çalıştırma anı). Zaman kuralı: her an `ISO + (now − meta.today)`; `*_rel_days` yazılmaz |
| `--bucket <ad>` | Storage kovası (varsayılan `<proje>.firebasestorage.app`) |
| `--dry-run` | yalnızca dönüştürür ve doğrular |

- **Ne yazar:** 17 koleksiyon / alt koleksiyon, **3 292 belge** (users 226 · private/account 226 · blocks 1 · clubs 14 · memberships 515 · private/contact 515 · posts 36 · votes 250 · comments 41 · events 22 · rsvps 944 · notifications 40 · reports 11 · activity 222 · settings 226 · savedPosts 2 · announcementCounters 1) + **226 Auth kullanıcısı** (`uid = id`, e-posta doğrulanmış; `u_admin` → `superadmin: true` claim'i) + Storage emülatörü açıksa **15 yer tutucu görsel** (`posts/{postId}/<damga>_<16 hex>.png`, `metadata.clubId`). `categories/interests/departments/places` yazılmaz; Dart `StaticTables` ile karşılaştırılır (fark = betik durur).
- **Dönüşüm kuralları:** `docs/PLAN.md §9.12`; kod `tool/seed/lib/convert.js`. Aynı kuralların Dart kopyası `packages/gu_data/test/fixtures/demo_data.dart`'tır — biri değişirse ikisi birlikte değişir. `nameLower` için `tool/seed/lib/tr_lower.js` (CD-11).
- **Yazmadan önce doğrulama (hata = çıkış 1, yazım yok):** başkan üyeliği, `memberCount`, etkinlik sayaçları (`goingCount` = going + attended, CD-130), `likeCount`, `commentCount`, bilet kodu deseni, şikayet kimliği, duyuru sayacı ≤ `Limits.announcementDailyLimit`.
- **Yeniden koşum:** belgeler aynı kimlikle üzerine yazılır, Auth kullanıcıları güncellenir; hiçbir şey silinmez (madde 5). Gönderi görselleri her koşumda yeni adla yüklenir (eskiler yetim kalır). Temiz başlangıç = emülatörü yeniden başlat.
- **Storage:** `FIREBASE_STORAGE_EMULATOR_HOST` yoksa görseller atlanır (uyarı); belgelerdeki `images[].path` yine yazılır.
- **Uygulama tarafı:** veri `demo-gu-kulupler` proje ad alanına yazılır (emülatör verisi proje kimliğine göre ayrılır). Uygulama `flutter run --dart-define=ENV=emulator` ile aynı kimliğe bağlanır: `AppEnvironment.configure()` (`lib/core/env/app_environment.dart`) `gu-emulator` adlı ikinci Firebase uygulamasını `demo-gu-kulupler` kimliği ve `demo-gu-kulupler.firebasestorage.app` kovasıyla açar, Auth/Firestore/Storage'ı `firebase.json` portlarına bağlar (Android emülatörü `10.0.2.2`, iOS simülatörü `localhost`; gerçek cihaz: `--dart-define=EMULATOR_HOST=<LAN-IP>`). `EMULATOR_HOST` yalnızca `localhost`, `.local` adı ya da özel ağ IPv4 adresi olabilir; emülatör uygulaması gerçek projenin API anahtarını taşımaz; release derlemesi `ENV=emulator` ile açılmaz (CD-131).
- Öz-test: `node --test tool/test/seed_emulator.test.js` (korumalar + dönüşüm; emülatör gerekmez).

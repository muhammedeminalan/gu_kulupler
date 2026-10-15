# T-45 · Güvenlik gözden geçirme

> Dal `feat/T-45-guvenlik` · plan `docs/plans/T-45.md` · tarih 2026-10-15. Kaynaklar: rules-spec (tamamı, §9), borçlar W-59, W-61, W-86, W-88, W-105, W-106.
> 2. iş akışı (2026-10-16): kullanıcı kararları (§7.1) uygulandı — kontrast, şikayet kotası (K grubu), push döngü freni ve kalan açıklar (F grubu); bütünleme. Kararlar: `docs/decisions.md` H-12 – H-15, CD-168.

## 1. Özet

| | |
|---|---|
| **Kapsam** | Firestore Rules (tam matris + erişim bütçesi) · Storage Rules + Cloud Functions · istemci / platform (release ikilisi, manifest / plist, yerel depo, günlük) · gizli bilgi + bağımlılık · kötüye kullanım / kota / spam |
| **Yöntem** | 1. iş akışı: 5 paralel denetim → her bulguya iki bağımsız doğrulayıcı (saldırı merceği: yol gerçekten sömürülebilir mi; sözleşme merceği: kabul edilmiş sınırlama mı) → 3 paralel düzeltme grubu (R Rules, F Functions, P istemci / platform). Her düzeltme önce kırmızı, sonra yeşil testle. 2. iş akışı: kullanıcı kararları (§7) + bu rapor + bütünleme |
| **Sonuç** | **16 bulgu → 13 düzeltildi, 3 elendi. Kritik bulgu yok.** Önem: 1 yüksek, 6 orta, 9 düşük. Düzeltilenler: 1 yüksek, 4 orta, 8 düşük. 2. iş akışında ayrıca: şikayet kotası (kullanıcı kararı 3), push döngü freni (S2-01), `send_push` tür süzgeci makbuzdan önce, `blocks` create `exists(blockedId)`, admin temizlik betiğinin sayfalanması, kontrast token'ı (kullanıcı kararı 1). Denetimler ayrıca **40 aday**ı bulgu saymadı (kabul edilmiş, sömürülemez ya da kota kararı kullanıcıya ait): Rules 10, Storage + Functions 7, istemci 10, gizli bilgi 4, kötüye kullanım 9 |
| **Test (1. iş akışı sonu)** | Rules 37 dosya, **5225 / 5225**, `todo` yok (başlangıç 5146 + 2 todo; yeni Rules testlerinden 41'i düzeltmeden önce kırmızıydı) · `gu_data` 3275 / 3275 · Dart ~2 700 ilgili test · `tool/test` 62 / 62 · Functions 12 + 1 suite, 59 + 4 test · `check_rules_parity`, `check_no_hard_delete`, hardcode, katman sınırı, `check_arb_parity --strict --unused` temiz · golden değişmedi |
| **Test (2. iş akışı sonu — kapıdan önceki son koşular)** | Rules **39 dosya, 5310 / 5310** (K grubunun yeni Rules testlerinden 36'sı eski kurallara karşı kırmızıydı) · `gu_data` **3291 / 3291** (gerçek repository'nin 13 yeni testi eski uygulamaya karşı kırmızıydı) · kök Dart **4627 / 4627**, `gu_ui` **1227 / 1227** (`GU_MATRIX=fast`) · Functions **12 + 1 suite, 72 + 4 test** (5 birim + 6 emülatör testi önce kırmızı) · `tool/test` **67 / 67** (admin temizlik koşucusunun 5 testi önce kırmızı) · `check_rules_parity`, ARB `--strict --unused`, hardcode, katman sınırı, hard-delete temiz · golden: **114** açık tema (kontrast; koyu 0, yeni golden yok). Kapı: `bash tool/quality_gate.sh --task T-45` tam mod — bu rapor kapıdan önce yazıldı; sonuç task kaydında (`node tool/progress.js done T-45 --gate …`) |

## 2. Bulgular

### 2.1 Düzeltilen 13 bulgu

| ID | Önem | Alan | Sorun | Saldırı / etki | Düzeltme | Test |
|---|---|---|---|---|---|---|
| **A5-01** + F3 | yüksek (+ düşük) | Rules `notifications` · `event_reminder` | Dal yalnızca `userId == uid()`, dolu `refs` ve kimlik eşitliğine bakıyordu; etkinlik / katılım aranmıyordu. CD-44 kabulü T-42 tetikleyicisinden önce verilmişti | Yönetici olmayan her etkin hesap uydurma `eventId`'lerle sınırsız belge yazar (PoC: kulüpsüz öğrenci, 450 belge tek batch). Her belge 1 işlev çağrısı + 2 kalıcı `pushReceipts` yazımı (D-10, silinmez) | `reminderRsvpOk`: yazarın kendi `rsvps/{eventId}_{uid}` kaydı var, `userId` / `eventId` / `clubId` eşit. 2 erişim yolu. Durum aranmaz (iptal sonrası dokunuş yazar) | `notifications.json`, `notifications.test.js`, `account_deletion.test.js`, `repository_payloads.json` |
| **F1** | orta | Rules `clubs` | `social.email`, `social.web`, `coverSeed` sınırsız; süper admin dallarında `iconName`, `advisor.title` de | Herhangi bir yönetim kurulu üyesi herkese açık kulüp belgesini ~1 MB'a şişirir (PoC: 900 754 bayt); CLB-01 tüm kulüpleri tek seferde çeker | Yeni `Limits`: `socialEmailMax` 254, `socialWebMax` 200, `coverSeedMax` 64, `iconNameMax` 40, `advisorTitleMax` 60; `FieldValidators` `tooLong`; repository doğrulayıcıları | `memberships_manager.test.js`, `admin.test.js` (N geçer / N + 1 ret), `field_validators_test.dart`, 2 repository testi |
| **F2** | orta | İstemci AUT-05 | `displayName` yazılamazsa ad e-postanın yerel kısmından türetiliyordu (D-29 ihlali) | Kayıttan hemen sonraki ağ hatasında öğrenci numarası / ad.soyad herkese açık `users.name` ve `memberships.applicant.name`'e gider; 2 izinli alan adıyla tam e-posta yeniden kurulur | Sıra: görünen ad → cihazdaki bekleyen ad (`pref.pendingName.<uid>`, profil oluşunca silinir) → yer tutucu (ARB `authSetupPlaceholderName`: "Kullanıcı" / "User") | `setup_profile_view_model_test` (uçtan uca `2025123456` yazılmıyor), `register_view_model_test`, `app_preferences_store_test`, `fake_app_preferences_store_test` |
| **A3-01** | orta | Android manifest | `allowBackup` / `dataExtractionRules` tanımsız (varsayılan yedek açık) | Auth yenileme jetonu, Firestore kalıcı önbelleği (kendi `private/account`; yöneticide üyelerin `private/contact` e-postaları) ve SharedPreferences Google Drive yedeğine ve cihazdan cihaza aktarıma girer | `allowBackup="false"`, `fullBackupContent="@xml/backup_rules"`, `dataExtractionRules`; `res/xml/` altında 2 kural dosyası. iOS karşılığı kabul edildi (rules-spec §9.18) | `test/platform/android_backup_test.dart` |
| **A5-02** | orta | Functions `finishAccountDeletions` | Kişisel belgeler (`notifications` / `blocks` / `savedPosts`) limitsiz tek sorguyla okunuyor, belge başına ayrı commit atılıyordu; kullanıcı içinde süre denetimi yoktu | Hesap ~11 bin sahte `blocks` (var olmayan `blockedId`) ya da hatırlatıcı yazıp kendini siler → 540 sn'lik koşu düşer, arkadaki hesapların iletişim e-postası / notu boşaltılmaz (PoC: 1 350 engel = 1 351 commit; üretimde 20–50 ms / commit → ~10,8–27 bin belge) | İki geçiş: önce penceredeki tüm hesapların kritik birimleri, sonra kalan süreyle kişisel belgeler. Sayfalı okuma 450, koşu başına hesap × koleksiyon ≤ 900, ≤ 450'lik gruplu batch (her yazım kendi önkoşuluyla), bütçe sayfa / hesap / batch öncesi | `account_cleanup_runner.emu.test.ts` (eski kodda 1 003 commit, beklenen 3) |
| **F4** | düşük | Rules `settings` | `settings.clubs` biçimsiz ve sınırsız (CD-133 madde 8 bu task'a bırakmıştı) | Sahibi 500 KB dizgi + liste + iç içe harita yazar (PoC); sunucu her push'ta belgeyi okuyup ayrıştırır | `clubsOk`: değer dört bool alanın 16 birleşiminden biri, anahtar `[A-Za-z0-9]{1,20}`, en çok `settingsClubsMax` 200 kayıt (belge boyutu sınırı, kota değil) | `settings.test.js` |
| **F5** | düşük | Rules testleri | `parity.test.js`'te "nihai T-45" işaretli 2 `test.todo` | Limits ↔ Rules sapması ve sınırı hiç olmayan alanlar (F1 gibi) sistematik yakalanmıyordu | 2 todo gerçek teste döndü (`role_policy.json` ↔ beklenti dosyaları, 7 izin–koleksiyon eşleşmesi; `// limit:` karşılaştırma yönü); `clubs` anahtar / değer paritesi; sınırın tam değeri satırları (özet 160, hakkında 1000, ad 60) | `parity.test.js` (bozulmuş kopyada 2 hatayı yakaladığı sınandı) |
| **S2-01** (+ A5-03) | düşük | Functions `push_guard` | Kapsam kilidi yalnızca `event_new`, `application_received`, `new_report`'ta. `removed_from_club` (FORCED; M9 ↔ M12b, yönetim kurulu da), `application_approved` / `_rejected` (M5 / M6 ↔ M12a) ve `role_changed` (FORCED; M10, başkan) gerçek ama yinelenebilir geçişe bağlı | Karar → 30 sn içinde geri al döngüsü: her tur 1 gelen kutusu belgesi + 1 push; ~1 sn / tur ile günde ~86 bin FORCED push, alıcı kapatamaz | 1. iş akışı: `push_guard.ts:13`'teki yanlış "tek seferlik olay" iddiası kaldırıldı, döngü belgelendi, kabul testi. 2. iş akışı: **push döngü freni uygulandı (F grubu)** — `DECISION_TYPES` dört tür için kilit `decision\|{clubId}\|{Istanbul günü}`, kimlik `once_{type}_{key}_{uid}` → (tür, kulüp, alıcı) başına günde bir push; ikinci push'un makbuzu `throttled`, bildirim belgesi aynen. Rol kapsamda değil (aç-kapa da günde bir); onay / ret ayrı tür (dönüşümlü döngüde günde en çok 2). Aynı günün meşru ikinci kararı yalnızca gelen kutusunda (kabul) | `functions/test/push_guard.test.ts` (yeniden yazıldı) · `send_push.emu.test.ts` (dört türün her biri için iki ardışık tur: ikinci `throttled`; başka kulüp / ertesi gün geçer; türler ve alıcılar birbirini frenlemez) |
| **A3-02** | düşük | Yerel depolama | Son aramalar tek global anahtarda; yazı taslağı yalnızca kulüp kimliğiyle anahtarlı; çıkışta silinmiyordu | Ortak cihazda sonraki hesap öncekinin son aramalarını ve kulüp taslağını görür | Son aramalar çıkışta, dışarıdan kapanışta ve hesap değişiminde sessizce silinir (`SessionViewModel._resolveFor`); taslak `ownerUid` etiketli, başka hesabın ya da etiketsiz taslağı yüklenmez | `session_view_model_test`, `compose_state_test`, `compose_view_model_test` |
| **A3-03** + **S4-01** | düşük | `.gitignore` | `*.p8`, `*.pem`, `*.key`, `.secret.local`, `.runtimeconfig.json`, GCP varsayılan anahtar adı kapsanmıyordu (`git check-ignore`: 9 örnek dosya izlenebilir) | Repo herkese açık; W-104'te APNs `.p8` indirilecek → yanlışlıkla commit = anahtar sızıntısı | `*.p8 *.pem *.key *.cer **/.secret.local **/.runtimeconfig.json service-account*.json *credentials*.json gu-kulupler-*.json`; desenlere uyan izlenen dosya yok | `test/platform/gitignore_secrets_test.dart` |
| **S4-02** | düşük | `tool/admin` | `package-lock.json` yok, `firebase-admin ^13.0.0`; betikler servis hesabıyla gerçek projeye yazıyor (`.gitignore:86` CD-40 kuralıyla çelişki) | Tedarik zinciri: kurulumda öngörülmeyen sürüm çözülür | `package-lock.json` (firebase-admin 13.10.0, 178 paket, hepsinde bütünlük karması); README + 2 ipucu `npm ci --ignore-scripts` | `tool/test/admin_scripts.test.js` |

### 2.2 Elenen 3 bulgu

| ID | Önem | Sorun | Elenme gerekçesi |
|---|---|---|---|
| S4-03 | düşük | `functions` üretim zincirinde 9 orta danışma; kök GHSA-w5hq-g745-h8pq (uuid < 11.1.1, v3 / v5 / v6'da `buf` parametresi) | Saldırı merceği: istismar yolu yok. Tek `uuid@9.0.1`, `firebase-admin 13.10.0` → `@google-cloud/firestore` / `google-gax` / `@google-cloud/storage` zinciri; kod yalnızca parametresiz `v4()` çağırıyor. Kapatmak `firebase-admin` 14 (major) ister |
| A5-03 | orta | `gateIdFor` yalnızca 3 türe kapsam kilidi koyuyor | Gerçek (emülatör PoC 5 / 5), ama S2-01 ile aynı döngü → S2-01 altında birleştirildi. Düzeltmesi push hız sınırı kararıydı: 1. iş akışında kabul + test, 2. iş akışında F grubu freni |
| A5-04 | orta | Hiçbir liste kuralı `request.query.limit` sınırı koymuyor; doğrulanmış hesap `users`'ın tamamını tek istekte okur | Kural kısmı doğru, maliyet büyütme iddiası yanlış. PoC: `limit ≤ 50` kuralı altında imleçli sayfalama 120 belgenin tamamını aynı toplam okumayla çekti; kural meşru sorguları kırar (ADM-01 `count()`, `getUsers` `whereIn`, `listByInterests limit(200)`). `users` taraması §9.1'de kabul |

### 2.3 Düzeltme dışında kalan, açık işler

- **2. iş akışında kapandı:** `send_push.ts` tür denetimi makbuz `create`'inden önce — `event_reminder` / bilinmeyen tür `skipped_type` döner, makbuz yazılmaz (aynı belge iki kez tetiklense de push yok; emülatör + e2e testi). `canCreateBlock` + `exists(users/{blockedId})` (2 erişim yolu; uydurma kimlikle sınırsız engel yok). `tool/admin/finish_account_deletion.js` → saf modül `tool/admin/lib/account_cleanup_runner.js`: functions A5-02 kurgusu (iki geçiş, sayfalı okuma, ≤ 450'lik önkoşullu batch; kuru çalıştırma `count()`; önkoşulu tutmayan batch sayılır ve "yeniden çalıştır" denir). `fake_management_repository` kapak tohumunu `FieldValidators.coverSeed` ile denetler.
- A5-02 kalan sınırı: Functions 72 sa pencerede koleksiyon başına en çok 3 × 900 belge temizler; fazlası (saldırganın kendi sahte belgeleri) admin betiğine kalır.
- F2: `updateDisplayName` yeniden denemesi (`packages/gu_data`) ve AUT-05'e koşullu ad alanı (tasarım sapması, kullanıcı kararı) yapılmadı; yer tutucu kullanılıyor.
- A3-02: jetonlu görsel adresleri (`media.imageUrls`) çıkışta silinmiyor. Hepsi doğrulanmış her kullanıcının okuyabildiği yollar (§9.11 d); Android yedeği kapatıldı.

## 3. Sunucu tarafı

### 3.1 Firestore Rules matrisi

`firestore.rules` (2 990 satır, denetim anı) spec §3 ile koleksiyon koleksiyon karşılaştırıldı. 21 `match` bloğunun hepsinde `allow delete: if false`. Rol yükseltme, başka kulübe yazma, `private/*` sızıntısı, sayaç / işaretçi manipülasyonu yolu bulunmadı. Matris `expectations/*.json` → `helpers/matrix.js`, 14 bağlam (12 sütun + `outsideDomain` / `deleted`). Toplam **1 683 matris vakası** (denetim anı; düzeltme turu yenilerini ekledi):

| Koleksiyon | Vaka | İşlem başına bağlam |
|---|---|---|
| `users` | 85 | get / list / update 14, create 13 |
| `users/private/account` | 87 | get / update 14, create 12, list 2 |
| `clubs` | 104 | get 14, create 12, update 13, list 8 |
| `clubs/private/counter` | 30 | get 14 |
| `memberships` | 246 | get / create / update 14, list 13 |
| `memberships/private/contact` | 66 | get / update 14, create 6 |
| `posts` | 148 | create 14, get / update 13, softDelete 9, restore 5 |
| `posts/votes` | 51 | create 14, get 13 |
| `comments` | 91 | create 14, get 13, update 10 |
| `events` | 163 | get / create 14, list 12, update 9, softDelete 6, restore 4 |
| `events/private/counter` | 29 | — |
| `rsvps` | 129 | get / create 14, list 10, update 9 |
| `notifications` | 82 | get / create 14, list / update / softDelete 8 |
| `reports` | 46 | create 14, get 10 |
| `activity` | 50 | get / create 12, list 7 |
| `settings` | 67 | get / create / update 14 |
| `blocks` | 52 | create 14, softDelete 9 |
| `savedPosts` | 62 | create 14, get 11, softDelete 10 |
| `supportTickets` | 58 | get / create 14, list 9, update 7 |
| `announcementCounters` | 37 | — |
| `pushReceipts` | deny_all | `push_receipts.test.js` + `delete_denied` (`SERVER_ONLY_ROOTS`) |

Matris dışı ayrıntılar ayrı dosyalarda: `memberships_manager`, `counters`, `notifications` tür dalları, `queries` (§6 sorgu sözleşmesi), `admin`, `account_deletion`, `repository_payloads` (gerçek repository yükleri). Bağımsız doğrulamada sağlam: sayaç / işaretçi bağları (`ownMembershipUnmoved`, `sidePointsHere`, `lastRsvpRef`, `lastCommentRef`, `lastPostRef`; `getAfter` iki yönlü) · sahte bildirim (tür bazlı üretici + olay bağı, belgede metin yok) · kendi rolünü yükseltme (M1–M4 `member`, M10 yalnızca başkan / süper admin) · geri alma yalnızca silen / süper admin · `private` koleksiyon grubu yalnızca süper admin.

**Şikayet kotası (kullanıcı kararı 3):** uygulandı (K grubu; rules-spec §3.10 `reportCounted()`, yeni §3.18). Sayaç `reportCounters/{uid}_{yyyyMMdd}` şikayetle aynı batch'te `increment(1)`; sınır `Limits.reportDailyLimit` = 20 (`// limit:`). Duyuru sayacı kalıbı: gün **sunucu** saatinden ve toleranssız, sayaç ↔ şikayet iki yönlü bağ (`getAfter.count == önceki + 1`, `reportId` işaretçisi), sayaç tek başına / azaltılarak / sıfırlanarak / mutlak değerle yazılamaz, yalnızca sahibi okur (liste kapalı). Erişim yolu: şikayet + sayaç **4** (`budget/report_budget.test.js`). İndeks gerekmez (yalnızca `get`). İstemci (`FirebaseReportRepository`) yazmadan önce sayacı okur: dolu → yazım yok, `FirestoreRuleCode.reportLimit` (aynı hedef zaten bildirilmişse önce `alreadyExists`); Rules reddinden sonra sayaç doluysa yine `reportLimit`; gün sınırı penceresinde komşu günle bir kez yeniden dener (W-50). Arayüz: yeni toast yok, SHT-10'un satır içi hata satırında `sht10DailyLimit` (K-92). Testler: `rules/report_limit.test.js`, `expectations/report_counters.json` (matris satırı 22), `budget/report_budget.test.js`, `firebase_report_repository_test` (13 yeni), fake'ler. Kabul: çözülen şikayet hakkı iade etmez; sayaç hesap silmede temizlenmez (yalnızca uid + sayı — rules-spec §9.14 f); `notifyNewReport` değişmedi.

### 3.2 Erişim çağrısı bütçesi

Sınır: tek istekte 10, batch / transaction'da 20 `get` / `exists` / `getAfter`. Emülatör tekil yol sayımı (`budget/*.test.js`, bu turda yeniden koşuldu):

| İşlem | Yol |
|---|---|
| `assignPresident` (en ağır) | 9 |
| M5 onay / M6 / M9 / M12 | 6 |
| M11 devir · bildirimli duyuru yayını · `createClub` | 5 · 5 · ≈ 5 |
| RSVP katılım · yoklama / terfi | ≤ 4 · 4 |
| Bildirim fan-out parçası | 4 ortak yol (N = 10–450 geçti; parça 225) |
| Yorum | 3 |
| Tek belgelik en ağır istek (`canEditNote` / `canEditPost` / `canLike`) | 3 |
| `event_reminder` (T-45 A5-01) | 2 |
| Şikayet + günlük sayaç (T-45 kullanıcı kararı 3) | 4 |
| `blocks` create (T-45 `exists(blockedId)`) | 2 |
| Hesap silme üyelik parçası | 1 + 2N (N = 9 geçer, 10 hata; parça 5 → 11) |
| `resolveReports` | 449 yazım, 1 ortak yol |

Canlı uyarısı (spec §5, kabul): aynı belgenin önbelleğe alınması ("may be cached") ve batch başına 1 000 ifade sınırı emülatörde ölçülemez → T-46'da canlı fan-out ve hesap silme parçası denenir; kural değişmez, gerekirse yalnızca `Limits` küçülür. Not: 450 belgelik hatırlatıcı saldırı testi emülatörde "1000 ifade" hatası verdiği için 5 belgeyle koşuyor.

### 3.3 Storage yol matrisi (`firebase/storage.rules`)

| Yol | get | create | Firestore belgesi | Kabul edilen kalan |
|---|---|---|---|---|
| `users/{uid}/{file}` | doğrulanmış her hesap | sahibi + `isNewFile` + `imageOk` + `fileNameOk` + `noCustomMetadata` + `accountActive` | 1 | adet kotası yok (§9.8) |
| `clubs/{clubId}/{file}` | doğrulanmış her hesap | `metadata.clubId` = klasör, `uploaderId` = uid; süper admin ya da o kulübün etkin yöneticisi + `accountActive` | 2 | askıdaki kulüpte yükleme geçer, iliştirme `clubLive`'da düşer (§9.11 b) |
| `events/{eventId}/{file}` · `posts/{postId}/{file}` | doğrulanmış her hesap | klasör `[A-Za-z0-9_-]+`; yalnızca `metadata.clubId` kulübünün etkin yöneticisi | 2 | yabancı klasöre yetim dosya (§9.11 g, §9.12 d) |
| `support/{ticketNo}/{file}` | yalnızca yükleyen + süper admin | etkin her hesap, `GU-…` deseni + `uploaderMetadataOnly` | 1 | kota yok — **kullanıcı kararı 2: sınırsız** (§9.13) |
| `{allPaths=**}` | ret | ret | — | — |

Doğrulanan: tür yalnızca jpeg / png / webp (svg, gif ret) · `0 < boyut < 5 MB` · gzip ve `attachment` ret · `..%2F` yol geçişi ret · uzantı ↔ içerik türü · `isNewFile` üzerine yazmayı kapatır · üst veri sonradan değişmez (`update: false`) · `uploaderId` / `clubId` sahteciliği ve `c01_u` + `x` kimlik kaydırması testli · dosya silinmez (D-10), zararlı içerik konsoldan (W-74). **Storage'da yeni bulgu yok; T-45'te `storage.rules` değişmedi.** Canlıda doğrulanmamış: W-75, W-87, W-100, W-60 (IAM `firestoreServiceAgent`).

### 3.4 Functions güven sınırı

| Fonksiyon | İstemciden alınan | Denetim | Sonuç |
|---|---|---|---|
| `sendPushOnNotificationCreated` | `userId` (`isValidId`), `type` (beyaz liste), `refs` (7 anahtar, dolu dizgi) | Push metni yalnızca DB'den okunan kulüp adı / etkinlik başlığı (60 karakter); FCM `data` yalnızca kimlik; alıcı bağı (`announcement`, `event_cancelled`, `event_new`); kapsam kilidi; `users.status != active` alıcıya push yok; `pushReceipts.create` ile bildirim başına ≤ 1 push | Sağlam; S2-01 döngüsü §2.1 |
| `notifyNewReport` | `targetType` / `targetId` / `reporterId` / `status` | Alıcı = claim + `disabled` değil + `users.status == active`, şikayet eden hariç; `create()` idempotent | Sağlam |
| `promoteWaitlistOnCancel` | yalnızca `going → cancelled` geçişi | Tek transaction: etkinlik yayında / silinmemiş, kulüp canlı, `endsAt`, kapasite, aday alanları; `waitlistAt` Rules'ta `request.time` → sıra atlanamaz; bir iptal ≤ 1 terfi | Sağlam |
| `finishAccountDeletions` | `status == 'deleted'` (yalnızca sahibi yazar) | Kimlik + alan eşleşmesi, ilk yazım `lastUpdateTime` önkoşullu | A5-02 düzeltildi; başka hesabı etkileme yolu yok |

Genel: hepsi `retry: false` ve fırlatmaz (yeniden deneme döngüsü yok) · loglarda yalnızca türetilmiş anahtar ve sayılar · `functions/src`'de hard delete yok. Süper admin dizini 10 dk önbellekli: yetkisi alınan admin en çok 10 dk daha `new_report` alabilir; bu, kabul edilmiş ≤ 1 sa jeton penceresinin içinde (rules-spec §9.16 a).

## 4. İstemci ve platform

| Konu | Doğrulama | Sonuç |
|---|---|---|
| **Release ikilisi** | `flutter build apk --release --target-platform android-arm64 --analyze-size` (ENV yok = production). Dart AOT aşaması tamam | Snapshot'ta `debug_menu` kütüphanesi, `DebugMenuView`, `DebugMenuViewModel`, `DebugDemoAccounts`, `signInDemo`, `EmulatorCrashService` **0**. `strings app.so`: `Demo1234` 0, `ayse.demir@ogr` 0, `admin@gumushane.edu.tr` 0, `u_ayse` 0, `debug.open` 0. Kalan: `DebugMenuRoute` (NotFoundView'a gider) ve zararsız emülatör sabitleri (`AEMULATOR-ONLY_…` 1, `10.0.2.2` 2, `demo-gu-kulupler` 3; `AppEnvironment.parse` release'te ENV=emulator için `StateError`) |
| Gradle aşaması | `:app:checkReleaseAarMetadata` kırıldı | Güvenlik dışı **T-46 engeli**: permission_handler_android compileSdk 37 istiyor (uygulama 36, AGP 9.0.1) |
| Android manifest | Dışa açık bileşenler | Yalnızca `MainActivity` (`taskAffinity=""`) ve `FlutterFirebaseMessagingReceiver` (c2dm SEND izni); eklenti manifestlerinde başka `exported="true"` yok. `usesCleartextTraffic` yalnızca debug manifest'inde. Yedek: A3-01 düzeltildi |
| iOS | `Info.plist`, entitlements | ATS istisnası ve URL şeması yok; izin metinleri TR / EN; `aps-environment=development` (W-104, T-46); Keychain / iCloud yedeği kabul (§9.18) |
| Yerel depolama | SharedPreferences, bellek önbellekleri | T-44 `RepositoryReadCaches` uid değişince temizlenir; A3-02 düzeltildi; jetonlu adresler §2.3 |
| Günlük | `AppLogger`, Crashlytics | E-posta, ad, jeton, içerik yok; yalnızca uid, hata adı, kimliksiz yol kalıbı, enum değeri |
| Dış girdi | QR, push yükü, rota, `url_launcher`, dışa aktarım | `parseTicketQr` + `eventId` eşitliği · `isValidId` · `Uri.encodeComponent` + `rejectInvalidIds` (W-54) · `from` yalnızca kabuk rotası · şema beyaz listesi (https / http / mailto), userInfo'lu adres reddi, DLG-32 onayı · CSV formül enjeksiyonu ve ICS kaçışı önlenmiş · EXIF yeniden kodlamayla atılıyor |
| E-posta alan adı | İstemci ↔ Rules `emailOk()` | Tam eşleşme, ASCII küçültme — tutarlı. gmail.com geçici izni (W-61) kapsam dışı, **kalır** |

Bulgu sayılmayan sağlamlaştırma notları (T-46): `flutter_deeplinking_enabled` varsayılan açık → `<meta-data android:name="flutter_deeplinking_enabled" android:value="false"/>` (uygulamada derin bağlantı yok; guard'lar geçerli) · release debug anahtarıyla imzalı · About "Demo sürümü" metni · `shareBaseUrl` (`kulupler.gumushane.edu.tr`) sahipliği · çıkışta Firestore `clearPersistence` ve görsel önbelleği boşaltma · MGT-03 / MGT-06 CSV'leri paylaşımdan sonra önbellek dizininde kalıyor.

## 5. Gizli bilgi ve bağımlılık

### 5.1 Gizli bilgi taraması

| Komut | Sonuç |
|---|---|
| `git log --all -G'<desen>' --oneline` — 152 revizyon, 52 yerel + `origin/*` dal; desenler: `AIza[0-9A-Za-z_-]{35}`, `-----BEGIN [A-Z ]*PRIVATE KEY-----`, `"private_key"`, `client_secret`, `ghp_…`, `gh[ousr]_…`, `sk_live`, `sk_test`, `xox[baprs]-`, `AKIA[0-9A-Z]{16}`, `serviceAccount`, `firebase-adminsdk`, FCM sunucu anahtarı, `ya29.`, `1//0…`, `APA91b…`, JWT, `bearer`, `api[_-]?key=`, `secret=`, `BEGIN CERTIFICATE`, `BEGIN OPENSSH` | **Geçmiş dahil özel anahtar, servis hesabı, jeton yok.** Yalnızca `AIza` eşleşti (fc79231; 75c199d yalnızca önek metni). `serviceAccount` / `firebase-adminsdk` eşleşmeleri `.gitignore` satırı ve belge |
| `git log --all --name-only` (3 013 yol) | `.env`, `.pem` / `.p8` / `.p12` / `.jks` / `.keystore`, apk / aab / ipa, emülatör dışa aktarımı, adminsdk JSON hiç commit edilmemiş |
| `git ls-files reference` · `git log --all -- reference` | Boş · 0 commit (`reference/` hiç gitmemiş) |
| Diskte izlenmeyen dosyalar | Servis hesabı / `.env` / `.p8` / `key.properties` yok; tek `.pem` üçüncü taraf açık sertifika (`build/` altında) |
| CI | `.github/`, gitlab-ci, codemagic, bitrise, fastlane yok (CD-67) |

**İki Firebase istemci API anahtarı** — Android `AIzaSyCui_…` (`google-services.json:18`, `firebase_options.dart:53`), iOS `AIzaSyC7Ag…` (`GoogleService-Info.plist:6`, `firebase_options.dart:61`), proje `gu-kulupler`. İstemci yapılandırmasıdır, herkese açık olması normal (D-36); kayıt. Döndürülmüş başka anahtar yok; emülatör uygulaması gerçek anahtarı taşımıyor (CD-131). Demo parolası yalnızca emülatör seed'inde (`seed_emulator.js` `demo-` dışına yazmaz) ve release ikilisinde yok (§4).

**T-46 önerisi — API anahtarı kısıtlaması** (GCP Console → APIs & Services → Credentials):
1. Uygulama kısıtlaması: Android anahtarı → `com.gukulupler.gu_kulupler` + **release** imza SHA-1 (release imzası kurulmadan anlamsız); iOS anahtarı → bundle ID `com.gukulupler.guKulupler`.
2. API kısıtlaması: yalnızca Identity Toolkit, Token Service, Cloud Firestore, Cloud Storage for Firebase, Firebase Installations, FCM Registration, Remote Config, Crashlytics.
3. Uygulama kısıtlaması başlık sahteciliğiyle aşılabilir; Auth REST kötüye kullanımına karşı asıl fren **App Check**'tir (CD-64, §6).

### 5.2 Bağımlılık danışmaları

| Kapsam | Komut | Sonuç | Karar |
|---|---|---|---|
| `functions/` üretim | `npm audit --omit=dev` | 179 paket: 9 orta, 0 yüksek, 0 kritik; tek kök uuid GHSA-w5hq-g745-h8pq | Kabul — istismar yolu yok (S4-03); düzeltme `firebase-admin` 14 (major) |
| `functions/` tam | `npm audit` | 31 orta; ek kökler sprintf-js ≤ 1.1.3 (jest zinciri), ts-deepmerge < 8 (firebase-functions-test) | Kabul — yalnızca test süreci, dağıtılmaz; npm'in önerdiği jest 25 / ts-jest 27 geri sürümü uygulanmaz |
| `firebase/` (Rules testleri) | `npm audit` | 5 yüksek, 19 orta, hepsi geliştirme; yüksek: `@grpc/grpc-js` 1.9.16 (düzeltme 1.13.6; `@firebase/firestore` `~1.9.0`'a sabit, firebase 13.0.0 da) | Kabul — yalnızca jest + yerel emülatör; upstream düzeltme yok. İsteğe bağlı `overrides` uygulanmadı (uyumluluk riski, paralel Rules testleri) |
| `tool/admin/` | geçici lockfile + `npm audit` | 8 orta (firebase-admin 13.10.0 / uuid 9.0.1, functions ile aynı zincir) | Lockfile commit edildi (S4-02); danışma major yükseltmeyle kapanır → dokunulmadı |
| Dart | `flutter pub outdated --json --show-all` | **231 paket** (33 doğrudan, 13 geliştirme, 185 geçişli): danışma, discontinued, retracted **0**; git / path kaynağı yok; npm lockfile'larında `registry.npmjs.org` dışı kaynak yok | Temiz. Major güncellemeler (cloud_firestore 7, firebase_auth 7, firebase_core 5, firebase_messaging 17, firebase_storage 14, equatable 3 …) güvenlik gerektirmiyor → T-46 sonrası |
| iOS SPM | `Package.resolved` | firebase-ios-sdk 12.19.0, libwebp 1.6.0 (CVE-2023-4863 düzeltmesi 1.3.2'den beri), SDWebImage 5.21.7 | Bilinen açık yok |

## 6. Spam ve kota

Maliyet rakamları tahmindir (Firestore okuma ~0,03–0,06 $ / 100 bin, yazma ~0,09–0,18 $ / 100 bin); kesin fiyat ve Auth / Storage kotaları T-46'da konsoldan doğrulanır. App Check projede hiçbir yerde yok.

| Borç | Mevcut fren | En kötü günlük yük | Karar | Kalan risk |
|---|---|---|---|---|
| **W-86 (a)** iptal → yeniden başvuru | `application_received` kimliği `priorCount`'a bağlı (tur başına yönetici başına 1); push (kulüp, başvuran) başına günde 1; ret → 7 gün `retryAfter`; askı | ~1 sn / tur → kulüp başına ~86 bin × k (3–10 yönetici) gelen kutusu belgesi + aynı sayıda tetikleyici + makbuz | Sorulmadı → kabul (§9.3). Öneri: `cancelled → pending`'de `updatedAt + 10 dk < request.time` (0 erişim yolu) | Gelen kutusu şişmesi; tur başvuru listesinde ve günlükte görünür |
| **W-86 (b)** `event_new` yayın penceresi | Yalnızca yönetici, 10 dk pencere; push üyeye etkinlik başına 1; FORCED değil (`newEvents` / kulübü sessize alma) | Etkinlik oluşturma kotasız: günde 1 000 etkinlik = üye başına 1 000 push | Sorulmadı → kabul (K-J, CD-65). Öneri: üye için `club\|{clubId}\|{day}` başına ≤ N kilit ya da etkinlik yayın sayacı (W-50 deseni) | Kötü niyetli yönetici; fren hesap askısı |
| **W-86 (c)** fan-out parçası 225 | `permissionDenied`'da parça yarılır | Canlıda erişim önbelleği yoksa 225 → … → 3 (~7 reddedilen commit), 1 000 üye ≈ 333 commit | T-46 canlı ölçüm; `Limits` ve `fanout_result.json` canlı değerle | Ölçülene kadar belirsiz |
| **W-88** destek talebi | Askı (`activeUser` / `accountActive`), `userId` / `uploaderId` izi, süper admin listesinde `limit` | 5–10 talep / sn → 430–860 bin talep (≤ 500 karakter) + her birine < 5 MB ek (bant sınırlı, ~860 GB) | **Kullanıcı kararı 2: SINIRSIZ** — kabul (§9.13) | Yazım + depolama maliyeti; süper admin listesi taşar; App Check önerilir |
| **W-105 (a)** kalıcı kuyruk yok (CD-49) | — (güvenilirlik, kötüye kullanım değil) | Fan-out sırasında öldürülen uygulama → kalan alıcılara bildirim gitmez | Sorulmadı. Öneri: Mod F `ServerSideDispatcher` (fan-out sunucuya; §9.3'ü de kapatır) | Kayıp bildirim |
| **W-105 (b)** jeton tekilleştirme | Kısmen giderildi (`pref.pushTokenUid`, W-106 c, T-44 A4-06) | Pencere: eski hesabın push'u (kulüp adı / etkinlik başlığı) aynı cihaza | Sorulmadı. Öneri: sunucunun yazdığı `pushTokens/{sha256(token)}` sahip belgesi | Düşük (kişisel veri yok) |
| **W-105 (c)** `pushReceipts` saklama | D-10 (silinmez) | Normal: ~3 000 kullanıcı × ~3 bildirim ≈ 9 bin makbuz / gün ≈ 3,3 M / yıl ≈ 1–2 GB. Saldırı: A5-01 ile hatırlatıcı yolu katılım kaydına bağlandı | TTL (`expireAt`) D-10 ile çelişir → sorulmadı | Yavaş büyüme; §2.3 makbuz sırası |
| **W-106 (a)** herkese açık etkinlik push'u | Üye olmayana kulüp başına günde 1; FORCED değil | Tek kulüp yöneticisi ~5 000 doğrulanmış kullanıcıya günde 1 push; başlık yöneticinin metni (oltalama) | **Kullanıcı kararı 4: ŞİMDİKİ GİBİ** — kabul (§9.17 g) | Oltalama; `event_cancelled` / `waitlist_promoted` FORCED push'larında da başlık yönetici metni (alıcılar gerçek katılımcı, olay tek seferlik) |
| **W-106 (b)** şikayet seli | `new_report` push admin başına 15 dk'da 1 (günde ≤ 96); açık grup varsa bildirim yok | Önce: tek hesap ~5 bin şikayet (tüm kullanıcılar, herkese açık etkinlikler, 50 kulüp) → ~5 bin × admin sayısı gelen kutusu belgesi + tetikleyici; gelen kutusu sınırı 100 → gerçek şikayetler kaybolur | **Kullanıcı kararı 3: kullanıcı başına günde en çok 20** — Rules'ta uygulandı (K grubu; `reportCounters`, §3.1) | Sonra: hesap başına günde ≤ 20 şikayet → ≤ 20 `notifyNewReport` tetikleyicisi ve ≤ 20 × admin sayısı gelen kutusu belgesi (yalnızca grubun ilk açık şikayeti bildirilir); push admin başına 15 dk'da 1. Kalan: çok hesaplı saldırı (her doğrulanmış hesap 20) — fren askı, App Check |
| **W-106 (c)** jeton penceresi | — | W-105 (b) ile aynı | W-105 (b) | — |
| **W-106 (d)** `role_changed` + S2-01 / A5-03 döngüleri | Gerçek geçişe bağlı; kilit yoktu | ~1 sn / tur → günde ~86 bin FORCED push | **Push döngü freni uygulandı (F grubu):** (tür, kulüp, alıcı) başına Istanbul günü başına 1 push (§2.1 S2-01) | Push: alıcı başına kulüp başına günde ≤ 4 (dört tür); gelen kutusu: tur başına 1 belge kalır (§9.15 a, K-J kabul) |
| **W-106 (e)** `once_` kilit belgeleri | Türe / kapsama göre günlük sınırlı; D-10 | En kötü herkese açık `event_new`: 5 bin kullanıcı × 50 kulüp = 250 bin / gün | TTL D-10'a bağlı → sorulmadı | Yavaş büyüme |
| **W-59 (a)** Auth sayım / e-posta | Alan adı, 60 sn bekleme, giriş kilidi yalnızca istemcide (REST atlar); doğrulanmamış hesap veriye erişemez (`emailOk()`) | Auth hesap açma IP başına saatte ~100 (belgeye göre; konsolda doğrulanır) → IP başına ~2 400 hesap / gün; doğrulama e-postası günlük kotası tükenir, yeni öğrenciler o gün doğrulayamaz | Konsol (T-46): **Email enumeration protection açık**, Auth kullanım uyarısı, GCP bütçe uyarısı; App Check; `beforeUserCreated` (Identity Platform) sorulmadı | §9.9 kabul |
| **W-59 (b)** Storage kotası | Dosya < 5 MB, jpeg / png / webp, üst veri, `accountActive`; adet sınırı yok | Tek hesap ~10 MB / sn → ~860 GB (~172 bin dosya) / gün, kalıcı (~0,02–0,026 $ / GB-ay). İndirme: 5 MB'lık dosyayı döngüyle indirmek 100 Mbps'de ~1 TB / gün (~120 $ / gün) | Sorulmadı → kabul (§9.8). Öneri: App Check + bütçe / bucket izleme; Mod F `onObjectFinalized` yükleyen başına günlük sayaç (silmeden askı / işaret); `users/` ve `support/` için Firestore "yükleme bileti" (`private/account`, 2 belge sınırına sığar; `posts/` / `events/` / `clubs/` sığmaz) | Maliyet; fren hesap askısı |

**App Check önerisi (CD-64):** Play Integrity + App Attest / DeviceCheck; Firestore, Storage ve Auth'ta önce izleme, sonra zorlama kipinde. Auth REST spam'i, Storage kotası (S-8, S-9, W-59) ve destek talebi seli için asıl frendir.
**Auth e-posta sayım koruması:** konsol işi — T-46 (W-60).

## 7. Kullanıcı kararları ve T-46'ya kalanlar

### 7.1 Kullanıcı kararları (2026-10-15 22:35, AskUserQuestion)

| # | Konu | Karar | Uygulama |
|---|---|---|---|
| 1 | Kontrast | `textTertiary` #62748E → **#5E708A** ("çok az koyulaştır"; `bgSubtle` #F1F5F9 üzerinde 4,61 : 1, AA) | Uygulandı (K-91): kodda token `GuColors.light.textMuted` (`bgSurfaceMuted` üzerinde) → **4.61**, `bgSurface` / `bgSurfaceRaised` 5.05, `bgCanvas` 4.79; koyu `#AEB5BF` değişmedi (en düşük 6.61). Bilinen kusur listesi 4 → 3 çift. **114 golden** bilinçli güncellendi (kök 102, `gu_ui` 12; hepsi açık tema, koyu 0; kanal farkı en çok 4). A11y kontrast denetimi artık varsayılan açık (51 ekran; T-43 C-1 kapandı); muaf yalnızca EVT-02 harita metni 4.46 (tasarım) ve CLB-06 yanlış pozitifi (`lowContrastLabels`). İllüstrasyon SVG'leri #62748E kalır (K-20) |
| 2 | Destek talebi kotası | **Sınırsız kalır** | Kabul edilmiş sınırlama — W-88, rules-spec §9.13, PLAN S-10 / R-27 |
| 3 | Şikayet kotası | **Kullanıcı başına günde en çok 20**, Rules'ta zorlanır | Uygulandı (K grubu, §3.1): `reportCounters` + `Limits.reportDailyLimit`, `FirestoreRuleCode.reportLimit`, SHT-10 satır içi hata (K-92) |
| 4 | Herkese açık etkinlik push'u (üye olmayana) | **Şimdiki gibi** (kulüp başına günde 1) | Kabul edilmiş sınırlama — W-106 (a), rules-spec §9.17 (g), PLAN S-12 |
| — | Önceki kararlar | gmail.com geçici izni (W-61) **kalır**; QR v1; canlıya yükleme yalnızca kullanıcı söyleyince | Değişmedi |

### 7.2 T-46'ya kalanlar

Borçlar (`docs/progress.json`): **W-109** (W-59 c, cihazda fotoğraf yükleme) · **W-110** (W-86 c, canlı fan-out / hesap silme parçası) · **W-111** (gmail.com izni, W-61'in devamı) · **W-112** (release manifest, API anahtarı kısıtlaması, App Check, yükleme sırası). T-45'e bağlı açık borç kalmadı (W-59, W-61, W-86, W-88, W-105, W-106 kapandı).

1. **Canlıya yükleme sırası** (kullanıcı "yükle" deyince): `firebase deploy --only firestore:rules,firestore:indexes` → `--only storage` → `--only functions`. T-45 içeriği: `firestore.rules` (F1, A5-01, F4, `blocks` `exists(blockedId)` + şikayet kotası `reportCounters`; **indeks değişmedi**) · functions (`finishAccountDeletions` A5-02 + `sendPushOnNotificationCreated` push döngü freni ve makbuz öncesi tür süzgeci) · `storage.rules` T-45'te değişmedi. **Kurallar ile yeni uygulama sürümü birlikte çıkar:** kurallar yüklendikten sonra eski sürüm şikayet gönderemez (sayaçsız şikayet reddedilir), kurallar yüklenmeden yeni sürüm de gönderemez (ilk canlı yükleme; ardından hemen W-75 / W-87 / W-100 denemeleri). Bölge `REGION` Firestore konumuna göre doğrulanır (W-104).
2. **Release manifest'i:** `build/app/intermediates/merged_manifests/release/…` içinde `allowBackup="false"` ve `dataExtractionRules`'un eklenti manifestleriyle ezilmediği denetlenir (offline Gradle derlemesi doğrulayamadı); `usesCleartextTraffic` yok; dışa açık yalnızca `MainActivity` + mesajlaşma alıcısı.
3. **Android release derlemesi:** compileSdk 37 + AGP yükseltmesi ya da permission_handler_android sürüm sabitleme; release imzası `key.properties` yükleme anahtarıyla (şu an debug), Play App Signing, release SHA-1 / SHA-256 Firebase'e.
4. **Release ikilisi tekrar:** `--obfuscate --split-debug-info=<repo dışı>`; `strings libapp.so | grep -c Demo1234` = 0 ve `--analyze-size` snapshot'ında `debug_menu` yok.
5. **Konsol:** API anahtarı kısıtlaması (§5.1), App Check, Email enumeration protection, Auth kota ve GCP bütçe uyarısı (W-60).
6. **Canlı fan-out parça doğrulaması** (W-86 c, `notificationFanOutChunkSize` 225) ve hesap silme üyelik parçası (`accountDeletionChunk` 5): kural değişmez, gerekirse yalnızca `Limits`.
7. **gmail.com kaldırma** (W-61): yalnızca kullanıcı söyleyince — `EmailDomainPolicy.temporaryTestDomains` + `firestore.rules` / `storage.rules` regex, ardından yeniden yükleme.
8. **APNs `.p8`** repo dışında saklanır (`~/.secrets/`; `.gitignore` artık `*.p8` kapsıyor); `aps-environment` App Store arşivinde production (W-104).
9. Sağlamlaştırma (isteğe bağlı): `flutter_deeplinking_enabled=false`, çıkışta Firestore `clearPersistence`, About "Demo sürümü" metni, `shareBaseUrl` alan adı sahipliği, FlutterFire major yükseltmeleri.

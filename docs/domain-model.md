# Alan Modeli, Veri Şeması ve İş Kuralları

> **Bu doküman sözleşmedir.** Kaynaklar: tasarım brief'i (`design/prototype/claude-design-prompt.md`), prototipin davranışı (`design/prototype/app/actions.js` — `sel`, `notify`, `store.register` işleyicileri) ve `design/extracted/*`, demo veri (`tool/seed/demo-data.json`).
> Claude Code Faz 0 planında alan seviyesinde **kesinleştirir** (tip/nullability/validator); burada yazanla **çelişen** bir şema üretmez. Çelişki/boşluk bulursa `AskUserQuestion` ile sorar. Bilinen boşluklar §12'dedir.
> Firestore Security Rules karşılığı: [`firestore-rules-spec.md`](firestore-rules-spec.md). Silme politikası: [`soft-delete.md`](soft-delete.md).

---

## 1. İlkeler

1. **Düz (flat) koleksiyonlar** (D-25); ilişkiler id ile. Prototipin `memberships`, `rsvps` anahtarları aynen doküman ID'sidir: `${clubId}_${userId}`, `${eventId}_${userId}`.
2. **Her dokümanda ortak alanlar** (`BaseFields`): `createdAt`, `updatedAt` (sunucu zamanı), `isDeleted` (varsayılan `false`), `deletedAt?`, `deletedBy?`. Yazanı gereken dokümanlarda `createdBy`. Sabit alan adları `gu_data/constants/firestore_fields.dart`'ta.
3. **Hard delete yok.** İki kavram ayrılır: **(a) durum geçişi** (üyelik `left/cancelled`, katılım `cancelled`, etkinlik `cancelled`) — alan `status`; **(b) içerik silme** (gönderi, yorum, taslak etkinlik, bildirim, kayıt, engel) — `isDeleted`. Kullanıcıya görünen metin "silinecek" kalır; veri soft delete edilir.
4. **Sayaçlar** (`memberCount`, `goingCount`, `waitlistCount`, `attendedCount`, `likeCount`, `commentCount`) ilgili değişiklikle **aynı batch/transaction**'da güncellenir; Rules `getAfter()` ile tutarlılığı doğrular (`firestore-rules-spec.md §4`).
5. **Zaman:** UTC `Timestamp`; "gün" sınırı gerektiren her şey (duyuru limiti) **Europe/Istanbul** gününe göre (UTC+3, DST yok).
6. **Statik arama tabloları Firestore'da değildir** (§10): kategori, ilgi alanı, fakülte/bölüm, mekân, yıl, etkinlik türü.
7. **Arama istemci tarafında**: aktif kulüpler (az sayıda) ve yaklaşan etkinlikler (en çok 200) bir kez çekilir, yerelde süzülür (250 ms debounce). Sunucu tarafı tam metin arama **kapsam dışı**.

## 2. Koleksiyon şemaları

Tür kısaltmaları: `s` string, `i` int, `b` bool, `ts` Timestamp, `L<T>` liste, `M` map. `?` = null olabilir. Doğrulama sınırları `Limits` sabitleridir (§9).

### 2.1 `users/{uid}`  (uid = Firebase Auth uid)
| Alan | Tür | Not |
|---|---|---|
| `name` | s (2–60) | Anonimleştirmede `"Silinmiş kullanıcı"` |
| `nameLower` | s | `name.toLowerCase()` (tr yerel ayarlı, ADM-05 ad araması) |
| `avatarSeed` | s | Avatar rengi/harfi tohumu (tasarım) |
| `avatarPath?` | s | Storage yolu (Q-19) |
| `department?` | s | `d01…d24` |
| `year?` | s | `prep,1,2,3,4,5plus,master,phd` |
| `interests` | L<s> (1–5) | `i01…i16` |
| `bio` | s (≤140) | |
| `status` | s | `active` · `suspended` · `deleted` |
| `suspendReason?` | s | |
| `staff` | b | Akademik/idari personel (öğrenci ilgi alanı yok) — yalnızca seed/admin yazar |
| `profileComplete` | b | AUT-05 bitince `true` |
| + `BaseFields` | | |

- **E-posta burada değildir** (D-29). Kullanıcı kendi e-postasını `FirebaseAuth.currentUser.email`'den okur.
- Süper admin **alan değildir**; ID token claim'idir (D-28).

### 2.2 `users/{uid}/private/account`  (tek doküman, id `account`)
`email` (s), `emailLower` (s), `fcmTokens` (L<M{token,platform,updatedAt}>), `lastLoginAt?`, + `BaseFields`.
Okuma/yazma: **yalnızca sahibi**; okuma ayrıca süper admin (ADM-05 e-posta araması → `collectionGroup('private')`).

### 2.3 `clubs/{clubId}`
| Alan | Tür | Not |
|---|---|---|
| `name` | s | Başkan/yönetim **değiştiremez** (MGT-09'da kilitli); yalnızca süper admin. Benzersiz (ADM-03 doğrulaması: `nameLower` ile sorgu) |
| `nameLower` | s | |
| `categoryId` | s | `k01…k08` |
| `iconName` | s | Lucide adı (`code-xml`, `mountain`…) |
| `palette` / `pattern` | s | `red\|slate\|bordeaux` / `dots\|lines\|mountain\|waves` |
| `coverSeed` | s | `club-<id>` |
| `logoPath?` `coverPath?` | s | Storage (Q-19); yoksa tasarım kapağı |
| `memberCount` | i ≥ 0 | Aktif üyeler (danışman dahil değil — bkz. §5.5) |
| `approvalRequired` `applicationsOpen` `requireNote` | b | |
| `founded` | i | |
| `summary` (≤160) `about` (≤1000) | s | |
| `conditions` | L<s> | Katılım koşulları |
| `social` | M{`email?`,`instagram?`,`web?`} | Biçim doğrulama |
| `presidentId` | s | `memberships` içindeki `president` ile **tutarlı** |
| `pinnedPostId?` | s | Sabitlenmiş gönderi (kulüp başına **en çok 1** kuralının tek doğruluk kaynağı; `posts.pinned` yalnızca gösterim için kopyadır, ikisi aynı batch'te yazılır) |
| `advisor?` | M{`name`,`title`,`userId?`} | Bkz. G-1 |
| `status` | s | `active` · `suspended` |
| `suspendReason?` | s | Süper admin zorunlu girer |
| + `BaseFields`, `createdBy` | | |

### 2.4 `memberships/{clubId}_{userId}`
| Alan | Tür | Not |
|---|---|---|
| `clubId` `userId` | s | ID ile tutarlı |
| `status` | s | `pending · active · rejected · removed · left · cancelled` (§5) |
| `role` | s | `member · board · president · advisor` (yalnızca `active` iken anlamlı) |
| `note` | s (≤300) | Başvuru notu |
| `applicant` | M{`name`,`department?`,`year?`,`avatarSeed`} | **Başvuru anındaki anlık görüntü** (ad/bölüm/sınıf; zaten `users/{uid}` ile aynı gizlilik sınıfında). Anonimleştirmede boşaltılır |
| `appliedAt` | ts | |
| `decidedAt?` `decidedBy?` | ts, s | Onay/red/çıkarma anı ve yapan |
| `retryAfter?` | ts | `rejected`/`removed` → karar + 7 gün |
| `rejectReason?` | s | `quota · criteria · missing · other` |
| `rejectNote?` | s | |
| `priorCount` | i | Önceki başvuru sayısı (SHT-19'da gösterilir) |
| + `BaseFields` | | |
- **`memberships/{id}/private/contact`** (tek doküman, id `contact`): `email` (s), `emailLower` (s), + `BaseFields`. Başvuru anında **başvuran** yazar (değer = `request.auth.token.email`, Rules doğrular). Okuma: sahibi, kulüp **yöneticisi/danışmanı**, süper admin. **Sıradan üyeler okuyamaz** — üye listesi sorgusu (`memberships` where `clubId`, `status=='active'`) bu yüzden e-posta taşımaz (Firestore'da alan-düzeyi okuma kısıtı olmadığı için ayrı doküman). Yönetici bağlamındaki e-posta (MGT-02, SHT-19, SHT-21, MGT-03) buradan gelir. Anonimleştirmede `email/emailLower=''`.
- Demo'daki `stale` **saklanmaz**: çakışma, işlem sırasında beklenen durumun (`pending`) değişmiş olmasıdır → DLG-18.

### 2.5 `posts/{postId}`
`clubId`, `authorId`, `type` (`post·announcement·poll`), `title?` (≤80; duyuruda zorunlu), `text` (≤1000), `images` (L<M{path,w,h}> ≤4), `poll?` M{`options` L<M{id,text}> (2–4), `endsAt`, `showResultsAfterVote`}, `pinned` (kulüp başına **en çok 1**), `pushSent` (b), `likes` (L<s> uid), `likeCount` (i), `commentCount` (i), `isHidden` (moderasyon; `hiddenBy`, `hiddenAt`), `editedAt?`, + `BaseFields`.
- `posts/{postId}/votes/{uid}`: `optionId`, `createdAt`. **Değiştirilemez, silinemez** (oy değiştirilemez kuralı). Sonuç sayımı: oy dokümanları istemcide toplanır (kulüp boyutu küçük) veya `count()` toplama sorgusu.

### 2.6 `comments/{commentId}`
`postId`, `clubId` (denormalize), `authorId`, `text` (≤500), `isHidden` (`hiddenBy`,`hiddenAt`), + `BaseFields`. Tek seviye (yanıt yok).

### 2.7 `events/{eventId}`
| Alan | Tür | Not |
|---|---|---|
| `clubId` `createdBy` | s | |
| `title` (≤80) `desc` (≤1000) | s | |
| `type` | s | `egitim · sosyal · gezi · yarisma · konferans` |
| `startsAt` `endsAt` | ts | bitiş > başlangıç; yayında başlangıç gelecekte |
| `placeId?` `placeText?` | s | Mekân tablosu (§10) veya serbest metin |
| `capacity?` | i ≥ 1 | `null` = sınırsız |
| `visibility` | s | `public · members` |
| `status` | s | `draft · published · cancelled` ("Geçmiş" = türetilmiş: `endsAt < now`) |
| `cancelReason?` | s | DLG-23 zorunlu neden |
| `coverSeed` `coverPalette` `coverPattern` `coverPath?` | s | |
| `registrationOpen` `autoReminder` | b | |
| `goingCount` `waitlistCount` `attendedCount` | i | Sayaçlar (§4) |
| `publishedAt?` | ts | |
| + `BaseFields` | | Yalnızca **taslak** soft delete edilebilir (DLG-31); yayındaki = iptal |

### 2.8 `rsvps/{eventId}_{userId}`
`eventId`, `clubId` (denormalize), `userId`, `status` (`going · waitlist · attended · cancelled`), `reminder` (`none · 1h · 1d`), `ticketCode` (D-30), `waitlistAt?`, `scannedAt?`, `scannedBy?`, + `BaseFields`. "Gelmedin" = türetilmiş (etkinlik bitti, `attended` değil).

### 2.9 `notifications/{notificationId}`
`userId`, `type` (§6), `refs` M{`clubId?`,`eventId?`,`postId?`,`applicantId?`,`reportId?`,`role?`,`textKey?`}, `read` (b), + `BaseFields` (kaydır-sil = soft delete; Geri al = `restore`).

### 2.10 `reports/{reporterId}_{targetType}_{targetId}`
`targetType` (`post·comment·user·club`), `targetId`, `targetClubId?`, `reporterId`, `reason` (`spam·inappropriate·harassment·misinformation·other`), `note` (≤300), `status` (`open·resolved`), `action?` (`removed·dismissed·suspended`), `resolvedAt?`, `resolvedBy?`, + `BaseFields`.
- **Prototipte tek rapor birden çok neden içerir; üretimde her şikayet ayrı dokümandır** (başkasının dokümanını güncellemeyi Rules'a açmamak için). ADM-04 / SHT-26 aynı `(targetType,targetId)` olanları **istemcide gruplar** (şikayet sayısı = grup boyu). Çözüm = gruptaki tüm `open` dokümanları tek batch'te `resolved` yapmak. Aynı kullanıcı aynı hedefi yalnızca bir kez şikayet edebilir (deterministik ID).

### 2.11 `activity/{activityId}`  (değiştirilemez günlük)
`clubId`, `actorId`, `kind` (`application_received·application_approved·application_rejected·member_joined·member_left·member_removed·role_changed·event_published·event_cancelled·post_created·announcement·poll·settings_changed`), `refs` M{`userId?`,`eventId?`,`postId?`,`role?`}, `createdAt`. **Güncellenemez** (Rules). Eylemi yapan istemci, eylemle **aynı batch**'te yazar. MGT-10 filtreleri: Üyelik / Etkinlik / İçerik / Ayar (`ACT_CAT` eşlemesi `design/extracted/registry.json#actCat`).

### 2.12 `settings/{uid}`
`announcements` `eventReminders` `newEvents` `applicationResults` `management` `system` (b), `reminderTime` (`1h·1d`), `quiet` (b), `quietFrom` `quietTo` (`HH:mm`, varsayılan 22:00–08:00), `clubs` M<clubId, M{`announcements`,`events`,`posts`,`muted`}>, `updatedAt`. Sahibi okur/yazar. Kayıtta oluşturulur (varsayılan hepsi açık).

### 2.13 `blocks/{blockerId}_{blockedId}`
`blockerId`, `blockedId`, + `BaseFields`. Engel kaldırma = `isDeleted:true` (Geri al = restore); yeniden engelleme = restore. Sahibi okur/yazar. Oturum açılışında sahibi bütün aktif engellerini çeker; **akış/yorum/üye listeleri istemcide süzülür**.

### 2.14 `savedPosts/{userId}_{postId}`
`userId`, `postId`, `clubId`, `savedAt`, + `BaseFields` (kaydı kaldır = soft delete). Sahibi okur/yazar.

### 2.15 `supportTickets/{ticketId}`
`ticketNo` (örn. `GU-7K3Q9X`, CSPRNG; kullanıcıya `#GU-7K3Q9X` gösterilir), `userId`, `subject` (`bug·suggestion·account·club·other`), `message` (≤500), `attachmentPaths` (L<s> ≤1), `status` (`open·closed`), + `BaseFields`. Sahibi oluşturur/okur; süper admin okur.

### 2.16 `announcementCounters/{clubId}_{yyyyMMdd}`  (Istanbul günü)
`clubId`, `day` (s, `yyyy-MM-dd`), `count` (i, 0–2), `updatedAt`. Bkz. §7.

## 3. Roller ve yetki matrisi

Roller **kulüp bazlıdır** (`memberships.role`); `superadmin` global claim'dir. Brief §2.2'nin tam matrisi kodda **tek yerde**: `gu_data/lib/src/core/role_policy.dart` (`ClubPermission` enum + `RolePolicy.can(permission, role, {isSuper})`), saf Dart, **tablo testli**. Rules'taki yardımcı fonksiyonlarla birebir eşleşir (parite testi: `docs/testing.md §6`).

| İzin (`ClubPermission`) | student | member | board | president | advisor | superadmin |
|---|---|---|---|---|---|---|
| `viewPublic` (tanıtım, public etkinlik) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `apply` | ✓ | — | — | — | — | — |
| `viewInside` (gönderi, üye listesi, members-only etkinlik) | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| `comment`, `vote` | — | ✓ | ✓ | ✓ | — | — |
| `createPost` | — | — | ✓ | ✓ | — | — |
| `sendAnnouncementPush` (günde ≤ 2) | — | — | ✓ | ✓ | — | — |
| `manageEvents` (oluştur/düzenle/yayınla/iptal) | — | — | ✓ | ✓ | — | — |
| `takeAttendance` | — | — | ✓ | ✓ | — | — |
| `decideApplications` | — | — | ✓ | ✓ | — | — |
| `removeMember` | — | — | ✓ | ✓ | — | ✓ |
| `moderateContent` (başkasının gönderi/yorumunu kaldır) | — | — | ✓ | ✓ | — | ✓ |
| `editClubSettings` | — | — | ✓ | ✓ | — | — |
| `assignRoles`, `transferPresidency` | — | — | — | ✓ | — | ✓ |
| `viewManagement` | — | — | ✓ | ✓ | ✓ (salt okunur) | ✓ |
| `createClub`, `suspendClub`, `assignPresident` | — | — | — | — | — | ✓ |
| `moderateReports`, `suspendUser` | — | — | — | — | — | ✓ |

- **Danışman:** panelde her şeyi görür; yazma aksiyonları **devre dışı** görünür ve dokununca **TST-26** ("Danışman yetkisi salt okunurdur") çıkar; panelin üstünde kalıcı "Salt okunur" bandı. Danışman yorum/oy veremez, kendi gönderisi olmaz.
- **Süper admin** kulüp içeriğini **görür** (`viewInside`), moderasyon ve çıkarma yapar; ancak kulüp adına gönderi/etkinlik oluşturmaz.
- Rol çözümü: `SessionViewModel.accessTo(clubId)` → `visitor · pending · rejected · member · manager · advisor · super` (prototipteki `sel.mode`); kod karşılığı `RolePolicy.accessOf`. Yalnızca `active` üyelik rol taşır: üyelik belgesindeki `role` (başvuruda da `member` yazılıdır) `RolePolicy.can`'e doğrudan değil, `RolePolicy.activeRole(status, role)` üzerinden verilir (Rules `mActive`).
- **Çıkarma ve rol atama hedefi** yalnızca `member` ve `board` üyedir: başkan önce devreder; danışman `memberCount`'a dahil olmadığı için çıkarılamaz ve rolü atamayla değiştirilemez — danışman ataması/kaldırması süper adminin ayrı işlemidir (`RolePolicy.canRemove` / `canAssignRole`, Rules M9 / M10 / M13).

## 4. Sayaçlar ve tutarlılık

| Sayaç | Artar | Azalır | Yazan | Aynı batch'te |
|---|---|---|---|---|
| `clubs.memberCount` | onay (`pending→active`), anında katılım | ayrılma, çıkarma, onay geri alma | karar veren yönetici / ayrılan kullanıcı | üyelik güncellemesi + `activity` |
| `events.goingCount` | katılım (`going`) | vazgeçme, terfi hariç; `going→cancelled` | katılan/vazgeçen kullanıcı; terfi = yönetici (veya Mod F tetikleyici) | rsvp yazımı |
| `events.waitlistCount` | bekleme listesine katılım | bekleme listesinden ayrılma / terfi | aynı | rsvp |
| `events.attendedCount` | `going→attended` | `attended→going` | yoklama alan yönetici | rsvp |
| `posts.likeCount` | beğeni | beğeniyi geri alma | beğenen üye | `likes` alanı |
| `posts.commentCount` | yorum | yorum soft delete | yorumcu / silen | yorum dokümanı |

**Kural:** Rules, sayaç değişimini **yalnızca beraberindeki doküman değişikliğiyle uyumluysa** ve **±1** ise kabul eder (`getAfter`). İstemci hiçbir zaman "değer = hesapla" yazmaz, her zaman delta ile (transaction içinde okuyup +1/−1).

## 5. Üyelik durum makinesi

Brief §2.3'ün üretim karşılığı. `none` = doküman yok **veya** `left/cancelled`. (`left` ve `cancelled` PRF-03 "Geçmiş" sekmesi için tutulur.)

| Geçiş | Tetikleyici (ekran/aksiyon) | Kim yazar | Sayaç | Bildirim / Günlük | Koşul |
|---|---|---|---|---|---|
| `∅/left/cancelled → pending` | Başvur (SHT-05) | başvuran | — | `application_received` → yöneticiler; `activity: application_received` | `club.approvalRequired && applicationsOpen`; `retryAfter` yok ya da geçmiş; `status` yalnızca `pending` yazılabilir; `applicant` snapshot dolu |
| `∅/left/cancelled → active` (`member`) | Katıl (anında) | katılan | `memberCount +1` | `activity: member_joined` | `!approvalRequired && applicationsOpen && status==active` |
| `pending → active` | Onayla (MGT-02 ✓) | yönetici | `+1` | `application_approved` → başvuran; `activity` | önceki durum `pending` değilse **DLG-18** |
| `pending → rejected` | Reddet (SHT-20) | yönetici | — | `application_rejected`; `retryAfter = decidedAt + 7 gün`; `rejectReason/Note` | |
| `pending → cancelled` | İsteği iptal et (DLG-07) | başvuran | — | TST-40 | |
| `rejected/removed → pending` | Tekrar başvur | başvuran | — | yukarıdaki | `request.time ≥ retryAfter` aksi halde geri sayım |
| `active → left` | Kulüpten ayrıl (DLG-08) | üye | `−1` | `activity: member_left` | **tek başkan ayrılamaz** (DLG-09: önce devret) |
| `active → removed` | Üyeyi çıkar (DLG-19) | yönetici/süper admin | `−1` | `removed_from_club` (force); `retryAfter +7g`; `activity` | başkan çıkarılamaz |
| `active(role) → active(role')` | Rol seç (SHT-22 → DLG-20) | başkan/süper admin | — | `role_changed` (force); `activity` | `president` rolü yalnızca devirle |
| `active/rejected → pending` (**geri al**) | Toast "Geri al" (6 sn) | karar veren yönetici | `−1` (aktifse) | — | `request.time < decidedAt + 30 sn` |
| devir | Başkanlığı devret (SHT-25 → DLG-21) | başkan/süper admin | — | `role_changed` (force) | tek batch: eski başkan→`board`, yenisi→`president`, `clubs.presidentId` |

- `role='advisor'` üyelik **danışman hesabıdır**; `memberCount`'a dahil **edilmez** ve `member` listesinde "Danışman" grubunda görünür. Danışmanlar yönetici sınırı hesabına girmez.
- **Eşzamanlılık:** her geçiş transaction'da *beklenen önceki durumu* doğrular (optimistic). Beklenmeyen durum = çakışma = DLG-18 + liste yenile.
- `priorCount` yeniden başvuruda `+1`.

## 6. Bildirimler

Tür → alıcı → ayar anahtarı (prototipte `TYPE_SETTING`) → tetikleyici. **`force` = kullanıcı tercihine bakmadan gider.** Hedef ekran (dokununca) `NTF-01` tablosu ve prototip `flows.openNotification`'dadır; derin bağlantı kuralı: ilgili **sekmenin köküne** geri dönen yığın.

| `type` | Alıcı | Ayar | force | Kim/ne zaman üretir |
|---|---|---|---|---|
| `application_received` | kulüp yöneticileri (board+president) | `management` | — | başvuru gönderilince |
| `application_approved` | başvuran | `applicationResults` | — | onayda |
| `application_rejected` | başvuran | `applicationResults` | — | redde |
| `removed_from_club` | çıkarılan | — | ✓ | çıkarmada |
| `role_changed` | rolü değişen | — | ✓ | rol/devir/başkan atamada |
| `announcement` | kulüp üyeleri (yazar ve danışman hariç) | `announcements` + kulüp bazlı (`muted`, `announcements`) | — | duyuru **push açık** yayınlanınca (limit ≤2/gün) |
| `event_new` | kulüp üyeleri + (public ise) kategorisi ilgi alanıyla eşleşen kullanıcılar (yayıncı hariç) | `newEvents` + kulüp bazlı (`events`) | — | etkinlik yayınlanınca ("{n} üyeye bildirim gönder" işaretliyse) |
| `event_reminder` | kayıtlı (`going`) katılımcılar | `eventReminders` + `reminderTime`/rsvp `reminder` | — | zamanlanmış (Mod F: Function; Mod C: cihazda yerel) |
| `event_cancelled` | etkinlik kayıtlıları (going+waitlist) | — | ✓ | iptalde |
| `waitlist_promoted` | terfi edilen | — | ✓ | terfide (yönetici veya Mod F tetikleyici) |
| `report_resolved` | şikayet edenler | — | ✓ | şikayet çözülünce |
| `new_report` | tüm süper adminler | — | ✓ | şikayet açılınca |
| `system` | herkes | `system` | — | admin/sistem |

- Sessiz saatler (`quiet`, `quietFrom/To`): push teslimini erteler/engeller (Mod F sunucuda; Mod C'de push yok, liste etkilenmez).
- Okunmamış sayısı rozet: Bildirimler sekmesinde, `9+` üstü "9+".
- Hedef silinmişse (gönderi/etkinlik) → **SYS-04**.
- Bildirim üretim sorumluluğu **Q-02** cevabına göre (`docs/architecture.md §7`).

## 7. Duyuru günlük limiti (2/gün)

- Yalnızca **push açık duyuru** sayılır (`type=announcement && pushSent=true`). Push kapalı duyuru sınırsızdır ("Bildirimsiz yayınla", DLG-24).
- Sayaç: `announcementCounters/{clubId}_{yyyyMMdd}`, gün = **Istanbul günü**. Yayın batch'i: gönderi dokümanı + sayaç `count+1` (+ `activity`). Rules `count ≤ 2` ve artışın tam +1 olmasını `getAfter` ile doğrular; gün anahtarı `request.time + 3 saat` üzerinden hesaplanır.
- UI: FED-03'te "Bugünkü duyuru hakkı: 1/2" çubuğu (sayaç dokümanından), hak 0'sa anahtar devre dışı + DLG-24 akışı. Yenilenme: Istanbul 00:00.
- `SHT`/Remote Config `announcement_daily_limit` **yalnızca UI ipucudur**; zorlayıcı sınır Rules'taki 2'dir (Q-10).

## 8. Etkinlik katılım kuralları

- **Katıl** (SHT-12 onayı): kontenjan yok ya da `goingCount < capacity` → `going` (+`goingCount`); aksi halde `waitlist` (+`waitlistCount`, `waitlistAt`). Aynı transaction'da event + rsvp. `registrationOpen=false` ise TST-X2 ("kayıtlar kapalı"). Bitmiş etkinlikte TST-X6. `members` görünürlüklü etkinliğe yalnızca aktif üye katılır.
- **Vazgeç** (DLG-14): `going→cancelled` (`goingCount −1`) / `waitlist→cancelled` (`waitlistCount −1`). Mod F: tetikleyici en eski bekleyeni `going` yapar ve `waitlist_promoted` yollar. Mod C: yalnızca yönetici elle terfi (MGT-06 "Kayıtlıya al"; kontenjan yoksa TST-X14).
- **Bekleme sırası** ("{n}. sıra"): aynı etkinliğin `waitlist` rsvp'leri `waitlistAt`'e göre sıralanır; kullanıcının sırası = ondan önceki sayısı + 1.
- **Hatırlatıcı** (SHT-13): `reminder ∈ {none,1h,1d}`; katılmadan ayarlanamaz (TST-X7). `autoReminder` etkinlik düzeyinde ek hatırlatmadır.
- **Bilet** (EVT-03): `going/attended` durumunda gösterilir; QR içeriği `gu:ticket:v1:{eventId}:{ticketCode}`. Durum rozeti: **Geçerli** (`going`) · **Okutuldu** (`attended`, `scannedAt`) · **İptal** (rsvp `cancelled` veya etkinlik `cancelled`). Canlı akış: yönetici okutunca bilet ekranı anında "Okutuldu" olur.
- **Yoklama** (MGT-06/07): QR okut → `eventId` ve kod ile rsvp aranır → sonuç **SHT-24**: *Geçerli* (`going→attended`, `scannedAt/By`, TST-31 yok; 2 sn sonra otomatik kapanır, tarama devam), *Zaten okutulmuş* (`attended`), *Geçersiz* (yok/iptal/başka etkinlik). Manuel "Katıldı" anahtarı ve "Tümünü katıldı yap" (DLG-17) aynı alanları yazar. Yoklama %: `attended / (going+attended)`.
- **İptal** (DLG-23): etkinlik `cancelled` + neden zorunlu; kayıtlılara `event_cancelled`. Bilet **İptal** görünür; yeni katılım yok.
- **Yayın** (DLG-22): `draft→published` (+`publishedAt`); "{n} üyeye bildirim gönder" işaretliyse `event_new`. Yayından çek = `published→draft` (TST-X19). **Kopyala**: yeni taslak, tarih +7 gün, başlık "(kopya)" (ARB metni).
- Düzenleme: yayındaki etkinlikte `capacity`, mevcut `goingCount`'tan düşük olamaz.
- Etkinlik listeleri: `members` görünürlükler yalnızca o kulübün aktif üyelerine ve süper admine; taslak yalnızca yönetici (+ süper admin); askıdaki kulübün etkinliği görünmez.

## 9. Sabit sınırlar (`Limits`, tek yer)

Şifre ≥ 8 + büyük harf + rakam · giriş: 5 hatalı denemede 30 sn kilit (istemci) · doğrulama maili tekrar gönderme 60 sn · ilgi alanı 1–5 · biyografi 140 · ad 2–60 · gönderi metni 1000 · duyuru başlığı 80 · yorum 500 (400'den sonra sayaç) · görsel ≤ 4 (dosya ≤ 5 MB) · anket: 2–4 seçenek, süre 1/3/7 gün · kısa açıklama 160 · uzun açıklama 1000 · başvuru notu 300 · etkinlik başlığı 80, açıklaması 1000 · destek mesajı 500 · yeniden başvuru bekleme **7 gün** · duyuru **2/gün** · son aramalar 6 · arama debounce 250 ms · sayfa boyutu 20 · yönetici karar geri alma 30 sn (Rules).
`Limits` değerleri ARB metinleriyle (`{n}` parametreleri) tutarlı olmalı.

Sunum süreleri `Limits`'te **değildir** (CD-24, CD-58; PLAN §9.8): toast 4 sn → `GuMotion.toastDefault` · "Geri al"lı toast (geri alma penceresi) 6 sn → `GuMotion.toastUndo` · splash animasyonu 1.2 sn → `GuMotion.splash` · QR başarı (SHT-24) oto-kapanma 2 sn → `AppDurations.qrSuccessAutoClose` (`lib/core/constants/app_durations.dart`, T-35).

## 10. Statik tablolar (Firestore dışı, `gu_data/constants`)

`categories` (8: `k01…k08`, ikon adı + ARB `cat.kXX`), `interests` (16: `i01…i16`, `cat` bağı), `faculties` (`f1…`) ve `departments` (24: `d01…d24`, `faculty`), `places` (10 kurgusal kampüs mekânı `pl01…pl10`), `years` (`prep,1,2,3,4,5plus,master,phd`), `eventTypes` (5), `popularSearches`. Ad/etiketler ARB'dedir. Kaynak: `design/extracted/registry.json` + `tool/seed/demo-data.json`.

## 11. Hesap silme (SET-03)

1. **Ön koşul:** kullanıcı herhangi bir kulübün **başkanıysa** ilerleyemez (devret → MGT-03; TST-X10).
2. Şifre ile **yeniden doğrulama** (`reauthenticate`) + "SİL" yazma (TST-X11, TST-X20 benzeri).
3. **Tek batch/işlem dizisi (anonimleştirme + soft delete):** `users/{uid}`: `name="Silinmiş kullanıcı"`, `bio=''`, `interests=[]`, `avatarPath=null`, `department/year=null`, `status='deleted'`, soft-delete alanları; `private/account`: `email/emailLower=''`, `fcmTokens=[]`; her üyeliğin `private/contact` dokümanı: `email/emailLower=''`; kullanıcının `active` üyelikleri `left` (+`memberCount −1`, `applicant` snapshot boşaltılır), `pending` → `cancelled`; kendi rsvp'leri `cancelled` (+sayaçlar); `notifications`, `savedPosts`, `blocks` → `isDeleted`. **Gönderi ve yorumlar kalır**, yazar "Silinmiş kullanıcı" görünür.
4. Oturum kapatılır → AUT-01 + TST-22. `status=='deleted'` kullanıcı **hiçbir yazma yapamaz** (Rules `isActiveUser()`), tekrar giriş denerse oturum kapatılır.
5. **Auth kimliğinin kendisinin kalıcı silinmesi** istemcide yapılmaz (D-10). Q-11 cevabına göre: yok / Functions ile sunucu tarafı. Apple 5.1.1(v) uygulama içi silme başlatma gereksinimi bu akışla karşılanır; **mağaza gönderimi öncesi** kullanıcıyla netleştirilir.

## 12. Bilinen boşluklar (Claude Code `K-xx` sorusu olarak sorar / planda not düşer)

- **G-1 Danışman hesabı bağlama:** ADM-03 danışmanı yalnızca ad+unvan olarak alır, ama prototip verisinde danışmanın kullanıcı hesabı ve `advisor` üyeliği vardır. Öneri: `clubs.advisor{name,title,userId?}`; hesap bağlama MVP'de `tool/admin/` betiğiyle.
- **G-2 Brief ↔ prototip sayıları:** brief 51 ekran / 34 sheet / 32 dialog / **58 toast** der ve ID'leri prototiple birebir aynıdır; prototip ayrıca brief'te olmayan **20 ek toast** (`TST-X1…X20`: kapalı başvuru, kapalı kayıt, bekleme süresi, kontenjan dolu, yetki yok, DEVRET onayı vb.) içerir → **78 toast**. Kaynak: `registry.json`. Hepsi uygulanır.
- **G-3 Gönderi görselleri:** prototipte `images` yer tutucu tohumlardır (`p02-img1`). Üretimde Storage yüklemesi (Q-19).
- **G-4 Kapak seçimi (SHT-31):** şablon (renk×desen) seçimi mi, yükleme mi — tasarımdaki sheet içeriğine bakılarak Faz 1'de netleşir; öneri şablon + (Q-19 evetse) yükleme.
- **G-5 `members`-only etkinlik bildirimi:** `event_new` ilgi-eşleşmeli kullanıcılara yalnızca **public** etkinlikte gider (prototip davranışı).

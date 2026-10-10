# Firestore / Storage Security Rules ve İndeks Spesifikasyonu

> **Sözleşmedir.** Kaynak: `docs/domain-model.md` (şema, yetki matrisi §3, durum makinesi §5, sayaçlar §4). Claude Code `firebase/firestore.rules`, `firebase/storage.rules`, `firebase/firestore.indexes.json` dosyalarını **bu belgeye göre** yazar ve emülatör testleriyle kanıtlar (`docs/testing.md §6`).
> Buradaki kod blokları **tasarım taslağıdır** (sözdizimi emülatörde doğrulanır); davranış ve kural listesi bağlayıcıdır. Çelişki/boşlukta `AskUserQuestion` ile sor.

## 1. İlkeler

1. **Varsayılan ret.** Açıkça izin verilmeyen her şey reddedilir. Son kural: `match /{document=**} { allow read, write: if false; }`.
2. **`allow delete: if false` her koleksiyonda ve her alt koleksiyonda — süper admin dahil** (D-10). Alan düzeyinde silme (`FieldValue.delete()`, `arrayRemove`) bir *update*'tir ve izinli alan listesindeyse serbesttir.
3. **Yetki Rules'ta uygulanır**, arayüzde gizlemek yetmez (CLAUDE.md §9). Her yeni yazma yolu **aynı commit'te** Rules + indeks + Rules testi içerir.
4. **Beyaz liste (allow-list) alan kontrolü:** her `create`/`update` izinli alan kümesini `hasOnly([...])` ile sınırlar; `diff().affectedKeys()` kullanılır. Bilinmeyen alan = ret.
5. **Sunucu zamanı:** `createdAt/updatedAt/deletedAt` değerleri `request.time`'a eşit olmalıdır (istemci `FieldValue.serverTimestamp()` yazar).
6. **Tip ve sınır doğrulaması:** `is string`, `size()` aralıkları, `in [...]` numaralandırmaları — `Limits` sabitleriyle (domain-model §9) **aynı** sayılar. Parite testi: `tool/` altında Rules metnindeki sayılar ile `Limits` karşılaştırılır (`docs/testing.md §6`, madde 11).
7. **Rules filtre değildir.** Liste sorgusu, kuralın koşulunu **kanıtlayabilmek** için gereken `where` süzgeçlerini taşımak zorundadır (§6 Sorgu sözleşmesi). Aksi halde `permission-denied`.
8. **Erişim çağrısı bütçesi:** tek işlem başına en çok 10, tek istek (batch/transaction) toplamında en çok 20 `get/exists/getAfter`. Kurallar bu yüzden **az sayıda belgeye** bakar (kullanıcı belgesi, o kulübün üyelik belgesi, kulüp belgesi). Aynı belgeye tekrar bakmak tek sayılıyorsa bile bütçe **emülatörde ölçülür**; hesap silme gibi çok işlemli akışlar **parçalara bölünür** (≤ 5 üyelik/parça). Bütçe aşımı bir tasarım hatasıdır, kuralı gevşetmek değil işlemi bölmek çözümdür.
9. Süper admin **yalnızca claim**: `request.auth.token.superadmin == true` (D-28). Firestore alanı yetki vermez.
10. E-posta alan adı kısıtı **Rules'ta da** (D-27): `request.auth.token.email_verified == true` ve `email.lower().matches('.*@(ogr\\.gumushane\\.edu\\.tr|gumushane\\.edu\\.tr)')`. Alan adı listesi `ALLOWED_EMAIL_DOMAINS` ile aynı; parite testi zorunlu.

## 2. Yardımcı fonksiyonlar (taslak)

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // ---- kimlik ----
    function signedIn()   { return request.auth != null; }
    function uid()        { return request.auth.uid; }
    function isSuper()    { return signedIn() && request.auth.token.get('superadmin', false) == true; }
    function emailOk()    { return signedIn() && request.auth.token.email_verified == true
                              && request.auth.token.email.lower().matches('.*@(ogr\\.gumushane\\.edu\\.tr|gumushane\\.edu\\.tr)'); }
    function userPath(id) { return /databases/$(database)/documents/users/$(id); }
    function me()         { return get(userPath(uid())).data; }
    // aktif = e-posta doğrulanmış + kullanıcı belgesi var + askıda/silinmiş değil + profil tamam
    function activeUser() { return emailOk() && exists(userPath(uid())) && me().status == 'active' && me().profileComplete == true; }

    // ---- üyelik ----
    function mPath(c, u)  { return /databases/$(database)/documents/memberships/$(c + '_' + u); }
    function hasM(c)      { return exists(mPath(c, uid())); }
    function myM(c)       { return get(mPath(c, uid())).data; }
    function mActive(c)   { return hasM(c) && myM(c).status == 'active'; }
    function isMember(c)  { return mActive(c) && myM(c).role in ['member','board','president']; }   // yazma yetkili üye
    function isManager(c) { return mActive(c) && myM(c).role in ['board','president']; }
    function isPres(c)    { return mActive(c) && myM(c).role == 'president'; }
    function isAdvisor(c) { return mActive(c) && myM(c).role == 'advisor'; }
    function seesInside(c){ return isSuper() || mActive(c); }                 // gönderi, üye listesi, members-only etkinlik
    function seesMgmt(c)  { return isSuper() || isManager(c) || isAdvisor(c); } // panel (danışman salt okunur)

    // ---- ortak alanlar ----
    function baseCreate() {
      return request.resource.data.createdAt == request.time && request.resource.data.updatedAt == request.time
          && request.resource.data.isDeleted == false
          && request.resource.data.get('deletedAt', null) == null && request.resource.data.get('deletedBy', null) == null;
    }
    function touches(keys) { return request.resource.data.diff(resource.data).affectedKeys().hasOnly(keys.concat(['updatedAt']))
                                  && request.resource.data.updatedAt == request.time; }
    function isSoftDelete(extra) {
      return resource.data.isDeleted == false && request.resource.data.isDeleted == true
          && request.resource.data.deletedBy == uid() && request.resource.data.deletedAt == request.time
          && touches(['isDeleted','deletedAt','deletedBy'].concat(extra));
    }
    function isRestore(extra) {
      return resource.data.isDeleted == true && request.resource.data.isDeleted == false
          && request.resource.data.deletedAt == null && request.resource.data.deletedBy == null
          && touches(['isDeleted','deletedAt','deletedBy'].concat(extra));
    }
    // delta doğrulama (±1) — `getAfter` ile aynı batch içindeki yazımı görür
    function counterDelta(path, field, d) { return getAfter(path).data[field] == get(path).data[field] + d; }
  }
}
```
- `softDelete`/`restore` kimin yapabileceği **koleksiyona özeldir** (§4); `isSoftDelete` yalnızca biçimi doğrular.
- `restore` yalnızca silmeyi yapan (`resource.data.deletedBy == uid()`) ya da süper admin tarafından yapılır (Geri al toast'ı).

## 3. Koleksiyon kuralları

Gösterim: **R** okuma (get/list), **C** create, **U** update, **D** delete (hep `false`). "Aktif" = `activeUser()`.

### 3.1 `users/{uid}`
- **R:** `emailOk()` (doğrulanmış herhangi bir kullanıcı). `isDeleted` süzgeci **yok**: hesabı silinmiş (anonimleştirilmiş, `status=='deleted'`) kullanıcı belgesi de okunur; böylece gönderi/yorum yazarı "Silinmiş kullanıcı" olarak gösterilebilir. Liste sorguları (ADM-05) `isDeleted==false` ekler.
- **C:** `uid == request.auth.uid`, `emailOk()`, belge yok; `status=='active'`, `profileComplete==false`, `staff==false`, `isDeleted==false`; alan beyaz listesi; `name` 2–60.
- **U (sahibi):** `name, avatarSeed, avatarPath, department, year, interests, bio, profileComplete` (+`updatedAt`); `interests.size()` 1–5; `bio.size() <= 140`. `status`, `staff`, `suspendReason`, `isDeleted*` **değişemez** — yalnızca **hesap silme** akışında `status:'deleted'` + anonimleştirme alanları (domain-model §11) tek `update`te izinli (özel dal: `request.resource.data.status=='deleted' && name=='Silinmiş kullanıcı' && bio=='' && interests==[] && …`).
- **U (süper admin):** yalnızca `status` (`active↔suspended`), `suspendReason`.
- **D:** `false`.

### 3.2 `users/{uid}/private/account`
- **R/C/U:** `uid == request.auth.uid` && `emailOk()`; `email`/`emailLower` = `request.auth.token.email` (+lower); `fcmTokens` ≤ 10 eleman. **R** ayrıca süper admin (ADM-05 e-posta araması: `collectionGroup('private')` + `emailLower` aralığı → **kural koleksiyon grubu için ayrıca yazılır**: `match /{path=**}/private/{doc} { allow read: if isSuper(); }`).
- **D:** `false`.

### 3.3 `clubs/{clubId}`
- **R:** `emailOk()` && (`!resource.data.isDeleted` || `isSuper()`). Askıdaki kulüp okunur (kart "askıda" görünümü / yönetici paneli); listeden ayıklamak arayüzdedir.
- **C:** yalnızca `isSuper()` (ADM-03). Alan beyaz listesi, `nameLower` = `name.lower()`, `memberCount == 1` ve **aynı batch'te** `memberships/{clubId}_{presidentId}` (role `president`, `active`) ve `presidentId` tutarlı (`getAfter(mPath(clubId, presidentId)).data.role == 'president'`); danışman girildiyse (G-1) ek `advisor` üyeliği (`memberCount`'a dahil değil). Ad benzersizliği: istemci `nameLower` sorgusuyla kontrol eder, Rules **ikinci savunma** olarak `clubs/{nameLower-index}` kullanmaz — benzersizlik ihlali yönetsel risktir (kabul; K-sorusu adayı).
- **U (yönetim `board|president`):** yalnızca `summary, about, conditions, social, approvalRequired, applicationsOpen, requireNote, palette, pattern, coverSeed, logoPath, coverPath, pinnedPostId`; sınırlar `Limits`. `name, nameLower, categoryId, iconName, founded, status, presidentId` **değişemez** (MGT-09'da kilitli).
- **U (süper admin):** `status, suspendReason` (zorunlu neden), `name/nameLower/categoryId/iconName/founded`, `presidentId` (+aynı batch üyelik tutarlılığı).
- **U (devir — başkan):** `presidentId` yalnızca başkanlık devri batch'inde: `getAfter` ile eski başkan `board`, yenisi `president` (domain-model §5).
- **U (sayaç):** `memberCount` yalnızca üyelik değişimiyle ±1 (§5). Yalnızca `memberCount` + `updatedAt` değişir.
- **D:** `false`.

### 3.4 `memberships/{clubId}_{userId}` ve `/private/contact`
Belge ID'si `clubId + '_' + userId` ile **birebir** eşleşmeli (`request.resource.id == resource/clubId_userId`).

- **R:** (a) `resource.data.userId == uid()`; (b) `seesMgmt(resource.data.clubId)`; (c) üye listesi: `resource.data.status=='active' && mActive(resource.data.clubId)` (sorgu `clubId` + `status=='active'` ile). `pending/rejected/removed/left/cancelled` belgeleri (c)'ye girmez. Üyelik belgesi **e-posta taşımaz** (domain-model §2.4).
- **`/private/contact` R:** sahibi, `seesMgmt(clubId)` (danışman dahil). **C:** başvuran, yalnızca üyelik belgesiyle **aynı batch'te**; `email == request.auth.token.email`. **U:** yalnızca anonimleştirme (`email==''`). **D:** `false`.

**U/C geçiş tablosu** (hepsi `touches([...])` beyaz listesi ve `updatedAt == request.time` ister; "aynı batch" = `getAfter` doğrulaması):

| # | Geçiş | Aktör (Rules'un doğruladığı) | İzinli alanlar | Ek koşullar | Sayaç / yan yazım |
|---|---|---|---|---|---|
| M1 | **create** `pending` (Başvur) | `activeUser()`, `userId==uid()` | tüm başlangıç alanları (`status,role:'member',note,applicant,appliedAt,priorCount:0,…`) | kulüp `status=='active' && applicationsOpen && approvalRequired`; `note.size()<=300 && (!requireNote\|\|note.size()>0)`; `applicant.name==me().name` | `private/contact` (aynı batch); `activity`(isteğe bağlı: yazan başvuran, `kind='application_received'`) |
| M2 | **create** `active` (anında katıl) | aynı | + `role:'member'`, `decidedAt` yok | kulüp `active && applicationsOpen && !approvalRequired` | `memberCount +1` (`counterDelta`) + `activity member_joined` |
| M3 | `left/cancelled → pending\|active` (yeniden) | belge sahibi | `status,note,applicant,appliedAt,priorCount(+1),retryAfter:null,rejectReason:null,rejectNote:null,decidedAt:null,decidedBy:null,role:'member'` | pending→M1 koşulları; active→M2 koşulları | aktifse `+1` |
| M4 | `rejected/removed → pending` (tekrar başvur) | belge sahibi | M3 ile aynı | `resource.data.retryAfter == null \|\| request.time >= resource.data.retryAfter` | — |
| M5 | `pending → active` (Onayla) | `isManager(clubId)` (karar veren ≠ başvuran) | `status,role:'member',decidedAt,decidedBy` | `resource.status=='pending'`; `decidedBy==uid()` | `memberCount +1` + bildirim + `activity` |
| M6 | `pending → rejected` (Reddet) | `isManager` | `status,decidedAt,decidedBy,retryAfter,rejectReason,rejectNote` | `retryAfter == request.time + duration.value(7,'d')`; `rejectReason in [quota,criteria,missing,other]`; `rejectNote.size()<=200` | — |
| M7 | `pending → cancelled` (İsteği iptal) | belge sahibi | `status` | — | — |
| M8 | `active → left` (Ayrıl) | belge sahibi | `status` | `role in [member,board]` (**başkan/danışman ayrılamaz**) | `memberCount −1` + `activity member_left` |
| M9 | `active → removed` (Çıkar) | hiyerarşi: `isPres(c)` `member` ve `board` üyeyi, `isManager(c)` yalnızca `role=='member'`, `isSuper()` `member` ve `board` üyeyi (başkan ve danışman hariç) | `status,decidedAt,decidedBy,retryAfter,rejectReason:'other',rejectNote` | `resource.role in ['member','board']` (başkan: önce devir M11; danışman `memberCount` dışıdır, yalnızca M13 — CD-129) | `−1` + `removed_from_club` bildirimi + `activity` |
| M10 | `role` değişimi (SHT-22) | `isPres(c)` veya `isSuper()` | `role` | yeni rol ∈ `member,board`; `president` rolüne **yalnızca devirle**; hedef `active` ve mevcut rolü ∈ `member,board` (`resource.role in ['member','board']`; danışman rolü yalnızca M13 — CD-129) | `role_changed` bildirimi + `activity` |
| M11 | Devir (SHT-25) | `isPres(c)` veya `isSuper()` | iki belge + `clubs.presidentId` (tek batch) | eski başkan `president→board`, yeni `member\|board→president` (`active`); `clubs.presidentId == yeni` | `role_changed` ×2 |
| M12 | **Geri al** (`active/rejected → pending`) | kararı veren (`resource.data.decidedBy == uid()`) | `status,decidedAt:null,decidedBy:null,retryAfter:null,rejectReason:null,rejectNote:null` | `request.time < resource.data.decidedAt + duration.value(30,'s')` (kararın **sunucu zamanı** ile) | aktifse `−1` |
| M13 | Danışman ata/kaldır (ADM-03 / G-1) | `isSuper()` | `role:'advisor'` belgesi create/`status` | `memberCount`'a dahil değil | — |
| M14 | Hesap silme (SET-03) | belge sahibi | `status` (`active→left`, `pending→cancelled`), `applicant` boşaltma | kullanıcı `status` aynı işlemde `deleted`'a gidiyor | `memberCount −1` |

- **Aynı kulüpte tek başkan:** `isPres` yalnızca devirle değişir (M11). `clubs.presidentId` ile üyelik tutarlılığı `getAfter` ile doğrulanır.
- **Çakışma (DLG-18):** M5–M7, M9, M12'de `resource.data.status` beklenen değerde değilse kural **reddeder**; istemci `permission-denied` yerine işlem içi okuma yaparak önce DLG-18'i gösterir (transaction'da beklenen durum doğrulanır).
- **D:** `false`.

### 3.5 `posts/{postId}`
- **R:** `emailOk()` && `seesInside(resource.data.clubId)` && (`!resource.data.isDeleted` || yazar/yönetici/süper) && (`!resource.data.isHidden` || yazar/yönetici/süper). Üyelik dışı kullanıcı gönderi **okuyamaz**.
- **C:** `isManager(clubId)` (CLB yönetimi: `createPost`), `authorId==uid()`, `activeUser()`; `type in [post,announcement,poll]`; `text.size()<=1000`; `title`: duyuruda zorunlu 1–80; `images.size()<=4`; `poll`: yalnız `type=='poll'`, `options.size() in 2..4`, `endsAt` ∈ now+1/3/7 gün; `likes==[] && likeCount==0 && commentCount==0 && pinned==false && isHidden==false`; `pushSent` yalnız `type=='announcement'`. **`pushSent==true`** ise `announcementCounters/{clubId}_{gün}` `count` +1 ve `≤ 2` (§5).
- **U (yazar):** `text,title,images,editedAt` (poll seçenekleri oy başladıktan sonra **değişmez**), soft delete (`isSoftDelete(['commentCount'?])` hayır — yalnız silme alanları).
- **U (yönetici):** `pinned` + aynı batch'te `clubs.pinnedPostId` (eski sabitlenmiş gönderinin `pinned:false`'u da aynı batch); soft delete (başkasının gönderisi, `moderateContent`); restore.
- **U (süper admin):** `isHidden, hiddenBy, hiddenAt` (şikayet çözümü "removed"), soft delete.
- **U (üye — beğeni):** yalnızca `likes`, `likeCount` (+`updatedAt` **değişmez**: beğeni `updatedAt`'i etkilemez → bu alan beyaz listede yok): `likes` ya `arrayUnion([uid])` (uid yoktu, `likeCount +1`) ya `arrayRemove([uid])` (vardı, `−1`); `isMember(clubId)` (**danışman beğenemez**).
- **D:** `false`.

`posts/{postId}/votes/{uid}`:
- **R:** `seesInside(post.clubId)` (sonuç sayımı için; **anonimlik arayüzdedir**, kabul edilmiş sınırlama §9).
- **C:** `request.resource.id == uid()`, `isMember(post.clubId)` (danışman/süper oy veremez), anket `type=='poll'`, `request.time < post.poll.endsAt`, `optionId` mevcut seçeneklerden, gönderi silinmemiş. **U/D:** `false` (oy değiştirilemez, TST-10).

### 3.6 `comments/{commentId}`
- **R:** `seesInside(resource.data.clubId)` && `!isDeleted` && `!isHidden` (yazar/yönetici/süper hariç).
- **C:** `isMember(clubId)` (danışman yorum yapamaz), `activeUser()`, `authorId==uid()`, `clubId == get(post).clubId`, gönderi silinmemiş, `text.size() in 1..500`, `isHidden==false`; **aynı batch'te** `posts.commentCount +1` (`counterDelta`).
- **U:** yazar soft delete / restore; `isManager` ve `isSuper` (başkasının yorumu, `moderateContent`) soft delete / restore. Silme ⇒ `commentCount −1`; restore ⇒ `+1` (aynı batch). Süper admin `isHidden*`.
- **D:** `false`.

### 3.7 `events/{eventId}`
- **R:** `emailOk()` && `!isDeleted` (yönetici/süper hariç) && aşağıdakilerden biri:
  - `status in ['published','cancelled'] && visibility=='public'`;
  - `status in ['published','cancelled'] && visibility=='members' && seesInside(clubId)`;
  - `status=='draft' && seesMgmt(clubId)`.
- **C:** `isManager(clubId)`; `createdBy==uid()`; `status in ['draft','published']`; `endsAt > startsAt`; yayında `startsAt > request.time`; `capacity==null \|\| capacity>=1`; `goingCount==waitlistCount==attendedCount==0`; `title<=80`, `desc<=1000`; `type` ∈ 5 tür; kulüp `status=='active'` (askıdaki kulüp etkinlik açamaz).
- **U (yönetici):** içerik alanları; `status` geçişleri: `draft→published` (+`publishedAt`), `published→draft` (TST-X19; `goingCount==0` değilse **reddedilir**: kayıtlı varken taslağa alınamaz — K-sorusu adayı, öneri: yalnızca kayıt yokken), `published→cancelled` (+`cancelReason.size()>0`); `cancelled` geri dönmez; `capacity >= goingCount`; `registrationOpen`; soft delete **yalnızca `draft`** (DLG-31) ve geri al.
- **U (sayaç):** `goingCount/waitlistCount/attendedCount` yalnızca rsvp değişimiyle ±1 (§5); katılımcı `going/waitlist` değişimini kendi rsvp'siyle birlikte yazar.
- **D:** `false`.

### 3.8 `rsvps/{eventId}_{userId}`
- **R:** sahibi; `seesMgmt(resource.data.clubId)`; süper admin. (Katılımcı listesi sorgusu `eventId` **ve** `clubId` süzgeçlerini taşır.)
- **C (Katıl):** `activeUser()`, `userId==uid()`, etkinlik `published && registrationOpen && endsAt > request.time`, `visibility=='members'` ise `isMember(clubId)`; `status=='going'` ⇒ (`capacity==null \|\| goingCount < capacity`) ve `goingCount +1`; aksi halde `status=='waitlist'` ve `waitlistCount +1`, `waitlistAt==request.time`; `ticketCode` formatı `GU-[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}` (32'lik alfabe: I ve O yok, 0/1 yok); `reminder in [none,1h,1d]`.
- **U (sahibi):** `reminder` (yalnızca `going/waitlist` iken); `going→cancelled` (`goingCount −1`), `waitlist→cancelled` (`waitlistCount −1`), `cancelled→going/waitlist` (yeniden katıl, yeni sayaç kuralı, **aynı `ticketCode` korunur**).
- **U (yönetici):** `going→attended` (`attendedCount +1`, `scannedAt==request.time`, `scannedBy==uid()`), `attended→going` (`−1`), `waitlist→going` (terfi: `goingCount +1`, `waitlistCount −1`, kontenjan kontrolü, `waitlist_promoted` bildirimi); etkinlik `published` ve (yoklama için) `startsAt - 2sa <= request.time <= endsAt + 6sa` penceresi — pencere dışı ret (K-sorusu adayı, öneri: açık).
- **D:** `false`.

### 3.9 `notifications/{id}`
- **R:** `userId == uid()` (silinmişler dahil → Geri al). Sorgu: `where userId == uid`.
- **U (sahibi):** `read` (`false→true`, toplu okundu), soft delete / restore.
- **C:** Mod F: **yalnız Functions** (Admin SDK Rules'u atlar) ⇒ istemci için `allow create: if false`. Mod C: `ClientFanOutDispatcher` — izinli, **tür-bazlı** koşullarla: `userId != uid()` ise `type` yazanın yetkisiyle uyumlu olmalı: `application_received` (yazan = `refs.applicantId == uid()`, hedef kulüp yöneticisi), `application_approved/rejected/removed_from_club/role_changed` (yazan `isManager(refs.clubId)` veya `isSuper()`), `announcement/event_new/event_cancelled/waitlist_promoted` (yazan `isManager(refs.clubId)`), `report_resolved/new_report/system` (`isSuper()`; `new_report` ayrıca şikayeti açan), alan beyaz listesi, `read==false`. Alıcının gerçekten üye olup olmadığı **doğrulanmaz** (bütçe) — kabul edilmiş sınırlama §9.
- **Kimlik tekilliği (CD-129; T-25):** belge kimliği deterministiktir (`{type}_{refId}_{userId}`, `FirestoreIds.notification`). Var olan belgeye ikinci `set` **update** sayılır ve update yalnızca sahibine açıktır; bu yüzden tekrarlanabilen olaylarda (onayla → geri al → yeniden onayla, rol değişimi + devir, çıkar → geri al → çıkar, yeniden başvuru, yeniden yayın, terfi) `refId` **olay başına tekil** üretilir — aksi halde yazım, içinde olduğu kritik batch ile birlikte reddedilir. Kimlik şeması T-25 planında kesinleşir; Rules testi: "aynı tür/ref/alıcı için ikinci olay yazılabilir".
- **D:** `false`.

### 3.10 `reports/{reporterId}_{targetType}_{targetId}`
- **C:** `activeUser()`, `reporterId==uid()`, belge ID biçimi, `reason` ∈ 5, `note<=300`, `status=='open'`, `action==null`; hedef için kendi kendini şikayet yok (`targetType=='user'` ise `targetId != uid()`).
- **R:** sahibi (kendi şikayeti) ve `isSuper()`. **U:** `isSuper()` — `status:'resolved', action, resolvedAt, resolvedBy` (grup çözümü aynı batch). **D:** `false`.

### 3.11 `activity/{id}`
- **R:** `seesMgmt(resource.data.clubId)`. **C:** işlemi yapan kullanıcı (`actorId==uid()`) ve `kind` ile yetki uyumu (örn. `member_removed` ⇒ `isManager`/`isSuper`; `member_joined` ⇒ kendisi) — **ve aynı batch'te** ilgili asıl yazım bulunmalı (`getAfter` ile üyelik/etkinlik/gönderi değişimi). **U/D:** `false` (değiştirilemez günlük).

### 3.12 `settings/{uid}`
- **R/C/U:** `uid == request.auth.uid` && `emailOk()`; alan beyaz listesi; `quietFrom/quietTo` `HH:mm` regex; `reminderTime in [1h,1d]`. **D:** `false`.

### 3.13 `blocks/{blockerId}_{blockedId}`
- **R/C/U:** `blockerId == uid()`; kendini engelleme yok (`blockedId != uid()`); engel kaldırma = `isSoftDelete`; yeniden engelleme/Geri al = `isRestore`. **D:** `false`.

### 3.14 `savedPosts/{userId}_{postId}`
- **R/C/U:** `userId == uid()`; **C** için `seesInside(clubId)`; kaldır = `isSoftDelete`, kaydet/Geri al = `isRestore`. **D:** `false`.

### 3.15 `supportTickets/{id}`
- **C:** `activeUser()`, `userId==uid()`, `status=='open'`, `message<=500`, `ticketNo` formatı, `attachmentPaths.size()<=1` ve yol `support/{ticketNo}/…`. **R:** sahibi, `isSuper()`. **U:** `isSuper()` (`status`). **D:** `false`.

### 3.16 `announcementCounters/{clubId}_{yyyyMMdd}`
- **R:** `seesMgmt(clubId)` (FED-03 hak çubuğu).
- **C/U:** yalnız `isManager(clubId)` ve **aynı batch'te** `type=='announcement' && pushSent==true` olan gönderi yazımıyla; `count == önceki+1` (yoksa `1`), `count <= 2`; belge ID günü = `request.time + duration.value(3,'h')` Istanbul günü (`yyyyMMdd`); `day` alanı buna eşit. **D:** `false`.
- **Saat kayması (CD-129; T-19):** gün eşitliği **toleranssızdır** (CD-32 toleransı yalnızca `retryAfter` ve `poll.endsAt` içindir). İstemci günü cihaz saatinden hesaplar; cihaz saati kaymışsa Istanbul gün sınırının yakınında yanlış gün anahtarı üretir ve yazım reddedilir. İstemci, `permission-denied` alır ve cihaz saati gün sınırına `clockSkewTolerance` (5 dk) içindeyse komşu gün anahtarıyla **bir kez** yeniden dener. Rules testi: "gün sınırında yanlış gün ret / doğru gün geçer".

### 3.17 Her şeyin altı
`match /{document=**} { allow read, write: if false; }` — yukarıda adı geçmeyen koleksiyon/alt koleksiyon kapalıdır.

## 4. Sayaç tutarlılığı (`getAfter`) özeti

| Sayaç | İzinli değişim | Doğrulanan eşlik eden yazım |
|---|---|---|
| `clubs.memberCount` | ±1 | `memberships` M2/M3(active)/M5/M8/M9/M12/M14 |
| `events.goingCount` | ±1 | `rsvps` (create going / going→cancelled / waitlist→going / …) |
| `events.waitlistCount` | ±1 | `rsvps` |
| `events.attendedCount` | ±1 | `rsvps` going↔attended |
| `posts.likeCount` | ±1 | aynı belgedeki `likes` dizisinin uzunluk değişimi (`likes.size()`) |
| `posts.commentCount` | ±1 | `comments` create / soft delete / restore |
| `announcementCounters.count` | +1 | `posts` create (`announcement && pushSent`) |

Kural: sayaç **hiçbir zaman** mutlak değer olarak serbest yazılmaz; her sayaç yazımı yukarıdaki eşlik eden yazımla birlikte ve tam ±1'dir. Sayaç bozulması (örn. elle düzeltme) süper admin betiğiyle (`tool/admin/`) yapılır, istemciyle değil.

## 5. Mod C bildirim fan-out sınırı

Mod C'de bir işlem çok alıcıya yazar (duyuru → tüm üyeler). Erişim çağrısı bütçesi nedeniyle fan-out **parçalı** yapılır (batch başına en çok N alıcı; N emülatör ölçümüyle belirlenir, tahmini ≤ 400 yazma ama kural çağrıları ≤ 20 olacak şekilde kuralın alıcı başına `get` yapmaması şart). Duyuru yayını: önce gönderi + sayaç batch'i (kritik), ardından bildirim parçaları (en iyi çaba; başarısız parça tekrar denenir, kullanıcıya hata göstermez). Mod F'de bu bölüm gereksizdir (Function yazar).

## 6. Sorgu sözleşmesi (Rules'un kabul etmesi için gereken süzgeçler)

| Liste / ekran | Koleksiyon | Zorunlu süzgeçler (Rules'a kanıt) | Sıralama / sayfa |
|---|---|---|---|
| CLB-01/02 kulüp listesi | `clubs` | `isDeleted==false` | `nameLower` ya da istemci sıralama; tümü bir kez çekilir (≤ 50) |
| CLB-03 kulüp | `clubs/{id}` get | — | — |
| Oturum üyelikleri | `memberships` | `userId==uid` | canlı akış |
| CLB-06 üye listesi | `memberships` | `clubId==X`, `status=='active'` | `appliedAt`; sayfa 20 |
| MGT-02 başvurular | `memberships` | `clubId==X`, `status=='pending'` | `appliedAt` ↓ |
| MGT-03 üye yönetimi | `memberships` | `clubId==X`, `status=='active'` (+ rol süzgeci istemci) | — |
| Başvuran e-postası | `memberships/{id}/private/contact` get | — | tek tek (SHT-19) |
| FED-01 gönderi akışı | `posts` | `clubId==X`, `isDeleted==false`, `isHidden==false` | `createdAt` ↓, 20 + imleç |
| MGT-08 içerik yönetimi | `posts` | `clubId==X`, `isDeleted==false` | `createdAt` ↓ |
| FED-02 yorumlar | `comments` | `postId==P`, `clubId==X`, `isDeleted==false`, `isHidden==false` | `createdAt` ↑ canlı |
| Oy sonuçları | `posts/{id}/votes` | — (üye) | `count()` toplama veya tüm belgeler |
| EVT-01 herkese açık | `events` | `visibility=='public'`, `status in ['published','cancelled']`, `isDeleted==false` | `startsAt` ↑, `startsAt >= now-…` |
| EVT-01 üyeye özel | `events` | **her üye olunan kulüp için ayrı sorgu:** `clubId==X`, `visibility=='members'`, `status in […]`, `isDeleted==false` | istemci birleştirir (`whereIn` + `get()`'li kural **çalışmaz**) |
| MGT-04 yönetici | `events` | `clubId==X`, `isDeleted==false` | `startsAt` ↓ |
| EVT-04 / PRF-03 | `rsvps` | `userId==uid`, `isDeleted==false` | — |
| MGT-06 katılımcılar | `rsvps` | `eventId==E`, `clubId==X` | `status`, `waitlistAt` |
| NTF-01 bildirimler | `notifications` | `userId==uid`, `isDeleted==false` | `createdAt` ↓, canlı |
| MGT-10 faaliyet | `activity` | `clubId==X` | `createdAt` ↓, 20 + imleç |
| ADM-04 şikayetler | `reports` | `status=='open'` (süper) | `createdAt` ↓; gruplama istemci |
| ADM-05 kullanıcılar | `users` | `isDeleted==false` (+ `nameLower` aralık) | `nameLower` |
| ADM-05 e-posta arama | `collectionGroup('private')` | `emailLower` aralığı | — |
| PRF-04 kaydedilenler | `savedPosts` | `userId==uid`, `isDeleted==false` | `savedAt` ↓ |
| SET-02 engelliler | `blocks` | `blockerId==uid`, `isDeleted==false` | — |

## 7. Storage Rules

```
service firebase.storage {
  match /b/{bucket}/o {
    match /users/{uid}/{file}        { allow read: if signedInVerified(); allow create: if request.auth.uid == uid && imageOk(); allow update, delete: if false; }
    match /clubs/{clubId}/{file}     { allow read: if signedInVerified(); allow create: if isManagerOf(clubId) && imageOk(); allow update, delete: if false; }
    match /posts/{postId}/{file}     { allow read: if signedInVerified(); allow create: if <Firestore post yazarı> && imageOk(); allow update, delete: if false; }
    match /support/{ticket}/{file}   { allow read: if isSuperAdmin(); allow create: if signedInVerified() && imageOk(); allow update, delete: if false; }
  }
}
function imageOk() { return request.resource.contentType.matches('image/.*') && request.resource.size < 5 * 1024 * 1024; }
```
- Dosya adı **benzersiz** (zaman damgası/UUID); mevcut dosya **üzerine yazılmaz** (`update: false`) ve silinmez. Değiştirme = yeni dosya + Firestore yol alanı (`avatarPath` vb.) güncelleme (D-10, architecture §10).
- Storage Rules'tan Firestore'a `firestore.get()` / `firestore.exists()` çapraz kullanım yalnızca gerekirse (kulüp rolü kontrolü); maliyet/bütçe farkındalığıyla.
- Q-19 "yükleme yok" seçilirse bu bölüm yalnızca kilit (`allow read, write: if false`) olur.

## 8. İndeksler (`firebase/firestore.indexes.json`)

Bileşik indeksler (alan sırası sorgu sırasıdır; Claude Code gerçek sorgulardan emülatör hatalarıyla doğrular, **eksik indeks = hata**):

| Koleksiyon | Alanlar |
|---|---|
| `memberships` | (`userId` ↑, `status` ↑) · (`clubId` ↑, `status` ↑, `appliedAt` ↓) · (`clubId` ↑, `status` ↑, `role` ↑) |
| `posts` | (`clubId` ↑, `isDeleted` ↑, `isHidden` ↑, `createdAt` ↓) · (`clubId` ↑, `isDeleted` ↑, `createdAt` ↓) |
| `comments` | (`postId` ↑, `clubId` ↑, `isDeleted` ↑, `isHidden` ↑, `createdAt` ↑) |
| `events` | (`visibility` ↑, `status` ↑, `isDeleted` ↑, `startsAt` ↑) · (`clubId` ↑, `visibility` ↑, `status` ↑, `isDeleted` ↑, `startsAt` ↑) · (`clubId` ↑, `isDeleted` ↑, `startsAt` ↓) |
| `rsvps` | (`userId` ↑, `isDeleted` ↑, `createdAt` ↓) · (`eventId` ↑, `clubId` ↑, `status` ↑, `waitlistAt` ↑) |
| `notifications` | (`userId` ↑, `isDeleted` ↑, `createdAt` ↓) |
| `activity` | (`clubId` ↑, `createdAt` ↓) · (`clubId` ↑, `kind` ↑, `createdAt` ↓) |
| `reports` | (`status` ↑, `createdAt` ↓) · (`targetType` ↑, `targetId` ↑, `status` ↑) |
| `savedPosts` | (`userId` ↑, `isDeleted` ↑, `savedAt` ↓) |
| `blocks` | (`blockerId` ↑, `isDeleted` ↑) |
| `supportTickets` | (`userId` ↑, `createdAt` ↓) |
| `users` | (`isDeleted` ↑, `nameLower` ↑) |
| koleksiyon grubu `private` | tek alan `emailLower` (koleksiyon grubu kapsamı) |

## 9. Kabul edilmiş sınırlamalar (kullanıcıya bir kez bildirilir, `docs/PLAN.md` "Riskler"e yazılır)

1. **Profil okuma:** `users/{uid}` tüm doğrulanmış kullanıcılarca okunabilir; "ortak kulüp yoksa gizle" yalnızca arayüzdedir (D-29).
2. **Oy anonimliği:** oy belgeleri üyelerce okunabilir; arayüz kimin ne oy verdiğini göstermez.
3. **Mod C fan-out:** alıcının üyeliği Rules'ta doğrulanmaz; kötü niyetli bir **yönetici** başka kullanıcılara bildirim yazabilir (spam). Mod F'de yok.
4. **Kulüp adı benzersizliği** istemci kontrolüne dayanır (yarış durumu mümkün, süper admin tek kişi → pratikte düşük risk).
5. **Askıdaki kulübün etkinlikleri** listede Rules'la değil istemciyle gizlenir (kural per-belge `get` yapamaz).
6. **Silinmiş-anonim kullanıcı** belgeleri ve içerikleri kalıcıdır (soft delete politikası); KVKK "silme" talebi için kalıcı temizlik süreci kullanıcıyla ayrıca netleştirilir (Q-11).
7. Zorunlu güncelleme/bakım (Remote Config) Rules'tan bağımsızdır; eski istemci Rules'a takılırsa DLG-26.

## 10. Süper admin kurulumu

`tool/admin/set_superadmin.js` (Firebase Admin SDK, **kullanıcının kendi makinesinde**, servis hesabı anahtarı repoya girmez — D-36): `admin.auth().setCustomUserClaims(uid, {superadmin:true})`. Claim ID token yenilenince etkinleşir (istemci `getIdTokenResult(true)`); `SessionViewModel` claim'i okur. Rules testleri claim'i `withCustomClaims`/`authenticatedContext(uid, {superadmin:true})` ile simüle eder.

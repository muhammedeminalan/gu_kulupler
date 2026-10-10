# Soft Delete Politikası (D-10)

> **Kullanıcının açık talimatı:** uygulamada **hiçbir yerde hard delete yok**. Bu doküman politikayı, API'yi, sorgu kurallarını ve istisna olmayan sınırı tanımlar. `tool/check_no_hard_delete.sh` kod tabanında ihlali yakalar; `firestore.rules` / `storage.rules` sunucu tarafında kilitler.

## 1. Üç kavram — karıştırma

| Kavram | Ne | Alan | Örnek |
|---|---|---|---|
| **İçerik silme** (soft delete) | Kaydı kullanıcıdan gizler, veri kalır | `isDeleted:true, deletedAt, deletedBy, updatedAt` | gönderi, yorum, taslak etkinlik, bildirim, kaydedilen, engel |
| **Durum geçişi** | İş akışı durumu; kayıt "silinmez" | `status` | üyelik `left/removed/cancelled`, rsvp `cancelled`, etkinlik `cancelled` |
| **Alan temizleme** | Belge kalır, tek alan boşalır | `FieldValue.delete()` / `arrayRemove` / `null` | FCM jetonu çıkarma, oy sonrası değil |

- Kullanıcıya görünen metinler ("silinecek", "kaldırıldı") **değişmez**; altındaki veri soft delete edilir.
- *Durum geçişi* olan yerlere `isDeleted` **yazılmaz** (üyelik `left` ≠ silinmiş).

## 2. Ortak alanlar (`BaseFields`) — her belgede

```
createdAt   Timestamp (sunucu)       isDeleted  bool (varsayılan false)
updatedAt   Timestamp (sunucu)       deletedAt  Timestamp?   (silinince sunucu zamanı)
createdBy   string? (gerekliyse)     deletedBy  string?      (silen uid)
```
- Model tarafı: `BaseFields` mixin/yardımcı `gu_data/lib/src/core/base_fields.dart`; `fromJson/toJson` `Timestamp`↔`DateTime(UTC)` dönüştürücüsüyle.
- Alan adları sabit: `FirestoreFields.isDeleted` vb. Elle string yok (D-15).

## 3. API (tek yol)

`gu_data/lib/src/core/soft_delete.dart`:

```dart
abstract final class SoftDelete {
  /// Silme yükü: isDeleted:true, deletedAt:serverTimestamp, deletedBy:uid, updatedAt:serverTimestamp
  static Map<String, Object?> payload({required String actorId});
  /// Geri alma yükü: isDeleted:false, deletedAt:null, deletedBy:null, updatedAt:serverTimestamp
  static Map<String, Object?> restorePayload();
  /// Rules ile eşleşen izinli anahtar kümesi (test/doğrulama için)
  static const Set<String> affectedKeys = {'isDeleted','deletedAt','deletedBy','updatedAt'};
}
```

Servis arayüzü (örnek `FirestoreService`):

```dart
Future<FirestoreResult<void>> softDelete(DocumentReference ref, {required String actorId, WriteBatch? batch});
Future<FirestoreResult<void>> restore(DocumentReference ref, {WriteBatch? batch});
// delete / deleteDoc / batch.delete → YAZILMAZ. Arayüzde bulunmaz.
```

- Repository'ler alan dilinde sunar: `postRepository.softDeletePost(postId)`, `restorePost`. `deletePost` adlı metot **yoktur**.
- Toplu işlemler (hesap anonimleştirme, rapor grubu çözümü) `WriteBatch`/`Transaction` içinde `softDelete`'i kullanır; **sayaçlar aynı batch'te** (domain-model §4).
- Batch kipinde (`batch:` verilerek) çağrılan `softDelete` / `restore` başarısız olursa (boş `actorId` dahil) batch **geçersiz** sayılır: `commitBatch` hiçbir yazımı uygulamaz ve o hatayı döner — sayaç tek başına düşmez (CD-131). `commitBatch` gövdesi eşzamanlıdır; bu çağrıların sonucu gövdede beklenmez.
- **Geri al (toast):** `restore` aynı belgeyi `isDeleted:false` yapar; kural gereği yalnızca silen (`deletedBy`) veya süper admin yapabilir.

## 4. Okuma kuralı

Her liste/okuma sorgusu **`isDeleted == false`** süzer (Rules sorgu sözleşmesi, `firestore-rules-spec.md §6`).

```dart
// repository içinde tek yardımcı:
Query<T> notDeleted<T>(Query<T> q) => q.where(FirestoreFields.isDeleted, isEqualTo: false);
```

- İstisna: sahibinin kendi *geri alınabilir* silmelerini görmesi gereken yerler (Geri al toast'ı yalnızca bellekteki referansla çalışır; liste yeniden `isDeleted==false` ile çekilir).
- Tekil `get` ile gelen belge `isDeleted==true` ise repository `NotFound`'a çevirir (SYS-04 akışı: "Bu içerik artık yok").
- Silinmiş içeriğe işaret eden bildirim/derin bağlantı → SYS-04.
- Sayaçlar silinmiş kayıtları **dışlar** (soft delete aynı batch'te sayacı düşürür).

## 5. Hangi varlık nasıl "silinir"

| Varlık | Kullanıcı eylemi (ekran/diyalog) | Teknik karşılık | Kim | Geri al |
|---|---|---|---|---|
| Gönderi | Sil (DLG-10) / İçeriği kaldır (DLG-29, TST-51) | `posts.isDeleted` (+ sabitliyse `clubs.pinnedPostId` temizlenir) | yazar; yönetici (başkasınınki); süper | Yazar: yok (diyalog onaylı); moderatör: TST-45 Geri al |
| Yorum | Sil (DLG-11) | `comments.isDeleted` + `posts.commentCount −1` | yazar; yönetici; süper | TST-45 |
| Taslak etkinlik | Sil (DLG-31) | `events.isDeleted` (**yalnız `draft`**) | yönetici | TST-45 |
| Yayındaki etkinlik | İptal et (DLG-23) | `events.status='cancelled'` (**silme değil**) | yönetici | — |
| Bildirim | Kaydır-sil (TST-16) | `notifications.isDeleted` | sahibi | TST-16 Geri al |
| Kaydedilen | Kaldır (TST-11) | `savedPosts.isDeleted` | sahibi | TST-11 Geri al |
| Engel | Engeli kaldır | `blocks.isDeleted` | sahibi | yeniden engelle = restore |
| Üyelik | Ayrıl/çıkar/iptal | `memberships.status` (durum geçişi) | bkz. domain-model §5 | Yönetici kararı 30 sn |
| Katılım | Vazgeç (DLG-14) | `rsvps.status='cancelled'` | sahibi | yeniden katıl |
| Son aramalar | Temizle (TST-06) | yerel (`shared_preferences`) — Firestore değil | sahibi | TST-06 Geri al |
| Hesap | Hesabı sil (SET-03) | **anonimleştirme + `users.status='deleted'`** (domain-model §11) | sahibi | yok |
| Oy | — | **silinmez, değiştirilemez** | — | — |
| Şikayet | Çöz (ADM-04) | `reports.status='resolved'` | süper | — |
| Faaliyet günlüğü | — | **değiştirilemez / silinemez** | — | — |
| Storage dosyası | Fotoğraf değiştir | yeni dosya + yol alanı; **eski dosya silinmez** | — | — |
| Auth kimliği | Hesap silme | istemcide `user.delete()` **yok**; kalıcı kaldırma Q-11'e göre | — | — |

## 6. Yasaklı çağrılar (kod tabanı taraması)

`tool/check_no_hard_delete.sh` (`lib/`, `packages/*/lib`, `functions/src`, `tool/` — test dizinleri hariç; Rules testleri `delete` reddini **doğrulamak için** çağırabilir ve bu dizin taramadan hariçtir):

- Dart: `.delete(` (Firestore `DocumentReference`/`WriteBatch`/`Transaction`, Storage `Reference`, Auth `User`), `deleteDoc`, `.deleteApp`, `FieldValue.delete()` **belge-düzeyinde değil** alan temizlemede serbest (ayrı beyaz liste: `// allow-field-delete: <gerekçe>` yorumu zorunlu), `recursiveDelete`, `listDocuments().*delete`.
- TS (functions): `.delete()`, `recursiveDelete`, `bulkWriter.delete`.
- Rules: `allow delete` ifadesi `if false` dışında olamaz; `allow write` (create+update+delete birlikte) **yasak** (delete'i kapsadığı için) — yalnızca ayrı `create/update`.
- **Belge/dosya/hesap silme için satır içi istisna yok** (hardcode'dan farklı olarak `ignore` yorumu kabul edilmez); tek işaretleyici alan temizleme içindir (`// allow-field-delete: <gerekçe>`). Gerçekten gerekliyse `AskUserQuestion` ile kullanıcıya sorulur (karar defterine yazılır).

## 7. Testler

- **Birim:** `SoftDelete.payload/restorePayload` alan kümesi; her servis `softDelete/restore` ve `delete` metodunun **bulunmadığı** (reflection yerine arayüz testi: `abstract` sınıfta `delete` sembolü yok — derleme zamanı garantisi, `tool/check_no_hard_delete.sh` ile).
- **Repository:** silinen kayıt listeden düşer, sayaç düşer, Geri al listede geri getirir.
- **Rules (emülatör):** her koleksiyon için `delete` hata verir (anonim, sahibi, yönetici, başkan, süper admin); `softDelete` yalnızca yetkili rolde geçer; izinsiz alanla `softDelete` reddedilir; başkasının kaydını `restore` reddedilir.
- **Kalite kapısı:** `check_no_hard_delete.sh` her commit'te.

## 8. KVKK notu

Soft delete veriyi **kalıcı tutar**. Kişisel veri silme talebi (KVKK m.7) için: hesap silme akışı kişiyi **anonimleştirir** (ad, e-posta, biyografi, avatar, ilgi alanları boşaltılır); içerik (gönderi/yorum) yazar adı olmadan kalır. Kalıcı fiziksel silme (veritabanı temizliği) gerekiyorsa bu **uygulama dışı, yönetici-tarafı bir işlemdir** ve Q-11 cevabıyla kullanıcı tarafından yetkilendirilir; istemci koduna **eklenmez**.

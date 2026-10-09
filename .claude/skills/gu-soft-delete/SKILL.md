---
name: gu-soft-delete
description: Uygulamada hard delete olmadığını uygulatır; silme/geri alma işlemlerini SoftDelete API'siyle yazdırır. Silme, kaldırma, geri alma, iptal, hesap silme, Storage dosyası değiştirme veya herhangi bir .delete( çağrısı söz konusu olduğunda kullan.
---

# gu-soft-delete — D-10 (kullanıcının açık talimatı)

Tam politika: `docs/soft-delete.md`. **Hiçbir yerde hard delete yok.** `tool/check_no_hard_delete.sh` her commit'te, Rules sunucuda (`allow delete: if false`) kilitler.

## Üç kavramı karıştırma

| Kavram | Yaz | Örnek |
|---|---|---|
| İçerik silme | `isDeleted:true, deletedAt, deletedBy, updatedAt` | gönderi, yorum, taslak etkinlik, bildirim, kaydedilen, engel |
| Durum geçişi | `status` | üyelik `left/removed/cancelled`, rsvp `cancelled`, etkinlik `cancelled` (**`isDeleted` yazılmaz**) |
| Alan temizleme | `FieldValue.delete()` / `arrayRemove` / `null` | FCM jetonu çıkarma (`// allow-field-delete: <gerekçe>` zorunlu) |

## API

```dart
// gu_data — tek yol
await firestoreService.softDelete(ref, actorId: uid, batch: batch);   // SoftDelete.payload(actorId: uid)
await firestoreService.restore(ref, batch: batch);                    // SoftDelete.restorePayload()
```

- Repository: `softDeletePost`, `restorePost`, `softDeleteComment`… **`delete*` metodu yazılmaz.**
- **Sayaç aynı batch/transaction'da** düşer/artar (`commentCount`, `likeCount`, `memberCount`, `goingCount`…). Sabitlenmiş gönderi silinince `clubs.pinnedPostId` temizlenir.
- Geri al (toast): aynı belge `restore`; yalnızca silen (`deletedBy`) veya süper admin.
- Okuma: tekil `get` → `isDeleted == true` ise `NotFound` (→ SYS-04); listeler `isDeleted == false`.
- Alan adları `FirestoreFields.*` sabitlerinden; elle string yok.

## Tabloya bak

Hangi varlık nasıl "silinir" → `docs/soft-delete.md §5` (gönderi, yorum, taslak etkinlik, bildirim, kaydedilen, engel, üyelik, rsvp, hesap, oy, şikayet, faaliyet günlüğü, Storage, Auth). Tabloda olmayan bir silme gerekiyorsa **dur ve `gu-ask-user`**.

## Hesap silme (SET-03)

Anonimleştirme + soft delete + durum geçişleri; Auth kimliği istemcide silinmez (`user.delete()` yok). Q-11 cevabı belirler. Parçalı işlem (erişim bütçesi). `docs/domain-model.md §11`.

## Storage

Dosya silinmez; değiştirme = yeni dosya adı + belge alanı güncelleme; eski dosya yetim kalır. Storage Rules `allow delete: if false`.

## Testler

`SoftDelete.payload/restorePayload` alan kümesi · her servisin `softDelete/restore` davranışı · silinen kayıt listeden düşer, sayaç düşer, Geri al geri getirir · Rules: her koleksiyonda `delete` reddi, izinsiz alanla softDelete reddi, başkasının kaydını restore reddi.

## Hook uyarısı geldiyse

`PostToolUse` hook'u `.delete(` bulduysa çağrıyı **sil** ve `softDelete/restore`'a çevir; susturma/yorumla geçme yok.

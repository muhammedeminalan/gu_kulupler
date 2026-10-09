---
name: gu-firebase-model
description: Firestore/Storage veri katmanı işleri (model, servis, repository, Security Rules, indeks, seed, Rules testi, sayaç batch'leri, bildirim üretimi). Yeni koleksiyon, yazma yolu, sorgu veya rol/yetki kuralı eklerken ya da değiştirirken kullan.
---

# gu-firebase-model — veri, Rules, indeks

Kaynaklar: `docs/domain-model.md` (alanlar, roller, durum makinesi, sayaçlar), `docs/firestore-rules-spec.md` (kurallar, sorgu sözleşmesi, indeksler), `docs/soft-delete.md`, `docs/architecture.md §7–10`.

## Değişmez ilke

**Yeni yazma/okuma yolu = aynı commit'te** `firebase/firestore.rules` + `firebase/firestore.indexes.json` + Rules testi + (gerekirse) `tool/seed/demo-data.json` + repository/servis + testleri. Aksi halde üretimde `permission-denied`.

## Sıra

1. **Spesifikasyonu oku:** koleksiyonun satırı (`domain-model §2`), yetki (`§3`), sayaçlar (`§4`), geçiş tablosu (`firestore-rules-spec §3`), sorgu sözleşmesi (`§6`).
2. **Model** (`gu_data`): alan tipi, nullability, varsayılan, `BaseFields`; `Timestamp` yalnızca sınırda; ID kuralları (`${clubId}_${userId}`, `${eventId}_${userId}`).
3. **Repository arayüzü**: alan dili; `FirebaseResult`; **sorgu `isDeleted == false` süzer** (`notDeleted` yardımcısı); sayfalama `limit(20)` + `startAfterDocument`.
4. **Yazma = batch/transaction:** iş durumu + sayaç ±1 + `activity` + `notifications` (Mod C) **tek atomik işlemde**. Kontenjan/çakışma gerektiren yerde transaction + beklenen durum doğrulaması (DLG-18).
5. **Rules:** alan beyaz listesi (`affectedKeys().hasOnly`), `request.time` ile zaman damgası denetimi, sayaç ±1 `getAfter`, rol yardımcıları (`isMember/isManager/isPres/isAdvisor/isSuper`), **`allow delete: if false`**, `allow write` yok. Erişim çağrısı bütçesi (10/işlem, 20/istek): ağır işlemleri parçala (`§5`).
6. **İndeks:** her yeni bileşik sorgu için `firestore.indexes.json` satırı (sorgu sözleşmesi tablosuyla eşleşir).
7. **Rules testi** (`firebase/test/`): rol × işlem matrisi, izinsiz alan, sayaç ±1 dışı, yanlış durum geçişi, **delete reddi**, sorgu sözleşmesi (süzgeçsiz sorgu ret). `npm test` emülatörde.
8. **Seed:** `tool/seed/demo-data.json`'daki ilişkili belgeler; seed yükleyici yalnızca emülatöre (ENV kontrolü).
9. **Repository/servis testi** (Q-06): soft delete alanları, sayaç, hata eşlemesi.
10. **Gizlilik:** e-posta yalnızca `users/{uid}/private/account` ve `memberships/{id}/private/contact`; `applicant` anlık görüntüsünde **e-posta yok**; ViewModel'e e-posta sızmaz.

## Yasaklar

❌ `.delete()` / `deleteDoc` / `batch.delete` / Storage silme / `user.delete()` · ❌ `allow write` · ❌ istemcide süper admin yükseltme (yalnızca custom claim, `tool/admin/set_superadmin.js`) · ❌ gerçek projeye kullanıcı onayı olmadan yazma / `firebase deploy` · ❌ Rules'ta "şimdilik açık" geçici kural.

## Bildirim üretimi

`NotificationDispatcher` arayüzü arkasında (Mod C: istemci batch yazar; Mod F: Functions tetikleyici). Tür × alıcı tablosu `domain-model §6`. Tercih/sessiz saat: okuyan taraf (Mod C) veya sunucu (Mod F).

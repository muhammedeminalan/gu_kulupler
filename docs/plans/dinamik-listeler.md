# Dinamik listeler — bölüm, fakülte, mekân Firestore'dan (H-22)

> Durum: **PLAN — başlanmadı** (kullanıcı 2026-10-17: "planını yap ama şuan başlama"). Tahmini süre ~4 sa (test + kapı dahil).
> Amaç: bölüm / fakülte / mekân listesini build çıkmadan değiştirmek. Şu anki listeler tasarımdan kalma kurgusal veridir (`static_tables.dart`).

## 1. Kararlar (kullanıcı, 2026-10-17)
- **Kapsam:** bölüm + fakülte + mekân. Kategori, ilgi alanı, yıl, etkinlik türü, popüler aramalar **gömülü kalır** (ikon, CD-38 bildirim eşlemesi, Rules listesi).
- **Kaynak:** Firestore belgesi `config/lookups` (Remote Config değil).

## 2. Veri sözleşmesi — `config/lookups`
```json
{
  "version": 1,
  "updatedAt": "<sunucu zamanı>",
  "faculties":   [{ "id": "f1",   "label": { "tr": "…", "en": "…" }, "active": true }],
  "departments": [{ "id": "d01",  "facultyId": "f1", "label": { "tr": "…", "en": "…" }, "active": true }],
  "places":      [{ "id": "pl01", "label": { "tr": "…", "en": "…" }, "active": true }]
}
```
- Sıra = dizi sırası. Kimlik biçimi: `f[0-9]{1,2}`, `d[0-9][0-9]`, `pl[0-9][0-9]` (Rules zaten bölüm / mekânı yalnızca **biçimle** doğruluyor → Rules alan kuralı değişmez).
- **Öğe silinmez, `active: false` olur** (eski profil / etkinlik etiketi çözülmeye devam eder; seçicide görünmez).
- İstemci yazamaz; yalnızca Admin SDK betiği yazar.

## 3. Adımlar
1. **gu_data (~1 sa):** `LookupTables` modeli (Equatable; savunmacı `fromJson` — bozuk öğe atlanır, boş / bozuk belge → gömülü yedek). `LookupRepository.watchLookups()` (`FirebaseResult`, Firestore çevrimdışı önbelleği). `StaticTables` yedek olarak kalır.
2. **Biçim doğrulaması (~30 dk):** `FieldValidators` (department, placeId), `UserModel.fromJson:76`, `UserProfilePatch:46`, `EventModel:119`, `EventDraft:19,54` sabit küme yerine biçim kontrolü (Rules ile aynı). Yoksa yeni `d25` profilde düşer.
3. **Uygulama (~1 sa):** keepAlive `LookupTablesViewModel` (gömülü yedekle başlar, oturum açılınca dinler). `StaticLabels.department / faculty / place`: dinamik etiket (dil) → ARB → kimlik. Seçiciler yalnızca etkinleri gösterir: `department_picker_sheet.dart`, `place_picker_sheet.dart`, `search_view_mixin.dart:55`.
4. **Rules (~20 dk):** `match /config/{docId} { allow read: if signedIn(); allow write: if false; }` + Rules testi (oturumlu okur, anonim okuyamaz, herkes yazamaz / silemez).
5. **Admin betiği (~40 dk):** `tool/admin/lookups.json` (ilk içerik = bugünkü liste + ARB'deki TR/EN etiketler) + `tool/admin/set_lookups.js` (kuru varsayılan, fark özeti: eklenen / değişen / pasifleşen; kimlik silmeyi ve bozuk biçimi reddeder; TTY onayı) + test + README. Emülatör tohumu da bu dosyayı yazar.
6. **Kapanış (~30 dk):** testler (model, repository, ViewModel, etiket çözümü, seçici etkin süzgeci, biçim doğrulama), `docs/decisions.md` H-22, domain-model + rules-spec `config` bölümü, `bash tool/quality_gate.sh` (arka planda) → PR → merge.

## 4. Kullanıcıdan gerekenler
- **Gerçek liste:** fakülte / bölüm / mekân adları (TR + EN). Sen ver ya da web'den derleyeyim (onayınla).
- **Yükleme:** `node tool/admin/set_lookups.js --yes` (sen çalıştırırsın) + Rules deploy (`firebase deploy --only firestore:rules`).
- **Build:** değişiklik bir sonraki sürüme girer (1.0.1). İncelemedeki 1.0.0 (1) etkilenmez.

## 5. Bilinçli olarak yapılmayanlar
- Kategori / ilgi alanı dinamik değil (istenirse 2. tur: Rules listeleri biçim kontrolüne çevrilir).
- Uygulama içi liste düzenleme ekranı yok (yerel admin paneli planına bırakıldı).

# tool/seed — demo verisi

`demo-data.json` Claude Design prototipinin **kurgusal** veri kümesidir (hiçbir kayıt gerçek kişiye ait değildir). Amaç: **yalnızca yerel Firebase emülatörünü** gerçekçi veriyle doldurmak ve ekran/test örneklemesi. Gerçek projeye **asla** yazılmaz.

| Alan | İçerik | Not |
|---|---|---|
| `meta.today` | göreli tarihlerin referans günü (`2026-10-07T21:00Z`) | `*_rel_days` = `today`'e göre gün farkı; tohumlayıcı bugüne kaydırır |
| `categories`(8) `interests`(16) `departments`(24) `places`(10) | referans listeleri | uygulamadaki sabit/katalog verisiyle eşleşir (`domain-model.md`) |
| `users`(226) `settings`(226) | kullanıcılar ve bildirim tercihleri | e-postalar sahte `@ogr.gumushane.edu.tr`; demo hesaplar `u_ayse, u_mehmet, u_zeynep, u_burak, u_elif, u_admin` |
| `clubs`(14) `memberships`(515) | kulüpler, üyelik/başvurular | `memberships` anahtarı `<clubId>_<userId>` |
| `posts`(36) `comments`(41) `saved` | akış | `likes` dizileri **sayaç + oy belgesine** çevrilir |
| `events`(22) `rsvps`(944) | etkinlikler, katılım, bilet kodu | `ticketCode` bilet; `scannedAt` yoklama |
| `notifications`(40) `reports`(8) `activity`(222) `dailyAnnouncementCount` | bildirim, şikayet, faaliyet, günlük duyuru sayacı | |

## Kurallar (tohumlayıcıyı yazan task: T-10, genişleme: T-45)
1. **Prototip biçimi ≠ Firestore modeli.** Tohumlayıcı (`tool/seed/seed_emulator.js`, T-10'da yazılır) bu JSON'u `docs/domain-model.md` şemasına **dönüştürür**: düz koleksiyonlar, soft delete alanları (`deletedAt/deletedBy/...`), sayaçlar (`memberCount` vb. üyelik belgelerinden tutarlı hesaplanır), iletişim bilgisi `memberships/{id}/private/contact` alt belgesine, `createdAt/updatedAt` sunucu biçimi.
2. **Yalnızca emülatör:** `FIRESTORE_EMULATOR_HOST` ve `FIREBASE_AUTH_EMULATOR_HOST` tanımlı değilse betik **durur**; proje kimliği `demo-` ile başlamalıdır. Gerçek proje kimliği görürse hata verir.
3. Auth kullanıcıları emülatörde sabit, yalnızca-yerel bir parolayla oluşturulur (betik sabiti; sır değildir, gerçek hesaplara bağlı değildir). UI'da "demo hesap" bölümü **uygulanmaz** (K-02).
4. Veri değişirse bu dosya `design/` gibi salt okunur sayılır; yeni senaryo için ayrı dosya ekle (`tool/seed/*.json`).
5. **Hard delete yok:** tohumlayıcı temizlik için belge silmez; emülatörü yeniden başlatır (`firebase emulators:start --import … ` / veri dizinini yenile).

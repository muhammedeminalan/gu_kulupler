# T-43 · Bütünleme denetimi — 5 durum + erişilebilirlik (Grup D)

> Tarih: 2026-10-15 · Dal: `feat/T-43-butunleme` · Hızlı mod (CD-123).
> Testler `--dart-define=GU_MATRIX=fast` ile koşuldu. Golden değişmedi.

## 1. Beş durum (hata → yükleniyor → boş → dolu + çevrimdışı)

**Sıra:** liste ekranlarının tamamı `GuListStatus.resolve(isError, isLoading, isEmpty)`
(`gu_ui/.../gu_list_state.dart`: hata → yükleniyor → boş → dolu) ya da eşdeğer
`if (isError) … else if (isFetching) … else if (isEmpty)` zinciri kullanıyor
(CLB-02 `search_view`, CLB-07 `user_profile_view`, MGT-06 `attendance_view`). Sıra
ihlali **yok**.

**Çevrimdışı:** bant ekran başına değil, kökte: `OfflineBanner`
(`GuApp.builder`, uygulama kabuğundaki tüm yollar; `test/product/widget/system/offline_banner_test.dart`,
`test/core/bootstrap/gu_app_test.dart`). Tasarımdaki `*__offline` yakalamaları =
bant + önbellekteki liste. Ekran düzeyinde doğrulanan şey yazma kapısıdır
(`WriteGuardMixin.ensureOnline` → TST-24, yazım yok, liste kalır).

Gösterim: ✓ = view / ViewModel testi mevcut · **eklendi** = bu denetimde eklendi ·
— = tasarımda yok (`design/reference-shots/states/` yakalaması yok, dal gerekmiyor).

| Ekran | Hata | Yükleniyor | Boş | Çevrimdışı (bant + yazma kapısı) | Tasarım yakalaması |
|---|---|---|---|---|---|
| CLB-01 Kulüpler | ✓ | ✓ | ✓ | ✓ view ("Katıl" → TST-24) | 4/4 |
| CLB-02 Arama | ✓ | ✓ | ✓ (`searchNoResults`) | ✓ VM | 4/4 |
| CLB-03 Kulüp · Hakkında | ✓ | ✓ | ✓ | ✓ view ("Katıl" → TST-24) | 4/4 |
| CLB-03 · Gönderiler (FED-01) | ✓ | ✓ (+ sonraki sayfa) | ✓ | ✓ view (beğeni → TST-24) | 4/4 |
| CLB-03 · Etkinlikler | ✓ | ✓ | ✓ | ✓ (bant; RSVP kapısı EVT-02 VM) | 4/4 |
| CLB-06 Üyeler | ✓ | ✓ | ✓ | ✓ view | — |
| CLB-07 Profil | ✓ | ✓ | — | — | — |
| FED-02 Gönderi + yorumlar | ✓ | ✓ | ✓ | ✓ view | — |
| EVT-01 Etkinlikler | ✓ | ✓ | ✓ | ✓ (bant; "Katıl" → SHT-12 → EVT-02 VM kapısı) | 4/4 |
| EVT-04 Biletlerim | ✓ | ✓ | ✓ | ✓ VM ("Ayrıl") | 4/4 |
| NTF-01 Bildirimler | ✓ | ✓ | ✓ | **eklendi** VM (okundu / sil → TST-24) | 4/4 |
| PRF-03 Kulüplerim | ✓ | ✓ | ✓ | ✓ view + VM | 4/4 |
| PRF-04 Kaydedilenler | ✓ | ✓ | ✓ | ✓ view (kaldır → TST-24) | 4/4 |
| SET-02 Engellenenler | ✓ | ✓ | ✓ | ✓ view + VM | — |
| MGT-01 Yönetim | ✓ | ✓ | — | ✓ (bant; ekran yazmaz) | — |
| MGT-02 Başvurular | ✓ | ✓ | ✓ | — (VM kapısı var, test yok) | — |
| MGT-03 Üyeleri yönet | ✓ | ✓ | ✓ | **eklendi** VM (çıkar → TST-24) | 4/4 |
| MGT-04 Etkinlikleri yönet | ✓ | ✓ | ✓ | **eklendi** VM (iptal → TST-24) | 4/4 |
| MGT-05 Etkinlik formu | — | — | — | ✓ VM | 4/4 (form; liste değil) |
| MGT-06 Yoklama | ✓ | ✓ | ✓ | — (VM kapısı var, test yok) | — |
| MGT-08 İçerik yönetimi | ✓ | ✓ | ✓ | — (VM kapısı var, test yok) | — |
| MGT-10 Etkinlik günlüğü | ✓ | ✓ (+ sonraki sayfa) | ✓ | ✓ view (yenileme okunamadı → liste kalır) | — |
| ADM-01 Admin | ✓ | ✓ | — | — | — |
| ADM-02 Kulüpler (admin) | ✓ | ✓ | ✓ | ✓ VM | 4/4 |
| ADM-04 Şikayetler | ✓ | ✓ | ✓ | ✓ VM | 4/4 |
| ADM-05 Kullanıcılar | ✓ | ✓ | ✓ | **eklendi** VM (askıya al → TST-24) | 4/4 |

Eklenen testler (4): `notifications_view_model_test`, `manage_members_view_model_test`,
`manage_events_view_model_test`, `admin_users_view_model_test` — "çevrimdışı (T-43)".
Eksik görünüm dalı bulunmadı.

## 2. Erişilebilirlik

**Yardımcı:** `test/helpers/a11y_guidelines.dart` → `expectA11yGuidelines(tester)`:
`labeledTapTargetGuideline` + 44 × 44 dokunma hedefi (`iOSTapTargetGuideline` ölçüsü, D-22;
bağlantı düğümleri yönerge gereği muaf; `smallTargetLabels` ile gerekçeli muafiyet) +
isteğe bağlı `textContrastGuideline` (`contrast: true`). Öz testi:
`test/helpers/a11y_guidelines_test.dart` (4 test).

**Kapsam:** 51 ekranın varsayılan (dolu) durum testine birer satır eklendi (her test
dosyasının ilk "içerik" testi; yerel ayar döngülüyse TR + EN). Sheet / dialog / toast
kapsam dışı.

| # | Bulgu | Ekran | Düzeltme |
|---|---|---|---|
| A-1 | Bildirim satırının dış düğümü (uzun basma + "Okundu yap" / "Sil" özel eylemleri + yatay kaydırma) **etiketsiz** — 9 satır | NTF-01 | `NotificationRow` → `MergeSemantics`: tek düğüm = satır etiketi + aç + menü + özel eylemler (`lib/product/widget/notification/notification_row.dart`) |

- Etiketsiz dokunma hedefi: **1 tür (9 düğüm) → düzeltildi.**
- 44 dp altı dokunma hedefi: **0** (D-22 `GuTapTarget` yaygın). Muafiyet gerekmedi.

**Kontrast (bilgi; kapıya bağlanmadı):** `contrast: true` deneme koşusunda 6 test
(4 ekran) AA altı buldu:

| # | Bulgu | Ekran | Değerlendirme |
|---|---|---|---|
| C-1 | `textTertiary` (#62748E) / `bgSubtle` (#F1F5F9) üzerinde 12 px rozet / durum metni — 4.35 : 1 (< 4.5) | CLB-03 kategori rozeti ("Spor ve Doğa"), EVT-02 rozet ("Eğitim"), NTF-02 "Kapalı" | **Tasarım token çifti.** Rengi değiştirmek tasarım + token kararı (kullanıcı onayı) gerektirir → kalan |
| C-2 | Harita yer tutucusu üzerindeki konum metni — 4.21 : 1 | EVT-02 | Desenli zemin; tasarım yakalamasıyla aynı → kalan |
| C-3 | "79 kişi" — 1.17 : 1 | CLB-06 | Yanlış pozitif: metin kaydırma kenarında (y = 0), örneklenen piksel üst katmana düşüyor |

## 3. Kalanlar

1. **C-1** `textTertiary` / `bgSubtle` küçük metin kontrastı 4.35 : 1 — token kararı
   (ör. rozette `textSecondary`) kullanıcıya sorulmalı; değişirse golden'lar bilinçli güncellenir.
2. **C-2** EVT-02 harita yer tutucusu metni — tasarım; C-1 kararıyla birlikte.
3. MGT-02 / MGT-06 / MGT-08 çevrimdışı yazma kapısı VM'de var, testi yok
   (tasarım yakalaması da yok) — düşük öncelik.
4. A11y taraması yalnızca ekranların varsayılan karesini kapsar; sheet / dialog ve
   kaydırma dışı satırlar kapsam dışı (`expectSemanticsCleanWhileScrolling` ayrı).
5. Yeni ARB metni gerekmedi.

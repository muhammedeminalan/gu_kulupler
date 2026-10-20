# Tam responsive web / geniş ekran (H-23)

> Durum: **Yerine referans düzen uygulandı (2026-10-20, H-23)** — telefon kartı + yan menü (`WebShell`, `GuWebFrame`, `GuSidebar`). Aşağıdaki sayfa sayfa plan uygulanmadı; ileride gerekirse bu plandan devam edilir.
> Eski durum: **PLAN — başlanmadı** (kullanıcı 2026-10-17: "C seçeneğini planla: tam responsive"). Tahmini süre ~17 sa (≈ 2 iş günü), 6 aşama.
> Bugün: geniş ekranda tüm uygulama ortalanmış 480 dp telefon sütunu (Q-13, CD-29 — `GuContentColumn`, `gu_app.dart:188`). Tasarımda masaüstü ekranı yok; prototip 390 px telefon.

## 1. İlke
- **Telefon (< 600 dp) hiç değişmez:** tasarıma 1:1, golden'lar (320 / 390 / 430) aynı kalır.
- Düzen **genişliğe** göre seçilir (platforma göre değil): web, Android tablet ve geniş pencere aynı kuralı alır.
- Masaüstü düzenlerinin tasarım referansı yok → her aşama tarayıcı önizlemesinde kullanıcıya gösterilir, onaydan sonra sıradakine geçilir. Yalnız mevcut token'lar kullanılır (renk, tipografi, boşluk); yeni ölçü token katmanına eklenir (`docs/token-map.md`).
- **Değişecek kilitli kararlar** (başlarken H-23'e işlenir): Q-13 (geniş ekranda 480 sütun), D-31 (tablet / yatay yerleşim kapsam dışı), CD-29.

## 2. Kırılımlar (öneri — başlamadan onay)
| Sınıf | Genişlik | Gezinme | İçerik |
|---|---|---|---|
| compact | < 600 | alt sekme çubuğu (bugünkü) | tek sütun, tasarım 1:1 |
| medium | 600 – 1023 | sol ray (yalnız ikon + rozet) | ≤ 720 sütun, listeler 2 sütun |
| expanded | ≥ 1024 | sol kenar menü (240, ikon + metin) | ≤ 1200, ızgara 3–4 sütun, iki bölmeli sayfalar |

## 3. Temel (aşama 1, ~4 sa)
1. **gu_ui token + yardımcılar:** `GuBreakpoints` → `compact / medium / expanded` + `GuWindowSize.of(context)`; düzen widget'ları `GuResponsiveBody(maxWidth)`, `GuAdaptiveGrid(minTileWidth)`, `GuTwoPane(main, side)`, `GuMasterDetail(list, detail)`. Kataloğa (`docs/widget-catalog.md`) eklenir.
2. **Kabuk:** `app_shell_view.dart` alt çubuk yerine ray / kenar menü (aynı `GuTab` listesi, bildirim rozeti, aktif sekmeye tekrar dokunma = köke dön kuralı korunur).
3. **Genel sütun kalkar:** `GuApp.builder` artık her şeyi 480'e sıkıştırmaz; sayfa kendi genişliğini `GuResponsiveBody` ile seçer. Aşaması gelmemiş sayfalar geçici olarak 480 sütunda kalır (yarım iş görünmez).
4. **Overlay'ler:** expanded'da bottom sheet → ortalı diyalog (≤ 560); toast alt orta, alt çubuk boşluğu yok; açılır menü konumu.
5. **Web dokunuşları:** fare imleci + hover (pressed durumunun hafifi), tekerlekle kaydırma, Esc ile kapatma, Enter ile form gönderme.

## 4. Ekran planı (51 ekran)
| Aşama | Ekranlar | medium / expanded düzeni |
|---|---|---|
| 2 · Sekme kökleri (~3 sa) | CLB-01, CLB-02, EVT-01, NTF-01, PRF-01, ADM-01 | Kulüp / etkinlik / arama sonuçları ızgara 2–4; EVT-01 yanında "Etkinliklerim" paneli; NTF-01 ≤ 720 liste; PRF-01 sol profil kartı + sağ içerik; ADM-01 metrik kartları 4 sütun |
| 3 · Detaylar (~3 sa) | CLB-03, EVT-02, FED-02, CLB-06, CLB-07, EVT-03, EVT-04, PRF-03, PRF-04 | CLB-03 tam genişlik kapak + iki bölme (sol sekmeler / sağ hakkında, kurul, katıl düğmesi sabit); EVT-02 bilgi + sağda sabit katılım kartı; FED-02 gönderi + yanda yorumlar; üye / kayıtlı / kulüplerim ızgara; EVT-03 bilet ortalı 480 |
| 4 · Formlar + ayarlar (~2 sa) | AUT-01…06, ONB-01, SYS-01…04, CLB-04, CLB-05, FED-03, PRF-02, NTF-02, SET-01…05, MGT-05, MGT-09, ADM-03 | Giriş / kayıt / sistem ortalı 480 kart (değişmez); formlar ≤ 720, uzun formlar (MGT-05, ADM-03) iki sütun alan; SET ana-detay (sol ayar listesi / sağ sayfa) |
| 5 · Yönetim + admin (~3 sa) | MGT-01…04, MGT-06…08, MGT-10, ADM-02, ADM-04, ADM-05 | MGT-01 pano ızgarası; başvuru / üye / yoklama / kullanıcı listeleri geniş satır (tablo görünümü); ADM-04 şikayet listesi + sağda detay bölmesi; MGT-07 QR tarama ortalı (web kamerası) |
| 6 · Test + kapı (~2–3 sa) | tümü | aşağıda |

## 5. Test
- Cihaz matrisi genişler: + 1024 ve 1440 genişlik (açık / koyu × TR / EN × metin ölçeği); 600–1440 arası taşma = fail.
- Ekran başına expanded golden (1280 × 800, açık + koyu). Telefon golden'ları değişmemeli (değişirse hata).
- Kabuk: ray / kenar menü sekme geçişi, rozet, köke dönüş; overlay: expanded'da sheet → diyalog.
- `bash tool/quality_gate.sh` tam kapı (arka planda) → PR → merge. Her aşama ayrı PR.

## 6. Başlamadan kullanıcı kararı
1. Kırılım değerleri (600 / 1024 öneri).
2. Expanded'da bottom sheet → diyalog (öneri: evet).
3. Web'i yayınla: `gu-kulupler.web.app/app` (öneri: aşama 2'den sonra; Hosting deploy senin onayınla).
4. Aşama başına önizleme + onay (öneri: evet).

## 7. Kapsam dışı
- Yatay telefon yerleşimi (telefon dikey kilitli kalır — Q-13'ün telefon kısmı).
- Web'de push / hatırlatıcı (PR #60: web'de kapalı); masaüstü uygulaması (macOS / Windows).

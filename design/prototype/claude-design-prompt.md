# GÜ Kulüpler — Claude Design Brief'i (v1.0)

> **Proje:** Gümüşhane Üniversitesi öğrenci kulüpleri için yönetim + sosyal medya mobil uygulaması
> **Çalışma adı:** "GÜ Kulüpler" (tek bir `APP_NAME` sabitinden okunur; sonradan değiştirmek tek satır olmalı)
> **Üretim teknolojisi:** Flutter + Firebase. Bu belge yalnızca **tasarım prototipi** içindir.
> **Arayüz dili:** Türkçe (varsayılan) + İngilizce
> **Tarih:** 8 Ekim 2026

Bu dosyanın tamamı **tek bir Claude Design isteği** olarak verilir. Aşağıdaki her bölüm bağlayıcıdır. Belirsiz kalan yerde en makul varsayımı seç, bunu prototipin "Ekran Haritası" sayfasındaki **Varsayımlar** kutusuna yaz ve devam et; durup soru sorma.

---

## 0. Talimat Özeti (önce bunu oku)

Sen kıdemli bir ürün tasarımcısı ve ön yüz prototipçisisin. Aşağıdaki spesifikasyona göre, **tek seferde, eksiksiz, tıklanabilir ve gerçekçi demo verili** bir mobil uygulama prototipi üret. Prototipin yanında bir **Assets sayfası**, bir **Tasarım Sistemi sayfası**, bir **Ekran Haritası sayfası** ve bir **Kalite Kontrol sayfası** da teslim et.

### Kesin kurallar

| # | Kural |
|---|---|
| K1 | **Tek seferde her şey.** Bu belgedeki tüm ekranlar, sheet'ler, dialog'lar ve toast'lar tek teslimde bulunur. "Sonra eklenir", "placeholder" ve "TODO" yok. |
| K2 | **Ölü öğe yok.** Her buton, link, çip, liste satırı, kart, ikon buton, menü öğesi, switch ve sekme gerçek bir sonuç üretir. `href="#"`, boş `onclick`, "yakında" etiketi yasak. |
| K3 | Her aksiyonun sonucu şunlardan biridir: **ekran geçişi · bottom sheet · dialog · toast/snackbar · veri durumu değişikliği · animasyonlu geri bildirim**. Sonucu olmayan aksiyon tasarlama. |
| K4 | **Tek veri deposu (store).** Ekranlar store'dan okur, aksiyonlar store'u değiştirir. Örnek: bir kulübe başvurunca kart durumu "İstek gönderildi" olur; yönetici rolüne geçince o başvuru "Başvurular" listesinde görünür; onaylayınca başvuranın bildirimlerine kayıt düşer ve rozet sayısı artar. |
| K5 | **Sahte ama gerçekçi veri.** Bölüm 11'deki demo veri kullanılır. Lorem ipsum yok. Gerçek kişi, gerçek kulüp, gerçek marka, gerçek fotoğraf yok; tüm kişi ve kulüpler **kurgusaldır**. |
| K6 | **Tüm arayüz metinleri i18n sözlüğünden gelir** (`t("anahtar")`). TR ve EN eksiksiz olur. Dil değişince ekran yeniden yüklenmeden anında güncellenir. |
| K7 | **Açık ve koyu tema** eksiksiz çalışır. Her ekran ve bileşen iki temada da kontrol edilmiş olur. |
| K8 | **Tek ikon kayıt defteri (registry).** Kullanılan her ikon tek bir `ICONS` nesnesinden gelir ve Assets sayfasında listelenir. Emoji ikon yerine kullanılmaz. |
| K9 | Her liste ve veri bloğu için **yükleniyor (skeleton), boş, hata ve çevrimdışı** durumu tasarlanır ve Kontrol Paneli'nden zorlanabilir. |
| K10 | **Erişilebilirlik** (Bölüm 4.9) bağlayıcıdır: dokunma hedefi ≥ 48 px, AA kontrast, odak halkası, `aria-label`, dialog'larda odak tuzağı. |
| K11 | **Faz 2 özellikleri için buton, sekme veya "yakında" etiketi koyma** (görev yönetimi, bütçe, sertifika, sohbet, kulüp kurma başvurusu). Bunlar kapsam dışıdır (Bölüm 17). |
| K12 | Üniversitenin **resmi logosunu kopyalama**. Yerine kırmızı yuvarlak bir `LogoPlaceholder` amblemi çiz (Assets sayfasında "Gerçek logoyu buraya ekle" notuyla). |
| K13 | Dış görsel yükleme yok. Görseller (kapak, avatar, illüstrasyon) **kodla üretilir** (SVG, gradient, desen). |
| K14 | Teslimden önce **Bölüm 15'teki self-check'i** çalıştır ve sonucu Kalite Kontrol sayfasına yaz. |

### Teslim edilecek parçalar

1. **Prototip:** 390 × 844 cihaz çerçevesinde, bu belgedeki tüm akışlarla çalışan uygulama.
2. **Kontrol Paneli:** Rol, tema, dil, ağ ve veri durumunu değiştiren demo paneli (Bölüm 5).
3. **Assets sayfası:** Tüm ikonlar, renkler, yazı tipleri, amblem, illüstrasyonlar, desenler, demo veri ve dil dosyaları; tek tuşla toplu indirme (Bölüm 12).
4. **Tasarım Sistemi sayfası:** Her bileşenin tüm varyant ve durumları, açık/koyu yan yana (Bölüm 13).
5. **Ekran Haritası sayfası:** Akış diyagramları + ekran envanteri + varsayımlar (Bölüm 14).
6. **Kalite Kontrol sayfası:** Aksiyon kapsamı ve self-check raporu (Bölüm 14.2–14.3).

---

## 1. Ürün Özeti

**Problem.** Kulüp iletişimi bugün WhatsApp grupları, Instagram hesapları ve Google Form'lar arasında dağınık. Öğrenci hangi kulübün ne yaptığını bilmiyor; yönetim başvuru, yoklama ve duyuruyu üç ayrı yerde takip ediyor.

**Çözüm.** Tek uygulamada kulüpleri keşfet, başvur, etkinliklere katıl, QR ile yoklama ver, duyuruları al. Kulüp yönetimi için başvuru onayı, üye ve etkinlik yönetimi, duyuru paneli.

**Değer önerisi cümlesi (onboarding ve sunumda kullanılacak):** "Kampüsteki tüm kulüpler, tek cebinizde."

### Personalar

| Persona | Hedef | Kritik ekranlar |
|---|---|---|
| **Ayşe Demir** — 1. sınıf, yeni öğrenci | Kendine uygun kulüp bulmak, başvurmak, etkinliğe gitmek | CLB-01, CLB-03, CLB-04, EVT-01, EVT-03 |
| **Burak Şahin** — Doğa Sporları Kulübü Başkanı | Başvuruları onaylamak, etkinlik açmak, yoklama almak | MGT-01…MGT-07 |
| **Dr. Zeynep Arslan** — Danışman akademisyen | Kulübün durumunu izlemek | MGT-01 (salt okunur) |
| **Kampüs Yönetimi** — Süper admin | Kulüpleri açmak, şikayetleri yönetmek | ADM-01…ADM-05 |

### Tasarım ilkeleri

1. **Kampüs sıcaklığı + resmi güven:** Üniversitenin kırmızı kimliği, krem zemin, bol beyaz kart.
2. **Tek elle kullanım:** Birincil eylemler ekranın alt yarısında; seçimler bottom sheet ile.
3. **Önce eylem:** Her ekranda tek net birincil CTA.
4. **Durum her zaman görünür:** Üyelik, başvuru, kontenjan ve bilet durumu kartın üstünde okunur.
5. **Yönetici hızı:** Tek dokunuşla onay, toplu işlem, geri alınabilir eylemler.
6. **Güvenli his:** Geri alınamaz işlemlerde açık onay; tehlikeli eylemler görsel olarak ayrışır.

### Platform

iOS ve Android, dikey yön. Referans genişlik **390 px**; **360–430 px** arası duyarlı. Tablet ve yatay yön kapsam dışı. Süper admin web paneli kapsam dışı (süper admin için mobilde "Admin" sekmesi vardır).

---

## 2. Roller, Yetkiler, Üyelik Durumları

### 2.1 Roller

Roller **kulüp bazlıdır**: aynı kişi bir kulüpte `president`, başka kulüpte `member` olabilir. `superadmin` globaldir.

| Rol | Kod | Not |
|---|---|---|
| Öğrenci (üye değil) | `student` | Bir kulübe üye olmayan herkes |
| Üye | `member` | Onaylanmış üyelik |
| Yönetim Kurulu | `board` | Operasyonu yürütür |
| Başkan | `president` | Tüm kulüp yetkileri; yetki devri |
| Danışman | `advisor` | Panel **salt okunur** |
| Süper Admin | `superadmin` | Kampüs yönetimi, moderasyon |

### 2.2 Yetki matrisi

| İşlem | Öğrenci | Üye | Yönetim Kurulu | Başkan | Danışman | Süper Admin |
|---|---|---|---|---|---|---|
| Kulüp tanıtımını ve herkese açık etkinlikleri görme | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Üyelik başvurusu gönderme | ✓ | — | — | — | — | — |
| Gönderi, üye listesi ve üyelere özel etkinlikleri görme | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| Yorum yazma, anket oylama | — | ✓ | ✓ | ✓ | — | — |
| Gönderi oluşturma | — | — | ✓ | ✓ | — | — |
| Duyuru (push) gönderme (günde en fazla 2) | — | — | ✓ | ✓ | — | — |
| Etkinlik oluşturma/düzenleme | — | — | ✓ | ✓ | — | — |
| QR ile yoklama alma | — | — | ✓ | ✓ | — | — |
| Başvuru onay/red | — | — | ✓ | ✓ | — | — |
| Üye çıkarma | — | — | ✓ | ✓ | — | ✓ |
| Başkasının gönderi/yorumunu silme | — | — | ✓ | ✓ | — | ✓ |
| Kulüp profilini ve ayarlarını düzenleme | — | — | ✓ | ✓ | — | — |
| Rol atama, başkanlık devri | — | — | — | ✓ | — | ✓ |
| Yönetim panelini görme | — | — | ✓ | ✓ | ✓ (salt okunur) | ✓ |
| Kulüp açma/askıya alma, başkan atama | — | — | — | — | — | ✓ |
| Şikayet moderasyonu, kullanıcı askıya alma | — | — | — | — | — | ✓ |

**Danışman davranışı:** Panelde tüm veriyi görür; yazma eylemleri (onayla, düzenle, yayınla…) **devre dışıdır**. Devre dışı butona dokunulunca toast: "Danışman yetkisi salt okunurdur." Panelin en üstünde kalıcı bilgi bandı gösterilir.

### 2.3 Üyelik durum makinesi

Durumlar: `none` · `pending` · `active` · `rejected` · `removed`

| Geçiş | Tetikleyici | Kural |
|---|---|---|
| `none → pending` | Başvuru gönder (SHT-05) | Kulüp "onay gerekli" ise |
| `none → active` | "Katıl" (anında katılım) | Kulüp "onay gerekmez" ise; SHT-05 açılmaz, katılım doğrudan gerçekleşir + TST-34 |
| `pending → active` | Yönetici onaylar | Başvurana bildirim gider |
| `pending → rejected` | Yönetici reddeder (neden opsiyonel) | `retryAfter = reddedilme tarihi + 7 gün` |
| `pending → none` | Kullanıcı isteği iptal eder | DLG-07 onayıyla |
| `rejected → pending` | Tekrar başvuru | Yalnızca `retryAfter` geçtiyse; aksi halde geri sayım gösterilir |
| `active → none` | Kullanıcı kulüpten ayrılır | DLG-08; son yönetici ayrılamaz (DLG-09) |
| `active → removed` | Yönetici üyeyi çıkarır | `retryAfter = +7 gün` |

**Başvurular kapalı** kulüpler: Katıl butonu devre dışı, altında "Başvurular şu an kapalı" bilgisi.

### 2.4 Kulüp kartı CTA tablosu

| Durum | Buton | Stil | Dokununca |
|---|---|---|---|
| `none` + açık | **Katıl** | Primary (dolu kırmızı) | SHT-05 (veya anında katılım) |
| `none` + kapalı | Başvurular kapalı | Disabled | Toast: "Bu kulüp şu an başvuru almıyor." |
| `pending` | İstek gönderildi | Tonal, saat ikonu | CLB-05 |
| `rejected` | Reddedildi | Tonal, kırmızı tonlu | CLB-05 |
| `active` | **Aç** | Outline | CLB-03 (üye modu) |
| `active` + yönetici | Aç + "Yönetici" rozeti | Outline + rozet | CLB-03 (yönetici modu) |

---

## 3. Bilgi Mimarisi ve Navigasyon

### 3.1 Alt gezinme çubuğu

4 sekme: **Kulüpler** · **Etkinlikler** · **Bildirimler** · **Profil**.
Süper admin için 5. sekme: **Admin** (Profil'den önce).

- Aktif sekme: kırmızı ikon + etiket, üstte kısa kırmızı gösterge çizgisi.
- Bildirimler sekmesinde okunmamış sayısı rozeti (9+ üstü "9+").
- Her sekmenin **kendi yığını** vardır; sekme değiştirince durum korunur. Aktif sekmeye tekrar dokunma: ekranın başına kaydır, yığın varsa köke dön.
- Yönetim girişleri: (a) kulüp detayında "Yönetim" butonu, (b) Profil'de "Yönettiğim kulüpler" kartı. Birden fazla kulübü yöneten kullanıcı önce SHT-18'i görür.

> Global "Akış" sekmesi **yoktur**. Akış, her kulübün içinde yaşar (FED-01).

### 3.2 Rota tablosu

| Rota | Ekran | Sekme |
|---|---|---|
| `/splash` | SYS-01 | — |
| `/onboarding` | ONB-01 | — |
| `/login` · `/register` · `/verify` · `/reset` · `/setup-profile` · `/legal/:tip` | AUT-01…AUT-06 | — |
| `/clubs` · `/clubs/search` | CLB-01 · CLB-02 | Kulüpler |
| `/clubs/:id` | CLB-03 | Kulüpler |
| `/clubs/:id/application` · `/clubs/:id/applied` | CLB-05 · CLB-04 | Kulüpler |
| `/clubs/:id/members` | CLB-06 | Kulüpler |
| `/users/:id` | CLB-07 | (bağlama göre) |
| `/clubs/:id/posts/:postId` · `/clubs/:id/compose` | FED-02 · FED-03 | Kulüpler |
| `/events` · `/events/:id` · `/events/:id/ticket` · `/events/mine` | EVT-01…EVT-04 | Etkinlikler |
| `/notifications` | NTF-01 | Bildirimler |
| `/profile` · `/profile/edit` · `/profile/clubs` · `/profile/saved` | PRF-01…PRF-04 | Profil |
| `/settings` · `/settings/notifications` · `/settings/blocked` · `/settings/delete` · `/settings/about` · `/settings/support` | SET-01…SET-05, NTF-02 | Profil |
| `/manage/:clubId/...` | MGT-01…MGT-10 | Kulüpler |
| `/admin/...` | ADM-01…ADM-05 | Admin |

### 3.3 Davranış kuralları

- Geri: sol üst ok + kenardan kaydırma jesti; sheet'ler: sürükleyerek, scrim'e dokunarak ya da X ile kapanır; dialog'lar: Esc ve "İptal" ile.
- **Deep link senaryosu:** Bildirime dokunmak ilgili ekranı açar ve geri tuşu o sekmenin köküne döner. Bildirim türü → hedef tablosu NTF-01'de.
- Rol veya oturum değişince (Kontrol Paneli) tüm yığınlar sıfırlanır ve uygun başlangıç ekranına gidilir.

---

## 4. Tasarım Sistemi

Marka dili, üniversitenin resmi sitesinden (gumushane.edu.tr) okunan değerlerden türetilmiştir: kırmızı `#D00A2D`, krem zemin `#FAF9F6`, beyaz kartlar, slate gri metinler, Montserrat başlıklar, 12 px düğme köşesi, yuvarlak kartlar.

### 4.1 Renk tokenları

| Token | Açık | Koyu | Kullanım |
|---|---|---|---|
| `brand.primary` | `#D00A2D` | `#D00A2D` | Dolu butonlar, aktif sekme göstergesi, rozetler |
| `brand.primaryText` | `#D00A2D` | `#F2536C` | Link, ikon, vurgulu metin (koyu zeminde okunurluk için açık ton) |
| `brand.primaryPressed` | `#A80824` | `#B8082A` | Basılı durum |
| `brand.onPrimary` | `#FFFFFF` | `#FFFFFF` | Kırmızı üstü metin/ikon |
| `brand.primaryContainer` | `#FCE8EC` | `#3A0C16` | Tonal arka plan |
| `brand.onPrimaryContainer` | `#7A0619` | `#FFD9E0` | Tonal üstü metin |
| `bg.canvas` | `#FAF9F6` | `#17191C` | Sayfa zemini |
| `bg.surface` | `#FFFFFF` | `#1E2024` | Kart yüzeyi |
| `bg.surfaceMuted` | `#F1F5F9` | `#292E35` | Girdi, çip, ikincil alan |
| `bg.surfaceRaised` | `#FFFFFF` | `#23272E` | Sheet, dialog |
| `border.default` | `#E2E8F0` | `#39414B` | Kenarlık |
| `border.soft` | `#EEF1F5` | `#303740` | Ayraç |
| `text.primary` | `#101828` | `#F1F1ED` | Gövde |
| `text.heading` | `#1D293D` | `#F5F5F1` | Başlık |
| `text.secondary` | `#45556C` | `#C6CCD4` | İkincil |
| `text.muted` | `#62748E` | `#AEB5BF` | Yardımcı, zaman damgası |
| `text.disabled` | `#A3AEBF` | `#6B7480` | Devre dışı |
| `state.success` / `successContainer` | `#15803D` / `#DCFCE7` | `#4ADE80` / `#0F2E1A` | Onaylandı, katıldı |
| `state.warning` / `warningContainer` | `#B45309` / `#FEF3C7` | `#FBBF24` / `#3A2A0A` | Beklemede, dikkat |
| `state.danger` / `dangerContainer` | `#B42318` / `#FEE4E2` | `#FF7A70` / `#3B1512` | Hata, silme |
| `state.info` / `infoContainer` | `#1D5FAD` / `#E3F0FC` | `#7DB7F2` / `#0F2538` | Bilgi |
| `overlay.scrim` | `rgba(16,24,40,.48)` | `rgba(0,0,0,.60)` | Sheet/dialog arkası |
| `focus.ring` | `#D00A2D` | `#F2536C` | 2 px halka, 2 px offset |

**Markanın kırmızısı ile hata kırmızısı karışmasın:**
- Marka kırmızısı (`#D00A2D`) yalnızca **birincil eylemleri ve kimliği** taşır.
- Hata/silme durumları **daha koyu `state.danger` + uyarı ikonu + metin** ile verilir; yıkıcı eylem butonları ana ekranlarda **outline/metin** stilindedir, yalnızca onay dialog'unda dolu `danger` olur.
- Renk tek başına anlam taşımaz: durum her zaman ikon + metinle birlikte verilir.

**Rol ve durum rozetleri**

| Rozet | Arka plan | Metin | İkon |
|---|---|---|---|
| Başkan | `primaryContainer` | `onPrimaryContainer` | `crown` |
| Yönetim Kurulu | `surfaceMuted` + `border.default` | `text.heading` | `shield-check` |
| Danışman | `warningContainer` | `warning` | `graduation-cap` |
| Üye | `surfaceMuted` | `text.secondary` | `user-check` |
| Süper Admin | `text.heading` (koyu) | `bg.surface` | `badge-check` |
| Beklemede | `warningContainer` | `warning` | `hourglass` |
| Onaylandı / Katıldı | `successContainer` | `success` | `check-circle` |
| Reddedildi / İptal | `dangerContainer` | `danger` | `x-circle` |
| Dolu | `surfaceMuted` | `text.muted` | `users` |

Kontrast referansı: beyaz üstünde `#D00A2D` ≈ 5.6:1 (AA metin için yeterli). Tüm metin/zemin çiftleri en az AA olmalıdır; koyu temada `brand.primaryText` kullanılır.

### 4.2 Tipografi

Yazı tipleri: **Montserrat** (başlık, rakam vurgusu, overline) ve **Inter** (gövde, etiket). İkisi de Türkçe karakterleri (ğ, ş, ı, İ, ç, ö, ü) tam destekler. **HTML `lang` özniteliği dile göre `tr`/`en` değişir**; aksi halde `text-transform: uppercase` "i" harfini "İ" yapmaz.

| Stil | Font | Boyut / Satır | Ağırlık | Not |
|---|---|---|---|---|
| Display | Montserrat | 28 / 34 | 700 | Karşılama, hero başlıklar |
| Title L | Montserrat | 22 / 28 | 700 | Ekran başlığı |
| Title M | Montserrat | 18 / 24 | 600 | Bölüm başlığı |
| Title S | Montserrat | 16 / 22 | 600 | Kart başlığı |
| Body L | Inter | 16 / 24 | 400 | Uzun metin |
| Body M | Inter | 15 / 22 | 400 | Varsayılan gövde |
| Body S | Inter | 13 / 18 | 400 | İkincil metin |
| Label L | Inter | 14 / 20 | 600 | Buton |
| Label M | Inter | 12 / 16 | 600 | Çip, rozet |
| Caption | Inter | 12 / 16 | 500 | Zaman, yardımcı |
| Overline | Montserrat | 11 / 14, +8% harf aralığı, BÜYÜK HARF | 600 | Bölüm üst etiketi (sitedeki wordmark tarzı) |

Sayaçlar (üye sayısı, kontenjan) `font-variant-numeric: tabular-nums`. Metin ölçeği %100/130/160 desteklenir; taşma yerine satır kırılır.

### 4.3 Boşluk, köşe, gölge

- **4 px ızgara:** 4 · 8 · 12 · 16 · 20 · 24 · 32 · 40 · 48.
- Sayfa kenar boşluğu **16**, bölümler arası **24**, kart iç boşluğu **16**, liste satırı min. yükseklik **56**.
- **Köşe:** `r.sm` 12 (buton, girdi) · `r.md` 16 · `r.lg` 20 (kart) · `r.xl` 28 (sheet üst köşesi) · `r.full` 999 (çip, avatar, rozet).
- **Gölge:** `e0` yok + 1 px kenarlık · `e1` `0 1px 2px rgba(16,24,40,.06), 0 1px 3px rgba(16,24,40,.08)` · `e2` `0 4px 12px rgba(16,24,40,.10)` · `e3` (sheet) `0 -8px 32px rgba(16,24,40,.16)`. Koyu temada gölge yerine kenarlık + hafif yüzey farkı kullan.

### 4.4 İkonlar

- **Tek set:** Lucide stili (ISC lisanslı çizgi ikonlar), 24 × 24 viewBox, `stroke="currentColor"`, **stroke-width 1.75**, `stroke-linecap/linejoin: round`, dolgu yok.
- Boyutlar: 16 · 20 · 24 · 32. Alt çubukta aktif sekme için dolgulu varyant gerekmez; renk + gösterge çizgisi yeterlidir.
- İkonlar **kod içine gömülür** (`ICONS = { "home": "<path…/>", … }`), SVG yolu elle uydurulmaz; Lucide'den alınır. Böylece Assets sayfası her ikonu ham `.svg` olarak indirebilir.
- Zorunlu ikon listesi **Bölüm 12.2**'dedir. Listede olmayan ikon kullanılırsa listeye eklenir.

### 4.5 Görsel dil (kapak, avatar, illüstrasyon)

- **Kulüp/etkinlik kapağı:** `CoverArt(seed, iconName, palette)` fonksiyonu SVG üretir. 3 palet: **Kırmızı–Krem**, **Slate–Lacivert**, **Bordo–Kum**. Gradient + geometrik desen (üçgen dağ silüeti, çizgi, nokta ızgarası) + büyük, %12 opaklıkta kulüp ikonu. Aynı `seed` her zaman aynı kapağı üretir.
- **Avatar:** Baş harfler + seed'e göre gradient. Boyutlar 24 · 32 · 40 · 56 · 96. Üst üste dizili avatar grubu (`+12` sayacıyla).
- **İllüstrasyonlar:** Boş durumlar ve onboarding için 12 adet basit, tek renk + kırmızı vurgulu SVG (Bölüm 12.5). Fotoğraf yok.
- **Amblem:** `LogoPlaceholder` — kırmızı daire, içinde stilize "kulüp/kampüs" simgesi. Yazı: "GÜ Kulüpler" (Montserrat 700, harf aralıklı). Gerçek logo yerine geçecektir; Assets sayfasında not düş.

### 4.6 Hareket

| Token | Değer |
|---|---|
| `motion.fast` | 120 ms |
| `motion.base` | 200 ms |
| `motion.slow` | 320 ms |
| `ease.standard` | `cubic-bezier(.2, 0, 0, 1)` |
| `ease.emphasized` | `cubic-bezier(.3, 0, 0, 1)` |

- Sayfa geçişi (push): yatay **16 px kayma + solma** (`base`). Sekme değişimi: yalnız solma.
- Bottom sheet: aşağıdan yukarı yaylanarak (`slow`), sürükleyerek kapanır; scrim solar.
- Dialog: `0.96 → 1` ölçek + solma (`base`).
- Başarı işareti: SVG çizgisi çizilerek (`slow`). Beğeni: kalp küçük "pop".
- Skeleton: 1.2 sn yatay parıltı döngüsü.
- Toast: alttan yükselir, 4 sn sonra kapanır (geri al varsa 6 sn).
- `prefers-reduced-motion: reduce` → yalnızca solma, kayma/ölçek/parıltı yok.

### 4.7 Bileşen ailesi (özet; ayrıntı Bölüm 13)

Button (primary / tonal / outline / text / destructive-outline / destructive-filled; S-M-L; loading; disabled; ikonlu; ikon-only), Input (metin, şifre, arama, çok satırlı, seçici-alan, sayaçlı), Checkbox, Radio, Switch, Chip (filtre, seçim, girdi), Badge (rol, durum, sayaç), Avatar (+grup), Card (kulüp, etkinlik, gönderi, bildirim, üye, başvuru, KPI), List tile, Tabs (üst sekme, segmented), Bottom navigation, App bar (büyük, küçük, arama), Bottom sheet, Dialog, Snackbar/Toast, Banner (çevrimdışı, bilgi, uyarı, salt okunur), Progress (doğrusal kontenjan, dairesel), Skeleton, Empty state, Error state, Date/Time picker (özel), Calendar (aylık), QR çerçevesi, Stepper.

### 4.8 Düzen kalıpları

- **App bar:** Ana sekme kökleri "büyük başlık" (Title L, kaydırınca küçülür); alt ekranlar küçük başlık + geri oku.
- **Liste/kart:** 16 px kenar boşluğu, kartlar arası 12 px. Uzun listelerde "çek-yenile" ve sonda "Hepsi bu kadar" satırı.
- **Sticky CTA:** Detay ekranlarında birincil CTA, güvenli alana oturan sabit alt çubukta (üstü hafif gölge).
- **Form:** Etiket üstte, yardım/hata metni altta; hata durumunda kenarlık `danger` + ikon + metin. Gönder butonu doğrulama geçene kadar devre dışı değildir; tıklanınca ilk hatalı alana odaklanır ve kaydırır.
- **Güvenli alan:** Üstte durum çubuğu (saat, pil, sinyal), altta ana gösterge çizgisi; içerik bunların altında kalmaz.

### 4.9 Erişilebilirlik (bağlayıcı)

- Dokunma hedefi **≥ 48 × 48 px**; küçük ikonların dokunma alanı genişletilir.
- Metin kontrastı **≥ 4.5:1**, büyük metin ve ikonlar **≥ 3:1**.
- `:focus-visible` halkası tüm etkileşimli öğelerde; klavye ile (Tab/Enter/Space/Esc) tüm akış yürütülebilir.
- İkon-only butonlarda `aria-label` (i18n'den). Dialog `role="dialog" aria-modal="true"`, odak tuzağı, kapanınca odak tetikleyiciye döner. Sheet için aynısı.
- Toast `aria-live="polite"`; hata mesajları `role="alert"`.
- Başlık hiyerarşisi (h1 → h2 → h3) ekran başına tutarlı.
- Renk tek başına anlam taşımaz (ikon + metin).
- Metin ölçeği 200%'e kadar düzen bozulmaz (`rem` kullan).
- `prefers-color-scheme` varsayılanı izler; kullanıcı seçimi üzerine yazar.

---

## 5. Prototip Kabuğu ve Kontrol Paneli

### 5.1 Yerleşim

- **Masaüstü (≥ 1024 px):** 3 sütun. **Sol:** site menüsü (Prototip · Assets · Tasarım Sistemi · Ekran Haritası · Kalite Kontrol). **Orta:** 390 × 844 cihaz çerçevesi (köşe 44 px, çentik/ada, durum çubuğu, ana gösterge çizgisi). **Sağ:** Kontrol Paneli.
- **Mobil (< 768 px):** Uygulama tam ekran; çerçeve yok. Sol altta küçük yüzen **"Demo"** butonu Kontrol Paneli'ni alt çekmece olarak açar; site menüsü panelin içindedir.
- **Orta (768–1023):** Çerçeve ortada, panel alt çekmece.

### 5.2 Kontrol Paneli (her kontrol çalışır)

| Grup | Kontrol | Etki |
|---|---|---|
| **Hesap** | Demo hesap seçici (6 hesap, Bölüm 11.2) + "Bu hesapla giriş yap" | Anında oturum açar, yığınları sıfırlar |
| | "Çıkış yap" | AUT-01'e döner |
| **Görünüm** | Tema: Sistem / Açık / Koyu | Anında uygular |
| | Dil: TR / EN | Anında uygular, `lang` günceller |
| | Yazı boyutu: %100 / %130 / %160 | Ölçeği değiştirir |
| | Cihaz çerçevesi göster/gizle | Çerçeveyi açar/kapatır |
| **Ağ** | Çevrimiçi / Çevrimdışı / Yavaş (1.5 sn gecikme) | Çevrimdışıyken banner + yazma eylemleri hata/kuyruğa düşer |
| **Veri durumu** | Normal / Boş / Hata (zorla) | Tüm listeler boş veya hata durumunu gösterir; "Yeniden dene" Normal'e döner |
| | "Yükleniyor durumunu göster" (3 sn) | Skeleton'ları gösterir |
| **Sistem olayları** | Zorunlu güncelleme göster | DLG-26 |
| | Oturum süresi doldu | DLG-27 |
| | Yeni bildirim simüle et | Rastgele bildirim + rozet + TST-55 (Görüntüle → ilgili ekran) |
| | Bildirim iznini sıfırla | DLG-03 yeniden çıkar |
| **Başvuru simülasyonu** | "Bekleyen başvurumu onayla" / "reddet" | Başvuran hesapta durum değişir, bildirim düşer |
| **Veri** | "Demo verisini sıfırla" | Seed'i yeniden yükler |
| | "Tüm demo verisini JSON indir" | `demo-data.json` indirir |

Panel açıkken değişiklikler anlık yansır. Ekran değişince panelin durumu korunur.

---

## 6. Teknik Sözleşme

### 6.1 Yığın ve dosya düzeni

- Tek, kendi kendine yeten bir HTML teslimi tercih edilir; framework serbesttir (hafif React/Preact ya da düz JS). Dış bağımlılık **yalnızca** `cdnjs.cloudflare.com`, `cdn.jsdelivr.net`, `unpkg.com` ve Google Fonts'tan olabilir.
- Kod bölümleri yorum başlıklarıyla ayrılır: `/* ===== STORE ===== */`, `ROUTER`, `I18N`, `ICONS`, `COVER_ART`, `COMPONENTS`, `SCREENS`, `SHEETS`, `DIALOGS`, `ASSETS_PAGE`, `QA_PAGE`.
- Dosya çok büyürse çok dosyalı teslim serbesttir; ancak tek giriş noktasından çalışmalıdır.

### 6.2 Store

Tek kaynak: `store` nesnesi, değişmez (immutable) güncellemeler, `dispatch(action)`. Durum `localStorage`'a **try/catch ile** yazılır (erişilemezse bellekte çalışır). Seed fonksiyonu deterministik rastgele sayı üretir; tüm tarihler **bugüne göre göreli** hesaplanır (böylece demo her zaman güncel görünür).

```ts
store = {
  session: { userId, role, emailVerified, locale, theme },
  ui: { network: 'online'|'offline'|'slow', dataMode: 'normal'|'empty'|'error', textScale, frame },
  users: { [id]: { name, email, department, year, interests[], avatarSeed, blocked[], status: 'active'|'suspended' } },
  clubs: { [id]: { name, categoryId, about, coverSeed, iconName, memberCount, approvalRequired, applicationsOpen, social{}, status: 'active'|'suspended' } },
  memberships: { [clubId_userId]: { status, role, note, appliedAt, decidedAt, retryAfter, rejectReason } },
  posts: { [id]: { clubId, authorId, type: 'post'|'announcement'|'poll', text, images[], poll?, pinned, createdAt, likes[], commentIds[] } },
  comments: { [id]: { postId, authorId, text, createdAt } },
  events: { [id]: { clubId, title, desc, startsAt, endsAt, place, capacity, visibility: 'public'|'members', status: 'draft'|'published'|'cancelled', coverSeed } },
  rsvps: { [eventId_userId]: { status: 'going'|'waitlist'|'attended'|'cancelled', reminder } },
  notifications: { [id]: { userId, type, refs{}, createdAt, read } },
  reports: { [id]: { targetType, targetId, reason, note, reporterId, status: 'open'|'resolved', action } },
  activity: [ { clubId, actorId, kind, createdAt, refs{} } ],
  dailyAnnouncementCount: { [clubId_date]: n }
}
```

### 6.3 Router ve yardımcılar

`navigate(route, params)`, `back()`, `switchTab(tab)`, `openSheet(id, props)`, `openDialog(id, props)`, `toast(id, props)`. Her sekme için ayrı yığın. Rota değişimi hash tabanlıdır; geri tuşu çalışır.

### 6.4 Aksiyon sözleşmesi

- Her etkileşimli DOM öğesinde `data-action="<EKRAN-ID>.<aksiyon>"` bulunur (örn. `CLB-01.join`, `MGT-02.approve`).
- Her aksiyon bir handler'a bağlıdır ve **gözlemlenebilir sonuç** üretir (K3).
- Ağ gerektiren eylemler `await fakeApi(fn, { delay: 400–900, fail })` ile çalışır: butonda yükleniyor durumu, çift tıklama engeli, çevrimdışıysa hata toast'ı, başarısızlıkta **geri alma (rollback)**.
- İyimser güncelleme (beğeni, kaydet, katıl) anında yansır; hata olursa geri alınır ve toast gösterilir.

### 6.5 i18n

- `I18N = { tr: {...}, en: {...} }`; `t("auth.login.title", { n: 3 })`. Çoğul ve sayı biçimleri `Intl.PluralRules` / `Intl.NumberFormat` ile.
- Tarih/saat: `Intl.DateTimeFormat('tr-TR' | 'en-GB')`. Göreli zaman: "2 saat önce" / "2 hours ago". Gün adları ve ay kısaltmaları dile göre.
- Anahtar adlandırma: `modül.ekran.öğe` (örn. `clubs.card.join`). Aynı metin iki yerde kullanılıyorsa tek anahtardır.
- Sözlük **ARB biçiminde dışa aktarılabilir** (`app_tr.arb`, `app_en.arb`); Assets sayfasındaki indirmeye dahildir (Bölüm 12.7). Çoğul/parametreler ICU söz diziminde (`{count, plural, one{# üye} other{# üye}}`) yazılır ki Flutter `intl` ile doğrudan kullanılabilsin.
- Kullanıcı içeriği (gönderi, duyuru, kulüp açıklaması) **çevrilmez**; yalnızca arayüz çevrilir.
- Dil seçici: giriş ekranında sağ üst köşede küçük **TR | EN** menüsü (SHT-01), ayrıca Ayarlar'da.

---

## 7. Ekran Envanteri

**Okuma kılavuzu.** Her ekran için: *Rota/Roller*, *Düzen*, *Aksiyonlar* (`data-action` → sonuç; her satır uygulanır), *Durumlar*. Sheet'ler `SHT-xx` (Bölüm 8), dialog'lar `DLG-xx` (Bölüm 9), toast'lar `TST-xx` (Bölüm 10) kimlikleriyle anılır. Aksiyon listesinde adı geçmeyen ama ekranda görünen her öğe de bir sonuç üretmek zorundadır (K2).

**Toplam kapsam:** 4 sistem + 1 onboarding + 6 kimlik + 7 kulüp + 3 akış + 4 etkinlik + 2 bildirim + 4 profil + 5 ayar + 10 yönetim + 5 süper admin = **51 ekran** (+ 34 sheet, 32 dialog, 58 toast).

---

### 7.1 Sistem

#### SYS-01 — Açılış (Splash)
- **Düzen:** Ortada `LogoPlaceholder` (ölçek + solma animasyonu, 1.2 sn), altında uygulama adı, en altta "v1.0.0".
- **Akış:** Oturum varsa → CLB-01 (rol/doğrulama/profil kontrolleri ile); yoksa ilk açılışta ONB-01, sonrasında AUT-01.
- **Aksiyon:** Yok (otomatik). Kontrol Paneli "Çıkış yap" sonrası AUT-01'e gider.

#### SYS-02 — Hata Ekranı
- **Düzen:** Hata illüstrasyonu, başlık ("Bir şeyler ters gitti"), açıklama, iki buton. Tam ekran veya liste içi (inline) varyantı vardır.
- **Aksiyonlar:** `SYS-02.retry` → butonda yükleniyor, 0.8 sn sonra `dataMode=normal` ise içerik gelir, değilse tekrar hata · `SYS-02.home` → CLB-01.
- **Tetik:** Kontrol Paneli "Hata (zorla)", ağ hatası simülasyonu.

#### SYS-03 — Çevrimdışı
- **Banner (kalıcı, üstte):** "Çevrimdışısın. Önbellekteki veriler gösteriliyor." Yazma eylemleri toast ile engellenir (TST-24). Tekrar bağlanınca banner kaybolur, TST-25 görünür.
- **Tam ekran varyant** (önbellek yoksa): illüstrasyon + `SYS-03.retry` → bağlantı yoksa sallanma + toast, varsa içerik yüklenir.

#### SYS-04 — İçerik Bulunamadı
- **Düzen:** "Bu içerik artık yok" başlığı, açıklama (silinmiş, taşınmış ya da erişim yetkin yok), `SYS-04.back` → önceki ekran, `SYS-04.home` → CLB-01.
- **Tetik:** Silinmiş gönderi/etkinlik/kulübe deep link; askıdaki kulüpteki etkinlik; engelli kullanıcıdan içerik.

---

### 7.2 Karşılama ve Kimlik

#### ONB-01 — Karşılama Slaytları
- **Roller:** Oturumsuz, ilk açılış. **Rota:** `/onboarding`.
- **Düzen:** 3 slayt (yatay kaydırma + noktalar). Slayt 1 **Keşfet** (kulüp illüstrasyonu), Slayt 2 **Katıl** (başvuru + etkinlik), Slayt 3 **Takip et** (bildirim + QR yoklama). Üstte sağda dil menüsü (SHT-01) ve "Atla"; altta noktalar + "İleri" (son slaytta "Başla").
- **Aksiyonlar:** `ONB-01.lang` → SHT-01 · `ONB-01.skip` → AUT-01 · `ONB-01.next` → sonraki slayt · `ONB-01.start` → AUT-01 · kaydırma jesti.
- **Durumlar:** Normal. İlk açılış bayrağı kaydedilir; ikinci açılışta gösterilmez (Kontrol Paneli "Sıfırla" ile tekrar).

#### AUT-01 — Giriş
- **Rota:** `/login`.
- **Düzen:** Sağ üstte **dil çipi "TR ▾"** (SHT-01). Ortada amblem + "Hoş geldin" (Display) + alt metin ("Kampüsteki tüm kulüpler, tek cebinde."). Form: E-posta, Şifre (göster/gizle ikonu). "Şifremi unuttum" (text link), **Giriş yap** (primary, tam genişlik), "Hesabın yok mu? **Kayıt ol**". Altta açılır bölüm **"Demo hesaplarla giriş"** (6 hesap çipi). Sayfa sonu: "Devam ederek Kullanım Koşulları ve Gizlilik Politikası'nı kabul etmiş olursun" (iki ayrı link).
- **Doğrulama:** Boş alan, e-posta biçimi, alan adı yalnızca üniversite e-postası (Bölüm 11.2'deki `ALLOWED_EMAIL_DOMAINS`), şifre ≥ 8 karakter. Hata: alan altında kırmızı metin + ikon, ilk hatalı alana odak.
- **Aksiyonlar:**
  - `AUT-01.lang` → SHT-01
  - `AUT-01.togglePassword` → şifre görünürlüğü
  - `AUT-01.forgot` → AUT-04
  - `AUT-01.login` → yükleniyor (0.9 sn) → sonuç tablosu aşağıda
  - `AUT-01.register` → AUT-02
  - `AUT-01.demoAccount.<id>` → alanları doldurur, 0.4 sn sonra giriş yapar
  - `AUT-01.terms` / `AUT-01.privacy` → AUT-06 (ilgili sekme)
- **Giriş sonuçları:**

| Durum | Sonuç |
|---|---|
| Başarılı, e-posta doğrulanmamış | AUT-03 |
| Başarılı, profil eksik | AUT-05 |
| Başarılı, her şey tamam | CLB-01 (+ ilk girişte DLG-03) |
| Yanlış e-posta/şifre | Alan altında hata + kart sallanır + TST-01 |
| Hesap askıda | DLG-01 |
| 5 başarısız deneme | DLG-02 (30 sn geri sayım, buton kilitli) |
| Çevrimdışı | TST-24, işlem yapılmaz |

- **Durumlar:** Yükleniyor (buton içinde döner), hata, çevrimdışı, klavye açıkken içerik kayar.

#### AUT-02 — Kayıt
- **Rota:** `/register`.
- **Düzen:** Geri oku + dil çipi. Alanlar: **Ad Soyad**, **Üniversite e-postası** (yardım metni: "Okul e-posta adresinle kayıt ol"), **Şifre** (4 segmentli güç göstergesi + kural listesi: 8+ karakter, büyük harf, rakam — sağlandıkça tikli), **Şifre tekrar**, **KVKK/Gizlilik onay kutusu** ("… okudum, kabul ediyorum" — link AUT-06). **Hesap oluştur** (primary).
- **Aksiyonlar:** `AUT-02.back` → AUT-01 · `AUT-02.lang` → SHT-01 · `AUT-02.togglePassword` · `AUT-02.legal` → AUT-06 (dönüşte onay kutusu işaretlenir) · `AUT-02.submit` → doğrulama → yükleniyor → AUT-03 · `AUT-02.toLogin` → AUT-01.
- **Hatalar:** E-posta zaten kayıtlı (`ayse.demir@…` demo'da kayıtlıdır) → alan hatası; geçersiz alan adı → "Yalnızca üniversite e-postası kullanılabilir"; şifreler uyuşmuyor; onay kutusu işaretsiz → kutu altında hata.
- **Durumlar:** Yükleniyor, hata, çevrimdışı.

#### AUT-03 — E-posta Doğrulama
- **Rota:** `/verify`.
- **Düzen:** Zarf illüstrasyonu, "E-postanı doğrula", "**{eposta}** adresine bir doğrulama bağlantısı gönderdik." Butonlar: **Doğruladım** (primary), **Tekrar gönder** (60 sn geri sayımlı; sayaç bitene kadar devre dışı), **E-postayı değiştir** (satır içi input açılır), **Çıkış yap** (text).
- **Demo davranışı:** "Doğruladım"a ilk basışta 1.2 sn sonra "Henüz doğrulanmadı" (TST-02); ikinci basışta başarı. Ayrıca ekranda **"(Demo) Bağlantıya tıkladım"** küçük butonu vardır ve doğrudan başarıya götürür.
- **Aksiyonlar:** `AUT-03.confirm` · `AUT-03.resend` → TST-03 + sayaç yeniden başlar · `AUT-03.changeEmail` → inline alan, "Güncelle" ile yeni e-posta, TST-03 · `AUT-03.logout` → DLG-06 → AUT-01 · `AUT-03.demoVerify`.
- **Başarı:** Onay animasyonu (1 sn) → AUT-05 (profil eksikse) ya da CLB-01.

#### AUT-04 — Şifre Sıfırlama
- **Rota:** `/reset`.
- **Düzen:** Başlık, açıklama, e-posta alanı, **Bağlantı gönder**. Başarıda aynı ekranda içerik değişir: onay animasyonu, "Gelen kutunu kontrol et", `Girişe dön` (primary), `Tekrar gönder` (60 sn sayaçlı).
- **Not:** Güvenlik gereği kayıtlı olmayan e-posta için de aynı başarı mesajı gösterilir.
- **Aksiyonlar:** `AUT-04.back` · `AUT-04.send` · `AUT-04.resend` → TST-03 · `AUT-04.toLogin` → AUT-01.

#### AUT-05 — Profil Tamamlama
- **Rota:** `/setup-profile`. **Düzen:** Üstte ilerleme çubuğu "1/3". 3 adım:
  1. **Fotoğraf:** Büyük avatar + "Fotoğraf ekle" (SHT-16), "Şimdilik atla".
  2. **Eğitim bilgisi:** **Bölüm** (seçici alan → SHT-02), **Sınıf** (seçici alan → SHT-03). İkisi de zorunlu.
  3. **İlgi alanları:** Çipler (Bölüm 11.4'teki 16 etiket), **en az 1, en fazla 5**; sayaç "2/5"; sınır aşılınca TST-04.
- **Alt çubuk:** Geri / **Devam** (son adımda **Tamamla**).
- **Aksiyonlar:** `AUT-05.photo` → SHT-16 · `AUT-05.skipPhoto` · `AUT-05.department` → SHT-02 · `AUT-05.year` → SHT-03 · `AUT-05.toggleInterest.<id>` · `AUT-05.next` / `back` · `AUT-05.finish` → CLB-01 + TST-05 ("Hoş geldin, {ad}!") · `AUT-05.close` → DLG-25.
- **Durumlar:** Hata (zorunlu alan boş → alan altında mesaj, devam etmez), yükleniyor.

#### AUT-06 — Yasal Metinler
- **Rota:** `/legal/:tip` (`kvkk` · `gizlilik` · `kosullar`).
- **Düzen:** Üst sekmeler (**KVKK Aydınlatma · Gizlilik Politikası · Kullanım Koşulları**), her sekmede 6–8 maddelik gerçekçi Türkçe (EN karşılığı da) kurgusal metin; sağda sabit "içindekiler" çipleri (maddeye atlar). Kayıt akışından gelindiyse altta sabit **Okudum, anladım** butonu.
- **Aksiyonlar:** `AUT-06.tab.<id>` · `AUT-06.jump.<n>` · `AUT-06.accept` → geri döner, AUT-02'de onay kutusu işaretli · `AUT-06.back`.

---

### 7.3 Kulüpler

#### CLB-01 — Kulüpler (Ana Ekran)
- **Rota:** `/clubs`. **Roller:** Tümü. Giriş sonrası ilk ekran.
- **Düzen (yukarıdan aşağı):**
  1. Büyük başlık "Kulüpler" + sağda **arama ikonu** (CLB-02).
  2. **Kulüplerim şeridi:** Yatay kaydırmalı küçük kartlar (kapak + ad + okunmamış nokta). Yöneticiysen kartta "Yönetici" rozeti. Sonunda "Tümü" kartı (PRF-03). Üye değilse şerit yerine **"İlk kulübünü bul"** bilgi kartı (illüstrasyon + "Keşfet" → listeye kaydırır).
  3. **Kategori çipleri** (yatay): Tümü + 8 kategori.
  4. **Araç satırı:** "13 kulüp" sayacı · **Filtre/Sırala** (SHT-04, aktif filtre sayısı rozetli) · **Liste/Izgara** düğmesi (tercih hatırlanır).
  5. **Kulüp kartları:** Liste görünümünde kapak (16:9), amblem/ikon, ad, kategori çipi, üye sayısı, 2 satırlık açıklama, **durum CTA'sı** (Bölüm 2.4). Izgara görünümünde 2 sütun kompakt kart.
  6. Sonda "Hepsi bu kadar" satırı.
- **Aksiyonlar:** `CLB-01.search` → CLB-02 · `CLB-01.category.<id>` · `CLB-01.filter` → SHT-04 · `CLB-01.toggleView` · `CLB-01.myClub.<id>` → CLB-03 · `CLB-01.myClubsAll` → PRF-03 · `CLB-01.discover` · `CLB-01.card.<id>` → CLB-03 · `CLB-01.join.<id>` → SHT-05 (ya da anında katılım) · `CLB-01.status.<id>` → CLB-05 · `CLB-01.refresh` (çek-yenile) · `CLB-01.clearFilters`.
- **İlk girişte:** DLG-03 (bildirim ön izni) bir kez gösterilir.
- **Durumlar:** Skeleton (6 kart) · Boş (filtre sonuçsuz: "Aramana uygun kulüp bulamadık" + **Filtreleri temizle**) · Hata (SYS-02 inline) · Çevrimdışı (banner + önbellek).

#### CLB-02 — Arama
- **Rota:** `/clubs/search`.
- **Düzen:** Otomatik odaklı arama girdisi (temizle X, **İptal**), altında sekmeler **Kulüpler · Etkinlikler**.
  - **Sorgu boşken:** *Son aramalar* (tek tek silinebilir, "Temizle") · *Popüler aramalar* çipleri · *Sizin için önerilen kulüpler* (ilgi alanlarına göre 3 kart).
  - **Yazarken:** 250 ms gecikmeli anlık sonuçlar, eşleşen kısım kalın.
- **Aksiyonlar:** `CLB-02.cancel` → geri · `CLB-02.clear` · `CLB-02.tab.<id>` · `CLB-02.recent.<i>` → sorguyu doldurur · `CLB-02.removeRecent.<i>` · `CLB-02.clearRecent` → TST-06 (Geri al) · `CLB-02.popular.<i>` · `CLB-02.result.club.<id>` → CLB-03 · `CLB-02.result.event.<id>` → EVT-02 · `Enter` → sorguyu "Son aramalar"a kaydeder.
- **Durumlar:** Sonuçsuz ("'{sorgu}' için sonuç yok" + öneri çipleri), yükleniyor.

#### CLB-03 — Kulüp Detayı
- **Rota:** `/clubs/:id`. **Modlar:** `visitor` · `pending` · `rejected` · `member` · `manager` (board/president) · `advisor`.
- **Üst alan:** Parallax kapak (CoverArt), geri oku; sağ üstte **Paylaş** (SHT-15) ve **⋯** (SHT-06). Yarı taşan amblem, kulüp adı (Title L), kategori çipi, kulüp tipi etiketi ("Onay gerekli" / "Anında katılım"), üye sayısı + avatar grubu (+N), üye ise rol rozeti.
- **Birincil CTA:** Mod'a göre (Bölüm 2.4). `manager`: **Yönetim** (primary) + **Etkinlik oluştur** (tonal). `advisor`: **Yönetimi görüntüle** (tonal) + salt okunur bant.
- **Yapışkan sekmeler:** **Hakkında · Etkinlikler · Gönderiler · Üyeler**
  - *Hakkında:* uzun açıklama ("Devamı"), kuruluş yılı, iletişim/sosyal bağlantılar (e-posta, Instagram, web), danışman kartı, yönetim kurulu avatar listesi (→ CLB-07), katılım koşulları maddeleri, "Bu kulübü şikayet et" metin butonu (SHT-10).
  - *Etkinlikler:* **Yaklaşan / Geçmiş** segmenti. Ziyaretçi/bekleyen/reddedilen yalnızca `public` etkinlikleri görür; üye hepsini görür. Kart → EVT-02.
  - *Gönderiler:* `member`/`manager`/`advisor` için FED-01; diğerleri için **kilit durumu** (kilit ikonu, "Gönderileri görmek için kulübe üye ol", mod'a uygun CTA).
  - *Üyeler:* Ziyaretçi için kilit + yalnızca sayı. Üye için ilk 5 üye + **Tüm üyeler** (CLB-06).
- **Aksiyonlar:** `CLB-03.back` · `CLB-03.share` → SHT-15 · `CLB-03.menu` → SHT-06 · `CLB-03.join` → SHT-05 / anında katılım · `CLB-03.requestStatus` → CLB-05 · `CLB-03.openManage` → MGT-01 (veya SHT-18) · `CLB-03.createEvent` → MGT-05 · `CLB-03.tab.<id>` · `CLB-03.about.link.<tip>` → DLG-32 · `CLB-03.about.person.<id>` → CLB-07 · `CLB-03.report` → SHT-10 · `CLB-03.event.<id>` → EVT-02 · `CLB-03.allMembers` → CLB-06 · `CLB-03.loadMore`.
- **Durumlar:** Skeleton · Kulüp askıda (üstte `warning` bant "Bu kulüp geçici olarak askıda", CTA yok) · Silinmiş (SYS-04) · Çevrimdışı.

#### CLB-04 — Başvuru Gönderildi
- **Rota:** `/clubs/:id/applied`. Tam ekran.
- **Düzen:** Çizilen onay animasyonu, "İsteğin kulüp yönetimine iletildi", açıklama ("Sonuç bildirimle gelecek. Yanıt genellikle 1–3 gün içinde verilir."), **özet kartı** (kulüp, gönderilme tarihi, notun). Bildirim izni kapalıysa inline kart: "Sonucu kaçırma — bildirimleri aç" (→ DLG-03).
- **Aksiyonlar:** `CLB-04.browse` (**Diğer kulüplere göz at**, primary) → CLB-01 · `CLB-04.myApplications` (**Başvurularım**, text) → PRF-03 · `CLB-04.close` → CLB-03 (bekleyen modunda) · `CLB-04.enableNotifications` → DLG-03.
- **Kural:** Geri tuşu CLB-03'e döner; SHT-05 yeniden açılmaz.

#### CLB-05 — Başvuru Durumu
- **Rota:** `/clubs/:id/application`.
- **Düzen:** Kulüp mini kartı, **zaman çizelgesi** (Gönderildi → İnceleniyor → Sonuç) ve duruma göre içerik:
  - `pending`: Notun (düzenlenebilir alan + **Kaydet**), **İsteği iptal et** (destructive outline → DLG-07).
  - `rejected`: Neden kartı (varsa), **"Tekrar başvurabileceğin tarih: {tarih}"** geri sayım çipi. Süre dolduysa **Tekrar başvur** (primary → SHT-05), dolmadıysa devre dışı + açıklama.
  - `active` (yeni onaylı): "Üyeliğin onaylandı" + **Kulübe git** (primary → CLB-03).
  - `removed`: Çıkarılma bilgisi + tekrar başvuru tarihi.
- **Aksiyonlar:** `CLB-05.back` · `CLB-05.saveNote` → TST-07 · `CLB-05.cancel` → DLG-07 · `CLB-05.reapply` → SHT-05 · `CLB-05.openClub` → CLB-03.

#### CLB-06 — Üye Listesi
- **Rota:** `/clubs/:id/members`. **Roller:** Üye ve üstü.
- **Düzen:** Arama + rol çipleri (**Tümü · Yönetim · Üye**). Gruplu sticky başlıklar (**Başkan · Yönetim Kurulu · Danışman · Üyeler**) ve toplam sayaç. Satır: avatar, ad, bölüm · sınıf, rol rozeti. Yönetici modunda satır sonunda **⋯** (SHT-21).
- **Aksiyonlar:** `CLB-06.search` · `CLB-06.filter.<id>` · `CLB-06.member.<id>` → CLB-07 · `CLB-06.menu.<id>` → SHT-21 · `CLB-06.back`.
- **Durumlar:** Skeleton, sonuçsuz arama, çevrimdışı.

#### CLB-07 — Kullanıcı Profili (Başkası)
- **Rota:** `/users/:id`.
- **Düzen:** Avatar (96), ad, bölüm · sınıf, **ortak kulüpler** çipleri (→ CLB-03), rozetler. **Gizlilik kuralı:** Ortak kulübün yoksa yalnızca ad ve avatar + "Bu profil yalnızca ortak kulüp üyelerine açık" notu. Kulüp yöneticisi bağlamında sınıf ve e-posta da görünür (e-posta için **Kopyala** → TST-08). Sağ üstte **⋯** (SHT-27).
- **Yönetici bağlamında** ek satır: **Rolü değiştir** (SHT-22) ve **Üyelikten çıkar** (DLG-19).
- **Engelli kullanıcı:** Banner "Bu kullanıcıyı engelledin" + **Engeli kaldır**.
- **Aksiyonlar:** `CLB-07.back` · `CLB-07.menu` → SHT-27 · `CLB-07.copyEmail` · `CLB-07.club.<id>` → CLB-03 · `CLB-07.changeRole` · `CLB-07.remove` · `CLB-07.unblock` → TST-09.

---

### 7.4 Akış

#### FED-01 — Kulüp Akışı (CLB-03 içinde "Gönderiler" sekmesi)
- **Düzen:**
  - Yönetici için üstte kompakt yazı kutusu ("Kulübüne bir şey yaz…") → FED-03.
  - Filtre çipleri: **Tümü · Duyurular · Anketler · Görseller**.
  - Sabitlenmiş gönderi en üstte (sabit ikonu).
  - **Gönderi kartı:** avatar, yazar adı + rol rozeti, kulüp, göreli zaman, **⋯** (SHT-08); metin (5 satırdan sonra "Devamı"); görsel ızgarası (1–4 görsel); tür etiketi (Duyuru = megafon + tonal kırmızı); **anket bloğu**; aksiyon satırı: **Beğen** (kalp, sayı, iyimser) · **Yorum** (sayı) · **Paylaş** · **Kaydet** (yer imi).
  - "Yeni gönderiler ↑" çipi (Kontrol Paneli "Yeni bildirim simüle et" ile birlikte tetiklenebilir).
- **Anket davranışı:** Oy vermeden önce seçenekler; oy verince yüzde çubukları animasyonla dolar, kendi seçimin işaretli, toplam oy ve kalan süre görünür; süresi bitince "Anket sona erdi". Oy değiştirilemez (TST-10).
- **Aksiyonlar:** `FED-01.compose` → FED-03 · `FED-01.filter.<id>` · `FED-01.post.<id>` → FED-02 · `FED-01.author.<id>` → CLB-07 · `FED-01.menu.<id>` → SHT-08 · `FED-01.like.<id>` · `FED-01.comment.<id>` → SHT-09 · `FED-01.share.<id>` → SHT-15 · `FED-01.save.<id>` → TST-11 (Geri al) · `FED-01.image.<id>.<i>` → SHT-34 · `FED-01.vote.<postId>.<optionId>` · `FED-01.more.<id>` (metni açar) · `FED-01.newPosts` · `FED-01.refresh`.
- **Durumlar:** Skeleton · Boş ("Henüz gönderi yok"; yönetici için **İlk gönderini yaz** CTA) · Kilitli (ziyaretçi) · Çevrimdışı (beğeni/oy kuyruğa alınmaz, TST-24).

#### FED-02 — Gönderi Detayı
- **Rota:** `/clubs/:id/posts/:postId`.
- **Düzen:** Genişletilmiş gönderi kartı (tam metin, tüm görseller), altında yorum listesi, **sabit yorum girişi** (avatar + alan + gönder; boşken devre dışı; 500 karakter, 400'den sonra sayaç). Yorum satırı: avatar, ad + rol rozeti, zaman, metin, **⋯** (kendi yorumun: Sil; yönetici: Sil/Şikayet; diğerleri: Şikayet et/Engelle). Yanıtlama yok (tek seviye).
- **Danışman:** Giriş alanı yerine "Danışman olarak yorum yazamazsın" bilgisi.
- **Aksiyonlar:** `FED-02.back` · `FED-02.like` · `FED-02.share` → SHT-15 · `FED-02.save` · `FED-02.menu` → SHT-08 · `FED-02.sendComment` → yeni yorum listenin sonuna, kaydırır, TST-12 · `FED-02.commentMenu.<id>` → SHT-27/DLG-11 · `FED-02.vote.<optionId>` · `FED-02.image.<i>` → SHT-34 · `FED-02.author.<id>` → CLB-07.
- **Durumlar:** Skeleton, silinmiş gönderi (SYS-04), yorum yok ("İlk yorumu sen yaz").

#### FED-03 — Gönderi / Duyuru / Anket Oluştur
- **Rota:** `/clubs/:id/compose` (düzenleme: `?edit=postId`). **Roller:** `board`, `president`.
- **Düzen:** Üst çubuk: **X** (DLG-25), başlık, sağda **Yayınla** (geçersizken devre dışı). Altında **segmented tür seçici: Gönderi · Duyuru · Anket**. Yazar satırı (avatar, kulüp adı; birden fazla kulüp yönetiyorsa seçici → SHT-18).
  - **Gönderi:** Çok satırlı metin (1000, sayaçlı), **Görsel ekle** (SHT-16; en çok 4, her birinde X ile kaldırma), **Sabitle** anahtarı.
  - **Duyuru:** Başlık (80, zorunlu), metin, **"Üyelere bildirim gönder"** anahtarı (varsayılan açık), altında **"Bugünkü duyuru hakkı: 1/2"** ilerleme çubuğu. Hak 0 ise anahtar devre dışı + açıklama. **Bildirim önizlemesi** kartı (başlık + gövde, cihaz bildirimi görünümü).
  - **Anket:** Soru (zorunlu), seçenekler (2–4; **Seçenek ekle** / her satırda sil), **Süre** segmenti (1 gün · 3 gün · 7 gün), "Sonuçlar oy verince görünsün" anahtarı.
- **Ek menü (⋯):** Taslak kaydet, Önizle (gönderi kartı olarak), Temizle.
- **Aksiyonlar:** `FED-03.close` → DLG-25 (değişiklik varsa) · `FED-03.type.<id>` · `FED-03.addImage` → SHT-16 · `FED-03.removeImage.<i>` · `FED-03.pin` · `FED-03.pushToggle` · `FED-03.addOption` / `removeOption.<i>` · `FED-03.duration.<id>` · `FED-03.saveDraft` → TST-13 · `FED-03.preview` · `FED-03.publish` → (duyuru + hak doluysa DLG-24) → yükleniyor → FED-01, yeni gönderi 1.5 sn vurgulanır, TST-14 (Görüntüle).
- **Doğrulama:** Boş metin/soru, 2'den az seçenek, aynı seçenek metni. Hatalar alan altında.
- **Durumlar:** Yükleniyor (yayınlarken buton), çevrimdışı (taslak yerelde saklanır, yayınlama TST-24), danışman erişemez.

---

### 7.5 Etkinlikler

#### EVT-01 — Etkinlikler
- **Rota:** `/events`.
- **Düzen:** Büyük başlık, sağda **Biletlerim** ikonu (EVT-04) ve **arama** (CLB-02, Etkinlikler sekmesi). **Segmented: Liste · Takvim.** Filtre çipleri: **Tümü · Bugün · Bu hafta · Kulüplerim · Herkese açık** + **Filtre** (SHT-11).
  - **Liste:** Tarih gruplarıyla (Bugün, Yarın, Bu hafta, Daha sonra) sticky başlıklar. **Etkinlik kartı:** küçük kapak, **tarih rozeti** (gün + ay), başlık, kulüp adı, saat · yer, **kontenjan çubuğu** ("48/60"), **durum etiketi** (Katılıyorsun · Bekleme listesi · Dolu · Üyelere özel (kilit) · İptal), hızlı **Katıl** butonu.
  - **Takvim:** Aylık ızgara (Pazartesi başlangıçlı; EN'de Pazar), gün başına etkinlik noktası (en çok 3 nokta), bugün halkalı, seçili gün dolu daire; ay oklarıyla gezinme + **Bugün** düğmesi; altta seçili günün etkinlik listesi.
- **Kural:** `members` görünürlüklü etkinlikler yalnızca o kulübün üyelerine listelenir.
- **Aksiyonlar:** `EVT-01.tickets` → EVT-04 · `EVT-01.search` · `EVT-01.view.<id>` · `EVT-01.chip.<id>` · `EVT-01.filter` → SHT-11 · `EVT-01.card.<id>` → EVT-02 · `EVT-01.join.<id>` → SHT-12 (dolu ise DLG-15, daha önce katıldıysa EVT-03) · `EVT-01.club.<id>` → CLB-03 · `EVT-01.prevMonth` / `nextMonth` / `today` · `EVT-01.day.<date>` · `EVT-01.refresh` · `EVT-01.clearFilters`.
- **Durumlar:** Skeleton · Boş ("Bu aralıkta etkinlik yok") · Hata · Çevrimdışı.

#### EVT-02 — Etkinlik Detayı
- **Rota:** `/events/:id`.
- **Düzen:** Parallax kapak, geri, paylaş (SHT-15), **⋯** (SHT-14/13/10 kısayolları; yönetici için SHT-23). Başlık, kulüp satırı (→ CLB-03), kategori etiketi, görünürlük etiketi. Bilgi kartları:
  - **Tarih ve saat** (uzun biçim + süre),
  - **Yer** (harita yer tutucu SVG + **Yol tarifi** → DLG-32),
  - **Kontenjan** (ilerleme çubuğu + "12 kişi kaldı", bekleme listesi sayısı),
  - **Hatırlatıcı** satırı (SHT-13) ve **Takvime ekle** (SHT-14),
  - **Açıklama** ("Devamı"),
  - **Katılımcılar** avatar grubu (yalnızca üye ve yönetici görür).
- **Yapışkan CTA durumları:**

| Durum | Görünüm | Birincil aksiyon |
|---|---|---|
| Katılmıyor, yer var | **Katıl** | SHT-12 |
| Katılıyor | **Biletini göster** + "Vazgeç" (text) | EVT-03 · DLG-14 |
| Dolu | **Bekleme listesine katıl** | DLG-15 |
| Bekleme listesinde | "Bekleme listesindesin ({n}. sıra)" + **Ayrıl** | DLG-14 (bekleme varyantı) |
| Sadece üyelere + üye değil | Kilit + **Kulübe başvur** | CLB-03 |
| Etkinlik bitti | "Etkinlik sona erdi" (devre dışı) / katıldıysa "Katıldın" rozeti | — |
| İptal edildi | Üstte `danger` bant "Bu etkinlik iptal edildi" + neden, CTA yok; ilk açılışta DLG-16 gösterilir | — |
| Yönetici | **Düzenle** · **Katılımcılar** · **Yoklama başlat** | MGT-05 · MGT-06 · MGT-07 |
| Danışman | "Salt okunur" bant, CTA yok | — |

- **Aksiyonlar:** `EVT-02.back` · `EVT-02.share` · `EVT-02.menu` · `EVT-02.club` · `EVT-02.directions` · `EVT-02.reminder` → SHT-13 · `EVT-02.addToCalendar` → SHT-14 · `EVT-02.join` · `EVT-02.ticket` · `EVT-02.leave` · `EVT-02.waitlist` · `EVT-02.attendees` · `EVT-02.report` · yönetici aksiyonları.
- **Durumlar:** Skeleton, silinmiş (SYS-04), çevrimdışı.

#### EVT-03 — Bilet (QR)
- **Rota:** `/events/:id/ticket`.
- **Düzen:** Bilet kartı (üstte etkinlik adı, tarih, yer; ortada **QR** — 29×29 modüllü, üç köşe konum işaretli, `seed`'e göre deterministik SVG; altında kod "GU-7F3K-92QX"; katılımcı adı). Üstte "Ekran parlaklığı artırıldı" çipi (simüle).
- **Durum rozeti:** **Geçerli** (yeşil) · **Okutuldu** (gri, QR bulanık, tarih-saat, onay ikonu) · **İptal** (kırmızı, QR çizili).
- **Aksiyonlar:** `EVT-03.back` · `EVT-03.addToCalendar` → SHT-14 · `EVT-03.leave` → DLG-14 · `EVT-03.openEvent` → EVT-02 · `EVT-03.demoScan` (**"Okutuldu simüle et (demo)"** — durum Okutuldu olur, yönetici yoklama listesine yansır, TST-15).

#### EVT-04 — Etkinliklerim
- **Rota:** `/events/mine`.
- **Düzen:** Segmented **Yaklaşan · Geçmiş · Bekleme listesi**. Satır/kart: etkinlik, durum etiketi, **Bilet** kısayolu. Geçmişte "Katıldın" / "Gelmedin" etiketi.
- **Aksiyonlar:** `EVT-04.back` · `EVT-04.tab.<id>` · `EVT-04.event.<id>` → EVT-02 · `EVT-04.ticket.<id>` → EVT-03 · `EVT-04.leave.<id>` → DLG-14.
- **Durumlar:** Her sekme için boş durum + "Etkinlikleri keşfet" CTA, skeleton.

---

### 7.6 Bildirimler

#### NTF-01 — Bildirim Merkezi
- **Rota:** `/notifications`.
- **Düzen:** Büyük başlık; sağda **Tümünü okundu yap** (check-check) ve **Ayarlar** (NTF-02). Filtre çipleri: **Tümü · Okunmamış · Kulüpler · Etkinlikler · Sistem**. Gruplar: Bugün · Dün · Bu hafta · Daha eski. Bildirim izni kapalıysa üstte kapatılabilir banner ("Bildirimler kapalı — **Aç**" → DLG-03).
- **Satır:** Tür ikonu (renkli daire), başlık (okunmamışta kalın), 2 satır gövde, zaman, okunmamış kırmızı nokta.
- **Hareketler:** Sola kaydır → **Sil** (TST-16, Geri al); sağa kaydır → **Okundu/Okunmadı**; uzun bas → mini menü (Okundu yap, Sil, Bu türü kapat).
- **Dokununca:** Okundu olur ve türün hedefine gider:

| Tür (`type`) | Alıcı | İkon | Hedef |
|---|---|---|---|
| `application_received` | Yönetim | `user-plus` | MGT-02 (ilgili başvuru SHT-19 açık) |
| `application_approved` | Başvuran | `check-circle` | CLB-03 (üye modu) |
| `application_rejected` | Başvuran | `x-circle` | CLB-05 |
| `removed_from_club` | Üye | `user-x` | CLB-05 |
| `role_changed` | Üye | `user-cog` | CLB-03 |
| `announcement` | Üyeler | `megaphone` | FED-02 |
| `event_new` | Üyeler | `calendar-plus` | EVT-02 |
| `event_reminder` | Katılımcı | `bell-ring` | EVT-03 |
| `event_cancelled` | Katılımcı | `calendar-x` | EVT-02 (ilk açılışta DLG-16) |
| `waitlist_promoted` | Bekleme listesi | `ticket` | EVT-03 |
| `report_resolved` | Şikayet eden | `shield-check` | Bilgi dialog'u (TST-17) |
| `new_report` | Süper admin | `flag` | ADM-04 |
| `system` | Herkes | `info` | SET-04 |

- **Aksiyonlar:** `NTF-01.markAllRead` → TST-18 · `NTF-01.settings` → NTF-02 · `NTF-01.filter.<id>` · `NTF-01.item.<id>` · `NTF-01.swipeDelete.<id>` · `NTF-01.swipeRead.<id>` · `NTF-01.menu.<id>` · `NTF-01.enable` → DLG-03 · `NTF-01.dismissBanner` · `NTF-01.refresh`.
- **Durumlar:** Skeleton · Boş ("Henüz bildirimin yok") · Hata · Çevrimdışı.

#### NTF-02 — Bildirim Tercihleri
- **Rota:** `/settings/notifications`.
- **Düzen:** Üstte **sistem izni kartı** (Açık/Kapalı; kapalıysa **İzni aç** → DLG-03). Anahtarlar: **Duyurular · Etkinlik hatırlatmaları · Yeni etkinlikler · Başvuru sonuçları · Yönetim bildirimleri** (yalnızca yöneticilere) **· Sistem**. **Hatırlatma zamanı** (1 saat önce / 1 gün önce segmenti). **Sessiz saatler** anahtarı + başlangıç/bitiş saat alanları (SHT-29). **Kulüp bazlı ayarlar** listesi (SHT-07).
- Her değişiklik anında kaydedilir → TST-19.
- **Aksiyonlar:** `NTF-02.back` · `NTF-02.permission` · `NTF-02.toggle.<id>` · `NTF-02.reminderTime.<id>` · `NTF-02.quiet` · `NTF-02.quietFrom` / `quietTo` → SHT-29 · `NTF-02.club.<id>` → SHT-07.

---

### 7.7 Profil ve Ayarlar

#### PRF-01 — Profilim
- **Rota:** `/profile`.
- **Düzen:** Avatar (96), ad, bölüm · sınıf, **Profili düzenle** (outline). Üç sayaç kartı: **Kulüp · Katıldığım etkinlik · Bekleyen başvuru** (her biri ilgili ekrana gider). Yöneticiyse **"Yönettiğim kulüpler"** kartı (kulüp satırları + **Yönetim paneli**). **Kulüplerim** önizlemesi (3 + "Tümü"). Hızlı bağlantılar: **Biletlerim** (EVT-04), **Kaydedilenler** (PRF-04), **Ayarlar** (SET-01). İlgi alanları çipleri. Süper adminde rol etiketi.
- **Aksiyonlar:** `PRF-01.edit` → PRF-02 · `PRF-01.stat.clubs` → PRF-03 · `PRF-01.stat.events` → EVT-04 · `PRF-01.stat.pending` → PRF-03 (Bekleyen sekmesi) · `PRF-01.managed.<id>` → MGT-01 · `PRF-01.managedAll` → SHT-18 · `PRF-01.club.<id>` → CLB-03 · `PRF-01.allClubs` → PRF-03 · `PRF-01.tickets` · `PRF-01.saved` · `PRF-01.settings` · `PRF-01.avatar` → SHT-16 (hızlı değiştirme).
- **Durumlar:** Skeleton, boş bölümler ("Henüz kulübün yok" + Keşfet).

#### PRF-02 — Profili Düzenle
- **Rota:** `/profile/edit`.
- **Düzen:** Avatar değiştir (SHT-16), **Ad Soyad**, **Bölüm** (SHT-02), **Sınıf** (SHT-03), **İlgi alanları** çipleri (1–5), **Kısa biyografi** (140 karakter, sayaçlı), **E-posta** (salt okunur, kilit ikonu + "Üniversite e-postası değiştirilemez"). Gizlilik bilgisi kartı: "Profilin yalnızca ortak kulüp üyelerine ve kulüp yöneticilerine görünür." Sticky **Kaydet** (değişiklik yoksa devre dışı).
- **Aksiyonlar:** `PRF-02.back` → değişiklik varsa DLG-25 · `PRF-02.avatar` · `PRF-02.department` · `PRF-02.year` · `PRF-02.toggleInterest.<id>` · `PRF-02.lockedEmail` → TST-20 · `PRF-02.save` → yükleniyor → PRF-01 + TST-21.

#### PRF-03 — Kulüplerim ve Başvurularım
- **Rota:** `/profile/clubs`.
- **Düzen:** Sekmeler **Üyeliklerim · Bekleyen · Geçmiş** (Geçmiş = reddedilen, ayrılınan, çıkarılan). Satır: amblem, ad, rol/durum rozeti, tarih. Her satırda **⋯**: Üyeliklerde **Kulüpten ayrıl** (DLG-08), Bekleyende **İsteği iptal et** (DLG-07), Geçmişte **Tekrar başvur** (retryAfter geçtiyse).
- **Aksiyonlar:** `PRF-03.back` · `PRF-03.tab.<id>` · `PRF-03.row.<id>` → CLB-03 (bekleyen/reddedilen için CLB-05) · `PRF-03.menu.<id>` · `PRF-03.discover` → CLB-01.
- **Durumlar:** Her sekme için boş durum, skeleton.

#### PRF-04 — Kaydedilenler
- **Rota:** `/profile/saved`.
- **Düzen:** Kaydedilen gönderilerin kart listesi (kulüp adı, özet, zaman). Her kartta **Kaydı kaldır** (yer imi) ve gövde dokunuşu FED-02.
- **Aksiyonlar:** `PRF-04.back` · `PRF-04.post.<id>` → FED-02 · `PRF-04.unsave.<id>` → TST-11 (Geri al).
- **Durumlar:** Boş ("Kaydettiğin gönderiler burada görünür"), silinmiş gönderi kartı ("İçerik kaldırıldı" + kaldır).

#### SET-01 — Ayarlar
- **Rota:** `/settings`.
- **Düzen (gruplu liste):**
  - **Görünüm:** Tema (SHT-17; sağda seçim) · Dil (SHT-01 liste varyantı) · Yazı boyutu (önizlemeli segment 100/130/160).
  - **Bildirimler:** Bildirim tercihleri (NTF-02).
  - **Gizlilik ve güvenlik:** Engellenen kullanıcılar (SET-02) · Gizlilik Politikası / KVKK (AUT-06) · Şifre değiştir (SHT-32).
  - **Destek:** Yardım ve destek (SET-05) · Hakkında (SET-04).
  - **Hesap:** **Oturumu kapat** (DLG-06) · **Hesabı sil** (kırmızı metin; SET-03).
  - Altta "v1.0.0 (demo)".
- **Aksiyonlar:** `SET-01.back` · `SET-01.theme` · `SET-01.language` · `SET-01.textScale.<id>` · `SET-01.notifications` · `SET-01.blocked` · `SET-01.privacy` · `SET-01.password` · `SET-01.support` · `SET-01.about` · `SET-01.logout` · `SET-01.delete`.

#### SET-02 — Engellenen Kullanıcılar
- **Rota:** `/settings/blocked`.
- **Düzen:** Açıklama metni, liste (avatar, ad, **Engeli kaldır**). Boş: "Kimseyi engellemedin."
- **Aksiyonlar:** `SET-02.back` · `SET-02.unblock.<id>` → TST-09 (Geri al) · `SET-02.user.<id>` → CLB-07.

#### SET-03 — Hesabı Sil (3 adım)
- **Rota:** `/settings/delete`.
  1. **Uyarı:** Ne silinir (üyelikler, başvurular, biletler, bildirimler) / ne kalır (gönderi ve yorumlar **"Silinmiş kullanıcı"** olarak anonimleşir). Kulüp **başkanıysan** engel kartı: "Önce başkanlığı devretmelisin" + kulüp listesi + **Devret** (MGT-03) — bu durumda ilerlenemez.
  2. **Neden** (opsiyonel radyo listesi + serbest alan).
  3. **Onay:** Şifre alanı + "**SİL** yazarak onayla" alanı. **Hesabımı kalıcı olarak sil** (dolu `danger`) yalnızca doğru yazılınca etkin.
- **Aksiyonlar:** `SET-03.back` · `SET-03.next` · `SET-03.reason.<id>` · `SET-03.transfer.<clubId>` · `SET-03.confirm` → yükleniyor → AUT-01 + TST-22 ("Hesabın silindi").
- **Hata:** Yanlış şifre (alan hatası).

#### SET-04 — Hakkında
- **Rota:** `/settings/about`.
- **Düzen:** Amblem, sürüm, "Gümüşhane Üniversitesi öğrenci kulüpleri için, girişimcilik dersi projesi olarak geliştirilmiştir." Ekip kartı (3 kurgusal isim), **Açık kaynak lisansları** (Lucide — ISC, Montserrat — OFL, Inter — OFL; her satır genişler), **Sürüm notları** akordiyonu, **Kullanım Koşulları** ve **Gizlilik** bağlantıları.
- **Aksiyonlar:** `SET-04.back` · `SET-04.license.<id>` · `SET-04.releaseNotes` · `SET-04.terms` · `SET-04.privacy` · `SET-04.support` → SET-05.

#### SET-05 — Yardım ve Destek
- **Rota:** `/settings/support`.
- **Düzen:** Arama kutusu (SSS'de filtreler), **SSS akordiyonu** (8 soru, gerçek cevaplı: kulübe başvuru, başvuru neden beklemede, QR okutulmuyor, bildirim gelmiyor, hesap silme, kulüp nasıl açılır, e-posta değiştirme, kullanıcı şikayeti). **Bize ulaş** formu: **Konu** (Hata bildirimi · Öneri · Hesap · Kulüp · Diğer — seçici), **Mesaj** (500), **Ekran görüntüsü ekle** (SHT-16, opsiyonel), **Gönder**.
- **Gönderme:** Yükleniyor → formun yerini başarı durumu alır ("Mesajın alındı. Talep no: #GU-4821") + TST-23.
- **Aksiyonlar:** `SET-05.back` · `SET-05.search` · `SET-05.faq.<id>` · `SET-05.subject` · `SET-05.attach` · `SET-05.send` · `SET-05.newRequest` (başarı durumundan formu sıfırlar).

---

### 7.8 Kulüp Yönetimi

> Bu bölümdeki ekranlar `board`, `president` için tam yetkili; `advisor` için **salt okunur**, yazma aksiyonları devre dışı + TST-26. Hepsinin üstünde mevcut kulüp adı ve rol rozeti görünür; çoklu kulüp yönetenlerde ad **▾** ile SHT-18'i açar.

#### MGT-01 — Panel Özeti
- **Rota:** `/manage/:clubId`.
- **Düzen:**
  1. Başlık satırı: kulüp adı **▾** + rol rozeti. Danışmanda üstte kalıcı "Salt okunur" bandı.
  2. **KPI kartları (2×2):** Toplam üye (+x bu ay) · **Bekleyen başvuru** (kırmızı vurgu) · Yaklaşan etkinlik · Bu ay duyuru.
  3. **Hızlı işlemler** (3×2 ızgara): Gönderi yaz · Duyuru yap · Etkinlik oluştur · Yoklama al · Üyeler · Kulüp ayarları.
  4. **Üye artışı** mini çizgi grafik (8 hafta; noktaya dokununca tooltip).
  5. **Bugünkü duyuru hakkı:** 1/2 göstergesi.
  6. **Yaklaşan etkinlikler** (2 kart → MGT-06).
  7. **Son hareketler** (5 satır) + **Tümü** (MGT-10).
- **Aksiyonlar:** `MGT-01.back` · `MGT-01.switchClub` → SHT-18 · `MGT-01.kpi.members` → MGT-03 · `MGT-01.kpi.pending` → MGT-02 · `MGT-01.kpi.events` → MGT-04 · `MGT-01.kpi.announcements` → MGT-08 · `MGT-01.quick.post` / `announce` → FED-03 · `MGT-01.quick.event` → MGT-05 · `MGT-01.quick.attendance` → MGT-06 · `MGT-01.quick.members` → MGT-03 · `MGT-01.quick.settings` → MGT-09 · `MGT-01.chart.point.<i>` → tooltip · `MGT-01.event.<id>` → MGT-06 · `MGT-01.activityAll` → MGT-10.
- **Durumlar:** Skeleton · Yeni kulüp (sıfır veri: "Henüz üyen yok — kulüp bağlantısını paylaş" + **Paylaş** → SHT-15) · Çevrimdışı.

#### MGT-02 — Başvurular
- **Rota:** `/manage/:clubId/applications`.
- **Düzen:** Sekmeler **Bekleyen (n) · Onaylanan · Reddedilen**; arama; sıralama ikonu (yeni/eski). **Başvuru satırı:** avatar, ad, bölüm · sınıf, not önizlemesi (1 satır), göreli zaman; sağda iki **hızlı buton: ✓ Onayla** ve **✕ Reddet** (renk + ikon + `aria-label`; 48 px).
  - **Onayla:** İyimser: satır soluklaşıp çıkar → **TST-27** ("{ad} onaylandı") + **Geri al** (6 sn). Başvuranın bildirimlerine `application_approved` düşer, üye sayısı +1.
  - **Reddet:** SHT-20 (neden opsiyonel) → satır çıkar → TST-28.
  - **Satır gövdesi:** SHT-19 (detay).
  - **Çoklu seçim:** Uzun bas → onay kutuları; üst çubuk "3 seçili" + **Onayla** / **Reddet** → DLG-17. **Hepsini seç** seçeneği.
  - **Başvurular kapalıysa:** Üstte bilgi bandı + **Başvuruları aç** anahtarı.
- **Çakışma demo'su:** Seed'deki "Cem Aydın" başvurusu `stale=true`dur; onaylanmak/reddedilmek istenirse **DLG-18** ("Bu başvuru zaten sonuçlandırıldı") açılır ve liste yenilenir.
- **Aksiyonlar:** `MGT-02.back` · `MGT-02.tab.<id>` · `MGT-02.search` · `MGT-02.sort` · `MGT-02.row.<id>` → SHT-19 · `MGT-02.approve.<id>` · `MGT-02.reject.<id>` · `MGT-02.select.<id>` · `MGT-02.selectAll` · `MGT-02.bulkApprove` / `bulkReject` → DLG-17 · `MGT-02.undo` · `MGT-02.toggleOpen` → TST-54.
- **Durumlar:** Skeleton · Boş ("Bekleyen başvuru yok") · Hata · Çevrimdışı (işlem yapılmaz, TST-24).

#### MGT-03 — Üye Yönetimi
- **Rota:** `/manage/:clubId/members`.
- **Düzen:** Arama; rol çipleri **Tümü · Başkan · Yönetim · Danışman · Üye**; sıralama (ad, katılım tarihi, katılım oranı); sayaç. **Satır:** avatar, ad, rol rozeti, "Mart 2026'dan beri", etkinlik katılım oranı (küçük ilerleme "%80"), **⋯** (SHT-21). Başkana ⋯ yok. Başkan için sayfa altında **"Başkanlığı devret"** kartı. Üst çubuk **⋯**: **Üye listesini dışa aktar (CSV)**.
- **Aksiyonlar:** `MGT-03.back` · `MGT-03.search` · `MGT-03.filter.<id>` · `MGT-03.sort` · `MGT-03.member.<id>` → CLB-07 · `MGT-03.menu.<id>` → SHT-21 · `MGT-03.transfer` → SHT-25 → DLG-21 · `MGT-03.export` → gerçek `uyeler.csv` indirir + TST-29.
- **Durumlar:** Skeleton, sonuçsuz arama, boş (yeni kulüp).

#### MGT-04 — Etkinlik Yönetimi
- **Rota:** `/manage/:clubId/events`.
- **Düzen:** Segmented **Taslak · Yayında · Geçmiş · İptal**. Satır: başlık, tarih, kayıtlı/kontenjan, görünürlük etiketi, durum, **⋯** (SHT-23). Sağ altta **+ Etkinlik** FAB.
- **Aksiyonlar:** `MGT-04.back` · `MGT-04.tab.<id>` · `MGT-04.event.<id>` → EVT-02 · `MGT-04.menu.<id>` → SHT-23 · `MGT-04.create` → MGT-05.
- **Durumlar:** Her sekme için boş durum.

#### MGT-05 — Etkinlik Oluştur / Düzenle
- **Rota:** `/manage/:clubId/events/new` · `.../events/:id/edit`.
- **Düzen:** Stepper (3 adım) ve sabit alt çubuk (Geri / Devam).
  1. **Temel bilgiler:** **Kapak** (SHT-31), **Başlık** (80), **Açıklama** (1000, sayaçlı), **Tür** (Eğitim · Sosyal · Gezi · Yarışma · Konferans — tek seçimli çip).
  2. **Zaman, yer, katılım:** **Başlangıç** tarih (SHT-28) + saat (SHT-29), **Bitiş**, **Yer** (SHT-30), **Kontenjan** (− / + stepper; **Sınırsız** anahtarı), **Görünürlük** (segmented: Herkese açık · Sadece üyeler + açıklama), **Otomatik hatırlatma** anahtarı (1 gün + 1 saat önce). Aynı saatte başka etkinlik varsa `info` bandı ("Aynı saatte 1 etkinlik var").
  3. **Önizleme ve yayın:** EVT-02'nin üye gözüyle önizlemesi, özet listesi. **Taslak olarak kaydet** (outline) ve **Yayınla** (primary → DLG-22).
- **Düzenleme modu:** Değişen alanlar vurgulanır; yayındaki etkinlikte kontenjan, mevcut kayıt sayısından düşük girilemez (hata).
- **Doğrulama:** Başlangıç gelecekte, bitiş başlangıçtan sonra, başlık/yer zorunlu.
- **Aksiyonlar:** `MGT-05.close` → DLG-25 · `MGT-05.cover` · `MGT-05.type.<id>` · `MGT-05.startDate` / `startTime` / `endDate` / `endTime` · `MGT-05.place` → SHT-30 · `MGT-05.capacity.minus` / `plus` · `MGT-05.unlimited` · `MGT-05.visibility.<id>` · `MGT-05.autoReminder` · `MGT-05.next` / `back` · `MGT-05.saveDraft` → TST-13 · `MGT-05.publish` → DLG-22 → MGT-04 + TST-30. Yayınlanınca üyelere `event_new` bildirimi düşer.

#### MGT-06 — Katılımcılar ve Yoklama
- **Rota:** `/manage/:clubId/events/:id/attendance`.
- **Düzen:** Etkinlik başlığı + **Değiştir ▾** (etkinlik seçici). Özet çipleri (tıklanınca filtreler): **Kayıtlı · Katıldı · Gelmedi · Bekleme** + "Yoklama %62" çubuğu. Arama. **Liste:** avatar, ad, bölüm, durum rozeti, sağda **Katıldı** anahtarı (manuel işaretleme; anında, geri alınabilir toast). **Bekleme listesi** bölümü: sıra no + **Kayıtlıya al** (kontenjan varsa). Üst sağda **QR tara** (primary → MGT-07) ve **⋯**: **CSV dışa aktar**, **Tüm kayıtlıları katıldı yap** (DLG-17), **Kayıtları kapat/aç**.
- Etkinlik başlamadıysa üstte `info` bandı: "Etkinlik henüz başlamadı" (işlemler yine yapılabilir).
- **Aksiyonlar:** `MGT-06.back` · `MGT-06.switchEvent` · `MGT-06.summary.<id>` · `MGT-06.search` · `MGT-06.attended.<userId>` → TST-31 · `MGT-06.promote.<userId>` · `MGT-06.scan` → MGT-07 · `MGT-06.menu` · `MGT-06.export` · `MGT-06.markAll` · `MGT-06.toggleRegistration`.
- **Durumlar:** Skeleton, boş ("Henüz kayıt yok"), sonuçsuz arama.

#### MGT-07 — QR Tarayıcı
- **Rota:** `/manage/:clubId/events/:id/scan`. Tam ekran, koyu.
- **Düzen:** Kamera görünümü simülasyonu (koyu gradient, köşe çerçevesi, kayan tarama çizgisi). Üstte etkinlik adı + sayaç "Katıldı 18/48", **X**, **Fener** ve **Kamera çevir** anahtarları. Altta **Kod gir** (manuel) ve **Demo: bilet okut** (3 hazır sonuç: *Geçerli bilet* · *Zaten okutulmuş* · *Geçersiz bilet*).
- **Sonuç:** SHT-24 (başarıda 2 sn sonra otomatik kapanır ve taramaya devam eder).
- **İzin akışı:** İlk açılışta DLG-04. Reddedilirse tam ekran "Kamera izni gerekli" durumu: **Manuel kod gir** + **Ayarlara git** (TST-32).
- **Aksiyonlar:** `MGT-07.close` · `MGT-07.torch` · `MGT-07.flip` · `MGT-07.manualCode` → alan + **Doğrula** · `MGT-07.demoScan.valid` / `used` / `invalid` · `MGT-07.permission.retry`.

#### MGT-08 — İçerik Yönetimi
- **Rota:** `/manage/:clubId/content`.
- **Düzen:** Segmented **Gönderiler · Duyurular · Anketler**, arama. Satır: özet metin, tür, tarih, beğeni/yorum sayıları, sabit ikonu, **şikayet uyarısı** ("2 şikayet", `warning`). **⋯**: **Sabitle / Sabitlemeyi kaldır**, **Düzenle** (FED-03 düzenleme modu), **Sil** (DLG-10). Sağ altta **+** FAB.
- **Aksiyonlar:** `MGT-08.back` · `MGT-08.tab.<id>` · `MGT-08.search` · `MGT-08.row.<id>` → FED-02 · `MGT-08.pin.<id>` · `MGT-08.edit.<id>` · `MGT-08.delete.<id>` · `MGT-08.create` → FED-03.
- **Durumlar:** Boş, skeleton.

#### MGT-09 — Kulüp Ayarları
- **Rota:** `/manage/:clubId/settings`.
- **Düzen:** **Görünüm:** Logo (SHT-16), Kapak (SHT-31). **Bilgiler:** Ad (salt okunur; kilit ikonu + "Ad değişikliği için kampüs yönetimiyle iletişime geç"), Kategori (SHT-33), Kısa açıklama (160), Uzun açıklama (1000). **İletişim:** e-posta, Instagram, web (biçim doğrulama). **Katılım:** **Başvurular açık** · **Yönetim onayı gerekli** (kapalıyken uyarı bandı: "Herkes anında üye olur") · **Başvuruda not iste**. **Danışman** (salt okunur kart). Sticky **Kaydet**.
- **Aksiyonlar:** `MGT-09.back` → değişiklik varsa DLG-25 · `MGT-09.logo` / `cover` / `category` · `MGT-09.lockedName` → TST-20 · `MGT-09.toggle.<id>` (Başvurular açık/kapalı → TST-54) · `MGT-09.save` → yükleniyor → TST-21.
- **Danışman:** Tüm alanlar devre dışı.

#### MGT-10 — Faaliyet Geçmişi
- **Rota:** `/manage/:clubId/activity`.
- **Düzen:** Filtre çipleri **Tümü · Üyelik · Etkinlik · İçerik · Ayar**; tarih başlıklı kronolojik liste. Satır: aktör avatarı, "**Burak Şahin**, Cem Aydın'ın başvurusunu onayladı", zaman, tür ikonu. Satıra dokunmak ilgili ekrana gider (başvuru → MGT-02, etkinlik → EVT-02…).
- **Aksiyonlar:** `MGT-10.back` · `MGT-10.filter.<id>` · `MGT-10.row.<id>`.
- **Durumlar:** Boş, skeleton.

---

### 7.9 Süper Admin

> `superadmin` oturumunda alt çubukta **Admin** sekmesi görünür; sekme içinde üstte segmentli gezinme: **Genel · Kulüpler · Şikayetler · Kullanıcılar**.

#### ADM-01 — Genel Bakış
- **Rota:** `/admin`.
- **Düzen:** Tarih aralığı çipleri (**7 gün · 30 gün · Dönem**; seçilince tüm grafikler değişir). KPI: **Aktif kulüp · Toplam kullanıcı · Askıdaki kulüp · Açık şikayet**. **Haftalık aktif kullanıcı** çizgi grafiği. **En aktif 5 kulüp** yatay bar. **Etkinlik katılım oranı** halka. **Bekleyen işler** listesi (açık şikayetler → ADM-04, askıdaki kulüpler → ADM-02).
- **Aksiyonlar:** `ADM-01.range.<id>` · `ADM-01.kpi.<id>` · `ADM-01.chart.point.<i>` → tooltip · `ADM-01.topClub.<id>` → CLB-03 · `ADM-01.task.<id>`.

#### ADM-02 — Kulüpler
- **Rota:** `/admin/clubs`.
- **Düzen:** Segmented **Aktif · Askıda**, arama. Satır: amblem, ad, başkan, üye sayısı, durum, **⋯**: **Görüntüle** (CLB-03), **Düzenle** (ADM-03), **Başkanı değiştir** (SHT-25), **Askıya al / Etkinleştir** (DLG-28). Sağ altta **+ Kulüp oluştur** FAB.
- **Aksiyonlar:** `ADM-02.tab.<id>` · `ADM-02.search` · `ADM-02.row.<id>` · `ADM-02.menu.<id>` · `ADM-02.create` → ADM-03.

#### ADM-03 — Kulüp Oluştur / Düzenle
- **Rota:** `/admin/clubs/new` · `/admin/clubs/:id/edit`.
- **Düzen:** **Ad**, **Kategori** (SHT-33), kısa açıklama (160), uzun açıklama, logo (SHT-16), kapak (SHT-31). **Başkan ata** (SHT-25 → seçilen kullanıcı kartı + **Kaldır**), **Danışman** (ad + unvan alanları). **Katılım:** Başvurular açık · Onay gerekli. **Oluştur / Kaydet**.
- **Doğrulama:** Ad benzersiz (var olan adla hata), başkan zorunlu.
- **Sonuç:** ADM-02'ye döner, TST-33; atanan başkana `role_changed` bildirimi düşer.
- **Aksiyonlar:** `ADM-03.close` → DLG-25 · `ADM-03.category` · `ADM-03.logo` · `ADM-03.cover` · `ADM-03.assignPresident` → SHT-25 · `ADM-03.removePresident` · `ADM-03.toggle.<id>` · `ADM-03.save`.

#### ADM-04 — Şikayetler
- **Rota:** `/admin/reports`.
- **Düzen:** Sekmeler **Açık (n) · Çözüldü**; hedef türü çipleri (**Gönderi · Yorum · Kullanıcı · Kulüp**). Satır: hedef önizlemesi, neden rozeti, şikayet sayısı, zaman. Dokununca SHT-26.
- **Aksiyonlar:** `ADM-04.tab.<id>` · `ADM-04.filter.<id>` · `ADM-04.row.<id>` → SHT-26.
- **Durumlar:** Boş ("Açık şikayet yok"), skeleton.

#### ADM-05 — Kullanıcılar
- **Rota:** `/admin/users`.
- **Düzen:** Arama (ad/e-posta), çipler **Tümü · Askıda · Yöneticiler**. Satır: avatar, ad, bölüm, kulüp sayısı, durum rozeti, **⋯**: **Profili gör** (CLB-07), **Askıya al / Aç** (DLG-30), **Üyelik geçmişi** (satır içinde genişler).
- **Aksiyonlar:** `ADM-05.search` · `ADM-05.filter.<id>` · `ADM-05.row.<id>` · `ADM-05.menu.<id>` · `ADM-05.history.<id>`.

---

## 8. Bottom Sheet Kataloğu (34 adet)

**Ortak sheet kuralları:** Üstte sürükleme tutacağı (36 × 4 px), başlık + **X**. Üst köşe `r.xl` (28). En fazla ekran yüksekliğinin %90'ı; liste sheet'leri yarım yükseklikte açılır ve yukarı çekilince tam yüksekliğe geçer. Scrim'e dokunmak, aşağı sürüklemek, X ve Esc kapatır (formu olan sheet'te değişiklik varsa kapatmadan önce DLG-25). Klavye açılınca sheet yukarı kayar; alt aksiyon çubuğu yapışkandır. Odak tuzağı + kapanınca odak tetikleyiciye döner. Sheet içindeki her etkileşimli öğe `data-action="SHT-xx.<aksiyon>"` taşır.

**SHT-01 — Dil Menüsü**
- Tetik: AUT-01/02, ONB-01 (küçük açılır menü, sağ üstte) · SET-01 (alt sheet, radyo listesi).
- İçerik: **Türkçe — TR** ve **English — EN**, seçili olanda tik.
- Aksiyon: `SHT-01.select.tr|en` → dil anında değişir, `lang` güncellenir, menü kapanır.

**SHT-02 — Bölüm Seçici**
- Tetik: AUT-05, PRF-02. Tam yükseklik. Arama alanı + fakülteye göre gruplu 24 bölüm (Bölüm 11.4), tek seçimli radyo, seçili öğe üstte.
- Aksiyon: `SHT-02.search` · `SHT-02.select.<id>` → kapanır, alan güncellenir · sonuçsuzsa "Bölüm bulunamadı".

**SHT-03 — Sınıf Seçici**
- Seçenekler: Hazırlık · 1 · 2 · 3 · 4 · 5+ · Yüksek Lisans · Doktora. Tek seçim, anında kapanır. `SHT-03.select.<id>`.

**SHT-04 — Kulüp Filtre ve Sıralama**
- Tetik: CLB-01. İçerik: **Kategori** (çoklu çip), **Üyelik durumu** (Tümü · Üye olduklarım · Üye olmadıklarım segmenti), anahtarlar **Yalnızca başvurusu açık** ve **Anında katılım olanlar**, **Sırala** (Popüler · Yeni eklenen · A–Z radyo).
- Alt çubuk: **Temizle** + **Sonuçları göster (n)** (n canlı hesaplanır).
- Aksiyon: `SHT-04.category.<id>` · `SHT-04.membership.<id>` · `SHT-04.toggle.<id>` · `SHT-04.sort.<id>` · `SHT-04.clear` · `SHT-04.apply`.

**SHT-05 — Katılma Başvurusu**
- Tetik: CLB-01/03/06 "Katıl". Kulüp mini başlığı, **"Neden katılmak istiyorsun?"** çok satırlı alan (300 karakter, sayaçlı; kulüp "not iste" açıksa **zorunlu**, değilse opsiyonel). Bilgi satırı: "Adın, bölümün ve sınıfın kulüp yönetimiyle paylaşılır." (KVKK bağlantısı → AUT-06).
- **Başvuruyu gönder** (primary): yükleniyor, **çift tıklama engellenir**, çevrimdışıysa TST-24, başarıda sheet kapanır → **CLB-04**.
- `retryAfter` geçmediyse CTA devre dışı + geri sayım.
- Anında katılım kulüplerinde bu sheet **açılmaz**: katılım doğrudan gerçekleşir + TST-34.
- Aksiyon: `SHT-05.note` · `SHT-05.legal` · `SHT-05.submit` · `SHT-05.close`.

**SHT-06 — Kulüp Menüsü**
- Tetik: CLB-03 ⋯. Satırlar: **Bildirimleri yönet** (SHT-07, üye) · **Paylaş** (SHT-15) · **Üye listesi** (CLB-06, üye) · **Şikayet et** (SHT-10) · **Kulüp ayarları** (MGT-09, yönetici) · **Kulüpten ayrıl** (DLG-08, üye; kırmızı metin).

**SHT-07 — Kulüp Bildirim Ayarları**
- Anahtarlar: **Duyurular · Yeni etkinlikler · Yeni gönderiler · Tümünü sessize al** (ana anahtar diğerlerini kapatır). Anında kaydeder → TST-38.

**SHT-08 — Gönderi Menüsü**
- Satırlar: **Kaydet / Kaydı kaldır** (TST-11) · **Paylaş** (SHT-15) · **Bağlantıyı kopyala** (TST-35) · **Şikayet et** (SHT-10) · **Kullanıcıyı engelle** (DLG-13; başkasının gönderisinde). Yönetici ek: **Düzenle** (FED-03) · **Sabitle / Sabitlemeyi kaldır** (TST-53) · **Sil** (DLG-10). Kendi gönderisinde şikayet/engelle yoktur.

**SHT-09 — Yorumlar**
- Tetik: FED-01 yorum ikonu. Yarım yükseklik; FED-02'deki yorum bileşeni + giriş alanı. **Tümünü gör** → FED-02.

**SHT-10 — Şikayet Nedeni**
- Radyo: **Spam · Taciz veya zorbalık · Uygunsuz içerik · Yanlış bilgi · Kulübe uygun değil · Diğer**. "Diğer" seçilince açıklama alanı (200) **zorunlu** olur.
- **Şikayet et** → yükleniyor → kapanır → **DLG-12**. Hedef `reports`a eklenir; süper adminlere `new_report` bildirimi düşer.

**SHT-11 — Etkinlik Filtresi**
- **Tarih** (Bugün · Bu hafta · Bu ay · Özel aralık → iki kez SHT-28) · **Kulüp** (çoklu, üye olduklarım üstte) · **Tür** (5 çip) · **Görünürlük** (Hepsi · Herkese açık · Sadece üyeler) · **Yalnızca boş kontenjan** anahtarı · **Sırala** (Tarihe göre · Popüler). Alt çubuk: **Temizle** + **Uygula (n)**.

**SHT-12 — Katılım Onayı**
- Etkinlik özeti (başlık, tarih, yer), **Hatırlatıcı** çipleri (Yok · 1 saat önce · 1 gün önce · İkisi). Aynı saatte başka kayıtlı etkinlik varsa `warning` satırı. **Katılımı onayla** → yükleniyor → kapanır → **TST-41** (Bileti göster).

**SHT-13 — Hatırlatıcı**
- Radyo: **Hatırlatma yok · 15 dk önce · 1 saat önce · 1 gün önce**. Seçim anında kaydedilir → TST-37.

**SHT-14 — Takvime Ekle**
- Satırlar: **Cihaz takvimi** (gerçek `.ics` dosyası indirir → TST-36) · **Google Takvim** (DLG-32) · **Bağlantıyı kopyala** (TST-35).

**SHT-15 — Paylaş**
- Önizleme kartı (başlık + kısa bağlantı) ve satırlar: **Bağlantıyı kopyala** (TST-35) · **WhatsApp** (DLG-32) · **E-posta** (DLG-32) · **Diğer…** (TST-58 "Demo: sistem paylaşım menüsü açılıyor").

**SHT-16 — Fotoğraf Kaynağı / Görsel Seçici**
- Varyant A (tek görsel): **Kamera** (DLG-04 → demo görsel) · **Galeri** (DLG-05 → demo görsel ızgarası) · **Fotoğrafı kaldır** (varsa; kırmızı metin).
- Varyant B (FED-03/SET-05, çoklu): 8 demo görselin ızgarası, çoklu seçim (en çok 4), **Ekle (n)**.
- Seçim sonrası kapanır, TST-57.

**SHT-17 — Tema Seçici**
- Üç kart (minyatür önizlemeli): **Sistem · Açık · Koyu**. Anında uygulanır.

**SHT-18 — Yönetilen Kulüp Seçici**
- Liste: amblem, kulüp adı, rol rozeti (danışman: "Salt okunur"). Seçim → MGT-01 o kulüp bağlamında açılır.

**SHT-19 — Başvuru Detayı**
- Avatar, ad, bölüm · sınıf, başvuru tarihi, **notun tamamı**, ortak kulüpler, "Daha önce bu kulübe başvurdu: Evet/Hayır" satırı, **Profili gör** (CLB-07). Butonlar: **Onayla** (primary) · **Reddet** (outline → SHT-20). Sonuçlanmış başvuruda sonuç bilgisi + **Geri al** (24 saat içinde).
- Çakışma demo'su: `stale` başvuruda onay → DLG-18.

**SHT-20 — Red Nedeni**
- Hızlı çipler: **Kontenjan dolu · Koşulları karşılamıyor · Eksik bilgi · Diğer** + opsiyonel serbest alan (200). "Neden başvurana gösterilir" bilgisi. **Reddet** (dolu `danger`) → TST-28.

**SHT-21 — Üye İşlemleri**
- Satırlar: **Profili gör** (CLB-07) · **Rolü değiştir** (SHT-22; yalnızca başkan) · **Üyelikten çıkar** (DLG-19; kırmızı metin).
- Hiyerarşi: Yönetim Kurulu yalnızca `member` rolündekileri çıkarabilir; başkana ve diğer yönetim kurulu üyelerine işlem yapılamaz (satırlar devre dışı + açıklama).

**SHT-22 — Rol Seçici**
- Radyo kartları: **Üye** ve **Yönetim Kurulu**, her birinin altında yetki özeti. (Başkanlık devri ayrı akıştır: MGT-03.) **Kaydet** → DLG-20.

**SHT-23 — Etkinlik Menüsü (Yönetim)**
- Satırlar: **Düzenle** (MGT-05) · **Çoğalt** (taslak olarak kopya, TST-13) · **Katılımcılar** (MGT-06) · **Yoklama başlat** (MGT-07) · **Paylaş** (SHT-15) · **Yayından kaldır / taslağa al** · **İptal et** (DLG-23) · **Sil** (yalnızca taslak; DLG-31).

**SHT-24 — QR Tarama Sonucu**
- Üç varyant: **Geçerli** (yeşil; avatar, ad, "Katıldı olarak işaretlendi", sayaç +1, **Geri al**) · **Zaten okutulmuş** (sarı; okutulma saati) · **Geçersiz** (kırmızı; "Bu bilet bu etkinliğe ait değil" ya da "Okunamadı"). Buton: **Sonraki bilet**. Geçerli sonuç 2 sn sonra otomatik kapanır.

**SHT-25 — Kullanıcı Arayıcı**
- Arama alanı + sonuç listesi (avatar, ad, bölüm). Tek seçim. Başlık bağlama göre: **"Başkan ata"** (ADM-03/ADM-02: tüm kullanıcılar) veya **"Başkanlığı devret"** (MGT-03: yalnızca o kulübün üyeleri). Seçince geri döner (ADM-03'te kart olarak görünür; MGT-03'te DLG-21 açılır).

**SHT-26 — Şikayet Detayı (Süper Admin)**
- Hedef içerik tam önizleme (gönderi/yorum/kullanıcı/kulüp kartı), şikayet listesi (kim, neden, not, zaman). Aksiyonlar: **İçeriği kaldır** (DLG-29) · **Kullanıcıyı askıya al** (DLG-30) · **Şikayeti kapat** (yükleniyor → çözüldü → TST-56). Çözülmüş şikayette yalnızca sonuç özeti.

**SHT-27 — Kullanıcı Menüsü**
- Satırlar: **Profili gör** (CLB-07) · **Engelle** (DLG-13) · **Şikayet et** (SHT-10). Yorum bağlamında yetkiliye ek: **Yorumu sil** (DLG-11).

**SHT-28 — Tarih Seçici**
- Özel aylık takvim (min/max destekli), ay okları, **Bugün**, **Tamam / İptal**. Geçmiş günler devre dışı olabilir (bağlama göre).

**SHT-29 — Saat Seçici**
- İki tekerlek (saat 00–23, dakika 5'er), **Tamam / İptal**.

**SHT-30 — Mekân Seçici**
- Arama + 10 kampüs mekânı listesi (Bölüm 11.9) + **"Başka bir yer yaz"** (serbest metin alanı açar). Seçince kapanır.

**SHT-31 — Kapak Seçici**
- 12 hazır CoverArt şablonu (3 palet × 4 desen) ızgarası, canlı önizleme; **Galeriden seç** (SHT-16 A varyantı akışı). **Kullan**.

**SHT-32 — Şifre Değiştir**
- **Mevcut şifre**, **Yeni şifre** (güç göstergesi), **Yeni şifre tekrar**. **Kaydet** → yükleniyor → TST-44. Hata: mevcut şifre yanlış, şifreler uyuşmuyor, kural ihlali.

**SHT-33 — Kategori Seçici**
- 8 kategori satırı (ikon + ad), tek seçim, anında kapanır.

**SHT-34 — Görsel Görüntüleyici (tam ekran)**
- Siyah zemin, sayaç "1/3", yatay kaydırma, çift dokunuşla yakınlaştırma, **X**, **Paylaş** (SHT-15). Aşağı sürükleyerek kapanır.

---

## 9. Dialog Kataloğu (32 adet)

**Ortak dialog kuralları:** Ortalı kart, `r.lg`, en fazla 320 px genişlik, `role="dialog"`, odak tuzağı, Esc/scrim kapatır (**DLG-26 hariç**). Birincil buton sağda/üstte; yıkıcı eylemde `danger` dolu buton ve **sol/alt'ta güvenli seçenek**. Her butonun `data-action="DLG-xx.<aksiyon>"`.

| ID | Başlık | Gövde (TR) | Butonlar → sonuç |
|---|---|---|---|
| DLG-01 | Hesabın askıya alındı | "Topluluk kurallarını ihlal ettiği için hesabına erişimin geçici olarak kapatıldı. İtiraz için destek ekibine yazabilirsin." | **Destekle iletişime geç** → DLG-32 (mailto) · **Tamam** |
| DLG-02 | Çok fazla deneme | "Güvenliğin için girişi {sn} saniye kilitledik." (canlı geri sayım) | **Tamam** · **Şifremi unuttum** → AUT-04 |
| DLG-03 | Bildirimleri açalım mı? | "Başvuru sonuçlarından ve etkinlik hatırlatmalarından haberdar olmak için bildirim izni ver." | **İzin ver** → sistem izni simülasyonu (İzin Ver / İzin Verme) → verilirse TST-19, verilmezse NTF-01'de banner · **Şimdi değil** (3 gün tekrar sormaz) |
| DLG-04 | Kamera erişimi | "QR kodları taramak için kameraya erişmemiz gerekiyor." | **İzin ver** → sistem simülasyonu → reddedilirse TST-32 · **Şimdi değil** |
| DLG-05 | Fotoğraflarına erişim | "Fotoğraf seçebilmek için galerine erişim izni ver." | **İzin ver** · **Şimdi değil** |
| DLG-06 | Çıkış yapılsın mı? | "Hesabından çıkış yapacaksın. İstediğin zaman tekrar giriş yapabilirsin." | **Çıkış yap** → AUT-01 · **Vazgeç** |
| DLG-07 | İsteği iptal et? | "{kulüp} kulübüne gönderdiğin istek geri çekilecek. İstediğin zaman yeniden başvurabilirsin." | **İsteği iptal et** (danger) → durum `none`, TST-40 · **Vazgeç** |
| DLG-08 | Kulüpten ayrıl? | "{kulüp} üyeliğin sona erecek ve gönderileri göremeyeceksin. Tekrar katılmak için yeniden başvurman gerekebilir." | **Ayrıl** (danger) → TST-39 · **Vazgeç** |
| DLG-09 | Ayrılamazsın | "Bu kulübün tek başkanısın. Ayrılmadan önce başkanlığı başka bir üyeye devretmelisin." | **Başkanlığı devret** → SHT-25 → DLG-21 · **Tamam** |
| DLG-10 | Gönderi silinsin mi? | "Bu gönderi ve yorumları silinecek." | **Sil** (danger) → TST-45 (6 sn içinde **Geri al**) · **Vazgeç** |
| DLG-11 | Yorum silinsin mi? | "Bu yorum silinecek." | **Sil** (danger) → TST-45 · **Vazgeç** |
| DLG-12 | Şikayetin alındı | "Teşekkürler. Kampüs yönetimi içeriği inceleyecek; sonucu bildirimle haber vereceğiz." | **Tamam** · **{ad} kullanıcısını da engelle** (yalnızca kullanıcı içeriğinde) → DLG-13 |
| DLG-13 | {ad} engellensin mi? | "Bu kullanıcının gönderilerini ve yorumlarını görmeyeceksin. Engeli Ayarlar'dan kaldırabilirsin." | **Engelle** (danger) → TST-09 · **Vazgeç** |
| DLG-14 | Katılımdan vazgeç? | "Biletin iptal edilecek ve yerin bekleyenlere açılacak." (bekleme varyantı: "Bekleme listesinden çıkarılacaksın.") | **Vazgeç** (danger) → TST-42 · **Kalmaya devam et** |
| DLG-15 | Kontenjan doldu | "Bu etkinlikte yer kalmadı. Bekleme listesine katılırsan boşalan yer olursa sana bildirim göndeririz. Şu an {n} kişi bekliyor." | **Bekleme listesine katıl** → TST-43 · **Vazgeç** |
| DLG-16 | Etkinlik iptal edildi | "{etkinlik}, {neden} nedeniyle iptal edildi. Biletin geçersiz." | **Tamam** · **Benzer etkinlikleri gör** → EVT-01 |
| DLG-17 | Toplu işlem onayı | "{n} başvuru onaylansın mı?" / "{n} başvuru reddedilsin mi?" / "Tüm kayıtlılar katıldı olarak işaretlensin mi?" (başvuranlara bildirim gider) | **Onayla / Reddet** → TST-27/28/31 · **Vazgeç** |
| DLG-18 | Başvuru zaten sonuçlandırıldı | "Bu başvuru başka bir yönetici tarafından {sonuç}. Liste yenilendi." | **Tamam** → liste yenilenir |
| DLG-19 | {ad} çıkarılsın mı? | "Üyelikten çıkarılacak ve bilgilendirilecek. 7 gün boyunca yeniden başvuramaz." + opsiyonel neden alanı | **Üyeyi çıkar** (danger) → TST-47 · **Vazgeç** |
| DLG-20 | Rol değişsin mi? | "{ad}, {eskiRol} rolünden {yeniRol} rolüne geçecek. Yetkileri hemen değişir." | **Onayla** → TST-46 · **Vazgeç** |
| DLG-21 | Başkanlığı devret? | **2 adım.** 1) "Başkanlığı {ad} kullanıcısına devretmek üzeresin. Sen Yönetim Kurulu üyesi olacaksın. Bu işlem geri alınamaz." 2) "Onaylamak için **DEVRET** yaz." | **Devret** (danger; yazılana kadar devre dışı) → TST-49 · **Vazgeç** |
| DLG-22 | Etkinlik yayınlansın mı? | "Etkinlik herkesin görebileceği şekilde yayınlanacak." + **"{n} üyeye bildirim gönder"** onay kutusu (açık) | **Yayınla** → TST-30 · **Düzenlemeye dön** |
| DLG-23 | Etkinlik iptal edilsin mi? | "{n} kayıtlı katılımcıya iptal bildirimi gidecek. Bu işlem geri alınamaz." + **zorunlu neden** radyosu (Hava koşulları · Konuşmacı gelemiyor · Mekân sorunu · Diğer) | **Etkinliği iptal et** (danger) → TST-48 · **Vazgeç** |
| DLG-24 | Bugünkü duyuru hakkın doldu | "Bir kulüp günde en fazla 2 duyuru bildirimi gönderebilir. Duyuruyu bildirimsiz yayınlayabilirsin. Yeni hakkın yarın 00:00'da yenilenir." | **Bildirimsiz yayınla** · **Vazgeç** |
| DLG-25 | Değişiklikler kaydedilmedi | "Çıkarsan yaptığın değişiklikler kaybolacak." | **Kaydet** (taslak/ayar bağlamında) · **Kaydetmeden çık** (danger metin) · **Düzenlemeye devam et** |
| DLG-26 | Güncelleme gerekli | "Uygulamayı kullanmaya devam etmek için yeni sürüme güncellemelisin." (**kapatılamaz**) | **Güncelle** → TST-58 "Demo: mağaza açılıyor" → dialog kapanır |
| DLG-27 | Oturumun sona erdi | "Güvenliğin için yeniden giriş yapman gerekiyor." | **Giriş yap** → AUT-01 |
| DLG-28 | {kulüp} askıya alınsın mı? | "Kulüp listede görünmez, üyeler gönderilere ve etkinliklere erişemez. İstediğin zaman yeniden etkinleştirebilirsin." + **zorunlu neden** alanı (etkinleştirmede onay metni) | **Askıya al / Etkinleştir** → TST-50 · **Vazgeç** |
| DLG-29 | İçerik kaldırılsın mı? | "İçerik herkesten gizlenir ve yazarı bilgilendirilir. Şikayet çözüldü olarak işaretlenir." | **Kaldır** (danger) → TST-51; şikayet edene `report_resolved` bildirimi · **Vazgeç** |
| DLG-30 | {ad} askıya alınsın mı? | "Kullanıcı giriş yapamaz ve içerikleri gizlenir." + **zorunlu neden** alanı (açmada onay metni) | **Askıya al / Askıyı kaldır** → TST-52 · **Vazgeç** |
| DLG-31 | Taslak silinsin mi? | "Bu taslak kalıcı olarak silinecek." | **Sil** (danger) → TST-45 · **Vazgeç** |
| DLG-32 | Uygulamadan ayrılıyorsun | "Şu adrese gidilecek: **{url}** Bu adrese güveniyor musun?" | **Aç** → TST-58 "Demo: bağlantı açılıyor" (gerçek yönlendirme yok) · **Vazgeç** |

---

## 10. Toast / Snackbar Kataloğu (58 adet)

**Kurallar:** Alttan yükselir, alt çubuğun üstünde durur, aynı anda en çok **1 toast** (yenisi eskisini değiştirir). Süre 4 sn; **Geri al** içerenler 6 sn. Renkli sol çizgi + ikon + metin (renk tek başına anlam taşımaz). `aria-live="polite"`; hata toast'ları `role="alert"`. **Geri al** eylemi store'u önceki duruma döndürür (gerçek geri alma).

| ID | Tür | Mesaj (TR) | Aksiyon |
|---|---|---|---|
| TST-01 | error | E-posta veya şifre hatalı. | — |
| TST-02 | info | E-postan henüz doğrulanmamış. Bağlantıya tıkladıktan sonra tekrar dene. | — |
| TST-03 | success | Bağlantı gönderildi. Gelen kutunu kontrol et. | — |
| TST-04 | info | En fazla 5 ilgi alanı seçebilirsin. | — |
| TST-05 | success | Hoş geldin, {ad}! | — |
| TST-06 | info | Son aramalar temizlendi. | Geri al |
| TST-07 | success | Notun kaydedildi. | — |
| TST-08 | success | E-posta adresi kopyalandı. | — |
| TST-09 | info | {ad} engellendi. / {ad} için engel kaldırıldı. | Geri al |
| TST-10 | info | Oyun kaydedildi. Anketlerde oy değiştirilemez. | — |
| TST-11 | success | Kaydedilenlere eklendi. / Kaydedilenlerden kaldırıldı. | Geri al |
| TST-12 | success | Yorumun gönderildi. | — |
| TST-13 | success | Taslak kaydedildi. | — |
| TST-14 | success | Yayınlandı. | Görüntüle |
| TST-15 | success | Biletin okutuldu. İyi eğlenceler! | — |
| TST-16 | info | Bildirim silindi. | Geri al |
| TST-17 | success | Şikayetin incelendi ve gereken işlem yapıldı. Teşekkürler. | — |
| TST-18 | success | Tüm bildirimler okundu olarak işaretlendi. | — |
| TST-19 | success | Tercihin kaydedildi. | — |
| TST-20 | info | Bu alan değiştirilemez. | — |
| TST-21 | success | Değişiklikler kaydedildi. | — |
| TST-22 | success | Hesabın silindi. Seni özleyeceğiz. | — |
| TST-23 | success | Mesajın alındı. Talep no: #GU-4821 | — |
| TST-24 | error | Çevrimdışısın. Bu işlem için internet bağlantısı gerekli. | — |
| TST-25 | success | Tekrar çevrimiçisin. | — |
| TST-26 | info | Danışman yetkisi salt okunurdur. | — |
| TST-27 | success | {ad} onaylandı. | Geri al |
| TST-28 | info | {ad} reddedildi. | Geri al |
| TST-29 | success | Dışa aktarma hazır. Dosya indirildi. | — |
| TST-30 | success | Etkinlik yayınlandı. | Görüntüle |
| TST-31 | success | {ad} katıldı olarak işaretlendi. | Geri al |
| TST-32 | error | Kamera izni gerekli. | Ayarlara git (→ TST-58) |
| TST-33 | success | Kulüp oluşturuldu. | — |
| TST-34 | success | Kulübe katıldın! | Kulübe git |
| TST-35 | success | Bağlantı kopyalandı. | — |
| TST-36 | success | Takvime eklendi. | — |
| TST-37 | success | Hatırlatıcı ayarlandı. / Hatırlatıcı kapatıldı. | — |
| TST-38 | success | Kulüp bildirim ayarların güncellendi. | — |
| TST-39 | info | Kulüpten ayrıldın. | — |
| TST-40 | info | İsteğin iptal edildi. | — |
| TST-41 | success | Kaydın alındı. Biletin hazır. | Bileti göster |
| TST-42 | info | Katılımdan vazgeçtin. | — |
| TST-43 | success | Bekleme listesine eklendin ({n}. sıra). | — |
| TST-44 | success | Şifren değiştirildi. | — |
| TST-45 | info | {nesne} silindi. | Geri al |
| TST-46 | success | {ad} artık {rol}. | — |
| TST-47 | info | {ad} kulüpten çıkarıldı. | Geri al |
| TST-48 | info | Etkinlik iptal edildi. Katılımcılara haber verildi. | — |
| TST-49 | success | Başkanlık {ad} kullanıcısına devredildi. | — |
| TST-50 | info | Kulüp askıya alındı. / Kulüp yeniden etkinleştirildi. | — |
| TST-51 | success | İçerik kaldırıldı. | — |
| TST-52 | info | Kullanıcı askıya alındı. / Kullanıcının askısı kaldırıldı. | — |
| TST-53 | success | Gönderi sabitlendi. / Sabitleme kaldırıldı. | — |
| TST-54 | info | Başvurular açıldı. / Başvurular kapatıldı. | — |
| TST-55 | info | Yeni bildirim: {başlık} | Görüntüle |
| TST-56 | info | Şikayet kapatıldı. | — |
| TST-57 | success | Fotoğraf güncellendi. | — |
| TST-58 | info | Demo: {eylem} açılıyor. | — |

---

## 11. Demo Veri Spesifikasyonu

### 11.1 Genel kurallar

- Her şey **kurgusaldır**; gerçek kişi, gerçek kulüp, gerçek telefon/e-posta yok. E-postalar `ad.soyad@ogr.gumushane.edu.tr` biçimindedir ve yalnızca prototipte anlam taşır.
- Tüm tarihler **bugüne göre göreli** üretilir (`today + n gün`). Saatler 24 saatlik, yerel saat (Europe/Istanbul).
- Sayılar tutarlı olmalıdır: bir kulübün `memberCount` değeri, `memberships` içindeki `active` kayıtların sayısına **eşit veya ondan büyük** olabilir (geri kalanı "özet" sayı); ama etkinlik `registered` değeri `rsvps` ile **birebir** eşleşir.
- Türkçe içerik doğal, dil bilgisi hatasız ve gündelik olmalıdır. Her listede en az bir **uzun** ve bir **çok kısa** içerik bulunur (taşma testi). En az bir kayıtta çok uzun ad ("Muhammed Burak Yıldırım Arslanoğlu").
- Seed deterministiktir; "Demo verisini sıfırla" her zaman aynı veriyi üretir.

### 11.2 Demo hesaplar

`ALLOWED_EMAIL_DOMAINS = ['ogr.gumushane.edu.tr', 'gumushane.edu.tr']` (tek sabit; gerçek alan adı kesinleşince burada değişir). **Tüm demo hesapların şifresi:** `Demo1234!`

| Hesap | E-posta | Rol bağlamı | Başlangıç durumu / test amacı |
|---|---|---|---|
| **Ayşe Demir** | `ayse.demir@ogr.gumushane.edu.tr` | `student` | 1. sınıf, Bilgisayar Müh.; **hiçbir kulübe üye değil**. Başvuru ve etkinlik akışları. 3 bildirim. |
| **Mehmet Kaya** | `mehmet.kaya@ogr.gumushane.edu.tr` | `member` | Yazılım ve Yapay Zekâ (**aktif**), Fotoğraf ve Sinema (**aktif**), Satranç (**beklemede**), Tiyatro (**reddedildi**, 3 gün sonra tekrar başvurabilir). 9 bildirim. Geçmiş etkinlik kayıtları. |
| **Elif Yıldız** | `elif.yildiz@ogr.gumushane.edu.tr` | `board` (Yazılım) + `member` (Girişimcilik) | 6 bekleyen başvuru. Çoklu kulüp senaryosu. |
| **Burak Şahin** | `burak.sahin@ogr.gumushane.edu.tr` | `president` (Doğa Sporları) + `member` (Yazılım) | 9 bekleyen başvuru (biri `stale`), taslak etkinlik, dolu etkinlik. Başkanlık devri ve hesap silme engeli. |
| **Dr. Öğr. Üyesi Zeynep Arslan** | `zeynep.arslan@gumushane.edu.tr` | `advisor` (Yazılım, Girişimcilik) | Panel salt okunur. |
| **Kampüs Yönetimi** | `admin@gumushane.edu.tr` | `superadmin` | 5 açık şikayet, 1 askıdaki kulüp. |

Özel girişler: `unverified@ogr.gumushane.edu.tr` → AUT-03 · `suspended@ogr.gumushane.edu.tr` → DLG-01. Giriş ekranında "Demo hesaplarla giriş" bölümü bu 6 hesabı çip olarak listeler.

### 11.3 Kategoriler (8) ve kulüpler (14)

Kategoriler: **Teknoloji · Bilim ve Mühendislik · Spor ve Doğa · Sanat ve Kültür · Sosyal Sorumluluk · Kariyer ve Girişimcilik · Oyun ve Zekâ · Medya ve İletişim**.

| ID | Kulüp (kurgusal) | Kategori | İkon | Palet | Üye | Onay | Başvuru | Başkan | Danışman |
|---|---|---|---|---|---|---|---|---|---|
| c01 | Yazılım ve Yapay Zekâ Topluluğu | Teknoloji | `code-xml` | Kırmızı–Krem | 186 | ✓ | Açık | Baran Çelik | Zeynep Arslan |
| c02 | Girişimcilik ve İnovasyon Kulübü | Kariyer ve Girişimcilik | `lightbulb` | Slate–Lacivert | 142 | ✓ | Açık | Selin Aksoy | Zeynep Arslan |
| c03 | Doğa Sporları ve Dağcılık Kulübü | Spor ve Doğa | `mountain` | Bordo–Kum | 231 | ✓ | Açık | Burak Şahin | Doç. Dr. Hakan Yalçın |
| c04 | Maden ve Yer Bilimleri Topluluğu | Bilim ve Mühendislik | `pickaxe` | Slate–Lacivert | 98 | ✓ | Açık | Emre Doğan | Prof. Dr. Nurten Kılıç |
| c05 | Tiyatro Kulübü | Sanat ve Kültür | `drama` | Kırmızı–Krem | 74 | ✓ | **Kapalı** | Ceren Uslu | Dr. Öğr. Üyesi Gül Erten |
| c06 | Müzik ve Sahne Sanatları Kulübü | Sanat ve Kültür | `music` | Bordo–Kum | 120 | ✓ | Açık | Kaan Erdem | Öğr. Gör. Sinan Bulut |
| c07 | Fotoğraf ve Sinema Kulübü | Medya ve İletişim | `camera` | Slate–Lacivert | 88 | ✗ (anında) | Açık | Yağmur Tan | Dr. Öğr. Üyesi Pınar Aydemir |
| c08 | Havacılık ve Uzay Teknolojileri Kulübü | Teknoloji | `rocket` | Kırmızı–Krem | 112 | ✓ | Açık | Oğuz Karaca | Doç. Dr. Ali Rıza Tuna |
| c09 | Satranç ve Zekâ Oyunları Kulübü | Oyun ve Zekâ | `puzzle` | Bordo–Kum | 65 | ✗ (anında) | Açık | Mina Özer | Öğr. Gör. Cem Başaran |
| c10 | E-Spor Kulübü | Oyun ve Zekâ | `gamepad-2` | Slate–Lacivert | 204 | ✓ | Açık | Arda Polat | Dr. Öğr. Üyesi Tuba Yaman |
| c11 | Gönüllülük ve Sosyal Sorumluluk Kulübü | Sosyal Sorumluluk | `heart-handshake` | Kırmızı–Krem | 157 | ✓ | Açık | Nehir Koç | Doç. Dr. Elvan Sönmez |
| c12 | Kitap ve Edebiyat Kulübü | Sanat ve Kültür | `book-open` | Bordo–Kum | 59 | ✗ (anında) | Açık | Ece Sezer | Prof. Dr. Mehmet Ali Özkan |
| c13 | Yerel Kültür ve Halk Oyunları Kulübü | Sanat ve Kültür | `users-round` | Slate–Lacivert | 133 | ✓ | Açık | Tolga Gündüz | Öğr. Gör. Fatma Çiçek |
| c14 | Kariyer ve Mezunlar Kulübü | Kariyer ve Girişimcilik | `briefcase` | Kırmızı–Krem | 91 | ✓ | — | Hande Tekin | Dr. Öğr. Üyesi Okan Yurt — **ASKIDA** |

Askıdaki kulüp (c14) CLB-01'de listelenmez ("13 kulüp"); yalnızca üyelerinin "Kulüplerim" şeridinde "Askıda" etiketiyle görünür ve CLB-03'te `warning` bantlı açılır. Süper adminin ADM-02 "Askıda" sekmesinde bulunur.

Her kulüp için: 2–3 cümlelik `about`, kısa 1 cümlelik özet, kuruluş yılı (2008–2025), 3–4 maddelik katılım koşulları, iletişim e-postası ve Instagram kullanıcı adı (kurgusal, `@guk_yazilim` gibi), yönetim kurulu (4–6 kişi, hepsi seed kullanıcıdır).

### 11.4 Kullanıcılar, bölümler, ilgi alanları

- **Kullanıcılar:** Yukarıdaki 6 hesap + ~64 üretilmiş kullanıcı (toplam ~70). Ad ve soyad havuzu en az 30'ar Türkçe isim içermeli (Ahmet, Zeynep, Mustafa, Elif, Yusuf, Defne, Emirhan, İrem, Kerem, Ayça, Berk, Özge…). Ortak soyadlar tekrar edebilir; en az bir **çok uzun isim** ve bir **tek harfli baş harf avatarı** bulunmalı.
- **Bölümler (24, fakülteye göre gruplu, örnek liste):** *Mühendislik:* Bilgisayar, Elektrik-Elektronik, İnşaat, Maden, Jeoloji, Harita, Gıda · *Mimarlık:* Mimarlık, Peyzaj Mimarlığı · *Fen-Edebiyat:* Matematik, Fizik, Kimya, Türk Dili ve Edebiyatı, Tarih, Psikoloji · *İktisadi ve İdari:* İşletme, İktisat, Uluslararası İlişkiler · *Sağlık/Spor:* Hemşirelik, Beden Eğitimi ve Spor · *Turizm/Sanat:* Gastronomi ve Mutfak Sanatları, Turizm İşletmeciliği, Radyo-TV ve Sinema, Grafik Tasarımı. *(Örnek listedir; gerçek liste sonra değişir.)*
- **İlgi alanları (16):** Yazılım · Yapay zekâ · Girişimcilik · Doğa yürüyüşü · Dağcılık · Fotoğraf · Sinema · Müzik · Tiyatro · Edebiyat · Satranç · E-spor · Gönüllülük · Halk oyunları · Havacılık · Kariyer.

### 11.5 Etkinlikler (22)

`+n` = bugünden itibaren gün. Saatler yerel. Kontenjan = `kapasite`, `kayıtlı` = rsvps sayısı.

| ID | Etkinlik | Kulüp | Zaman | Mekân | Kont./Kayıtlı | Görünürlük | Durum / not |
|---|---|---|---|---|---|---|---|
| e01 | Yapay Zekâya Giriş Atölyesi | c01 | +1, 18:00–20:00 | Bilgisayar Lab-2 | 40 / 36 | Herkese açık | **Az yer kaldı** |
| e02 | Hackathon Hazırlık Buluşması | c01 | +3, 19:00 | Kulüpler Binası Toplantı Salonu | 60 / 22 | Sadece üyeler | — |
| e03 | Zigana Yolu Doğa Yürüyüşü | c03 | +5, 08:00 (8 sa) | Kampüs Ana Giriş | 30 / 30 | Herkese açık | **DOLU**, bekleme listesi 4 kişi |
| e04 | Girişimci Sohbetleri: İlk Müşteri | c02 | +2, 17:30 | Kongre Merkezi Salon B | 120 / 74 | Herkese açık | — |
| e05 | Maden Müzesi Teknik Gezisi | c04 | +9, 09:00 | Kampüs Ana Giriş | 45 / 40 | Sadece üyeler | — |
| e06 | Açık Mikrofon Gecesi | c06 | +4, 20:00 | Açık Hava Sahnesi | 150 / 61 | Herkese açık | — |
| e07 | Karadeniz Fotoğraf Yürüyüşü | c07 | +6, 10:00 | Meydan | 25 / 14 | Herkese açık | — |
| e08 | Satranç Turnuvası: Güz Kupası | c09 | +7, 13:00 | Kütüphane Çalışma Salonu | 32 / 28 | Herkese açık | — |
| e09 | E-Spor Kampüs Ligi — Eleme | c10 | +8, 18:00 | Bilgisayar Lab-2 | 64 / 64 | Herkese açık | **DOLU**, bekleme 0 |
| e10 | Gönüllülük Günü: Barınak Ziyareti | c11 | +10, 11:00 | Kampüs Ana Giriş | 35 / 20 | Herkese açık | — |
| e11 | Edebiyat Kafe: Hikâye Atölyesi | c12 | +11, 16:00 | Kulüpler Binası | 20 / 9 | Sadece üyeler | — |
| e12 | Horon Çalıştayı | c13 | +12, 17:00 | Spor Salonu | 80 / 52 | Herkese açık | — |
| e13 | Model Roket Fırlatma Günü | c08 | +14, 14:00 | Açık Hava Sahnesi | 50 / 31 | Herkese açık | — |
| e14 | Tiyatro Oyunu: Kapalı Gişe | c05 | +16, 20:00 | Kongre Merkezi Salon A | 200 / 188 | Herkese açık | Başvurular kapalı kulüp, etkinlik açık |
| e15 | Kariyer Günleri Söyleşisi | c02 | +18, 10:00 | Kongre Merkezi Salon A | 100 / 40 | Herkese açık | — |
| e16 | Dağcılık Temel Eğitimi | c03 | +20, 09:00 | Spor Salonu | 25 / 11 | Sadece üyeler | — |
| e17 | Veri Bilimi Söyleşisi | c01 | **bugün**, 19:30 | Amfi-1 | 80 / 52 | Herkese açık | **Bugün** |
| e18 | Açılış Tanışma Toplantısı | c01 | −6, 18:00 | Amfi-1 | 70 / 64 | Sadece üyeler | **Geçmiş** (Mehmet: katıldı) |
| e19 | Sonbahar Kampı | c03 | −12, 09:00 | Kampüs Ana Giriş | 40 / 38 | Herkese açık | **Geçmiş** |
| e20 | Portre Fotoğrafçılığı Atölyesi | c07 | −4, 15:00 | Kulüpler Binası | 20 / 18 | Herkese açık | **Geçmiş** (Mehmet: gelmedi) |
| e21 | Açık Hava Sinema Gecesi | c07 | +5, 21:00 | Meydan | 100 / 47 | Herkese açık | **İPTAL** (hava koşulları) |
| e22 | Kış Kampı Planlama | c03 | +25, 10:00 | — | — | — | **Taslak** (yalnız Burak görür) |

RSVP seed: Mehmet → e01 (katılıyor), e08 (bekleme listesi), e18 (katıldı), e20 (gelmedi). Elif → e17 ve e02. Ayşe → hiçbir etkinliğe kayıtlı değil. e17'de en az 5 kişi `attended` durumundadır (yoklama demo'su).

### 11.6 Gönderiler (36)

Dağılım: c01: 7 · c03: 6 · c02: 4 · c06: 3 · c07: 4 · c09: 2 · c11: 3 · c13: 2 · diğer kulüpler: 5. Türler: ~24 gönderi, ~8 duyuru, ~4 anket. Her kulübün en çok 1 sabitli gönderisi. Beğeni 0–180, yorum 0–14 aralığında, her kulübün en az 1 yorumlu gönderisi.

**Örnek içerikler (aynen kullan, kalan 26'sını bu üslupta üret):**
1. **c01 · duyuru · sabitli:** "Güz Hackathon'u için ekip kurma haftası başlıyor" — "Bu hafta içinde 4 kişilik ekibini kur. Perşembe günkü hazırlık buluşmasına gelmen yeterli; yeni başlayanlar için mentor desteği olacak."
2. **c01 · gönderi · 2 görsel:** "Dünkü Yapay Zekâya Giriş atölyesinden kareler! Katılan herkese teşekkürler. Bir sonrakinde birlikte model eğiteceğiz."
3. **c03 · duyuru:** "Cumartesi Zigana yürüyüşü için toplanma saati 08:00, ana girişte. Su, mevsimlik mont ve yürüyüş ayakkabısı şart. Kontenjan dolduğu için bekleme listesi açıldı."
4. **c03 · anket:** "Kış kampı için hangi tarih uygun?" — *6–7 Aralık · 13–14 Aralık · 20–21 Aralık* · süre 3 gün · 74 oy (Ayşe/Mehmet henüz oy vermedi).
5. **c02 · gönderi:** "Bu haftaki konuğumuz ilk müşterisini nasıl bulduğunu anlatacak. Sorularını yorumlara bırak, sunum sırasında yanıtlayalım."
6. **c06 · anket:** "Açık mikrofon gecesinde en çok hangi türü görmek istersin?" — *Pop · Rock · Halk müziği · Enstrümantal* · süresi **dolmuş** anket örneği.
7. **c07 · gönderi · 3 görsel:** "Karadeniz sisinde sabah yürüyüşü. Haftaya aynı rotada fotoğraf yürüyüşü yapıyoruz."
8. **c09 · duyuru:** "Güz Kupası kayıtları açıldı! 32 kişilik kontenjan, İsviçre sistemi, 5 tur."
9. **c11 · gönderi:** "Barınak ziyaretimiz için ihtiyaç listesi: mama, battaniye, temizlik malzemesi. Getirebilenler Cuma gününe kadar kulüp odasına bıraksın."
10. **c13 · gönderi:** "Horon çalıştayında temel adımları öğreneceğiz. Kıyafet şartı yok, rahat bir ayakkabı yeterli."

Yorum örnekleri: kısa ("Harika olmuş 👏" yerine emoji kullanmadan "Harika olmuş, teşekkürler!"), uzun (3–4 cümle), soru ("Kontenjan dolmadan kayıt olabilir miyiz?") ve yönetimden yanıt. Görseller kodla üretilen CoverArt'tır.

### 11.7 Bildirimler, başvurular, şikayetler

- **Bildirimler:** Her hesapta 3–10 bildirim; en az 1 okunmamış ve 1 okunmuş; farklı türler; bugün/dün/bu hafta/daha eski dağılımı. Burak: 3 × `application_received` (okunmamış) + 1 `event_reminder`. Elif: 2 × `application_received`. Mehmet: `announcement`, `event_new`, `application_rejected` (Tiyatro), `event_reminder` (e01), `waitlist_promoted` yok (bekleme listesi demo için değil). Admin: 3 × `new_report`. Ayşe: `system` (hoş geldin, okunmuş), `event_new` (e01, okunmamış), `event_new` (e04, okunmamış).
- **Başvurular:**
  - **c03 (Burak):** 9 **bekleyen** (farklı bölüm/sınıf; 2'sinde uzun not, 3'ünde not yok), 14 onaylı (geçmiş), 4 reddedilmiş (nedenli). Bekleyenlerden **"Cem Aydın" `stale=true`** (çakışma demo'su).
  - **c01 (Elif):** 6 bekleyen.
  - Diğer kulüplerde 0–3 bekleyen.
- **Şikayetler (8):** 5 **açık** (2 gönderi: spam ve uygunsuz içerik; 1 yorum: taciz; 1 kullanıcı: sahte profil; 1 kulüp: yanlış bilgi), 3 **çözüldü**. Her biri bir veya daha fazla şikayetçiye bağlıdır; açıkların en az birinde 3 şikayet vardır ("3 şikayet" rozeti).
- **Faaliyet geçmişi:** Her kulüp için son 30 günde 15–25 olay (başvuru onayı, etkinlik yayını, gönderi, rol değişikliği…).

### 11.8 SSS (SET-05)

8 soru-cevap (TR+EN): *Bir kulübe nasıl başvururum? · Başvurum neden hâlâ beklemede? · QR kodum okutulmuyor, ne yapmalıyım? · Bildirim alamıyorum · Hesabımı nasıl silerim? · Kulübüm uygulamada yok, nasıl eklenir? · E-posta adresimi değiştirebilir miyim? · Bir kullanıcıyı veya içeriği nasıl şikayet ederim?* Cevaplar 2–4 cümle, akış adımlarına gerçekten karşılık gelir.

### 11.9 Kampüs mekânları (10, kurgusal adlar)

Kongre ve Kültür Merkezi — Salon A · Kongre ve Kültür Merkezi — Salon B · Mühendislik Fakültesi Amfi-1 · Bilgisayar Laboratuvarı-2 · Açık Hava Sahnesi · Öğrenci Kulüpleri Binası — Toplantı Salonu · Merkez Kütüphane — Çalışma Salonu · Spor Salonu · Kampüs Ana Giriş (toplanma noktası) · Yemekhane Önü Meydan.

### 11.10 Önerilen test senaryoları (prototip bunlarla gezilebilmeli)

| # | Senaryo | Adımlar (özet) |
|---|---|---|
| S1 | **Başvur → onayla → üye ol** | Ayşe ile giriş → CLB-01 → Doğa Sporları "Katıl" → SHT-05 → gönder → CLB-04 → Kontrol Paneli'nden Burak'a geç → MGT-02 Başvurular → Ayşe'yi onayla → Ayşe'ye dön → Bildirimler → CLB-03 üye modu |
| S2 | **Etkinliğe katıl → bilet → yoklama** | Ayşe → EVT-01 → e01 → Katıl → SHT-12 → bilet (EVT-03) → "Okutuldu simüle et" → Elif'e geç → MGT-06 → Ayşe "Katıldı" |
| S3 | **Dolu etkinlik** | Ayşe → e03 → DLG-15 → bekleme listesi → EVT-04 "Bekleme listesi" |
| S4 | **Etkinlik oluştur** | Burak → MGT-05 (3 adım) → yayınla → Ayşe'de `event_new` bildirimi |
| S5 | **Duyuru limiti** | Burak → FED-03 Duyuru → 3 kez yayınla → 3. denemede DLG-24 |
| S6 | **Moderasyon** | Mehmet bir gönderiyi şikayet eder → Admin → ADM-04 → içeriği kaldır → Mehmet'te `report_resolved` |
| S7 | **Hesap silme engeli** | Burak → SET-03 (başkan engeli) · Ayşe → SET-03 tam akış |
| S8 | **Çevrimdışı** | Panelden Çevrimdışı → beğen/başvur → TST-24 → Çevrimiçi → TST-25 |
| S9 | **Danışman** | Zeynep → MGT-01 salt okunur → Onayla → TST-26 |
| S10 | **Kulüp aç, askıya al** | Admin → ADM-03 → oluştur → ADM-02 → askıya al (DLG-28) |
| S11 | **Çakışma** | Burak → Başvurular → "Cem Aydın" onayla → DLG-18 |
| S12 | **Dil/tema** | AUT-01 köşe TR/EN → tüm ekran dil değişimi → Koyu tema → tüm sheet/dialog'lar |

---

## 12. Assets Sayfası (Toplu İndirme)

Amaç: Projede kullanılan **tüm görsel ve kod varlıklarının tek yerde toplanması ve tek tuşla indirilmesi**. Sayfa, site menüsünde **Assets** adıyla bulunur ve açık/koyu temada çalışır.

### 12.1 Genel yerleşim

- Üstte başlık, **Tümünü indir (ZIP)** (primary, ilerleme çubuğu ve dosya sayısı ile), arama alanı.
- **Sekmeler:** İkonlar · Renkler · Tipografi · Amblem · İllüstrasyonlar · Kapaklar ve Desenler · Veri ve Dil · Flutter Çıktıları.
- Her sekmenin başında "**Bu bölümü indir (ZIP)**" butonu.
- Her varlık kartında: önizleme, ad, boyut/format, **Kopyala** (ad veya kod), **İndir**.

### 12.2 İkonlar (≈130, tek `ICONS` registry'si)

- Izgara görünümü: ikon + ad. **Kontroller:** boyut kaydırıcısı (16–48 px), **çizgi kalınlığı** kaydırıcısı (1–2.5), renk seçici (yalnızca önizleme), kategori çipleri, arama.
- **Her ikonda:** `Adı kopyala` · `SVG kopyala` · `SVG indir` · `PNG indir` (48/96/192 px, saydam zemin) · `Flutter kodu kopyala` (`LucideIcons.home`, `Icon(...)`).
- **Zorunlu liste** (K8). Listede olmayan ikon kullanılırsa listeye eklenir:

```text
Gezinme:     home search bell user users calendar layout-grid list menu chevron-left chevron-right
             chevron-down chevron-up arrow-left arrow-right arrow-up x plus minus check check-check
             more-vertical more-horizontal external-link link copy share-2 download upload refresh-cw
             sliders-horizontal arrow-up-down settings log-in log-out
Güvenlik:    mail key-round lock lock-open eye eye-off shield shield-check badge-check smartphone
             languages globe moon sun monitor
Kullanıcı:   user-plus user-check user-x user-cog crown graduation-cap
İçerik:      heart message-circle send bookmark megaphone flag ban image images camera pin pin-off
             pencil trash-2 file-text scroll-text life-buoy inbox history clipboard-list list-checks
             sparkles
Etkinlik:    calendar-plus calendar-check calendar-x calendar-days clock map-pin navigation qr-code
             scan-line ticket hourglass party-popper flashlight switch-camera bell-ring bell-off mic
Durum:       circle-check circle-x triangle-alert info circle-help wifi-off cloud-off loader-circle
Grafik:      chart-column chart-line chart-pie trending-up trending-down
Kulüp/kategori: code-xml flask-conical mountain drama heart-handshake briefcase gamepad-2 music
             rocket lightbulb book-open pickaxe puzzle palette trophy landmark newspaper film tent
             users-round cpu dumbbell
```

- **Ad uyumu:** Bu belgede geçen `check-circle`, `x-circle`, `alert-triangle`, `help-circle`, `unlock`, `loader`, `bar-chart-3`, `pie-chart`, `line-chart` eski Lucide adlarıdır. Registry **güncel adları** tutar (`circle-check`, `circle-x`, `triangle-alert`, `circle-help`, `lock-open`, `loader-circle`, `chart-column`, `chart-pie`, `chart-line`); eski adlar **alias** olarak aynı ikona çözülür.

### 12.3 Renkler

- Bölüm 4.1'deki **tüm tokenlar**: kare önizleme (açık/koyu yan yana), token adı, hex, **kopyala** (hex, CSS değişkeni, Flutter `Color(0xFF…)`), kontrast rozeti (AA/AAA) seçili metin renklerinde.
- Rol ve durum rozeti paleti; 3 kapak paleti (Kırmızı–Krem, Slate–Lacivert, Bordo–Kum) gradient önizlemeleriyle.
- İndirilebilirler: `tokens.json`, `tokens.css`, `app_colors.dart`, `app_theme.dart` (açık+koyu `ColorScheme`).

### 12.4 Tipografi

- **Montserrat** (400 · 500 · 600 · 700) ve **Inter** (400 · 500 · 600): her ağırlık için örnek satırı, tüm Türkçe karakterleri içeren test metni ("ĞÜŞİÖÇ ğüşıöç — Gümüşhane Üniversitesi — 0123456789"), TR/EN karşılaştırması.
- Tipografi ölçeği tablosu (Bölüm 4.2) canlı örneklerle; her stil için **CSS kopyala** ve **Flutter `TextStyle` kopyala**.
- **Font indirme:** her aile için **Google Fonts'ta aç** (DLG-32) ve **woff2 indir** (Google Fonts CSS'inden `latin` + `latin-ext` alt kümelerini çekip ZIP'e koyar; ağ engelliyse bu satır "ZIP'e dahil edilemedi, Google Fonts bağlantısını kullan" uyarısı verir ama ZIP yine oluşur). **`latin-ext` zorunludur** (ğ, ş, İ, ı için).
- İndirilebilirler: `typography.json`, `text_theme.dart`, `FONTS.md` (lisans: SIL OFL, `pubspec.yaml` font tanımı örneği).

### 12.5 Amblem ve illüstrasyonlar

- `LogoPlaceholder` (kırmızı daire amblem): yatay, dikey ve yalnızca-amblem varyantları, açık/koyu zemin, 16–512 px, **SVG ve PNG indir**. Üstte uyarı notu: "Gerçek üniversite logosu bu çalışmada kullanılmamıştır; kullanım izni alındıktan sonra bu dosyaların yerine konur."
- **12 illüstrasyon** (SVG; tek renk + kırmızı vurgu; açık/koyu uyumlu): `onb-discover`, `onb-join`, `onb-follow`, `empty-clubs`, `empty-events`, `empty-notifications`, `empty-posts`, `empty-applications`, `error`, `offline`, `email-verify`, `locked`. Her biri 3 boyutlu önizleme + **SVG indir**.
- Uygulama ikonu önerisi (1024 × 1024): amblem, kırmızı zemin; iOS/Android maskeleri önizlemesi.

### 12.6 Kapaklar ve desenler

- `CoverArt` üreticisi: 3 palet × 4 desen = 12 şablon, **seed girişi** ile canlı üretim, **SVG indir**. Kategori ikonları ile örnek 14 kulüp kapağı (gerçek seed'lerle).
- Avatar üreticisi önizlemesi (baş harf + gradient), 24–96 px.
- Desenler: dağ silüeti, çizgi, nokta ızgarası, dalga (4 SVG), `patterns/` klasörü.

### 12.7 Veri ve dil

- `demo-data.json` (Bölüm 11'in tamamı: kullanıcılar, kulüpler, etkinlikler, gönderiler, bildirimler, başvurular, şikayetler; tarihler **ISO 8601 + göreli ofset** alanıyla).
- **`app_tr.arb` ve `app_en.arb`:** i18n sözlüğünden otomatik üretilir (`@@locale`, ICU çoğul/parametre söz dizimi, her anahtar için `@anahtar` açıklaması). Çeviri tablosu önizlemesi (anahtar | TR | EN) ve eksik çeviri sayacı (**0 olmalı**).
- Bölüm 8–10'daki tüm **sheet/dialog/toast metinleri** sözlükte bulunur.

### 12.8 Toplu indirme (ZIP)

- **JSZip** ve **FileSaver** (cdnjs) ile tarayıcıda üretilir; ilerleme çubuğu ("42/218 dosya"), iptal edilebilir, bitince toast. Kütüphane yüklenemezse yedek: dosyaları sırayla tek tek indir.
- **ZIP yapısı:**

```text
gu-kulupler-assets.zip
├─ README.md                    (içerik özeti, lisans notları, Flutter'a aktarma adımları)
├─ icons/
│  ├─ svg/*.svg                 (≈130 dosya, kebab-case ad)
│  └─ png/{ad}@48.png|@96|@192
├─ logo/                        (placeholder amblem: svg + png)
├─ illustrations/*.svg          (12)
├─ patterns/*.svg  covers/*.svg (şablonlar + 14 kulüp kapağı)
├─ colors/   tokens.json  tokens.css  app_colors.dart  app_theme.dart
├─ typography/  typography.json  text_theme.dart  FONTS.md  fonts/*.woff2 (varsa)
├─ i18n/     app_tr.arb  app_en.arb
└─ data/     demo-data.json
```

- Dosya adları sabit ve küçük harflidir; boşluk ve Türkçe karakter yoktur.

---

## 13. Tasarım Sistemi Sayfası

Site menüsünde **Tasarım Sistemi**. Üstte **açık/koyu** ve **TR/EN** anahtarları; her bölüm "Kodu kopyala" ve **durum zorlama** kontrolleri içerir (hover, pressed, focus, disabled, loading).

| Bölüm | İçerik |
|---|---|
| Renkler | Tüm tokenlar, açık/koyu, kontrast oranları |
| Tipografi | Ölçek + canlı örnek |
| Boşluk, köşe, gölge | Görsel ölçekler |
| Butonlar | 6 varyant × 3 boyut × (varsayılan, hover, pressed, focus, loading, disabled), ikonlu, ikon-only, tam genişlik |
| Girdiler | Metin, şifre, arama, çok satırlı, seçici alan, sayaçlı; durumlar: boş, dolu, odak, hata, devre dışı, yardım metni |
| Seçim kontrolleri | Checkbox, radyo, anahtar, segmented, çipler (filtre/seçim/girdi) |
| Rozetler ve avatar | Rol, durum, sayaç; avatar boyutları ve grup |
| Kartlar | Kulüp (liste/ızgara), etkinlik, gönderi (metin/görsel/anket/duyuru), bildirim, üye, başvuru, KPI; her biri normal/skeleton/boş |
| Gezinme | Alt çubuk (4 ve 5 sekme, rozetli), app bar (büyük/küçük/arama), üst sekmeler, stepper, breadcrumb yok |
| Sheet / Dialog / Toast | Her tipten çalışan örnek açma butonu; tüm 34 sheet, 32 dialog, 58 toast **"Katalog" alt sekmesinden tek tek açılabilir** |
| Bantlar | Çevrimdışı, bilgi, uyarı, salt okunur, askıda |
| Geri bildirim | İlerleme (doğrusal kontenjan, dairesel), skeleton, boş durum (12 illüstrasyonla), hata durumu |
| Özel bileşenler | Aylık takvim, tarih/saat seçici, QR bilet çerçevesi, kontenjan çubuğu, anket çubukları, mini çizgi grafik |
| Hareket | Süre/eğri tokenları canlı demo, sayfa geçişi, sheet, dialog, başarı çizgisi |

---

## 14. Ekran Haritası ve Kalite Kontrol Sayfaları

### 14.1 Ekran Haritası sayfası

- **Akış diyagramları (tıklanabilir düğümler):** düğüme tıklamak prototipi ilgili ekranda, uygun demo hesapla açar.

| Akış | Adımlar |
|---|---|
| F1 Kayıt | ONB-01 → AUT-02 → AUT-03 → AUT-05 → CLB-01 |
| F2 Başvuru | CLB-01 → CLB-03 → SHT-05 → CLB-04 → (bildirim) → CLB-03 üye |
| F3 Başvuru onayı | NTF-01 → MGT-02 → SHT-19 / SHT-20 → TST-27/28 |
| F4 Etkinliğe katılım | EVT-01 → EVT-02 → SHT-12 → EVT-03 |
| F5 Etkinlik yönetimi | MGT-04 → MGT-05 → DLG-22 → MGT-06 → MGT-07 → SHT-24 |
| F6 İçerik | FED-03 → FED-01 → FED-02 |
| F7 Moderasyon | SHT-10 → DLG-12 → ADM-04 → SHT-26 → DLG-29 |
| F8 Hesap silme | PRF-01 → SET-01 → SET-03 |
| F9 Kulüp açma | ADM-02 → ADM-03 → SHT-25 |
| F10 Rol ve devir | MGT-03 → SHT-21 → SHT-22 → DLG-20 / SHT-25 → DLG-21 |

- **Ekran envanteri tablosu:** 51 ekran için ID, ad, rota, roller, **Aç** butonu.
- **Varsayımlar kutusu:** Teslimde yapılan tüm varsayımlar maddeler halinde (örn. "A1 — e-posta alan adı örnektir", "A2 — bölüm listesi örnektir", "A3 — QR, kamera, harita ve push simülasyondur", "A4 — dış bağlantılar demo dialog'una yönlenir").

### 14.2 Kalite Kontrol — Aksiyon Kapsamı

- **Aksiyon kayıt defteri:** `data-action` değerleri, ekran, bağlı olduğu sonuç türü (navigasyon / sheet / dialog / toast / durum), **tıklanma sayısı** (oturum içinde).
- **"Bu ekranı tara":** Açık ekrandaki tüm etkileşimli öğeleri (`button`, `a`, `[role=button]`, `[tabindex]`, `input`…) sayar; `data-action` veya handler'ı olmayanları **kırmızı listeler**.
- **"Tüm ekranları tara":** Tüm ekranları sırayla ziyaret eder (uygun rolle), her birinde taramayı çalıştırır, **toplam ölü öğe = 0** olmalıdır.
- **Kapsam özeti:** Ekran **51/51**, sheet **34/34**, dialog **32/32**, toast **58/58** (registry sayısı beklenenle karşılaştırılır; eksik kimlikler listelenir). i18n eksik anahtar sayısı **0**.

### 14.3 Self-check raporu

Bölüm 15'teki kontrol listesi bu sayfada çalıştırılabilir bir listedir (her madde **GEÇTİ / KALDI** + not). **Raporu indir** → `qa-report.json`. KALDI olan madde varsa teslimden önce düzeltilir.

---

## 15. Kabul Kriterleri ve Self-Check

Teslimden önce her madde işaretlenir. Hepsi **GEÇTİ** olmadan teslim etme.

**Kapsam**
- [ ] 51 ekran, 34 sheet, 32 dialog, 58 toast mevcut ve kimlikleriyle bulunabilir.
- [ ] Bölüm 7'deki her **aksiyon** çalışıyor ve gözlemlenebilir sonuç üretiyor. Ölü öğe sayısı **0**.
- [ ] Faz 2 özelliği için buton/sekme/etiket yok.

**Veri ve akış**
- [ ] Tek store; S1–S12 senaryoları baştan sona çalışıyor.
- [ ] Başvuru → onay → bildirim → üye modu zinciri roller arası geçişte tutarlı.
- [ ] Kontenjan, bekleme listesi, bilet ve yoklama sayıları ekranlar arasında birebir tutarlı.
- [ ] Geri al (Undo) eylemleri store'u gerçekten eski haline döndürüyor.
- [ ] Duyuru limiti (2/gün) ve tekrar başvuru bekleme süresi (7 gün) doğru çalışıyor.

**Durumlar**
- [ ] Her liste için skeleton, boş, hata, çevrimdışı durumu var ve Kontrol Paneli'nden zorlanabiliyor.
- [ ] Her form için doğrulama hatası, yükleniyor ve başarı durumu var; çift gönderim engelli.
- [ ] Danışman rolünde tüm yazma aksiyonları devre dışı + TST-26.

**Dil, tema, erişilebilirlik**
- [ ] TR/EN **eksiksiz**, eksik anahtar **0**; ekran yeniden yüklenmeden değişiyor; `lang` güncelleniyor; Türkçe büyük harf "İ" doğru.
- [ ] Açık/koyu tema her ekranda, her sheet/dialog'da doğru; kontrast AA.
- [ ] Dokunma hedefleri ≥ 48 px; tüm ikon butonlarda `aria-label`; odak halkası; klavye ile tam gezinti; dialog/sheet odak tuzağı.
- [ ] Yazı boyutu %160'ta düzen bozulmuyor; `prefers-reduced-motion` destekleniyor.
- [ ] 360 ve 430 px genişlikte düzen taşmıyor.

**Assets**
- [ ] Her kullanılan ikon `ICONS` registry'sinde; Assets sayfası **hepsini** listeliyor.
- [ ] **Tümünü indir (ZIP)** çalışıyor; yapı Bölüm 12.8 ile aynı; dosya adları kebab-case.
- [ ] `app_tr.arb` ve `app_en.arb` geçerli JSON ve Flutter `gen-l10n` ile uyumlu.
- [ ] `tokens.css` ve `app_colors.dart` değerleri Bölüm 4.1 ile birebir.

**İçerik**
- [ ] Lorem ipsum, gerçek kişi, gerçek marka, gerçek fotoğraf, üniversite logosu kopyası **yok**.
- [ ] Emoji ikon yerine kullanılmamış.

---

## 16. Flutter Aktarım Notları

| Prototip | Flutter karşılığı |
|---|---|
| `tokens.css` / renk tokenları | `ThemeData` + `ColorScheme` (`app_colors.dart`, `app_theme.dart`); `brand.primary` → `colorScheme.primary` |
| Tipografi ölçeği | `TextTheme`; Montserrat/Inter → `google_fonts` ya da `assets/fonts` (+ `pubspec.yaml`) |
| Köşe/boşluk tokenları | `ThemeExtension<AppSpacing>` / `AppRadius` sabitleri |
| `ICONS` (Lucide stili) | `lucide_icons_flutter` ya da `flutter_svg` ile `assets/icons/*.svg` |
| Router / sekme yığınları | `go_router` (`StatefulShellRoute` ile sekmeler başına yığın) |
| Store | `flutter_riverpod` (`Notifier`/`AsyncNotifier`) + repository katmanı |
| i18n | `flutter_localizations` + `intl`, `l10n.yaml`, indirilen `app_tr.arb` / `app_en.arb` |
| Bottom sheet / dialog / toast | `showModalBottomSheet` / `showDialog` / `ScaffoldMessenger` SnackBar (ortak yardımcı sınıf) |
| Takvim | `table_calendar` |
| QR üretme / tarama | `qr_flutter` / `mobile_scanner` |
| Kamera/galeri | `image_picker`, izinler için `permission_handler` |
| Takvime ekleme, paylaşım, dış bağlantı | `add_2_calendar`, `share_plus`, `url_launcher` |
| Önbellek ve görsel | Firestore yerel önbellek; `cached_network_image` |

**Prototipte simüle edilen → üretimdeki karşılığı**

| Prototip simülasyonu | Üretim |
|---|---|
| `fakeApi` gecikmesi | Firestore/Functions çağrıları |
| Demo giriş, e-posta doğrulama | Firebase Auth (e-posta bağlantısı, alan adı kuralı Cloud Function/Rules ile) |
| Rol değiştirme paneli | Firebase **custom claims** + Firestore `clubs/{id}/members/{uid}` (`status`, `role`) |
| Bildirimler | FCM + Cloud Functions (üyelik/etkinlik dokümanı değişince tetiklenir) |
| Duyuru limiti (2/gün) | `clubs/{id}/stats` sayacı + Functions |
| Zorunlu güncelleme | Remote Config |
| QR bilet + yoklama | `events/{id}/attendees/{uid}` + imzalı kod |
| Şikayet/engelleme | `reports`, `blocks` koleksiyonları |

**Güvenlik notu:** Arayüzde butonu gizlemek yetki değildir; yetki kontrolleri Firestore Security Rules'ta (rol alanları üzerinden) uygulanmalıdır. Kullanıcı yalnızca kendi üyelik dokümanını `pending` olarak oluşturabilmeli; durum yalnızca ilgili kulübün yöneticisi tarafından değiştirilebilmelidir.

---

## 17. Kapsam Dışı (Faz 2 — tasarıma dahil etme)

Aşağıdakiler için ekran, buton, sekme, menü öğesi veya "yakında" etiketi **koyma**:

- Kulüp içi görev yönetimi (Kanban), bütçe/gider takibi
- Katılım sertifikası (PDF) üretimi
- Kulüp içi sohbet / mesajlaşma
- Kulüp kurma başvurusu ve onay süreci (MVP'de kulüpleri süper admin ekler)
- Süper admin web paneli (yalnızca mobil "Admin" sekmesi vardır)
- Global akış sekmesi, hikâyeler (stories), kullanıcı arama
- Ücretli etkinlik, ödeme, sponsor modülü
- Gerçek harita entegrasyonu, canlı kamera taraması, gerçek push
- Çoklu üniversite desteği, tablet/yatay yerleşim
- Danışman için etkinlik onay yetkisi

---

*Bu belge sonu. Teslimde Bölüm 15 self-check sonucunu Kalite Kontrol sayfasına ekleyerek bitir.*

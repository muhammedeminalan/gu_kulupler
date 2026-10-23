# Değişiklik Günlüğü

Bu projedeki önemli değişiklikler bu dosyada tutulur.

Biçim [Keep a Changelog](https://keepachangelog.com/tr-TR/1.1.0/) kurallarına uyar. Sürümler [Anlamsal Sürümleme](https://semver.org/lang/tr/) ile numaralandırılır.

## [Yayınlanmamış]

### Eklendi
- Bölüm listesine **Yönetim Bilişim Sistemleri** (İktisadi ve İdari Bilimler Fakültesi) eklendi (H-26).

### Planlandı
- Bölüm, fakülte ve mekân listelerinin Firestore'dan gelmesi (`docs/plans/dinamik-listeler.md`, H-22).
- Geniş ekran ve web için tam responsive düzen (`docs/plans/responsive-web.md`, H-23).

## [1.1.0] — 2026-10-20

İlk Google Play sürümü; iOS güncellemesi.

### Eklendi
- **Geniş ekranda web düzeni (H-23):** bilgisayarda uygulama desenli zeminde ortalanmış bir kartta açılır (en fazla 768 genişlik); geniş pencerede alt menü yerine solda yan menü (sekmeler + bildirim sayısı). Telefon ve mobil uygulama değişmedi.
- **Daha çok bildirim (H-25):** uygulama kapalıyken de push gelir:
  - Kulüpte yeni gönderi / anket → kulüp üyelerine.
  - Gönderine yorum → sana; yorum yaptığın gönderiye yeni yorum → sana.
  - Herkese açık yeni etkinlik → tüm kullanıcılara.
  - Bildirime dokununca ilgili gönderi açılır. Bildirim tercihlerinde "Yeni gönderiler" ve "Yorumlar" anahtarları eklendi.
- **Uygulama simgesi rozeti:** iOS'ta simgede okunmamış bildirim sayısı görünür; okudukça azalır, çıkışta silinir.

### Düzeltildi
- Gönderi ekranı bildirim üreten yolu çağırmıyordu: bildirimli duyuru ve yeni gönderi push'u hiç gitmiyordu.
- **Web sürümü:** Firebase web uygulaması ve `web/` hedefi eklendi. Uygulama Hosting'de [gu-kulupler.web.app/app](https://gu-kulupler.web.app/app/) adresinden yayınlanır; tanıtım sayfasına "Web'de aç" bağlantısı eklendi. Web'de push, yerel hatırlatıcı ve Crashlytics kapalıdır.
- **Etkinlik konum kartı görseli:** kapak deseni üzerinde büyük pin ve mekân adı. Tasarımdaki taslak yer tutucunun yerini aldı (karar H-24).
- **Otomatik web yayını:** GitHub'da sürüm yayımlanınca web uygulaması GitHub Actions ile Hosting'e yüklenir.
- **Yönetim betikleri:**
  - Gerçek projeye demo içerik yazan `tool/admin/seed_demo_content.js`.
  - App Store inceleme hesabı açan `tool/admin/create_review_account.js`.
  - Serbest metinli push gönderen `tool/admin/send_push.js`.
- **Açık kaynak belgeleri:** README, LICENSE (MIT), katkı rehberi, davranış kuralları, güvenlik politikası, destek, katkıda bulunanlar, issue ve PR şablonları.

## [1.0.0] — 2026-10-16

İlk sürüm. iOS için TestFlight'ta ve App Store incelemesinde.

### Eklendi
- **Hesap:**
  - Üniversite e-postasıyla kayıt ve e-posta doğrulama.
  - Profil kurulumu (bölüm, sınıf, ilgi alanları).
  - Şifre sıfırlama.
  - KVKK ve gizlilik metinleri.
- **Kulüpler:**
  - Kategori ve sıralamayla kulüp rehberi, arama, öneriler.
  - Kulüp sayfası: hakkında, kurul, gönderiler, etkinlikler, üyeler.
  - Üyelik başvurusu, başvuru durumu, ayrılma.
- **Etkinlikler:**
  - Katılım ve kontenjan.
  - Bekleme listesi ve otomatik terfi.
  - QR bilet, takvime ekleme (`.ics`), hatırlatıcı.
- **Akış:** duyuru, gönderi ve anket; beğeni, yorum, kaydetme; şikayet ve engelleme.
- **Bildirimler:** uygulama içi bildirim kutusu, push (FCM), bildirim tercihleri ve sessiz saatler.
- **Kulüp yönetimi:**
  - Başvuru onay / ret (geri alma dahil).
  - Üye ve rol yönetimi, başkanlık devri.
  - Etkinlik oluşturma ve QR ile yoklama.
  - İçerik yönetimi, kulüp ayarları, etkinlik günlüğü.
- **Uygulama yönetimi:** genel bakış, kulüp açma / askıya alma, şikayet kuyruğu, kullanıcı askıya alma.
- **Ayarlar:** dil (TR / EN), tema (açık / koyu / sistem), engellenenler, destek talebi, uygulama içinden hesap silme.
- **Altyapı:**
  - Firestore ve Storage Security Rules (rol × işlem testli), soft delete.
  - Cloud Functions: push dağıtımı, bekleme listesi terfisi, hesap silme temizliği.
  - Remote Config: bakım modu, güncelleme kapısı.
  - Crashlytics; çevrimdışı önbellek ve bant.
- **Web sayfaları:** [gu-kulupler.web.app](https://gu-kulupler.web.app) (tanıtım, gizlilik politikası, destek).

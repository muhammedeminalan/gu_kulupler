# Güvenlik Politikası

## Desteklenen sürümler

| Sürüm | Destek |
|---|---|
| 1.0.x | ✅ |
| < 1.0 | ❌ |

Güvenlik düzeltmeleri en son sürüme gelir. Uygulamayı güncel tut.

## Güvenlik açığı bildirme

**Güvenlik açıklarını herkese açık GitHub issue'su olarak bildirme.**

İki yoldan birini kullan:

1. **GitHub özel bildirimi (önerilen):** [Security → Report a vulnerability](https://github.com/muhammedeminalan/gu_kulupler/security/advisories/new)
2. **E-posta:** **eminalan334@gmail.com**. Konu satırına `[GÜVENLİK]` yaz.

Bildirimde şunlar olsun:
- açığın türü ve etkisi;
- etkilenen bileşen (uygulama ekranı, Security Rules, Cloud Function, Hosting…);
- yeniden üretme adımları ya da kavram kanıtı;
- varsa önerdiğin çözüm.

### Süreç

| Adım | Süre |
|---|---|
| Bildirimin alındığının onayı | 3 iş günü içinde |
| İlk değerlendirme ve önem derecesi | 7 gün içinde |
| Düzeltme ya da azaltma planı | önem derecesine göre |

Açık giderilene kadar ayrıntıları gizli tutmanı rica ederiz. Düzeltme yayımlanınca istersen adınla teşekkür ederiz.

## Kapsam

**Kapsamda:**
- Firestore ve Storage Security Rules ile yetki atlatma (başka kullanıcının verisini okuma / yazma, rol yükseltme).
- Kişisel veri sızıntısı (e-posta, başvuru notu, özel belgeler).
- Cloud Functions girdi doğrulama ve güven sınırı.
- Uygulamada kimlik doğrulama ve oturum hataları.

**Kapsam dışı:**
- **Firebase istemci API anahtarları.** `firebase_options.dart`, `google-services.json` ve `GoogleService-Info.plist` dosyalarındaki anahtarlar tasarım gereği herkese açıktır; erişimi Security Rules sınırlar.
- Hizmet engelleme (DoS) ve otomatik tarama araçlarının ham çıktıları.
- Fiziksel erişim ya da root / jailbreak edilmiş cihaz gerektiren senaryolar.
- Sosyal mühendislik.

## Güvenlik ilkeleri

- Yetki arayüzde gizlenerek sağlanmaz, **Security Rules**'ta uygulanır. Her kuralın rol × işlem testi vardır (`firebase/test/`).
- Silme bütün istemcilere kapalıdır; veriler soft delete ile işaretlenir.
- E-posta adresleri profilde gösterilmez. Yalnızca ilgili kulüp yönetimi ve uygulama yöneticileri görür.
- Servis hesabı anahtarları depo dışında tutulur. `tool/admin` betikleri repo içindeki anahtarı reddeder.
- Süper admin yetkisi yalnızca Firebase custom claim'idir; Firestore alanıyla yetki yükseltilemez.

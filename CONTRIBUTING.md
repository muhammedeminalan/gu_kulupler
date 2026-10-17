# Katkı Rehberi

GÜ Kulüpler'e katkı vermek istediğin için teşekkürler! Bu belge; hata bildirmeyi, öneri sunmayı ve kod göndermeyi anlatır.

Bu projeye katılan herkes [Davranış Kuralları](CODE_OF_CONDUCT.md)'na uyar.

## İçindekiler

- [Nasıl katkı verebilirim?](#nasıl-katkı-verebilirim)
- [Geliştirme ortamı](#geliştirme-ortamı)
- [Geliştirme akışı](#geliştirme-akışı)
- [Dal ve commit biçimi](#dal-ve-commit-biçimi)
- [Kod kuralları](#kod-kuralları)
- [Test ve kalite kapısı](#test-ve-kalite-kapısı)
- [Pull request süreci](#pull-request-süreci)

## Nasıl katkı verebilirim?

### Hata bildirmek

1. Önce [açık issue'lara](https://github.com/muhammedeminalan/gu_kulupler/issues) bak; aynı hata bildirilmiş olabilir.
2. Yoksa **Hata bildirimi** şablonuyla yeni issue aç.
3. Şunları yaz:
   - adımlar;
   - beklenen ve gerçekleşen davranış;
   - cihaz, işletim sistemi ve uygulama sürümü;
   - varsa ekran görüntüsü.

> Güvenlik açıkları için issue **açma**. [SECURITY.md](SECURITY.md) dosyasındaki yolu izle.

### Özellik önermek

**Özellik önerisi** şablonuyla issue aç. Hangi sorunu çözdüğünü ve kimin işine yarayacağını anlat. Büyük değişikliklere başlamadan önce issue'da konuşalım; böylece emeğin boşa gitmez.

### Kod göndermek

Küçük düzeltmeler (yazım, metin, küçük hata) için doğrudan PR açabilirsin. Yeni özellik, mimari değişiklik ya da tasarım değişikliği için önce issue aç.

## Geliştirme ortamı

Kurulum adımları [README → Başlarken](README.md#-başlarken) bölümündedir. Özetle:

```bash
bash tool/codegen.sh   # bağımlılıklar + kod üretimi
bash tool/dev.sh       # emülatör + demo veri + uygulama
```

Geliştirme **her zaman emülatörde** yapılır. Gerçek Firebase projesine yazan komutlar (`firebase deploy`, `tool/admin/*`) yalnızca proje sahibi tarafından çalıştırılır.

## Geliştirme akışı

1. Depoyu fork'la ve klonla.
2. `main`'den yeni bir dal aç (biçim aşağıda).
3. Değişikliği yap; gerekiyorsa testini aynı commit'te yaz.
4. `bash tool/quality_gate.sh` çalıştır. **Kırmızıyken commit atma.**
5. Dalını push'la ve `main`'e PR aç.

## Dal ve commit biçimi

**Dal adı:** `<tür>/<kısa-açıklama>`, örneğin `feat/etkinlik-hatirlatici`, `fix/qr-bilet-hatasi`, `docs/readme`.

**Commit:** [Conventional Commits](https://www.conventionalcommits.org/tr/) + **Türkçe açıklama**.

```
feat(events): bekleme listesinden otomatik terfi bildirimi
fix(auth): doğrulama mailinin yeniden gönderim sayacı
docs: kurulum adımlarına Java gereksinimi eklendi
```

| Tür | Ne zaman |
|---|---|
| `feat` | yeni özellik |
| `fix` | hata düzeltmesi |
| `refactor` | davranışı değiştirmeyen kod düzenlemesi |
| `test` | yalnızca test |
| `docs` | yalnızca belge |
| `chore` | araç, bağımlılık, yapılandırma |
| `perf` | performans |
| `sec` | güvenlik |

Üretilen dosyaları (`*.g.dart`, `lib/l10n/app_localizations*.dart`) commit etme. `--no-verify` kullanma.

## Kod kuralları

Bütün kurallar [CLAUDE.md](CLAUDE.md) dosyasındadır. Kilitli kararlar [docs/decisions.md](docs/decisions.md) dosyasındadır. En önemlileri:

- **Katmanlar tek yönlüdür:** `view → viewmodel → repository → service → Firebase SDK`.
  - `gu_ui` Firebase'e bağımlı değildir.
  - Feature'lar birbirini import etmez.
- **State:** `@riverpod` Notifier ve `Equatable` state kullanılır, `copyWith` elle yazılır. **Freezed ve `AsyncValue` yok.** İstisnayı yutma; `isError` bayrağına çevir.
- **Hardcode yok:** aşağıdakiler token'dan ya da ARB'den gelir. `tool/check_hardcode.sh` reddeder.

  | Kullanma | Yerine |
  |---|---|
  | `Color(0x…)` | `context.gu.colors` |
  | sayısal `EdgeInsets` | `GuInsets` / `GuSpacing` |
  | `TextStyle(fontSize:)` | `context.gu.text` |
  | `Text('…')` | `context.l10n` |
  | `Icon(Icons.…)` | `GuIcon` |
- **Hard delete yok:** silme her zaman soft delete'tir (`isDeleted`, `deletedAt`, `deletedBy`). Ayrıntı: [docs/soft-delete.md](docs/soft-delete.md).
- **Yetki Rules'tadır:** yeni bir yazma yolu açan değişiklik **aynı PR'da** şunları içerir:
  - `firebase/firestore.rules`;
  - indeksler;
  - Rules testi.
- **Yeni metin:** önce `app_tr.arb` ve `app_en.arb` dosyalarının **ikisine de** eklenir.
- **Widget:** yeni widget yazmadan önce [docs/widget-catalog.md](docs/widget-catalog.md) dosyasına bak. Benzeri varsa onu genişlet. Yeni widget'ı kataloğa aynı PR'da ekle.
- **Tasarım uyumu:** ekranlar `design/reference-shots` görüntüleriyle birebir olmalıdır. Bilinçli sapmayı `docs/decisions.md` dosyasına yaz.
- **Salt okunur klasörler:** `design/` ve `reference/` klasörlerine dokunma.

## Test ve kalite kapısı

- Her ViewModel, State, repository ve servis için test **zorunludur**.
- Her widget için widget testi ve golden (açık + koyu) yazılır.
- Her ekran için şunlar yazılır:
  - cihaz matrisi testi (320 / 390 / 430 / tablet × açık / koyu × TR / EN × metin ölçeği 1.0 / 1.3 / 1.6);
  - yükleniyor, boş, hata ve çevrimdışı durum testleri.
- Golden'ları yalnızca bilinçli olarak güncelle (`flutter test --update-goldens <dosya>`) ve bunu PR açıklamasında belirt.

```bash
bash tool/quality_gate.sh --static   # hızlı statik kontrol
bash tool/quality_gate.sh            # tam kapı (PR'dan önce zorunlu)
```

Ayrıntı: [docs/testing.md](docs/testing.md).

## Pull request süreci

1. PR şablonunu doldur:
   - ne değişti, neden değişti;
   - nasıl test edildi;
   - arayüz değiştiyse ekran görüntüsü.
2. PR'ı tek bir konuya odakla; büyük işleri küçük PR'lara böl.
3. Tam kalite kapısı yeşil olmalı.
4. İnceleme yorumlarını yeni commit'lerle karşıla; geçmişi zorla yeniden yazma.
5. Onaylanan PR'ı proje sahibi `main`'e alır.

Katkın [MIT Lisansı](LICENSE) altında yayımlanır.

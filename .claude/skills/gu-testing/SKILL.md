---
name: gu-testing
description: Bu projede test yazma rehberi (widget, golden, ekran cihaz matrisi, aksiyon envanteri, ViewModel, repository/servis, Rules, router, l10n, token). Test eklerken, testi düzeltirken veya "test yaz" istendiğinde kullan.
---

# gu-testing

Tam sözleşme: `docs/testing.md`. **D-33: her widget, servis, repository, ViewModel için test; Rules için emülatör testi.**

## İlkeler

- Davranışı test et (metin, rota, durum, toast, sayaç); özel alanı değil.
- **Mock kütüphanesi yok.** El yazımı fake'ler `test/fakes/` (gerçek arayüzü uygular, bellekte).
- Zaman/rastgelelik enjekte: `AppClock`, `TicketCodeGenerator`; `DateTime.now()`/`Random()` yok.
- Test adı tasarım ID'sini taşır: `group('CLB-01 · Kulüpler', …)`; aksiyon `find.byKey(GuKey.action('CLB-01.join.c03'))`.
- Metin doğrulaması `tester.l10n.<anahtar>` ile (TR ve EN ayrı).
- `pumpAndSettle` sonsuz animasyonda (skeleton) yok → `tester.pump(GuMotion.base)`; shimmer testte kapatılır.
- Flaky/ağ/gerçek zaman yok; `skip:` yok.

## Hangi test, nerede

| Hedef | Test |
|---|---|
| Model | JSON gidiş-dönüş, `copyWith`, eşitlik, `BaseFields` |
| State | `props` ve `copyWith` **her alanı** içeriyor (alan başına assert) |
| ViewModel | `ProviderContainer` + fake repo: başlangıç, mutasyon, optimistik + geri alma, hata → `isError`, art arda tetik |
| Servis/Repository | soft delete alanları, sayaç ±1 aynı batch, hata eşleme, durum makinesi satırları (geçerli + geçersiz) |
| Widget (`gu_ui`/`product`) | tüm durumlar + `Semantics` + dokunma hedefi + 320 dp taşma + golden açık/koyu |
| Ekran | cihaz matrisi + aksiyon envanteri + 5 durum + her aksiyon sonucu |
| Sheet/Dialog/Toast | içerik, kapanma yolları, klavye, `ToastId` kataloğu |
| Router | `AppRedirect` tablosu, rota envanteri, yığın bağımsızlığı, `push` taraması |
| Rules | `firebase/test/` rol × işlem, delete reddi, sayaç, alan listesi, sorgu sözleşmesi |

## Ekran testi iskeleti

```dart
void main() {
  group('CLB-03 · Kulüp detayı', () {
    testWidgets('aksiyon envanteri', (tester) async {
      await tester.pumpApp(const ClubDetailView(clubId: 'c01'), overrides: [...]);
      expectActionInventory(tester, 'CLB-03', role: 'member');          // screens-actions.json ile eşit (muaflar hariç)
    });
    testWidgets('cihaz matrisi', (tester) async {
      await DeviceMatrix.run(tester, (ctx) => ClubDetailView(clubId: 'c01'), overrides: [...]); // taşma = fail
    });
    testWidgets('Katıl → başvuru sheet açılır', (tester) async { /* tap GuKey.action('CLB-03.join') … SHT-05 */ });
    for (final state in ViewState.values) { /* loading/empty/error/offline */ }
  });
}
```

## Cihaz matrisi (D-21)

320×640, 390×844, 430×932, 768×1024 × açık/koyu × TR/EN × ölçek 1.0/1.3/1.6. `--fast` kapısı: 320+390 × açık × TR × {1.0, 1.6}. `overflow_detector` taşmayı **hata** sayar. Formlu ekranlarda klavye varyantı (`viewInsets.bottom=320`).

## Golden

`goldenForThemes(name, widget)`; dosyalar commit edilir; güncelleme yalnızca bilinçli (`--update-goldens <dosya>`), **referans görüntüyle karşılaştırdıktan sonra** ve kullanıcıya bildirilir. Kapsam Q-16.

## Rules testi

Node + `@firebase/rules-unit-testing`; `cd firebase && npm test`. **Her koleksiyonda delete reddi** otomatik; parite testleri: `Limits` ↔ Rules, `ALLOWED_EMAIL_DOMAINS` ↔ Rules regex, `RolePolicy` ↔ beklenti JSON.

## Bitmeden

Eksik test = görev bitmez. `bash tool/quality_gate.sh --task T-xx` testleri koşar; `gu-test-auditor` ajanı boşlukları listeler.

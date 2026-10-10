# Test Stratejisi

> D-33: **her widget, servis, repository ve ViewModel için test.** Kural/Rules için emülatör testi. Test yazılmadan görev bitmez (`prompts/task-calistir.md` adım 6). `tool/quality_gate.sh` testleri koşar; kırmızıyken commit yok.

## 1. İlkeler

1. **Davranışı test et, uygulamayı değil.** Kullanıcının gördüğü/yaptığı (metin, rota, durum, toast, sayaç) doğrulanır; özel alanlar değil.
2. **El yazımı fake'ler** (`test/fakes/`): mock kütüphanesi yok (packages.md §3). Fake'ler gerçek arayüzü (`gu_data` repository/servis arayüzleri) uygular ve bellekte çalışır. Her fake'in kendi küçük testi vardır (arayüz sözleşmesi).
3. **Zaman ve rastgelelik enjekte edilir:** `AppClock` (şimdi, Istanbul günü) ve `TicketCodeGenerator`/`Random` arayüzü. `DateTime.now()` ve `Random()` doğrudan çağrılmaz.
4. **Test adı tasarım ID'sini taşır:** `group('CLB-01 · Kulüpler', …)` (D-19). Aksiyon testleri anahtarla bulur (`find.byKey(GuKey.action('CLB-01.join.c03'))`).
5. **Metin aramak yerine anahtar/semantik:** metin doğrulaması yalnızca l10n ile (`tester.l10n.xyz`), TR ve EN ayrı.
6. **Flaky yasak:** gerçek zamanlayıcı/ağ yok; `tester.pump(GuMotion.base)` ile ilerlet; `pumpAndSettle` sonsuz animasyonda (skeleton shimmer) kullanılmaz — shimmer testte kapatılabilir (`GuSkeleton.debugAnimate=false` ya da `disableAnimations`).
7. Test dosyası yolu kaynağı yansıtır: `lib/features/x/view/y_view.dart` → `test/features/x/view/y_view_test.dart`.

## 2. Dizin ve yardımcılar

```
test/
  fakes/                  # FakeClubRepository, FakeSessionService, FakeFeedbackService, FakeClock…
  helpers/
    pump_app.dart         # tester.pumpApp(widget, {locale, theme, textScale, size, platform, overrides, route})
    device_matrix.dart    # DeviceMatrix.run(tester, builder) → tüm kombinasyonlar, taşma toplayıcı
    golden_helper.dart    # goldenForThemes(name, widget, {locales})
    overflow_detector.dart# FlutterError.onError → "overflowed" yakalar ve testi düşürür
    action_inventory.dart # ekrandaki GuKey.action kümesi ↔ screens-actions.json
    design_ids.dart       # registry.json'dan ID listeleri
    design_files.dart     # repo kökünden JSON/metin okuyucu
    test_l10n.dart        # tester.l10n, l10nFor(locale), loadL10n
    test_container.dart   # createContainer({overrides})
  features/ … core/ … product/ …
packages/gu_data/test/    # model, servis, repository, soft delete, RolePolicy
packages/gu_ui/test/      # token, widget, golden (goldens/ altında); helpers/: pump_app.dart (alt küme: GetIt/Riverpod/AppLocalizations yok) · golden_helper.dart (goldenForWidget) · css_measure.dart · design_sources.dart — CD-122(3)
integration_test/         # birkaç uçtan uca akış (emülatör): auth, başvuru→onay, etkinlik→bilet→yoklama, hesap silme
firebase/test/            # Rules testleri (Node, emülatör)
functions/test/           # Mod F ise
```

`pumpApp` varsayılanları: TR, açık tema, ölçek 1.0, 390×844, Android; `GetIt` her testte `reset()` + fake kaydı; `ProviderScope` override'ları. `route`/`wrapInShell` T-11'de, `GuSkeleton.debugAnimate = false` T-06'da eklenir; `FakeAppClock` T-08'de (CD-122). Aksiyon envanterinin muaf ve dinamik kalıpları `tool/design_exempt_actions.txt` / `tool/design_dynamic_actions.txt` (JS ve Dart tek kaynak).

## 3. Test türleri ve asgari içerik

| Katman | Zorunlu testler |
|---|---|
| **Model** (`gu_data`) | `fromJson/toJson` gidiş-dönüş (Timestamp↔DateTime UTC), `copyWith`, eşitlik, varsayılan `BaseFields`, geçersiz/eksik alan toleransı, `explicit_to_json` iç içe nesne |
| **Servis** (`gu_data`) | Q-06'ya göre `fake_cloud_firestore` ile: CRUD yolları, **`softDelete`/`restore` alanları**, `delete` metodu **yok**, hata → `FirebaseFailure` eşlemesi, sayaçlı batch'ler (±1 aynı batch), sorgu süzgeçleri (`isDeleted==false`) |
| **Repository** | alan dili metotları (başvur/onayla/ayrıl/katıl/vazgeç/yoklama…) durum makinesi tablosunun **her satırı** (domain-model §5): geçerli ve geçersiz geçiş, çakışma (DLG-18), sayaç, bildirim/aktivite üretimi (`NotificationDispatcher` fake'ine çağrı) |
| **ViewModel** | `ProviderContainer` + fake repository: başlangıç state'i, her mutasyon (`copyWith`), optimistik güncelleme + geri alma, hata → `isError`, yarış (art arda tetik) |
| **State** | `props` tüm alanları içeriyor mu (eşitlik testi), `copyWith` her alanı taşıyor mu (reflection yerine her alan için bir assert) |
| **Widget** (`gu_ui`, `product/widget`) | tüm durumlar (default/pressed/focus/disabled/loading/selected/error), `Semantics`, dokunma hedefi, **golden açık+koyu**, 320 dp'de taşmama |
| **Ekran** | §5 matris + aksiyon envanteri + durumlar (normal/yükleniyor/boş/hata/çevrimdışı) + her aksiyonun sonucu (rota/sheet/dialog/toast/durum) |
| **Sheet/Dialog/Toast** | içerik, aksiyonlar, kapanma yolları (scrim, X, aşağı sürükle, geri), klavye altında kayma, `ToastId` kataloğu (78 kimlik → metin/tür/süre/aksiyon) |
| **Router** | navigation.md §7 (redirect tablosu, envanter, yığın, geçiş, `push` taraması) |
| **l10n** | TR/EN anahtar eşitliği, ICU parametreleri, çoğul biçimleri, **Türkçe büyük harf** ("İ", "ı"), kullanılmayan anahtar yok |
| **Token** | `GuColors`/`GuTypography`/`GuSpacing`/`GuRadius`/`GuShadows`/`GuMotion`/`GuSizes` ↔ `registry.json` + `component-css.css`; AA kontrast çiftleri (metin/zemin) her iki tema |
| **Font/ikon** | Türkçe glifler (`ğ ş İ ı ç ö ü ₺`) Montserrat+Inter ile render (golden); `GuIcons` ↔ `assets/icons` birebir (130) ve her SVG yüklenir |
| **Durum çubuğu** | `GuSystemUi` stil haritası (design-contract §5) |
| **Hata yönetimi** | `AppErrorHandler`: hata yakalama → Crashlytics fake'i; `ErrorWidget.builder` nötr `GuErrorState` |
| **Entegrasyon** | `integration_test` (emülatör): kayıt→doğrulama→profil→kulüp başvuru→onay (iki kullanıcı)→etkinlik katıl→bilet→yoklama; hesap silme (anonimleştirme) |

## 4. Rota ve akış testleri

navigation.md §7. Ek: **derin bağlantı akışları** (§4.1 tablo, her tür) ve **sekme yığını bağımsızlığı** testleri ekran görüntüsüz, `GoRouter` + fake oturum ile.

## 5. Cihaz matrisi testi (D-21)

Her **ekran**, her **sheet ve dialog** için (görünüm sınıfı bazında, 51 + 34 + 32):

| Boyut | Genişlik × yükseklik (dp) | Not |
|---|---|---|
| küçük | 320 × 640 | **sağ taşma sıfır** |
| referans | 390 × 844 | tasarım boyutu |
| büyük | 430 × 932 | |
| tablet | 768 × 1024 | Q-13: dikey kilit + ortalanmış 480 dp sütun; tabletle taşma/uzama yok |

× tema {açık, koyu} × dil {TR, EN} × metin ölçeği {1.0, 1.3, 1.6} = **48 kombinasyon/ekran** (4 × 2 × 2 × 3; CD-42 — eski "72" hesap hatası). Klavye (1) ve güvenli alan (4) varyantları bu sayının dışında, yalnızca 390×844 × açık × TR × 1.0. Hızlı kapı (`--fast`): 320 + 390 × açık × TR × {1.0, 1.6}; tam matris CI/commit öncesi `quality_gate.sh` tam modunda. Seçim `test/helpers/device_matrix.dart` içinde `const String.fromEnvironment('GU_MATRIX', defaultValue: 'full')` ile yapılır; kapı `flutter test --dart-define=GU_MATRIX=fast|full` verir (varsayılan `full`).
- `overflow_detector` "A RenderFlex overflowed" mesajını **hata** sayar; ayrıca `tester.takeException() == null`.
- Klavye açık varyantı (formlu ekranlar): `viewInsets.bottom = 320` ile içerik kaydırılabilir ve odaktaki alan görünür.
- Güvenli alan varyantları: üst 47/59 (çentik), alt 34 (home indicator), Android sistem çubuğu.
- Kırpılma kontrolü: metinli öğelerde `Text.overflow` beklenen yerlerde `ellipsis`; hit-test yapılabilirlik (görünür bölge içinde).

## 6. Rules ve politika testleri (`firebase/test/`, emülatör)

Kütüphane: `@firebase/rules-unit-testing`. `npm test` → emülatörleri başlatır (`firebase emulators:exec`).

1. **Rol × işlem matrisi** (`domain-model §3` ve `firestore-rules-spec §3`): her koleksiyon için `{anonim, doğrulanmamış, aktif öğrenci, başvuran(pending), üye, board, president, advisor, süper admin, askıdaki kullanıcı, başka kulübün yöneticisi}` × `{get, list, create, update-izinli-alan, update-izinsiz-alan, softDelete, restore, delete}`. Beklenen sonuçlar tabloda yazılı **beklenti dosyasından** (`firebase/test/expectations/*.json`) okunur; test tek bir döngüdür.
2. **`delete` her yerde reddedilir** (süper admin dahil) — otomatik: tüm koleksiyon/alt koleksiyon adları `FirestoreCollections` + rules'tan çıkarılır.
3. **Durum makinesi:** üyelik geçiş tablosu M1–M14 (her satır: izinli aktör geçer, diğerleri ret; yanlış `from` durumu ret; `retryAfter` içindeyken ret; geri al 30 sn penceresi).
4. **Sayaçlar:** her sayaç için ±1 dışı ret, eşlik eden yazım yoksa ret, aynı batch ile geçiş.
5. **Alan beyaz listesi:** izinsiz alan ekleme/değiştirme ret; `createdAt/updatedAt` sunucu zamanı değilse ret.
6. **Sorgu sözleşmesi:** `firestore-rules-spec §6` tablosundaki her sorgu geçer; süzgeçsiz eşdeğeri `permission-denied` verir.
7. **Duyuru limiti:** gün başına 2; 3. ret; sayaç yok → ret; ertesi Istanbul günü (UTC+3 sınırı `request.time` ile) sıfırlanır.
8. **E-posta alan adı:** izinli iki alan adı geçer; diğer alan adı / doğrulanmamış e-posta ret.
9. **Erişim çağrısı bütçesi:** en ağır işlemler (hesap silme parçası, Mod C duyuru fan-out parçası, devir) bütçeyi aşmaz.
10. **Storage rules:** tür/boyut, sahiplik, `update/delete` ret.
11. **Parite testleri:** (a) `Limits` ↔ Rules içindeki sayılar; (b) `ALLOWED_EMAIL_DOMAINS` ↔ Rules regex; (c) `RolePolicy` (Dart) ↔ `firebase/test/expectations` (aynı JSON'dan Dart tarafı da beslenir) — Dart ve Rules **aynı yetkiyi** verir.

## 7. Golden politikası (Q-16)

- Konum: `…/test/goldens/<ad>__<tema>[__<dil>].png`; commit edilir. Platform: **Linux CI ile üretilmez**, yerelde macOS üretilir ve kullanıcıya bildirilir (font/AA farkı); eşik `LocalFileComparator` toleransı yok (0), farklılık olursa bilinçli güncellenir.
- Kapsam Q-16 cevabına göre: öneri = **tüm gu_ui widget'ları (açık+koyu) + her ekran 390 × açık × TR (+ koyu) + sheet/dialog/toast**; EN ve tam matris golden değil, taşma testi.
- Güncelleme yalnızca `flutter test --update-goldens <dosya>` ile ve **ilgili referans görüntüyle karşılaştırıldıktan sonra**; kullanıcıya "şu golden'lar bilinçli güncellendi" denir.
- Referans karşılaştırma (D-17 L5) golden'dan **ayrıdır**: `reference-shots` ↔ Flutter çıktısı gözle (`gu-design-fidelity-reviewer`); piksel eşitliği hedeflenmez (font rasterizasyonu), **ölçü/renk/boşluk/metin/ikon/durum** eşitliği hedeflenir.

## 8. Kapsam hedefleri

Satır kapsamı: `gu_data` ≥ 90 %, `gu_ui` ≥ 90 %, `lib/features/*/provider` ≥ 90 %, view'lar ≥ 80 % (davranış testleriyle). Kapsam kapıdadır (`quality_gate.sh` `lcov` özeti; düşüş = uyarı, eşik altı = hata). Üretilen kod (`*.g.dart`) ve `firebase_options.dart` hariç.

## 9. Çalıştırma

```
bash tool/quality_gate.sh --task T-12     # TAM kapı: tam matris + kapsam + Rules + o task'ın tasarım kapsamı (done için şart)
bash tool/quality_gate.sh --fast          # format + analyze + taramalar + hızlı matris (done için geçersiz)
bash tool/quality_gate.sh --static        # testsiz statik kontrol
bash tool/quality_gate.sh --final         # T-47 nihai kapı
(cd firebase && npm test)                 # Rules (emülatör)
flutter test integration_test --dart-define=ENV=emulator   # uçtan uca
```

## 10. Yapılmayacaklar

Gerçek Firebase projesine karşı test yok · ağ erişimi yok · `sleep`/gerçek zaman yok · ekran görüntüsünü elle düzenleme yok · test atlatma (`skip:`, `--no-verify`) yok · kırık testi silmek yok (düzelt ya da kullanıcıya bildir).

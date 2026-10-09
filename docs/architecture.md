# Mimari

> Kilitli kararlar: `docs/decisions.md` (D-xx). Bu doküman onların **uygulama biçimidir**; Claude Code Faz 0 planında bunu **somutlaştırır** (dosya adları, sınıflar) ama **çelişen bir şey üretmez**.
> Soru turu sonucu belirlenecek noktalar `⟦Q-xx⟧` ile işaretlidir.

## 1. Katmanlar

```
┌────────────────────────── uygulama (lib/) ──────────────────────────┐
│  features/<f>/view  ──watch/read──▶  features/<f>/provider (VM+State) │
│          │                                   │                        │
│          ▼                                   ▼                        │
│  product/widget (alan-bilen)         product/feedback (SHT/DLG/TST)   │
│          │                                   │                        │
└──────────┼───────────────────────────────────┼────────────────────────┘
           ▼                                   ▼
   packages/gu_ui  (saf UI)            packages/gu_data
   token · tema · GuIcon               modeller · FirebaseResult
   çekirdek widget · overlay           repository (arayüz + impl)
   çerçeveleri · extension             servis (Firestore/Storage/Auth/…)
                                       soft delete · sabitler
                                              │
                                              ▼
                                       Firebase SDK / Emulator
```

Kurallar CLAUDE.md §1'de. Özet: **tek yön**, `gu_ui` ↛ `gu_data`, ViewModel SDK tipi görmez, feature'lar birbirini import etmez.

## 2. Paketler

### `packages/gu_data`
```
lib/gu_data.dart                      # public API (barrel)
lib/src/
  core/        firebase_result.dart · firestore_error.dart · storage_error.dart · soft_delete.dart · app_clock.dart
  constants/   firestore_collections.dart · firestore_fields.dart · limits.dart · role_codes.dart
  models/      user · club · membership · post · comment · poll · event · rsvp · notification · report · activity_log · user_settings · block · support_ticket · place · category · interest · department … (+ enum'lar)
  services/    firestore_service.dart · storage_service.dart · auth_service.dart · messaging_service.dart · remote_config_service.dart · crash_service.dart
  repositories/<alan>_repository.dart (arayüz) + firebase_<alan>_repository.dart (impl)
  utils/       email_domain_validator.dart · ticket_code.dart · retry_policy.dart · json_converters.dart
test/ (modeller, servisler — fake_cloud_firestore ⟦Q-06⟧)
```
- Modeller `json_serializable` + `Equatable`; Firestore `Timestamp` ↔ `DateTime(UTC)` dönüştürücüsü tek yerde (`json_converters.dart`).
- **`SoftDelete` yardımcıları** (`payload`, `affectedKeys`, `restorePayload`) `core/soft_delete.dart`; `docs/soft-delete.md`.
- Repository arayüzleri **alan dilinde** konuşur (`approveApplication(clubId, userId)`), SDK dilinde değil.

### `packages/gu_ui`
```
lib/gu_ui.dart
lib/src/
  tokens/      gu_colors.dart · gu_typography.dart · gu_spacing.dart · gu_radius.dart · gu_shadows.dart · gu_motion.dart · gu_sizes.dart · gu_breakpoints.dart
  theme/       gu_theme.dart (light/dark ThemeData) · gu_theme_extension.dart (context.gu) · gu_system_ui.dart
  icons/       gu_icon.dart · gu_icons.dart (130, assets/icons ile birebir)
  widgets/     primitives/ (button, icon_button, chip, badge, avatar, …) · inputs/ · feedback/ (skeleton, empty/error/offline state, banner) · navigation/ (app_bar, tabs, segmented, bottom_nav) · display/ (card, tile, kpi, progress, chart, calendar, cover, illustration)
  overlay/     gu_sheet_frame.dart · gu_dialog_frame.dart · gu_toast.dart · gu_pop_menu.dart
  extensions/  build_context_x.dart (gu, l10n köprüsü hariç) · num_x.dart
  utils/       gu_key.dart (GuKey.action) · gu_tap_target.dart · text_scale.dart
test/ (token testi, widget testleri, golden)
```
- Metin gerektiren widget'lar metni **parametre** olarak alır (l10n uygulama katmanında) → `gu_ui` ARB'ye bağlı değildir.
- Alan-bağımsız olmayan kompozitler (ClubCard, EventCard, PostCard, MemberRow, ApplicationRow, NotificationRow…) `lib/product/widget/` altında yaşar; `gu_ui` primitifleriyle kurulur. (Faz 1'de her widget için yer kararı `docs/widget-catalog.md`'ye yazılır.)

## 3. Uygulama dizini (`lib/`)

```
lib/
├── main.dart                         # ProviderScope + bootstrap
├── core/
│   ├── bootstrap/app_bootstrap.dart  # WidgetsFlutterBinding, hata yakalayıcılar, Firebase, DI, prefs, Remote Config
│   ├── di/project_dependency.dart · project_dependency_mixin.dart · app_provider_mixin.dart
│   ├── env/app_environment.dart      # ENV=emulator|production (--dart-define), emülatör host'ları
│   ├── error/app_error_handler.dart · app_logger.dart
│   └── session/session_view_model.dart · session_state.dart   # kimlik/rol çözümü (§6)
├── product/
│   ├── navigation/app_router.dart · route_guards.dart · routes/*.dart · shell/app_shell_view.dart
│   ├── feedback/feedback_service.dart · sheet_id.dart · dialog_id.dart · toast_id.dart · catalogs/{sheets,dialogs,toasts}/…
│   ├── widget/ …                     # alan-bilen kompozitler
│   ├── mixin/ …
│   └── init/ …                       # tema/dil/metin ölçeği tercihleri, uygulama başlangıç bayrakları
├── features/
│   ├── system/ (splash, error, offline, not_found)
│   ├── onboarding/   auth/   clubs/   feed/   events/   notifications/
│   ├── profile/   settings/   management/   admin/   search/
│   └── <feature>/{provider|view_model, view/{mixin, widget}}
└── l10n/
```

## 4. Bootstrap

```
main() → runZonedGuarded(() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppErrorHandler.install();                 // FlutterError.onError + PlatformDispatcher.onError + ErrorWidget.builder
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  AppEnvironment.configure();                 // ENV=emulator ise Auth/Firestore/Storage/(Functions) emülatör bağlantısı
  Crashlytics.setCollectionEnabled(!kDebugMode);
  await ProjectDependency.setup();            // GetIt: servisler + repository'ler + FeedbackService
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(overrides: [...], child: const GuApp()));
}, AppErrorHandler.onZoneError);
```
- `GuApp` = `MaterialApp.router` (`theme`, `darkTheme`, `themeMode`, `locale`, `localizationsDelegates`, `routerConfig`, `builder` → metin ölçeği + `GuSystemUi` + çevrimdışı banner + zorunlu güncelleme katmanı).
- **Splash (SYS-01):** ilk karede native splash → `SplashView` (1.2 sn ölçek+solma) → oturum çözümü bitince yönlendirme. Splash süresi **en az** animasyon süresi, **en çok** zaman aşımı (20 sn, sonra SYS-02).

## 5. Ortam (`AppEnvironment`)

- `--dart-define=ENV=emulator|production` (varsayılan: `kDebugMode ? emulator : production` **değil** — açık verilmezse `production` ve debug'da uyarı; yanlışlıkla gerçek projeye yazma riskini azaltmak için emülatör **açıkça** seçilir).
- Emülatör host'ları: Android emülatör `10.0.2.2`, iOS simülatör/masaüstü `localhost`; gerçek cihaz için `--dart-define=EMULATOR_HOST=<LAN-IP>`. Portlar `firebase.json`'dan (Auth 9099, Firestore 8080, Storage 9199, Functions 5001, UI 4000).
- Gerçek proje kimlikleri `firebase_options.dart`'tadır (flutterfire). **Bu dosya zaten repoda olabilir; yeniden üretme.**
- ⟦Q-03⟧ tek proje mi iki proje mi: iki proje seçilirse `--dart-define=ENV=dev|prod` ve iki `firebase_options`.

## 6. Oturum ve rol çözümü

`SessionViewModel` (kök, uygulama ömrü boyunca) şunları üretir:

```
SessionState {
  AuthStatus status;      // unknown | signedOut | unverified | profileIncomplete | active | suspended
  String? uid;
  UserModel? user;
  bool isSuperAdmin;      // ID token claim `superadmin == true`
  Map<String, MembershipModel> memberships;   // kulüp id → üyelik (canlı akış: yalnızca kendi üyelikleri)
  Set<String> blockedUserIds;
}
```
- `ClubRole roleIn(clubId)` ve `ClubAccess accessTo(clubId)` (visitor/pending/rejected/member/manager/advisor) **buradan** türetilir; ekranlar kendi başlarına rol hesaplamaz.
- **Router yönlendirme tablosu** (`redirect`):

| Durum | Hedef |
|---|---|
| `unknown` | SYS-01 (splash) |
| `signedOut`, ilk açılış | ONB-01 → AUT-01 |
| `signedOut` | AUT-01 (+ `/register`, `/reset`, `/legal/:tip` serbest) |
| `unverified` | AUT-03 |
| `profileIncomplete` | AUT-05 |
| `suspended` | AUT-01 + DLG-01 (oturum kapatılır) |
| `active` | istenen rota; `/admin/**` yalnızca `isSuperAdmin`, `/manage/:clubId/**` yalnızca o kulüpte `manager|advisor` (advisor salt okunur) |
- Oturum düşerse (token iptali/`user-token-expired`) DLG-27 → AUT-01. Zorunlu güncelleme (Remote Config `min_supported_build`) DLG-26 (kapatılamaz) kök katmanda.
- İlk girişte (profil tamam) DLG-03 (bildirim ön izni) **bir kez**.

## 7. Bildirimler ve Functions mimarisi ⟦Q-02, Q-07, Q-10⟧

Bildirim türleri ve alıcıları `docs/domain-model.md §6`'dadır. İki çalışma biçimi vardır; kod **ortak arayüz** (`NotificationDispatcher`) arkasındadır:

| | **Mod F — Functions (Blaze)** | **Mod C — yalnızca istemci (Spark)** |
|---|---|---|
| Bildirim dokümanı üretimi | Firestore tetikleyicileri (üyelik/etkinlik/gönderi/rsvp yazımı) | İşlemi yapan istemci batch ile yazar (Rules `notifications` create'i dar koşullarla açar) |
| Push (FCM) | Functions `sendEachForMulticast` (kullanıcı tercihleri + sessiz saatler sunucuda) | **Yok** (uygulama içi liste + açık uygulamada anlık görünürlük); Q-07'ye göre yerel zamanlanmış hatırlatıcı |
| Etkinlik hatırlatıcısı | Zamanlanmış Function (1 gün / 1 saat önce) | `flutter_local_notifications` ile cihazda planlı |
| Bekleme listesi terfisi | Tetikleyici otomatik terfi + `waitlist_promoted` | Yalnızca yönetici elle "Kayıtlıya al" (MGT-06; tasarımda zaten vardır). Otomatik terfi **yok** → `waitlist_promoted` bildirimi yönetici işlemiyle üretilir |
| Duyuru limiti (2/gün) | Rules + sayaç (Q-10 önerisi) veya Functions | Rules + sayaç |
| Hesap silme temizliği | Q-11'e göre | Q-11'e göre |

- `lib/` içinde **iki mod için ayrı kod dalı yok**: `NotificationDispatcher` arayüzü; `ClientFanOutDispatcher` (Mod C) ve `ServerSideDispatcher` (Mod F, istemcide no-op). Q-02 cevabıyla DI'da biri bağlanır.
- Mod F'de `functions/` (TypeScript, Node 20, `firebase-functions` v2) yazılır: `functions/src/{triggers,scheduled,lib}`; her fonksiyon için emülatör testi. **Deploy kullanıcı onayıyla.**
- FCM jetonu `users/{uid}/private/account.fcmTokens[]`; çıkışta jeton alanı `arrayRemove` ile temizlenir (alan silme hard delete değildir).
- Bildirim tercihleri (`settings/{uid}`) ve sessiz saatler: Mod F'de sunucu uygular; Mod C'de istemci yazarken filtrelemez, **okuyan** taraf (liste) filtreler.

## 8. Hata modeli ve kullanıcı geri bildirimi

- Servis katmanı: `FirebaseResult<T, E>` (D-34). ViewModel `isError`'a çevirir.
- Kullanıcıya gösterim eşlemesi: ağ yok → `SYS-03` banner + **TST-24**; zaman aşımı/bilinmeyen → `SYS-02` (ekran içi) veya toast; yetki yok → TST-X18; bulunamadı/silinmiş → `SYS-04`; çakışma (aynı başvuruya iki yönetici) → DLG-18.
- Yazma işlemleri çevrimdışıyken **engellenir** (TST-24) — tasarım kuralı; Firestore'un yerel yazma kuyruğu **kullanıcıya vaat edilmez**.

## 9. Çevrimdışı ⟦Q-12⟧

- Firestore kalıcı önbellek (mobilde varsayılan) açık; okuma önbellekten gelir. Bağlantı durumu `connectivity_plus` + Firestore `snapshotsInSync`/metadata (`isFromCache`) ile; **kalıcı banner** (SYS-03) üstte; bağlantı geri gelince TST-25.
- Tam ekran çevrimdışı (önbellek yok) = SYS-03 tam varyant.

## 10. Depolama (Storage)

> **Plan notu:** Firebase, Eylül 2024'ten beri yeni projelerde Spark planına varsayılan Storage bucket'ı vermez (Blaze gerekir; Blaze'in ücretsiz kotası vardır). Eski `appspot.com` bucket'ı olan projeler etkilenmez. Bu yüzden Q-19 (fotoğraf yükleme) ve Q-02 (Blaze) **birlikte** değerlendirilir. Kaynak: Firebase "Storage changes announced Sept 2024" SSS sayfası.

```
users/{uid}/avatar.jpg                 # sahibi yazar (Q-19)
clubs/{clubId}/logo.jpg · cover.jpg    # yönetici
posts/{postId}/{n}.jpg                 # gönderiyi yazan yönetici (en çok 4)
support/{ticketNo}/{n}.jpg             # ekran görüntüsü
```
- **Dosya silme yok** (D-10): değiştirme = yeni dosya adı + doküman alanı güncelleme; eski dosya yetim kalır (temizliği bir gün sunucu yapar, istemci değil). Storage Rules `allow delete: if false`.
- Yüklemeden önce istemci tarafı yeniden boyutlandırma/sıkıştırma (Q-19), tür/boyut sınırı Rules'ta (görsel ≤ 5 MB, `image/*`).

## 11. Remote Config anahtarları

`min_supported_build` (int), `maintenance_message` (string, boşsa yok), `announcement_daily_limit` (varsayılan 2 — Rules ile uyumlu tutulur; Rules sabit değeri esas alır), `reapply_cooldown_days` (7).
Kodda varsayılan değerler `Limits` sabitlerindedir; Remote Config yalnızca **geçersiz kılar**.

## 12. Gözlemlenebilirlik

- `AppLogger` (debug: konsol; release: Crashlytics `log`). Kullanıcı kimliği Crashlytics'e **uid** olarak (e-posta değil).
- Analytics yok (KVKK; kullanıcı ayrıca isterse sorulur).

## 13. Performans kuralları

- Listeler `ListView.builder`/sliver; sayfalama imleç tabanlı (`limit(20)` + `startAfterDocument`), "Hepsi bu kadar" sonu (`ListEnd`).
- Canlı dinleyici (`snapshots`) yalnızca: oturumun üyelikleri, bildirim listesi/sayacı, açık gönderinin yorumları, açık biletin rsvp durumu, açık yoklama listesi. Diğer her şey tek seferlik `get` + çek-yenile.
- Görseller `cached_network_image` + sabit en-boy oranı (layout kayması yok). Kapak/desen SVG'leri `flutter_svg` ile; ağır SVG'ler (≈55 KB, ~300 daire) ilk çizimde `RepaintBoundary` içinde, listelerde `cacheExtent` ayarıyla.
- Uygulama önyüklemesinde yalnızca zorunlu servisler; Remote Config `fetchAndActivate` arka planda.

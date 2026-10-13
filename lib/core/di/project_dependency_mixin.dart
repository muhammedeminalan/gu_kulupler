import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/connectivity/connectivity_gate.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/service/app_info_service.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';
import 'package:gu_kulupler/product/service/image_picker_service.dart';
import 'package:gu_kulupler/product/service/permission_service.dart';
import 'package:gu_kulupler/product/service/share_service.dart';
import 'package:gu_kulupler/product/service/url_launcher_service.dart';

/// ViewModel'lerin GetIt'teki servis ve repository'lere **tek** erişim yolu
/// (D-04; PLAN §6.1, §12.1). View dosyasında `GetIt.I` yasaktır (HC13).
///
/// Getter'lar tembeldir (her okumada GetIt'e sorar): testte `GetIt.I.reset()`
/// sonrası kaydedilen fake görülür. Her backend task'ı kendi getter'ını ekler.
///
/// **Bilerek olmayan getter'lar** (PLAN §6.1): Firestore, Storage, Remote
/// Config ve çökme raporlama servisleri. Storage yüklemesi repository
/// metodudur; Remote Config yalnızca `AppGateViewModel` kurucusuna verilir;
/// çökme raporlama yalnızca `lib/core/error/` içindedir. Bildirim dağıtıcısı
/// (`NotificationDispatcher`) repository'lerin kurucusuna verilir; ViewModel
/// onu çağırmaz.
mixin ProjectDependencyMixin {
  /// Kimlik doğrulama servisi (ham). Kimlik işlemleri [authRepository]
  /// üzerinden yapılır; servis yalnızca oturum kimliğini okumak içindir.
  AuthService get authService => GetIt.I<AuthService>();

  // ── Repository'ler (her backend task'ı kendisininkini ekler) ─────────

  /// Kimlik işlemleri: kayıt, giriş, doğrulama, şifre, oturum akışı (T-12).
  AuthRepository get authRepository => GetIt.I<AuthRepository>();

  /// Kullanıcı profili ve gizli hesap belgesi (T-12).
  UserRepository get userRepository => GetIt.I<UserRepository>();

  /// Bildirim ayarları (T-12).
  SettingsRepository get settingsRepository => GetIt.I<SettingsRepository>();

  /// Kulüp okuma yüzeyi: liste, tekil ve toplu okuma (T-15).
  ClubRepository get clubRepository => GetIt.I<ClubRepository>();

  /// Üyelik ve başvurular: başvur, katıl, iptal, ayrıl, listeler (T-15).
  MembershipRepository get membershipRepository =>
      GetIt.I<MembershipRepository>();

  /// Şikayet oluşturma ve "zaten bildirildi" denetimi (T-15).
  ReportRepository get reportRepository => GetIt.I<ReportRepository>();

  /// Engellenen kullanıcılar (T-15).
  BlockRepository get blockRepository => GetIt.I<BlockRepository>();

  /// Kulüp günlüğü (MGT-10; T-15).
  ActivityRepository get activityRepository => GetIt.I<ActivityRepository>();

  // ── Uygulama servisleri ──────────────────────────────────────────────

  /// Sheet / dialog / toast tek girişi.
  FeedbackService get feedback => GetIt.I<FeedbackService>();

  /// Saat ve Istanbul günü (`DateTime.now()` doğrudan çağrılmaz).
  AppClock get appClock => GetIt.I<AppClock>();

  /// Çevrimdışı yazma kapısı (`WriteGuardMixin` üzerinden kullanılır).
  ConnectivityGate get connectivityGate => GetIt.I<ConnectivityGate>();

  /// Cihazda saklanan tercihler ve ilk açılış bayrakları.
  AppPreferencesStore get appPreferencesStore => GetIt.I<AppPreferencesStore>();

  // ── Cihaz servisleri (CD-08) ─────────────────────────────────────────

  /// Ağ bağlantısı durumu.
  ConnectivityService get connectivityService => GetIt.I<ConnectivityService>();

  /// Kurulu uygulamanın sürüm / derleme bilgisi.
  AppInfoService get appInfoService => GetIt.I<AppInfoService>();

  /// Dış bağlantılar: `mailto:`, web, mağaza (T-13). Kullanıcının dokunduğu
  /// bağlantılar doğrudan değil `ExternalLinkMixin.openExternalLink` ile
  /// (DLG-32 onayı) açılır.
  UrlLauncherService get urlLauncherService => GetIt.I<UrlLauncherService>();

  /// Sistem paylaşım sayfası — bağlantı (SHT-15), dosya (SHT-14) — ve
  /// panoya kopyalama (TST-08, TST-35) (T-16).
  ShareService get shareService => GetIt.I<ShareService>();

  /// Kamera / bildirim izni ve "Ayarlara git" (T-14). İzin ön açıklamaları
  /// (DLG-03, DLG-04, DLG-05) için `PermissionPromptMixin` kullanılır.
  PermissionService get permissionService => GetIt.I<PermissionService>();

  /// Kamera / galeriden görsel seçimi (T-14). Ekranlar doğrudan değil
  /// `PermissionPromptMixin.pickImage` üzerinden çağırır.
  ImagePickerService get imagePickerService => GetIt.I<ImagePickerService>();
}

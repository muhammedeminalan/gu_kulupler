import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/connectivity/connectivity_gate.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/service/app_info_service.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';

/// ViewModel'lerin GetIt'teki servis ve repository'lere **tek** erişim yolu
/// (D-04; PLAN §6.1, §12.1). View dosyasında `GetIt.I` yasaktır (HC13).
///
/// Getter'lar tembeldir (her okumada GetIt'e sorar): testte `GetIt.I.reset()`
/// sonrası kaydedilen fake görülür. Her backend task'ı kendi getter'ını ekler.
///
/// **Bilerek olmayan getter'lar** (PLAN §6.1): Firestore, Storage, Remote
/// Config ve çökme raporlama servisleri. Storage yüklemesi repository
/// metodudur; Remote Config yalnızca `AppGateViewModel` kurucusuna verilir;
/// çökme raporlama yalnızca `lib/core/error/` içindedir.
mixin ProjectDependencyMixin {
  /// Kimlik doğrulama servisi.
  AuthService get authService => GetIt.I<AuthService>();

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
}

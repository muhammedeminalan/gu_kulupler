import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_kulupler/core/di/project_dependency.dart';
import 'package:gu_kulupler/core/env/app_environment.dart';
import 'package:gu_kulupler/core/error/app_error_handler.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/firebase_options.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Uygulamanın açılış sırası (architecture §4, PLAN §4.4).
///
/// `main()` bunu `runZonedGuarded` içinde çağırır
/// (`AppErrorHandler.onZoneError` ile); bağlama ve `runApp` aynı bölgede
/// çalışmalıdır.
abstract final class AppBootstrap {
  /// Açılış adımlarını **bu sırayla** çalıştırır:
  ///
  /// 1. `WidgetsFlutterBinding.ensureInitialized`
  /// 2. `AppErrorHandler.install` (hata yakalayıcılar + `ErrorWidget.builder`)
  /// 3. Dikey yön kilidi (`SystemChrome.setPreferredOrientations`, Q-13;
  ///    platform dosyalarındaki kilidin çalışma zamanı eşi)
  /// 4. `Firebase.initializeApp` (varsayılan uygulama)
  /// 5. `AppEnvironment.configure` (emülatör bağlaması; hatası yutulmaz —
  ///    yarım kurulumla devam edilmez)
  /// 6. `initializeDateFormatting` (`tr_TR`, `en_GB` — CD-56)
  /// 7. Crashlytics toplama anahtarı
  /// 8. `ProjectDependency.setup` (GetIt kayıtları)
  /// 9. `AppPreferencesStore.load` (tema / dil ilk karede hazır)
  /// 10. `runApp(ProviderScope(…))`
  ///
  /// [appBuilder] kök widget'ı verir ve `GuToastHost` için toast
  /// denetleyicisini alır. Overlay'lerin itildiği kök gezgin router'ınkidir
  /// (`rootNavigatorKey`; `ProjectDependency.setup` bağlar).
  static Future<void> run({
    required Widget Function(GuToastController toastController) appBuilder,
  }) async {
    WidgetsFlutterBinding.ensureInitialized();
    AppErrorHandler.install();
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await AppEnvironment.configure();
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_GB');
    await configureCrashlytics();
    final toastController = GuToastController();
    await ProjectDependency.setup(toastController: toastController);
    await GetIt.I<AppPreferencesStore>().load();
    runApp(ProviderScope(child: appBuilder(toastController)));
  }

  /// Crashlytics toplamayı yalnızca **üretim ortamının release olmayan-debug
  /// dışı** derlemelerinde açar ([crashCollectionEnabled]).
  ///
  /// Yerel SDK varsayılan (gerçek) Firebase uygulamasıyla kendiliğinden
  /// başlar; emülatör ortamında ve debug derlemede toplama **kapatılır** ki
  /// geliştirme oturumlarının çökmeleri gerçek projeye gitmesin (W-53). Çağrı
  /// yereldir (ağ isteği yapmaz). Hatası açılışı durdurmaz.
  ///
  /// Yerel SDK bu çağrıdan **önce** açıldığı için otomatik toplama platform
  /// dosyalarında kapalı başlar (Android debug manifest
  /// `firebase_crashlytics_collection_enabled`, iOS `Info.plist`
  /// `FirebaseCrashlyticsCollectionEnabled`): toplamayı yalnızca bu çağrı
  /// açar. iOS'ta plist tüm yapılandırmalar için ortaktır; release derlemede
  /// toplama bu çağrının yazdığı `true` ile açılır (değer cihazda kalıcıdır).
  @visibleForTesting
  static Future<void> configureCrashlytics({
    Future<void> Function({required bool enabled})? apply,
    bool enabled = crashCollectionEnabled,
  }) async {
    try {
      await (apply ?? _applyCrashCollection)(enabled: enabled);
    } on Object catch (error, stack) {
      AppLogger.warn(
        'Crashlytics toplama ayarı yazılamadı',
        error: error,
        stackTrace: stack,
      );
    }
  }

  /// Çökme raporu toplansın mı: debug derlemede ve emülatör ortamında hayır.
  static const bool crashCollectionEnabled =
      !kDebugMode && !AppEnvironment.isEmulator;

  static Future<void> _applyCrashCollection({required bool enabled}) =>
      FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(enabled);
}

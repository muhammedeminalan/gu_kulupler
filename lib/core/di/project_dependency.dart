import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/connectivity/connectivity_gate.dart';
import 'package:gu_kulupler/core/env/app_environment.dart';
import 'package:gu_kulupler/core/env/emulator_services.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/navigation/navigator_keys.dart';
import 'package:gu_kulupler/product/service/app_info_service.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';
import 'package:gu_ui/gu_ui.dart';

/// [ProjectDependency.setup]'ın gerçek uygulama yerine kullanacağı örnekler.
///
/// Verilmeyen her servis gerçek uygulamasıyla kurulur. Yalnızca testte ve
/// platform kanalı olmayan ortamlarda doldurulur.
final class ProjectDependencyOverrides {
  /// Hiçbir şeyi değiştirmeyen boş küme.
  const ProjectDependencyOverrides({
    this.authService,
    this.firestoreService,
    this.storageService,
    this.remoteConfigService,
    this.crashService,
    this.appClock,
    this.connectivityService,
    this.appInfoService,
    this.appPreferencesStore,
  });

  /// `AuthService` yerine.
  final AuthService? authService;

  /// `FirestoreService` yerine.
  final FirestoreService? firestoreService;

  /// `StorageService` yerine.
  final StorageService? storageService;

  /// `RemoteConfigService` yerine.
  final RemoteConfigService? remoteConfigService;

  /// `CrashService` yerine.
  final CrashService? crashService;

  /// `AppClock` yerine.
  final AppClock? appClock;

  /// `ConnectivityService` yerine.
  final ConnectivityService? connectivityService;

  /// `AppInfoService` yerine.
  final AppInfoService? appInfoService;

  /// `AppPreferencesStore` yerine.
  final AppPreferencesStore? appPreferencesStore;
}

/// GetIt kayıtları — kompozisyon kökü (D-04; PLAN §4.4, §6.2).
///
/// Bu dosya ve `project_dependency_mixin.dart` dışında servis/repository
/// örneği **kurulmaz**. ViewModel'ler `ProjectDependencyMixin` getter'larını,
/// view'lar Riverpod sağlayıcılarını kullanır.
///
/// - Auth / Firestore / Storage örnekleri yalnızca `AppEnvironment.auth` /
///   `.firestore` / `.storage` üzerinden alınır (emülatörde ikinci Firebase
///   uygulaması — CD-131). `AppEnvironment.configure()` tamamlanmadıysa
///   [setup] `StateError` ile durur; hata yakalanıp devam edilmez.
/// - **Emülatörde Remote Config ve çökme raporlama gerçek projeye gitmez**
///   (W-53): ikisinin emülatörü yoktur ve SDK'ları varsayılan (gerçek)
///   Firebase uygulamasını kullanır. `ENV=emulator` iken yerel uygulamalar
///   kaydedilir ([EmulatorRemoteConfigService], [EmulatorCrashService]).
abstract final class ProjectDependency {
  /// Tüm servisleri kaydeder. `Firebase.initializeApp` ve
  /// `AppEnvironment.configure()` sonrasında, `runApp` öncesinde bir kez
  /// çağrılır.
  ///
  /// [toastController] kök ağaçtaki `GuToastHost` ile paylaşılır. Overlay'ler
  /// (sheet / dialog / menü) router'ın kök gezginine (`rootNavigatorKey`)
  /// itilir: alt sekme çubuğunun üstünde dururlar ve geri tuşu önce onları
  /// kapatır. [navigatorKey], [isEmulator] ve [overrides] yalnızca testte
  /// verilir.
  static Future<void> setup({
    required GuToastController toastController,
    GlobalKey<NavigatorState>? navigatorKey,
    bool isEmulator = AppEnvironment.isEmulator,
    ProjectDependencyOverrides overrides = const ProjectDependencyOverrides(),
  }) async {
    // Önce tüm örnekler kurulur, sonra kaydedilir: kurulum yarıda kesilirse
    // (ör. ortam kurulmadan çağrı) GetIt yarım kayıtla kalmaz.
    final crashService =
        overrides.crashService ??
        (isEmulator
            ? const EmulatorCrashService()
            : FirebaseCrashService(FirebaseCrashlytics.instance));
    final remoteConfigService =
        overrides.remoteConfigService ??
        (isEmulator
            ? const EmulatorRemoteConfigService()
            : FirebaseRemoteConfigService(FirebaseRemoteConfig.instance));
    // Firebase servisleri: örnekler yalnızca AppEnvironment üzerinden.
    final authService =
        overrides.authService ?? FirebaseAuthService(AppEnvironment.auth);
    final firestoreService =
        overrides.firestoreService ??
        FirebaseFirestoreService(AppEnvironment.firestore);
    final storageService =
        overrides.storageService ??
        FirebaseStorageService(AppEnvironment.storage);
    // Cihaz servisleri (CD-08).
    final connectivityService =
        overrides.connectivityService ?? await _startConnectivity();
    final appInfoService =
        overrides.appInfoService ?? await PackageAppInfoService.load();

    GetIt.I
      // Çökme raporlama ilk kayıttır: sonraki adımların günlüğü ona düşer.
      ..registerSingleton<CrashService>(crashService)
      ..registerSingleton<RemoteConfigService>(remoteConfigService)
      ..registerSingleton<AppClock>(
        overrides.appClock ?? const SystemAppClock(),
      )
      ..registerSingleton<AuthService>(authService)
      ..registerSingleton<FirestoreService>(firestoreService)
      ..registerSingleton<StorageService>(storageService)
      // Geri bildirim: router'ın kök gezgini + GuToastHost denetleyicisi
      // (CD-128).
      ..registerSingleton<GuToastController>(toastController)
      ..registerSingleton<FeedbackService>(
        AppFeedbackService(
          navigatorKey: navigatorKey ?? rootNavigatorKey,
          toastController: toastController,
        ),
      )
      ..registerSingleton<ConnectivityService>(connectivityService)
      ..registerSingleton<ConnectivityGate>(
        ConnectivityGate(connectivityService),
      )
      ..registerSingleton<AppInfoService>(appInfoService)
      // Depo burada yalnızca kaydedilir; `AppBootstrap` `load()` çağırır.
      ..registerSingleton<AppPreferencesStore>(
        overrides.appPreferencesStore ?? SharedAppPreferencesStore(),
      );
  }

  /// Tüm kayıtları siler (test ve yeniden kurulum).
  static Future<void> reset() => GetIt.I.reset();

  static Future<ConnectivityService> _startConnectivity() async {
    final service = DeviceConnectivityService();
    await service.start();
    return service;
  }
}

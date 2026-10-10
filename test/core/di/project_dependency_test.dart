// T-11 · ProjectDependency: GetIt kayıtları, emülatörde yerel Remote Config /
// çökme servisleri (W-53), reset (D-04; PLAN §4.4).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/connectivity/connectivity_gate.dart';
import 'package:gu_kulupler/core/di/project_dependency.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/env/app_environment.dart';
import 'package:gu_kulupler/core/env/emulator_services.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/navigation/navigator_keys.dart';
import 'package:gu_kulupler/product/service/app_info_service.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../fakes/fake_app_info_service.dart';
import '../../fakes/fake_app_preferences_store.dart';
import '../../fakes/fake_auth_service.dart';
import '../../fakes/fake_connectivity_service.dart';
import '../../fakes/fake_crash_service.dart';
import '../../fakes/fake_firestore_service.dart';
import '../../fakes/fake_remote_config_service.dart';
import '../../fakes/fake_storage_service.dart';
import '../../helpers/design_files.dart';
import '../../helpers/fake_app_clock.dart';

final class _Consumer with ProjectDependencyMixin {}

void main() {
  late GlobalKey<NavigatorState> navigatorKey;
  late GuToastController toastController;
  late FakeAuthService auth;
  late FakeFirestoreService firestore;
  late FakeStorageService storage;
  late FakeConnectivityService connectivity;
  late FakeAppInfoService appInfo;
  late FakeAppPreferencesStore prefs;

  /// Platform kanalı ve Firebase uygulaması isteyen her şey fake'tir; Remote
  /// Config ve çökme servisi **verilmez** (ortam seçimi sınanır).
  ProjectDependencyOverrides platformFakes({
    RemoteConfigService? remoteConfigService,
    CrashService? crashService,
    AppClock? appClock,
  }) => ProjectDependencyOverrides(
    authService: auth,
    firestoreService: firestore,
    storageService: storage,
    connectivityService: connectivity,
    appInfoService: appInfo,
    appPreferencesStore: prefs,
    remoteConfigService: remoteConfigService,
    crashService: crashService,
    appClock: appClock,
  );

  setUp(() async {
    await GetIt.I.reset();
    addTearDown(GetIt.I.reset);
    navigatorKey = GlobalKey<NavigatorState>();
    toastController = GuToastController();
    addTearDown(toastController.dispose);
    auth = FakeAuthService();
    firestore = FakeFirestoreService();
    storage = FakeStorageService();
    connectivity = FakeConnectivityService();
    appInfo = FakeAppInfoService();
    prefs = FakeAppPreferencesStore(loaded: false);
  });

  group('T-11 · ProjectDependency.setup', () {
    test('tüm servisleri kaydeder', () async {
      await ProjectDependency.setup(
        navigatorKey: navigatorKey,
        toastController: toastController,
        isEmulator: true,
        overrides: platformFakes(),
      );

      expect(GetIt.I<AuthService>(), same(auth));
      expect(GetIt.I<FirestoreService>(), same(firestore));
      expect(GetIt.I<StorageService>(), same(storage));
      expect(GetIt.I<RemoteConfigService>(), isA<RemoteConfigService>());
      expect(GetIt.I<CrashService>(), isA<CrashService>());
      expect(GetIt.I<AppClock>(), isA<SystemAppClock>());
      expect(GetIt.I<GuToastController>(), same(toastController));
      expect(GetIt.I<FeedbackService>(), isA<AppFeedbackService>());
      expect(GetIt.I<ConnectivityService>(), same(connectivity));
      expect(GetIt.I<ConnectivityGate>(), isA<ConnectivityGate>());
      expect(GetIt.I<AppInfoService>(), same(appInfo));
      expect(GetIt.I<AppPreferencesStore>(), same(prefs));
    });

    test('FeedbackService verilen kök gezgine ve toast denetleyicisine '
        'bağlanır (CD-128)', () async {
      await ProjectDependency.setup(
        navigatorKey: navigatorKey,
        toastController: toastController,
        isEmulator: true,
        overrides: platformFakes(),
      );
      final feedback = GetIt.I<FeedbackService>() as AppFeedbackService;
      expect(feedback.navigatorKey, same(navigatorKey));
      expect(feedback.toastController, same(toastController));
    });

    test('gezgin verilmezse FeedbackService router’ın kök gezginine '
        '(rootNavigatorKey) bağlanır', () async {
      await ProjectDependency.setup(
        toastController: toastController,
        isEmulator: true,
        overrides: platformFakes(),
      );
      final feedback = GetIt.I<FeedbackService>() as AppFeedbackService;
      expect(feedback.navigatorKey, same(rootNavigatorKey));
    });

    test("ConnectivityGate kayıtlı ConnectivityService'i okur", () async {
      await ProjectDependency.setup(
        navigatorKey: navigatorKey,
        toastController: toastController,
        isEmulator: true,
        overrides: platformFakes(),
      );
      final gate = GetIt.I<ConnectivityGate>();
      expect(gate.requireOnline().isSuccess, isTrue);
      connectivity.isOffline = true;
      expect(gate.requireOnline().errorOrNull, FirestoreError.offline);
    });

    test(
      'tercih deposu yalnızca kaydedilir; yüklemeyi açılış sırası yapar',
      () async {
        await ProjectDependency.setup(
          navigatorKey: navigatorKey,
          toastController: toastController,
          isEmulator: true,
          overrides: platformFakes(),
        );
        expect(prefs.callsTo('load'), isEmpty);
        expect(GetIt.I<AppPreferencesStore>().isLoaded, isFalse);
      },
    );

    test(
      "ProjectDependencyMixin getter'ları kayıtlı örnekleri döndürür",
      () async {
        final clock = FakeAppClock(DateTime.utc(2026, 10, 12));
        await ProjectDependency.setup(
          navigatorKey: navigatorKey,
          toastController: toastController,
          isEmulator: true,
          overrides: platformFakes(appClock: clock),
        );
        final consumer = _Consumer();
        expect(consumer.authService, same(auth));
        expect(consumer.feedback, same(GetIt.I<FeedbackService>()));
        expect(consumer.appClock, same(clock));
        expect(consumer.connectivityGate, same(GetIt.I<ConnectivityGate>()));
        expect(consumer.appPreferencesStore, same(prefs));
        expect(consumer.connectivityService, same(connectivity));
        expect(consumer.appInfoService, same(appInfo));
      },
    );

    test('ikinci setup (reset olmadan) hatadır: çift kayıt sessizce '
        'geçmez', () async {
      await ProjectDependency.setup(
        navigatorKey: navigatorKey,
        toastController: toastController,
        isEmulator: true,
        overrides: platformFakes(),
      );
      await expectLater(
        ProjectDependency.setup(
          navigatorKey: navigatorKey,
          toastController: toastController,
          isEmulator: true,
          overrides: platformFakes(),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('T-11 · ProjectDependency · emülatör ortamı (W-53)', () {
    test('emülatörde Remote Config ve çökme servisi yereldir: Firebase '
        "SDK'sına dokunulmaz", () async {
      // Testte Firebase uygulaması yoktur: SDK örneği istenseydi setup
      // fırlatırdı.
      await ProjectDependency.setup(
        navigatorKey: navigatorKey,
        toastController: toastController,
        isEmulator: true,
        overrides: platformFakes(),
      );
      expect(
        GetIt.I<RemoteConfigService>(),
        isA<EmulatorRemoteConfigService>(),
      );
      expect(GetIt.I<CrashService>(), isA<EmulatorCrashService>());
    });

    test(
      'üretim ortamında gerçek SDK istenir (testte Firebase uygulaması '
      'olmadığından kurulum durur — sessizce yerel servise düşmez)',
      () async {
        await expectLater(
          ProjectDependency.setup(
            navigatorKey: navigatorKey,
            toastController: toastController,
            // Varsayılan derleme sabitidir (emülatör derlemesinde true);
            // test ortamdan bağımsız kalsın diye açık verilir.
            // ignore: avoid_redundant_argument_values
            isEmulator: false,
            overrides: platformFakes(),
          ),
          throwsA(anything),
        );
        expect(GetIt.I.isRegistered<RemoteConfigService>(), isFalse);
        expect(GetIt.I.isRegistered<CrashService>(), isFalse);
      },
    );

    test('verilen servisler ortamdan bağımsız olarak kullanılır', () async {
      final config = FakeRemoteConfigService();
      final crash = FakeCrashService();
      await ProjectDependency.setup(
        navigatorKey: navigatorKey,
        toastController: toastController,
        // Varsayılan derleme sabitidir; ortamdan bağımsız kalsın diye açık.
        // ignore: avoid_redundant_argument_values
        isEmulator: false,
        overrides: platformFakes(
          remoteConfigService: config,
          crashService: crash,
        ),
      );
      expect(GetIt.I<RemoteConfigService>(), same(config));
      expect(GetIt.I<CrashService>(), same(crash));
    });

    test('varsayılan ortam bayrağı derleme sabitidir; test koşusunda '
        'emülatör değildir', () {
      expect(AppEnvironment.isEmulator, isFalse);
    });

    test(
      'Auth / Firestore / Storage örnekleri yalnızca AppEnvironment '
      'üzerinden alınır; kurulmamış ortamda setup StateError ile durur',
      () async {
        final source = readText('lib/core/di/project_dependency.dart');
        expect(source, contains('FirebaseAuthService(AppEnvironment.auth)'));
        expect(
          source,
          contains('FirebaseFirestoreService(AppEnvironment.firestore)'),
        );
        expect(
          source,
          contains('FirebaseStorageService(AppEnvironment.storage)'),
        );

        // Ortam kurulmadı (configure çağrılmadı) → gerçek uygulamaya düşmez.
        await expectLater(
          ProjectDependency.setup(
            navigatorKey: navigatorKey,
            toastController: toastController,
            isEmulator: true,
            overrides: ProjectDependencyOverrides(
              connectivityService: connectivity,
              appInfoService: appInfo,
              appPreferencesStore: prefs,
            ),
          ),
          throwsStateError,
        );
        // Yarım kayıt kalmaz.
        expect(GetIt.I.isRegistered<CrashService>(), isFalse);
        expect(GetIt.I.isRegistered<ConnectivityService>(), isFalse);
      },
    );
  });

  group('T-11 · ProjectDependency.reset', () {
    test('tüm kayıtları siler; ardından yeniden kurulabilir', () async {
      await ProjectDependency.setup(
        navigatorKey: navigatorKey,
        toastController: toastController,
        isEmulator: true,
        overrides: platformFakes(),
      );
      await ProjectDependency.reset();

      expect(GetIt.I.isRegistered<AuthService>(), isFalse);
      expect(GetIt.I.isRegistered<FeedbackService>(), isFalse);
      expect(GetIt.I.isRegistered<ConnectivityGate>(), isFalse);
      expect(GetIt.I.isRegistered<AppPreferencesStore>(), isFalse);
      expect(() => _Consumer().authService, throwsStateError);

      await ProjectDependency.setup(
        navigatorKey: navigatorKey,
        toastController: toastController,
        isEmulator: true,
        overrides: platformFakes(),
      );
      expect(GetIt.I<AuthService>(), same(auth));
    });
  });
}

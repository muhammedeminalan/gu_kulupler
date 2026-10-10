// Varsayılan fake kayıtları (CLAUDE.md §3, PLAN §16.2/§16.3).
//
// `pumpApp` her çağrıda `GetIt.I.reset()` sonrası bunu çağırır. Her fake
// kendi task'ında (T-10 servisler, T-12+ repository'ler) buraya bir satır
// ekler, ör.
//   GetIt.I.registerSingleton<AuthService>(FakeAuthService());
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/connectivity/connectivity_gate.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/service/app_info_service.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';

import '../helpers/fake_app_clock.dart';
import 'fake_app_info_service.dart';
import 'fake_app_preferences_store.dart';
import 'fake_auth_service.dart';
import 'fake_connectivity_service.dart';
import 'fake_crash_service.dart';
import 'fake_feedback_service.dart';
import 'fake_firestore_service.dart';
import 'fake_remote_config_service.dart';
import 'fake_storage_service.dart';

/// Varsayılan [FakeAppClock] anı: 12 Ekim 2026 Pazartesi 19:30 Istanbul
/// (PLAN §14.7 örnek anı).
final DateTime kDefaultFakeNowUtc = DateTime.utc(2026, 10, 12, 16, 30);

/// Varsayılan fake'leri `GetIt.I`'ye kaydeder. `ConnectivityGate` gerçek
/// sınıftır ve kayıtlı `FakeConnectivityService`'i okur.
void registerDefaultFakes() {
  final connectivity = FakeConnectivityService();
  GetIt.I
    ..registerSingleton<FeedbackService>(FakeFeedbackService())
    // T-10 · Firebase servisleri
    ..registerSingleton<AuthService>(FakeAuthService())
    ..registerSingleton<FirestoreService>(FakeFirestoreService())
    ..registerSingleton<StorageService>(FakeStorageService())
    ..registerSingleton<RemoteConfigService>(FakeRemoteConfigService())
    ..registerSingleton<CrashService>(FakeCrashService())
    // T-11 · saat, cihaz servisleri, tercihler, çevrimdışı kapısı
    ..registerSingleton<AppClock>(FakeAppClock(kDefaultFakeNowUtc))
    ..registerSingleton<ConnectivityService>(connectivity)
    ..registerSingleton<ConnectivityGate>(ConnectivityGate(connectivity))
    ..registerSingleton<AppInfoService>(FakeAppInfoService())
    ..registerSingleton<AppPreferencesStore>(FakeAppPreferencesStore());
}

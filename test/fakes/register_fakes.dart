// Varsayılan fake kayıtları (CLAUDE.md §3, PLAN §16.2/§16.3).
//
// `pumpApp` her çağrıda `GetIt.I.reset()` sonrası bunu çağırır. Her fake
// kendi task'ında (T-10 servisler, T-12+ repository'ler) buraya bir satır
// ekler, ör.
//   GetIt.I.registerSingleton<AuthService>(FakeAuthService());
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';

import 'fake_auth_service.dart';
import 'fake_crash_service.dart';
import 'fake_feedback_service.dart';
import 'fake_firestore_service.dart';
import 'fake_remote_config_service.dart';
import 'fake_storage_service.dart';

/// Varsayılan fake'leri `GetIt.I`'ye kaydeder.
void registerDefaultFakes() {
  GetIt.I
    ..registerSingleton<FeedbackService>(FakeFeedbackService())
    // T-10 · Firebase servisleri
    ..registerSingleton<AuthService>(FakeAuthService())
    ..registerSingleton<FirestoreService>(FakeFirestoreService())
    ..registerSingleton<StorageService>(FakeStorageService())
    ..registerSingleton<RemoteConfigService>(FakeRemoteConfigService())
    ..registerSingleton<CrashService>(FakeCrashService());
}

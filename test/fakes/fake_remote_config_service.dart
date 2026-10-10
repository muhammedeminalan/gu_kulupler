// `RemoteConfigService` fake'i (PLAN §16.3): değerler [values] haritasından
// okunur; anahtar yoksa gerçek servisle aynı kod içi varsayılan döner.
//
//   final config = FakeRemoteConfigService()
//     ..values[RemoteConfigKeys.minSupportedBuild] = 42;
//   config.configUpdatedController.add(null);
import 'dart:async';

import 'package:gu_data/gu_data.dart';

import 'fake_base.dart';

final class FakeRemoteConfigService extends FakeBase
    implements RemoteConfigService {
  /// Uzaktan değerler (`RemoteConfigKeys` anahtarı → `int` / `String`).
  /// Eksik ya da yanlış tipte değer varsayılana düşer.
  final Map<String, Object> values = <String, Object>{};

  /// [onConfigUpdated] akışının denetleyicisi.
  final StreamController<void> configUpdatedController =
      StreamController<void>.broadcast();

  /// [fetchAndActivate] başarı değeri (değerler değişti mi).
  bool activated = true;

  @override
  Future<RemoteConfigResult<bool>> fetchAndActivate() async {
    record('fetchAndActivate');
    if (takeFailure() case final error?) {
      return FirebaseFailure(
        error is RemoteConfigError ? error : RemoteConfigError.unknown,
      );
    }
    return FirebaseSuccess(activated);
  }

  @override
  int get minSupportedBuild => _int(RemoteConfigKeys.minSupportedBuild, 0);

  @override
  String get maintenanceMessage =>
      switch (values[RemoteConfigKeys.maintenanceMessage]) {
        final String text => text,
        _ => '',
      };

  @override
  int get announcementDailyLimit => _int(
    RemoteConfigKeys.announcementDailyLimit,
    Limits.announcementDailyLimit,
  );

  @override
  int get reapplyCooldownDays =>
      _int(RemoteConfigKeys.reapplyCooldownDays, Limits.reapplyCooldown.inDays);

  @override
  Stream<void> get onConfigUpdated => configUpdatedController.stream;

  int _int(String key, int fallback) => switch (values[key]) {
    final int value => value,
    _ => fallback,
  };
}

// `CrashService` fake'i (PLAN §16.3): raporları ve günlük satırlarını bellekte
// tutar; gerçek servis gibi hiçbir metodu fırlatmaz.
//
//   final crash = FakeCrashService();
//   await handler.onZoneError(error, stack);
//   expect(crash.recorded.single.$1, error);
import 'package:gu_data/gu_data.dart';

import 'fake_base.dart';

final class FakeCrashService extends FakeBase implements CrashService {
  /// Raporlanan hatalar (hata, yığın), geliş sırasıyla.
  final List<(Object error, StackTrace? stack)> recorded =
      <(Object, StackTrace?)>[];

  /// [recorded] ile aynı sırada `fatal` bayrakları.
  final List<bool> fatals = <bool>[];

  /// [recorded] ile aynı sırada bağlam notları.
  final List<String?> reasons = <String?>[];

  /// Yazılan günlük satırları.
  final List<String> logs = <String>[];

  /// Son [setUserId] değeri (`null` = temizlendi / hiç verilmedi).
  String? userId;

  /// Son [setCollectionEnabled] değeri; hiç çağrılmadıysa `null`.
  bool? collectionEnabled;

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? reason,
  }) async {
    record('recordError', [error, stack, fatal, reason]);
    recorded.add((error, stack));
    fatals.add(fatal);
    reasons.add(reason);
  }

  @override
  void log(String message) {
    record('log', [message]);
    logs.add(message);
  }

  @override
  Future<void> setUserId(String? uid) async {
    record('setUserId', [uid]);
    userId = uid;
  }

  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    record('setCollectionEnabled', [enabled]);
    collectionEnabled = enabled;
  }
}

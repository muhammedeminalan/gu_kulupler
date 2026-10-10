// Araç öz-testi fixture'ı (tool/test/check_rules_parity.test.js): Limits'in küçük bir kopyası.
abstract final class Limits {
  /// Yorumdaki sayı okunmaz: static const int ghost = 999;
  static const int nameMin = 2;
  static const int nameMax = 60;
  static const int supportAttachmentsMax = 1;
  static const int postTextMax = 1000;
  static const int imageMaxBytes = 5 * 1024 * 1024;
  static const int notificationFanOutChunkSize = 50;
  static const int accountDeletionChunk = 5;
  static const Duration reapplyCooldown = Duration(days: 7);
  static const Duration clockSkewTolerance = Duration(minutes: 5);
  static const Duration managerUndoWindow = Duration(seconds: 30);
  static const List<int> pollDurationsDays = [1, 3, 7];
  static const String instagramHandlePattern = r'^@?[A-Za-z0-9._]{1,30}$';
  static const String timeOfDayPattern = r'^([01]\d|2[0-3]):[0-5]\d$';
}

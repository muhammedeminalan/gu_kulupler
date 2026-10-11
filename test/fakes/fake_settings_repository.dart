// `SettingsRepository` fake'i (PLAN §16.3): bildirim ayarlarını bellekte
// tutar.
//
//   final settings = FakeSettingsRepository();
//   await settings.getSettings('u1');                 // varsayılanı yazar
//   settings.failNext(FirestoreError.unavailable);
//   expect(settings.patches.single.patch.quiet, isTrue);
//
// Gerçek repository gibi: `getSettings` belge yoksa varsayılanı **yazar** ve
// döndürür; boş yama ve geçersiz kimlik `invalidArgument`, belgesi olmayan
// ayarın güncellenmesi `notFound`.
import 'package:gu_data/gu_data.dart';

import 'fake_base.dart';

/// `updateSettings` çağrısının argümanları.
typedef FakeSettingsPatch = ({String uid, UserSettingsPatch patch});

/// `updateClubSettings` çağrısının argümanları.
typedef FakeClubSettingsWrite = ({
  String uid,
  String clubId,
  ClubNotificationPrefsModel prefs,
});

final class FakeSettingsRepository extends FakeBase
    implements SettingsRepository {
  /// `settings/{uid}` belgeleri; test ön veriyi buraya yazar.
  final Map<String, UserSettingsModel> settings = <String, UserSettingsModel>{};

  /// Başarılı `updateSettings` çağrıları, sırasıyla.
  final List<FakeSettingsPatch> patches = <FakeSettingsPatch>[];

  /// Başarılı `updateClubSettings` çağrıları, sırasıyla.
  final List<FakeClubSettingsWrite> clubSettingsWrites =
      <FakeClubSettingsWrite>[];

  @override
  Future<FirestoreResult<UserSettingsModel>> getSettings(String uid) async {
    record('getSettings', [uid]);
    if (_rejected<UserSettingsModel>(uid) case final failure?) return failure;
    return FirebaseSuccess(
      settings.putIfAbsent(uid, () => UserSettingsModel.defaults(uid)),
    );
  }

  @override
  Future<FirestoreResult<void>> updateSettings(
    String uid,
    UserSettingsPatch patch,
  ) async {
    record('updateSettings', [uid, patch]);
    if (_rejected<void>(uid) case final failure?) return failure;
    if (patch.isEmpty) {
      return const FirebaseFailure(FirestoreError.invalidArgument);
    }
    final current = settings[uid];
    if (current == null) return const FirebaseFailure(FirestoreError.notFound);
    settings[uid] = current.copyWith(
      announcements: patch.announcements,
      eventReminders: patch.eventReminders,
      newEvents: patch.newEvents,
      applicationResults: patch.applicationResults,
      management: patch.management,
      system: patch.system,
      reminderTime: patch.reminderTime,
      quiet: patch.quiet,
      quietFrom: patch.quietFrom,
      quietTo: patch.quietTo,
    );
    patches.add((uid: uid, patch: patch));
    return const FirebaseSuccess(null);
  }

  @override
  Future<FirestoreResult<void>> updateClubSettings(
    String uid,
    String clubId,
    ClubNotificationPrefsModel prefs,
  ) async {
    record('updateClubSettings', [uid, clubId, prefs]);
    if (_rejected<void>(uid) case final failure?) return failure;
    if (!RepositoryHelpers.isFieldPathSegment(clubId)) {
      return const FirebaseFailure(FirestoreError.invalidArgument);
    }
    final current = settings[uid];
    if (current == null) return const FirebaseFailure(FirestoreError.notFound);
    settings[uid] = current.copyWith(clubs: {...current.clubs, clubId: prefs});
    clubSettingsWrites.add((uid: uid, clubId: clubId, prefs: prefs));
    return const FirebaseSuccess(null);
  }

  /// Bekleyen hata ya da geçersiz [uid] varsa başarısızlık; yoksa `null`.
  FirestoreResult<T>? _rejected<T>(String uid) {
    if (_failure() case final error?) return FirebaseFailure(error);
    if (!RepositoryHelpers.isValidId(uid)) {
      return const FirebaseFailure(FirestoreError.invalidArgument);
    }
    return null;
  }

  FirestoreError? _failure() => switch (takeFailure()) {
    null => null,
    final FirestoreError error => error,
    _ => FirestoreError.unknown,
  };
}

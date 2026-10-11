// T-12 · FakeSettingsRepository sözleşmesi (PLAN §16.3): `settings`,
// `patches`, `clubSettingsWrites`; gerçek repository'nin sonuçlarını izler.
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';

import 'fake_settings_repository.dart';
import 'register_fakes.dart';

const String _uid = 'u_ayse';

void main() {
  late FakeSettingsRepository fake;

  setUp(() => fake = FakeSettingsRepository());

  group('T-12 · FakeSettingsRepository', () {
    test('SettingsRepository arayüzünü uygular; registerDefaultFakes '
        'kaydeder', () {
      addTearDown(GetIt.I.reset);
      registerDefaultFakes();
      expect(GetIt.I<SettingsRepository>(), isA<FakeSettingsRepository>());
    });

    test('getSettings: belge yoksa varsayılanı yazar ve döndürür', () async {
      final result = await fake.getSettings(_uid);
      expect(result.dataOrNull, const UserSettingsModel.defaults(_uid));
      expect(fake.settings[_uid], const UserSettingsModel.defaults(_uid));
    });

    test('updateSettings: yamayı uygular ve `patches`e yazar', () async {
      await fake.getSettings(_uid);
      const patch = UserSettingsPatch(
        announcements: false,
        reminderTime: ReminderOption.oneDay,
        quiet: true,
        quietFrom: '23:30',
      );
      expect((await fake.updateSettings(_uid, patch)).isSuccess, isTrue);

      final updated = fake.settings[_uid]!;
      expect(updated.announcements, isFalse);
      expect(updated.reminderTime, ReminderOption.oneDay);
      expect(updated.quiet, isTrue);
      expect(updated.quietFrom, '23:30');
      expect(updated.quietTo, Limits.quietToDefault);
      expect(fake.patches.single, (uid: _uid, patch: patch));
    });

    test('updateClubSettings: yalnızca o kulübün kaydını değiştirir ve '
        '`clubSettingsWrites`e yazar', () async {
      const muted = ClubNotificationPrefsModel(muted: true);
      const quietEvents = ClubNotificationPrefsModel(events: false);
      await fake.getSettings(_uid);
      await fake.updateClubSettings(_uid, 'c01', muted);
      await fake.updateClubSettings(_uid, 'c02', quietEvents);

      expect(fake.settings[_uid]!.clubs, {'c01': muted, 'c02': quietEvents});
      expect(fake.clubSettingsWrites, [
        (uid: _uid, clubId: 'c01', prefs: muted),
        (uid: _uid, clubId: 'c02', prefs: quietEvents),
      ]);
    });

    test('boş yama / geçersiz kimlik invalidArgument, belge yoksa '
        'notFound', () async {
      expect(
        (await fake.updateSettings(
          _uid,
          const UserSettingsPatch(quiet: true),
        )).errorOrNull,
        FirestoreError.notFound,
      );
      expect(
        (await fake.updateClubSettings(
          _uid,
          'c01',
          const ClubNotificationPrefsModel(),
        )).errorOrNull,
        FirestoreError.notFound,
      );
      await fake.getSettings(_uid);
      expect(
        (await fake.updateSettings(
          _uid,
          const UserSettingsPatch(),
        )).errorOrNull,
        FirestoreError.invalidArgument,
      );
      expect(
        (await fake.updateClubSettings(
          _uid,
          'c.01',
          const ClubNotificationPrefsModel(),
        )).errorOrNull,
        FirestoreError.invalidArgument,
      );
      expect(
        (await fake.getSettings('u/1')).errorOrNull,
        FirestoreError.invalidArgument,
      );
      expect(fake.patches, isEmpty);
      expect(fake.clubSettingsWrites, isEmpty);
    });

    test('failNext sıradaki çağrıyı düşürür (tek seferlik)', () async {
      fake.failNext(FirestoreError.unavailable);
      expect(
        (await fake.getSettings(_uid)).errorOrNull,
        FirestoreError.unavailable,
      );
      expect(fake.settings, isEmpty);
      expect((await fake.getSettings(_uid)).isSuccess, isTrue);
    });
  });
}

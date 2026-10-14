// T-25 · NotificationPreferenceFilter — okuyan tarafın süzgeci (PLAN §15.5
// tablosu birebir; docs/plans/T-25.md §6 e): force türleri her zaman, diğerleri
// alıcının kendi tercihleriyle; kulüp sessizliği / kulüp türü; sessiz saat
// listeyi etkilemez; tanınmayan tür gizli.
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

void main() {
  const uid = 'u_ayse';
  const defaults = UserSettingsModel.defaults(uid);

  NotificationModel note(NotificationType type, {String? clubId = 'c01'}) =>
      NotificationModel(
        id: '${type.json}_k_$uid',
        userId: uid,
        type: type,
        refs: NotificationRefsModel(clubId: clubId),
      );

  group('T-25 · NotificationPreferenceFilter', () {
    test('varsayılan tercihlerde tanınan her tür görünür, unknown gizli', () {
      for (final type in NotificationType.values) {
        expect(
          NotificationPreferenceFilter.allows(note(type), defaults),
          type != NotificationType.unknown,
          reason: type.json,
        );
      }
    });

    test(
      'force türleri her tercih kapalıyken ve kulüp sessizken de görünür',
      () {
        const allOff = UserSettingsModel(
          uid: uid,
          announcements: false,
          eventReminders: false,
          newEvents: false,
          applicationResults: false,
          management: false,
          system: false,
          clubs: {'c01': ClubNotificationPrefsModel(muted: true)},
        );
        final visible = {
          for (final type in NotificationType.values)
            if (NotificationPreferenceFilter.allows(note(type), allOff)) type,
        };
        expect(visible, NotificationPreferenceFilter.forced);
      },
    );

    test('genel tercih → tür tablosu (PLAN §15.5)', () {
      final cases = <NotificationType, UserSettingsModel>{
        NotificationType.applicationReceived: defaults.copyWith(
          management: false,
        ),
        NotificationType.applicationApproved: defaults.copyWith(
          applicationResults: false,
        ),
        NotificationType.applicationRejected: defaults.copyWith(
          applicationResults: false,
        ),
        NotificationType.announcement: defaults.copyWith(announcements: false),
        NotificationType.eventNew: defaults.copyWith(newEvents: false),
        NotificationType.eventReminder: defaults.copyWith(
          eventReminders: false,
        ),
        NotificationType.system: defaults.copyWith(system: false),
      };
      for (final MapEntry(key: type, value: settings) in cases.entries) {
        expect(
          NotificationPreferenceFilter.allows(note(type), settings),
          isFalse,
          reason: type.json,
        );
      }
    });

    test('kulüp tercihi: sessiz kulüp duyuru ve yeni etkinliği gizler; tür '
        'bazlı kapama yalnızca kendi türünü; başka kulüp etkilenmez', () {
      final muted = defaults.copyWith(
        clubs: const {'c01': ClubNotificationPrefsModel(muted: true)},
      );
      final noAnnouncements = defaults.copyWith(
        clubs: const {'c01': ClubNotificationPrefsModel(announcements: false)},
      );
      bool allows(
        NotificationType type,
        UserSettingsModel s, [
        String c = 'c01',
      ]) => NotificationPreferenceFilter.allows(note(type, clubId: c), s);

      expect(allows(NotificationType.announcement, muted), isFalse);
      expect(allows(NotificationType.eventNew, muted), isFalse);
      expect(allows(NotificationType.applicationReceived, muted), isTrue);
      expect(allows(NotificationType.announcement, noAnnouncements), isFalse);
      expect(allows(NotificationType.eventNew, noAnnouncements), isTrue);
      expect(allows(NotificationType.announcement, muted, 'c02'), isTrue);
    });

    test('sessiz saat listeyi etkilemez (CD-43); apply sırayı korur ve '
        'gizlenenleri çıkarır', () {
      final quiet = defaults.copyWith(
        quiet: true,
        announcements: false,
      );
      final items = [
        note(NotificationType.eventNew),
        note(NotificationType.announcement),
        note(NotificationType.roleChanged),
        note(NotificationType.unknown),
      ];

      expect(
        NotificationPreferenceFilter.apply(quiet, items).map((n) => n.type),
        [NotificationType.eventNew, NotificationType.roleChanged],
      );
    });
  });
}

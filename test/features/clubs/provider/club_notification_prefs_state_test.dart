// SHT-07 · ClubNotificationPrefsState: varsayılanlar, gösterilen değer
// (`valueOf`), kilit (`isLocked`), `props` ve `copyWith`.
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/clubs/provider/club_notification_prefs_state.dart';

void main() {
  group('SHT-07 · ClubNotificationPrefsState', () {
    test('varsayılan: tercihler açık, yüklenmedi', () {
      const state = ClubNotificationPrefsState();
      expect(state.prefs, const ClubNotificationPrefsModel());
      expect(state.isLoaded, isFalse);
      expect(state.isSaving, isFalse);
      expect(state.isError, isFalse);
    });

    test('anahtar adları aksiyon anahtarlarının son parçasıdır', () {
      expect(ClubPrefKey.values.map((key) => key.name), [
        'announcements',
        'events',
        'posts',
        'muted',
      ]);
    });

    test('`valueOf`: kayıttaki değer; sessizdeyken üç tür kapalı görünür', () {
      const mixed = ClubNotificationPrefsState(
        prefs: ClubNotificationPrefsModel(events: false),
      );
      expect(mixed.valueOf(ClubPrefKey.announcements), isTrue);
      expect(mixed.valueOf(ClubPrefKey.events), isFalse);
      expect(mixed.valueOf(ClubPrefKey.posts), isTrue);
      expect(mixed.valueOf(ClubPrefKey.muted), isFalse);

      // Kayıtta açık kalsa da sessizde kapalı görünür.
      const muted = ClubNotificationPrefsState(
        prefs: ClubNotificationPrefsModel(muted: true),
      );
      expect(muted.valueOf(ClubPrefKey.announcements), isFalse);
      expect(muted.valueOf(ClubPrefKey.events), isFalse);
      expect(muted.valueOf(ClubPrefKey.posts), isFalse);
      expect(muted.valueOf(ClubPrefKey.muted), isTrue);
    });

    test(
      '`isLocked`: yalnızca sessizdeyken ve "Tümünü sessize al" dışında',
      () {
        const open = ClubNotificationPrefsState();
        const muted = ClubNotificationPrefsState(
          prefs: ClubNotificationPrefsModel(muted: true),
        );
        for (final key in ClubPrefKey.values) {
          expect(open.isLocked(key), isFalse, reason: key.name);
          expect(
            muted.isLocked(key),
            key != ClubPrefKey.muted,
            reason: key.name,
          );
        }
      },
    );

    test('`props` tüm alanları taşır; her alan eşitliği bozar', () {
      const base = ClubNotificationPrefsState();
      expect(base.props, hasLength(4));
      const variants = [
        ClubNotificationPrefsState(
          prefs: ClubNotificationPrefsModel(posts: false),
        ),
        ClubNotificationPrefsState(isLoaded: true),
        ClubNotificationPrefsState(isSaving: true),
        ClubNotificationPrefsState(isError: true),
      ];
      for (final variant in variants) {
        expect(variant, isNot(base));
      }
      expect(const ClubNotificationPrefsState(), base);
    });

    test('`copyWith` her alanı değiştirir, verilmeyeni korur', () {
      const prefs = ClubNotificationPrefsModel(announcements: false);
      final full = const ClubNotificationPrefsState().copyWith(
        prefs: prefs,
        isLoaded: true,
        isSaving: true,
        isError: true,
      );
      expect(
        full,
        const ClubNotificationPrefsState(
          prefs: prefs,
          isLoaded: true,
          isSaving: true,
          isError: true,
        ),
      );
      expect(full.copyWith(), full);
      expect(full.copyWith(isSaving: false).prefs, prefs);
    });
  });
}

// T-11 · SharedAppPreferencesStore: shared_preferences anahtarları, kodlama,
// kalıcılık ve hata dayanıklılığı (PLAN §4.4, §12.2; D-24, Q-14, CD-52).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/media/constants/media_constants.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) {};
    addTearDown(() => debugPrint = original);
  });

  group('T-11 · AppPreferenceKeys', () {
    test('anahtar adları tek liste (PLAN §12.2)', () {
      expect(AppPreferenceKeys.themeMode, 'pref.themeMode');
      expect(AppPreferenceKeys.locale, 'pref.locale');
      expect(AppPreferenceKeys.textScale, 'pref.textScale');
      expect(AppPreferenceKeys.onboardingSeen, 'pref.onboardingSeen');
      expect(
        AppPreferenceKeys.notificationPermissionAsked,
        'pref.notificationPermissionAsked',
      );
    });
  });

  group('T-11 · SharedAppPreferencesStore', () {
    test('load öncesi varsayılanlar; isLoaded false', () {
      final store = SharedAppPreferencesStore();
      expect(store.isLoaded, isFalse);
      expect(store.themeMode, ThemeMode.system);
      expect(store.locale, isNull);
      expect(store.textScale, GuTextScaleLevel.s100);
      expect(store.onboardingSeen, isFalse);
      expect(store.notificationPermissionAsked, isFalse);
    });

    test('boş diskten load: varsayılanlar, isLoaded true', () async {
      final store = SharedAppPreferencesStore();
      await store.load();
      expect(store.isLoaded, isTrue);
      expect(store.themeMode, ThemeMode.system);
      expect(store.locale, isNull);
      expect(store.textScale, GuTextScaleLevel.s100);
      expect(store.onboardingSeen, isFalse);
      expect(store.notificationPermissionAsked, isFalse);
    });

    test('diskteki değerler okunur', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        AppPreferenceKeys.themeMode: 'dark',
        AppPreferenceKeys.locale: 'en',
        AppPreferenceKeys.textScale: 's130',
        AppPreferenceKeys.onboardingSeen: true,
        AppPreferenceKeys.notificationPermissionAsked: true,
      });
      final store = SharedAppPreferencesStore();
      await store.load();
      expect(store.themeMode, ThemeMode.dark);
      expect(store.locale, const Locale('en'));
      expect(store.textScale, GuTextScaleLevel.s130);
      expect(store.onboardingSeen, isTrue);
      expect(store.notificationPermissionAsked, isTrue);
    });

    test('her yazıcı değeri diske yazar; yeni depo aynı değerleri okur '
        '(kalıcılık)', () async {
      final store = SharedAppPreferencesStore();
      await store.load();
      expect(await store.setThemeMode(ThemeMode.light), isTrue);
      expect(await store.setLocale(const Locale('tr')), isTrue);
      expect(await store.setTextScale(GuTextScaleLevel.s160), isTrue);
      expect(await store.setOnboardingSeen(true), isTrue);
      expect(await store.setNotificationPermissionAsked(true), isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppPreferenceKeys.themeMode), 'light');
      expect(prefs.getString(AppPreferenceKeys.locale), 'tr');
      expect(prefs.getString(AppPreferenceKeys.textScale), 's160');
      expect(prefs.getBool(AppPreferenceKeys.onboardingSeen), isTrue);
      expect(
        prefs.getBool(AppPreferenceKeys.notificationPermissionAsked),
        isTrue,
      );

      final reopened = SharedAppPreferencesStore();
      await reopened.load();
      expect(reopened.themeMode, ThemeMode.light);
      expect(reopened.locale, const Locale('tr'));
      expect(reopened.textScale, GuTextScaleLevel.s160);
      expect(reopened.onboardingSeen, isTrue);
      expect(reopened.notificationPermissionAsked, isTrue);
    });

    test(
      'her ThemeMode ve GuTextScaleLevel değeri gidiş-dönüş korunur',
      () async {
        final store = SharedAppPreferencesStore();
        await store.load();
        for (final mode in ThemeMode.values) {
          await store.setThemeMode(mode);
          final reopened = SharedAppPreferencesStore();
          await reopened.load();
          expect(reopened.themeMode, mode);
        }
        for (final level in GuTextScaleLevel.values) {
          await store.setTextScale(level);
          final reopened = SharedAppPreferencesStore();
          await reopened.load();
          expect(reopened.textScale, level);
        }
      },
    );

    test('setLocale(null) sistem diline döner ve kalıcıdır', () async {
      final store = SharedAppPreferencesStore();
      await store.load();
      await store.setLocale(const Locale('en'));
      await store.setLocale(null);
      expect(store.locale, isNull);

      final reopened = SharedAppPreferencesStore();
      await reopened.load();
      expect(reopened.locale, isNull);
    });

    test('bozuk / tanınmayan / yanlış tipte değer varsayılana düşer', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        AppPreferenceKeys.themeMode: 'neon',
        AppPreferenceKeys.locale: 'de',
        AppPreferenceKeys.textScale: 42,
        AppPreferenceKeys.onboardingSeen: 'evet',
        AppPreferenceKeys.notificationPermissionAsked: 1,
      });
      final store = SharedAppPreferencesStore();
      await store.load();
      expect(store.isLoaded, isTrue);
      expect(store.themeMode, ThemeMode.system);
      expect(store.locale, isNull);
      expect(store.textScale, GuTextScaleLevel.s100);
      expect(store.onboardingSeen, isFalse);
      expect(store.notificationPermissionAsked, isFalse);
    });

    test('bölge kodlu dil yalnızca dil koduyla saklanır', () async {
      final store = SharedAppPreferencesStore();
      await store.load();
      await store.setLocale(const Locale('en', 'GB'));
      final reopened = SharedAppPreferencesStore();
      await reopened.load();
      expect(reopened.locale, const Locale('en'));
    });

    test('load öncesi yazım da depoyu açar ve yazar', () async {
      final store = SharedAppPreferencesStore();
      expect(await store.setOnboardingSeen(true), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AppPreferenceKeys.onboardingSeen), isTrue);
    });

    test('depo açılamazsa load fırlatmaz: varsayılanlar, isLoaded false; '
        'yazım false döner ama bellekteki değer geçerlidir', () async {
      final store = SharedAppPreferencesStore(
        open: () async => throw StateError('disk yok'),
      );
      await store.load();
      expect(store.isLoaded, isFalse);
      expect(store.themeMode, ThemeMode.system);

      expect(await store.setThemeMode(ThemeMode.dark), isFalse);
      expect(store.themeMode, ThemeMode.dark);
      expect(await store.setLocale(const Locale('en')), isFalse);
      expect(store.locale, const Locale('en'));
      expect(await store.setTextScale(GuTextScaleLevel.s130), isFalse);
      expect(store.textScale, GuTextScaleLevel.s130);
      expect(await store.setOnboardingSeen(true), isFalse);
      expect(store.onboardingSeen, isTrue);
      expect(await store.setNotificationPermissionAsked(true), isFalse);
      expect(store.notificationPermissionAsked, isTrue);
    });
  });

  group('T-14 · SharedAppPreferencesStore · photoAccessExplained (DLG-05)', () {
    test('anahtar adı; varsayılan false (load öncesi ve boş diskte)', () async {
      expect(
        AppPreferenceKeys.photoAccessExplained,
        'pref.photoAccessExplained',
      );
      final store = SharedAppPreferencesStore();
      expect(store.photoAccessExplained, isFalse);
      await store.load();
      expect(store.photoAccessExplained, isFalse);
    });

    test('yazılır, diske işler ve yeni depo okur (kalıcılık); geri '
        'alınabilir', () async {
      final store = SharedAppPreferencesStore();
      await store.load();

      expect(await store.setPhotoAccessExplained(true), isTrue);
      expect(store.photoAccessExplained, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AppPreferenceKeys.photoAccessExplained), isTrue);
      // Diğer bayraklara dokunmaz.
      expect(store.notificationPermissionAsked, isFalse);
      expect(store.onboardingSeen, isFalse);

      final reopened = SharedAppPreferencesStore();
      await reopened.load();
      expect(reopened.photoAccessExplained, isTrue);

      expect(await reopened.setPhotoAccessExplained(false), isTrue);
      expect(reopened.photoAccessExplained, isFalse);
    });

    test('yanlış tipte değer varsayılana düşer', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        AppPreferenceKeys.photoAccessExplained: 'evet',
      });
      final store = SharedAppPreferencesStore();
      await store.load();
      expect(store.photoAccessExplained, isFalse);
    });

    test('depo açılamazsa yazım false döner ama bellekteki değer '
        'geçerlidir', () async {
      final store = SharedAppPreferencesStore(
        open: () async => throw StateError('disk yok'),
      );
      expect(await store.setPhotoAccessExplained(true), isFalse);
      expect(store.photoAccessExplained, isTrue);
    });
  });

  group('T-21 · SharedAppPreferencesStore · composeDraft (FED-03, CD-45)', () {
    test('anahtar `compose_draft_<clubId>`; kulüp başına tek taslak diske '
        'işler, yeni depo okur; null taslağı kaldırır', () async {
      expect(AppPreferenceKeys.composeDraft('c03'), 'compose_draft_c03');
      final store = SharedAppPreferencesStore();
      expect(store.composeDraft('c03'), isNull);
      await store.load();
      expect(store.composeDraft('c03'), isNull);

      expect(await store.setComposeDraft('c03', '{"text":"a"}'), isTrue);
      expect(await store.setComposeDraft('c03', '{"text":"b"}'), isTrue);
      expect(store.composeDraft('c03'), '{"text":"b"}');
      expect(store.composeDraft('c01'), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('compose_draft_c03'), '{"text":"b"}');

      final reopened = SharedAppPreferencesStore();
      await reopened.load();
      expect(reopened.composeDraft('c03'), '{"text":"b"}');

      expect(await reopened.setComposeDraft('c03', null), isTrue);
      expect(reopened.composeDraft('c03'), isNull);
      expect(prefs.containsKey('compose_draft_c03'), isFalse);
    });

    test('depo açılamazsa yazım false döner ama taslak oturum boyunca '
        'geçerlidir; yanlış tipte değer taslak sayılmaz', () async {
      final broken = SharedAppPreferencesStore(
        open: () async => throw StateError('disk yok'),
      );
      expect(await broken.setComposeDraft('c03', '{}'), isFalse);
      expect(broken.composeDraft('c03'), '{}');

      SharedPreferences.setMockInitialValues(<String, Object>{
        AppPreferenceKeys.composeDraft('c03'): 7,
      });
      final store = SharedAppPreferencesStore();
      await store.load();
      expect(store.composeDraft('c03'), isNull);
    });
  });

  group('T-17 · SharedAppPreferencesStore · recentSearches (CLB-02)', () {
    test('anahtar adı; varsayılan boş (load öncesi ve boş diskte)', () async {
      expect(AppPreferenceKeys.recentSearches, 'pref.recentSearches');
      final store = SharedAppPreferencesStore();
      expect(store.recentSearches, isEmpty);
      await store.load();
      expect(store.recentSearches, isEmpty);
    });

    test(
      'yazılır, diske işler ve yeni depo okur; fazlası '
      'Limits.recentSearchesMax sınırında kesilir; boş liste temizler',
      () async {
        final store = SharedAppPreferencesStore();
        await store.load();
        final terms = [for (var i = 0; i < 8; i++) 'arama $i'];

        expect(await store.setRecentSearches(terms), isTrue);
        expect(store.recentSearches, terms.take(6));
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getStringList(AppPreferenceKeys.recentSearches),
          terms.take(6),
        );

        final reopened = SharedAppPreferencesStore();
        await reopened.load();
        expect(reopened.recentSearches, terms.take(6));

        expect(await reopened.setRecentSearches(const []), isTrue);
        expect(reopened.recentSearches, isEmpty);
      },
    );

    test('yanlış tipte değer boş listeye düşer', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        AppPreferenceKeys.recentSearches: 'hackathon',
      });
      final store = SharedAppPreferencesStore();
      await store.load();
      expect(store.recentSearches, isEmpty);
    });
  });

  group('T-42 · SharedAppPreferencesStore · pushTokenUid', () {
    test('anahtar adı; yazılır, yeni depo okur; null kaldırır; yanlış tip '
        'null', () async {
      expect(AppPreferenceKeys.pushTokenUid, 'pref.pushTokenUid');
      final store = SharedAppPreferencesStore();
      await store.load();
      expect(store.pushTokenUid, isNull);

      expect(await store.setPushTokenUid('u1'), isTrue);
      final reopened = SharedAppPreferencesStore();
      await reopened.load();
      expect(reopened.pushTokenUid, 'u1');

      expect(await reopened.setPushTokenUid(null), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(AppPreferenceKeys.pushTokenUid), isFalse);

      SharedPreferences.setMockInitialValues(<String, Object>{
        AppPreferenceKeys.pushTokenUid: 7,
      });
      final broken = SharedAppPreferencesStore();
      await broken.load();
      expect(broken.pushTokenUid, isNull);
    });
  });

  group('T-44 · SharedAppPreferencesStore · görsel adresleri ve bitmiş '
      'etkinlikler (D2-05, D2-06)', () {
    test('anahtar adları', () {
      expect(AppPreferenceKeys.imageUrls, 'media.imageUrls');
      expect(AppPreferenceKeys.reminderDone('u1'), 'pref.reminderDone.u1');
    });

    test('görsel adresleri JSON gidiş-dönüşü: yeni depo aynı adres ve anı '
        'okur; en yeni imageUrlPersistMaxEntries kayıt tutulur', () async {
      final store = SharedAppPreferencesStore();
      await store.load();
      final at = DateTime.utc(2026, 10, 15, 9);
      final entries = {
        for (var i = 0; i < MediaConstants.imageUrlPersistMaxEntries + 5; i++)
          'posts/p$i/a.jpg': (
            url: 'https://storage.test/$i',
            at: at.add(Duration(minutes: i)),
          ),
      };

      expect(await store.setImageUrls(entries), isTrue);
      final reopened = SharedAppPreferencesStore();
      await reopened.load();
      final read = reopened.imageUrls;

      expect(read, hasLength(MediaConstants.imageUrlPersistMaxEntries));
      // En eski beş kayıt atıldı.
      expect(read.containsKey('posts/p0/a.jpg'), isFalse);
      const last =
          'posts/p${MediaConstants.imageUrlPersistMaxEntries + 4}/a.jpg';
      expect(read[last]?.url, entries[last]!.url);
      expect(read[last]?.at, entries[last]!.at);
      expect(read[last]!.at.isUtc, isTrue);
    });

    test('bozuk ya da yanlış biçimli görsel kaydı boş haritaya düşer, '
        'fırlatmaz; geçerli kayıtlar kalır', () async {
      for (final raw in ['{bozuk', '[1,2]', '']) {
        SharedPreferences.setMockInitialValues(<String, Object>{
          AppPreferenceKeys.imageUrls: raw,
        });
        final store = SharedAppPreferencesStore();
        await store.load();
        expect(store.imageUrls, isEmpty, reason: raw);
      }
      SharedPreferences.setMockInitialValues(<String, Object>{
        AppPreferenceKeys.imageUrls:
            '{"a": ["https://x", 1760000000000], "b": [1, 2], "c": "x"}',
      });
      final mixed = SharedAppPreferencesStore();
      await mixed.load();
      expect(mixed.imageUrls.keys, ['a']);
      // Load öncesi boş.
      expect(SharedAppPreferencesStore().imageUrls, isEmpty);
    });

    test(
      'bitmiş etkinlik kümesi hesap başına yazılır ve yeni depo okur',
      () async {
        final store = SharedAppPreferencesStore();
        await store.load();
        expect(store.reminderDoneEvents('u1'), isEmpty);

        expect(await store.setReminderDoneEvents('u1', {'e01', 'e02'}), isTrue);
        expect(store.reminderDoneEvents('u1'), {'e01', 'e02'});
        final reopened = SharedAppPreferencesStore();
        await reopened.load();
        expect(reopened.reminderDoneEvents('u1'), {'e01', 'e02'});
        expect(reopened.reminderDoneEvents('u2'), isEmpty);
      },
    );
  });

  group('T-45 · SharedAppPreferencesStore · bekleyen ad (F2)', () {
    test('anahtar hesap başınadır; yazılır, yeni depo okur; null kaldırır; '
        'yanlış tip null', () async {
      expect(AppPreferenceKeys.pendingName('u1'), 'pref.pendingName.u1');
      final store = SharedAppPreferencesStore();
      await store.load();
      expect(store.pendingDisplayName('u1'), isNull);

      expect(await store.setPendingDisplayName('u1', 'Ayşe Yılmaz'), isTrue);
      expect(store.pendingDisplayName('u1'), 'Ayşe Yılmaz');
      final reopened = SharedAppPreferencesStore();
      await reopened.load();
      expect(reopened.pendingDisplayName('u1'), 'Ayşe Yılmaz');
      expect(reopened.pendingDisplayName('u2'), isNull);

      expect(await reopened.setPendingDisplayName('u1', null), isTrue);
      expect(reopened.pendingDisplayName('u1'), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(AppPreferenceKeys.pendingName('u1')), isFalse);

      SharedPreferences.setMockInitialValues(<String, Object>{
        AppPreferenceKeys.pendingName('u1'): 7,
      });
      final broken = SharedAppPreferencesStore();
      await broken.load();
      expect(broken.pendingDisplayName('u1'), isNull);
      // Load öncesi okunmaz.
      expect(SharedAppPreferencesStore().pendingDisplayName('u1'), isNull);
    });
  });
}

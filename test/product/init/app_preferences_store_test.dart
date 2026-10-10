// T-11 · SharedAppPreferencesStore: shared_preferences anahtarları, kodlama,
// kalıcılık ve hata dayanıklılığı (PLAN §4.4, §12.2; D-24, Q-14, CD-52).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
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
}

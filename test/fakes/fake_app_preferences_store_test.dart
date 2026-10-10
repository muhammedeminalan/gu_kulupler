// T-11 · FakeAppPreferencesStore sözleşmesi (PLAN §16.3): gerçek depoyla aynı
// anahtarlar ve kodlama.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_ui/gu_ui.dart';

import 'fake_app_preferences_store.dart';
import 'register_fakes.dart';

void main() {
  group('T-11 · FakeAppPreferencesStore', () {
    test('AppPreferencesStore arayüzünü uygular; registerDefaultFakes '
        'yüklenmiş olarak kaydeder', () {
      addTearDown(GetIt.I.reset);
      registerDefaultFakes();
      final store = GetIt.I<AppPreferencesStore>();
      expect(store, isA<FakeAppPreferencesStore>());
      expect(store.isLoaded, isTrue);
    });

    test('boşken gerçek deponun varsayılanları döner', () {
      final fake = FakeAppPreferencesStore();
      expect(fake.themeMode, ThemeMode.system);
      expect(fake.locale, isNull);
      expect(fake.textScale, GuTextScaleLevel.s100);
      expect(fake.onboardingSeen, isFalse);
      expect(fake.notificationPermissionAsked, isFalse);
    });

    test('yazıcılar değeri AppPreferenceKeys anahtarıyla saklar ve çağrıyı '
        'kaydeder', () async {
      final fake = FakeAppPreferencesStore();
      expect(await fake.setThemeMode(ThemeMode.dark), isTrue);
      expect(await fake.setLocale(const Locale('en')), isTrue);
      expect(await fake.setTextScale(GuTextScaleLevel.s160), isTrue);
      expect(await fake.setOnboardingSeen(true), isTrue);
      expect(await fake.setNotificationPermissionAsked(true), isTrue);

      expect(fake.values, {
        AppPreferenceKeys.themeMode: 'dark',
        AppPreferenceKeys.locale: 'en',
        AppPreferenceKeys.textScale: 's160',
        AppPreferenceKeys.onboardingSeen: true,
        AppPreferenceKeys.notificationPermissionAsked: true,
      });
      expect(fake.themeMode, ThemeMode.dark);
      expect(fake.locale, const Locale('en'));
      expect(fake.textScale, GuTextScaleLevel.s160);
      expect(fake.onboardingSeen, isTrue);
      expect(fake.notificationPermissionAsked, isTrue);
      expect(fake.calls.map((c) => c.method), [
        'setThemeMode',
        'setLocale',
        'setTextScale',
        'setOnboardingSeen',
        'setNotificationPermissionAsked',
      ]);
    });

    test('setLocale(null) sistem diline döner; desteklenmeyen kod yok '
        'sayılır', () async {
      final fake = FakeAppPreferencesStore();
      await fake.setLocale(const Locale('en'));
      await fake.setLocale(null);
      expect(fake.locale, isNull);

      fake.values[AppPreferenceKeys.locale] = 'de';
      expect(fake.locale, isNull);
    });

    test('failNext: yazım false döner ama bellekteki değer güncellenir '
        '(gerçek depo gibi)', () async {
      final fake = FakeAppPreferencesStore()..failNext();
      expect(await fake.setThemeMode(ThemeMode.light), isFalse);
      expect(fake.themeMode, ThemeMode.light);
      expect(await fake.setThemeMode(ThemeMode.dark), isTrue);
    });

    test('loaded: false → load() yükler; failNext ile yükleme başarısız '
        'kalır', () async {
      final fake = FakeAppPreferencesStore(loaded: false);
      expect(fake.isLoaded, isFalse);
      fake.failNext();
      await fake.load();
      expect(fake.isLoaded, isFalse);
      await fake.load();
      expect(fake.isLoaded, isTrue);
      expect(fake.callsTo('load'), hasLength(2));
    });
  });
}

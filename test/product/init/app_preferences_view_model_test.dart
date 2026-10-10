// T-11 · AppPreferencesViewModel: başlangıç, her mutasyon, kalıcılık ve
// kalıcılık hatası (PLAN §12.2).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_kulupler/product/init/app_preferences_state.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/init/app_preferences_view_model.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../fakes/fake_app_preferences_store.dart';
import '../../helpers/test_container.dart';

void main() {
  late FakeAppPreferencesStore store;
  late List<String> console;

  void useStore(FakeAppPreferencesStore value) {
    store = value;
    GetIt.I.registerSingleton<AppPreferencesStore>(store);
  }

  setUp(() async {
    await GetIt.I.reset();
    addTearDown(GetIt.I.reset);
    console = <String>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) => console.add(message ?? '');
    addTearDown(() => debugPrint = original);
  });

  group('T-11 · AppPreferencesViewModel', () {
    test('başlangıç: yüklenmiş depo boşsa varsayılanlar + isLoaded', () {
      useStore(FakeAppPreferencesStore());
      final container = createContainer();
      expect(
        container.read(appPreferencesViewModelProvider),
        const AppPreferencesState(isLoaded: true),
      );
    });

    test("başlangıç: depodaki değerler ilk state'te hazırdır", () {
      useStore(
        FakeAppPreferencesStore()
          ..values[AppPreferenceKeys.themeMode] = 'dark'
          ..values[AppPreferenceKeys.locale] = 'en'
          ..values[AppPreferenceKeys.textScale] = 's160'
          ..values[AppPreferenceKeys.onboardingSeen] = true
          ..values[AppPreferenceKeys.notificationPermissionAsked] = true,
      );
      final container = createContainer();
      expect(
        container.read(appPreferencesViewModelProvider),
        const AppPreferencesState(
          themeMode: ThemeMode.dark,
          locale: Locale('en'),
          textScale: GuTextScaleLevel.s160,
          onboardingSeen: true,
          notificationPermissionAsked: true,
          isLoaded: true,
        ),
      );
    });

    test("depo henüz yüklenmediyse isLoaded false; load() okur ve state'i "
        'yeniler', () async {
      useStore(
        FakeAppPreferencesStore(loaded: false)
          ..values[AppPreferenceKeys.themeMode] = 'light',
      );
      final container = createContainer();
      expect(container.read(appPreferencesViewModelProvider).isLoaded, isFalse);

      await container.read(appPreferencesViewModelProvider.notifier).load();
      final state = container.read(appPreferencesViewModelProvider);
      expect(state.isLoaded, isTrue);
      expect(state.themeMode, ThemeMode.light);
      expect(store.callsTo('load'), hasLength(1));
    });

    test('setThemeMode: state + depo', () async {
      useStore(FakeAppPreferencesStore());
      final container = createContainer();
      final notifier = container.read(appPreferencesViewModelProvider.notifier);

      await notifier.setThemeMode(ThemeMode.dark);
      expect(
        container.read(appPreferencesViewModelProvider).themeMode,
        ThemeMode.dark,
      );
      expect(store.themeMode, ThemeMode.dark);
    });

    test('setLocale: dil seçimi ve null ile sistem diline dönüş', () async {
      useStore(FakeAppPreferencesStore());
      final container = createContainer();
      final notifier = container.read(appPreferencesViewModelProvider.notifier);

      await notifier.setLocale(const Locale('en'));
      expect(
        container.read(appPreferencesViewModelProvider).locale,
        const Locale('en'),
      );
      expect(store.locale, const Locale('en'));

      await notifier.setLocale(null);
      expect(container.read(appPreferencesViewModelProvider).locale, isNull);
      expect(store.locale, isNull);
    });

    test('setTextScale: üç düzey', () async {
      useStore(FakeAppPreferencesStore());
      final container = createContainer();
      final notifier = container.read(appPreferencesViewModelProvider.notifier);

      for (final level in GuTextScaleLevel.values) {
        await notifier.setTextScale(level);
        expect(
          container.read(appPreferencesViewModelProvider).textScale,
          level,
        );
        expect(store.textScale, level);
      }
    });

    test(
      'markNotificationPermissionAsked: bayrak bir kez işaretlenir',
      () async {
        useStore(FakeAppPreferencesStore());
        final container = createContainer();
        await container
            .read(appPreferencesViewModelProvider.notifier)
            .markNotificationPermissionAsked();

        expect(
          container
              .read(appPreferencesViewModelProvider)
              .notificationPermissionAsked,
          isTrue,
        );
        expect(store.notificationPermissionAsked, isTrue);
      },
    );

    test("syncOnboardingSeen depodaki bayrağı state'e yansıtır (bayrağı "
        "oturum ViewModel'i yazar — CD-52)", () async {
      useStore(FakeAppPreferencesStore());
      final container = createContainer();
      expect(
        container.read(appPreferencesViewModelProvider).onboardingSeen,
        isFalse,
      );

      await store.setOnboardingSeen(true);
      container
          .read(appPreferencesViewModelProvider.notifier)
          .syncOnboardingSeen();
      expect(
        container.read(appPreferencesViewModelProvider).onboardingSeen,
        isTrue,
      );
    });

    test('state diske yazımdan ÖNCE güncellenir (arayüz beklemez)', () async {
      useStore(FakeAppPreferencesStore());
      final container = createContainer();
      final pending = container
          .read(appPreferencesViewModelProvider.notifier)
          .setThemeMode(ThemeMode.light);
      expect(
        container.read(appPreferencesViewModelProvider).themeMode,
        ThemeMode.light,
      );
      await pending;
    });

    test('kalıcılık hatası: state geri alınmaz, günlüğe uyarı düşer', () async {
      useStore(FakeAppPreferencesStore()..failNext());
      final container = createContainer();
      await container
          .read(appPreferencesViewModelProvider.notifier)
          .setTextScale(GuTextScaleLevel.s130);

      expect(
        container.read(appPreferencesViewModelProvider).textScale,
        GuTextScaleLevel.s130,
      );
      expect(console.where((line) => line.startsWith('[W]')), hasLength(1));
    });

    test('kalıcılık: yeni kapsayıcı (yeniden açılış) aynı tercihlerle '
        'başlar', () async {
      useStore(FakeAppPreferencesStore());
      final first = createContainer();
      final notifier = first.read(appPreferencesViewModelProvider.notifier);
      await notifier.setThemeMode(ThemeMode.dark);
      await notifier.setLocale(const Locale('en'));
      await notifier.setTextScale(GuTextScaleLevel.s160);
      await notifier.markNotificationPermissionAsked();

      final second = createContainer();
      expect(
        second.read(appPreferencesViewModelProvider),
        first.read(appPreferencesViewModelProvider),
      );
      expect(
        second.read(appPreferencesViewModelProvider).themeMode,
        ThemeMode.dark,
      );
    });

    test('keepAlive: dinleyici kalmasa da state korunur', () async {
      useStore(FakeAppPreferencesStore());
      final container = createContainer();
      final sub = container.listen(appPreferencesViewModelProvider, (_, _) {});
      await container
          .read(appPreferencesViewModelProvider.notifier)
          .setThemeMode(ThemeMode.dark);
      sub.close();
      await pumpEventQueue();
      // Depo değişse bile yeniden kurulmaz: değer state'ten gelir.
      store.values[AppPreferenceKeys.themeMode] = 'light';
      expect(
        container.read(appPreferencesViewModelProvider).themeMode,
        ThemeMode.dark,
      );
    });
  });
}

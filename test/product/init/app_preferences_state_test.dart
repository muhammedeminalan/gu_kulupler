// T-11 · AppPreferencesState: props / copyWith tüm alanlar (PLAN §12.16).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/product/init/app_preferences_state.dart';
import 'package:gu_ui/gu_ui.dart';

void main() {
  group('T-11 · AppPreferencesState', () {
    const a = AppPreferencesState();
    const en = Locale('en');

    test('props tüm alanları içerir (alan sayısı = 6)', () {
      expect(a.props.length, 6);
    });

    test('varsayılanlar', () {
      expect(a.themeMode, ThemeMode.system);
      expect(a.locale, isNull);
      expect(a.textScale, GuTextScaleLevel.s100);
      expect(a.onboardingSeen, isFalse);
      expect(a.notificationPermissionAsked, isFalse);
      expect(a.isLoaded, isFalse);
    });

    test('copyWith her alanı taşır ve eşitliği bozar', () {
      expect(a.copyWith(themeMode: ThemeMode.dark).themeMode, ThemeMode.dark);
      expect(a.copyWith(themeMode: ThemeMode.dark), isNot(a));
      expect(a.copyWith(locale: en).locale, en);
      expect(a.copyWith(locale: en), isNot(a));
      expect(
        a.copyWith(textScale: GuTextScaleLevel.s130).textScale,
        GuTextScaleLevel.s130,
      );
      expect(a.copyWith(textScale: GuTextScaleLevel.s130), isNot(a));
      expect(a.copyWith(onboardingSeen: true).onboardingSeen, isTrue);
      expect(a.copyWith(onboardingSeen: true), isNot(a));
      expect(
        a
            .copyWith(notificationPermissionAsked: true)
            .notificationPermissionAsked,
        isTrue,
      );
      expect(a.copyWith(notificationPermissionAsked: true), isNot(a));
      expect(a.copyWith(isLoaded: true).isLoaded, isTrue);
      expect(a.copyWith(isLoaded: true), isNot(a));
    });

    test('clearLocale dili sistem diline döndürür; locale ile birlikte '
        'verilirse clearLocale kazanır', () {
      final withLocale = a.copyWith(locale: en);
      expect(withLocale.copyWith(clearLocale: true).locale, isNull);
      expect(withLocale.copyWith(locale: en, clearLocale: true).locale, isNull);
      expect(withLocale.copyWith().locale, en);
    });

    test('copyWith parametresiz aynı değeri verir', () {
      final b = a.copyWith(
        themeMode: ThemeMode.light,
        locale: en,
        textScale: GuTextScaleLevel.s160,
        onboardingSeen: true,
        notificationPermissionAsked: true,
        isLoaded: true,
      );
      expect(b.copyWith(), b);
    });
  });
}

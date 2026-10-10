// T-11 · DebugMenu · DebugMenuState: props / copyWith tüm alanlar
// (PLAN §12.16).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/features/system/debug_menu/provider/debug_menu_state.dart';
import 'package:gu_ui/gu_ui.dart';

void main() {
  group('T-11 · DebugMenuState', () {
    const a = DebugMenuState();

    test('props tüm alanları içerir (alan sayısı = 6)', () {
      expect(a.props.length, 6);
    });

    test('varsayılanlar: sistem teması, sistem dili, %100; süren giriş ve '
        'hata yok', () {
      expect(a.themeMode, ThemeMode.system);
      expect(a.locale, isNull);
      expect(a.textScale, GuTextScaleLevel.s100);
      expect(a.signingInId, isNull);
      expect(a.isError, isFalse);
      expect(a.errorCode, isNull);
    });

    test('copyWith her alanı taşır ve eşitliği bozar', () {
      expect(a.copyWith(themeMode: ThemeMode.dark).themeMode, ThemeMode.dark);
      expect(a.copyWith(themeMode: ThemeMode.dark), isNot(a));
      expect(a.copyWith(locale: const Locale('en')).locale, const Locale('en'));
      expect(a.copyWith(locale: const Locale('en')), isNot(a));
      expect(
        a.copyWith(textScale: GuTextScaleLevel.s160).textScale,
        GuTextScaleLevel.s160,
      );
      expect(a.copyWith(textScale: GuTextScaleLevel.s160), isNot(a));
      expect(a.copyWith(signingInId: 'u_ayse').signingInId, 'u_ayse');
      expect(a.copyWith(signingInId: 'u_ayse'), isNot(a));
      expect(a.copyWith(isError: true).isError, isTrue);
      expect(a.copyWith(isError: true), isNot(a));
      expect(a.copyWith(errorCode: 'network').errorCode, 'network');
      expect(a.copyWith(errorCode: 'network'), isNot(a));
    });

    test('copyWith parametresiz aynı değeri verir; clearLocale dili '
        'sistem diline döndürür', () {
      final b = a.copyWith(
        themeMode: ThemeMode.light,
        locale: const Locale('tr'),
        textScale: GuTextScaleLevel.s130,
        signingInId: 'u_elif',
        isError: true,
        errorCode: 'network',
      );
      expect(b.copyWith(), b);
      expect(b.copyWith(clearLocale: true).locale, isNull);
      expect(
        b.copyWith(clearLocale: true, locale: const Locale('en')).locale,
        isNull,
      );
    });

    test('clearSigningInId / clearErrorCode alanı `null` yapar ve verilen '
        'değerden önce gelir', () {
      const b = DebugMenuState(
        signingInId: 'u_elif',
        isError: true,
        errorCode: 'network',
      );
      expect(b.copyWith(clearSigningInId: true).signingInId, isNull);
      expect(
        b.copyWith(clearSigningInId: true, signingInId: 'u_ayse').signingInId,
        isNull,
      );
      expect(b.copyWith(clearErrorCode: true).errorCode, isNull);
      expect(
        b.copyWith(clearErrorCode: true, errorCode: 'unknown').errorCode,
        isNull,
      );
      // Temizleme diğer alanlara dokunmaz.
      expect(b.copyWith(clearSigningInId: true).errorCode, 'network');
      expect(b.copyWith(clearErrorCode: true).isError, isTrue);
    });
  });
}

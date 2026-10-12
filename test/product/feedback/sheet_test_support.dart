// Katalog sheet testlerinin ortak düzeneği (SHT-02, SHT-03, SHT-16): gerçek
// `AppFeedbackService` + kendi gezgini. Overlay gerçekten çizilir (scrim,
// geçiş, çerçeve); sonuç `showSheet`'in döndürdüğü değerdir.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/golden_helper.dart';
import '../../helpers/pump_app.dart';

/// [id] sayfasını gerçek servis üzerinden açan test düzeneği.
///
/// Gezgin, uygulama kökündeki gibi (`GuApp.builder`, `.gu-root`) kök metin
/// stilinin altındadır: kök gezgine itilen sayfa bir `Scaffold` altında
/// değildir, stil oradan gelir.
class SheetHarness<T> {
  SheetHarness(this.id, this.builder);

  /// Açılan sayfanın kimliği.
  final SheetId id;

  /// Sayfa içeriği (`GuSheetFrame` döndürür); sonraki [open] için
  /// değiştirilebilir.
  WidgetBuilder builder;

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final GuToastController controller = GuToastController();
  late final AppFeedbackService service = AppFeedbackService(
    navigatorKey: navigatorKey,
    toastController: controller,
  );

  static const Object _pending = Object();
  Object? _result = _pending;
  bool _disposeRegistered = false;

  /// Son açılan sayfa kapandı mı?
  bool get isClosed => !identical(_result, _pending);

  /// Son açılan sayfanın sonucu; kapanmadıysa hata.
  T? get result {
    if (!isClosed) throw StateError('${id.designId} henüz kapanmadı.');
    return _result as T?;
  }

  /// Boş bir sayfa üstünde gezgini çizer.
  Future<void> pump(
    WidgetTester tester, {
    Locale locale = const Locale('tr'),
    ThemeMode theme = ThemeMode.light,
  }) async {
    if (!_disposeRegistered) {
      _disposeRegistered = true;
      addTearDown(controller.dispose);
    }
    await tester.pumpApp(
      Builder(
        builder: (context) => DefaultTextStyle(
          style: context.gu.text.bodyM,
          child: Navigator(
            key: navigatorKey,
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: SizedBox.expand()),
            ),
          ),
        ),
      ),
      locale: locale,
      theme: theme,
    );
  }

  /// Sayfayı açar ve giriş geçişini bitirir.
  Future<void> open(WidgetTester tester) async {
    _result = _pending;
    unawaited(
      service
          .showSheet<T>(id, builder: builder)
          .then((value) => _result = value),
    );
    await tester.pumpAndSettle();
  }

  /// Geri tuşu: gezgin en üstteki rotayı (sayfayı) kapatır.
  Future<void> back(WidgetTester tester) async {
    expect(await navigatorKey.currentState!.maybePop(), isTrue);
    await tester.pumpAndSettle();
  }

  /// Açık sayfanın tam ekran golden'ı (scrim dahil), açık + koyu, TR:
  /// `test/goldens/<name>__<tema>__tr.png`.
  Future<void> golden(WidgetTester tester, String name) async {
    const locale = Locale('tr');
    for (final theme in kGoldenThemes) {
      await pump(tester, theme: theme);
      await open(tester);
      await expectLater(
        find.byKey(kPumpAppBoundaryKey),
        matchesGoldenFile(goldenUri(goldenPath(name, theme, locale))),
      );
    }
  }
}

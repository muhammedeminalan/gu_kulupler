// Dialog testlerinin ortak düzeneği (DLG-03, DLG-04, DLG-05, DLG-06, DLG-25):
// gerçek `AppFeedbackService` + kendi gezgini. Overlay gerçekten çizilir
// (scrim, geçiş, çerçeve); sonuç dialogun `pop` değeridir.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/golden_helper.dart';
import '../../helpers/pump_app.dart';

/// Dialogları gerçek servis üzerinden açan test düzeneği.
///
/// Gezgin, uygulama kökündeki gibi (`GuApp.builder`) kök metin stilinin
/// altındadır: kök gezgine itilen dialog bir `Scaffold` altında değildir.
class DialogHarness {
  final GuToastController controller = GuToastController();

  /// Geçerli gezginin anahtarı. Her [pump] yenisini kurar: aynı `GlobalKey`
  /// yeniden kullanılırsa önceki gezgin (açık dialoguyla birlikte) yeni ağaca
  /// taşınır.
  GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Geçerli gezgine bağlı gerçek servis.
  AppFeedbackService get service => AppFeedbackService(
    navigatorKey: navigatorKey,
    toastController: controller,
  );

  static const Object _pending = Object();
  Object? _result = _pending;
  bool _disposeRegistered = false;

  /// Son açılan dialog kapandı mı?
  bool get isClosed => !identical(_result, _pending);

  /// Son açılan dialogun sonucu; kapanmadıysa hata.
  Object? get result {
    if (!isClosed) throw StateError('Dialog henüz kapanmadı.');
    return _result;
  }

  /// [id] dialogunun [action] anahtarı (`DLG-06.logout`).
  static Key keyOf(DialogId id, String action) =>
      FeedbackKeys.of(id.designId, action);

  /// Boş bir sayfa üstünde gezgini çizer.
  Future<void> pump(
    WidgetTester tester, {
    Locale locale = const Locale('tr'),
    ThemeMode theme = ThemeMode.light,
    Size size = const Size(390, 844),
    double textScale = 1.0,
  }) async {
    if (!_disposeRegistered) {
      _disposeRegistered = true;
      addTearDown(controller.dispose);
    }
    navigatorKey = GlobalKey<NavigatorState>();
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
      size: size,
      textScale: textScale,
    );
  }

  /// [open] ile verilen dialogu açar ve giriş geçişini bitirir.
  Future<void> open<T>(
    WidgetTester tester,
    Future<T?> Function(FeedbackService service) open,
  ) async {
    _result = _pending;
    unawaited(open(service).then((value) => _result = value));
    await tester.pumpAndSettle();
  }

  /// [key] düğmesine dokunur ve çıkış geçişini bitirir.
  Future<void> tap(WidgetTester tester, Key key) async {
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
  }

  /// Geri tuşu: gezgin en üstteki rotayı (dialogu) kapatır.
  Future<void> back(WidgetTester tester) async {
    expect(await navigatorKey.currentState!.maybePop(), isTrue);
    await tester.pumpAndSettle();
  }

  /// Açık dialogun tam ekran golden'ı (scrim dahil), açık + koyu, TR:
  /// `test/goldens/<name>__<tema>__tr.png`.
  Future<void> golden<T>(
    WidgetTester tester,
    String name,
    Future<T?> Function(FeedbackService service) open,
  ) async {
    const locale = Locale('tr');
    for (final theme in kGoldenThemes) {
      await pump(tester, theme: theme);
      await this.open<T>(tester, open);
      await expectLater(
        find.byKey(kPumpAppBoundaryKey),
        matchesGoldenFile(goldenUri(goldenPath(name, theme, locale))),
      );
    }
  }
}

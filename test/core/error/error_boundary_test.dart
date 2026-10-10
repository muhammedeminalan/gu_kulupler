// T-11 · ErrorBoundary: çöken alt ağacın yer tutucusu (D-23) — üretimde
// tasarımın hata durumu, debug'da Flutter'ın kırmızı ekranı.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/core/error/error_boundary.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/device_matrix.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/test_l10n.dart';

FlutterErrorDetails _details() =>
    FlutterErrorDetails(exception: StateError('build patladı'));

/// İlk kurulumda fırlatan, [healed] sonrası düzelen widget.
class _Flaky extends StatelessWidget {
  const _Flaky();

  static bool healed = false;
  static int builds = 0;

  @override
  Widget build(BuildContext context) {
    builds++;
    if (!healed) throw StateError('build patladı');
    return const Text('ok', textDirection: TextDirection.ltr);
  }
}

void main() {
  group('T-11 · ErrorBoundary · builder', () {
    test("install ErrorWidget.builder'ı bağlar", () {
      final original = ErrorWidget.builder;
      addTearDown(() => ErrorWidget.builder = original);
      ErrorBoundary.install();
      expect(ErrorWidget.builder, ErrorBoundary.builder);
    });

    test("debug derlemede Flutter'ın kırmızı hata widget'ı (mesajla)", () {
      final widget = ErrorBoundary.builder(_details());
      expect(widget, isA<ErrorWidget>());
      expect((widget as ErrorWidget).message, contains('build patladı'));
    });

    test('üretimde tasarımın yer tutucusu', () {
      expect(
        ErrorBoundary.builder(_details(), debug: false),
        isA<ErrorBoundaryFallback>(),
      );
    });
  });

  group('T-11 · ErrorBoundaryFallback', () {
    testWidgets('hata durumunu ARB metinleriyle çizer (TR)', (tester) async {
      await tester.pumpApp(const ErrorBoundaryFallback());
      expect(find.byType(GuErrorState), findsOneWidget);
      expect(find.text(tester.l10n.sysErrorTitle), findsOneWidget);
      expect(find.text(tester.l10n.sysErrorDesc), findsOneWidget);
      expect(find.text(tester.l10n.commonRetry), findsOneWidget);
    });

    testWidgets('EN metinleri', (tester) async {
      await tester.pumpApp(
        const ErrorBoundaryFallback(),
        locale: const Locale('en'),
      );
      final en = tester.l10nFor(const Locale('en'));
      expect(find.text(en.sysErrorTitle), findsOneWidget);
      expect(find.text(en.commonRetry), findsOneWidget);
    });

    testWidgets('tema / yerelleştirme yoksa (MaterialApp üstü) boş alan '
        'çizer, fırlatmaz', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: ErrorBoundaryFallback(),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(GuErrorState), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('GuTheme olmayan MaterialApp içinde de fırlatmaz', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: ErrorBoundaryFallback()),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(GuErrorState), findsNothing);
    });

    testWidgets('üretim akışı: çöken build yerine yer tutucu; "Yeniden dene" '
        "çöken widget'ı yeniden kurar ve düzelince yer tutucu kalkar", (
      tester,
    ) async {
      // Bağlama, test gövdesi bitmeden kancanın eski haline dönmesini ister.
      final original = ErrorWidget.builder;
      _Flaky.healed = false;
      _Flaky.builds = 0;
      ErrorWidget.builder = (details) =>
          ErrorBoundary.builder(details, debug: false);
      try {
        await tester.pumpApp(const _Flaky());
        expect(tester.takeException(), isStateError);
        expect(find.byType(ErrorBoundaryFallback), findsOneWidget);
        final buildsAfterCrash = _Flaky.builds;

        // Hâlâ bozuk: yeniden dener, yine yer tutucu.
        await tester.tap(find.text(tester.l10n.commonRetry));
        await tester.pump();
        expect(tester.takeException(), isStateError);
        expect(_Flaky.builds, greaterThan(buildsAfterCrash));
        await tester.pumpAndSettle();
        expect(find.byType(ErrorBoundaryFallback), findsOneWidget);

        _Flaky.healed = true;
        await tester.tap(find.text(tester.l10n.commonRetry));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('ok'), findsOneWidget);
        expect(find.byType(ErrorBoundaryFallback), findsNothing);
      } finally {
        ErrorWidget.builder = original;
      }
    });

    testWidgets('cihaz matrisi: taşma yok', (tester) async {
      await DeviceMatrix.run(
        tester,
        (_) => const Scaffold(body: ErrorBoundaryFallback()),
      );
    });
  });
}

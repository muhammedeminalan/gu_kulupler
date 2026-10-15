// T-35 · ScanOverlay (widget-catalog F1) — MGT-07 tarayıcı katmanı: üst satır
// (kapat · başlık + sayaç · fener · kamera çevir), 240 çerçeve + tarama
// çizgisi (GuMotion.scan; azaltılmış harekette durağan 8 %), ipucu, alt panel
// "Kod gir" / elle kod alanı, fener açık (beyaz daire), ön kamera aynası,
// anahtarlar + geri çağrılar, Semantics, cihaz matrisi
// ve golden (açık + koyu). Demo tarama düğmeleri yok (K-02, K-04). Kaynak:
// prototip `screens-manage.js:149–155`; css:335, 401–404, 422;
// design/reference-shots/screens/MGT-07__*.webp (DLG-04 ile örtülü).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/management/view/widget/scan_overlay.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../../helpers/device_matrix.dart';
import '../../../../helpers/golden_helper.dart';
import '../../../../helpers/pump_app.dart';
import '../../../../helpers/test_l10n.dart';

const Locale _tr = Locale('tr');
const Key _previewKey = ValueKey<String>('test.preview');
const Key _fieldKey = ValueKey<String>('test.manualField');

/// Çağrıları kaydeden düzenek.
class _Calls {
  final List<String> log = [];
}

ScanOverlay _overlay(
  BuildContext context, {
  _Calls? calls,
  String title = 'Veri Bilimi Söyleşisi',
  bool torchOn = false,
  bool frontCamera = false,
  bool manualOpen = false,
}) {
  final l10n = context.l10n;
  return ScanOverlay(
    preview: const SizedBox.expand(key: _previewKey),
    title: title,
    counterLabel: l10n.scanCounter('5', '52'),
    hintLabel: l10n.scanHint,
    onClose: () => calls?.log.add('close'),
    onTorch: () => calls?.log.add('torch'),
    onFlip: () => calls?.log.add('flip'),
    onManualCode: () => calls?.log.add('manual'),
    torchOn: torchOn,
    frontCamera: frontCamera,
    manualOpen: manualOpen,
    manualField: const SizedBox(key: _fieldKey, height: GuSizes.inputHeight),
  );
}

Future<void> _pump(
  WidgetTester tester,
  ScanOverlay Function(BuildContext context) build, {
  bool reduceMotion = false,
}) async {
  await tester.pumpApp(
    Scaffold(
      body: Builder(
        builder: (context) => reduceMotion
            ? MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(disableAnimations: true),
                child: Builder(builder: build),
              )
            : build(context),
      ),
    ),
  );
  await tester.pump();
}

/// 240 kare tarama çerçevesi (`.scan-box`).
final Finder _scanBox = find.byWidgetPredicate(
  (w) =>
      w is SizedBox &&
      w.width == GuSizes.scanBox &&
      w.height == GuSizes.scanBox,
);

/// Tarama çizgisinin çerçeve içindeki üst konumu (dp).
double _lineTop(WidgetTester tester) {
  final line = find.descendant(
    of: _scanBox,
    matching: find.byWidgetPredicate(
      (w) => w is Positioned && w.height == GuSizes.scanLineHeight,
    ),
  );
  return tester.getTopLeft(line.first).dy - tester.getTopLeft(_scanBox).dy;
}

void main() {
  group('T-35 · ScanOverlay', () {
    test('anahtarlar prototipteki aksiyon adlarıdır', () {
      expect(ScanOverlay.closeKey, GuKey.action('MGT-07.close'));
      expect(ScanOverlay.torchKey, GuKey.action('MGT-07.torch'));
      expect(ScanOverlay.flipKey, GuKey.action('MGT-07.flip'));
      expect(ScanOverlay.manualCodeKey, GuKey.action('MGT-07.manualCode'));
    });

    testWidgets('içerik: önizleme, başlık + sayaç, ipucu, "Kod gir"; demo '
        'düğmesi yok; dokunuşlar geri çağrılara', (tester) async {
      final calls = _Calls();
      await _pump(tester, (context) => _overlay(context, calls: calls));
      final l10n = tester.l10nFor(_tr);
      expect(find.byKey(_previewKey), findsOneWidget);
      expect(find.text('Veri Bilimi Söyleşisi'), findsOneWidget);
      expect(find.text(l10n.scanCounter('5', '52')), findsOneWidget);
      expect(find.text(l10n.scanHint), findsOneWidget);
      expect(find.text(l10n.scanManualCode), findsOneWidget);
      expect(find.text(l10n.scanDemoValid), findsNothing);
      expect(find.byKey(_fieldKey), findsNothing);
      expect(tester.getSize(_scanBox), const Size.square(GuSizes.scanBox));
      for (final key in [
        ScanOverlay.closeKey,
        ScanOverlay.torchKey,
        ScanOverlay.flipKey,
        ScanOverlay.manualCodeKey,
      ]) {
        await tester.tap(find.byKey(key));
      }
      expect(calls.log, ['close', 'torch', 'flip', 'manual']);
    });

    testWidgets('fener açık: beyaz daire + toggled semantiği, ikon rengi '
        'kapsayıcıdan; ön kamera: çerçeve aynalanır', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        (context) => _overlay(context, torchOn: true, frontCamera: true),
      );
      final l10n = tester.l10nFor(_tr);
      final torch = find.descendant(
        of: find.byKey(ScanOverlay.torchKey),
        matching: find.byType(GuIconButton),
      );
      final button = tester.widget<GuIconButton>(torch);
      expect(button.onCover, isFalse);
      expect(button.foregroundInherit, isTrue);
      expect(
        find.descendant(
          of: find.byKey(ScanOverlay.torchKey),
          matching: find.byWidgetPredicate(
            (w) =>
                w is DecoratedBox &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).color ==
                    GuComponentColors.light.onCoverForeground,
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.ancestor(
          of: torch,
          matching: find.byWidgetPredicate(
            (w) => w is Semantics && (w.properties.toggled ?? false),
          ),
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(l10n.scanTorch), findsOneWidget);
      final flip = tester.widget<Transform>(
        find.ancestor(of: _scanBox, matching: find.byType(Transform)).first,
      );
      expect(flip.transform.entry(0, 0), -1);
      handle.dispose();
    });

    testWidgets('elle kod açık: alan çizilir, "Kod gir" gizlenir', (
      tester,
    ) async {
      await _pump(tester, (context) => _overlay(context, manualOpen: true));
      expect(find.byKey(_fieldKey), findsOneWidget);
      expect(find.byKey(ScanOverlay.manualCodeKey), findsNothing);
    });

    testWidgets('tarama çizgisi: 8 % → (1,1 sn) 90 % → (2,2 sn) 8 %; '
        'azaltılmış harekette durağan', (tester) async {
      await _pump(tester, _overlay);
      const box = GuSizes.scanBox;
      expect(_lineTop(tester), closeTo(box * GuSizes.scanLineTopMin, 1));
      await tester.pump(GuMotion.scan ~/ 2);
      expect(_lineTop(tester), closeTo(box * GuSizes.scanLineTopMax, 1));
      await tester.pump(GuMotion.scan ~/ 2);
      expect(_lineTop(tester), closeTo(box * GuSizes.scanLineTopMin, 1));

      await _pump(tester, _overlay, reduceMotion: true);
      await tester.pump(GuMotion.scan ~/ 2);
      expect(_lineTop(tester), closeTo(box * GuSizes.scanLineTopMin, 1));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('cihaz matrisi: taşma yok (uzun başlık 320 × 1.6 dahil, '
        'güvenli alanlar)', (tester) async {
      await DeviceMatrix.run(
        tester,
        (context) => Scaffold(
          body: Builder(
            builder: (context) => _overlay(
              context,
              title:
                  'Yapay Zekâ ve Veri Bilimi Söyleşisi: Geleceğin Meslekleri',
            ),
          ),
        ),
        safeAreas: true,
      );
    });

    testWidgets('golden: fener açık — açık + koyu (TR)', (
      tester,
    ) async {
      await goldenForThemes(
        tester,
        'scan_overlay',
        Scaffold(
          body: Builder(
            builder: (context) => _overlay(context, torchOn: true),
          ),
        ),
      );
    });
  });
}

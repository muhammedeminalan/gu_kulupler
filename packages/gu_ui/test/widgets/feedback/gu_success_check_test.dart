// T-06 · GuSuccessCheck (widget-catalog #37; A.2 #37; ui.js:151;
// css:332–333, 420, 427).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

final Finder _paint = find.descendant(
  of: find.byType(GuSuccessCheck),
  matching: find.byType(CustomPaint),
);

/// Dairenin son karesi: `stroke-dasharray:200` / r 40 = 5 rad (≈ 286°).
const double _finalSweep = 200 / GuSizes.successCircleR;

/// `drawArc` çağrısının süpürme açısı [expected] mi (± 1e-6).
bool Function(Symbol, List<dynamic>) _arcSweep(double expected) =>
    (method, arguments) =>
        method == #drawArc &&
        ((arguments[2] as double) - expected).abs() < 1e-6;

PaintPattern _finalFrame(Color color, {double scale = 1}) => paints
  ..save()
  ..scale(x: scale, y: scale)
  ..arc(
    rect: const Rect.fromLTWH(8, 8, 80, 80),
    startAngle: 0,
    sweepAngle: _finalSweep,
    useCenter: false,
    color: color,
    strokeWidth: GuSizes.successCircleStroke,
    style: PaintingStyle.stroke,
  )
  ..path(
    color: color,
    strokeWidth: GuSizes.successCheckStroke,
    style: PaintingStyle.stroke,
    // Tik yolu üstündeki noktalar (M30 49 l12 12 24-26).
    includes: const [Offset(30, 49), Offset(42, 61), Offset(66, 35)],
  )
  ..restore();

/// `MediaQuery.disableAnimations` değerini [reduce] ile değiştiren sarmalayıcı.
Widget _host(ValueNotifier<bool> reduce, Widget child) =>
    ValueListenableBuilder<bool>(
      valueListenable: reduce,
      builder: (context, disable, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: disable),
        child: child!,
      ),
      child: Center(child: child),
    );

void main() {
  group('T-06 · GuSuccessCheck', () {
    testWidgets('T-06 · GuSuccessCheck · 96 px, state.success; daire 500 ms, '
        'tik 200 ms gecikme + 320 ms, tek sefer; Semantics', (tester) async {
      final handle = tester.ensureSemantics();
      final color = GuColors.light.stateSuccess;
      await tester.pumpApp(
        const Center(child: GuSuccessCheck(semanticLabel: 'Başarılı')),
      );
      expect(
        tester.getSize(find.byType(GuSuccessCheck)),
        const Size.square(GuSizes.successCheck),
      );
      // İlk kare: hiçbir şey çizilmez.
      expect(_paint, isNot(paints..arc()));
      expect(_paint, isNot(paints..path()));

      // 100 ms: yalnızca daire (tik 200 ms gecikmeli).
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        _paint,
        paints..something(
          _arcSweep(_finalSweep * GuMotion.easeStandard.transform(0.2)),
        ),
      );
      expect(_paint, isNot(paints..path()));

      // 250 ms: dairenin yarı süresi + tik başladı.
      await tester.pump(const Duration(milliseconds: 150));
      expect(
        _paint,
        paints
          ..something(
            _arcSweep(_finalSweep * GuMotion.easeStandard.transform(0.5)),
          )
          ..path(color: color, strokeWidth: GuSizes.successCheckStroke),
      );
      expect(tester.hasRunningAnimations, isTrue);

      // 520 ms: son kare; animasyon tekrar etmez.
      await tester.pump(GuMotion.checkDrawDelay + GuMotion.checkDraw);
      expect(tester.hasRunningAnimations, isFalse);
      expect(_paint, _finalFrame(color));

      expect(
        tester.getSemantics(find.byType(GuSuccessCheck)),
        isSemantics(label: 'Başarılı', isImage: true),
      );
      handle.dispose();
    });

    testWidgets('T-06 · GuSuccessCheck · azaltılmış harekette son kare '
        '(72 px, koyu); süren çizim durur, yeniden oynamaz', (tester) async {
      final reduce = ValueNotifier<bool>(true);
      addTearDown(reduce.dispose);
      const check = GuSuccessCheck(
        semanticLabel: 'Başarılı',
        size: 72,
      );
      await tester.pumpApp(_host(reduce, check), theme: ThemeMode.dark);
      expect(
        tester.getSize(find.byType(GuSuccessCheck)),
        const Size.square(72),
      );
      expect(tester.hasRunningAnimations, isFalse);
      expect(_paint, _finalFrame(GuColors.dark.stateSuccess, scale: 0.75));

      // Tercih kapanınca yeniden oynamaz.
      reduce.value = false;
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(_paint, _finalFrame(GuColors.dark.stateSuccess, scale: 0.75));

      // Çizim sürerken tercih açılırsa son kareye atlar.
      reduce.value = false;
      await tester.pumpApp(_host(reduce, check));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isTrue);
      reduce.value = true;
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(_paint, _finalFrame(GuColors.light.stateSuccess, scale: 0.75));
    });
  });
}

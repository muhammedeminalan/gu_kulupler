// T-07 · GuToastHost + GuToastController (widget-catalog #42b; css:288–289,
// 416; shell.js:17–19; core.js:565–570; CD-24, CD-29).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../helpers/pump_app.dart';

const _child = SizedBox.expand(key: ValueKey<String>('body'));

GuToastEntry _entry(
  String text, {
  GuToastKind kind = GuToastKind.info,
  String? actionLabel,
  VoidCallback? onAction,
  Duration? duration,
  bool persistent = false,
}) => GuToastEntry(
  kind: kind,
  text: text,
  closeSemanticLabel: 'Kapat',
  actionLabel: actionLabel,
  onAction: onAction,
  duration: duration,
  persistent: persistent,
  toastKey: ValueKey<String>('toast.$text'),
  actionKey: ValueKey<String>('action.$text'),
  closeKey: ValueKey<String>('close.$text'),
);

/// Giriş animasyonunu bitirir.
Future<void> _settleIn(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(GuMotion.slow);
}

/// Çıkış animasyonunu bitirir (durum bildirimi süreden sonraki ilk karede).
Future<void> _settleOut(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(GuMotion.base);
  await tester.pump(GuMotion.fast);
}

double _opacity(WidgetTester tester) => tester
    .widget<FadeTransition>(
      // En yakın ata: host'un solması (rota geçişleri daha yukarıda).
      find
          .ancestor(
            of: find.byType(GuToast),
            matching: find.byType(FadeTransition),
          )
          .first,
    )
    .opacity
    .value;

void main() {
  group('T-07 · GuToastHost', () {
    testWidgets('T-07 · GuToastHost · göster → giriş (24 px yukarı + solma, '
        'slow) → 4 sn sonra kapanır (çıkış base); kapat düğmesi hemen '
        'kapatır', (tester) async {
      final controller = GuToastController();
      addTearDown(controller.dispose);
      await tester.pumpApp(
        GuToastHost(controller: controller, child: _child),
      );
      expect(find.byType(GuToast), findsNothing);
      expect(find.byKey(const ValueKey<String>('body')), findsOneWidget);
      expect(controller.isVisible, isFalse);

      controller.show(_entry('Bağlantı kopyalandı.'));
      expect(controller.isVisible, isTrue);
      expect(controller.serial, 1);
      await tester.pump();
      expect(find.byType(GuToast), findsOneWidget);
      expect(_opacity(tester), 0);
      final start = tester.getTopLeft(find.byType(GuToast));
      await tester.pump(GuMotion.slow);
      expect(_opacity(tester), 1);
      final end = tester.getTopLeft(find.byType(GuToast));
      expect(start.dy - end.dy, GuMotion.toastEnterOffsetY);
      expect(start.dx, end.dx);

      // Standart süre 4 sn (giriş animasyonu dahil).
      expect(
        controller.current!.effectiveDuration,
        GuMotion.toastDefault,
      );
      await tester.pump(
        GuMotion.toastDefault - GuMotion.slow - GuMotion.fast,
      );
      expect(controller.isVisible, isTrue);
      await tester.pump(GuMotion.fast);
      expect(controller.isVisible, isFalse);
      // Çıkış animasyonu boyunca çizilir, sonra kalkar.
      expect(find.byType(GuToast), findsOneWidget);
      await _settleOut(tester);
      expect(find.byType(GuToast), findsNothing);

      // Kapat düğmesi.
      controller.show(_entry('Kaydedildi.'));
      await _settleIn(tester);
      await tester.tap(find.byKey(const ValueKey<String>('close.Kaydedildi.')));
      expect(controller.current, isNull);
      await _settleOut(tester);
      expect(find.byType(GuToast), findsNothing);
      // Kapalıyken `hide` etkisiz.
      controller.hide();
      await tester.pump(GuMotion.toastUndo);
      expect(find.byType(GuToast), findsNothing);
    });

    testWidgets('T-07 · GuToastHost · en çok 1: yenisi eskisini hemen '
        'kapatır ve süreyi sıfırlar; aynı girdi yeniden gösterilebilir', (
      tester,
    ) async {
      final controller = GuToastController();
      addTearDown(controller.dispose);
      await tester.pumpApp(
        GuToastHost(controller: controller, child: _child),
      );
      final first = _entry('Birinci');
      controller.show(first);
      await _settleIn(tester);
      await tester.pump(const Duration(seconds: 3) - GuMotion.slow);

      controller.show(_entry('İkinci'));
      await tester.pump();
      expect(find.byType(GuToast), findsOneWidget);
      expect(find.text('Birinci'), findsNothing);
      expect(find.text('İkinci'), findsOneWidget);
      // Yeni toast girişi baştan oynar.
      expect(_opacity(tester), 0);
      await tester.pump(GuMotion.slow);
      expect(_opacity(tester), 1);

      // İlk toastın sayacı (toplam 4 sn) ikinciyi kapatmaz.
      await tester.pump(const Duration(seconds: 3) - GuMotion.slow);
      expect(controller.current?.text, 'İkinci');
      await tester.pump(const Duration(seconds: 1));
      expect(controller.current, isNull);
      await _settleOut(tester);
      expect(find.byType(GuToast), findsNothing);

      // Aynı girdi iki kez: sıra numarası artar, sayaç yenilenir.
      controller.show(first);
      await _settleIn(tester);
      await tester.pump(const Duration(seconds: 3));
      controller.show(first);
      expect(controller.serial, 4);
      await tester.pump();
      expect(_opacity(tester), 0);
      await tester.pump(const Duration(seconds: 3));
      expect(controller.isVisible, isTrue);
      await tester.pump(const Duration(seconds: 1));
      expect(controller.isVisible, isFalse);
    });

    testWidgets('T-07 · GuToastHost · eylemli 6 sn (toastUndo), özel süre, '
        'persistent kapanmaz; eylem dokunuşu önce gizler sonra çağırır', (
      tester,
    ) async {
      final controller = GuToastController();
      addTearDown(controller.dispose);
      await tester.pumpApp(
        GuToastHost(controller: controller, child: _child),
      );
      final calls = <String>[];

      // Geri al'lı: 6 sn.
      controller.show(
        _entry(
          'Bildirim silindi.',
          actionLabel: 'Geri al',
          onAction: () => calls.add('undo:${controller.isVisible}'),
        ),
      );
      expect(controller.current!.effectiveDuration, GuMotion.toastUndo);
      await _settleIn(tester);
      await tester.pump(GuMotion.toastDefault);
      expect(controller.isVisible, isTrue);
      await tester.pump(GuMotion.toastUndo - GuMotion.toastDefault);
      expect(controller.isVisible, isFalse);
      expect(calls, isEmpty);
      await _settleOut(tester);

      // Eylem: gizle + çağır; sayaç iptal.
      controller.show(
        _entry(
          'Bildirim silindi.',
          actionLabel: 'Geri al',
          onAction: () => calls.add('undo:${controller.isVisible}'),
        ),
      );
      await _settleIn(tester);
      await tester.tap(
        find.byKey(const ValueKey<String>('action.Bildirim silindi.')),
      );
      expect(calls, ['undo:false']);
      await _settleOut(tester);
      expect(find.byType(GuToast), findsNothing);

      // Çağıranın verdiği süre önceliklidir; `onAction` yoksa da gizler.
      controller.show(
        _entry(
          'Yayınlandı.',
          actionLabel: 'Görüntüle',
          duration: GuMotion.toastDefault,
        ),
      );
      await _settleIn(tester);
      await tester.tap(
        find.byKey(const ValueKey<String>('action.Yayınlandı.')),
      );
      expect(controller.isVisible, isFalse);
      await _settleOut(tester);
      controller.show(_entry('Kısa', duration: GuMotion.slow * 2));
      await _settleIn(tester);
      expect(controller.isVisible, isTrue);
      await tester.pump(GuMotion.slow);
      expect(controller.isVisible, isFalse);
      await _settleOut(tester);

      // Kalıcı: süreyle kapanmaz.
      controller.show(_entry('Bakım modu', persistent: true));
      await _settleIn(tester);
      await tester.pump(const Duration(minutes: 5));
      expect(controller.isVisible, isTrue);
      expect(find.text('Bakım modu'), findsOneWidget);
      controller.hide();
      await _settleOut(tester);
      expect(find.byType(GuToast), findsNothing);
    });

    testWidgets('T-07 · GuToastHost · konum: yatay 12, alt = güvenli alan + '
        'bottomInset + 12; klavye üstü; 768 dp genişlikte 480 sütunu; host '
        'show çağrısından sonra kurulursa da çizer', (tester) async {
      final controller = GuToastController();
      addTearDown(controller.dispose);
      const padding = EdgeInsets.only(top: 47, bottom: 34);
      controller.show(_entry('Konum', persistent: true));

      // İç ekran: alt çubuk yok.
      await tester.pumpApp(
        GuToastHost(controller: controller, child: _child),
        viewPadding: padding,
      );
      await tester.pump(GuMotion.slow);
      var rect = tester.getRect(find.byType(GuToast));
      expect(rect.left, GuSizes.toastMarginX);
      expect(rect.right, 390 - GuSizes.toastMarginX);
      expect(rect.bottom, 844 - 34 - GuSizes.toastBottomExtra);
      expect(_opacity(tester), 1);

      // Sekme kökü: alt çubuğun üstü (`.above-nav`).
      await tester.pumpApp(
        GuToastHost(
          controller: controller,
          bottomInset: GuSizes.bottomNavHeight,
          child: _child,
        ),
        viewPadding: padding,
      );
      await tester.pump(GuMotion.slow);
      rect = tester.getRect(find.byType(GuToast));
      expect(
        rect.bottom,
        844 - 34 - GuSizes.bottomNavHeight - GuSizes.toastBottomExtra,
      );

      // Klavye açık: klavyenin üstü.
      await tester.pumpApp(
        GuToastHost(
          controller: controller,
          bottomInset: GuSizes.bottomNavHeight,
          child: _child,
        ),
        viewPadding: padding,
        keyboardInset: 300,
      );
      await tester.pump(GuMotion.slow);
      rect = tester.getRect(find.byType(GuToast));
      expect(rect.bottom, 844 - 300 - GuSizes.toastBottomExtra);

      // Geniş ekran: 480 sütununa ortalı (CD-29).
      await tester.pumpApp(
        GuToastHost(controller: controller, child: _child),
        size: const Size(768, 1024),
      );
      await tester.pump(GuMotion.slow);
      rect = tester.getRect(find.byType(GuToast));
      expect(rect.width, GuBreakpoints.maxContentWidth - 2 * 12);
      expect(rect.center.dx, 768 / 2);
      expect(rect.bottom, 1024 - GuSizes.toastBottomExtra);
    });

    testWidgets('T-07 · GuToastHost · azaltılmış hareket: giriş / çıkış '
        'anında; denetleyici değişimi eski toastı bırakır', (tester) async {
      final first = GuToastController();
      final second = GuToastController();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      Widget host(GuToastController controller) => Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: GuToastHost(controller: controller, child: _child),
        ),
      );
      late StateSetter setState;
      var controller = first;
      await tester.pumpApp(
        StatefulBuilder(
          builder: (context, set) {
            setState = set;
            return host(controller);
          },
        ),
      );
      first.show(_entry('Anında', kind: GuToastKind.success));
      await tester.pump();
      expect(_opacity(tester), 1);
      final shown = tester.getRect(find.byType(GuToast));
      expect(shown.bottom, 844 - GuSizes.toastBottomExtra);
      first.hide();
      await tester.pump();
      expect(find.byType(GuToast), findsNothing);

      // Denetleyici değişimi: yeni denetleyicinin toastı devralınır.
      first.show(_entry('Eski', persistent: true));
      await tester.pump();
      expect(find.text('Eski'), findsOneWidget);
      second.show(_entry('Yeni', kind: GuToastKind.error));
      setState(() => controller = second);
      await tester.pump();
      expect(find.text('Eski'), findsNothing);
      expect(find.text('Yeni'), findsOneWidget);
      expect(_opacity(tester), 1);
      // Eski denetleyici artık dinlenmez.
      first.hide();
      await tester.pump();
      expect(find.text('Yeni'), findsOneWidget);
      await tester.pump(GuMotion.toastDefault);
      expect(second.isVisible, isFalse);
      await tester.pump();
      expect(find.byType(GuToast), findsNothing);
    });
  });

  group('T-21 · GuToastBottomObstacle', () {
    const barKey = ValueKey<String>('bar');

    Widget page({required double? barHeight}) => Scaffold(
      body: _child,
      bottomNavigationBar: barHeight == null
          ? null
          : GuToastBottomObstacle(
              child: SizedBox(key: barKey, height: barHeight),
            ),
    );

    Future<Rect> shownToast(WidgetTester tester) async {
      await _settleIn(tester);
      return tester.getRect(find.byType(GuToast));
    }

    testWidgets('T-21 · GuToastBottomObstacle · toast bildirilen alt çubuğun '
        '12 üstünde durur; çubuk büyüyünce yükselir, kalkınca varsayılan '
        'konuma döner', (tester) async {
      final controller = GuToastController();
      addTearDown(controller.dispose);
      late StateSetter setState;
      double? barHeight = 64;
      await tester.pumpApp(
        GuToastHost(
          controller: controller,
          child: StatefulBuilder(
            builder: (context, set) {
              setState = set;
              return page(barHeight: barHeight);
            },
          ),
        ),
      );
      controller.show(_entry('Yorum gönderildi.', persistent: true));
      var toast = await shownToast(tester);
      final bar = tester.getRect(find.byKey(barKey));
      expect(bar.bottom, 844);
      expect(toast.bottom, bar.top - GuSizes.toastBottomExtra);
      expect(toast.overlaps(bar), isFalse);

      // Çubuk büyür (çok satırlı alan): toast görünürken de yükselir.
      setState(() => barHeight = 120);
      await tester.pump();
      await tester.pump();
      toast = tester.getRect(find.byType(GuToast));
      expect(toast.bottom, 844 - 120 - GuSizes.toastBottomExtra);

      // Çubuk kalkar: varsayılan konum.
      setState(() => barHeight = null);
      await tester.pump();
      await tester.pump();
      toast = tester.getRect(find.byType(GuToast));
      expect(toast.bottom, 844 - GuSizes.toastBottomExtra);
    });

    testWidgets('T-21 · GuToastBottomObstacle · sekme çubuğu boşluğu ve '
        'klavyeyle en büyüğü geçerlidir', (tester) async {
      final controller = GuToastController();
      addTearDown(controller.dispose);
      // Çubuk (40) sekme çubuğu boşluğundan kısa: boşluk geçerli.
      await tester.pumpApp(
        GuToastHost(
          controller: controller,
          bottomInset: GuSizes.bottomNavHeight,
          child: page(barHeight: 40),
        ),
      );
      controller.show(_entry('Kısa çubuk', persistent: true));
      var toast = await shownToast(tester);
      expect(
        toast.bottom,
        844 - GuSizes.bottomNavHeight - GuSizes.toastBottomExtra,
      );

      // Klavye (300) çubuktan (64) yüksek: klavyenin üstü.
      await tester.pumpApp(
        GuToastHost(controller: controller, child: page(barHeight: 64)),
        keyboardInset: 300,
      );
      controller.show(_entry('Klavye', persistent: true));
      toast = await shownToast(tester);
      expect(toast.bottom, 844 - 300 - GuSizes.toastBottomExtra);
    });

    testWidgets('T-21 · GuToastBottomObstacle · altta kalan sayfanın çubuğu '
        'toastı itmez; sayfa yeniden en üste gelince iter', (tester) async {
      final controller = GuToastController();
      addTearDown(controller.dispose);
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpApp(
        GuToastHost(
          controller: controller,
          child: Navigator(
            key: navigatorKey,
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => page(barHeight: 64),
            ),
          ),
        ),
      );
      unawaited(
        navigatorKey.currentState!.push(
          MaterialPageRoute<void>(builder: (_) => page(barHeight: null)),
        ),
      );
      await tester.pumpAndSettle();
      controller.show(_entry('Üst sayfa', persistent: true));
      var toast = await shownToast(tester);
      expect(toast.bottom, 844 - GuSizes.toastBottomExtra);

      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      toast = tester.getRect(find.byType(GuToast));
      expect(toast.bottom, 844 - 64 - GuSizes.toastBottomExtra);
    });

    testWidgets('T-21 · GuToastBottomObstacle · sahnede olmayan dalın '
        '(TickerMode kapalı — etkin olmayan sekme) çubuğu toastı itmez', (
      tester,
    ) async {
      final controller = GuToastController();
      addTearDown(controller.dispose);
      late StateSetter setState;
      var onstage = false;
      await tester.pumpApp(
        GuToastHost(
          controller: controller,
          child: StatefulBuilder(
            builder: (context, set) {
              setState = set;
              return TickerMode(
                enabled: onstage,
                child: page(barHeight: 64),
              );
            },
          ),
        ),
      );
      controller.show(_entry('Başka sekme', persistent: true));
      var toast = await shownToast(tester);
      expect(toast.bottom, 844 - GuSizes.toastBottomExtra);

      setState(() => onstage = true);
      await tester.pump();
      await tester.pump();
      toast = tester.getRect(find.byType(GuToast));
      expect(toast.bottom, 844 - 64 - GuSizes.toastBottomExtra);
    });

    testWidgets('T-21 · GuToastBottomObstacle · host yokken etkisizdir', (
      tester,
    ) async {
      await tester.pumpApp(page(barHeight: 64));
      expect(find.byKey(barKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

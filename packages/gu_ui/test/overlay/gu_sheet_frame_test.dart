// T-07 · GuSheetFrame + showGuSheet (widget-catalog #39; A.2 #39; css:266–278;
// ui.js:167–181; CD-24, CD-29, CD-113, K-07).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/src/overlay/gu_dialog_frame.dart';
import 'package:gu_ui/src/overlay/gu_sheet_frame.dart';
import 'package:gu_ui/src/tokens/gu_colors.dart';
import 'package:gu_ui/src/tokens/gu_motion.dart';
import 'package:gu_ui/src/tokens/gu_radius.dart';
import 'package:gu_ui/src/tokens/gu_shadows.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/tokens/gu_typography.dart';
import 'package:gu_ui/src/widgets/primitives/gu_button.dart';

import '../helpers/pump_app.dart';

const Key _openKey = ValueKey<String>('host.open');
const Key _scrimKey = ValueKey<String>('SHT-12.scrim');
const Key _closeKey = ValueKey<String>('SHT-12.close');
const Key _confirmKey = ValueKey<String>('SHT-12.confirm');
const Key _discardKey = ValueKey<String>('DLG-25.discard');

const String _title = 'Katılım onayı';
const EdgeInsets _notch = EdgeInsets.only(top: 47, bottom: 34);

/// `showGuSheet` sonucu.
class _Result {
  String? value;
  bool done = false;
}

Widget _host(
  _Result result,
  WidgetBuilder builder, {
  bool isDismissible = true,
  bool enableDrag = true,
  bool reduceMotion = false,
}) => Material(
  child: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: Builder(
        builder: (context) => Center(
          child: GuButton(
            key: _openKey,
            label: 'Aç',
            onPressed: () => unawaited(
              showGuSheet<String>(
                context,
                scrimKey: _scrimKey,
                barrierLabel: 'Arka plan',
                isDismissible: isDismissible,
                enableDrag: enableDrag,
                builder: builder,
              ).then((value) {
                result
                  ..value = value
                  ..done = true;
              }),
            ),
          ),
        ),
      ),
    ),
  ),
);

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(_openKey));
  await tester.pumpAndSettle();
}

/// Sheet yüzeyi (çerçevenin en dıştaki `DecoratedBox`'ı; sürükleme ve giriş
/// kaymasını içerir).
Finder get _surface => find
    .descendant(
      of: find.byType(GuSheetFrame),
      matching: find.byType(DecoratedBox),
    )
    .first;

Finder get _handle => find.byWidgetPredicate(
  (w) =>
      w is DecoratedBox &&
      (w.decoration as BoxDecoration).borderRadius == GuRadius.borderHandle,
);

Widget _rows(int count) => Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    for (var i = 0; i < count; i++)
      SizedBox(height: 50, child: Center(child: Text('Satır $i'))),
  ],
);

GuSheetFrame _frame({
  Widget body = const SizedBox(height: 100),
  bool footer = true,
  bool full = false,
  bool menu = false,
  bool flush = false,
  Future<bool> Function()? onWillClose,
  VoidCallback? onClose,
}) => GuSheetFrame(
  title: _title,
  closeSemanticLabel: 'Kapat',
  closeKey: _closeKey,
  full: full,
  menu: menu,
  flush: flush,
  onWillClose: onWillClose,
  onClose: onClose,
  footer: footer
      ? [GuButton(key: _confirmKey, label: 'Katılımı onayla', onPressed: () {})]
      : null,
  body: body,
);

void main() {
  group('T-07 · GuSheetFrame', () {
    testWidgets('T-07 · GuSheetFrame · yerleşim açık + koyu: alta yaslı yüzey '
        '(topXl, e3, koyu üst kenarlık), tutamaç 36×4, başlık + X, footer + '
        'alt güvenli alan, scrim overlayScrim', (tester) async {
      for (final (mode, colors, shadows, border) in [
        (ThemeMode.light, GuColors.light, GuShadows.light, 0.0),
        (ThemeMode.dark, GuColors.dark, GuShadows.dark, 1.0),
      ]) {
        final result = _Result();
        await tester.pumpApp(
          _host(result, (_) => _frame()),
          theme: mode,
          viewPadding: _notch,
        );
        await _open(tester);

        // kenarlık + tutamaç (8 + 4) + başlık (6 + 48 + 6) + gövde (100 + 16)
        // + footer (1 + 12 + 48 + 12 + 34).
        final height = border + 12 + 60 + 116 + 107;
        final top = 844 - height;
        expect(
          tester.getRect(_surface),
          Rect.fromLTWH(0, top, 390, height),
          reason: '$mode',
        );
        final box =
            tester.widget<DecoratedBox>(_surface).decoration as BoxDecoration;
        expect(box.color, colors.bgSurfaceRaised);
        expect(box.borderRadius, GuRadius.topXl);
        expect(box.boxShadow, shadows.e3);
        expect(
          box.border,
          mode == ThemeMode.dark
              ? Border(top: BorderSide(color: colors.borderDefault))
              : null,
        );

        expect(
          tester.getRect(_handle),
          Rect.fromLTWH(
            (390 - GuSizes.sheetHandleWidth) / 2,
            top + border + GuSizes.sheetHandleTop,
            GuSizes.sheetHandleWidth,
            GuSizes.sheetHandleHeight,
          ),
        );
        expect(
          (tester.widget<DecoratedBox>(_handle).decoration as BoxDecoration)
              .color,
          colors.borderDefault,
        );

        final title = tester.widget<Text>(find.text(_title));
        expect(title.style, GuTypography.resolve(colors).titleM);
        expect(
          tester.getTopLeft(find.text(_title)).dx,
          GuSizes.sheetHeadPaddingLeft,
        );
        expect(
          tester.getRect(find.byKey(_closeKey)),
          Rect.fromLTWH(390 - 8 - 48, top + border + 12 + 6, 48, 48),
        );
        // css:277 `.sheet-foot .btn{flex:1}` + alt güvenli alan (K-07).
        expect(
          tester.getRect(find.byKey(_confirmKey)),
          const Rect.fromLTWH(16, 844 - 34 - 12 - 48, 358, 48),
        );

        expect(
          tester
              .widget<AnimatedModalBarrier>(find.byType(AnimatedModalBarrier))
              .color
              .value,
          colors.overlayScrim,
        );
        // Scrim anahtarı sheet'in üstünde kalan bandı gösterir.
        expect(
          tester.getRect(find.byKey(_scrimKey)),
          Rect.fromLTWH(0, 0, 390, top),
        );
      }
    });

    testWidgets('T-07 · GuSheetFrame · varyantlar: en çok %90 / menu %80 / '
        'full %90 (ekran − üst inset); flush dolgusu; footer yoksa alt '
        'güvenli alan gövdede; uzun gövde kayar', (tester) async {
      const usable = 844 - 47;
      Future<void> pump(GuSheetFrame frame) async {
        await tester.pumpApp(
          _host(_Result(), (_) => frame),
          viewPadding: _notch,
        );
        await _open(tester);
      }

      EdgeInsetsGeometry? bodyPadding() => tester
          .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
          .padding;
      ScrollPosition position() =>
          tester.state<ScrollableState>(find.byType(Scrollable)).position;

      await pump(_frame(body: _rows(40), footer: false));
      expect(
        tester.getRect(_surface).height,
        moreOrLessEquals(usable * GuSizes.sheetMaxHeightRatio),
      );
      expect(tester.getRect(_surface).bottom, 844);
      expect(position().maxScrollExtent, greaterThan(0));
      expect(
        bodyPadding(),
        const EdgeInsets.only(left: 16, right: 16, bottom: 16 + 34),
      );

      await pump(_frame(body: _rows(40), menu: true, flush: true));
      expect(
        tester.getRect(_surface).height,
        moreOrLessEquals(usable * GuSizes.sheetMenuMaxHeightRatio),
      );
      // Footer varken güvenli alan footer'dadır.
      expect(bodyPadding(), const EdgeInsets.only(bottom: 8));

      await pump(_frame(full: true, footer: false, flush: true));
      expect(
        tester.getRect(_surface).height,
        moreOrLessEquals(usable * GuSizes.sheetFullHeightRatio),
      );
      expect(position().maxScrollExtent, 0);
      expect(bodyPadding(), const EdgeInsets.only(bottom: 8 + 34));
    });

    testWidgets('T-07 · GuSheetFrame · kapanma yolları: scrim, X, geri tuşu, '
        'aşağı sürükleme (120 → kalır ve yerine döner, 121 → kapanır)', (
      tester,
    ) async {
      Future<_Result> opened() async {
        final result = _Result();
        await tester.pumpApp(_host(result, (_) => _frame()));
        await _open(tester);
        expect(find.byType(GuSheetFrame), findsOneWidget);
        return result;
      }

      Future<void> expectClosed(_Result result) async {
        await tester.pumpAndSettle();
        expect(find.byType(GuSheetFrame), findsNothing);
        expect(result.done, isTrue);
        expect(result.value, isNull);
      }

      var result = await opened();
      await tester.tap(find.byKey(_scrimKey));
      await expectClosed(result);

      result = await opened();
      await tester.tap(find.byKey(_closeKey));
      await expectClosed(result);

      result = await opened();
      await tester.binding.handlePopRoute();
      await expectClosed(result);

      result = await opened();
      final rest = tester.getRect(_surface);
      final gesture = await tester.startGesture(
        tester.getCenter(find.text(_title)),
      );
      await gesture.moveBy(const Offset(0, GuSizes.sheetDragCloseThreshold));
      await tester.pump();
      // Parmağı izler (ui.js:172 `translateY(dy)`).
      expect(
        tester.getRect(_surface).top,
        rest.top + GuSizes.sheetDragCloseThreshold,
      );
      await gesture.up();
      await tester.pump();
      await tester.pump(GuMotion.base ~/ 2);
      // Eşik aşılmadı: `GuMotion.base` ile yerine döner.
      expect(tester.getRect(_surface).top, greaterThan(rest.top));
      expect(
        tester.getRect(_surface).top,
        lessThan(rest.top + GuSizes.sheetDragCloseThreshold),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(_surface), rest);
      expect(result.done, isFalse);

      await tester.drag(
        find.text(_title),
        const Offset(0, GuSizes.sheetDragCloseThreshold + 1),
      );
      await expectClosed(result);
    });

    testWidgets('T-07 · GuSheetFrame · onWillClose false → dört yolda da açık '
        'kalır, true → kapanır (DLG-25 akışı dahil); onClose verilirse pop '
        'yerine o çağrılır; isDismissible / enableDrag false', (tester) async {
      var allow = false;
      var asked = 0;
      var result = _Result();
      await tester.pumpApp(
        _host(
          result,
          (_) => _frame(
            onWillClose: () async {
              asked++;
              return allow;
            },
          ),
        ),
      );
      await _open(tester);
      final rest = tester.getRect(_surface);

      await tester.tap(find.byKey(_scrimKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_closeKey));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.drag(find.text(_title), const Offset(0, 200));
      await tester.pumpAndSettle();
      expect(asked, 4);
      expect(result.done, isFalse);
      // Reddedilen sürükleme yerine döner.
      expect(tester.getRect(_surface), rest);

      allow = true;
      await tester.tap(find.byKey(_closeKey));
      await tester.pumpAndSettle();
      expect(asked, 5);
      expect(result.done, isTrue);
      expect(find.byType(GuSheetFrame), findsNothing);

      // DLG-25 akışı: kapı sheet'in üstünde dialog açar; onay dialogu, ardından
      // sheet'i kapatır.
      result = _Result();
      await tester.pumpApp(
        _host(
          result,
          (context) => _frame(
            onWillClose: () async =>
                await showGuDialog<bool>(
                  context,
                  builder: (dialog) => GuDialogFrame(
                    title: 'Değişiklikler kaydedilmedi',
                    actions: [
                      GuButton(
                        key: _discardKey,
                        label: 'Kaydetmeden çık',
                        onPressed: () => Navigator.of(dialog).pop(true),
                      ),
                    ],
                  ),
                ) ??
                false,
          ),
        ),
      );
      await _open(tester);
      await tester.tap(find.byKey(_closeKey));
      await tester.pumpAndSettle();
      expect(find.byType(GuDialogFrame), findsOneWidget);
      expect(find.byType(GuSheetFrame), findsOneWidget);
      await tester.tap(find.byKey(_discardKey));
      await tester.pumpAndSettle();
      expect(find.byType(GuDialogFrame), findsNothing);
      expect(find.byType(GuSheetFrame), findsNothing);
      expect(result.done, isTrue);

      // onClose: kapatmak çağıranın işi → çerçeve pop etmez.
      var closed = 0;
      result = _Result();
      await tester.pumpApp(
        _host(result, (_) => _frame(onClose: () => closed++)),
      );
      await _open(tester);
      await tester.tap(find.byKey(_closeKey));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(closed, 2);
      expect(result.done, isFalse);
      expect(find.byType(GuSheetFrame), findsOneWidget);

      result = _Result();
      await tester.pumpApp(
        _host(
          result,
          (_) => _frame(),
          isDismissible: false,
          enableDrag: false,
        ),
      );
      await _open(tester);
      await tester.tap(find.byKey(_scrimKey));
      await tester.drag(find.text(_title), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(result.done, isFalse);
      expect(tester.getRect(_surface).bottom, 844);
      // Geri tuşu yine kapatır.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(result.done, isTrue);
    });

    testWidgets('T-07 · GuSheetFrame · gövdeden sürükleme: kaydırılmışken '
        'içerik kayar; baştayken aşağı çekme çerçeveyi sürükler, geri itme '
        'azaltır, eşiği aşınca kapanır', (tester) async {
      final result = _Result();
      await tester.pumpApp(
        _host(result, (_) => _frame(body: _rows(40), footer: false)),
      );
      await _open(tester);
      final rest = tester.getRect(_surface);
      final body = find.byType(SingleChildScrollView);
      ScrollPosition position() =>
          tester.state<ScrollableState>(find.byType(Scrollable)).position;

      // Kaydırılmış gövde: aşağı çekme yalnızca içeriği geri kaydırır.
      await tester.drag(body, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(position().pixels, greaterThan(0));
      await tester.drag(body, const Offset(0, 150));
      await tester.pumpAndSettle();
      expect(tester.getRect(_surface), rest);
      position().jumpTo(0);
      await tester.pump();

      // Baştan aşağı çek (150), geri it (100) → 50 kalır; bırakınca döner.
      final gesture = await tester.startGesture(tester.getCenter(body));
      await gesture.moveBy(const Offset(0, 20));
      await gesture.moveBy(const Offset(0, 150));
      await tester.pump();
      expect(tester.getRect(_surface).top, rest.top + 150);
      await gesture.moveBy(const Offset(0, -100));
      await tester.pump();
      expect(tester.getRect(_surface).top, rest.top + 50);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.getRect(_surface), rest);
      expect(result.done, isFalse);

      position().jumpTo(0);
      await tester.pump();
      await tester.drag(body, const Offset(0, 200));
      await tester.pumpAndSettle();
      expect(result.done, isTrue);
      expect(find.byType(GuSheetFrame), findsNothing);
    });

    testWidgets('T-07 · GuSheetFrame · klavye (viewInsets.bottom 320): çerçeve '
        'klavyenin üstünde biter, kalan alanı aşmaz, gövde kayar', (
      tester,
    ) async {
      await tester.pumpApp(
        _host(_Result(), (_) => _frame(body: _rows(40))),
        viewPadding: _notch,
        keyboardInset: 320,
      );
      await _open(tester);

      // Kalan alan: 844 − 47 − 320 = 477 (< %90 × 797).
      expect(
        tester.getRect(_surface),
        const Rect.fromLTRB(0, 47, 390, 844 - 320),
      );
      // Klavye açıkken alt güvenli alan payı düşer.
      expect(tester.getRect(find.byKey(_confirmKey)).bottom, 844 - 320 - 12);

      final last = find.text('Satır 39');
      await tester.dragUntilVisible(
        last,
        find.byType(SingleChildScrollView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(last).bottom,
        lessThanOrEqualTo(tester.getRect(find.byKey(_confirmKey)).top),
      );
      expect(tester.getRect(_surface).bottom, 844 - 320);
    });

    testWidgets('T-07 · GuSheetFrame · giriş alttan kayar (sheetEnter); '
        'azaltılmış harekette anında; Semantics (rota adı, scrim etiketi); '
        '768 dp → 480 sütun', (tester) async {
      await tester.pumpApp(_host(_Result(), (_) => _frame()));
      await tester.tap(find.byKey(_openKey));
      await tester.pump();
      await tester.pump(GuMotion.sheetEnter ~/ 2);
      final sliding = tester.getRect(_surface);
      await tester.pumpAndSettle();
      final rest = tester.getRect(_surface);
      expect(sliding.top, greaterThan(rest.top));
      expect(sliding.top, lessThan(844));

      final semantics = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.text(_title)),
        matchesSemantics(label: _title, isHeader: true, namesRoute: true),
      );
      expect(find.bySemanticsLabel('Arka plan'), findsOneWidget);
      expect(find.bySemanticsLabel('Kapat'), findsOneWidget);
      semantics.dispose();

      await tester.pumpApp(
        _host(_Result(), (_) => _frame(), reduceMotion: true),
      );
      await tester.tap(find.byKey(_openKey));
      await tester.pump();
      await tester.pump();
      expect(tester.getRect(_surface), rest);
      expect(tester.hasRunningAnimations, isFalse);

      await tester.pumpApp(
        _host(_Result(), (_) => _frame()),
        size: const Size(768, 1024),
      );
      await _open(tester);
      expect(tester.getRect(_surface).left, (768 - 480) / 2);
      expect(tester.getRect(_surface).width, 480);
      expect(tester.getRect(_surface).bottom, 1024);
    });
  });
}

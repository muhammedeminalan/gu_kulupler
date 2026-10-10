// T-07 · GuToast (widget-catalog #42a; css:290–294; shell.js:20–21; CD-98).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../helpers/pump_app.dart';

Widget _host(Widget child) =>
    Column(mainAxisSize: MainAxisSize.min, children: [child]);

Finder _within(Type type) =>
    find.descendant(of: find.byType(GuToast), matching: find.byType(type));

BoxDecoration _decoration(WidgetTester tester) =>
    tester.widget<DecoratedBox>(_within(DecoratedBox).first).decoration
        as BoxDecoration;

void main() {
  group('T-07 · GuToast', () {
    testWidgets('T-07 · GuToast · 3 tür: ikon 18 + şerit rengi, zemin '
        'text.heading, metin bg.surface, radius sm + e2, dolgu 12 / 8 / 12 / '
        '14 + şerit 4; canlı bölge; eylemsiz', (tester) async {
      final handle = tester.ensureSemantics();
      const c = GuColors.light;
      final expected = {
        GuToastKind.success: (GuIcons.circleCheck, c.stateSuccess),
        GuToastKind.error: (GuIcons.triangleAlert, c.stateDanger),
        GuToastKind.info: (GuIcons.info, c.stateInfo),
      };
      expect(expected.keys, GuToastKind.values);
      const message = 'Değişiklikler kaydedildi.';

      for (final MapEntry(key: kind, value: (glyph, accent))
          in expected.entries) {
        await tester.pumpApp(
          _host(
            GuToast(
              kind: kind,
              text: message,
              onClose: () {},
              closeSemanticLabel: 'Kapat',
            ),
          ),
        );
        final reason = '$kind';
        expect(kind.icon, glyph, reason: reason);
        expect(kind.colorOf(c), accent, reason: reason);
        final decoration = _decoration(tester);
        expect(decoration.color, c.textHeading, reason: reason);
        expect(decoration.borderRadius, GuRadius.borderSm, reason: reason);
        expect(decoration.boxShadow, GuShadows.light.e2, reason: reason);
        final icon = tester.widget<GuIcon>(_within(GuIcon).first);
        expect(icon.icon, glyph, reason: reason);
        expect(icon.size, GuSizes.toastIcon, reason: reason);
        expect(icon.color, accent, reason: reason);
        expect(
          DefaultTextStyle.of(tester.element(find.text(message))).style,
          GuTypography.resolve(c).toast,
          reason: reason,
        );
        expect(
          DefaultTextStyle.of(tester.element(find.text(message))).style.color,
          c.bgSurface,
          reason: reason,
        );
        // 12 + kapat 32 + 12.
        expect(tester.getSize(find.byType(GuToast)), const Size(390, 56));
        expect(
          tester.getTopLeft(_within(GuIcon).first).dx,
          GuSizes.toastAccent + GuSizes.toastPaddingLeft,
          reason: reason,
        );
        expect(
          tester.getTopLeft(find.text(message)).dx,
          GuSizes.toastAccent +
              GuSizes.toastPaddingLeft +
              GuSizes.toastIcon +
              GuSizes.toastGap,
          reason: reason,
        );
        expect(
          tester.getTopRight(find.byType(GuIconButton)).dx,
          390 - GuSizes.toastPaddingRight,
          reason: reason,
        );
        // `role="alert"` / `status` + `aria-live`.
        expect(
          tester.getSemantics(find.byType(GuToast)),
          isSemantics(isLiveRegion: true),
          reason: reason,
        );
        expect(_within(GuActionSurface), findsOneWidget, reason: reason);
      }
      handle.dispose();
    });

    testWidgets('T-07 · GuToast · eylem (36, dolgu 10, radius 8, CD-98 '
        'rengi + toastAction) ve kapat (32 / ikon 16, renk devralır) → '
        'callback + Semantics; açık / koyu', (tester) async {
      final handle = tester.ensureSemantics();
      final actionKey = GuKey.action('TST-27.undo');
      final closeKey = GuKey.action('TST-27.close');

      for (final (theme, colors, component) in [
        (ThemeMode.light, GuColors.light, GuComponentColors.light),
        (ThemeMode.dark, GuColors.dark, GuComponentColors.dark),
      ]) {
        var actions = 0;
        var closes = 0;
        await tester.pumpApp(
          _host(
            GuToast(
              kind: GuToastKind.success,
              text: 'Ayşe Demir onaylandı.',
              actionLabel: 'Geri al',
              onAction: () => actions++,
              actionKey: actionKey,
              onClose: () => closes++,
              closeKey: closeKey,
              closeSemanticLabel: 'Kapat',
            ),
          ),
          theme: theme,
        );
        final reason = '$theme';
        // 12 + eylem 36 + 12.
        expect(tester.getSize(find.byType(GuToast)), const Size(390, 60));
        expect(_decoration(tester).color, colors.textHeading, reason: reason);

        final action = find.byKey(actionKey);
        expect(tester.getSize(action).height, GuSizes.toastActionHeight);
        final label = tester.widget<Text>(find.text('Geri al'));
        expect(
          label.style,
          GuTypography.resolve(
            colors,
          ).toastAction.copyWith(color: component.toastActionForeground),
          reason: reason,
        );
        expect(
          tester.getTopLeft(find.text('Geri al')).dx -
              tester.getTopLeft(action).dx,
          GuSizes.toastActionPaddingX,
        );
        final actionBox =
            tester
                    .widget<DecoratedBox>(
                      find.descendant(
                        of: action,
                        matching: find.byType(DecoratedBox),
                      ),
                    )
                    .decoration
                as BoxDecoration;
        expect(actionBox.color, component.toastActionBackground);
        expect(actionBox.borderRadius, GuRadius.borderSkeleton);

        final close = tester.widget<GuIconButton>(find.byKey(closeKey));
        expect(close.icon, GuIcons.x);
        expect(close.size, GuIconButtonSize.xs);
        expect(close.iconSize, GuSizes.toastCloseIcon);
        expect(
          tester.getSize(find.byKey(closeKey)),
          const Size.square(GuSizes.toastCloseButton),
        );
        expect(
          tester
              .widget<GuIcon>(
                find.descendant(
                  of: find.byKey(closeKey),
                  matching: find.byType(GuIcon),
                ),
              )
              .color,
          colors.bgSurface,
          reason: reason,
        );

        expect(find.bySemanticsLabel('Geri al'), findsOneWidget);
        expect(find.bySemanticsLabel('Kapat'), findsOneWidget);
        await tester.tap(action);
        expect((actions, closes), (1, 0));
        await tester.tap(find.byKey(closeKey));
        expect((actions, closes), (1, 1));
      }
      // CD-98 / K-41: koyu eylem metni `bg.surface` koyu.
      expect(
        GuComponentColors.dark.toastActionForeground,
        GuColors.dark.bgSurface,
      );
      handle.dispose();
    });

    testWidgets('T-07 · GuToast · uzun metin 320 dp + ölçek 1.6: sarar, '
        'eylem satırın en çok yarısı, taşma yok', (tester) async {
      const message =
          'Çevrimdışısın. Bu işlem için internet bağlantısı gerekli.';
      final actionKey = GuKey.action('TST-41.action');
      await tester.pumpApp(
        _host(
          GuToast(
            kind: GuToastKind.error,
            text: message,
            actionLabel: 'Biletini göster',
            onAction: () {},
            actionKey: actionKey,
            onClose: () {},
            closeSemanticLabel: 'Kapat',
          ),
        ),
        size: const Size(320, 640),
        textScale: 1.6,
      );
      expect(tester.takeException(), isNull);
      final toast = tester.getRect(find.byType(GuToast));
      expect(toast.width, 320);
      // Tek satır 13 × 1.6 × 1.4 ≈ 29 → birden çok satır.
      expect(tester.getSize(find.text(message)).height, greaterThan(60));
      const rowWidth =
          320 -
          GuSizes.toastAccent -
          GuSizes.toastPaddingLeft -
          GuSizes.toastPaddingRight;
      expect(
        tester.getSize(find.byKey(actionKey)).width,
        lessThanOrEqualTo(rowWidth / 2),
      );
      expect(
        tester.getRect(find.byType(GuIconButton)).right,
        320 - GuSizes.toastPaddingRight,
      );
    });

    testWidgets('T-07 · GuToast · tür değişince ikon ve şerit yeniden '
        'boyanır; eylem etiketi eylemsiz verilemez', (tester) async {
      late StateSetter setState;
      var kind = GuToastKind.info;
      await tester.pumpApp(
        StatefulBuilder(
          builder: (context, set) {
            setState = set;
            return _host(
              GuToast(
                kind: kind,
                text: 'Bağlantı kopyalandı.',
                onClose: () {},
                closeSemanticLabel: 'Kapat',
              ),
            );
          },
        ),
      );
      final paint = find.descendant(
        of: find.byType(GuToast),
        matching: find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter != null,
        ),
      );
      final before = tester.widget<CustomPaint>(paint).painter!;
      expect(tester.widget<GuIcon>(_within(GuIcon).first).icon, GuIcons.info);
      setState(() => kind = GuToastKind.error);
      await tester.pump();
      final after = tester.widget<CustomPaint>(paint).painter!;
      expect(
        tester.widget<GuIcon>(_within(GuIcon).first).icon,
        GuIcons.triangleAlert,
      );
      expect(after.shouldRepaint(before), isTrue);
      expect(after.shouldRepaint(after), isFalse);

      expect(
        () => GuToast(
          kind: GuToastKind.info,
          text: 'x',
          actionLabel: 'Geri al',
          onClose: () {},
          closeSemanticLabel: 'Kapat',
        ),
        throwsAssertionError,
      );
    });
  });
}

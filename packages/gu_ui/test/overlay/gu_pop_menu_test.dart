// T-07 · GuPopMenu + GuPopMenuItem + showGuPopMenu (widget-catalog #41;
// A.2 #41; css:279–280; ui.js:191; sheets.js:11–12; CD-29, CD-83, CD-113).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/src/icons/gu_icon.dart';
import 'package:gu_ui/src/icons/gu_icons.dart';
import 'package:gu_ui/src/overlay/gu_pop_menu.dart';
import 'package:gu_ui/src/tokens/gu_colors.dart';
import 'package:gu_ui/src/tokens/gu_motion.dart';
import 'package:gu_ui/src/tokens/gu_opacity.dart';
import 'package:gu_ui/src/tokens/gu_radius.dart';
import 'package:gu_ui/src/tokens/gu_shadows.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/tokens/gu_typography.dart';
import 'package:gu_ui/src/widgets/primitives/gu_button.dart';

import '../helpers/pump_app.dart';

const Key _openKey = ValueKey<String>('host.open');
const Key _scrimKey = ValueKey<String>('EVT-02.scrim');
const Key _reminderKey = ValueKey<String>('EVT-02.menu.reminder');
const Key _shareKey = ValueKey<String>('EVT-02.menu.share');
const Key _reportKey = ValueKey<String>('EVT-02.menu.report');
const Key _trKey = ValueKey<String>('SHT-01.select.tr');

const EdgeInsets _notch = EdgeInsets.only(top: 47, bottom: 34);

/// `showGuPopMenu` sonucu.
class _Result {
  String? value;
  bool done = false;
}

Widget _host(
  _Result result,
  List<Widget> items, {
  bool reduceMotion = false,
}) => Material(
  child: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: Builder(
        builder: (context) => Align(
          alignment: Alignment.bottomLeft,
          child: GuButton(
            key: _openKey,
            label: 'Aç',
            onPressed: () => unawaited(
              showGuPopMenu<String>(
                context,
                items: items,
                scrimKey: _scrimKey,
                barrierLabel: 'Arka plan',
                semanticLabel: 'Etkinlik menüsü',
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

/// Menü yüzeyi (kutunun `DecoratedBox`'ı).
Finder get _surface => find
    .descendant(of: find.byType(GuPopMenu), matching: find.byType(DecoratedBox))
    .first;

/// EVT-MENU (`sheets.js:12`) + durum örnekleri.
List<Widget> _items(List<String> log, {String reminder = 'Hatırlatıcı'}) => [
  GuPopMenuItem(
    key: _reminderKey,
    label: reminder,
    icon: GuIcons.bellRing,
    value: 'reminder',
    onTap: () => log.add('reminder'),
  ),
  GuPopMenuItem(
    key: _shareKey,
    label: 'Paylaş',
    icon: GuIcons.share2,
    value: 'share',
    disabled: true,
    onTap: () => log.add('share'),
  ),
  GuPopMenuItem(
    key: _reportKey,
    label: 'Şikâyet et',
    icon: GuIcons.flag,
    danger: true,
    onTap: () => log.add('report'),
  ),
  const GuPopMenuItem(key: _trKey, label: 'Türkçe — TR', selected: true),
];

void main() {
  group('T-07 · GuPopMenu', () {
    testWidgets('T-07 · GuPopMenu · konum (CD-83): üst inset + 48, sağ 12; en '
        'az genişlik 200, uzun etiketle genişler; yüzey (md, e2, border.soft, '
        'dolgu 6); scrim saydam; 768 dp → 480 sütununun sağı', (tester) async {
      for (final (mode, colors, shadows) in [
        (ThemeMode.light, GuColors.light, GuShadows.light),
        (ThemeMode.dark, GuColors.dark, GuShadows.dark),
      ]) {
        await tester.pumpApp(
          _host(_Result(), _items([])),
          theme: mode,
          viewPadding: _notch,
        );
        await _open(tester);

        final rect = tester.getRect(_surface);
        expect(rect.top, 47 + GuSizes.popMenuTop, reason: '$mode');
        expect(rect.right, 390 - GuSizes.popMenuRight);
        expect(rect.width, GuSizes.popMenuMinWidth);
        final box =
            tester.widget<DecoratedBox>(_surface).decoration as BoxDecoration;
        expect(box.color, colors.bgSurfaceRaised);
        expect(box.borderRadius, GuRadius.borderMd);
        expect(box.boxShadow, shadows.e2);
        expect(box.border, Border.all(color: colors.borderSoft));

        // Öğe: kenarlık 1 + dolgu 6 içeride, en az 48 yüksek.
        expect(
          tester.getRect(find.byKey(_reminderKey)),
          Rect.fromLTWH(
            rect.left + 7,
            rect.top + 7,
            GuSizes.popMenuMinWidth - 14,
            GuSizes.popMenuTileMinHeight,
          ),
        );
        expect(rect.height, 4 * GuSizes.popMenuTileMinHeight + 14);

        // ui.js:191 `background:transparent`: renkli bariyer yok.
        expect(find.byType(AnimatedModalBarrier), findsNothing);
        // Scrim anahtarı menünün altında kalan bandı gösterir.
        expect(
          tester.getRect(find.byKey(_scrimKey)),
          Rect.fromLTRB(0, rect.bottom, 390, 844),
        );
      }

      await tester.pumpApp(
        _host(
          _Result(),
          _items([], reminder: 'Etkinlik hatırlatıcısını değiştir'),
        ),
      );
      await _open(tester);
      final wide = tester.getRect(_surface);
      expect(wide.width, greaterThan(GuSizes.popMenuMinWidth));
      expect(wide.right, 390 - GuSizes.popMenuRight);
      expect(wide.top, GuSizes.popMenuTop);

      await tester.pumpApp(
        _host(_Result(), _items([])),
        size: const Size(768, 1024),
      );
      await _open(tester);
      expect(
        tester.getRect(_surface).right,
        (768 + 480) / 2 - GuSizes.popMenuRight,
      );
    });

    testWidgets('T-07 · GuPopMenuItem · görünüm: ikon 20 + bodyM, danger, '
        'seçili onay işareti, devre dışı opaklık, basılı zemin; dokunma → '
        'menü kapanır, value döner, sonra onTap; devre dışı yok sayılır', (
      tester,
    ) async {
      final log = <String>[];
      final result = _Result();
      await tester.pumpApp(_host(result, _items(log)));
      await _open(tester);
      const colors = GuColors.light;
      final text = GuTypography.resolve(colors);

      GuIcon iconOf(Key key) => tester.widget<GuIcon>(
        find.descendant(of: find.byKey(key), matching: find.byType(GuIcon)),
      );
      double opacityOf(Key key) => tester
          .widget<Opacity>(
            find.descendant(
              of: find.byKey(key),
              matching: find.byType(Opacity),
            ),
          )
          .opacity;
      Color? backgroundOf(Key key) =>
          (tester
                      .widget<DecoratedBox>(
                        find.descendant(
                          of: find.byKey(key),
                          matching: find.byType(DecoratedBox),
                        ),
                      )
                      .decoration
                  as BoxDecoration)
              .color;

      expect(iconOf(_reminderKey).icon, GuIcons.bellRing);
      expect(iconOf(_reminderKey).size, GuSizes.icon20);
      expect(iconOf(_reminderKey).color, colors.textHeading);
      expect(
        tester.widget<Text>(find.text('Hatırlatıcı')).style,
        text.bodyM.copyWith(color: colors.textHeading),
      );
      expect(iconOf(_reportKey).color, colors.stateDanger);
      expect(
        tester.widget<Text>(find.text('Şikâyet et')).style,
        text.bodyM.copyWith(color: colors.stateDanger),
      );
      expect(iconOf(_trKey).icon, GuIcons.check);
      expect(iconOf(_trKey).size, GuSizes.icon18);
      expect(iconOf(_trKey).color, colors.brandPrimaryText);
      expect(opacityOf(_shareKey), GuOpacity.disabled);
      expect(opacityOf(_reminderKey), 1);

      // Devre dışı öğe: menü açık kalır, onTap çağrılmaz.
      await tester.tap(find.byKey(_shareKey));
      await tester.pumpAndSettle();
      expect(log, isEmpty);
      expect(result.done, isFalse);
      expect(find.byType(GuPopMenu), findsOneWidget);

      // Basılı zemin (css:212, K-53).
      expect(backgroundOf(_reminderKey), isNull);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_reminderKey)),
      );
      await tester.pump();
      expect(backgroundOf(_reminderKey), colors.bgSurfaceMuted);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(log, ['reminder']);
      expect(result.done, isTrue);
      expect(result.value, 'reminder');
      expect(find.byType(GuPopMenu), findsNothing);

      // `value` yoksa sonuç null; onTap yine çağrılır.
      final second = _Result();
      await tester.pumpApp(_host(second, _items(log)));
      await _open(tester);
      await tester.tap(find.byKey(_reportKey));
      await tester.pumpAndSettle();
      expect(log, ['reminder', 'report']);
      expect(second.done, isTrue);
      expect(second.value, isNull);
    });

    testWidgets('T-07 · GuPopMenu · kapanma: scrim, geri tuşu, Esc → sonuç '
        'null; giriş solma + ölçek, azaltılmış harekette anında; Semantics '
        '(menü adı, scrim etiketi); rota dışında öğe yalnızca onTap', (
      tester,
    ) async {
      Future<_Result> opened() async {
        final result = _Result();
        await tester.pumpApp(_host(result, _items([])));
        await _open(tester);
        expect(find.byType(GuPopMenu), findsOneWidget);
        return result;
      }

      Future<void> expectClosed(_Result result) async {
        await tester.pumpAndSettle();
        expect(find.byType(GuPopMenu), findsNothing);
        expect(result.done, isTrue);
        expect(result.value, isNull);
      }

      var result = await opened();
      final semantics = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Etkinlik menüsü'), findsOneWidget);
      expect(find.bySemanticsLabel('Arka plan'), findsOneWidget);
      semantics.dispose();
      await tester.tap(find.byKey(_scrimKey));
      await expectClosed(result);

      result = await opened();
      await tester.binding.handlePopRoute();
      await expectClosed(result);

      result = await opened();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await expectClosed(result);

      await tester.pumpApp(_host(_Result(), _items([])));
      await tester.tap(find.byKey(_openKey));
      await tester.pump();
      await tester.pump(GuMotion.base ~/ 2);
      final fade = tester.widget<FadeTransition>(
        find.ancestor(
          of: find.byType(GuPopMenu),
          matching: find.byType(FadeTransition),
        ),
      );
      expect(fade.opacity.value, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(fade.opacity.value, 1);

      await tester.pumpApp(_host(_Result(), _items([]), reduceMotion: true));
      await tester.tap(find.byKey(_openKey));
      await tester.pump();
      await tester.pump();
      expect(find.byType(GuPopMenu), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);

      // Kutu tek başına (galeri): kapatacak rota yok, yalnızca onTap.
      final log = <String>[];
      await tester.pumpApp(
        Material(
          child: Center(child: GuPopMenu(items: _items(log))),
        ),
      );
      await tester.tap(find.byKey(_reminderKey));
      await tester.pump();
      expect(log, ['reminder']);
      expect(find.byType(GuPopMenu), findsOneWidget);
    });
  });
}

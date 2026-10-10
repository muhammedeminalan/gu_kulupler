// T-07 · GuDialogFrame + showGuDialog (widget-catalog #40; A.2 #40;
// css:266–267, 282–286, 415; ui.js:182–190; CD-29, CD-113, CD-121(7), K-35).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/src/icons/gu_icons.dart';
import 'package:gu_ui/src/overlay/gu_dialog_frame.dart';
import 'package:gu_ui/src/tokens/gu_colors.dart';
import 'package:gu_ui/src/tokens/gu_motion.dart';
import 'package:gu_ui/src/tokens/gu_radius.dart';
import 'package:gu_ui/src/tokens/gu_shadows.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/tokens/gu_typography.dart';
import 'package:gu_ui/src/widgets/primitives/gu_button.dart';
import 'package:gu_ui/src/widgets/primitives/gu_icon_box.dart';

import '../helpers/pump_app.dart';

const Key _openKey = ValueKey<String>('host.open');
const Key _outsideKey = ValueKey<String>('host.outside');
const Key _scrimKey = ValueKey<String>('DLG-25.scrim');
const Key _saveKey = ValueKey<String>('DLG-25.save');
const Key _discardKey = ValueKey<String>('DLG-25.discard');
const Key _keepKey = ValueKey<String>('DLG-25.keep');
const Key _childKey = ValueKey<String>('DLG-25.child');

const String _title = 'Değişiklikler kaydedilmedi';
const String _body = 'Çıkarsan yaptığın değişiklikler kaybolacak.';

/// `showGuDialog` sonucu.
class _Result {
  String? value;
  bool done = false;
}

Widget _host(
  _Result result,
  WidgetBuilder builder, {
  bool barrierDismissible = true,
  bool reduceMotion = false,
}) => Material(
  child: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: Builder(
        builder: (context) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GuButton(
              key: _openKey,
              label: 'Aç',
              onPressed: () => unawaited(
                showGuDialog<String>(
                  context,
                  scrimKey: _scrimKey,
                  barrierLabel: 'Arka plan',
                  barrierDismissible: barrierDismissible,
                  builder: builder,
                ).then((value) {
                  result
                    ..value = value
                    ..done = true;
                }),
              ),
            ),
            GuButton(key: _outsideKey, label: 'Dışarıda', onPressed: () {}),
          ],
        ),
      ),
    ),
  ),
);

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(_openKey));
  await tester.pumpAndSettle();
}

/// Dialog yüzeyi (çerçevenin en dıştaki `DecoratedBox`'ı).
Finder get _surface => find
    .descendant(
      of: find.byType(GuDialogFrame),
      matching: find.byType(DecoratedBox),
    )
    .first;

/// DLG-25: marka ikonu + üç eylem (`dialogs/DLG-25__light.webp`).
Widget _dlg25(
  BuildContext context, {
  bool danger = false,
  bool dismissable = true,
  String? body = _body,
  Widget? child,
  GuDialogActionsLayout layout = GuDialogActionsLayout.column,
}) => GuDialogFrame(
  title: _title,
  body: body,
  icon: GuIcons.triangleAlert,
  danger: danger,
  dismissable: dismissable,
  actionsLayout: layout,
  actions: [
    GuButton(
      key: _saveKey,
      label: 'Kaydet',
      onPressed: () => Navigator.of(context).pop('save'),
    ),
    GuButton(
      key: _discardKey,
      label: 'Kaydetmeden çık',
      variant: GuButtonVariant.dangerOutline,
      onPressed: () {},
    ),
    if (layout == GuDialogActionsLayout.column)
      GuButton(
        key: _keepKey,
        label: 'Düzenlemeye devam et',
        variant: GuButtonVariant.text,
        onPressed: () {},
      ),
  ],
  child: child,
);

bool _hasFocus(Key key) {
  var found = false;
  FocusManager.instance.primaryFocus?.context?.visitAncestorElements((e) {
    found = e.widget.key == key;
    return !found;
  });
  return found;
}

void main() {
  group('T-07 · GuDialogFrame', () {
    testWidgets('T-07 · GuDialogFrame · içerik + yerleşim açık + koyu: '
        'ortada min(320, ekran − 48), yüzey (lg, e2, koyu kenarlık), ikon '
        'kutusu, başlık / gövde / özel gövde, eylemler tam genişlik aralık '
        '6; row dizilimi ters sıra', (tester) async {
      for (final (mode, colors, shadows, border) in [
        (ThemeMode.light, GuColors.light, GuShadows.light, 0.0),
        (ThemeMode.dark, GuColors.dark, GuShadows.dark, 1.0),
      ]) {
        await tester.pumpApp(
          _host(
            _Result(),
            (context) => _dlg25(
              context,
              danger: mode == ThemeMode.dark,
              child: const SizedBox(key: _childKey, height: 30),
            ),
          ),
          theme: mode,
        );
        await _open(tester);
        final text = GuTypography.resolve(colors);

        final rect = tester.getRect(_surface);
        expect(rect.width, GuSizes.dialogMaxWidth, reason: '$mode');
        expect(rect.center, const Offset(195, 422));
        final box =
            tester.widget<DecoratedBox>(_surface).decoration as BoxDecoration;
        expect(box.color, colors.bgSurfaceRaised);
        expect(box.borderRadius, GuRadius.borderLg);
        expect(box.boxShadow, shadows.e2);
        expect(
          box.border,
          mode == ThemeMode.dark
              ? Border.all(color: colors.borderDefault)
              : null,
        );

        // İkon kutusu 40, sol üstte (dolgu 24 / 20 + kenarlık).
        final iconBox = tester.widget<GuIconBox>(find.byType(GuIconBox));
        expect(
          iconBox.tone,
          mode == ThemeMode.dark ? GuIconBoxTone.danger : GuIconBoxTone.brand,
        );
        expect(
          tester.getRect(find.byType(GuIconBox)),
          Rect.fromLTWH(
            rect.left + 20 + border,
            rect.top + 24 + border,
            GuSizes.dialogIconBox,
            GuSizes.dialogIconBox,
          ),
        );
        expect(tester.widget<Text>(find.text(_title)).style, text.titleM);
        expect(
          tester.widget<Text>(find.text(_body)).style,
          text.bodyS.copyWith(color: colors.textSecondary),
        );
        // css:282 `gap:12px`.
        expect(
          tester.getRect(find.text(_title)).top,
          tester.getRect(find.byType(GuIconBox)).bottom + GuSizes.dialogGap,
        );
        expect(
          tester.getRect(find.byKey(_childKey)).top,
          tester.getRect(find.text(_body)).bottom + GuSizes.dialogGap,
        );

        // css:284–285: dikey, tam genişlik, aralık 6, üst boşluk 12 + 8.
        final save = tester.getRect(find.byKey(_saveKey));
        final discard = tester.getRect(find.byKey(_discardKey));
        final keep = tester.getRect(find.byKey(_keepKey));
        expect(save.left, rect.left + 20 + border);
        expect(save.width, 320 - 40 - 2 * border);
        expect(
          save.top,
          tester.getRect(find.byKey(_childKey)).bottom +
              GuSizes.dialogGap +
              GuSizes.dialogActionsTop,
        );
        expect(discard.top, save.bottom + GuSizes.dialogActionsGap);
        expect(discard.width, save.width);
        expect(keep.top, discard.bottom + GuSizes.dialogActionsGap);
        expect(keep.width, save.width);
        expect(keep.bottom, rect.bottom - 16 - border);
      }

      // 320 dp: genişlik ekran − 2 × 24; ikon ve gövde yok.
      await tester.pumpApp(
        _host(
          _Result(),
          (context) => GuDialogFrame(
            title: _title,
            actions: [GuButton(label: 'Tamam', onPressed: () {})],
          ),
        ),
        size: const Size(320, 640),
      );
      await _open(tester);
      expect(tester.getRect(_surface).width, 320 - 2 * GuSizes.dialogMarginX);
      expect(find.byType(GuIconBox), findsNothing);
      expect(tester.takeException(), isNull);

      // css:286 `.is-row`: `row-reverse`, eşit genişlik.
      await tester.pumpApp(
        _host(
          _Result(),
          (context) => _dlg25(context, layout: GuDialogActionsLayout.row),
        ),
      );
      await _open(tester);
      final first = tester.getRect(find.byKey(_saveKey));
      final second = tester.getRect(find.byKey(_discardKey));
      expect(first.left, second.right + GuSizes.dialogActionsGap);
      expect(first.width, (280 - GuSizes.dialogActionsGap) / 2);
      expect(second.width, first.width);
      expect(first.top, second.top);
    });

    testWidgets('T-07 · GuDialogFrame · kapanma: scrim / geri / Esc kapatır, '
        'eylem sonucu döner; barrierDismissible false → scrim ve Esc '
        'kapatmaz; dismissable false → geri ve scrim kapatmaz', (tester) async {
      Future<_Result> opened({
        bool barrierDismissible = true,
        bool dismissable = true,
      }) async {
        final result = _Result();
        await tester.pumpApp(
          _host(
            result,
            (context) => _dlg25(context, dismissable: dismissable),
            barrierDismissible: barrierDismissible,
          ),
        );
        await _open(tester);
        expect(find.byType(GuDialogFrame), findsOneWidget);
        return result;
      }

      var result = await opened();
      expect(
        tester
            .widget<AnimatedModalBarrier>(find.byType(AnimatedModalBarrier))
            .color
            .value,
        GuColors.light.overlayScrim,
      );
      // Scrim anahtarı dialogun üstünde kalan bandı gösterir.
      expect(
        tester.getRect(find.byKey(_scrimKey)),
        Rect.fromLTRB(0, 0, 390, tester.getRect(_surface).top),
      );
      await tester.tap(find.byKey(_scrimKey));
      await tester.pumpAndSettle();
      expect(result.done, isTrue);
      expect(result.value, isNull);
      expect(find.byType(GuDialogFrame), findsNothing);

      result = await opened();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(result.done, isTrue);

      result = await opened();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(result.done, isTrue);

      result = await opened();
      await tester.tap(find.byKey(_saveKey));
      await tester.pumpAndSettle();
      expect(result.value, 'save');

      result = await opened(barrierDismissible: false);
      await tester.tap(find.byKey(_scrimKey));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(result.done, isFalse);
      expect(find.byType(GuDialogFrame), findsOneWidget);

      // DLG-26 / DLG-27: kapatılamaz.
      result = await opened(dismissable: false);
      await tester.binding.handlePopRoute();
      await tester.tap(find.byKey(_scrimKey));
      await tester.pumpAndSettle();
      expect(result.done, isFalse);
      await tester.tap(find.byKey(_saveKey));
      await tester.pumpAndSettle();
      expect(result.value, 'save');
    });

    testWidgets('T-07 · GuDialogFrame · odak tuzağı: Tab / Shift+Tab dialog '
        'düğmeleri arasında döner, alttaki ekrana çıkmaz', (tester) async {
      await tester.pumpApp(_host(_Result(), _dlg25));
      await _open(tester);

      for (final key in [_saveKey, _discardKey, _keepKey, _saveKey]) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(_hasFocus(key), isTrue, reason: '$key');
        expect(_hasFocus(_outsideKey), isFalse);
        expect(_hasFocus(_openKey), isFalse);
      }
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(_hasFocus(_keepKey), isTrue);
    });

    testWidgets('T-07 · GuDialogFrame · en çok yükseklik %85 + kayar; klavye '
        'üstünde ortalanır; giriş solma + ölçek, azaltılmış harekette '
        'anında; Semantics; 768 dp → 480 sütun', (tester) async {
      final long = List.filled(400, 'uzun gövde').join(' ');
      await tester.pumpApp(
        _host(_Result(), (context) => _dlg25(context, body: long)),
      );
      await _open(tester);
      expect(
        tester.getRect(_surface).height,
        moreOrLessEquals(844 * GuSizes.dialogMaxHeightRatio),
      );
      expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable))
            .position
            .maxScrollExtent,
        greaterThan(0),
      );

      await tester.pumpApp(
        _host(_Result(), (context) => _dlg25(context, body: long)),
        keyboardInset: 320,
      );
      await _open(tester);
      final above = tester.getRect(_surface);
      expect(
        above.height,
        moreOrLessEquals((844 - 320) * GuSizes.dialogMaxHeightRatio),
      );
      expect(above.center.dy, moreOrLessEquals((844 - 320) / 2));

      // css:415 `dialogIn`: opaklık 0 → 1, ölçek .96 → 1.
      await tester.pumpApp(_host(_Result(), _dlg25));
      await tester.tap(find.byKey(_openKey));
      await tester.pump();
      await tester.pump(GuMotion.base ~/ 2);
      final fade = tester.widget<FadeTransition>(
        find.ancestor(
          of: find.byType(GuDialogFrame),
          matching: find.byType(FadeTransition),
        ),
      );
      final scale = tester.widget<ScaleTransition>(
        find.ancestor(
          of: find.byType(GuDialogFrame),
          matching: find.byType(ScaleTransition),
        ),
      );
      expect(fade.opacity.value, inExclusiveRange(0, 1));
      expect(
        scale.scale.value,
        inExclusiveRange(GuMotion.dialogEnterScale, 1),
      );
      await tester.pumpAndSettle();
      expect(fade.opacity.value, 1);
      expect(scale.scale.value, 1);

      final semantics = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.text(_title)),
        matchesSemantics(label: _title, isHeader: true, namesRoute: true),
      );
      expect(find.bySemanticsLabel('Arka plan'), findsOneWidget);
      semantics.dispose();

      await tester.pumpApp(_host(_Result(), _dlg25, reduceMotion: true));
      await tester.tap(find.byKey(_openKey));
      await tester.pump();
      await tester.pump();
      expect(find.byType(GuDialogFrame), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);

      await tester.pumpApp(
        _host(_Result(), _dlg25),
        size: const Size(768, 1024),
      );
      await _open(tester);
      expect(tester.getRect(_surface).width, GuSizes.dialogMaxWidth);
      expect(tester.getRect(_surface).center, const Offset(384, 512));
    });
  });
}

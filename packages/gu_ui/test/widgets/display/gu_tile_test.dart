// T-04 · GuTile (widget-catalog #17; CD-27, K-35; css:211–214).
import 'dart:ui' show SemanticsAction;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

Widget _host(Widget tile) =>
    Column(mainAxisSize: MainAxisSize.min, children: [tile]);

TextStyle _style(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!;

Color? _background(WidgetTester tester) =>
    (tester
                .widget<DecoratedBox>(
                  find.descendant(
                    of: find.byType(GuTile),
                    matching: find.byType(DecoratedBox),
                  ),
                )
                .decoration
            as BoxDecoration)
        .color;

double _opacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find.descendant(of: find.byType(GuTile), matching: find.byType(Opacity)),
    )
    .opacity;

void main() {
  group('T-04 · GuTile', () {
    testWidgets('T-04 · GuTile · yerleşim ve stiller token değerleriyle: min '
        '56, dolgu varyantları, başlık / alt satırlar, chevron, danger, '
        'titleStyle, alignStart', (tester) async {
      const colors = GuColors.light;
      final text = GuTypography.resolve(colors);

      // Yalnız başlık: en az yükseklik 56, tam genişlik.
      await tester.pumpApp(_host(const GuTile(title: 'Tema')));
      expect(tester.getSize(find.byType(GuTile)), const Size(390, 56));
      expect(
        _style(tester, 'Tema'),
        text.bodyM.copyWith(color: colors.textHeading),
      );
      expect(find.byType(GuIcon), findsNothing);

      // Üç satır: 22 + 18 + 16 = 56; dolgu 8 / 10 / 12 → 72 / 76 / 80.
      for (final (padding, height) in [
        (GuTilePadding.normal, 72.0),
        (GuTilePadding.inCard, 76.0),
        (GuTilePadding.notification, 80.0),
      ]) {
        await tester.pumpApp(
          _host(
            GuTile(
              title: 'Tema',
              subtitle: 'Açık',
              sub2: 'Sistem',
              padding: padding,
              leading: const GuIcon(GuIcons.sun, size: GuSizes.icon22),
              trailing: const Text('Aa'),
              chevron: true,
            ),
          ),
        );
        expect(
          tester.getSize(find.byType(GuTile)),
          Size(390, height),
          reason: '$padding',
        );
      }
      expect(
        _style(tester, 'Açık'),
        text.bodyS.copyWith(color: colors.textMuted),
      );
      expect(_style(tester, 'Sistem'), text.caption);
      // Baştaki ikon 16 px içeride, metinle arası 12.
      expect(tester.getTopLeft(find.byType(GuIcon).first).dx, 16);
      expect(tester.getTopLeft(find.text('Tema')).dx, 16 + 22 + 12);
      // trailing: text.muted; chevron 20 px, sağdan 16.
      expect(
        DefaultTextStyle.of(tester.element(find.text('Aa'))).style.color,
        colors.textMuted,
      );
      final chevron = tester.widget<GuIcon>(find.byType(GuIcon).last);
      expect(chevron.icon, GuIcons.chevronRight);
      expect(chevron.size, GuSizes.tileChevron);
      expect(chevron.color, colors.textMuted);
      expect(tester.getTopRight(find.byType(GuIcon).last).dx, 390 - 16);
      expect(
        tester.getTopLeft(find.byType(GuIcon).last).dx -
            tester.getTopRight(find.text('Aa')).dx,
        GuSizes.tileGap,
      );
      // Dikey orta: ikon satırın ortasında.
      expect(tester.getCenter(find.byType(GuIcon).first).dy, 40);

      // danger + titleStyle + alignStart.
      await tester.pumpApp(
        _host(
          GuTile(
            title: 'Hesabı sil',
            subtitle: 'Geri alınamaz',
            danger: true,
            alignStart: true,
            titleStyle: GuTypography.resolve(GuColors.dark).bodyS,
            padding: GuTilePadding.notification,
            leading: const GuIcon(GuIcons.info, size: GuSizes.icon20),
          ),
        ),
        theme: ThemeMode.dark,
      );
      const dark = GuColors.dark;
      final darkText = GuTypography.resolve(dark);
      // titleStyle varsayılan (bodyM + danger rengi) üstüne birleştirilir.
      expect(
        _style(tester, 'Hesabı sil'),
        darkText.bodyM.copyWith(color: dark.stateDanger).merge(darkText.bodyS),
      );
      expect(_style(tester, 'Hesabı sil').fontSize, darkText.bodyS.fontSize);
      // Üstten hizalı: ikon dolgunun hemen altında.
      expect(tester.getTopLeft(find.byType(GuIcon)).dy, 12);

      await tester.pumpApp(
        _host(const GuTile(title: 'Kulüpten ayrıl', danger: true)),
      );
      expect(_style(tester, 'Kulüpten ayrıl').color, colors.stateDanger);
    });

    testWidgets('T-04 · GuTile · dokunma → callback, basılı zemin '
        'bg.surfaceMuted (plain hariç), disabled → çağrılmaz + opaklık .5, '
        'Semantics, dokunma hedefi', (tester) async {
      final handle = tester.ensureSemantics();
      final key = GuKey.action('SET-01.theme');
      var taps = 0;
      Widget tile({bool plain = false, bool disabled = false}) => _host(
        GuTile(
          key: key,
          title: 'Tema',
          onTap: () => taps++,
          plain: plain,
          disabled: disabled,
          chevron: true,
        ),
      );

      await tester.pumpApp(tile());
      await tester.tap(find.byKey(key));
      expect(taps, 1);
      expect(_opacity(tester), 1);
      expect(
        tester.getSemantics(find.byKey(key)),
        matchesSemantics(
          label: 'Tema',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));

      expect(_background(tester), isNull);
      var gesture = await tester.startGesture(
        tester.getCenter(find.byKey(key)),
      );
      await tester.pump(kPressTimeout);
      expect(_background(tester), GuColors.light.bgSurfaceMuted);
      await gesture.up();
      await tester.pump();
      expect(_background(tester), isNull);
      expect(taps, 2);

      // plain: basılı zemin yok.
      await tester.pumpApp(tile(plain: true));
      gesture = await tester.startGesture(tester.getCenter(find.byKey(key)));
      await tester.pump(kPressTimeout);
      expect(_background(tester), isNull);
      await gesture.up();
      await tester.pump();
      expect(taps, 3);

      // disabled.
      await tester.pumpApp(tile(disabled: true));
      await tester.tap(find.byKey(key));
      expect(taps, 3);
      expect(_opacity(tester), GuOpacity.disabled);
      expect(
        tester.getSemantics(find.byKey(key)),
        matchesSemantics(label: 'Tema', isButton: true, hasEnabledState: true),
      );

      // Statik satır (onTap yok): düğme değil.
      await tester.pumpApp(_host(const GuTile(title: 'Sürüm')));
      final data = tester.getSemantics(find.text('Sürüm')).getSemanticsData();
      expect(data.flagsCollection.isButton, isFalse);
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      handle.dispose();
    });

    testWidgets('T-04 · GuTile · 320 dp × metin ölçeği 1.6 + uzun metin → '
        'taşma yok (metin sarar)', (tester) async {
      const long =
          'Gümüşhane Üniversitesi Yazılım ve Yapay Zekâ Topluluğu yönetim '
          'kurulu üyeliği';
      await tester.pumpApp(
        SingleChildScrollView(
          child: GuTile(
            title: long,
            subtitle: long,
            sub2: long,
            leading: const GuIcon(GuIcons.users, size: GuSizes.icon22),
            trailing: const Text('Aa'),
            chevron: true,
            onTap: () {},
          ),
        ),
        size: const Size(320, 640),
        textScale: 1.6,
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(GuTile)).width, 320);
      expect(
        tester.getSize(find.byType(GuTile)).height,
        greaterThan(GuSizes.tileMinHeight),
      );
    });
  });
}

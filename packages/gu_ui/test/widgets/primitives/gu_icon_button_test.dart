// T-04 · GuIconButton (widget-catalog #2; A.2 #2; K-03, K-32, K-53, CD-81).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

final Finder _button = find.byType(GuIconButton);

BoxDecoration _decoration(WidgetTester tester, [Finder? of]) =>
    tester
            .widget<AnimatedContainer>(
              find.descendant(
                of: of ?? _button,
                matching: find.byType(AnimatedContainer),
              ),
            )
            .decoration!
        as BoxDecoration;

GuIcon _icon(WidgetTester tester, [Finder? of]) => tester.widget<GuIcon>(
  find.descendant(of: of ?? _button, matching: find.byType(GuIcon)),
);

void main() {
  group('T-04 · GuIconButton', () {
    testWidgets('T-04 · GuIconButton · boyut 48 / 40 / 32, tonlar, onCover, '
        'rozet ve sayaç token değerleriyle; basılı zemin', (tester) async {
      const c = GuColors.light;
      const component = GuComponentColors.light;

      // Boyutlar; varsayılan ikon 24 + text.heading, zeminsiz, tam yuvarlak.
      for (final (size, dimension) in [
        (GuIconButtonSize.md, 48.0),
        (GuIconButtonSize.sm, 40.0),
        (GuIconButtonSize.xs, 32.0),
      ]) {
        await tester.pumpApp(
          Center(
            child: GuIconButton(
              icon: GuIcons.search,
              semanticLabel: 'Ara',
              size: size,
              onPressed: () {},
            ),
          ),
        );
        expect(tester.getSize(_button), Size.square(dimension));
        expect(_decoration(tester).color, isNull);
        expect(_decoration(tester).borderRadius, GuRadius.borderFull);
        expect((_icon(tester).size, _icon(tester).color), (24, c.textHeading));
      }

      // Basılı: bg.surfaceMuted (K-53).
      var gesture = await tester.startGesture(tester.getCenter(_button));
      await tester.pump();
      expect(_decoration(tester).color, c.bgSurfaceMuted);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_decoration(tester).color, isNull);

      // Tonlar: brand ikon rengi; success / danger 44 + kapsayıcı zemin,
      // basılı rengi yok (K-32).
      for (final (tone, dimension, fg, bg) in [
        (GuIconButtonTone.brand, 48.0, c.brandPrimaryText, null),
        (
          GuIconButtonTone.success,
          44.0,
          c.stateSuccess,
          c.stateSuccessContainer,
        ),
        (GuIconButtonTone.danger, 44.0, c.stateDanger, c.stateDangerContainer),
      ]) {
        await tester.pumpApp(
          Center(
            child: GuIconButton(
              icon: GuIcons.check,
              semanticLabel: 'Onayla',
              tone: tone,
              onPressed: () {},
            ),
          ),
        );
        expect(
          tester.getSize(_button),
          Size.square(dimension),
          reason: '$tone',
        );
        expect(_icon(tester).color, fg, reason: '$tone');
        expect(_decoration(tester).color, bg, reason: '$tone');
        if (bg != null) {
          gesture = await tester.startGesture(tester.getCenter(_button));
          await tester.pump();
          expect(_decoration(tester).color, bg, reason: '$tone basılı');
          await gesture.up();
          await tester.pumpAndSettle();
        }
      }

      // onCover: beyaz ikon, koyu örtü + blur 6 (daireye kırpılı); basılı
      // daha koyu örtü.
      await tester.pumpApp(
        Center(
          child: GuIconButton(
            icon: GuIcons.share2,
            semanticLabel: 'Paylaş',
            onCover: true,
            onPressed: () {},
          ),
        ),
      );
      expect(_icon(tester).color, component.onCoverForeground);
      expect(_decoration(tester).color, component.onCoverScrim);
      expect(
        tester.widget<ClipRRect>(find.byType(ClipRRect)).borderRadius,
        GuRadius.borderFull,
      );
      expect(find.byType(BackdropFilter), findsOneWidget);
      gesture = await tester.startGesture(tester.getCenter(_button));
      await tester.pump();
      expect(_decoration(tester).color, component.onCoverScrimPressed);
      await gesture.up();
      await tester.pumpAndSettle();

      // Rozet (.dot-badge): GuCountBadge(sm), üst 8 / sağ 8.
      // Sayaç (K-32): otomatik genişlik = 10 + 22 + 6 + metin + 10, radius 12.
      // foregroundInherit: ikon kapsayıcının metin rengini alır.
      await tester.pumpApp(
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GuIconButton(
                key: const ValueKey('badge'),
                icon: GuIcons.bell,
                semanticLabel: 'Bildirimler',
                badge: '9+',
                onPressed: () {},
              ),
              GuIconButton(
                key: const ValueKey('count'),
                icon: GuIcons.heart,
                semanticLabel: 'Beğen',
                iconSize: GuSizes.icon22,
                countLabel: '128',
                onPressed: () {},
              ),
              DefaultTextStyle(
                style: TextStyle(color: c.stateInfo),
                child: GuIconButton(
                  key: const ValueKey('inherit'),
                  icon: GuIcons.x,
                  semanticLabel: 'Kapat',
                  size: GuIconButtonSize.sm,
                  iconSize: GuSizes.icon18,
                  foregroundInherit: true,
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ),
      );
      final badgeHost = find.byKey(const ValueKey('badge'));
      final badge = tester.widget<GuCountBadge>(find.byType(GuCountBadge));
      expect((badge.label, badge.size), ('9+', GuCountBadgeSize.sm));
      final hostRect = tester.getRect(badgeHost);
      final badgeRect = tester.getRect(find.byType(GuCountBadge));
      expect(hostRect.size, const Size.square(48));
      expect(badgeRect.top - hostRect.top, 8);
      expect(hostRect.right - badgeRect.right, 8);

      final count = find.byKey(const ValueKey('count'));
      final countText = tester.widget<Text>(find.text('128'));
      expect(
        countText.style,
        GuTypography.resolve(c).labelM.copyWith(
          color: c.textHeading,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
      expect(
        tester.getSize(count),
        Size(10 + 22 + 6 + tester.getSize(find.text('128')).width + 10, 48),
      );
      expect(_decoration(tester, count).borderRadius, GuRadius.borderSm);

      final inherit = find.byKey(const ValueKey('inherit'));
      expect(
        (_icon(tester, inherit).size, _icon(tester, inherit).color),
        (
          18,
          c.stateInfo,
        ),
      );
    });

    testWidgets('T-04 · GuIconButton · dokunma → onPressed; disabled → '
        'onDisabledPressed + opaklık .45; Semantics; 32 px düğmede dokunma '
        'hedefi ≥ 48 dp', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      var disabledTaps = 0;
      await tester.pumpApp(
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: GuSpacing.s24,
            children: [
              GuIconButton(
                key: GuKey.action('TST-27.close'),
                icon: GuIcons.x,
                semanticLabel: 'Kapat',
                size: GuIconButtonSize.xs,
                iconSize: GuSizes.icon16,
                onPressed: () => taps++,
              ),
              GuIconButton(
                key: GuKey.action('FED-02.send'),
                icon: GuIcons.moreVertical,
                semanticLabel: 'Daha fazla',
                disabled: true,
                onPressed: () => taps++,
                onDisabledPressed: () => disabledTaps++,
              ),
              const GuIconButton(icon: GuIcons.search, semanticLabel: 'Ara'),
            ],
          ),
        ),
      );
      final close = find.byKey(GuKey.action('TST-27.close'));
      final more = find.byKey(GuKey.action('FED-02.send'));
      expect(tester.getSize(close), const Size.square(32));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      // Görünmez dolgu: 32 px dairenin 7 px dışı da etkin (48 dp).
      await tester.tap(close);
      await tester.tapAt(tester.getCenter(close) + const Offset(0, 23));
      expect((taps, disabledTaps), (2, 0));
      await tester.tap(more);
      await tester.tap(_button.last);
      expect((taps, disabledTaps), (2, 1));

      final opacities = tester
          .widgetList<Opacity>(find.byType(Opacity))
          .map((o) => o.opacity)
          .toList();
      expect(opacities, [
        1,
        GuOpacity.iconButtonDisabled,
        GuOpacity.iconButtonDisabled,
      ]);
      expect(
        tester.getSemantics(close),
        isSemantics(
          label: 'Kapat',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(more),
        isSemantics(
          label: 'Daha fazla',
          isButton: true,
          isEnabled: false,
          hasTapAction: false,
        ),
      );
      handle.dispose();
    });
  });
}

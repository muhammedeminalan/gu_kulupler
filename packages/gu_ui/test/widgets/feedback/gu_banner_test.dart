// T-06 · GuBanner (widget-catalog #19; K-27; css:248–257; ui.js:86–91).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

Widget _host(Widget child) =>
    Column(mainAxisSize: MainAxisSize.min, children: [child]);

Finder _within(Type type) =>
    find.descendant(of: find.byType(GuBanner), matching: find.byType(type));

BoxDecoration _decoration(WidgetTester tester) =>
    tester.widget<DecoratedBox>(_within(DecoratedBox).first).decoration
        as BoxDecoration;

void main() {
  group('T-06 · GuBanner', () {
    testWidgets('T-06 · GuBanner · 6 tür: zemin / metin rengi + varsayılan '
        'ikon 18, dolgu 10 / 16, aralık 10; ikon üst yazımı; danger canlı '
        'bölge', (tester) async {
      final handle = tester.ensureSemantics();
      const c = GuColors.light;
      final banner = GuTypography.resolve(c).banner;
      final expected = {
        GuBannerKind.info: (c.stateInfoContainer, c.stateInfo, GuIcons.info),
        GuBannerKind.warning: (
          c.stateWarningContainer,
          c.stateWarning,
          GuIcons.triangleAlert,
        ),
        GuBannerKind.danger: (
          c.stateDangerContainer,
          c.stateDanger,
          GuIcons.circleX,
        ),
        GuBannerKind.offline: (c.textHeading, c.bgSurface, GuIcons.wifiOff),
        GuBannerKind.readonly: (
          c.bgSurfaceMuted,
          c.textSecondary,
          GuIcons.eye,
        ),
        GuBannerKind.success: (
          c.stateSuccessContainer,
          c.stateSuccess,
          GuIcons.circleCheck,
        ),
      };
      expect(expected.keys, GuBannerKind.values);
      const message = 'Etkinlik henüz başlamadı.';

      for (final MapEntry(key: kind, value: (background, foreground, glyph))
          in expected.entries) {
        await tester.pumpApp(_host(GuBanner(text: message, kind: kind)));
        final reason = '$kind';
        expect(_decoration(tester).color, background, reason: reason);
        expect(_decoration(tester).borderRadius, isNull, reason: reason);
        final icon = tester.widget<GuIcon>(_within(GuIcon));
        expect(icon.icon, glyph, reason: reason);
        expect(icon.size, GuSizes.bannerIcon, reason: reason);
        expect(icon.color, foreground, reason: reason);
        expect(
          DefaultTextStyle.of(tester.element(find.text(message))).style,
          banner.copyWith(color: foreground),
          reason: reason,
        );
        // Satır 13 × 1.4 = 18.2 → yükseklik 10 + 18.2 + 10.
        final size = tester.getSize(find.byType(GuBanner));
        expect(size.width, 390, reason: reason);
        expect(size.height, moreOrLessEquals(38.2, epsilon: 0.5));
        expect(
          tester.getTopLeft(_within(GuIcon)).dx,
          GuSizes.bannerPaddingX,
          reason: reason,
        );
        expect(
          tester.getTopLeft(find.text(message)).dx,
          GuSizes.bannerPaddingX + GuSizes.bannerIcon + GuSizes.bannerGap,
          reason: reason,
        );
        // `role="alert"` yalnızca danger.
        expect(
          tester.getSemantics(find.byType(GuBanner)),
          kind == GuBannerKind.danger
              ? isSemantics(isLiveRegion: true)
              : isNot(isSemantics(isLiveRegion: true)),
          reason: reason,
        );
        expect(find.byType(GuIconButton), findsNothing, reason: reason);
      }

      // CLB-03 askıda bandı: `ban` ikonu.
      await tester.pumpApp(
        _host(
          const GuBanner(
            text: 'Bu kulüp geçici olarak askıda.',
            kind: GuBannerKind.warning,
            icon: GuIcons.ban,
          ),
        ),
      );
      expect(tester.widget<GuIcon>(_within(GuIcon)).icon, GuIcons.ban);
      handle.dispose();
    });

    testWidgets('T-06 · GuBanner · eylem (36, altı çizili, basılı zemin) ve '
        'kapat (40 / ikon 18) → callback + Semantics + dokunma hedefi; card '
        '(radius md, yatay 16); trailing satır içi', (tester) async {
      final handle = tester.ensureSemantics();
      const c = GuColors.light;
      final actionKey = GuKey.action('NTF-01.enable');
      final dismissKey = GuKey.action('NTF-01.dismissBanner');
      var actions = 0;
      var dismissals = 0;
      await tester.pumpApp(
        _host(
          GuBanner(
            text: 'Bildirimler kapalı',
            kind: GuBannerKind.warning,
            icon: GuIcons.bellOff,
            actionLabel: 'Aç',
            onAction: () => actions++,
            actionKey: actionKey,
            onDismiss: () => dismissals++,
            dismissActionKey: dismissKey,
            dismissSemanticLabel: 'Kapat',
          ),
        ),
      );
      // 10 + 40 (kapat) + 10.
      expect(tester.getSize(find.byType(GuBanner)), const Size(390, 60));
      expect(
        tester.getSize(find.byKey(actionKey)).height,
        GuSizes.bannerTextButtonHeight,
      );
      final label = tester.widget<Text>(find.text('Aç'));
      expect(label.style?.decoration, TextDecoration.underline);
      expect(label.style?.color, c.stateWarning);
      final dismiss = tester.widget<GuIconButton>(find.byKey(dismissKey));
      expect(dismiss.icon, GuIcons.x);
      expect(dismiss.size, GuIconButtonSize.sm);
      expect(dismiss.iconSize, GuSizes.bannerDismissIcon);
      expect(
        tester.getSize(find.byKey(dismissKey)),
        const Size.square(GuSizes.iconButtonSm),
      );
      // Kapat ikonu bandın metin rengini alır (`color:inherit`).
      expect(
        tester
            .widget<GuIcon>(
              find.descendant(
                of: find.byKey(dismissKey),
                matching: find.byType(GuIcon),
              ),
            )
            .color,
        c.stateWarning,
      );
      expect(
        tester.getTopRight(find.byKey(dismissKey)).dx,
        390 - GuSizes.bannerPaddingX,
      );
      expect(
        tester.getTopLeft(find.byKey(dismissKey)).dx,
        tester.getTopRight(find.byKey(actionKey)).dx + GuSizes.bannerGap,
      );
      expect(
        tester.getSemantics(find.byKey(actionKey)),
        isSemantics(
          label: 'Aç',
          isButton: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.byKey(dismissKey)),
        isSemantics(
          label: 'Kapat',
          isButton: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));

      // Basılı: `.btn-text:hover` zemini (K-53).
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(actionKey)),
      );
      await tester.pumpAndSettle();
      final pressed = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byKey(actionKey),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(
        (pressed.decoration! as BoxDecoration).color,
        c.brandPrimaryContainer,
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(actions, 1);
      await tester.tap(find.byKey(dismissKey));
      await tester.pumpAndSettle();
      expect((actions, dismissals), (1, 1));

      // card + trailing (MGT-02 anahtarı).
      const trailingKey = ValueKey<String>('trailing');
      await tester.pumpApp(
        _host(
          const GuBanner(
            text: 'Başvurular kapalı',
            icon: GuIcons.lock,
            card: true,
            trailing: SizedBox(key: trailingKey, width: 44, height: 26),
          ),
        ),
      );
      expect(_decoration(tester).borderRadius, GuRadius.borderMd);
      final box = tester.getRect(_within(DecoratedBox).first);
      expect(box.left, GuSizes.bannerCardMarginX);
      expect(box.width, 390 - 2 * GuSizes.bannerCardMarginX);
      const textLeft =
          GuSizes.bannerCardMarginX +
          GuSizes.bannerPaddingX +
          GuSizes.bannerIcon +
          GuSizes.bannerGap;
      expect(
        tester.getTopLeft(find.byKey(trailingKey)).dx,
        greaterThan(textLeft + GuSpacing.s8),
      );
      expect(
        tester.getCenter(find.byKey(trailingKey)).dy,
        moreOrLessEquals(box.center.dy, epsilon: 1),
      );
      handle.dispose();
    });

    testWidgets('T-06 · GuBanner · 320 dp × metin ölçeği 1.6 + uzun metin, '
        'eylem ve kapat → taşma yok (eylem en çok yarı genişlik)', (
      tester,
    ) async {
      final actionKey = GuKey.action('CLB-07.unblock');
      final dismissKey = GuKey.action('NTF-01.dismissBanner');
      await tester.pumpApp(
        _host(
          GuBanner(
            text:
                'Bu kullanıcıyı engelledin; gönderilerini ve yorumlarını '
                'artık görmeyeceksin.',
            kind: GuBannerKind.warning,
            actionLabel: 'Kullanıcının engelini hemen kaldır',
            onAction: () {},
            actionKey: actionKey,
            onDismiss: () {},
            dismissActionKey: dismissKey,
            dismissSemanticLabel: 'Kapat',
          ),
        ),
        size: const Size(320, 640),
        textScale: 1.6,
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byKey(actionKey)).width,
        lessThanOrEqualTo((320 - 2 * GuSizes.bannerPaddingX) / 2),
      );
      expect(
        tester.getTopRight(find.byKey(dismissKey)).dx,
        320 - GuSizes.bannerPaddingX,
      );
    });
  });
}

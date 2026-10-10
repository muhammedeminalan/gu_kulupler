// T-04 · temel grup galeri golden'ı (`gu_gallery_base__default__*.png`):
// GuSpinner, GuDivider, GuCountBadge, GuIconBox (+ GuTapTarget sarmalı).
// Referans: `ds_feedback.webp` (spinner), `ds_badges.webp` ("9+"),
// `ds_nav.webp` (halkalı rozet), `screens/NTF-01` (ikon kutuları).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/golden_helper.dart';

class _Gallery extends StatelessWidget {
  const _Gallery();

  @override
  Widget build(BuildContext context) {
    final colors = context.gu.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Spinner: currentColor, brand zemin üstünde onPrimary, muted, büyük.
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GuSpinner(),
            GuGap.h16,
            ColoredBox(
              color: colors.brandPrimary,
              child: Padding(
                padding: GuInsets.all12,
                child: GuSpinner(color: colors.brandOnPrimary),
              ),
            ),
            GuGap.h16,
            GuSpinner(color: colors.textMuted),
            GuGap.h16,
            GuSpinner(size: GuSizes.icon34, color: colors.brandPrimary),
          ],
        ),
        GuGap.v16,
        const GuDivider(),
        GuGap.v16,
        // Sayaç pilleri: sm, sm "9+", md, md "9+", md muted, halka, inverted.
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GuCountBadge(label: '2'),
            GuGap.h8,
            const GuCountBadge(label: '9+'),
            GuGap.h8,
            const GuCountBadge(label: '5', size: GuCountBadgeSize.md),
            GuGap.h8,
            const GuCountBadge(label: '9+', size: GuCountBadgeSize.md),
            GuGap.h8,
            const GuCountBadge(
              label: '1',
              size: GuCountBadgeSize.md,
              tone: GuCountBadgeTone.muted,
            ),
            GuGap.h8,
            ColoredBox(
              color: colors.bgSurface,
              child: const Padding(
                padding: GuInsets.all8,
                child: GuCountBadge(label: '4', ring: true),
              ),
            ),
            GuGap.h8,
            ColoredBox(
              color: colors.brandPrimary,
              child: const Padding(
                padding: GuInsets.all8,
                child: GuCountBadge(
                  label: '3',
                  tone: GuCountBadgeTone.inverted,
                ),
              ),
            ),
          ],
        ),
        GuGap.v16,
        const GuDivider(margin: GuInsets.h16),
        GuGap.v16,
        // İkon kutuları: 6 ton + SHT-24 büyük ölçü (GuTapTarget sarmalı).
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (tone, icon) in const [
              (GuIconBoxTone.brand, GuIcons.megaphone),
              (GuIconBoxTone.success, GuIcons.circleCheck),
              (GuIconBoxTone.danger, GuIcons.circleX),
              (GuIconBoxTone.info, GuIcons.calendarPlus),
              (GuIconBoxTone.warning, GuIcons.bellRing),
              (GuIconBoxTone.neutral, GuIcons.info),
            ]) ...[GuIconBox(icon: icon, tone: tone), GuGap.h4],
            GuTapTarget(
              onTap: () {},
              semanticLabel: 'Sonuç',
              child: const GuIconBox(
                icon: GuIcons.circleCheck,
                tone: GuIconBoxTone.success,
                size: GuSizes.notifIconLg,
                iconSize: GuSizes.notifIconLgIcon,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

void main() {
  testWidgets('T-04 · temel grup · galeri golden (açık + koyu)', (
    tester,
  ) async {
    await goldenForWidget(tester, 'gu_gallery_base', {
      'default': const _Gallery(),
    });
  });
}

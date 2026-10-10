import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import 'golden_helper.dart';

/// Prob: başlık (Montserrat) + Türkçe glifler (Inter) + marka dolgulu hap.
class _GoldenProbe extends StatelessWidget {
  const _GoldenProbe();

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Gümüşhane Üniversitesi', style: gu.text.titleM),
        GuGap.v4,
        Text('İ ı ğ ş ç ö ü ₺', style: gu.text.bodyM),
        GuGap.v8,
        DecoratedBox(
          decoration: BoxDecoration(
            color: gu.colors.brandPrimary,
            borderRadius: GuRadius.borderFull,
          ),
          child: Padding(
            padding: GuInsets.h16v8,
            child: Text(
              'Katıl',
              style: gu.text.button.copyWith(color: gu.colors.brandOnPrimary),
            ),
          ),
        ),
      ],
    );
  }
}

void main() {
  group('T-02 · goldenForWidget (gu_ui, Q-16)', () {
    test('yol biçimi <ad>__<durum>__<tema>.png (merkezi test/goldens)', () {
      expect(
        widgetGoldenPath('gu_button', 'pressed', ThemeMode.light),
        'test/goldens/gu_button__pressed__light.png',
      );
      expect(
        widgetGoldenPath('gu_button', 'default', ThemeMode.dark),
        'test/goldens/gu_button__default__dark.png',
      );
      expect(
        () => widgetGoldenPath('x', 'default', ThemeMode.system),
        throwsArgumentError,
      );
    });

    test('goldenUri paket köküne göre mutlak file: URI', () {
      final uri = goldenUri('test/goldens/x__default__light.png');
      expect(uri.scheme, 'file');
      expect(
        uri.path,
        endsWith('/packages/gu_ui/test/goldens/x__default__light.png'),
      );
    });

    test('politika: tolerans 0, varsayılan LocalFileComparator', () {
      expect(GoldenPolicy.tolerance, 0);
      expect(goldenFileComparator, isA<LocalFileComparator>());
    });

    testWidgets('prob golden: t02_probe__default__{light,dark}.png', (
      tester,
    ) async {
      await goldenForWidget(tester, 't02_probe', {
        'default': const _GoldenProbe(),
      });
      expect(find.byKey(kGoldenFrameKey), findsOneWidget);
    });
  });
}

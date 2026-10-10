import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_ui/gu_ui.dart';

import 'golden_helper.dart';
import 'pump_app.dart';

/// Prob ekranı: Montserrat başlık, Inter gövde, yüzey kartı, marka düğmesi;
/// metinler ARB'den (Türkçe glifler: ü, ş, İ, ı).
class _ProbeScreen extends StatelessWidget {
  const _ProbeScreen();

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: gu.colors.bgCanvas,
      body: SafeArea(
        child: Padding(
          padding: GuInsets.all16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.navClubs, style: gu.text.titleL),
              GuGap.v8,
              Text(l10n.onbDiscoverDesc, style: gu.text.bodyM),
              GuGap.v16,
              DecoratedBox(
                decoration: BoxDecoration(
                  color: gu.colors.bgSurface,
                  borderRadius: GuRadius.borderLg,
                  border: Border.all(color: gu.colors.borderSoft),
                ),
                child: Padding(
                  padding: GuInsets.all16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.onbJoinTitle, style: gu.text.titleS),
                      GuGap.v4,
                      Text(
                        l10n.onbJoinDesc,
                        style: gu.text.bodyS.copyWith(
                          color: gu.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              GuGap.v16,
              DecoratedBox(
                decoration: BoxDecoration(
                  color: gu.colors.brandPrimary,
                  borderRadius: GuRadius.borderFull,
                ),
                child: Padding(
                  padding: GuInsets.h16v12,
                  child: Text(
                    l10n.onbNext,
                    style: gu.text.button.copyWith(
                      color: gu.colors.brandOnPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  group('T-02 · golden_helper (kök, Q-16)', () {
    test('goldenPath: test/goldens/<ad>__<tema>__<dil>.png', () {
      expect(
        goldenPath('ekran_a', ThemeMode.light, const Locale('tr')),
        'test/goldens/ekran_a__light__tr.png',
      );
      expect(
        goldenPath('sheet_b', ThemeMode.dark, const Locale('en')),
        'test/goldens/sheet_b__dark__en.png',
      );
      expect(
        () => goldenPath('x', ThemeMode.system, const Locale('tr')),
        throwsArgumentError,
      );
    });

    test('goldenUri kök pakete göre mutlak file: URI', () {
      final uri = goldenUri('test/goldens/x__light__tr.png');
      expect(uri.scheme, 'file');
      expect(uri.path, endsWith('/test/goldens/x__light__tr.png'));
      expect(uri.path, isNot(contains('/packages/')));
    });

    test('politika: tolerans 0, varsayılan LocalFileComparator', () {
      expect(GoldenPolicy.tolerance, 0);
      expect(goldenFileComparator, isA<LocalFileComparator>());
    });

    testWidgets('prob golden: t02_probe__{light,dark}__tr.png', (
      tester,
    ) async {
      await goldenForThemes(tester, 't02_probe', const _ProbeScreen());
      expect(find.byKey(kPumpAppBoundaryKey), findsOneWidget);
    });
  });
}

// T-11 · countBadgeLabel: sayaç rozeti metni ve "9+" sınırı (CD-81; PLAN
// §15.9; `shell.js:12`).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/format/count_badge_label.dart';

void main() {
  for (final locale in AppLocalizations.supportedLocales) {
    group('T-11 · countBadgeLabel (${locale.languageCode})', () {
      late AppLocalizations l10n;

      setUp(() => l10n = lookupAppLocalizations(Locale(locale.languageCode)));

      test('0 ve negatif → rozet yok', () {
        expect(countBadgeLabel(l10n, 0), isNull);
        expect(countBadgeLabel(l10n, -3), isNull);
      });

      test('1…9 → sayı', () {
        expect(Limits.unreadBadgeMax, 9);
        for (var count = 1; count <= Limits.unreadBadgeMax; count++) {
          expect(countBadgeLabel(l10n, count), '$count');
        }
      });

      test('9 üstü → badgeOverflow ("9+")', () {
        expect(l10n.badgeOverflow, '9+');
        for (final count in [10, 11, 99, 1000]) {
          expect(countBadgeLabel(l10n, count), l10n.badgeOverflow);
        }
      });
    });
  }
}

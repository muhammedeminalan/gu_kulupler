// T-11 · L10nX: `context.l10n` köprüsü (CLAUDE.md §8, PLAN §14.6).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';

import '../../helpers/design_files.dart';
import '../../helpers/pump_app.dart';

void main() {
  group('T-11 · L10nX', () {
    for (final locale in AppLocalizations.supportedLocales) {
      testWidgets('context.l10n etkin dilin metinlerini verir '
          '(${locale.languageCode})', (tester) async {
        late AppLocalizations seen;
        await tester.pumpApp(
          Builder(
            builder: (context) {
              seen = context.l10n;
              return const SizedBox.shrink();
            },
          ),
          locale: locale,
        );
        expect(seen.localeName, locale.languageCode);
        expect(seen.commonRetry, lookupAppLocalizations(locale).commonRetry);
      });
    }

    test('köprü tek konumdadır: lib/l10n yalnızca ARB ve üretilen dosyaları '
        'taşır', () {
      expect(
        repoFile('lib/core/l10n/build_context_l10n_x.dart').existsSync(),
        isTrue,
      );
      expect(
        repoFile('lib/l10n/build_context_l10n_x.dart').existsSync(),
        isFalse,
      );
      expect(repoFile('lib/l10n/l10n_x.dart').existsSync(), isFalse);
    });
  });
}

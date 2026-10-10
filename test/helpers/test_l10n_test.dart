import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'design_files.dart';
import 'pump_app.dart';
import 'test_l10n.dart';

void main() {
  // Beklenen metinler ARB'den okunur (test içinde literal yok).
  final tr = readJsonMap('lib/l10n/app_tr.arb');
  final en = readJsonMap('lib/l10n/app_en.arb');

  group('T-02 · test_l10n', () {
    testWidgets('tester.l10n çizili ağacın dili (TR)', (tester) async {
      await tester.pumpApp(const SizedBox.shrink());
      expect(tester.l10n.localeName, 'tr');
      expect(tester.l10n.onbNext, tr['onbNext']);
    });

    testWidgets('tester.l10n çizili ağacın dili (EN)', (tester) async {
      await tester.pumpApp(
        const SizedBox.shrink(),
        locale: const Locale('en'),
      );
      expect(tester.l10n.localeName, 'en');
      expect(tester.l10n.onbNext, en['onbNext']);
      expect(tester.l10n.onbNext, isNot(tr['onbNext']));
    });

    testWidgets('l10nFor ağaçtan bağımsız', (tester) async {
      expect(tester.l10nFor(const Locale('tr')).navClubs, tr['navClubs']);
      expect(tester.l10nFor(const Locale('en')).navClubs, en['navClubs']);
    });

    testWidgets('pumpApp olmadan AppLocalizations yoksa StateError', (
      tester,
    ) async {
      await tester.pumpWidget(const SizedBox.shrink());
      expect(() => tester.l10n, throwsStateError);
    });

    test('loadL10n delegeyle yükler', () async {
      expect((await loadL10n(const Locale('tr'))).onbSkip, tr['onbSkip']);
      expect((await loadL10n(const Locale('en'))).onbSkip, en['onbSkip']);
    });
  });
}

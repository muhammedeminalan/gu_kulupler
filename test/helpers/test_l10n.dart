// Testte metin doğrulaması yalnızca l10n ile (testing.md §1.5; TR ve EN
// ayrı). Ör. `expect(find.text(tester.l10n.onbNext), findsOneWidget)`.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';

import 'pump_app.dart';

extension TesterL10n on WidgetTester {
  /// Çizili ağacın etkin `AppLocalizations`'ı (`pumpApp` çocuğunun bağlamı;
  /// yoksa `AppLocalizations` gören ilk öğe).
  AppLocalizations get l10n {
    final child = find.byKey(kPumpAppChildKey);
    if (any(child)) return AppLocalizations.of(element(child));
    for (final e in allElements) {
      final l10n = Localizations.of<AppLocalizations>(e, AppLocalizations);
      if (l10n != null) return l10n;
    }
    throw StateError('Ağaçta AppLocalizations yok — pumpApp ile çiz.');
  }

  /// Ağaçtan bağımsız, [locale] için `AppLocalizations`.
  AppLocalizations l10nFor(Locale locale) => lookupAppLocalizations(locale);
}

/// `AppLocalizations.delegate.load` ile [locale] çevirileri.
Future<AppLocalizations> loadL10n(Locale locale) =>
    AppLocalizations.delegate.load(locale);

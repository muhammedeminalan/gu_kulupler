import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/core/constants/app_constants.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/l10n/app_localizations_en.dart';
import 'package:gu_kulupler/l10n/app_localizations_tr.dart';

/// K-22 / K-23 düzeltmelerinin gen-l10n çıktısı üzerinden doğrulanması (CD-51, CD-75).
void main() {
  final tr = AppLocalizationsTr();
  final en = AppLocalizationsEn();

  group('T-00 · ARB düzeltmeleri', () {
    test('searchNoResults sorguyu düz tırnakla basar (K-23, CD-51)', () {
      expect(tr.searchNoResults('sorgu'), "'sorgu' için sonuç yok");
      expect(en.searchNoResults('query'), "No results for 'query'");
      expect(tr.searchNoResults('x'), isNot(contains('{q}')));
    });

    test('postComments üç çoğul dalı (K-23)', () {
      expect(tr.postComments(0), 'Yorumlar');
      expect(tr.postComments(1), '1 yorum');
      expect(tr.postComments(5), '5 yorum');
      expect(en.postComments(0), 'Comments');
      expect(en.postComments(1), '1 comment');
      expect(en.postComments(5), '5 comments');
    });

    test('timeInDays üç çoğul dalı (K-23)', () {
      expect(tr.timeInDays(0), 'bugün');
      expect(tr.timeInDays(1), '1 gün');
      expect(tr.timeInDays(3), '3 gün');
      expect(en.timeInDays(0), 'today');
      expect(en.timeInDays(1), '1 day');
      expect(en.timeInDays(2), '2 days');
    });

    test('hiçbir çoğul dalında # kalmadı (K-28, ARB15)', () {
      for (final lang in ['tr', 'en']) {
        final arb =
            jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
                as Map<String, dynamic>;
        final plurals = arb.entries
            .where((e) => !e.key.startsWith('@') && e.value is String)
            .map((e) => e.value as String)
            .where((v) => RegExp(r'\{\s*\w+\s*,\s*plural\s*,').hasMatch(v))
            .toList();
        expect(plurals, hasLength(13), reason: '$lang çoğul anahtar sayısı');
        expect(plurals, everyElement(isNot(contains('#'))));
      }
    });

    test('ürün adı yalnızca AppConstants üzerinden gelir (K-22, D-01)', () {
      expect(
        tr.notifTypeSystemWelcomeTitle(tr.appNameWelcomeArg),
        '${AppConstants.appNameDative} hoş geldin',
      );
      expect(
        en.notifTypeSystemWelcomeTitle(en.appNameWelcomeArg),
        'Welcome to ${AppConstants.appName}',
      );
      expect(tr.systemWelcomeTitle, contains(AppConstants.appName));
      expect(en.systemWelcomeTitle, 'Welcome to ${AppConstants.appName}');
      expect(
        tr.legalGizlilikB1(AppConstants.appName),
        contains(AppConstants.appName),
      );
      expect(
        en.legalGizlilikB1(AppConstants.appName),
        contains(AppConstants.appName),
      );
    });

    test('yer tutucu metinleri ürün adını literal taşımaz', () {
      const placeholder = 'X';
      expect(
        tr.notifTypeSystemWelcomeTitle(placeholder),
        isNot(contains('GÜ')),
      );
      expect(
        en.notifTypeSystemWelcomeTitle(placeholder),
        isNot(contains('GÜ')),
      );
      expect(tr.legalGizlilikB1(placeholder), isNot(contains('GÜ')));
      expect(en.legalGizlilikB1(placeholder), isNot(contains('GÜ')));
    });
  });
}

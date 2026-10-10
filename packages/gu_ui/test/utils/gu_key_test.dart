import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../helpers/design_sources.dart';

/// `tool/check_design_coverage.js` içindeki AKS05 öneki: `/^(…|NAV)\./`
/// biçimindeki JS düzenli ifade literalleri (gövde, `/` ayraçları hariç).
List<String> _aks05Literals() {
  final js = File('$repoRoot/tool/check_design_coverage.js').readAsStringSync();
  return RegExp(
    r'/(\^\([^/\n]*\|NAV\)\\\.)/',
  ).allMatches(js).map((m) => m.group(1)!).toSet().toList();
}

void main() {
  group('T-02 · GuKey (D-18, AKS05)', () {
    // Örnek kimlikler biçimce geçerli ama registry dışı (XYZ, QQ, ABCD):
    // `tool/check_design_coverage.js` TEST01 test metninde gerçek kimlik
    // arar; bu test ekran testlerinin yerine sayılmasın.
    test('action → ValueKey<String> (eşitlik ve değer)', () {
      expect(
        GuKey.action('XYZ-01.join.c03'),
        const ValueKey<String>('XYZ-01.join.c03'),
      );
      expect(GuKey.action('XYZ-01.join.c03').value, 'XYZ-01.join.c03');
      expect(GuKey.action('QQ-5.submit'), isA<ValueKey<String>>());
    });

    test('NAV, MENU ve X önekli kimlikler geçerli', () {
      for (final id in [
        'NAV.tab.clubs',
        'XYZ-MENU.share',
        'ABCD-X12.undo',
        'QQ-04.allow',
        'XYZ-05.menu.u003',
      ]) {
        expect(GuKey.isValid(id), isTrue, reason: id);
        expect(GuKey.action(id).value, id);
      }
    });

    test('geçersiz biçim debug assert ile durur', () {
      for (final id in [
        'xyz-01.join',
        'XYZ-01',
        'XYZ-01.',
        'XYZ01.join',
        'join',
        'NAVX.tab',
        'XYZ-123.join',
        'ABCDE-01.join',
        '',
      ]) {
        expect(GuKey.isValid(id), isFalse, reason: id);
        expect(() => GuKey.action(id), throwsAssertionError, reason: id);
      }
    });

    test('pattern == tool/check_design_coverage.js AKS05 ifadesi', () {
      final literals = _aks05Literals();
      expect(literals, hasLength(1), reason: 'AKS05 literali bulunamadı');
      expect(GuKey.pattern.pattern, literals.single);
    });

    test('screens-actions.json envanterindeki her anahtar geçerli', () {
      final inventory =
          jsonDecode(
                File(
                  '$repoRoot/design/extracted/screens-actions.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final actions = [
        for (final screen in inventory.values)
          ...((screen as Map<String, dynamic>)['actions'] as List<dynamic>)
              .cast<String>(),
      ];
      expect(actions, isNotEmpty);
      final invalid = actions.where((a) => !GuKey.isValid(a)).toList();
      expect(invalid, isEmpty);
    });
  });
}

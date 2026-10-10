import 'package:flutter/foundation.dart';

/// Etkileşimli öğelerin tasarım aksiyon anahtarı (D-18, D-19).
///
/// Biçim `<ID>.<aksiyon>` (`CLB-01.join.c03`, `SHT-05.submit`,
/// `EVT-MENU.share`, `TST-X12.undo`) ya da kabuk için `NAV.<aksiyon>`
/// (`NAV.tab.clubs`). Anahtar kümesi `design/extracted/screens-actions.json`
/// envanteriyle karşılaştırılır: statik olarak
/// `tool/check_design_coverage.js --actions` (AKS01–AKS06), çalışma anında
/// ekran testlerinde `expectActionInventory` (`test/helpers/
/// action_inventory.dart`).
///
/// ```dart
/// GuButton(key: GuKey.action('CLB-03.join'), …)
/// find.byKey(GuKey.action('CLB-03.join'))
/// ```
abstract final class GuKey {
  /// Geçerli anahtar öneki — `tool/check_design_coverage.js` AKS05 ile aynı
  /// ifade (eşitlik `packages/gu_ui/test/utils/gu_key_test.dart`'ta JS
  /// kaynağından okunarak doğrulanır).
  static final RegExp pattern = RegExp(
    r'^([A-Z]{2,4}-(?:X?\d{1,2}|MENU)|NAV)\.',
  );

  /// [id] için `ValueKey<String>`; biçim debug'da `assert` ile denetlenir
  /// ([pattern] + boş olmayan aksiyon parçası).
  static ValueKey<String> action(String id) {
    assert(
      isValid(id),
      'GuKey.action("$id"): biçim `<ID>.<aksiyon>` ya da `NAV.<aksiyon>` '
      'olmalı (D-18, AKS05).',
    );
    return ValueKey<String>(id);
  }

  /// [id] geçerli bir aksiyon anahtarı mı ([pattern] eşleşir ve önekten sonra
  /// aksiyon parçası boş değil).
  static bool isValid(String id) {
    final match = pattern.firstMatch(id);
    return match != null && match.end < id.length;
  }
}

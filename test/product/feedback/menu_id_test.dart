// T-07 · MenuId ↔ registry.json#menus (CD-113; KAT01–KAT04). Beklentiler
// registry'den okunur; literal tasarım kimliği yazılmaz (TEST01).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/product/feedback/menu_id.dart';

import '../../helpers/design_files.dart';
import '../../helpers/design_ids.dart';

/// `tool/lib/pack_data.js` `enumMember`: `XXX-MENU` → `xxxMenu`, diğerleri
/// önek küçük harf + numara.
String _enumMember(String designId) {
  final menu = RegExp(r'^([A-Z]{3})-MENU$').firstMatch(designId);
  if (menu != null) return '${menu.group(1)!.toLowerCase()}Menu';
  return designId.substring(0, 3).toLowerCase() + designId.substring(4);
}

void main() {
  group('T-07 · MenuId', () {
    test('2 üye; designId listesi registry.menus ile aynı', () {
      expect(MenuId.values, hasLength(2));
      expect(MenuId.values.map((e) => e.designId), DesignIds.menus);
    });

    test('üye adı kuralı (pack_data.enumMember)', () {
      expect(
        MenuId.values.map((e) => e.name),
        DesignIds.menus.map(_enumMember),
      );
    });

    test('her üyenin üstünde kendi `/// Design:` izi', () {
      final traces = parseEnumDesignTraces(
        readText('lib/product/feedback/menu_id.dart'),
      );
      expect(traces, {for (final id in MenuId.values) id.name: id.designId});
    });
  });
}

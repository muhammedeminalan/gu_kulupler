// T-07 · SheetId ↔ registry.json#sheets (KAT01–KAT04). Beklentiler
// registry'den okunur; literal tasarım kimliği yazılmaz (TEST01).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';

import '../../helpers/design_files.dart';
import '../../helpers/design_ids.dart';

void main() {
  group('T-07 · SheetId', () {
    test('34 üye; designId kümesi ve sırası registry ile aynı', () {
      expect(SheetId.values, hasLength(34));
      expect(SheetId.values.map((e) => e.designId), DesignIds.sheets);
    });

    test('üye adı kuralı: önek küçük harf + numara (pack_data.enumMember)', () {
      for (final id in SheetId.values) {
        final designId = id.designId;
        expect(
          id.name,
          designId.substring(0, 3).toLowerCase() + designId.substring(4),
        );
        expect(designId, matches(RegExp(r'^SHT-\d{2}$')));
      }
    });

    test('her üyenin üstünde kendi `/// Design:` izi', () {
      final traces = parseEnumDesignTraces(
        readText('lib/product/feedback/sheet_id.dart'),
      );
      expect(traces, {for (final id in SheetId.values) id.name: id.designId});
    });
  });
}

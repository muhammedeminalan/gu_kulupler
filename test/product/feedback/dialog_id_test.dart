// T-07 · DialogId ↔ registry.json#dialogs (KAT01–KAT04) + DialogCatalog
// kayıtları (her satırı sahibi olan task ekler).
// Beklentiler registry'den okunur; literal tasarım kimliği yazılmaz (TEST01).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/dialog_spec.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';

import '../../helpers/design_files.dart';
import '../../helpers/design_ids.dart';

void main() {
  group('T-07 · DialogId', () {
    test('32 üye; designId kümesi registry ile aynı (numara sıralı)', () {
      expect(DialogId.values, hasLength(32));
      final ids = DialogId.values.map((e) => e.designId).toList();
      // registry sırası DLG-03/04/05 ile başlar; enum numara sırasındadır.
      expect(ids, [...DesignIds.dialogs]..sort());
      expect(ids.toSet(), DesignIds.dialogs.toSet());
    });

    test('üye adı kuralı: önek küçük harf + numara (pack_data.enumMember)', () {
      for (final id in DialogId.values) {
        final designId = id.designId;
        expect(
          id.name,
          designId.substring(0, 3).toLowerCase() + designId.substring(4),
        );
        expect(designId, matches(RegExp(r'^DLG-\d{2}$')));
      }
    });

    test('her üyenin üstünde kendi `/// Design:` izi', () {
      final traces = parseEnumDesignTraces(
        readText('lib/product/feedback/dialog_id.dart'),
      );
      expect(traces, {for (final id in DialogId.values) id.name: id.designId});
    });
  });

  group('T-07 · DialogCatalog', () {
    test('satırları sahibi olan task ekler: T-11 → DLG-26, DLG-27', () {
      expect(DialogCatalog.ids.toSet(), {DialogId.dlg26, DialogId.dlg27});
      for (final id in DialogId.values) {
        expect(
          DialogCatalog.of(id),
          DialogCatalog.ids.contains(id) ? isNotNull : isNull,
          reason: id.designId,
        );
      }
    });
  });
}

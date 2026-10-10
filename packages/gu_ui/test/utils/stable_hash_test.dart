// T-04 · GuStableHash (CD-94): prototip `hashStr` (core.js:418) birebirliği.
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/src/utils/stable_hash.dart';

import '../helpers/design_sources.dart';

void main() {
  test('T-04 · GuStableHash · fnv1a32 prototip hashStr ile aynı değerleri '
      'verir (CD-94 vektörleri + UTF-16)', () {
    // Kaynak sabitleri değişirse vektörler de değişir.
    final core = prototypeJs('core.js');
    expect(core, contains('let h = 2166136261'));
    expect(core, contains('Math.imul(h, 16777619)'));

    // CD-94 doğrulanmış vektörler.
    expect(GuStableHash.fnv1a32(''), 2166136261);
    expect(GuStableHash.fnv1a32('a'), 3826002220);
    expect(GuStableHash.fnv1a32('av:u001'), 3469349974);
    // node ile hesaplanan ek vektörler (BMP dışı = iki kod birimi, Türkçe).
    expect(GuStableHash.fnv1a32('av:u_ayse'), 2295892842);
    expect(GuStableHash.fnv1a32('av:Ayşe Demir 🙂'), 3763793074);
    expect(GuStableHash.fnv1a32('av:${'ğüşıöç' * 40}'), 343756860);
  });
}

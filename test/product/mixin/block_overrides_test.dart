// BlockOverrides: ekranda yapılan engel değişikliklerinin oturumdaki kümenin
// üstüne uygulanması (CLB-06, FED-01, FED-02 ortak çekirdeği).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/product/mixin/block_user_mixin.dart';

void main() {
  group('BlockOverrides', () {
    test('değişiklik yokken oturumdaki küme olduğu gibi döner', () {
      expect(BlockOverrides().applyTo({'u1', 'u2'}), {'u1', 'u2'});
    });

    test('engellenen eklenir, engeli kaldırılan çıkar; oturuma işlenen '
        'değişiklik artık uygulanmaz', () {
      final blocks = BlockOverrides()
        ..mark('u3', isBlocked: true)
        ..mark('u1', isBlocked: false);
      expect(blocks.applyTo({'u1', 'u2'}), {'u2', 'u3'});

      blocks
        ..settle('u3')
        ..settle('u1');
      expect(blocks.applyTo({'u2', 'u3'}), {'u2', 'u3'});
      expect(blocks.applyTo({'u1'}), {'u1'});
    });
  });
}

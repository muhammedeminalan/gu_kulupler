import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_container.dart';

final Provider<String> _valueProvider = Provider<String>((ref) => 'gerçek');

void main() {
  group('T-02 · test_container', () {
    test('override uygulanır', () {
      final container = createContainer(
        overrides: [_valueProvider.overrideWithValue('sahte')],
      );
      expect(container.read(_valueProvider), 'sahte');
      expect(createContainer().read(_valueProvider), 'gerçek');
    });

    test('kapsayıcı test sonunda dispose edilir', () {
      var disposed = false;
      final probe = Provider<int>((ref) {
        ref.onDispose(() => disposed = true);
        return 1;
      });
      // addTearDown LIFO: bu kontrol createContainer'ın dispose'undan sonra.
      addTearDown(() => expect(disposed, isTrue));
      final container = createContainer();
      expect(container.read(probe), 1);
      expect(disposed, isFalse);
    });
  });
}

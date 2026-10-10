// T-08 · CategoryModel: const satır sınıfı, değer eşitliği, JSON yok
// (PLAN §9.1, §9.9).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../../helpers/repo_sources.dart';

void main() {
  group('T-08 · CategoryModel', () {
    test('alanları taşır', () {
      const model = CategoryModel(id: 'k01', icon: 'cpu');

      expect(model.id, 'k01');
      expect(model.icon, 'cpu');
    });

    test('const örnekler kanonikleşir', () {
      expect(
        identical(
          const CategoryModel(id: 'k01', icon: 'cpu'),
          const CategoryModel(id: 'k01', icon: 'cpu'),
        ),
        isTrue,
      );
    });

    test('aynı alanlar eşittir (const olmayan örnekler dahil)', () {
      final a = CategoryModel(id: ['k', '01'].join(), icon: 'cpu');
      const b = CategoryModel(id: 'k01', icon: 'cpu');

      expect(identical(a, b), isFalse);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('her alan eşitliğe girer', () {
      const base = CategoryModel(id: 'k01', icon: 'cpu');

      expect(base, isNot(const CategoryModel(id: 'k02', icon: 'cpu')));
      expect(base, isNot(const CategoryModel(id: 'k01', icon: 'palette')));
    });

    test('props tüm alanları sırayla içerir', () {
      expect(const CategoryModel(id: 'k01', icon: 'cpu').props, ['k01', 'cpu']);
    });

    test('başka satır sınıfıyla eşit değildir', () {
      expect(
        const CategoryModel(id: 'pl01', icon: 'cpu'),
        isNot(const PlaceModel(id: 'pl01')),
      );
    });

    test('toString alanları gösterir', () {
      expect(
        const CategoryModel(id: 'k01', icon: 'cpu').toString(),
        'CategoryModel(k01, cpu)',
      );
    });

    test('JSON dönüşümü ve üretilen parça yok', () {
      final source = readRepoFile(
        'packages/gu_data/lib/src/models/lookup/category_model.dart',
      );

      expect(source, isNot(contains('json')));
      expect(source, isNot(contains('Json')));
      expect(source, isNot(contains('part ')));
      expect(source, contains('final class CategoryModel extends Equatable {'));
    });
  });
}

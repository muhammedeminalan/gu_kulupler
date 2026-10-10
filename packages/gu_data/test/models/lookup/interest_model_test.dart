// T-08 · InterestModel: const satır sınıfı, değer eşitliği, JSON yok
// (PLAN §9.1, §9.9).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../../helpers/repo_sources.dart';

void main() {
  group('T-08 · InterestModel', () {
    test('alanları taşır', () {
      const model = InterestModel(id: 'i01', categoryId: 'k01');

      expect(model.id, 'i01');
      expect(model.categoryId, 'k01');
    });

    test('const örnekler kanonikleşir', () {
      expect(
        identical(
          const InterestModel(id: 'i01', categoryId: 'k01'),
          const InterestModel(id: 'i01', categoryId: 'k01'),
        ),
        isTrue,
      );
    });

    test('aynı alanlar eşittir (const olmayan örnekler dahil)', () {
      final a = InterestModel(id: ['i', '01'].join(), categoryId: 'k01');
      const b = InterestModel(id: 'i01', categoryId: 'k01');

      expect(identical(a, b), isFalse);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('her alan eşitliğe girer', () {
      const base = InterestModel(id: 'i01', categoryId: 'k01');

      expect(base, isNot(const InterestModel(id: 'i02', categoryId: 'k01')));
      expect(base, isNot(const InterestModel(id: 'i01', categoryId: 'k06')));
    });

    test('props tüm alanları sırayla içerir', () {
      expect(const InterestModel(id: 'i01', categoryId: 'k01').props, [
        'i01',
        'k01',
      ]);
    });

    test('alanların yeri değişince eşit değildir', () {
      expect(
        const InterestModel(id: 'a', categoryId: 'b'),
        isNot(const InterestModel(id: 'b', categoryId: 'a')),
      );
    });

    test('başka satır sınıfıyla eşit değildir', () {
      expect(
        const InterestModel(id: 'x', categoryId: 'y'),
        isNot(const DepartmentModel(id: 'x', facultyId: 'y')),
      );
    });

    test('toString alanları gösterir', () {
      expect(
        const InterestModel(id: 'i01', categoryId: 'k01').toString(),
        'InterestModel(i01, k01)',
      );
    });

    test('JSON dönüşümü ve üretilen parça yok', () {
      final source = readRepoFile(
        'packages/gu_data/lib/src/models/lookup/interest_model.dart',
      );

      expect(source, isNot(contains('json')));
      expect(source, isNot(contains('Json')));
      expect(source, isNot(contains('part ')));
      expect(source, contains('final class InterestModel extends Equatable {'));
    });
  });
}

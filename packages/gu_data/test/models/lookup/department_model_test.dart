// T-08 · DepartmentModel: const satır sınıfı, değer eşitliği, JSON yok
// (PLAN §9.1, §9.9).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../../helpers/repo_sources.dart';

void main() {
  group('T-08 · DepartmentModel', () {
    test('alanları taşır', () {
      const model = DepartmentModel(id: 'd01', facultyId: 'f1');

      expect(model.id, 'd01');
      expect(model.facultyId, 'f1');
    });

    test('const örnekler kanonikleşir', () {
      expect(
        identical(
          const DepartmentModel(id: 'd01', facultyId: 'f1'),
          const DepartmentModel(id: 'd01', facultyId: 'f1'),
        ),
        isTrue,
      );
    });

    test('aynı alanlar eşittir (const olmayan örnekler dahil)', () {
      final a = DepartmentModel(id: ['d', '01'].join(), facultyId: 'f1');
      const b = DepartmentModel(id: 'd01', facultyId: 'f1');

      expect(identical(a, b), isFalse);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('her alan eşitliğe girer', () {
      const base = DepartmentModel(id: 'd01', facultyId: 'f1');

      expect(base, isNot(const DepartmentModel(id: 'd02', facultyId: 'f1')));
      expect(base, isNot(const DepartmentModel(id: 'd01', facultyId: 'f2')));
    });

    test('props tüm alanları sırayla içerir', () {
      expect(const DepartmentModel(id: 'd01', facultyId: 'f1').props, [
        'd01',
        'f1',
      ]);
    });

    test('alanların yeri değişince eşit değildir', () {
      expect(
        const DepartmentModel(id: 'a', facultyId: 'b'),
        isNot(const DepartmentModel(id: 'b', facultyId: 'a')),
      );
    });

    test('başka satır sınıfıyla eşit değildir', () {
      expect(
        const DepartmentModel(id: 'x', facultyId: 'y'),
        isNot(const InterestModel(id: 'x', categoryId: 'y')),
      );
    });

    test('toString alanları gösterir', () {
      expect(
        const DepartmentModel(id: 'd01', facultyId: 'f1').toString(),
        'DepartmentModel(d01, f1)',
      );
    });

    test('JSON dönüşümü ve üretilen parça yok', () {
      final source = readRepoFile(
        'packages/gu_data/lib/src/models/lookup/department_model.dart',
      );

      expect(source, isNot(contains('json')));
      expect(source, isNot(contains('Json')));
      expect(source, isNot(contains('part ')));
      expect(
        source,
        contains('final class DepartmentModel extends Equatable {'),
      );
    });
  });
}

// T-08 · FacultyModel: const satır sınıfı, değer eşitliği, JSON yok
// (PLAN §9.1, §9.9).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../../helpers/repo_sources.dart';

void main() {
  group('T-08 · FacultyModel', () {
    test('alanı taşır', () {
      expect(const FacultyModel(id: 'f1').id, 'f1');
    });

    test('const örnekler kanonikleşir', () {
      expect(
        identical(const FacultyModel(id: 'f1'), const FacultyModel(id: 'f1')),
        isTrue,
      );
    });

    test('aynı alan eşittir (const olmayan örnekler dahil)', () {
      final a = FacultyModel(id: ['f', '1'].join());
      const b = FacultyModel(id: 'f1');

      expect(identical(a, b), isFalse);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('farklı kimlik eşit değildir', () {
      expect(const FacultyModel(id: 'f1'), isNot(const FacultyModel(id: 'f2')));
    });

    test('props tek alanı içerir', () {
      expect(const FacultyModel(id: 'f1').props, ['f1']);
    });

    test('başka satır sınıfıyla eşit değildir', () {
      expect(const FacultyModel(id: 'x'), isNot(const PlaceModel(id: 'x')));
    });

    test('toString alanı gösterir', () {
      expect(const FacultyModel(id: 'f1').toString(), 'FacultyModel(f1)');
    });

    test('JSON dönüşümü ve üretilen parça yok', () {
      final source = readRepoFile(
        'packages/gu_data/lib/src/models/lookup/faculty_model.dart',
      );

      expect(source, isNot(contains('json')));
      expect(source, isNot(contains('Json')));
      expect(source, isNot(contains('part ')));
      expect(source, contains('final class FacultyModel extends Equatable {'));
    });
  });
}

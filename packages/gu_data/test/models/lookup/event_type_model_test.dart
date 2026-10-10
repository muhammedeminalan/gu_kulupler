// T-08 · EventTypeModel: const satır sınıfı, değer eşitliği, JSON yok
// (PLAN §4.2, §9.9).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../../helpers/repo_sources.dart';

void main() {
  group('T-08 · EventTypeModel', () {
    test('alanı taşır', () {
      expect(const EventTypeModel(id: 'egitim').id, 'egitim');
    });

    test('const örnekler kanonikleşir', () {
      expect(
        identical(
          const EventTypeModel(id: 'egitim'),
          const EventTypeModel(id: 'egitim'),
        ),
        isTrue,
      );
    });

    test('aynı alan eşittir (const olmayan örnekler dahil)', () {
      final a = EventTypeModel(id: ['egi', 'tim'].join());
      const b = EventTypeModel(id: 'egitim');

      expect(identical(a, b), isFalse);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('farklı kimlik eşit değildir', () {
      expect(
        const EventTypeModel(id: 'egitim'),
        isNot(const EventTypeModel(id: 'sosyal')),
      );
    });

    test('props tek alanı içerir', () {
      expect(const EventTypeModel(id: 'egitim').props, ['egitim']);
    });

    test('başka satır sınıfıyla eşit değildir', () {
      expect(
        const EventTypeModel(id: 'x'),
        isNot(const FacultyModel(id: 'x')),
      );
    });

    test('toString alanı gösterir', () {
      expect(
        const EventTypeModel(id: 'egitim').toString(),
        'EventTypeModel(egitim)',
      );
    });

    test('JSON dönüşümü ve üretilen parça yok', () {
      final source = readRepoFile(
        'packages/gu_data/lib/src/models/lookup/event_type_model.dart',
      );

      expect(source, isNot(contains('json')));
      expect(source, isNot(contains('Json')));
      expect(source, isNot(contains('part ')));
      expect(
        source,
        contains('final class EventTypeModel extends Equatable {'),
      );
    });
  });
}

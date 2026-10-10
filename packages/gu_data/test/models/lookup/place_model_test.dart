// T-08 · PlaceModel: const satır sınıfı, değer eşitliği, JSON yok
// (PLAN §9.1, §9.9).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../../helpers/repo_sources.dart';

void main() {
  group('T-08 · PlaceModel', () {
    test('alanı taşır', () {
      expect(const PlaceModel(id: 'pl01').id, 'pl01');
    });

    test('const örnekler kanonikleşir', () {
      expect(
        identical(const PlaceModel(id: 'pl01'), const PlaceModel(id: 'pl01')),
        isTrue,
      );
    });

    test('aynı alan eşittir (const olmayan örnekler dahil)', () {
      final a = PlaceModel(id: ['pl', '01'].join());
      const b = PlaceModel(id: 'pl01');

      expect(identical(a, b), isFalse);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('farklı kimlik eşit değildir', () {
      expect(const PlaceModel(id: 'pl01'), isNot(const PlaceModel(id: 'pl02')));
    });

    test('props tek alanı içerir', () {
      expect(const PlaceModel(id: 'pl01').props, ['pl01']);
    });

    test('başka satır sınıfıyla eşit değildir', () {
      expect(const PlaceModel(id: 'x'), isNot(const EventTypeModel(id: 'x')));
    });

    test('toString alanı gösterir', () {
      expect(const PlaceModel(id: 'pl01').toString(), 'PlaceModel(pl01)');
    });

    test('JSON dönüşümü ve üretilen parça yok', () {
      final source = readRepoFile(
        'packages/gu_data/lib/src/models/lookup/place_model.dart',
      );

      expect(source, isNot(contains('json')));
      expect(source, isNot(contains('Json')));
      expect(source, isNot(contains('part ')));
      expect(source, contains('final class PlaceModel extends Equatable {'));
    });
  });
}

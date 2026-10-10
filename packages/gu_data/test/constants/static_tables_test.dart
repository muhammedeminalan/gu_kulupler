// T-08 · StaticTables: sayı, kimlik, bağ ve sıra paritesi —
// tool/seed/demo-data.json ve design/extracted/registry.json dosyalarından
// OKUNARAK (PLAN §9.9, domain-model §10).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../helpers/repo_sources.dart';

const String _sourcePath =
    'packages/gu_data/lib/src/constants/static_tables.dart';

final Map<String, Object?> _demo = readRepoJson('tool/seed/demo-data.json');
final Map<String, Object?> _registry = readRepoJson(
  'design/extracted/registry.json',
);

/// demo-data.json kökündeki [key] dizisinin nesne satırları.
List<Map<String, Object?>> _demoRows(String key) => [
  for (final row in _demo[key]! as List<Object?>) row! as Map<String, Object?>,
];

/// demo-data.json kökündeki [key] haritasının belgeleri.
List<Map<String, Object?>> _demoDocs(String key) => [
  for (final doc in (_demo[key]! as Map<String, Object?>).values)
    doc! as Map<String, Object?>,
];

/// [json] kökündeki [key] dizgi dizisi.
List<String> _strings(Map<String, Object?> json, String key) =>
    (json[key]! as List<Object?>).cast<String>();

/// `static_tables.dart` içindeki `static` üye adları, bildirim sırasıyla.
List<String> _sourceMembers() => [
  for (final match in RegExp(
    r'^ {2}static (?:const |final )?[\w<>, ]+? (\w+)(?: =|\()',
    multiLine: true,
  ).allMatches(readRepoFile(_sourcePath)))
    match.group(1)!,
];

/// PLAN §9.9 tablosunda [label] satırının "Sayı" hücresi.
int _planCount(String label) {
  final table = markdownTable(
    readRepoFile('docs/PLAN.md'),
    heading: '### 9.9 ',
  );
  expect(table.header.last, 'Sayı');
  return int.parse(table.rowWhereFirstCell(label).last);
}

void main() {
  group('T-08 · StaticTables · categories ↔ demo-data.json', () {
    final rows = _demoRows('categories');

    test('8 kategori', () {
      expect(rows, hasLength(8));
      expect(StaticTables.categories, hasLength(8));
      expect(_planCount('Kategoriler'), StaticTables.categories.length);
    });

    test('kimlik ve ikon, dosyadaki sırayla birebir', () {
      expect(StaticTables.categories, [
        for (final row in rows)
          CategoryModel(
            id: row['id']! as String,
            icon: row['icon']! as String,
          ),
      ]);
    });

    test('kimlikler k01–k08, ikonlar tasarım listesiyle aynı', () {
      expect(
        [for (final category in StaticTables.categories) category.id],
        ['k01', 'k02', 'k03', 'k04', 'k05', 'k06', 'k07', 'k08'],
      );
      expect(
        [for (final category in StaticTables.categories) category.icon],
        [
          'cpu',
          'flask-conical',
          'mountain',
          'palette',
          'heart-handshake',
          'briefcase',
          'gamepad-2',
          'newspaper',
        ],
      );
    });

    test('her ikon tasarım ikon kümesinde (registry.iconNames)', () {
      final iconNames = _strings(_registry, 'iconNames');

      for (final category in StaticTables.categories) {
        expect(iconNames, contains(category.icon), reason: category.id);
      }
    });

    test('demo dosyasındaki satırlar yalnızca id ve icon taşır', () {
      for (final row in rows) {
        expect(row.keys.toSet(), {'id', 'icon'});
      }
    });

    test('categoryIds = kategori kimlikleri (sıra korunur)', () {
      expect(StaticTables.categoryIds.toList(), [
        for (final row in rows) row['id'],
      ]);
    });
  });

  group('T-08 · StaticTables · interests ↔ demo-data.json', () {
    final rows = _demoRows('interests');

    test('16 ilgi alanı', () {
      expect(rows, hasLength(16));
      expect(StaticTables.interests, hasLength(16));
      expect(_planCount('İlgi alanları'), StaticTables.interests.length);
    });

    test('kimlik ve kategori bağı (cat → categoryId), sırayla birebir', () {
      expect(StaticTables.interests, [
        for (final row in rows)
          InterestModel(
            id: row['id']! as String,
            categoryId: row['cat']! as String,
          ),
      ]);
    });

    test('kimlikler i01–i16', () {
      expect(
        [for (final interest in StaticTables.interests) interest.id],
        [
          for (var n = 1; n <= 16; n++) 'i${n.toString().padLeft(2, '0')}',
        ],
      );
    });

    test('her ilgi alanı var olan bir kategoriye bağlı', () {
      for (final interest in StaticTables.interests) {
        expect(
          StaticTables.categoryIds,
          contains(interest.categoryId),
          reason: interest.id,
        );
      }
    });

    test('demo dosyasındaki satırlar yalnızca id ve cat taşır', () {
      for (final row in rows) {
        expect(row.keys.toSet(), {'id', 'cat'});
      }
    });

    test('interestIds = ilgi alanı kimlikleri (sıra korunur)', () {
      expect(StaticTables.interestIds.toList(), [
        for (final row in rows) row['id'],
      ]);
    });
  });

  group('T-08 · StaticTables · interestIdsOf', () {
    test('kategori başına beklenen kimlikler (tablo sırasıyla)', () {
      expect(StaticTables.interestIdsOf('k01'), ['i01', 'i02', 'i15']);
      expect(StaticTables.interestIdsOf('k02'), isEmpty);
      expect(StaticTables.interestIdsOf('k03'), ['i04', 'i05']);
      expect(StaticTables.interestIdsOf('k04'), ['i08', 'i09', 'i10', 'i14']);
      expect(StaticTables.interestIdsOf('k05'), ['i13']);
      expect(StaticTables.interestIdsOf('k06'), ['i03', 'i16']);
      expect(StaticTables.interestIdsOf('k07'), ['i11', 'i12']);
      expect(StaticTables.interestIdsOf('k08'), ['i06', 'i07']);
    });

    test('demo dosyasındaki cat bağlarıyla her kategori için aynı', () {
      final rows = _demoRows('interests');

      for (final category in StaticTables.categories) {
        expect(
          StaticTables.interestIdsOf(category.id),
          [
            for (final row in rows)
              if (row['cat'] == category.id) row['id'],
          ],
          reason: category.id,
        );
      }
    });

    test('kategoriler ilgi alanlarını böler: örtüşme yok, eksik yok', () {
      final all = [
        for (final category in StaticTables.categories)
          ...StaticTables.interestIdsOf(category.id),
      ];

      expect(all, hasLength(StaticTables.interests.length));
      expect(all.toSet(), StaticTables.interestIds);
    });

    test('bilinmeyen kategori boş liste döner', () {
      expect(StaticTables.interestIdsOf('k09'), isEmpty);
      expect(StaticTables.interestIdsOf(''), isEmpty);
      expect(StaticTables.interestIdsOf('K01'), isEmpty);
      expect(StaticTables.interestIdsOf('i01'), isEmpty);
    });

    test('dönen liste değiştirilemez', () {
      expect(
        () => StaticTables.interestIdsOf('k01').add('i99'),
        throwsUnsupportedError,
      );
      expect(
        () => StaticTables.interestIdsOf('k02').add('i99'),
        throwsUnsupportedError,
      );
    });

    test('Firestore arrayContainsAny sınırının (30) altında kalır', () {
      for (final category in StaticTables.categories) {
        expect(
          StaticTables.interestIdsOf(category.id).length,
          lessThanOrEqualTo(30),
        );
      }
    });
  });

  group('T-08 · StaticTables · departments ↔ demo-data.json', () {
    final rows = _demoRows('departments');

    test('24 bölüm', () {
      expect(rows, hasLength(24));
      expect(StaticTables.departments, hasLength(24));
      expect(_planCount('Bölümler'), StaticTables.departments.length);
    });

    test('kimlik ve fakülte bağı (faculty → facultyId), sırayla birebir', () {
      expect(StaticTables.departments, [
        for (final row in rows)
          DepartmentModel(
            id: row['id']! as String,
            facultyId: row['faculty']! as String,
          ),
      ]);
    });

    test('kimlikler d01–d24', () {
      expect(
        [for (final department in StaticTables.departments) department.id],
        [
          for (var n = 1; n <= 24; n++) 'd${n.toString().padLeft(2, '0')}',
        ],
      );
    });

    test('her bölüm var olan bir fakülteye bağlı', () {
      for (final department in StaticTables.departments) {
        expect(
          StaticTables.facultyIds,
          contains(department.facultyId),
          reason: department.id,
        );
      }
    });

    test('demo dosyasındaki satırlar yalnızca id ve faculty taşır', () {
      for (final row in rows) {
        expect(row.keys.toSet(), {'id', 'faculty'});
      }
    });

    test('departmentIds = bölüm kimlikleri (sıra korunur)', () {
      expect(StaticTables.departmentIds.toList(), [
        for (final row in rows) row['id'],
      ]);
    });
  });

  group('T-08 · StaticTables · faculties', () {
    test('6 fakülte, f1–f6', () {
      expect(StaticTables.faculties, const [
        FacultyModel(id: 'f1'),
        FacultyModel(id: 'f2'),
        FacultyModel(id: 'f3'),
        FacultyModel(id: 'f4'),
        FacultyModel(id: 'f5'),
        FacultyModel(id: 'f6'),
      ]);
      expect(_planCount('Fakülteler'), StaticTables.faculties.length);
    });

    test('demo dosyasındaki bölümlerin faculty değerlerinden türetilenle '
        'aynı (ilk görülme sırası)', () {
      final derived = <String>{
        for (final row in _demoRows('departments')) row['faculty']! as String,
      };

      expect(
        [for (final faculty in StaticTables.faculties) faculty.id],
        derived.toList(),
      );
    });

    test('prototip seed.js FACULTIES listesiyle aynı', () {
      final match = RegExp(
        r'const FACULTIES = \[([^\]]*)\];',
      ).firstMatch(readRepoFile('design/prototype/app/seed.js'))!;
      final ids = [
        for (final id in RegExp("'([^']+)'").allMatches(match.group(1)!))
          id.group(1),
      ];

      expect([for (final faculty in StaticTables.faculties) faculty.id], ids);
    });

    test('facultyIds = fakülte kimlikleri (sıra korunur)', () {
      expect(StaticTables.facultyIds.toList(), [
        'f1',
        'f2',
        'f3',
        'f4',
        'f5',
        'f6',
      ]);
    });
  });

  group('T-08 · StaticTables · departmentsOf', () {
    test('fakülte başına bölüm kimlikleri (tablo sırasıyla)', () {
      List<String> ids(String facultyId) => [
        for (final department in StaticTables.departmentsOf(facultyId))
          department.id,
      ];

      expect(ids('f1'), ['d01', 'd02', 'd03', 'd04', 'd05', 'd06', 'd07']);
      expect(ids('f2'), ['d08', 'd09']);
      expect(ids('f3'), ['d10', 'd11', 'd12', 'd13', 'd14', 'd15']);
      expect(ids('f4'), ['d16', 'd17', 'd18']);
      expect(ids('f5'), ['d19', 'd20']);
      expect(ids('f6'), ['d21', 'd22', 'd23', 'd24']);
    });

    test('dönen satırlar yalnızca istenen fakülteye ait', () {
      for (final faculty in StaticTables.faculties) {
        final departments = StaticTables.departmentsOf(faculty.id);

        expect(departments, isNotEmpty, reason: faculty.id);
        for (final department in departments) {
          expect(department.facultyId, faculty.id);
        }
      }
    });

    test('demo dosyasındaki faculty bağlarıyla her fakülte için aynı', () {
      final rows = _demoRows('departments');

      for (final faculty in StaticTables.faculties) {
        expect(
          [
            for (final department in StaticTables.departmentsOf(faculty.id))
              department.id,
          ],
          [
            for (final row in rows)
              if (row['faculty'] == faculty.id) row['id'],
          ],
          reason: faculty.id,
        );
      }
    });

    test('fakülteler bölümleri böler: örtüşme yok, eksik yok', () {
      final all = [
        for (final faculty in StaticTables.faculties)
          ...StaticTables.departmentsOf(faculty.id),
      ];

      expect(all, StaticTables.departments);
    });

    test('bilinmeyen fakülte boş liste döner', () {
      expect(StaticTables.departmentsOf('f7'), isEmpty);
      expect(StaticTables.departmentsOf(''), isEmpty);
      expect(StaticTables.departmentsOf('F1'), isEmpty);
      expect(StaticTables.departmentsOf('d01'), isEmpty);
    });

    test('dönen liste değiştirilemez', () {
      expect(
        () => StaticTables.departmentsOf(
          'f1',
        ).add(const DepartmentModel(id: 'd99', facultyId: 'f1')),
        throwsUnsupportedError,
      );
      expect(
        StaticTables.departmentsOf('f1').removeLast,
        throwsUnsupportedError,
      );
    });
  });

  group('T-08 · StaticTables · places ↔ demo-data.json', () {
    final ids = _strings(_demo, 'places');

    test('10 mekân', () {
      expect(ids, hasLength(10));
      expect(StaticTables.places, hasLength(10));
      expect(_planCount('Mekânlar'), StaticTables.places.length);
    });

    test('kimlikler dosyadaki sırayla birebir (pl01–pl10)', () {
      expect(StaticTables.places, [for (final id in ids) PlaceModel(id: id)]);
      expect(
        [for (final place in StaticTables.places) place.id],
        [
          for (var n = 1; n <= 10; n++) 'pl${n.toString().padLeft(2, '0')}',
        ],
      );
    });

    test('placeIds = mekân kimlikleri (sıra korunur)', () {
      expect(StaticTables.placeIds.toList(), ids);
    });
  });

  group('T-08 · StaticTables ↔ registry.json', () {
    test('years: 8 kod, sırayla birebir', () {
      expect(StaticTables.years, _strings(_registry, 'years'));
      expect(StaticTables.years, [
        'prep',
        '1',
        '2',
        '3',
        '4',
        '5plus',
        'master',
        'phd',
      ]);
      expect(_planCount('Yıllar'), StaticTables.years.length);
    });

    test('eventTypes: 5 tür, sırayla birebir', () {
      final codes = _strings(_registry, 'eventTypes');

      expect(StaticTables.eventTypes, [
        for (final code in codes) EventTypeModel(id: code),
      ]);
      expect(
        [for (final type in StaticTables.eventTypes) type.id],
        ['egitim', 'sosyal', 'gezi', 'yarisma', 'konferans'],
      );
      expect(_planCount('Etkinlik türleri'), StaticTables.eventTypes.length);
    });

    test('popularSearches: 6 sorgu, sırayla ve harfi harfine', () {
      expect(
        StaticTables.popularSearches,
        _strings(_registry, 'popularSearches'),
      );
      expect(StaticTables.popularSearches, [
        'Hackathon',
        'Doğa yürüyüşü',
        'Tiyatro',
        'E-spor',
        'Fotoğraf',
        'Satranç',
      ]);
      expect(
        _planCount('Popüler aramalar'),
        StaticTables.popularSearches.length,
      );
    });

    test(
      'popularSearches bileşik (NFC) harflerle yazılı, kenar boşluğu yok',
      () {
        for (final query in StaticTables.popularSearches) {
          expect(query, query.trim());
          expect(
            query.runes.where((rune) => rune >= 0x300 && rune <= 0x36F),
            isEmpty,
            reason: '$query: birleştirici işaret (NFD) içermemeli',
          );
        }
      },
    );

    test('PLAN §9.7 YearLevel / EventType JSON değerleriyle aynı (T-09 '
        "enum'ları bu kodları taşır)", () {
      final table = markdownTable(
        readRepoFile('docs/PLAN.md'),
        heading: '### 9.7 ',
      );
      List<String> jsonValues(String enumName) {
        final pair = RegExp(r"^\w+→'([^']*)'$");
        return [
          for (final span in codeSpans(
            table.rowWhereFirstCell('`$enumName`')[1],
          ))
            pair.firstMatch(span)!.group(1)!,
        ];
      }

      expect(jsonValues('YearLevel'), StaticTables.years);
      expect(jsonValues('EventType'), [
        for (final type in StaticTables.eventTypes) type.id,
      ]);
    });
  });

  group('T-08 · StaticTables · tekillik ve değişmezlik', () {
    final tables = <String, List<String>>{
      'categories': [for (final row in StaticTables.categories) row.id],
      'interests': [for (final row in StaticTables.interests) row.id],
      'faculties': [for (final row in StaticTables.faculties) row.id],
      'departments': [for (final row in StaticTables.departments) row.id],
      'places': [for (final row in StaticTables.places) row.id],
      'years': StaticTables.years,
      'eventTypes': [for (final row in StaticTables.eventTypes) row.id],
      'popularSearches': StaticTables.popularSearches,
    };

    test('sekiz tablonun satır sayıları: 8 · 16 · 6 · 24 · 10 · 8 · 5 · 6', () {
      expect(
        {for (final entry in tables.entries) entry.key: entry.value.length},
        {
          'categories': 8,
          'interests': 16,
          'faculties': 6,
          'departments': 24,
          'places': 10,
          'years': 8,
          'eventTypes': 5,
          'popularSearches': 6,
        },
      );
    });

    test('her tabloda kimlikler tekildir ve boş değildir', () {
      for (final MapEntry(key: name, value: ids) in tables.entries) {
        expect(ids.toSet(), hasLength(ids.length), reason: name);
        expect(ids, everyElement(isNotEmpty), reason: name);
      }
    });

    test('kimlik kümeleri liste uzunluğundadır', () {
      expect(StaticTables.categoryIds, hasLength(8));
      expect(StaticTables.interestIds, hasLength(16));
      expect(StaticTables.facultyIds, hasLength(6));
      expect(StaticTables.departmentIds, hasLength(24));
      expect(StaticTables.placeIds, hasLength(10));
    });

    test('kimlik uzayları ayrıktır (bir kimlik tek tabloya aittir)', () {
      final lookups = [
        StaticTables.categoryIds,
        StaticTables.interestIds,
        StaticTables.facultyIds,
        StaticTables.departmentIds,
        StaticTables.placeIds,
      ];
      final union = {for (final ids in lookups) ...ids};

      expect(union, hasLength(8 + 16 + 6 + 24 + 10));
    });

    test('kimlik kümeleri üyelik sorgusunu doğru yanıtlar', () {
      expect(StaticTables.categoryIds.contains('k01'), isTrue);
      expect(StaticTables.categoryIds.contains('k09'), isFalse);
      expect(StaticTables.categoryIds.contains('K01'), isFalse);
      expect(StaticTables.interestIds.contains('i16'), isTrue);
      expect(StaticTables.interestIds.contains('i17'), isFalse);
      expect(StaticTables.facultyIds.contains('f6'), isTrue);
      expect(StaticTables.facultyIds.contains('f0'), isFalse);
      expect(StaticTables.departmentIds.contains('d24'), isTrue);
      expect(StaticTables.departmentIds.contains('d25'), isFalse);
      expect(StaticTables.placeIds.contains('pl10'), isTrue);
      expect(StaticTables.placeIds.contains('pl11'), isFalse);
      expect(StaticTables.placeIds.contains(''), isFalse);
    });

    test('listeler değiştirilemez (const)', () {
      expect(
        () => StaticTables.categories.add(
          const CategoryModel(id: 'k09', icon: 'cpu'),
        ),
        throwsUnsupportedError,
      );
      expect(() => StaticTables.interests.removeLast(), throwsUnsupportedError);
      expect(() => StaticTables.faculties.clear(), throwsUnsupportedError);
      expect(
        () => StaticTables.departments.removeAt(0),
        throwsUnsupportedError,
      );
      expect(() => StaticTables.places.clear(), throwsUnsupportedError);
      expect(() => StaticTables.years.add('6'), throwsUnsupportedError);
      expect(() => StaticTables.eventTypes.clear(), throwsUnsupportedError);
      expect(
        () => StaticTables.popularSearches[0] = 'x',
        throwsUnsupportedError,
      );
    });

    test('kimlik kümeleri değiştirilemez', () {
      expect(() => StaticTables.categoryIds.add('k09'), throwsUnsupportedError);
      expect(
        () => StaticTables.interestIds.remove('i01'),
        throwsUnsupportedError,
      );
      expect(StaticTables.facultyIds.clear, throwsUnsupportedError);
      expect(
        () => StaticTables.departmentIds.add('d25'),
        throwsUnsupportedError,
      );
      expect(() => StaticTables.placeIds.add('pl11'), throwsUnsupportedError);
    });

    test('kimlik kümeleri her okumada aynı örnektir', () {
      expect(
        identical(StaticTables.categoryIds, StaticTables.categoryIds),
        isTrue,
      );
      expect(
        identical(StaticTables.departmentIds, StaticTables.departmentIds),
        isTrue,
      );
    });
  });

  group('T-08 · StaticTables ↔ demo belgeleri (kullanım paritesi)', () {
    test('her kulübün categoryId değeri tabloda', () {
      final clubs = _demoDocs('clubs');

      expect(clubs, hasLength(14));
      for (final club in clubs) {
        expect(
          StaticTables.categoryIds,
          contains(club['categoryId']),
          reason: '${club['id']}',
        );
      }
    });

    test(
      'her kullanıcının department, year ve interests değerleri tabloda',
      () {
        final users = _demoDocs('users');

        expect(users, hasLength(226));
        for (final user in users) {
          final id = '${user['id']}';
          final department = user['department'];
          final year = user['year'];

          if (department != null) {
            expect(
              StaticTables.departmentIds,
              contains(department),
              reason: id,
            );
          }
          if (year != null) {
            expect(StaticTables.years, contains(year), reason: id);
          }
          for (final interest in user['interests']! as List<Object?>) {
            expect(StaticTables.interestIds, contains(interest), reason: id);
          }
        }
      },
    );

    test('her etkinliğin type ve placeId değerleri tabloda', () {
      final events = _demoDocs('events');
      final typeIds = {for (final type in StaticTables.eventTypes) type.id};

      expect(events, hasLength(22));
      for (final event in events) {
        final id = '${event['id']}';
        final placeId = event['placeId'];

        expect(typeIds, contains(event['type']), reason: id);
        if (placeId != null) {
          expect(StaticTables.placeIds, contains(placeId), reason: id);
        }
      }
    });

    test('demo veri her kategoriyi, bölümü, ilgi alanını, mekânı ve türü '
        'en az bir kez kullanır (tabloda ölü satır yok)', () {
      final users = _demoDocs('users');
      final events = _demoDocs('events');

      expect(
        {for (final club in _demoDocs('clubs')) club['categoryId']},
        StaticTables.categoryIds,
      );
      expect(
        {for (final user in users) ?user['department']},
        StaticTables.departmentIds,
      );
      expect({
        for (final user in users) ...user['interests']! as List<Object?>,
      }, StaticTables.interestIds);
      expect(
        {for (final event in events) ?event['placeId']},
        StaticTables.placeIds,
      );
      expect(
        {for (final event in events) event['type']},
        {for (final type in StaticTables.eventTypes) type.id},
      );
    });
  });

  group('T-08 · StaticTables · kaynak sözleşmesi', () {
    final source = readRepoFile(_sourcePath);

    test('yalnızca PLAN §9.9 üyeleri bildirilir (fazla / eksik yok)', () {
      expect(_sourceMembers(), [
        'categories',
        'categoryIds',
        'interests',
        'interestIds',
        'interestIdsOf',
        'faculties',
        'facultyIds',
        'departments',
        'departmentIds',
        'departmentsOf',
        'places',
        'placeIds',
        'years',
        'eventTypes',
        'popularSearches',
      ]);
    });

    test('dosya yalnızca StaticTables sınıfını bildirir', () {
      final declarations = RegExp(
        '^(?:abstract |final |sealed |base |interface )*'
        r'(?:class|mixin|enum|extension)\b.*$',
        multiLine: true,
      ).allMatches(source).map((m) => m.group(0)).toList();

      expect(declarations, ['abstract final class StaticTables {']);
    });

    test('Flutter arayüzü, ARB ve Firebase içe aktarılmaz', () {
      final imports = [
        for (final match in RegExp(
          "^import '([^']+)';",
          multiLine: true,
        ).allMatches(source))
          match.group(1)!,
      ];

      expect(imports, isNotEmpty);
      expect(
        imports,
        everyElement(startsWith('package:gu_data/src/models/lookup/')),
      );
    });

    test('yasaklı adlar kullanılmaz (StaticLookups)', () {
      expect(source, isNot(contains('StaticLookups')));
    });
  });
}

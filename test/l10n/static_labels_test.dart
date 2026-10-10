// T-08 · StaticLabels: StaticTables kimliği → ARB metni. Her kimlik için TR
// ve EN etiket boş değil, doğru anahtardan geliyor ve tablo içinde tekil;
// tabloda olmayan kimlik olduğu gibi döner (PLAN §9.9).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/l10n/static_labels.dart';

import '../helpers/design_files.dart';
import '../helpers/pump_app.dart';

/// Bir statik tablo: kimlikler, etiket çözücü ve ARB anahtar öneki.
typedef _Table = ({
  String name,
  List<String> ids,
  String Function(BuildContext context, String id) resolve,
  String keyPrefix,
});

/// `k01` → `K01`, `prep` → `Prep`, `5plus` → `5plus`.
String _pascal(String id) => id[0].toUpperCase() + id.substring(1);

/// Tablonun [id] satırı için beklenen ARB anahtarı (PLAN §9.9 "ARB anahtar
/// deseni": `cat<PascalId>`, `interestI01`, `deptD01` …).
String _arbKey(_Table table, String id) => '${table.keyPrefix}${_pascal(id)}';

final List<_Table> _tables = [
  (
    name: 'category',
    ids: [for (final row in StaticTables.categories) row.id],
    resolve: StaticLabels.category,
    keyPrefix: 'cat',
  ),
  (
    name: 'interest',
    ids: [for (final row in StaticTables.interests) row.id],
    resolve: StaticLabels.interest,
    keyPrefix: 'interest',
  ),
  (
    name: 'faculty',
    ids: [for (final row in StaticTables.faculties) row.id],
    resolve: StaticLabels.faculty,
    keyPrefix: 'faculty',
  ),
  (
    name: 'department',
    ids: [for (final row in StaticTables.departments) row.id],
    resolve: StaticLabels.department,
    keyPrefix: 'dept',
  ),
  (
    name: 'place',
    ids: [for (final row in StaticTables.places) row.id],
    resolve: StaticLabels.place,
    keyPrefix: 'place',
  ),
  (
    name: 'year',
    ids: StaticTables.years,
    resolve: StaticLabels.year,
    keyPrefix: 'year',
  ),
  (
    name: 'eventType',
    ids: [for (final row in StaticTables.eventTypes) row.id],
    resolve: StaticLabels.eventType,
    keyPrefix: 'eventType',
  ),
];

/// [locale] diliyle çizilmiş ağacın bağlamı.
Future<BuildContext> _pumpContext(WidgetTester tester, Locale locale) async {
  await tester.pumpApp(const SizedBox.shrink(), locale: locale);
  return tester.element(find.byKey(kPumpAppChildKey));
}

void main() {
  group('T-08 · StaticLabels · tablolar', () {
    test('yedi tablo, toplam 77 kimlik (8 + 16 + 6 + 24 + 10 + 8 + 5)', () {
      expect(
        {for (final table in _tables) table.name: table.ids.length},
        {
          'category': 8,
          'interest': 16,
          'faculty': 6,
          'department': 24,
          'place': 10,
          'year': 8,
          'eventType': 5,
        },
      );
    });

    test('beklenen ARB anahtarları PLAN §9.9 desenleriyle aynı', () {
      _Table table(String name) => _tables.singleWhere((t) => t.name == name);

      expect(_arbKey(table('category'), 'k01'), 'catK01');
      expect(_arbKey(table('interest'), 'i16'), 'interestI16');
      expect(_arbKey(table('faculty'), 'f6'), 'facultyF6');
      expect(_arbKey(table('department'), 'd24'), 'deptD24');
      expect(_arbKey(table('place'), 'pl10'), 'placePl10');
      expect(
        [for (final id in StaticTables.years) _arbKey(table('year'), id)],
        [
          'yearPrep',
          'year1',
          'year2',
          'year3',
          'year4',
          'year5plus',
          'yearMaster',
          'yearPhd',
        ],
      );
      expect(
        [
          for (final type in StaticTables.eventTypes)
            _arbKey(table('eventType'), type.id),
        ],
        [
          'eventTypeEgitim',
          'eventTypeSosyal',
          'eventTypeGezi',
          'eventTypeYarisma',
          'eventTypeKonferans',
        ],
      );
    });

    for (final lang in ['tr', 'en']) {
      test('$lang ARB: her kimliğin anahtarı var, metni boş değil ve tablo '
          'içinde tekil', () {
        final arb = readJsonMap('lib/l10n/app_$lang.arb');

        for (final table in _tables) {
          final texts = <String>[];
          for (final id in table.ids) {
            final key = _arbKey(table, id);
            final text = arb[key];

            expect(text, isA<String>(), reason: '$lang · $key');
            expect((text as String).trim(), isNotEmpty, reason: '$lang · $key');
            texts.add(text);
          }
          expect(
            texts.toSet(),
            hasLength(texts.length),
            reason: '$lang · ${table.name}: yinelenen metin',
          );
        }
      });
    }
  });

  for (final lang in ['tr', 'en']) {
    group('T-08 · StaticLabels · $lang', () {
      for (final table in _tables) {
        testWidgets('${table.name}: her kimlik ARB metnine çözülür '
            '(${table.ids.length})', (tester) async {
          final context = await _pumpContext(tester, Locale(lang));
          final arb = readJsonMap('lib/l10n/app_$lang.arb');

          final labels = <String>[];
          for (final id in table.ids) {
            final label = table.resolve(context, id);
            final reason = '$lang · ${table.name} · $id';

            expect(label.trim(), isNotEmpty, reason: reason);
            expect(label, isNot(id), reason: reason);
            expect(label, arb[_arbKey(table, id)], reason: reason);
            labels.add(label);
          }
          expect(
            labels.toSet(),
            hasLength(table.ids.length),
            reason: '$lang · ${table.name}: iki kimlik aynı etikete çözüldü',
          );
        });
      }

      testWidgets('tabloda olmayan kimlik olduğu gibi döner (istisna yok)', (
        tester,
      ) async {
        final context = await _pumpContext(tester, Locale(lang));

        for (final table in _tables) {
          for (final unknown in ['', 'x', 'zz99', 'K01', ' k01', 'd25', '6']) {
            if (table.ids.contains(unknown)) continue;
            expect(
              table.resolve(context, unknown),
              unknown,
              reason: '${table.name} · "$unknown"',
            );
          }
        }
      });

      testWidgets('kimlik yalnızca kendi tablosunda çözülür', (tester) async {
        final context = await _pumpContext(tester, Locale(lang));

        for (final table in _tables) {
          for (final other in _tables) {
            if (identical(other, table)) continue;
            for (final id in other.ids) {
              if (table.ids.contains(id)) continue;
              expect(
                table.resolve(context, id),
                id,
                reason: '${table.name} ← ${other.name} · $id',
              );
            }
          }
        }
      });
    });
  }

  group('T-08 · StaticLabels · dil', () {
    testWidgets('açık örnekler: TR ve EN metinleri', (tester) async {
      final tr = await _pumpContext(tester, const Locale('tr'));
      expect(StaticLabels.category(tr, 'k01'), 'Teknoloji');
      expect(StaticLabels.interest(tr, 'i11'), 'Satranç');
      expect(StaticLabels.faculty(tr, 'f3'), 'Edebiyat Fakültesi');
      expect(StaticLabels.department(tr, 'd01'), 'Bilgisayar Mühendisliği');
      expect(StaticLabels.place(tr, 'pl08'), 'Spor Salonu');
      expect(StaticLabels.year(tr, 'prep'), 'Hazırlık');
      expect(StaticLabels.year(tr, '5plus'), '5+ sınıf');
      expect(StaticLabels.eventType(tr, 'yarisma'), 'Yarışma');

      final en = await _pumpContext(tester, const Locale('en'));
      final arb = readJsonMap('lib/l10n/app_en.arb');
      expect(StaticLabels.category(en, 'k01'), arb['catK01']);
      expect(StaticLabels.category(en, 'k01'), isNot('Teknoloji'));
      expect(StaticLabels.year(en, 'prep'), isNot('Hazırlık'));
      expect(StaticLabels.eventType(en, 'yarisma'), isNot('Yarışma'));
    });

    testWidgets('dil değişince aynı kimlik yeni dilin metnine çözülür', (
      tester,
    ) async {
      final trArb = readJsonMap('lib/l10n/app_tr.arb');
      final enArb = readJsonMap('lib/l10n/app_en.arb');

      final tr = await _pumpContext(tester, const Locale('tr'));
      final trLabels = [
        for (final table in _tables)
          for (final id in table.ids) table.resolve(tr, id),
      ];
      final en = await _pumpContext(tester, const Locale('en'));
      final enLabels = [
        for (final table in _tables)
          for (final id in table.ids) table.resolve(en, id),
      ];

      expect(trLabels, [
        for (final table in _tables)
          for (final id in table.ids) trArb[_arbKey(table, id)],
      ]);
      expect(enLabels, [
        for (final table in _tables)
          for (final id in table.ids) enArb[_arbKey(table, id)],
      ]);
      expect(trLabels, isNot(enLabels));
    });
  });

  group('T-08 · static_labels.dart · kaynak sözleşmesi', () {
    final source = readText('lib/product/l10n/static_labels.dart');

    test('yedi çözücü: category, interest, faculty, department, place, year, '
        'eventType', () {
      final members = [
        for (final match in RegExp(
          r'^ {2}static String (\w+)\(BuildContext context, String id\) \{$',
          multiLine: true,
        ).allMatches(source))
          match.group(1)!,
      ];

      expect(members, [for (final table in _tables) table.name]);
    });

    test('her tablo satırı için tam bir switch kolu (fazla / eksik yok)', () {
      final keys = [
        for (final match in RegExp(
          r"^ {6}'[^']+' => l10n\.(\w+),$",
          multiLine: true,
        ).allMatches(source))
          match.group(1)!,
      ];

      expect(keys, [
        for (final table in _tables)
          for (final id in table.ids) _arbKey(table, id),
      ]);
    });

    test('yerelleştirme nesnesi l10n adıyla tutulur (ARB14 taraması)', () {
      expect(
        'final l10n = AppLocalizations.of(context);'.allMatches(source),
        hasLength(_tables.length),
      );
      expect(source, isNot(contains('_l10n')));
    });

    test('gu_data ve Firebase içe aktarılmaz (yalnızca kimlik → metin)', () {
      final imports = [
        for (final match in RegExp(
          "^import '([^']+)';",
          multiLine: true,
        ).allMatches(source))
          match.group(1)!,
      ];

      expect(imports, [
        'package:flutter/widgets.dart',
        'package:gu_kulupler/l10n/app_localizations.dart',
      ]);
    });
  });
}

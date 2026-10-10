// Ekranlar envanterden niteliğe göre seçilir (literal tasarım kimliği
// yazılmaz): `tool/check_design_coverage.js` TEST01 test metninde kimlik
// arar; yardımcı testi ekran testinin yerine sayılmasın.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import 'action_inventory.dart';
import 'design_files.dart';
import 'design_ids.dart';
import 'pump_app.dart';

bool _isExempt(String action) =>
    matchesAnyGlob(ActionInventory.exemptPatterns, action);

ScreenMeta _screen(bool Function(ScreenMeta meta) where) =>
    DesignIds.screenMeta.values.firstWhere(where);

/// Küçük envanterli misafir ekranı (3–6 aksiyon; muafsız, tek önek).
final ScreenMeta _small = _screen(
  (m) =>
      m.roles == 'guest' &&
      m.actions.length >= 3 &&
      m.actions.length <= 6 &&
      m.actions.every(
        (a) => !_isExempt(a) && ActionInventory.prefixOf(a) == m.id,
      ),
);

/// Tek muaf (demo) aksiyonlu ekran.
final ScreenMeta _oneExempt = _screen(
  (m) => m.actions.where(_isExempt).length == 1,
);

/// Birden çok muaf aksiyonlu ekran.
final ScreenMeta _manyExempt = _screen(
  (m) => m.actions.where(_isExempt).length > 1,
);

/// Envanterinde başka tasarım kimliği öneki (dialog) olan ekran.
final ScreenMeta _crossPrefix = _screen(
  (m) => m.actions.any((a) {
    final p = ActionInventory.prefixOf(a);
    return p != m.id && p != kNavPrefix;
  }),
);

final String _clubsRoot = DesignIds.tabRoots['clubs']!;
final String _adminRoot = DesignIds.tabRoots['admin']!;

/// Sentetik ekran: her anahtar için `GuKey.action` anahtarlı bir `SizedBox`
/// (+ ilgisiz anahtarlar: başka tasarım kimliği, NAV, düz ValueKey).
Widget _syntheticScreen(Iterable<String> keys) => Column(
  children: [
    for (final k in keys) SizedBox(key: GuKey.action(k), height: 1),
    SizedBox(key: GuKey.action('${DesignIds.sheets.first}.tr'), height: 1),
    SizedBox(key: GuKey.action('NAV.tab.clubs'), height: 1),
    const SizedBox(key: ValueKey<String>('liste.basi'), height: 1),
  ],
);

void main() {
  final small = _small.actions.toSet();

  group('T-02 · ActionInventory (D-18, CD-86, CD-122)', () {
    test('load: 51 ekran; toplam aksiyon ve muaf sayısı task-map ile eşit', () {
      final inv = ActionInventory.load();
      expect(inv, hasLength(51));
      for (final MapEntry(key: id, value: actions) in inv.entries) {
        expect(actions, DesignIds.screenMeta[id]!.actions.toSet());
      }
      final totals =
          readJsonMap('docs/task-map.json')['totals'] as Map<String, dynamic>;
      final all = [
        for (final m in DesignIds.screenMeta.values) ...m.actions,
      ];
      expect(all, hasLength(totals['actions'] as int));
      expect(all.where(_isExempt), hasLength(totals['exemptActions'] as int));
    });

    test('muaf kalıplar dosyadan (5); JS aynı iki dosyayı okur', () {
      expect(ActionInventory.exemptPatterns, hasLength(5));
      final all = [
        for (final m in DesignIds.screenMeta.values) ...m.actions,
      ];
      for (final p in ActionInventory.exemptPatterns) {
        expect(all.where(globToRegExp(p).hasMatch), isNotEmpty, reason: p);
      }
      expect(
        ActionInventory.dynamicPatterns,
        readPatterns(kDynamicActionsFile),
      );
      final js = readText('tool/check_design_coverage.js');
      expect(js, contains("'$kExemptActionsFile'"));
      expect(js, contains("'$kDynamicActionsFile'"));
    });

    test('expected: muaf (demo) aksiyonlar düşer', () {
      final one = ActionInventory.expected(_oneExempt.id);
      expect(one, hasLength(_oneExempt.actions.length - 1));
      expect(one.where(_isExempt), isEmpty);
      final many = ActionInventory.expected(_manyExempt.id);
      expect(
        many,
        hasLength(_manyExempt.actions.where((a) => !_isExempt(a)).length),
      );
      expect(
        ActionInventory.expected(_oneExempt.id, exemptPatterns: const []),
        _oneExempt.actions.toSet(),
      );
    });

    test(
      'expected: NAV.* yalnızca includeShell + sekme kökünde (K-17, CD-53)',
      () {
        final nav = {
          for (final tab in ['clubs', 'events', 'notifications', 'profile'])
            'NAV.tab.$tab',
        };
        expect(ActionInventory.isTabRoot(_clubsRoot), isTrue);
        expect(ActionInventory.isTabRoot(_small.id), isFalse);
        expect(ActionInventory.expected(_clubsRoot).intersection(nav), isEmpty);
        expect(
          ActionInventory.expected(_clubsRoot, includeShell: true),
          containsAll(nav),
        );
        expect(
          ActionInventory.expected(_adminRoot, includeShell: true),
          contains('NAV.tab.admin'),
        );
        expect(
          ActionInventory.expected(_small.id, includeShell: true),
          ActionInventory.expected(_small.id),
        );
      },
    );

    test('expand: * şablonu bulunanlara genişler; jokersiz şablon kalır', () {
      expect(
        ActionInventory.expand(
          {'XYZ-01.myClub.*', 'XYZ-01.search', 'QQ-02.club.*'},
          {'XYZ-01.myClub.c01', 'XYZ-01.myClub.c02', 'XYZ-01.card.c01'},
        ),
        {'XYZ-01.myClub.c01', 'XYZ-01.myClub.c02', 'XYZ-01.search'},
      );
      expect(ActionInventory.expand(const {}, {'XYZ-01.x'}), isEmpty);
    });

    test('roleCovers: all ⊇ hepsi · member ⊇ üye/yönetici/admin · '
        'bilinmeyen rol hata', () {
      expect(ActionInventory.roleCovers('all', 'guest'), isTrue);
      expect(ActionInventory.roleCovers('member', 'member'), isTrue);
      expect(ActionInventory.roleCovers('member', 'manager'), isTrue);
      expect(ActionInventory.roleCovers('member', 'admin'), isTrue);
      expect(ActionInventory.roleCovers('member', 'guest'), isFalse);
      expect(ActionInventory.roleCovers('manager', 'member'), isFalse);
      expect(ActionInventory.roleCovers('guest', 'member'), isFalse);
      expect(ActionInventory.roleCovers('admin', 'admin'), isTrue);
      expect(
        () => ActionInventory.roleCovers('all', 'student'),
        throwsArgumentError,
      );
    });

    test('bilinmeyen ekran ArgumentError', () {
      expect(
        () => ActionInventory.diff('XYZ-98', const {}),
        throwsArgumentError,
      );
      expect(() => ActionInventory.expected('XYZ-98'), throwsArgumentError);
    });

    group('sentetik ekran ağacı (küçük misafir ekranı)', () {
      testWidgets('tam küme → yeşil; ilgisiz anahtarlar yok sayılır', (
        tester,
      ) async {
        await tester.pumpApp(_syntheticScreen(small));
        final found = ActionInventory.found(tester);
        expect(found, {
          ...small,
          '${DesignIds.sheets.first}.tr',
          'NAV.tab.clubs',
        });
        final diff = ActionInventory.diff(_small.id, found);
        expect(diff.isClean, isTrue, reason: diff.describe());
        expect(diff.found, small);
        expect(diff.expected, small);
        expectActionInventory(tester, _small.id);
        expectActionInventory(tester, _small.id, role: 'guest');
      });

      testWidgets('eksik anahtar → kırmızı; extraExempt gerekçeler', (
        tester,
      ) async {
        final dropped = small.last;
        await tester.pumpApp(_syntheticScreen(small.difference({dropped})));
        final diff = ActionInventory.diff(
          _small.id,
          ActionInventory.found(tester),
        );
        expect(diff.isClean, isFalse);
        expect(diff.missing, {dropped});
        expect(diff.extra, isEmpty);
        expect(
          () => expectActionInventory(tester, _small.id),
          throwsA(
            isA<TestFailure>().having(
              (e) => e.message,
              'message',
              allOf(contains('eksik (1)'), contains(dropped)),
            ),
          ),
        );
        expectActionInventory(tester, _small.id, extraExempt: {dropped});
      });

      testWidgets('fazla (dinamik olmayan) anahtar → kırmızı', (tester) async {
        final bogus = '${_small.id}.bogus';
        await tester.pumpApp(_syntheticScreen({...small, bogus}));
        final diff = ActionInventory.diff(
          _small.id,
          ActionInventory.found(tester),
        );
        expect(diff.extra, {bogus});
        expect(diff.missing, isEmpty);
        expect(
          () => expectActionInventory(tester, _small.id),
          throwsA(
            isA<TestFailure>().having(
              (e) => e.message,
              'message',
              allOf(contains('fazla (1)'), contains(bogus)),
            ),
          ),
        );
      });

      testWidgets('dinamik kalıba uyan fazla anahtar aklanır (CD-86)', (
        tester,
      ) async {
        final dots = {'${_small.id}.dot.0', '${_small.id}.dot.1'};
        await tester.pumpApp(_syntheticScreen({...small, ...dots}));
        final diff = ActionInventory.diff(
          _small.id,
          ActionInventory.found(tester),
          dynamicPatterns: ['${_small.id}.dot.*'],
        );
        expect(diff.isClean, isTrue, reason: diff.describe());
        expect(diff.dynamicFound, dots);
      });

      testWidgets('rol kapsamı: misafir ekranı member rolüyle kırmızı', (
        tester,
      ) async {
        await tester.pumpApp(_syntheticScreen(small));
        expect(
          () => expectActionInventory(tester, _small.id, role: 'member'),
          throwsA(
            isA<TestFailure>().having(
              (e) => e.message,
              'message',
              contains('"member" rolü ${_small.id}'),
            ),
          ),
        );
      });
    });

    test('muaf (demo) aksiyon uygulanmışsa kırmızı (K-02)', () {
      final demo = _oneExempt.actions.singleWhere(_isExempt);
      final found = {...ActionInventory.expected(_oneExempt.id), demo};
      final diff = ActionInventory.diff(_oneExempt.id, found);
      expect(diff.exemptFound, {demo});
      expect(diff.extra, isEmpty);
      expect(diff.missing, isEmpty);
      expect(diff.isClean, isFalse);
      expect(diff.describe(), contains('muaf (demo)'));
    });

    test('NAV.* kuralı: sekme kökünde kabuk açıkken beklenir', () {
      final screen = ActionInventory.expected(_clubsRoot);
      final withShell = ActionInventory.expected(
        _clubsRoot,
        includeShell: true,
      );
      final nav = withShell.difference(screen);
      expect(nav, hasLength(4));

      expect(
        ActionInventory.diff(_clubsRoot, withShell, includeShell: true).isClean,
        isTrue,
      );
      expect(
        ActionInventory.diff(_clubsRoot, screen, includeShell: true).missing,
        nav,
      );
      // Kabuk kapalı: NAV.* ne beklenir ne fazla sayılır.
      expect(ActionInventory.diff(_clubsRoot, withShell).isClean, isTrue);
      expect(ActionInventory.diff(_clubsRoot, screen).isClean, isTrue);
      // Sekme kökü olmayan ekranda NAV.* yok sayılır.
      final diff = ActionInventory.diff(_small.id, {
        ...small,
        'NAV.tab.clubs',
      }, includeShell: true);
      expect(diff.isClean, isTrue);
      expect(diff.found, small);
    });

    test('envanterdeki diğer önekler (ör. dialog) beklenir ve sayılır', () {
      final all = ActionInventory.expected(_crossPrefix.id);
      final foreign = all.firstWhere(
        (a) => ActionInventory.prefixOf(a) != _crossPrefix.id,
      );
      final prefix = ActionInventory.prefixOf(foreign)!;
      final unrelated = DesignIds.dialogs.firstWhere(
        (d) => all.every((a) => ActionInventory.prefixOf(a) != d),
      );
      final diff = ActionInventory.diff(_crossPrefix.id, {
        ...all.difference({foreign}),
        '$prefix.bogus',
        '$unrelated.other',
      });
      expect(diff.missing, {foreign});
      expect(diff.extra, {'$prefix.bogus'});
    });

    test('role: screens-actions roles alanı kapsamalı (CD-122(6))', () {
      final member = _screen((m) => m.roles == 'member');
      final expected = ActionInventory.expected(member.id);
      expect(
        ActionInventory.diff(member.id, expected, role: 'manager').isClean,
        isTrue,
      );
      final guest = ActionInventory.diff(member.id, expected, role: 'guest');
      expect(guest.roleError, contains('roles: member'));
      expect(guest.isClean, isFalse);
      final manager = _screen((m) => m.roles == 'manager');
      expect(
        ActionInventory.diff(
          manager.id,
          ActionInventory.expected(manager.id),
          role: 'member',
        ).roleError,
        isNotNull,
      );
    });
  });
}

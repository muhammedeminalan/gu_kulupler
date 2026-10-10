// Beklentiler registry/envanter JSON'undan okunur (literal tasarım kimliği
// yazılmaz; `tool/check_design_coverage.js` TEST01 test metninde kimlik arar).
import 'package:flutter_test/flutter_test.dart';

import 'design_files.dart';
import 'design_ids.dart';

void main() {
  final registry = readJsonMap('design/extracted/registry.json');
  final inventory = readJsonMap('design/extracted/screens-actions.json');

  group('T-02 · DesignIds (registry.json + screens-actions.json)', () {
    test('sayılar: 51 ekran · 34 sheet · 32 dialog · 78 toast · 2 menü · '
        '5 sekme kökü', () {
      expect(DesignIds.screens, hasLength(51));
      expect(DesignIds.sheets, hasLength(34));
      expect(DesignIds.dialogs, hasLength(32));
      expect(DesignIds.toasts, hasLength(78));
      expect(DesignIds.menus, hasLength(2));
      expect(DesignIds.menus, registry['menus']);
      expect(DesignIds.tabRoots, hasLength(5));
      expect(DesignIds.tabRoots, registry['tabRoot']);
      expect(DesignIds.tabRoots.keys.toSet(), {...registry['tabs'] as List});
      expect(DesignIds.screens, containsAll(DesignIds.tabRoots.values));
    });

    test('kimlikler benzersiz ve önek biçimli', () {
      for (final (ids, pattern) in [
        (DesignIds.screens, RegExp(r'^[A-Z]{3}-\d{2}$')),
        (DesignIds.sheets, RegExp(r'^SHT-\d{2}$')),
        (DesignIds.dialogs, RegExp(r'^DLG-\d{2}$')),
        (DesignIds.toasts, RegExp(r'^TST-X?\d{1,2}$')),
      ]) {
        expect(ids.toSet(), hasLength(ids.length));
        expect(ids.where((id) => !pattern.hasMatch(id)), isEmpty);
      }
    });

    test('screenMeta: 51 ekran, path/roles/user/actions envanterle eşit', () {
      expect(DesignIds.screenMeta.keys, DesignIds.screens);
      expect(DesignIds.screenMeta.keys.toSet(), inventory.keys.toSet());
      for (final MapEntry(key: id, value: meta)
          in DesignIds.screenMeta.entries) {
        final inv = inventory[id] as Map<String, dynamic>;
        expect(meta.id, id);
        expect(meta.path, inv['path'], reason: id);
        expect(meta.roles, inv['roles'], reason: id);
        expect(meta.user, inv['user'], reason: id);
        expect(meta.actions, inv['actions'], reason: id);
        expect(meta.actions, hasLength(inv['actionCount'] as int), reason: id);
      }
    });

    test('screenMeta: sekme ve başlık anahtarı registry ile eşit', () {
      for (final screen
          in (registry['screens'] as List<dynamic>)
              .cast<Map<String, dynamic>>()) {
        final meta = DesignIds.screenMeta[screen['id']]!;
        expect(meta.tab, screen['tab'], reason: meta.id);
        expect(meta.titleKey, screen['titleKey'], reason: meta.id);
      }
      expect(
        DesignIds.screenMeta.values.where((m) => m.tab == null),
        isNotEmpty,
      );
      expect(
        DesignIds.screenMeta.values.map((m) => m.roles).toSet(),
        {'all', 'guest', 'member', 'manager', 'admin'},
      );
    });

    test('ScreenMeta eşitliği tüm alanlarla (Equatable props)', () {
      final meta = DesignIds.screenMeta.values.first;
      ScreenMeta copy({String? path, List<String>? actions}) => ScreenMeta(
        id: meta.id,
        tab: meta.tab,
        titleKey: meta.titleKey,
        path: path ?? meta.path,
        roles: meta.roles,
        user: meta.user,
        actions: actions ?? meta.actions,
      );
      expect(copy(), meta);
      expect(copy(path: '/baska'), isNot(meta));
      expect(copy(actions: const ['x']), isNot(meta));
      expect(meta.props, hasLength(7));
    });
  });
}

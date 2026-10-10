// T-11 · DebugMenu · demo hesaplar: `DebugDemoAccounts` ↔
// `design/extracted/registry.json#demoAccounts` (kimlik, sıra, rol) ve
// `tool/seed/demo-data.json` (e-posta, demo parolası). Beklentiler dosyadan
// okunur; seed değişirse test kırılır.
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/features/system/debug_menu/provider/debug_demo_accounts.dart';

import '../../../../helpers/design_files.dart';

void main() {
  group('T-11 · DebugMenu · demo hesaplar', () {
    final registry = readJsonMap('design/extracted/registry.json');
    final seed = readJsonMap('tool/seed/demo-data.json');
    final demoAccounts = (registry['demoAccounts'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final users = seed['users'] as Map<String, dynamic>;

    test('altı hesap; kimlik ve sıra registry ile aynı', () {
      expect(DebugDemoAccounts.all, hasLength(6));
      expect(
        [for (final account in DebugDemoAccounts.all) account.id],
        [for (final account in demoAccounts) account['id']],
      );
    });

    test('rol registry `roleKey` ile aynı (`role.<ad>`)', () {
      expect(
        [for (final account in DebugDemoAccounts.all) account.role.name],
        [
          for (final account in demoAccounts)
            (account['roleKey'] as String).replaceFirst('role.', ''),
        ],
      );
      expect(DebugDemoRole.values, hasLength(6));
    });

    test('e-posta demo-data.json `users[id].email` ile aynı', () {
      for (final account in DebugDemoAccounts.all) {
        final user = users[account.id] as Map<String, dynamic>?;
        expect(user, isNotNull, reason: account.id);
        expect(account.email, user!['email'], reason: account.id);
      }
    });

    test('parola demo-data.json `meta.demoPassword` ile aynı', () {
      final meta = seed['meta'] as Map<String, dynamic>;
      expect(DebugDemoAccounts.password, meta['demoPassword']);
    });
  });
}

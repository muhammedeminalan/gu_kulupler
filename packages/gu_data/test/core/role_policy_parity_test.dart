// T-10 · RolePolicy ↔ firebase/test/expectations/role_policy.json paritesi
// (PLAN §11.6 (c), §16.6 satır 11). Aynı JSON'u Rules tarafında
// `firebase/test/parity.test.js` okur: tablo tek kaynaktan iki dile bağlanır;
// biri değişip diğeri değişmezse bu test (ya da Node eşi) kırılır.
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../helpers/repo_sources.dart';

const String _source = 'firebase/test/expectations/role_policy.json';

/// JSON sütunu → `RolePolicy.can` aktörü. `student` = kulüpte aktif üyeliği
/// olmayan kullanıcı; `superadmin` = üyeliği olmayan süper admin (claim).
const Map<String, ({ClubRole? role, bool isSuper})> _actors = {
  'student': (role: null, isSuper: false),
  'member': (role: ClubRole.member, isSuper: false),
  'board': (role: ClubRole.board, isSuper: false),
  'president': (role: ClubRole.president, isSuper: false),
  'advisor': (role: ClubRole.advisor, isSuper: false),
  'superadmin': (role: null, isSuper: true),
};

void main() {
  final json = readRepoJson(_source);
  final roles = (json['roles']! as List<Object?>).cast<String>();
  final permissions = (json['permissions']! as Map<String, Object?>).map(
    (name, holders) =>
        MapEntry(name, (holders! as List<Object?>).cast<String>()),
  );

  group('T-10 · RolePolicy ↔ role_policy.json', () {
    test('sütunlar ve izin adları Dart tanımlarıyla birebir', () {
      expect(roles, _actors.keys.toList());
      expect(
        permissions.keys.toSet(),
        {for (final permission in ClubPermission.values) permission.name},
      );
      for (final MapEntry(key: name, value: holders) in permissions.entries) {
        expect(roles, containsAll(holders), reason: name);
        expect(holders.toSet(), hasLength(holders.length), reason: name);
      }
    });

    test('her izin × rol hücresi RolePolicy.can ile aynı', () {
      var cells = 0;
      for (final permission in ClubPermission.values) {
        for (final MapEntry(key: column, value: actor) in _actors.entries) {
          cells++;
          expect(
            RolePolicy.can(permission, actor.role, isSuper: actor.isSuper),
            permissions[permission.name]!.contains(column),
            reason: '${permission.name} × $column',
          );
        }
      }
      expect(cells, ClubPermission.values.length * roles.length);
    });
  });
}

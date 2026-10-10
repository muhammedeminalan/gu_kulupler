// T-08 · RolePolicy: domain-model §3 rol/yetki matrisinin TABLO testi (her
// izin × rol hücresi), süper admin birleşimi, çıkarma / rol atama / devir
// hiyerarşisi (Rules M9–M11) ve ClubAccess çözümü (prototip `sel.mode`).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../helpers/repo_sources.dart';

/// Matris sütunları, domain-model §3 başlık sırasıyla.
const List<String> _columns = [
  'student',
  'member',
  'board',
  'president',
  'advisor',
  'superadmin',
];

/// domain-model §3 matrisi — beklenen değerler bu testte **açıkça** yazılıdır
/// (belgedeki gösterimle: `✓` izinli, `—` izinsiz).
///
/// Her satırın altı işareti sırasıyla şu sütunlardır:
/// student · member · board · president · advisor · superadmin.
/// `docs/domain-model.md` tablosu ayrıca ayrıştırılıp bu tabloyla
/// karşılaştırılır; belge ya da kod değişirse test kırılır.
const Map<ClubPermission, String> _matrixMarks = {
  ClubPermission.viewPublic: '✓ ✓ ✓ ✓ ✓ ✓',
  ClubPermission.apply: '✓ — — — — —',
  ClubPermission.viewInside: '— ✓ ✓ ✓ ✓ ✓',
  ClubPermission.comment: '— ✓ ✓ ✓ — —',
  ClubPermission.vote: '— ✓ ✓ ✓ — —',
  ClubPermission.createPost: '— — ✓ ✓ — —',
  ClubPermission.sendAnnouncementPush: '— — ✓ ✓ — —',
  ClubPermission.manageEvents: '— — ✓ ✓ — —',
  ClubPermission.takeAttendance: '— — ✓ ✓ — —',
  ClubPermission.decideApplications: '— — ✓ ✓ — —',
  ClubPermission.removeMember: '— — ✓ ✓ — ✓',
  ClubPermission.moderateContent: '— — ✓ ✓ — ✓',
  ClubPermission.editClubSettings: '— — ✓ ✓ — —',
  ClubPermission.assignRoles: '— — — ✓ — ✓',
  ClubPermission.transferPresidency: '— — — ✓ — ✓',
  ClubPermission.viewManagement: '— — ✓ ✓ ✓ ✓',
  ClubPermission.createClub: '— — — — — ✓',
  ClubPermission.suspendClub: '— — — — — ✓',
  ClubPermission.assignPresident: '— — — — — ✓',
  ClubPermission.moderateReports: '— — — — — ✓',
  ClubPermission.suspendUser: '— — — — — ✓',
};

/// [_matrixMarks] tablosunun bool karşılığı (izin → sütun sırasıyla hücreler).
final Map<ClubPermission, List<bool>> _matrix = {
  for (final MapEntry(key: permission, value: marks) in _matrixMarks.entries)
    permission: [for (final mark in marks.split(' ')) _markToBool(mark)],
};

bool _markToBool(String mark) => switch (mark) {
  '✓' => true,
  '—' => false,
  _ => throw StateError('Beklenmeyen işaret "$mark"'),
};

/// Bir matris sütununun [RolePolicy.can] girdisi.
typedef _Actor = ({ClubRole? role, bool isSuper});

/// Sütun adı → `can` girdisi. `student` = aktif üyeliği olmayan kullanıcı;
/// `superadmin` = üyeliği olmayan süper admin.
const Map<String, _Actor> _actors = {
  'student': (role: null, isSuper: false),
  'member': (role: ClubRole.member, isSuper: false),
  'board': (role: ClubRole.board, isSuper: false),
  'president': (role: ClubRole.president, isSuper: false),
  'advisor': (role: ClubRole.advisor, isSuper: false),
  'superadmin': (role: null, isSuper: true),
};

/// Aktör rolleri: aktif üyeliği olmayan (`null`) + dört kulüp rolü.
const List<ClubRole?> _actorRoles = [null, ...ClubRole.values];

bool _expected(ClubPermission permission, String column) =>
    _matrix[permission]![_columns.indexOf(column)];

/// [role] sütununda ✓ olan izinler ([RolePolicy.can] üzerinden).
Set<ClubPermission> _granted(ClubRole? role, {bool isSuper = false}) => {
  for (final permission in ClubPermission.values)
    if (RolePolicy.can(permission, role, isSuper: isSuper)) permission,
};

/// domain-model §3 tablosu: izin adı → hücreler (sütun sırasıyla).
///
/// İlk hücredeki her satır içi kod parçası bir izindir (`comment`, `vote`
/// aynı satırı paylaşır). Hücre `✓` ile başlıyorsa izinli, tam olarak `—` ise
/// izinsizdir; başka içerik hatadır.
Map<String, List<bool>> _docMatrix() {
  final table = markdownTable(
    readRepoFile('docs/domain-model.md'),
    heading: '## 3. ',
  );
  expect(table.header.first, 'İzin (`ClubPermission`)');
  expect(table.header.skip(1), _columns);

  final result = <String, List<bool>>{};
  for (final row in table.rows) {
    expect(row, hasLength(_columns.length + 1), reason: row.first);
    final cells = [
      for (final cell in row.skip(1))
        if (cell.startsWith('✓'))
          true
        else if (cell == '—')
          false
        else
          throw StateError('Beklenmeyen hücre "$cell" (${row.first})'),
    ];
    final names = codeSpans(row.first);
    expect(names, isNotEmpty, reason: row.first);
    for (final name in names) {
      expect(result, isNot(contains(name)), reason: 'yinelenen izin $name');
      result[name] = cells;
    }
  }
  return result;
}

/// Rules taslağındaki `function <name>(…) { … }` satırı.
String _rulesFunction(String name) =>
    readRepoFile('docs/firestore-rules-spec.md')
        .split('\n')
        .singleWhere((line) => line.trimLeft().startsWith('function $name('));

/// Rules satırındaki `role in [...]` listesinin rolleri.
Set<ClubRole> _rulesRoles(String name) {
  final list = RegExp(
    r'role in \[([^\]]*)\]',
  ).firstMatch(_rulesFunction(name))!.group(1)!;
  return {
    for (final match in RegExp("'([^']*)'").allMatches(list))
      ClubRole.fromJson(match.group(1)!),
  };
}

/// [permission] iznine sahip kulüp rolleri (süper admin değil).
Set<ClubRole> _rolesWith(ClubPermission permission) => {
  for (final role in ClubRole.values)
    if (RolePolicy.can(permission, role)) role,
};

void main() {
  group('T-08 · ClubPermission', () {
    test('21 izin, domain-model §3 satır sırasıyla', () {
      expect(
        [for (final permission in ClubPermission.values) permission.name],
        [
          'viewPublic',
          'apply',
          'viewInside',
          'comment',
          'vote',
          'createPost',
          'sendAnnouncementPush',
          'manageEvents',
          'takeAttendance',
          'decideApplications',
          'removeMember',
          'moderateContent',
          'editClubSettings',
          'assignRoles',
          'transferPresidency',
          'viewManagement',
          'createClub',
          'suspendClub',
          'assignPresident',
          'moderateReports',
          'suspendUser',
        ],
      );
    });

    test('belgedeki izin adları ve sırası enum ile birebir', () {
      expect(
        _docMatrix().keys.toList(),
        [for (final permission in ClubPermission.values) permission.name],
      );
    });

    test('test tablosu her izni tam bir kez, altı sütunla içerir', () {
      expect(_matrix.keys.toList(), ClubPermission.values);
      for (final MapEntry(key: permission, value: cells) in _matrix.entries) {
        expect(cells, hasLength(_columns.length), reason: permission.name);
      }
    });
  });

  group('T-08 · RolePolicy.can · matris (domain-model §3)', () {
    test('test tablosu belge tablosuyla hücre hücre aynı', () {
      final doc = _docMatrix();

      expect(doc, hasLength(_matrix.length));
      for (final permission in ClubPermission.values) {
        expect(
          _matrix[permission],
          doc[permission.name],
          reason: '${permission.name}: $_columns',
        );
      }
    });

    for (final permission in ClubPermission.values) {
      for (final column in _columns) {
        final expected = _expected(permission, column);

        test('${permission.name} × $column → ${expected ? '✓' : '—'}', () {
          final actor = _actors[column]!;

          expect(
            RolePolicy.can(permission, actor.role, isSuper: actor.isSuper),
            expected,
          );
        });
      }
    }

    test('126 hücrenin tamamı sınandı (21 izin × 6 sütun)', () {
      expect(_matrix.length * _columns.length, 126);
      expect(_actors.keys.toList(), _columns);
    });

    test('sütun başına ✓ sayısı: 2 · 4 · 13 · 15 · 3 · 12', () {
      expect(
        {
          for (final MapEntry(key: column, value: actor) in _actors.entries)
            column: _granted(actor.role, isSuper: actor.isSuper).length,
        },
        {
          'student': 2,
          'member': 4,
          'board': 13,
          'president': 15,
          'advisor': 3,
          'superadmin': 12,
        },
      );
    });

    test('isSuper varsayılanı false', () {
      for (final permission in ClubPermission.values) {
        for (final role in _actorRoles) {
          expect(
            RolePolicy.can(permission, role),
            // Varsayılanın açık değerle aynı sonucu verdiği sınanır.
            // ignore: avoid_redundant_argument_values
            RolePolicy.can(permission, role, isSuper: false),
            reason: '${permission.name} × $role',
          );
        }
      }
    });
  });

  group('T-08 · RolePolicy.can · rol kümeleri', () {
    test('öğrenci (aktif üyelik yok): yalnızca viewPublic ve apply', () {
      expect(_granted(null), {ClubPermission.viewPublic, ClubPermission.apply});
    });

    test('üye: görür, yorum yazar, oy verir; yönetemez', () {
      expect(_granted(ClubRole.member), {
        ClubPermission.viewPublic,
        ClubPermission.viewInside,
        ClubPermission.comment,
        ClubPermission.vote,
      });
    });

    test('danışman: yalnızca görür (salt okunur) — yazma izni yok', () {
      expect(_granted(ClubRole.advisor), {
        ClubPermission.viewPublic,
        ClubPermission.viewInside,
        ClubPermission.viewManagement,
      });
    });

    test(
      'yönetim kurulu: üye izinleri + yönetim (rol atama ve devir hariç)',
      () {
        expect(_granted(ClubRole.board), {
          ..._granted(ClubRole.member),
          ClubPermission.createPost,
          ClubPermission.sendAnnouncementPush,
          ClubPermission.manageEvents,
          ClubPermission.takeAttendance,
          ClubPermission.decideApplications,
          ClubPermission.removeMember,
          ClubPermission.moderateContent,
          ClubPermission.editClubSettings,
          ClubPermission.viewManagement,
        });
      },
    );

    test('başkan: yönetim kurulu izinleri + rol atama ve devir', () {
      expect(_granted(ClubRole.president), {
        ..._granted(ClubRole.board),
        ClubPermission.assignRoles,
        ClubPermission.transferPresidency,
      });
    });

    test('süper admin (üyeliksiz): görür, moderasyon ve çıkarma yapar, '
        'global yönetir; kulüp adına içerik / etkinlik oluşturmaz', () {
      expect(_granted(null, isSuper: true), {
        ClubPermission.viewPublic,
        ClubPermission.viewInside,
        ClubPermission.removeMember,
        ClubPermission.moderateContent,
        ClubPermission.assignRoles,
        ClubPermission.transferPresidency,
        ClubPermission.viewManagement,
        ClubPermission.createClub,
        ClubPermission.suspendClub,
        ClubPermission.assignPresident,
        ClubPermission.moderateReports,
        ClubPermission.suspendUser,
      });
    });

    test('hiyerarşi: üye ⊂ yönetim kurulu ⊂ başkan', () {
      final member = _granted(ClubRole.member);
      final board = _granted(ClubRole.board);
      final president = _granted(ClubRole.president);

      expect(board.containsAll(member), isTrue);
      expect(president.containsAll(board), isTrue);
      expect(board.length, greaterThan(member.length));
      expect(president.length, greaterThan(board.length));
    });

    test('apply yalnızca üyeliksiz öğrencide: hiçbir aktif rol başvuramaz', () {
      for (final role in ClubRole.values) {
        expect(RolePolicy.can(ClubPermission.apply, role), isFalse);
      }
    });

    test('global izinler (ADM) hiçbir kulüp rolünde yok', () {
      const global = [
        ClubPermission.createClub,
        ClubPermission.suspendClub,
        ClubPermission.assignPresident,
        ClubPermission.moderateReports,
        ClubPermission.suspendUser,
      ];

      for (final permission in global) {
        for (final role in _actorRoles) {
          expect(
            RolePolicy.can(permission, role),
            isFalse,
            reason: '${permission.name} × $role',
          );
        }
      }
    });
  });

  group('T-08 · RolePolicy.can · süper admin + kulüp rolü', () {
    test('her hücre: rol sütunu ∪ superadmin sütunu', () {
      for (final permission in ClubPermission.values) {
        for (final role in ClubRole.values) {
          expect(
            RolePolicy.can(permission, role, isSuper: true),
            _expected(permission, role.json) ||
                _expected(permission, 'superadmin'),
            reason: '${permission.name} × ${role.name} + süper',
          );
        }
      }
    });

    test('süper admin olmak hiçbir rolün iznini azaltmaz', () {
      for (final role in ClubRole.values) {
        expect(
          _granted(role, isSuper: true).containsAll(_granted(role)),
          isTrue,
          reason: role.name,
        );
      }
    });

    test('üyeliksiz süper admin öğrenci sayılmaz: apply yok', () {
      expect(
        RolePolicy.can(ClubPermission.apply, null, isSuper: true),
        isFalse,
      );
    });

    test('hiçbir rol + süper admin birleşimi apply vermez', () {
      for (final role in ClubRole.values) {
        expect(
          RolePolicy.can(ClubPermission.apply, role, isSuper: true),
          isFalse,
          reason: role.name,
        );
      }
    });

    test(
      'üyeliksiz süper admin içerik / etkinlik oluşturamaz, yorum yazamaz',
      () {
        for (final permission in [
          ClubPermission.comment,
          ClubPermission.vote,
          ClubPermission.createPost,
          ClubPermission.sendAnnouncementPush,
          ClubPermission.manageEvents,
          ClubPermission.takeAttendance,
          ClubPermission.decideApplications,
          ClubPermission.editClubSettings,
        ]) {
          expect(
            RolePolicy.can(permission, null, isSuper: true),
            isFalse,
            reason: permission.name,
          );
        }
      },
    );

    test('kulüpte yönetici olan süper admin yönetici izinlerini korur '
        '(Rules: isSuper() || isManager(c))', () {
      expect(
        RolePolicy.can(
          ClubPermission.createPost,
          ClubRole.board,
          isSuper: true,
        ),
        isTrue,
      );
      expect(
        RolePolicy.can(ClubPermission.comment, ClubRole.member, isSuper: true),
        isTrue,
      );
      expect(
        RolePolicy.can(
          ClubPermission.createPost,
          ClubRole.member,
          isSuper: true,
        ),
        isFalse,
      );
    });

    test('danışman olan süper admin yine de yazma izni kazanmaz', () {
      expect(
        _granted(ClubRole.advisor, isSuper: true),
        _granted(null, isSuper: true),
      );
    });
  });

  group('T-08 · RolePolicy.can ↔ Rules yardımcıları', () {
    test('isMember rol listesi = comment / vote izinli roller', () {
      expect(_rolesWith(ClubPermission.comment), _rulesRoles('isMember'));
      expect(_rolesWith(ClubPermission.vote), _rulesRoles('isMember'));
    });

    test('isManager rol listesi = yönetici izinli roller', () {
      for (final permission in [
        ClubPermission.createPost,
        ClubPermission.sendAnnouncementPush,
        ClubPermission.manageEvents,
        ClubPermission.takeAttendance,
        ClubPermission.decideApplications,
        ClubPermission.removeMember,
        ClubPermission.moderateContent,
        ClubPermission.editClubSettings,
      ]) {
        expect(
          _rolesWith(permission),
          _rulesRoles('isManager'),
          reason: permission.name,
        );
      }
    });

    test('isPres = rol atama ve devir izinli tek rol', () {
      expect(
        _rulesFunction('isPres'),
        contains("role == '${RoleCodes.president}'"),
      );
      expect(_rolesWith(ClubPermission.assignRoles), {ClubRole.president});
      expect(_rolesWith(ClubPermission.transferPresidency), {
        ClubRole.president,
      });
    });

    test(
      'seesInside = isSuper() || mActive(c): her aktif rol + süper admin',
      () {
        expect(
          _rulesFunction('seesInside'),
          contains('return isSuper() || mActive(c);'),
        );
        expect(_rolesWith(ClubPermission.viewInside), ClubRole.values.toSet());
        expect(
          RolePolicy.can(ClubPermission.viewInside, null, isSuper: true),
          isTrue,
        );
        expect(RolePolicy.can(ClubPermission.viewInside, null), isFalse);
      },
    );

    test('seesMgmt = isSuper() || isManager(c) || isAdvisor(c)', () {
      expect(
        _rulesFunction('seesMgmt'),
        contains('return isSuper() || isManager(c) || isAdvisor(c);'),
      );
      expect(_rolesWith(ClubPermission.viewManagement), {
        ..._rulesRoles('isManager'),
        ClubRole.advisor,
      });
      expect(
        RolePolicy.can(ClubPermission.viewManagement, null, isSuper: true),
        isTrue,
      );
    });
  });

  group('T-08 · RolePolicy.canRemove (Rules M9)', () {
    // Beklenen izinli (aktör, hedef) çiftleri — açıkça yazılı.
    const allowed = <(ClubRole?, ClubRole)>{
      (ClubRole.board, ClubRole.member),
      (ClubRole.president, ClubRole.member),
      (ClubRole.president, ClubRole.board),
    };
    const removableBySuper = {ClubRole.member, ClubRole.board};

    for (final actor in _actorRoles) {
      for (final target in ClubRole.values) {
        final expected = allowed.contains((actor, target));

        test('${actor?.name ?? 'üyeliksiz'} → ${target.name}: '
            '${expected ? 'çıkarır' : 'çıkaramaz'}', () {
          expect(RolePolicy.canRemove(actor, target), expected);
        });
      }
    }

    test('20 (aktör, hedef) çiftinin 3 tanesi izinli', () {
      expect(_actorRoles.length * ClubRole.values.length, 20);
      expect(allowed, hasLength(3));
    });

    test('süper admin: kendi rolünden bağımsız olarak member ve board üyeyi '
        'çıkarır', () {
      for (final actor in _actorRoles) {
        for (final target in ClubRole.values) {
          expect(
            RolePolicy.canRemove(actor, target, isSuper: true),
            removableBySuper.contains(target),
            reason: '${actor?.name} → ${target.name}',
          );
        }
      }
    });

    test('başkan hiçbir koşulda çıkarılamaz (önce devir)', () {
      for (final actor in _actorRoles) {
        for (final isSuper in [false, true]) {
          expect(
            RolePolicy.canRemove(actor, ClubRole.president, isSuper: isSuper),
            isFalse,
            reason: '${actor?.name}, süper=$isSuper',
          );
        }
      }
    });

    test('danışman bu yolla çıkarılamaz (Rules M13, memberCount dışı)', () {
      for (final actor in _actorRoles) {
        for (final isSuper in [false, true]) {
          expect(
            RolePolicy.canRemove(actor, ClubRole.advisor, isSuper: isSuper),
            isFalse,
            reason: '${actor?.name}, süper=$isSuper',
          );
        }
      }
    });

    test('yönetim kurulu üyesi başka bir yönetim kurulu üyesini çıkaramaz', () {
      expect(RolePolicy.canRemove(ClubRole.board, ClubRole.board), isFalse);
      expect(
        RolePolicy.canRemove(ClubRole.board, ClubRole.board, isSuper: true),
        isTrue,
      );
    });

    test('izinli her çıkarma removeMember iznini gerektirir', () {
      for (final actor in _actorRoles) {
        for (final target in ClubRole.values) {
          for (final isSuper in [false, true]) {
            if (RolePolicy.canRemove(actor, target, isSuper: isSuper)) {
              expect(
                RolePolicy.can(
                  ClubPermission.removeMember,
                  actor,
                  isSuper: isSuper,
                ),
                isTrue,
              );
            }
          }
        }
      }
    });

    test('Rules M9 satırı aynı hiyerarşiyi tanımlar: hedef yalnızca member / '
        'board (başkan ve danışman hariç)', () {
      final spec = readRepoFile('docs/firestore-rules-spec.md');
      final row = spec
          .split('\n')
          .singleWhere((line) => line.startsWith('| M9 |'));

      expect(row, contains('`isPres(c)` `member` ve `board` üyeyi'));
      expect(row, contains("`isManager(c)` yalnızca `role=='member'`"));
      expect(
        row,
        contains(
          '`isSuper()` `member` ve `board` üyeyi (başkan ve danışman '
          'hariç)',
        ),
      );
      expect(row, contains("`resource.role in ['member','board']`"));
      // Eski, danışmanı kapsayan koşul geri gelmemeli (sayaç kayması).
      expect(row, isNot(contains("`resource.role != 'president'`")));
      expect(row, isNot(contains('herkesi (başkan hariç)')));
    });

    test('Rules M9 hedef kümesi = canRemove ile çıkarılabilen roller', () {
      final row = readRepoFile(
        'docs/firestore-rules-spec.md',
      ).split('\n').singleWhere((line) => line.startsWith('| M9 |'));
      final list = RegExp(
        r'`resource\.role in \[([^\]]*)\]`',
      ).firstMatch(row)!.group(1)!;
      final specTargets = {
        for (final match in RegExp("'([^']*)'").allMatches(list))
          ClubRole.fromJson(match.group(1)!),
      };
      final removable = {
        for (final target in ClubRole.values)
          if (_actorRoles.any(
            (actor) =>
                RolePolicy.canRemove(actor, target) ||
                RolePolicy.canRemove(actor, target, isSuper: true),
          ))
            target,
      };

      expect(specTargets, {ClubRole.member, ClubRole.board});
      expect(removable, specTargets);
    });

    test('danışman memberCount dışıdır: çıkarma (sayaç −1) hiçbir aktöre açık '
        'değil — PLAN §11.2 M9 ve T-30 Rules testi aynı kuralı taşır', () {
      final row = readRepoFile('docs/PLAN.md')
          .split('\n')
          .singleWhere(
            (line) => line.startsWith('| M9 | `active → removed` |'),
          );

      expect(row, contains("`resource.data.role in ['member','board']`"));
      expect(row, isNot(contains("`resource.data.role != 'president'`")));
      expect(row, contains('`M9 advisor cannot be removed`'));
      expect(row, contains('`counterDelta −1`'));
      for (final actor in _actorRoles) {
        for (final isSuper in [false, true]) {
          expect(
            RolePolicy.canRemove(actor, ClubRole.advisor, isSuper: isSuper),
            isFalse,
            reason: '${actor?.name}, süper=$isSuper',
          );
        }
      }
    });
  });

  group('T-08 · RolePolicy.canAssignRole (Rules M10)', () {
    // (hedefin rolü, yeni rol): yalnızca member ↔ board arasında.
    const assignable = <(ClubRole, ClubRole)>{
      (ClubRole.member, ClubRole.member),
      (ClubRole.member, ClubRole.board),
      (ClubRole.board, ClubRole.member),
      (ClubRole.board, ClubRole.board),
    };

    test('başkan: member ↔ board atar; başka hiçbir (hedef, yeni rol) çifti '
        'izinli değil', () {
      for (final target in ClubRole.values) {
        for (final newRole in ClubRole.values) {
          expect(
            RolePolicy.canAssignRole(ClubRole.president, target, newRole),
            assignable.contains((target, newRole)),
            reason: '${target.name} → ${newRole.name}',
          );
        }
      }
    });

    test(
      'başkan olmayan (ve süper admin olmayan) hiçbir aktör rol atayamaz',
      () {
        for (final actor in [
          null,
          ClubRole.member,
          ClubRole.board,
          ClubRole.advisor,
        ]) {
          for (final target in ClubRole.values) {
            for (final newRole in ClubRole.values) {
              expect(
                RolePolicy.canAssignRole(actor, target, newRole),
                isFalse,
                reason: '${actor?.name}: ${target.name} → ${newRole.name}',
              );
            }
          }
        }
      },
    );

    test('süper admin: kendi rolünden bağımsız olarak member ↔ board atar', () {
      for (final actor in _actorRoles) {
        for (final target in ClubRole.values) {
          for (final newRole in ClubRole.values) {
            expect(
              RolePolicy.canAssignRole(actor, target, newRole, isSuper: true),
              assignable.contains((target, newRole)),
              reason: '${actor?.name}: ${target.name} → ${newRole.name}',
            );
          }
        }
      }
    });

    test('president rolü atamayla verilmez (yalnızca devir)', () {
      for (final target in ClubRole.values) {
        expect(
          RolePolicy.canAssignRole(
            ClubRole.president,
            target,
            ClubRole.president,
          ),
          isFalse,
        );
        expect(
          RolePolicy.canAssignRole(
            null,
            target,
            ClubRole.president,
            isSuper: true,
          ),
          isFalse,
        );
      }
    });

    test('advisor rolü atamayla verilmez (Rules M13)', () {
      for (final target in ClubRole.values) {
        expect(
          RolePolicy.canAssignRole(
            ClubRole.president,
            target,
            ClubRole.advisor,
          ),
          isFalse,
        );
        expect(
          RolePolicy.canAssignRole(
            null,
            target,
            ClubRole.advisor,
            isSuper: true,
          ),
          isFalse,
        );
      }
    });

    test('başkanın ve danışmanın rolü atamayla değiştirilemez', () {
      for (final target in [ClubRole.president, ClubRole.advisor]) {
        for (final newRole in ClubRole.values) {
          expect(
            RolePolicy.canAssignRole(ClubRole.president, target, newRole),
            isFalse,
          );
          expect(
            RolePolicy.canAssignRole(null, target, newRole, isSuper: true),
            isFalse,
          );
        }
      }
    });

    test('açık örnekler: yükseltme ve düşürme', () {
      expect(
        RolePolicy.canAssignRole(
          ClubRole.president,
          ClubRole.member,
          ClubRole.board,
        ),
        isTrue,
      );
      expect(
        RolePolicy.canAssignRole(
          ClubRole.president,
          ClubRole.board,
          ClubRole.member,
        ),
        isTrue,
      );
      expect(
        RolePolicy.canAssignRole(
          ClubRole.board,
          ClubRole.member,
          ClubRole.board,
        ),
        isFalse,
      );
    });

    test('izinli her atama assignRoles iznini gerektirir', () {
      for (final actor in _actorRoles) {
        for (final isSuper in [false, true]) {
          final any = ClubRole.values.any(
            (target) => ClubRole.values.any(
              (newRole) => RolePolicy.canAssignRole(
                actor,
                target,
                newRole,
                isSuper: isSuper,
              ),
            ),
          );

          expect(
            any,
            RolePolicy.can(ClubPermission.assignRoles, actor, isSuper: isSuper),
            reason: '${actor?.name}, süper=$isSuper',
          );
        }
      }
    });

    test('Rules M10 satırı aynı kuralı tanımlar', () {
      final row = readRepoFile(
        'docs/firestore-rules-spec.md',
      ).split('\n').singleWhere((line) => line.startsWith('| M10 |'));

      expect(row, contains('`isPres(c)` veya `isSuper()`'));
      expect(row, contains('yeni rol ∈ `member,board`'));
      expect(row, contains('`president` rolüne **yalnızca devirle**'));
      expect(row, contains("`resource.role in ['member','board']`"));
    });

    test('danışmanın rolü atamayla değiştirilemez (memberCount dışı üyelik '
        'sayaçsız üyeye dönüşmesin) — PLAN §11.2 M10 aynı kümeyi ister', () {
      final row = readRepoFile('docs/PLAN.md')
          .split('\n')
          .singleWhere((line) => line.startsWith('| M10 | rol değişimi |'));

      expect(row, contains("`resource.data.role in ['member','board']`"));
      expect(row, isNot(contains("`resource.data.role != 'president'`")));
      expect(row, contains('`M10 advisor role cannot be changed`'));
      for (final actor in _actorRoles) {
        for (final isSuper in [false, true]) {
          for (final newRole in ClubRole.values) {
            expect(
              RolePolicy.canAssignRole(
                actor,
                ClubRole.advisor,
                newRole,
                isSuper: isSuper,
              ),
              isFalse,
              reason: '${actor?.name}, süper=$isSuper → ${newRole.name}',
            );
          }
        }
      }
    });
  });

  group('T-08 · RolePolicy.canTransfer (Rules M11)', () {
    const targets = {ClubRole.member, ClubRole.board};

    for (final actor in _actorRoles) {
      for (final target in ClubRole.values) {
        final expected =
            actor == ClubRole.president && targets.contains(target);

        test('${actor?.name ?? 'üyeliksiz'} → ${target.name}: '
            '${expected ? 'devreder' : 'devredemez'}', () {
          expect(RolePolicy.canTransfer(actor, target), expected);
        });
      }
    }

    test(
      'yalnızca başkan devreder: (president, member) ve (president, board)',
      () {
        final allowed = {
          for (final actor in _actorRoles)
            for (final target in ClubRole.values)
              if (RolePolicy.canTransfer(actor, target)) (actor, target),
        };

        expect(allowed, {
          (ClubRole.president, ClubRole.member),
          (ClubRole.president, ClubRole.board),
        });
      },
    );

    test('süper admin: kendi rolünden bağımsız olarak member ve board üyeye '
        'devreder', () {
      for (final actor in _actorRoles) {
        for (final target in ClubRole.values) {
          expect(
            RolePolicy.canTransfer(actor, target, isSuper: true),
            targets.contains(target),
            reason: '${actor?.name} → ${target.name}',
          );
        }
      }
    });

    test('mevcut başkana ve danışmana devir yapılamaz', () {
      for (final target in [ClubRole.president, ClubRole.advisor]) {
        expect(RolePolicy.canTransfer(ClubRole.president, target), isFalse);
        expect(RolePolicy.canTransfer(null, target, isSuper: true), isFalse);
      }
    });

    test('izinli her devir transferPresidency iznini gerektirir', () {
      for (final actor in _actorRoles) {
        for (final isSuper in [false, true]) {
          final any = ClubRole.values.any(
            (target) => RolePolicy.canTransfer(actor, target, isSuper: isSuper),
          );

          expect(
            any,
            RolePolicy.can(
              ClubPermission.transferPresidency,
              actor,
              isSuper: isSuper,
            ),
            reason: '${actor?.name}, süper=$isSuper',
          );
        }
      }
    });

    test('Rules M11 satırı aynı kuralı tanımlar', () {
      final row = readRepoFile(
        'docs/firestore-rules-spec.md',
      ).split('\n').singleWhere((line) => line.startsWith('| M11 |'));

      expect(row, contains('`isPres(c)` veya `isSuper()`'));
      expect(row, contains(r'yeni `member\|board→president` (`active`)'));
    });
  });

  group('T-08 · ClubAccess', () {
    test('yedi kip, PLAN §9.1 sırasıyla', () {
      expect(
        [for (final access in ClubAccess.values) access.name],
        [
          'visitor',
          'pending',
          'rejected',
          'member',
          'manager',
          'advisor',
          'superAdmin',
        ],
      );
    });

    test('PLAN §9.1 enum bildirimiyle aynı değerler', () {
      final plan = readRepoFile('docs/PLAN.md');
      final declaration = RegExp(
        r'`enum ClubAccess \{ ([^}]*) \}`',
      ).firstMatch(plan)!.group(1)!;

      expect(
        [for (final name in declaration.split(',')) name.trim()],
        [for (final access in ClubAccess.values) access.name],
      );
    });
  });

  group('T-08 · RolePolicy.activeRole (Rules mActive)', () {
    const statuses = MembershipStatus.values;

    // Tablo: altı durum × (dört rol + rol yok) — yalnızca `active` rol taşır.
    for (final status in statuses) {
      for (final role in _actorRoles) {
        final expected = status == MembershipStatus.active ? role : null;

        test('durum=${status.json}, rol=${role?.name ?? '∅'} → '
            '${expected?.name ?? '∅'}', () {
          expect(RolePolicy.activeRole(status: status, role: role), expected);
        });
      }
    }

    test('üyelik belgesi yok (durum ve rol null) → rol yok', () {
      expect(RolePolicy.activeRole(), isNull);
      for (final role in ClubRole.values) {
        expect(RolePolicy.activeRole(role: role), isNull, reason: role.name);
      }
    });

    test('aktif olmayan üyelik hiçbir üye / yönetici iznini vermez: sonuç '
        'öğrenci (student) sütunudur', () {
      final student = _granted(null);

      for (final status in statuses) {
        if (status == MembershipStatus.active) continue;
        for (final role in ClubRole.values) {
          final resolved = RolePolicy.activeRole(status: status, role: role);

          expect(
            _granted(resolved),
            student,
            reason: 'durum=$status, rol=${role.name}',
          );
        }
      }
      expect(student, {ClubPermission.viewPublic, ClubPermission.apply});
    });

    test('başvuran (pending, role: member — Rules M1) kulüp içini göremez, '
        'yorum yazamaz, oy veremez', () {
      final role = RolePolicy.activeRole(
        status: MembershipStatus.pending,
        role: ClubRole.member,
      );

      for (final permission in [
        ClubPermission.viewInside,
        ClubPermission.comment,
        ClubPermission.vote,
      ]) {
        expect(
          RolePolicy.can(permission, role),
          isFalse,
          reason: '$permission',
        );
      }
      // Rolü doğrudan vermek tam da bu hatayı üretir (belgelenen tuzak).
      expect(
        RolePolicy.can(ClubPermission.viewInside, ClubRole.member),
        isTrue,
      );
    });

    test('çıkarılmış / ayrılmış yönetici yönetim iznini kaybeder', () {
      for (final status in [
        MembershipStatus.removed,
        MembershipStatus.left,
      ]) {
        for (final role in [ClubRole.board, ClubRole.president]) {
          final resolved = RolePolicy.activeRole(status: status, role: role);

          for (final permission in [
            ClubPermission.viewManagement,
            ClubPermission.decideApplications,
            ClubPermission.removeMember,
            ClubPermission.createPost,
          ]) {
            expect(
              RolePolicy.can(permission, resolved),
              isFalse,
              reason: 'durum=$status, rol=${role.name}, $permission',
            );
          }
          expect(RolePolicy.canRemove(resolved, ClubRole.member), isFalse);
          expect(RolePolicy.canTransfer(resolved, ClubRole.member), isFalse);
        }
      }
    });

    test('aktif üyelikte rol aynen döner ve matris sütununu verir', () {
      for (final role in ClubRole.values) {
        final resolved = RolePolicy.activeRole(
          status: MembershipStatus.active,
          role: role,
        );

        expect(resolved, role);
        expect(_granted(resolved), _granted(role));
      }
    });

    test('accessOf aynı çözümü kullanır: aktif rol yoksa kip üye / yönetici / '
        'danışman olamaz', () {
      const insiders = {
        ClubAccess.member,
        ClubAccess.manager,
        ClubAccess.advisor,
      };

      for (final status in <MembershipStatus?>[null, ...statuses]) {
        for (final role in _actorRoles) {
          final access = RolePolicy.accessOf(
            isSuper: false,
            status: status,
            role: role,
          );
          final resolved = RolePolicy.activeRole(status: status, role: role);

          expect(
            insiders.contains(access),
            resolved != null,
            reason: 'durum=$status, rol=${role?.name}',
          );
        }
      }
    });

    test('Rules mActive yardımcısı aynı koşulu kullanır (status == '
        "'active')", () {
      expect(_rulesFunction('mActive'), contains("status == 'active'"));
    });
  });

  group('T-08 · RolePolicy.accessOf', () {
    // (durum, rol) → beklenen kip — açıkça yazılı; süper admin değil.
    const expectations = <(MembershipStatus?, ClubRole?), ClubAccess>{
      // Üyelik belgesi yok.
      (null, null): ClubAccess.visitor,
      // Başvuru bekliyor / reddedildi (belgede rol 'member' yazılıdır).
      (MembershipStatus.pending, ClubRole.member): ClubAccess.pending,
      (MembershipStatus.pending, null): ClubAccess.pending,
      (MembershipStatus.rejected, ClubRole.member): ClubAccess.rejected,
      (MembershipStatus.rejected, null): ClubAccess.rejected,
      // Aktif üyelik: rol belirler.
      (MembershipStatus.active, ClubRole.member): ClubAccess.member,
      (MembershipStatus.active, ClubRole.board): ClubAccess.manager,
      (MembershipStatus.active, ClubRole.president): ClubAccess.manager,
      (MembershipStatus.active, ClubRole.advisor): ClubAccess.advisor,
      // Aktif ama rolü verilmemiş: en az yetki.
      (MembershipStatus.active, null): ClubAccess.visitor,
      // Biten üyelikler: ziyaretçi (rol ne olursa olsun).
      (MembershipStatus.removed, ClubRole.member): ClubAccess.visitor,
      (MembershipStatus.removed, ClubRole.board): ClubAccess.visitor,
      (MembershipStatus.left, ClubRole.member): ClubAccess.visitor,
      (MembershipStatus.left, ClubRole.board): ClubAccess.visitor,
      (MembershipStatus.left, ClubRole.president): ClubAccess.visitor,
      (MembershipStatus.left, ClubRole.advisor): ClubAccess.visitor,
      (MembershipStatus.cancelled, ClubRole.member): ClubAccess.visitor,
      (MembershipStatus.cancelled, null): ClubAccess.visitor,
    };

    for (final MapEntry(key: (status, role), value: expected)
        in expectations.entries) {
      test('durum=${status?.json ?? '∅'}, rol=${role?.name ?? '∅'} → '
          '${expected.name}', () {
        expect(
          RolePolicy.accessOf(isSuper: false, status: status, role: role),
          expected,
        );
      });
    }

    test('üyelik bilgisi verilmezse ziyaretçi', () {
      expect(RolePolicy.accessOf(isSuper: false), ClubAccess.visitor);
    });

    test('süper admin her üyelik durumunda superAdmin (önce gelir)', () {
      expect(RolePolicy.accessOf(isSuper: true), ClubAccess.superAdmin);
      for (final (status, role) in expectations.keys) {
        expect(
          RolePolicy.accessOf(isSuper: true, status: status, role: role),
          ClubAccess.superAdmin,
          reason: 'durum=$status, rol=$role',
        );
      }
    });

    test('pending / rejected durumunda rol yetki vermez (her rol için)', () {
      for (final role in _actorRoles) {
        expect(
          RolePolicy.accessOf(
            isSuper: false,
            status: MembershipStatus.pending,
            role: role,
          ),
          ClubAccess.pending,
        );
        expect(
          RolePolicy.accessOf(
            isSuper: false,
            status: MembershipStatus.rejected,
            role: role,
          ),
          ClubAccess.rejected,
        );
      }
    });

    test('altı durum kodunun tamamı sınanır', () {
      expect(
        {for (final (status, _) in expectations.keys) ?status},
        MembershipStatus.values.toSet(),
      );
    });

    test('her kip en az bir girdiyle üretilir', () {
      final produced = {
        RolePolicy.accessOf(isSuper: true),
        for (final (status, role) in expectations.keys)
          RolePolicy.accessOf(isSuper: false, status: status, role: role),
      };

      expect(produced, ClubAccess.values.toSet());
    });

    test('kulüp içini görme (viewInside) = member / manager / advisor / '
        'superAdmin kipleri (prototip canSeeInside)', () {
      const inside = {
        ClubAccess.member,
        ClubAccess.manager,
        ClubAccess.advisor,
        ClubAccess.superAdmin,
      };

      for (final isSuper in [false, true]) {
        for (final (status, role) in expectations.keys) {
          final access = RolePolicy.accessOf(
            isSuper: isSuper,
            status: status,
            role: role,
          );
          final activeRole = RolePolicy.activeRole(
            status: status,
            role: role,
          );

          expect(
            RolePolicy.can(
              ClubPermission.viewInside,
              activeRole,
              isSuper: isSuper,
            ),
            inside.contains(access),
            reason: 'süper=$isSuper, durum=$status, rol=$role → $access',
          );
        }
      }
    });

    test('yönetim panelini görme (viewManagement) = manager / advisor / '
        'superAdmin kipleri', () {
      const management = {
        ClubAccess.manager,
        ClubAccess.advisor,
        ClubAccess.superAdmin,
      };

      for (final isSuper in [false, true]) {
        for (final (status, role) in expectations.keys) {
          final access = RolePolicy.accessOf(
            isSuper: isSuper,
            status: status,
            role: role,
          );
          final activeRole = RolePolicy.activeRole(
            status: status,
            role: role,
          );

          expect(
            RolePolicy.can(
              ClubPermission.viewManagement,
              activeRole,
              isSuper: isSuper,
            ),
            management.contains(access),
            reason: 'süper=$isSuper, durum=$status, rol=$role → $access',
          );
        }
      }
    });

    test('demo verideki 515 üyelik: durum × rol dağılımı beklenen kiplere '
        'çözülür', () {
      final memberships =
          readRepoJson('tool/seed/demo-data.json')['memberships']!
              as Map<String, Object?>;
      final counts = <ClubAccess, int>{};
      for (final doc in memberships.values) {
        final membership = doc! as Map<String, Object?>;
        final access = RolePolicy.accessOf(
          isSuper: false,
          status: MembershipStatus.fromJson(membership['status']! as String),
          role: ClubRole.fromJson(membership['role']! as String),
        );
        counts[access] = (counts[access] ?? 0) + 1;
      }

      expect(memberships, hasLength(515));
      expect(counts, {
        // 383 aktif üye.
        ClubAccess.member: 383,
        // 75 yönetim kurulu + 14 başkan.
        ClubAccess.manager: 89,
        // 14 danışman.
        ClubAccess.advisor: 14,
        // 23 bekleyen başvuru.
        ClubAccess.pending: 23,
        // 5 reddedilen başvuru.
        ClubAccess.rejected: 5,
        // 1 çıkarılmış üye.
        ClubAccess.visitor: 1,
      });
    });
  });

  group('T-08 · role_policy.dart · kaynak sözleşmesi', () {
    final source = readRepoFile(
      'packages/gu_data/lib/src/core/role_policy.dart',
    );

    test('ClubAccess, ClubPermission ve RolePolicy bildirilir; ClubRole '
        'burada tanımlanmaz (tek tanım models/enums/club_role.dart)', () {
      final declarations = RegExp(
        '^(?:abstract |final |sealed |base |interface )*'
        r'(?:class|mixin|enum|extension)\b.*$',
        multiLine: true,
      ).allMatches(source).map((m) => m.group(0)).toList();

      expect(declarations, [
        'enum ClubAccess {',
        'enum ClubPermission {',
        'abstract final class RolePolicy {',
        'enum _Holder { student, member, board, president, advisor, superadmin }',
      ]);
    });

    test('public statik üyeler: can, canRemove, canAssignRole, canTransfer, '
        'activeRole, accessOf', () {
      final members = [
        for (final match in RegExp(
          r'^ {2}static [\w<>?]+ ([a-zA-Z]\w*)\(',
          multiLine: true,
        ).allMatches(source))
          match.group(1)!,
      ];

      expect(members, [
        'can',
        'canRemove',
        'canAssignRole',
        'canTransfer',
        'activeRole',
        'accessOf',
      ]);
    });

    test('saf Dart: yalnızca gu_data içi içe aktarımlar', () {
      final imports = [
        for (final match in RegExp(
          "^import '([^']+)';",
          multiLine: true,
        ).allMatches(source))
          match.group(1)!,
      ];

      expect(imports, [
        'package:gu_data/src/models/enums/club_role.dart',
        'package:gu_data/src/models/enums/membership_status.dart',
      ]);
    });
  });
}

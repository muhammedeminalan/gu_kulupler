// T-08 · RoleCodes / MembershipStatusCodes: değerler, tekillik ve belge
// paritesi (domain-model §2.4, PLAN §9.7, Rules taslağı, demo veri).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../helpers/repo_sources.dart';

const Map<String, String> _roleCodes = {
  'member': RoleCodes.member,
  'board': RoleCodes.board,
  'president': RoleCodes.president,
  'advisor': RoleCodes.advisor,
  'superadmin': RoleCodes.superadmin,
};

const Map<String, String> _statusCodes = {
  'pending': MembershipStatusCodes.pending,
  'active': MembershipStatusCodes.active,
  'rejected': MembershipStatusCodes.rejected,
  'removed': MembershipStatusCodes.removed,
  'left': MembershipStatusCodes.left,
  'cancelled': MembershipStatusCodes.cancelled,
};

const String _sourcePath = 'packages/gu_data/lib/src/constants/role_codes.dart';

/// `role_codes.dart` içinde [className] sınıfının `static const String`
/// bildirimleri (ad → değer).
Map<String, String> _readSourceMembers(String className) {
  final source = readRepoFile(_sourcePath);
  final start = source.indexOf('abstract final class $className {');
  if (start < 0) throw StateError('$className bulunamadı');
  final end = source.indexOf('\n}', start);
  return {
    for (final match in RegExp(
      r"^ {2}static const String (\w+) = '([^']*)';",
      multiLine: true,
    ).allMatches(source.substring(start, end)))
      match.group(1)!: match.group(2)!,
  };
}

/// domain-model §2.4 tablosunda [field] satırının `a · b · c` değer listesi.
List<String> _schemaValues(String field) {
  final table = markdownTable(
    readRepoFile('docs/domain-model.md'),
    heading: '### 2.4 ',
  );
  final cell = table.rowWhereFirstCell('`$field`')[2];
  return [for (final value in codeSpans(cell).first.split('·')) value.trim()];
}

/// PLAN §9.7 tablosunda [enumName] satırının JSON değerleri (`dart→'json'`).
List<String> _planEnumJsonValues(String enumName) {
  final table = markdownTable(
    readRepoFile('docs/PLAN.md'),
    heading: '### 9.7 ',
  );
  final cell = table.rowWhereFirstCell('`$enumName`')[1];
  final pair = RegExp(r"^\w+→'([^']*)'$");
  return [for (final span in codeSpans(cell)) pair.firstMatch(span)!.group(1)!];
}

/// Rules taslağındaki `function <name>(…) { … }` satırı.
String _rulesFunction(String name) =>
    readRepoFile('docs/firestore-rules-spec.md')
        .split('\n')
        .singleWhere((line) => line.trimLeft().startsWith('function $name('));

/// Rules satırındaki `role in [...]` listesinin elemanları.
List<String> _roleList(String rulesLine) {
  final list = RegExp(r'role in \[([^\]]*)\]').firstMatch(rulesLine)!.group(1)!;
  return [
    for (final match in RegExp("'([^']*)'").allMatches(list)) match.group(1)!,
  ];
}

void main() {
  group('T-08 · RoleCodes · değerler', () {
    test('beş kod: member, board, president, advisor, superadmin', () {
      expect(_roleCodes, {
        'member': 'member',
        'board': 'board',
        'president': 'president',
        'advisor': 'advisor',
        'superadmin': 'superadmin',
      });
    });

    test('kodlar tekildir', () {
      expect(_roleCodes.values.toSet(), hasLength(5));
    });

    test('kaynak dosyada yalnızca bu beş üye var (ad = değer)', () {
      final source = _readSourceMembers('RoleCodes');

      expect(source, _roleCodes);
      expect(source.keys.toList(), _roleCodes.keys.toList());
    });

    test('kodlar küçük harf ASCII (Rules dizgi karşılaştırması birebir)', () {
      for (final code in [..._roleCodes.values, ..._statusCodes.values]) {
        expect(code, matches(RegExp(r'^[a-z]+$')));
      }
    });
  });

  group('T-08 · RoleCodes ↔ ClubRole', () {
    test('ClubRole.json kümesi = superadmin hariç RoleCodes', () {
      final clubCodes = {..._roleCodes.values}..remove(RoleCodes.superadmin);

      expect({for (final role in ClubRole.values) role.json}, clubCodes);
    });

    test('her kulüp rol kodu ClubRole üzerinden gidiş-dönüş yapar', () {
      for (final code in [
        RoleCodes.member,
        RoleCodes.board,
        RoleCodes.president,
        RoleCodes.advisor,
      ]) {
        expect(ClubRole.fromJson(code).json, code);
      }
    });

    test('kod ↔ enum eşlemesi ad ada', () {
      expect(ClubRole.fromJson(RoleCodes.member), ClubRole.member);
      expect(ClubRole.fromJson(RoleCodes.board), ClubRole.board);
      expect(ClubRole.fromJson(RoleCodes.president), ClubRole.president);
      expect(ClubRole.fromJson(RoleCodes.advisor), ClubRole.advisor);
    });

    test('superadmin kulüp rolü değildir (claim) — ClubRole reddeder', () {
      expect(
        () => ClubRole.fromJson(RoleCodes.superadmin),
        throwsArgumentError,
      );
    });
  });

  group('T-08 · RoleCodes · belge paritesi', () {
    test('domain-model §2.4 role listesi = kulüp rol kodları (sırayla)', () {
      expect(_schemaValues('role'), [
        RoleCodes.member,
        RoleCodes.board,
        RoleCodes.president,
        RoleCodes.advisor,
      ]);
    });

    test('PLAN §9.7 ClubRole JSON değerleri = kulüp rol kodları', () {
      expect(_planEnumJsonValues('ClubRole'), [
        RoleCodes.member,
        RoleCodes.board,
        RoleCodes.president,
        RoleCodes.advisor,
      ]);
    });

    test('Rules isMember listesi: member, board, president', () {
      expect(_roleList(_rulesFunction('isMember')), [
        RoleCodes.member,
        RoleCodes.board,
        RoleCodes.president,
      ]);
    });

    test('Rules isManager listesi: board, president', () {
      expect(_roleList(_rulesFunction('isManager')), [
        RoleCodes.board,
        RoleCodes.president,
      ]);
    });

    test('Rules isPres / isAdvisor tekil rol kodları', () {
      expect(
        _rulesFunction('isPres'),
        contains("role == '${RoleCodes.president}'"),
      );
      expect(
        _rulesFunction('isAdvisor'),
        contains("role == '${RoleCodes.advisor}'"),
      );
    });

    test('Rules isSuper claim adı = RoleCodes.superadmin', () {
      expect(
        _rulesFunction('isSuper'),
        contains("request.auth.token.get('${RoleCodes.superadmin}', false)"),
      );
    });

    test('demo verideki her üyelik rolü bir kulüp rol kodudur', () {
      final memberships =
          readRepoJson('tool/seed/demo-data.json')['memberships']!
              as Map<String, Object?>;
      final roles = {
        for (final doc in memberships.values)
          (doc! as Map<String, Object?>)['role']! as String,
      };

      expect(memberships, hasLength(515));
      expect(roles, {
        RoleCodes.member,
        RoleCodes.board,
        RoleCodes.president,
        RoleCodes.advisor,
      });
    });
  });

  group('T-08 · MembershipStatusCodes', () {
    test('altı kod: pending, active, rejected, removed, left, cancelled', () {
      expect(_statusCodes, {
        'pending': 'pending',
        'active': 'active',
        'rejected': 'rejected',
        'removed': 'removed',
        'left': 'left',
        'cancelled': 'cancelled',
      });
    });

    test('kodlar tekildir', () {
      expect(_statusCodes.values.toSet(), hasLength(6));
    });

    test('kaynak dosyada yalnızca bu altı üye var (ad = değer)', () {
      final source = _readSourceMembers('MembershipStatusCodes');

      expect(source, _statusCodes);
      expect(source.keys.toList(), _statusCodes.keys.toList());
    });

    test('domain-model §2.4 status listesi ile birebir (sırayla)', () {
      expect(_schemaValues('status'), _statusCodes.values.toList());
    });

    test('PLAN §9.7 MembershipStatus JSON değerleri ile birebir', () {
      expect(
        _planEnumJsonValues('MembershipStatus'),
        _statusCodes.values.toList(),
      );
    });

    test('Rules mActive durumu = MembershipStatusCodes.active', () {
      expect(
        _rulesFunction('mActive'),
        contains("status == '${MembershipStatusCodes.active}'"),
      );
    });

    test('demo verideki her üyelik durumu bir durum kodudur', () {
      final memberships =
          readRepoJson('tool/seed/demo-data.json')['memberships']!
              as Map<String, Object?>;
      final statuses = {
        for (final doc in memberships.values)
          (doc! as Map<String, Object?>)['status']! as String,
      };

      expect(statuses, isNotEmpty);
      expect(_statusCodes.values, containsAll(statuses));
    });

    test('rol ve durum kodları ayrı kümelerdir', () {
      expect(
        _roleCodes.values.toSet().intersection(_statusCodes.values.toSet()),
        isEmpty,
      );
    });
  });

  test('T-08 · role_codes.dart yalnızca iki sabit sınıfı bildirir', () {
    final declarations = RegExp(
      '^(?:abstract |final |sealed |base |interface )*'
      r'(?:class|mixin|enum|extension)\b.*$',
      multiLine: true,
    ).allMatches(readRepoFile(_sourcePath)).map((m) => m.group(0)).toList();

    expect(declarations, [
      'abstract final class RoleCodes {',
      'abstract final class MembershipStatusCodes {',
    ]);
  });
}

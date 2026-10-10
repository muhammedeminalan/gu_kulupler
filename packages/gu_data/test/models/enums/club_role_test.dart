// T-08 · ClubRole: değerler, RoleCodes eşlemesi, fromJson gidiş-dönüşü ve
// bilinmeyen değer davranışı (PLAN §9.7).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../../helpers/repo_sources.dart';

void main() {
  group('T-08 · ClubRole · değerler', () {
    test('dört rol, bildirim sırası member → board → president → advisor', () {
      expect(ClubRole.values, [
        ClubRole.member,
        ClubRole.board,
        ClubRole.president,
        ClubRole.advisor,
      ]);
    });

    test('json değerleri RoleCodes sabitleridir', () {
      expect(ClubRole.member.json, RoleCodes.member);
      expect(ClubRole.board.json, RoleCodes.board);
      expect(ClubRole.president.json, RoleCodes.president);
      expect(ClubRole.advisor.json, RoleCodes.advisor);
    });

    test('json değerleri şemadaki dizgilerle birebir', () {
      expect(
        [for (final role in ClubRole.values) role.json],
        ['member', 'board', 'president', 'advisor'],
      );
    });

    test(
      'Dart adı = JSON değeri (json_serializable enum haritası ile aynı)',
      () {
        for (final role in ClubRole.values) {
          expect(role.json, role.name);
        }
      },
    );

    test('json değerleri tekildir', () {
      expect(
        {for (final role in ClubRole.values) role.json},
        hasLength(ClubRole.values.length),
      );
    });
  });

  group('T-08 · ClubRole · fromJson', () {
    test('values → json → fromJson gidiş-dönüşü', () {
      expect(
        ClubRole.values.map((role) => ClubRole.fromJson(role.json)),
        ClubRole.values,
      );
    });

    test('bilinmeyen değer ArgumentError fırlatır', () {
      for (final unknown in ['student', 'manager', 'owner', 'unknown', '']) {
        expect(
          () => ClubRole.fromJson(unknown),
          throwsArgumentError,
          reason: '"$unknown"',
        );
      }
    });

    test('superadmin kulüp rolü değildir', () {
      expect(
        () => ClubRole.fromJson(RoleCodes.superadmin),
        throwsArgumentError,
      );
    });

    test('eşleşme büyük/küçük harf ve boşluk duyarlıdır', () {
      for (final near in [
        'Member',
        'MEMBER',
        ' member',
        'member ',
        'board\n',
      ]) {
        expect(
          () => ClubRole.fromJson(near),
          throwsArgumentError,
          reason: '"$near"',
        );
      }
    });

    test('hata, geçersiz değeri ve parametre adını taşır', () {
      expect(
        () => ClubRole.fromJson('student'),
        throwsA(
          isA<ArgumentError>()
              .having((e) => e.invalidValue, 'invalidValue', 'student')
              .having((e) => e.name, 'name', 'json')
              .having((e) => '${e.message}', 'message', contains('ClubRole')),
        ),
      );
    });

    test('üyelik durum kodları rol olarak kabul edilmez', () {
      for (final status in [
        MembershipStatusCodes.pending,
        MembershipStatusCodes.active,
        MembershipStatusCodes.rejected,
        MembershipStatusCodes.removed,
        MembershipStatusCodes.left,
        MembershipStatusCodes.cancelled,
      ]) {
        expect(() => ClubRole.fromJson(status), throwsArgumentError);
      }
    });
  });

  group('T-08 · ClubRole · kaynak sözleşmesi', () {
    final source = readRepoFile(
      'packages/gu_data/lib/src/models/enums/club_role.dart',
    );

    test("@JsonEnum(valueField: 'json') ile işaretlidir (T-09 codegen)", () {
      expect(
        source,
        contains("@JsonEnum(valueField: 'json')\nenum ClubRole {"),
      );
    });

    test('değerler literal değil RoleCodes sabitleriyle bildirilir', () {
      for (final role in ClubRole.values) {
        expect(source, contains('${role.name}(RoleCodes.${role.name})'));
      }
      expect(source, isNot(contains(RegExp(r"\w+\('[^']*'\)[,;]"))));
    });
  });
}

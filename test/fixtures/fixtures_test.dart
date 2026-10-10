// T-09 · Kök fixture'lar (PLAN §16.2): sabit modeller demo veriden `fromJson`
// ile kurulur, birbirine tutarlı kimliklerle bağlanır; dönüşüm dosyası
// gu_data'daki asıl kopyayla birebir aynıdır.
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../helpers/design_files.dart';
import 'club_model_fixtures.dart';
import 'demo_data.dart';
import 'event_model_fixtures.dart';
import 'membership_model_fixtures.dart';
import 'post_model_fixtures.dart';
import 'user_model_fixtures.dart';

void main() {
  group('T-09 · kök fixture dosyaları', () {
    test('demo_data.dart, packages/gu_data/test/fixtures/demo_data.dart ile '
        'birebir aynıdır', () {
      expect(
        readText('test/fixtures/demo_data.dart'),
        readText('packages/gu_data/test/fixtures/demo_data.dart'),
      );
    });

    test('adlandırılmış sabit modeller demo verideki belgelerdir', () {
      final c01 = ClubModelFixtures.c01;
      final ayse = UserModelFixtures.ayse;
      final e01 = EventModelFixtures.e01;
      final p01 = PostModelFixtures.p01;
      final c01Mehmet = MembershipModelFixtures.c01Mehmet;
      final c04Ayse = MembershipModelFixtures.c04Ayse;

      expect((c01.id, c01.name), ('c01', 'Yazılım ve Yapay Zekâ Topluluğu'));
      expect((ayse.uid, ayse.name), ('u_ayse', 'Ayşe Demir'));
      expect(
        (e01.id, e01.clubId, e01.status),
        (
          'e01',
          c01.id,
          EventStatus.published,
        ),
      );
      expect(
        (p01.id, p01.clubId, p01.type),
        (
          'p01',
          c01.id,
          PostType.announcement,
        ),
      );
      expect(c01.pinnedPostId, p01.id);
      expect(
        (c01Mehmet.id, c01Mehmet.clubId, c01Mehmet.status),
        (
          'c01_u_mehmet',
          c01.id,
          MembershipStatus.active,
        ),
      );
      expect(
        (c04Ayse.id, c04Ayse.userId, c04Ayse.applicant.name),
        (
          'c04_u_ayse',
          ayse.uid,
          ayse.name,
        ),
      );
    });

    test('zamanlar UTC ve meta.today anına göre sabittir (FakeAppClock ile '
        'aynı an)', () {
      expect(DemoDataFixture.today, DateTime.utc(2026, 10, 7, 21));
      expect(EventModelFixtures.e01.startsAt, DateTime.utc(2026, 10, 9, 15));
      expect(EventModelFixtures.e01.startsAt.isUtc, isTrue);
    });

    test('byId demo verideki her belgeyi verir; bilinmeyen kimlik hata', () {
      expect(ClubModelFixtures.byId('c14').status, ClubStatus.suspended);
      expect(UserModelFixtures.byId('u_admin').staff, isTrue);
      expect(EventModelFixtures.byId('e22').status, EventStatus.draft);
      expect(PostModelFixtures.byId('p04').isPoll, isTrue);
      expect(
        MembershipModelFixtures.byId('c01_u_p_c01').role,
        ClubRole.president,
      );
      expect(() => ClubModelFixtures.byId('yok'), throwsArgumentError);
    });
  });
}

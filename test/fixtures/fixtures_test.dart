// T-09 · Kök fixture'lar (PLAN §16.2): sabit modeller demo veriden `fromJson`
// ile kurulur, birbirine tutarlı kimliklerle bağlanır; dönüşüm dosyası
// gu_data'daki asıl kopyayla birebir aynıdır.
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../helpers/design_files.dart';
import 'club_model_fixtures.dart';
import 'comment_model_fixtures.dart';
import 'demo_data.dart';
import 'event_model_fixtures.dart';
import 'membership_model_fixtures.dart';
import 'post_model_fixtures.dart';
import 'rsvp_model_fixtures.dart';
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

    test('T-19 · gönderi ve yorum fixture’ları birbirine bağlıdır: sayaç = '
        'yorum sayısı, akış en yeni üstte, yorumlar eskiden yeniye', () {
      final p01 = PostModelFixtures.p01;
      final comments = CommentModelFixtures.ofPost(p01.id);

      expect(comments.map((comment) => comment.id), ['cm03', 'cm02', 'cm01']);
      expect(p01.commentCount, comments.length);
      expect(comments.every((comment) => comment.clubId == p01.clubId), isTrue);
      expect(CommentModelFixtures.cm01, comments.last);
      expect(PostModelFixtures.p02.images, hasLength(2));
      expect(
        PostModelFixtures.p04.poll!.options.map((option) => option.id),
        ['o1', 'o2', 'o3', 'o4'],
      );
      final feed = PostModelFixtures.ofClub(p01.clubId);
      expect(feed.map((post) => post.id), containsAll(['p01', 'p02', 'p04']));
      expect(feed.every((post) => post.likeCount == post.likes.length), isTrue);
      for (var i = 1; i < feed.length; i++) {
        expect(feed[i - 1].createdAt!.isBefore(feed[i].createdAt!), isFalse);
      }
      expect(() => CommentModelFixtures.byId('yok'), throwsArgumentError);
    });

    test('T-22 · etkinlik ve katılım fixture’ları birbirine bağlıdır: '
        'sayaçlar = kayıt sayıları, kontenjan aşılmaz, bekleme listesi '
        'waitlistAt sırasıyla, kayıt yolu etkinlikte tutulmaz (W-64)', () {
      for (final event in EventModelFixtures.all()) {
        final rsvps = RsvpModelFixtures.ofEvent(event.id);
        int count(Set<RsvpStatus> statuses) =>
            rsvps.where((rsvp) => statuses.contains(rsvp.status)).length;
        expect(
          (event.goingCount, event.waitlistCount, event.attendedCount),
          (
            count({RsvpStatus.going, RsvpStatus.attended}),
            count({RsvpStatus.waitlist}),
            count({RsvpStatus.attended}),
          ),
          reason: event.id,
        );
        expect(
          event.goingCount,
          lessThanOrEqualTo(event.capacity ?? event.goingCount),
          reason: event.id,
        );
        expect(
          rsvps.every((rsvp) => rsvp.clubId == event.clubId),
          isTrue,
          reason: event.id,
        );
        expect(event.toJson(), isNot(contains('lastRsvpRef')));
      }

      final e03 = EventModelFixtures.e03;
      expect((e03.isFull, e03.waitlistCount), (true, 4));
      final waitlist = RsvpModelFixtures.ofEvent(
        e03.id,
      ).where((rsvp) => rsvp.status == RsvpStatus.waitlist).toList();
      expect(waitlist, hasLength(4));
      for (var i = 1; i < waitlist.length; i++) {
        expect(
          waitlist[i - 1].waitlistAt!.isBefore(waitlist[i].waitlistAt!),
          isTrue,
        );
      }
      expect(EventModelFixtures.e02.visibility, EventVisibility.membersOnly);
      expect(EventModelFixtures.e21.status, EventStatus.cancelled);
      expect(EventModelFixtures.e21.cancelReason, isNotEmpty);
      expect(
        (EventModelFixtures.e22.status, EventModelFixtures.e22.publishedAt),
        (EventStatus.draft, null),
      );
      expect(EventModelFixtures.e19.attendedCount, 34);
      expect(
        EventModelFixtures.ofClub('c01').map((event) => event.clubId).toSet(),
        {'c01'},
      );

      expect(
        RsvpModelFixtures.ofUser('u_mehmet').map((rsvp) => rsvp.id),
        unorderedEquals([
          'e01_u_mehmet',
          'e08_u_mehmet',
          'e18_u_mehmet',
          'e20_u_mehmet',
        ]),
      );
      expect(RsvpModelFixtures.e01Mehmet.status, RsvpStatus.going);
      // Prototipte anı olmayan bekleyen kayıt oluşturulduğu anda girmiş
      // sayılır (seed dönüşümü).
      expect(
        RsvpModelFixtures.e08Mehmet.waitlistAt,
        RsvpModelFixtures.e08Mehmet.createdAt,
      );
      expect(RsvpModelFixtures.e18Mehmet.status, RsvpStatus.attended);
      expect(RsvpModelFixtures.e18Mehmet.scannedBy, isNotNull);
      expect(
        RsvpModelFixtures.e01Mehmet.ticketCode,
        matches(FirestoreIds.ticketCodePattern),
      );
      expect(() => RsvpModelFixtures.byId('yok'), throwsArgumentError);
    });
  });
}

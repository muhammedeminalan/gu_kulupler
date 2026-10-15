// T-37 · FakeAdminRepository sözleşmesi (PLAN §16.3): kompozisyon (kayıtlı
// kulüp / kullanıcı / üyelik / gönderi / yorum fake'leri), gerçek
// `FirebaseAdminRepository` ile aynı sonuçlar — CD-63 ad benzersizliği,
// başkan ataması (yeni hedef: `memberCount +1`; etkin üye: M11), danışman
// bağlama (M13), askı (gerekçe yalnızca hesap belgesinde — CD-133), şikayet
// grubu çözümü (gizleme + tekil şikayetçiler), e-posta araması ve oturumsuz
// aktör.
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';

import '../fixtures/post_model_fixtures.dart';
import '../helpers/fake_app_clock.dart';
import 'fake_admin_repository.dart';
import 'fake_announcement_counter_repository.dart';
import 'fake_auth_service.dart';
import 'fake_club_repository.dart';
import 'fake_comment_repository.dart';
import 'fake_membership_repository.dart';
import 'fake_post_repository.dart';
import 'fake_user_repository.dart';
import 'register_fakes.dart';

const String _super = 'u_super';
const String _clubId = 'c01';
final DateTime _now = DateTime.utc(2026, 10, 15, 9);

const ClubCreateInput _input = ClubCreateInput(
  name: 'Fotoğraf Kulübü',
  nameLower: 'fotoğraf kulübü',
  categoryId: 'k02',
  iconName: 'camera',
  founded: 2020,
  palette: ClubPalette.slate,
  pattern: ClubPattern.waves,
);

void main() {
  late FakeAuthService auth;
  late FakeClubRepository clubs;
  late FakeUserRepository users;
  late FakeMembershipRepository memberships;
  late FakePostRepository posts;
  late FakeAdminRepository fake;

  MembershipModel membership(String uid, ClubRole role) => MembershipModel(
    clubId: _clubId,
    userId: uid,
    applicant: MembershipApplicantModel(name: 'Üye $uid', avatarSeed: uid),
    status: MembershipStatus.active,
    role: role,
  );

  setUp(() {
    final clock = FakeAppClock(_now);
    auth = FakeAuthService()
      ..currentUser = const AuthUserInfo(
        uid: _super,
        email: 'super@gumushane.edu.tr',
        emailVerified: true,
      );
    clubs = FakeClubRepository()..put(_clubId, memberCount: 2);
    users = FakeUserRepository()
      ..putActive('u_president')
      ..putActive('u_member')
      ..putActive(
        'u_ayse',
        name: 'Ayşe Işık',
        email: 'ayse@ogr.gumushane.edu.tr',
      );
    memberships = FakeMembershipRepository(clock, clubs: clubs)
      ..put(membership('u_president', ClubRole.president))
      ..put(membership('u_member', ClubRole.member));
    posts = FakePostRepository(
      clock,
      counters: FakeAnnouncementCounterRepository(clock),
    )..put(PostModelFixtures.p01);
    fake = FakeAdminRepository(
      clock,
      auth: auth,
      clubs: clubs,
      users: users,
      memberships: memberships,
      posts: posts,
      comments: FakeCommentRepository(clock, posts: posts),
    );
  });

  test('AdminRepository arayüzünü uygular; registerDefaultFakes kaydeder', () {
    addTearDown(GetIt.I.reset);
    registerDefaultFakes();

    expect(GetIt.I<AdminRepository>(), isA<FakeAdminRepository>());
  });

  test('createClub: başkan üyeliği + memberCount 1 + aktör; aynı ad '
      'alreadyExists; oturum yoksa unauthenticated', () async {
    final created = await fake.createClub(
      _input,
      presidentUserId: 'u_ayse',
      presidentUser: users.users['u_ayse']!,
      presidentEmail: 'ayse@ogr.gumushane.edu.tr',
    );

    final club = created.dataOrNull!;
    expect(club.memberCount, 1);
    expect(club.createdBy, _super);
    expect(
      memberships.memberships['${club.id}_u_ayse'],
      isA<MembershipModel>()
          .having((m) => m.role, 'role', ClubRole.president)
          .having((m) => m.decidedBy, 'decidedBy', _super),
    );
    expect(
      (await fake.createClub(
        _input,
        presidentUserId: 'u_ayse',
        presidentUser: users.users['u_ayse']!,
        presidentEmail: 'ayse@ogr.gumushane.edu.tr',
      )).errorOrNull,
      FirestoreError.alreadyExists,
    );
    auth.currentUser = null;
    expect(
      (await fake.resolveReports(
        reportIds: const ['x'],
        action: ReportAction.dismissed,
        actorId: _super,
      )).errorOrNull,
      FirestoreError.unauthenticated,
    );
  });

  test('assignPresident: üyeliği olmayan hedef → başkan, eski başkan board, '
      'memberCount +1; etkin üye → M11 (sayaç aynı)', () async {
    await fake.assignPresident(
      clubId: _clubId,
      toUserId: 'u_ayse',
      actorId: _super,
    );
    expect(clubs.clubs[_clubId]!.presidentId, 'u_ayse');
    expect(clubs.clubs[_clubId]!.memberCount, 3);
    expect(
      memberships.memberships['c01_u_president']!.role,
      ClubRole.board,
    );
    expect(
      memberships.memberships['c01_u_ayse']!.applicant.name,
      'Ayşe Işık',
    );

    await fake.assignPresident(
      clubId: _clubId,
      toUserId: 'u_member',
      actorId: _super,
    );
    expect(clubs.clubs[_clubId]!.presidentId, 'u_member');
    expect(clubs.clubs[_clubId]!.memberCount, 3);
  });

  test('setAdvisor: kayıt yoksa failedPrecondition; bağla / kaldır '
      'advisor.userId ve üyelik durumunu işler, sayaç değişmez', () async {
    expect(
      (await fake.setAdvisor(
        clubId: _clubId,
        userId: 'u_ayse',
        active: true,
      )).errorOrNull,
      FirestoreError.failedPrecondition,
    );
    await fake.updateClubIdentity(
      _clubId,
      const ClubIdentityPatch(advisor: AdvisorInput(name: 'Dr. Ayşe')),
    );

    await fake.setAdvisor(clubId: _clubId, userId: 'u_ayse', active: true);
    expect(clubs.clubs[_clubId]!.advisor!.userId, 'u_ayse');
    expect(memberships.memberships['c01_u_ayse']!.role, ClubRole.advisor);
    expect(
      (await fake.updateClubIdentity(
        _clubId,
        const ClubIdentityPatch(clearAdvisor: true),
      )).errorOrNull,
      FirestoreError.failedPrecondition,
    );

    await fake.setAdvisor(clubId: _clubId, userId: 'u_ayse', active: false);
    expect(clubs.clubs[_clubId]!.advisor!.userId, isNull);
    expect(
      memberships.memberships['c01_u_ayse']!.status,
      MembershipStatus.left,
    );
    expect(clubs.clubs[_clubId]!.memberCount, 2);
  });

  test('suspendUser: users.status + hesap gerekçesi; activateUser ikisini '
      'geri alır; silinmiş hesap conflict', () async {
    await fake.suspendUser('u_member', reason: 'Kural ihlali.');
    expect(users.users['u_member']!.status, UserStatus.suspended);
    expect(users.accounts['u_member']!.suspendReason, 'Kural ihlali.');

    await fake.activateUser('u_member');
    expect(users.users['u_member']!.status, UserStatus.active);
    expect(users.accounts['u_member']!.suspendReason, isNull);

    users.users['u_member'] = users.users['u_member']!.copyWith(
      status: UserStatus.deleted,
    );
    expect(
      (await fake.suspendUser('u_member', reason: 'Kural ihlali.')).errorOrNull,
      FirestoreError.conflict,
    );
  });

  test('resolveReports(removed): hedefin açık şikayetleri çözülür, gönderi '
      'gizlenir, şikayetçiler tekil; tekrar → conflict', () async {
    for (final reporter in ['u_member', 'u_ayse']) {
      fake.putReport(
        reporterId: reporter,
        type: ReportTargetType.post,
        targetId: 'p01',
        targetClubId: _clubId,
      );
    }

    final result = await fake.resolveReports(
      reportIds: const ['u_member_post_p01'],
      action: ReportAction.removed,
      actorId: _super,
      target: (type: ReportTargetType.post, id: 'p01', clubId: _clubId),
    );

    expect(result.isSuccess, isTrue);
    expect(posts.posts['p01']!.isHidden, isTrue);
    final resolution = fake.resolutions.single;
    expect(resolution.groupKey, 'post_p01');
    expect(resolution.reporterIds, unorderedEquals(['u_member', 'u_ayse']));
    expect(resolution.hidden, isTrue);
    expect(
      fake.reports.values.map((r) => r.status),
      everyElement(ReportStatus.resolved),
    );
    expect(
      (await fake.resolveReports(
        reportIds: const ['u_member_post_p01'],
        action: ReportAction.removed,
        actorId: _super,
      )).errorOrNull,
      FirestoreError.conflict,
    );
  });

  test('findUserByEmail önek araması; boş girdi sorgusuz boş; '
      'listManagerUserIds etkin board / president', () async {
    expect(
      (await fake.findUserByEmail('ayse@')).dataOrNull!.map((u) => u.uid),
      ['u_ayse'],
    );
    expect((await fake.findUserByEmail('')).dataOrNull, isEmpty);
    expect((await fake.listManagerUserIds()).dataOrNull, {'u_president'});
  });

  test(
    'failNext bir sonraki çağrıyı düşürür (permissionDenied — claim yok)',
    () async {
      fake.failNext(FirestoreError.permissionDenied);

      expect(
        (await fake.stats()).errorOrNull,
        FirestoreError.permissionDenied,
      );
      expect((await fake.stats()).isSuccess, isTrue);
    },
  );
}

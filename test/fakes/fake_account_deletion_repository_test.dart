// T-29 · FakeAccountDeletionRepository sözleşmesi (PLAN §16.3; sözleşme
// `docs/plans/T-29.md` §4): ön denetim, adım 1 (anonim profil), plan,
// parçalı temizlik, yarıda kesilip yeniden başlatma.
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';

import '../helpers/fake_app_clock.dart';
import 'fake_account_deletion_repository.dart';
import 'fake_club_repository.dart';
import 'fake_membership_repository.dart';
import 'fake_user_repository.dart';
import 'register_fakes.dart';

const String _me = 'u_ayse';

MembershipModel _membership(
  String clubId, {
  MembershipStatus status = MembershipStatus.active,
  ClubRole role = ClubRole.member,
}) => MembershipModel(
  clubId: clubId,
  userId: _me,
  applicant: const MembershipApplicantModel(
    name: 'Ayşe Işık',
    avatarSeed: 'seed-ayse',
  ),
  status: status,
  role: role,
);

void main() {
  late FakeUserRepository users;
  late FakeClubRepository clubs;
  late FakeMembershipRepository memberships;
  late FakeAccountDeletionRepository fake;

  setUp(() {
    final clock = FakeAppClock(kDefaultFakeNowUtc);
    users = FakeUserRepository()..putActive(_me);
    clubs = FakeClubRepository();
    memberships = FakeMembershipRepository(clock, clubs: clubs);
    fake = FakeAccountDeletionRepository(
      clock,
      users: users,
      memberships: memberships,
    );
  });

  group('T-29 · FakeAccountDeletionRepository', () {
    test('AccountDeletionRepository arayüzünü uygular; registerDefaultFakes '
        'kayıtlı kullanıcı / üyelik fake’leriyle kaydeder', () {
      addTearDown(GetIt.I.reset);
      registerDefaultFakes();
      final registered =
          GetIt.I<AccountDeletionRepository>() as FakeAccountDeletionRepository;
      expect(registered.userRepository, same(GetIt.I<UserRepository>()));
      expect(
        registered.membershipRepository,
        same(GetIt.I<MembershipRepository>()),
      );
    });

    test('precheck: etkin başkanlık → blockedByPresidency (sıralı); yoksa '
        'ready', () async {
      memberships
        ..put(_membership('c03', role: ClubRole.president))
        ..put(_membership('c01', role: ClubRole.president))
        ..put(
          _membership(
            'c02',
            role: ClubRole.president,
            status: MembershipStatus.left,
          ),
        );
      expect(
        (await fake.precheck(_me)).dataOrNull,
        const DeletionPrecheck.blockedByPresidency(['c01', 'c03']),
      );
      expect(
        (await fake.precheck('u_other')).dataOrNull,
        const DeletionPrecheck.ready(),
      );
    });

    test('markDeleted: profil anonim + deleted, e-posta boş; ikinci çağrı '
        'yazmaz; askıdaki hesap failedPrecondition', () async {
      final before = users.users[_me]!;

      expect((await fake.markDeleted(_me)).isSuccess, isTrue);
      final user = users.users[_me]!;
      expect(user.name, Anonymization.deletedUserName);
      expect(user.status, UserStatus.deleted);
      expect(user.isDeleted, isTrue);
      expect(user.deletedBy, _me);
      expect(user.department, isNull);
      expect(user.avatarSeed, before.avatarSeed);
      expect(users.accounts[_me]!.email, isEmpty);

      expect((await fake.markDeleted(_me)).isSuccess, isTrue);
      expect(users.users[_me], user);

      users.putActive('u_susp');
      users.users['u_susp'] = users.users['u_susp']!.copyWith(
        status: UserStatus.suspended,
      );
      expect(
        (await fake.markDeleted('u_susp')).errorOrNull,
        FirestoreError.failedPrecondition,
      );
    });

    test('resumeCleanup: silinmemiş hesapta failedPrecondition; düşen parça '
        'diziyi durdurmaz (ilk hata sonda), kalan iş sonraki çağrıda biter; '
        'okunamayan katılım kaydı vazgeçilir', () async {
      expect(
        (await fake.resumeCleanup(_me)).errorOrNull,
        FirestoreError.failedPrecondition,
      );
      for (final clubId in ['c01', 'c02', 'c03', 'c04', 'c05', 'c06']) {
        clubs.put(clubId, memberCount: 2);
        memberships.put(_membership(clubId));
      }
      fake.personalRefs.add(
        const PersonalDocRef(PersonalDocKind.savedPost, '${_me}_p01'),
      );
      const unreadable = RsvpModel(
        eventId: 'e09',
        clubId: 'c09',
        userId: _me,
        ticketCode: 'GU-ABCD-EFGH',
      );
      fake.unreadableRsvps.add(unreadable);
      await fake.markDeleted(_me);
      fake.failCleanupAfter(2);
      final progress = <DeleteProgress>[];

      expect(
        (await fake.resumeCleanup(_me, onProgress: progress.add)).errorOrNull,
        FirestoreError.unavailable,
      );
      expect(progress, const [
        DeleteProgress(done: 1, total: 4),
        DeleteProgress(done: 2, total: 4),
        DeleteProgress(done: 3, total: 4),
      ]);
      expect(fake.cancelledRsvps.single.eventId, 'e09');
      expect(clubs.clubs['c01']!.memberCount, 1);
      expect(clubs.clubs['c06']!.memberCount, 2);
      expect(fake.softDeleted, hasLength(1));

      progress.clear();
      expect(
        (await fake.resumeCleanup(_me, onProgress: progress.add)).isSuccess,
        isTrue,
      );
      expect(progress, const [DeleteProgress(done: 1, total: 1)]);
      expect(clubs.clubs['c06']!.memberCount, 1);
      expect((await fake.buildPlan(_me)).dataOrNull!.isEmpty, isTrue);
    });
  });
}

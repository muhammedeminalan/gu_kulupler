// T-30 · FakeManagementRepository sözleşmesi (PLAN §16.3): kompozisyon
// (kayıtlı üyelik / etkinlik / gönderi / yorum fake'lerine devir), toplu
// karar (`BulkResult`), kulüp ayarı yaması (`settingsUpdates`), kesinleşen
// yazımın fan-out'u (`fanOuts`), danışman salt okunur.
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';

import '../helpers/fake_app_clock.dart';
import 'fake_announcement_counter_repository.dart';
import 'fake_club_repository.dart';
import 'fake_comment_repository.dart';
import 'fake_event_repository.dart';
import 'fake_management_repository.dart';
import 'fake_membership_repository.dart';
import 'fake_post_repository.dart';
import 'register_fakes.dart';

const String _clubId = 'c01';
const String _manager = 'u_board';
final DateTime _now = DateTime.utc(2026, 10, 13, 9);

MembershipModel _pending(String uid) => MembershipModel(
  clubId: _clubId,
  userId: uid,
  applicant: MembershipApplicantModel(name: 'Aday $uid', avatarSeed: uid),
  appliedAt: _now.subtract(const Duration(days: 1)),
);

void main() {
  late FakeClubRepository clubs;
  late FakeMembershipRepository memberships;
  late FakeEventRepository events;
  late FakeManagementRepository fake;

  setUp(() {
    final clock = FakeAppClock(_now);
    clubs = FakeClubRepository()..put(_clubId, memberCount: 3);
    memberships = FakeMembershipRepository(clock, clubs: clubs);
    events = FakeEventRepository(clock);
    final posts = FakePostRepository(
      clock,
      counters: FakeAnnouncementCounterRepository(clock),
    );
    fake = FakeManagementRepository(
      memberships: memberships,
      events: events,
      posts: posts,
      comments: FakeCommentRepository(clock, posts: posts),
      clubs: clubs,
    );
  });

  test('ManagementRepository arayüzünü uygular; registerDefaultFakes kayıtlı '
      "üyelik ve kulüp fake'leriyle paylaştırarak kaydeder", () {
    addTearDown(GetIt.I.reset);
    registerDefaultFakes();

    final registered = GetIt.I<ManagementRepository>();
    expect(registered, isA<FakeManagementRepository>());
    expect(
      (registered as FakeManagementRepository).memberships,
      same(GetIt.I<MembershipRepository>()),
    );
    expect(registered.clubs, same(GetIt.I<ClubRepository>()));
  });

  test('toplu onay: her başvuru ayrı karar, tekilleştirilir; çakışan '
      'conflicted, sayaç başarılı onay kadar artar', () async {
    memberships
      ..put(_pending('u1'))
      ..put(_pending('u2'))
      ..put(_pending('u3').copyWith(status: MembershipStatus.active));

    final result = await fake.approveMany(
      clubId: _clubId,
      userIds: const ['u1', 'u2', 'u1', 'u3'],
      actorId: _manager,
    );

    expect(
      result.dataOrNull,
      const BulkResult(
        succeeded: ['u1', 'u2'],
        conflicted: ['u3'],
      ),
    );
    expect(clubs.clubs[_clubId]?.memberCount, 5);
    expect(memberships.callsTo('approve'), hasLength(3));
  });

  test('kulüp ayarı: yamanın alanları kulübe yazılır; boş / sınır dışı yama '
      'invalidArgument, olmayan kulüp notFound', () async {
    const patch = ClubSettingsPatch(
      summary: 'Yeni özet',
      applicationsOpen: false,
    );

    final updated = await fake.updateClubSettings(
      _clubId,
      patch,
      actorId: _manager,
    );
    final empty = await fake.updateClubSettings(
      _clubId,
      const ClubSettingsPatch(),
      actorId: _manager,
    );
    final multiline = await fake.updateClubSettings(
      _clubId,
      const ClubSettingsPatch(conditions: ['iki\nsatır']),
      actorId: _manager,
    );
    final missing = await fake.updateClubSettings(
      'c99',
      patch,
      actorId: _manager,
    );

    expect(updated.isSuccess, isTrue);
    expect(clubs.clubs[_clubId]?.summary, 'Yeni özet');
    expect(clubs.clubs[_clubId]?.applicationsOpen, isFalse);
    expect(fake.settingsUpdates.single.patch, patch);
    expect(empty.errorOrNull, FirestoreError.invalidArgument);
    expect(multiline.errorOrNull, FirestoreError.invalidArgument);
    expect(missing.errorOrNull, FirestoreError.notFound);
  });

  test('fan-out yalnızca kesinleşen yazımdan sonra: başarısız yayın '
      'dağıtım istemez; danışman salt okunur', () async {
    final failed = await fake.publishEvent(
      'e_yok',
      clubId: _clubId,
      actorId: _manager,
      notifyMembers: true,
    );

    expect(failed.isSuccess, isFalse);
    expect(fake.fanOuts, isEmpty);
    expect(fake.isReadOnly(ClubAccess.advisor), isTrue);
    expect(fake.isReadOnly(ClubAccess.manager), isFalse);
  });

  test('failNext bir sonraki çağrıyı devretmeden düşürür', () async {
    memberships.put(_pending('u1'));
    fake.failNext(FirestoreError.permissionDenied);

    final denied = await fake.approveApplication(
      clubId: _clubId,
      userId: 'u1',
      actorId: _manager,
    );

    expect(denied.errorOrNull, FirestoreError.permissionDenied);
    expect(memberships.callsTo('approve'), isEmpty);
    expect(clubs.clubs[_clubId]?.memberCount, 3);
  });
}

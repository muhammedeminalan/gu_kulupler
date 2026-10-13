// T-15 · FakeMembershipRepository sözleşmesi (PLAN §16.3): `memberships`,
// `contacts`, `applied`, `watchMyMembershipsController(uid)`,
// `activeListeners`; listeler ve sayfalama. T-16: `noteUpdates`
// (`updateApplicationNote`).
//
// Fake durum makinesini (M1–M4, M7, M8) kendi içinde uygular; kuralların
// gerçek `FirebaseMembershipRepository` ile **aynı** olduğu karşılaştırmalı
// sınanır: her önceki durum × kulüp biçimi × çağrı için iki taraf aynı
// sonucu (hata, kural kodu, bekleme anı) ve aynı son durumu (üyelik, not,
// `memberCount`) üretmelidir.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';

import '../helpers/fake_app_clock.dart';
import 'fake_club_repository.dart';
import 'fake_membership_repository.dart';
import 'fake_notification_dispatcher.dart';
import 'register_fakes.dart';

const String _clubId = 'c01';
const String _uid = 'u_ayse';
const String _email = 'ayse@ogr.gumushane.edu.tr';
const int _memberCount = 7;

final DateTime _now = DateTime.utc(2026, 10, 13, 9);

const UserModel _applicant = UserModel(
  uid: _uid,
  name: 'Ayşe Işık',
  nameLower: 'ayşe ışık',
  avatarSeed: 'seed-ayse',
  department: 'd02',
  year: YearLevel.second,
  interests: ['i01'],
  profileComplete: true,
);

MembershipModel _membership({
  String clubId = _clubId,
  String uid = _uid,
  MembershipStatus status = MembershipStatus.active,
  ClubRole role = ClubRole.member,
  DateTime? retryAfter,
  DateTime? appliedAt,
}) => MembershipModel(
  clubId: clubId,
  userId: uid,
  applicant: MembershipApplicantModel(name: 'Üye $uid', avatarSeed: uid),
  status: status,
  role: role,
  retryAfter: retryAfter,
  appliedAt: appliedAt ?? _now.subtract(const Duration(days: 30)),
  createdAt: _now.subtract(const Duration(days: 30)),
);

/// Karşılaştırmalı testin önceki durumu: ad → üyelik (yoksa `null`).
final Map<String, MembershipModel?> _priors = {
  'yok': null,
  'pending': _membership(status: MembershipStatus.pending),
  'active/member': _membership(),
  'active/board': _membership(role: ClubRole.board),
  'active/president': _membership(role: ClubRole.president),
  'active/advisor': _membership(role: ClubRole.advisor),
  'left': _membership(status: MembershipStatus.left),
  'cancelled': _membership(status: MembershipStatus.cancelled),
  'rejected (bekleme yok)': _membership(status: MembershipStatus.rejected),
  'rejected (bekleme doldu)': _membership(
    status: MembershipStatus.rejected,
    retryAfter: _now.subtract(const Duration(days: 1)),
  ),
  'rejected (bekleme sürüyor)': _membership(
    status: MembershipStatus.rejected,
    retryAfter: _now.add(const Duration(days: 3)),
  ),
  'removed (bekleme sürüyor)': _membership(
    status: MembershipStatus.removed,
    retryAfter: _now.add(const Duration(days: 6)),
  ),
};

/// Karşılaştırmalı testin kulüp biçimleri: ad → kulübü kuran işlev (`null`
/// dönerse kulüp yok).
final Map<String, ClubModel? Function(FakeClubRepository clubs)> _clubs = {
  'onaylı': (clubs) => clubs.put(_clubId, memberCount: _memberCount),
  'onaylı + not zorunlu': (clubs) =>
      clubs.put(_clubId, memberCount: _memberCount, requireNote: true),
  'onaysız': (clubs) =>
      clubs.put(_clubId, memberCount: _memberCount, approvalRequired: false),
  'başvuruya kapalı': (clubs) =>
      clubs.put(_clubId, memberCount: _memberCount, applicationsOpen: false),
  'askıda': (clubs) => clubs.put(
    _clubId,
    memberCount: _memberCount,
    status: ClubStatus.suspended,
  ),
  'silinmiş': (clubs) =>
      clubs.put(_clubId, memberCount: _memberCount, isDeleted: true),
  'yok': (_) => null,
};

/// Karşılaştırmalı testin çağrıları.
final Map<
  String,
  Future<FirestoreResult<Object?>> Function(MembershipRepository)
>
_operations = {
  'apply (notsuz)': (repository) => repository.apply(
    clubId: _clubId,
    applicant: _applicant,
    email: _email,
    note: '',
  ),
  'apply (notlu)': (repository) => repository.apply(
    clubId: _clubId,
    applicant: _applicant,
    email: _email,
    note: 'Katılmak istiyorum.',
  ),
  'joinInstant': (repository) => repository.joinInstant(
    clubId: _clubId,
    applicant: _applicant,
    email: _email,
  ),
  'cancelApplication': (repository) =>
      repository.cancelApplication(clubId: _clubId, userId: _uid),
  'leave': (repository) => repository.leave(clubId: _clubId, userId: _uid),
  'updateApplicationNote (notlu)': (repository) => repository
      .updateApplicationNote(clubId: _clubId, userId: _uid, note: 'Güncel.'),
  'updateApplicationNote (boş)': (repository) =>
      repository.updateApplicationNote(clubId: _clubId, userId: _uid, note: ''),
  'updateApplicationNote (çok uzun)': (repository) =>
      repository.updateApplicationNote(
        clubId: _clubId,
        userId: _uid,
        note: 'a' * (Limits.applicationNoteMax + 1),
      ),
};

/// Bir çağrının gözlenen sonucu ve bıraktığı durum.
typedef _Outcome = ({
  FirestoreError? error,
  Object? detail,
  MembershipStatus? status,
  ClubRole? role,
  int? priorCount,
  String? note,
  int? memberCount,
});

Object? _detailOf(FirestoreResult<Object?> result) => switch (result) {
  FirebaseFailure(:final detail) => detail,
  FirebaseSuccess() => null,
};

void main() {
  late FakeClubRepository clubs;
  late FakeMembershipRepository fake;

  setUp(() {
    clubs = FakeClubRepository();
    fake = FakeMembershipRepository(FakeAppClock(_now), clubs: clubs);
  });

  group('T-15 · FakeMembershipRepository', () {
    test('MembershipRepository arayüzünü uygular; registerDefaultFakes '
        'kayıtlı FakeClubRepository ile paylaştırarak kaydeder', () {
      addTearDown(GetIt.I.reset);
      registerDefaultFakes();
      final registered = GetIt.I<MembershipRepository>();
      expect(registered, isA<FakeMembershipRepository>());
      expect(
        (registered as FakeMembershipRepository).clubRepository,
        same(GetIt.I<ClubRepository>()),
      );
    });

    test('apply: bekleyen üyelik + iletişim belgesi (e-posta, not) yazılır, '
        '`applied`e eklenir; sayaç değişmez', () async {
      clubs.put(_clubId, memberCount: _memberCount, requireNote: true);

      final result = await fake.apply(
        clubId: _clubId,
        applicant: _applicant,
        email: _email,
        note: 'Katılmak istiyorum.',
      );

      final membership = result.dataOrNull!;
      expect(membership.status, MembershipStatus.pending);
      expect(
        membership.applicant,
        MembershipApplicantModel.fromUser(_applicant),
      );
      expect(membership.appliedAt, _now);
      expect(fake.memberships['${_clubId}_$_uid'], membership);
      expect(fake.contacts['${_clubId}_$_uid']!.email, _email);
      expect(fake.contacts['${_clubId}_$_uid']!.note, 'Katılmak istiyorum.');
      expect(fake.applied.single, (
        clubId: _clubId,
        userId: _uid,
        email: _email,
        note: 'Katılmak istiyorum.',
        status: MembershipStatus.pending,
      ));
      expect(clubs.clubs[_clubId]!.memberCount, _memberCount);
      expect(
        (await fake.readContact(_clubId, _uid)).dataOrNull?.note,
        'Katılmak istiyorum.',
      );
      expect(
        (await fake.getMembership(_clubId, _uid)).dataOrNull,
        membership,
      );
    });

    test('joinInstant sayacı +1, leave −1 oynatır (kayıtlı kulüpte)', () async {
      clubs.put(_clubId, memberCount: _memberCount, approvalRequired: false);

      await fake.joinInstant(
        clubId: _clubId,
        applicant: _applicant,
        email: _email,
      );
      expect(clubs.clubs[_clubId]!.memberCount, _memberCount + 1);

      await fake.leave(clubId: _clubId, userId: _uid);
      expect(clubs.clubs[_clubId]!.memberCount, _memberCount);
      expect(
        fake.memberships['${_clubId}_$_uid']!.status,
        MembershipStatus.left,
      );
    });

    test('yeniden başvuru: priorCount artar, e-posta korunur, not '
        'değişir', () async {
      clubs.put(_clubId);
      fake.put(
        _membership(status: MembershipStatus.cancelled),
        email: 'eski@ogr.gumushane.edu.tr',
        note: 'Eski not',
      );

      final result = await fake.apply(
        clubId: _clubId,
        applicant: _applicant,
        email: _email,
        note: 'Yeni not',
      );

      expect(result.dataOrNull?.priorCount, 1);
      final contact = fake.contacts['${_clubId}_$_uid']!;
      expect(contact.email, 'eski@ogr.gumushane.edu.tr');
      expect(contact.note, 'Yeni not');
    });

    test('watchMyMemberships: ilk anlık görüntü + her değişiklikte yeni '
        'olay; yalnızca o kullanıcının üyelikleri', () async {
      clubs.put(_clubId, approvalRequired: false);
      fake.put(_membership(clubId: 'c02', uid: 'u_other'));
      final events = <List<String>>[];
      final subscription = fake
          .watchMyMemberships(_uid)
          .listen(
            (event) => events.add([
              for (final item in event.dataOrNull!)
                '${item.clubId}:${item.status.json}',
            ]),
          );
      await pumpEventQueue();
      expect(fake.activeListeners, 1);

      await fake.joinInstant(
        clubId: _clubId,
        applicant: _applicant,
        email: _email,
      );
      await fake.leave(clubId: _clubId, userId: _uid);
      fake.put(_membership(clubId: 'c03', uid: 'u_other'));
      await pumpEventQueue();

      expect(events, [
        <String>[],
        ['c01:active'],
        ['c01:left'],
      ]);
      await subscription.cancel();
      expect(fake.activeListeners, 0);
    });

    test('watchMyMembershipsController: test elle olay (hata dahil) '
        'yazar', () async {
      final events = <FirestoreResult<List<MembershipModel>>>[];
      final subscription = fake.watchMyMemberships(_uid).listen(events.add);
      await pumpEventQueue();

      fake
          .watchMyMembershipsController(_uid)
          .add(const FirebaseFailure(FirestoreError.permissionDenied));
      await pumpEventQueue();

      expect(events.last.errorOrNull, FirestoreError.permissionDenied);
      await subscription.cancel();
    });

    test('listeler: aktif üyeler en yeni üstte ve sayfalı; rol süzgeci; '
        'yöneticiler; bekleyenler; kendi üyeliklerim', () async {
      for (var i = 0; i < 5; i++) {
        fake.put(
          _membership(
            uid: 'u$i',
            role: i == 0
                ? ClubRole.president
                : (i == 1 ? ClubRole.board : ClubRole.member),
            appliedAt: _now.subtract(Duration(days: i)),
          ),
        );
      }
      fake
        ..put(_membership(uid: 'u_p', status: MembershipStatus.pending))
        ..put(_membership(clubId: 'c02', uid: 'u0'))
        ..put(
          _membership(clubId: 'c03', uid: 'u0', status: MembershipStatus.left),
        );

      final first = (await fake.listActiveMembers(
        _clubId,
        const PageRequest(limit: 3),
      )).dataOrNull!;
      final second = (await fake.listActiveMembers(
        _clubId,
        PageRequest(limit: 3, after: first.next),
      )).dataOrNull!;
      final board = (await fake.listActiveMembers(
        _clubId,
        const PageRequest(),
        role: ClubRole.board,
      )).dataOrNull!;
      final managers = (await fake.listManagers(_clubId)).dataOrNull!;
      final pending = (await fake.listPending(
        _clubId,
        const PageRequest(),
      )).dataOrNull!;
      final mine = (await fake.listMine('u0')).dataOrNull!;
      final mineActive = (await fake.listMine(
        'u0',
        statuses: {MembershipStatus.active},
      )).dataOrNull!;

      expect([for (final item in first.items) item.userId], ['u0', 'u1', 'u2']);
      expect([for (final item in second.items) item.userId], ['u3', 'u4']);
      expect(second.hasMore, isFalse);
      expect([for (final item in board.items) item.userId], ['u1']);
      expect({for (final item in managers) item.userId}, {'u0', 'u1'});
      expect([for (final item in pending.items) item.userId], ['u_p']);
      expect({for (final item in mine) item.clubId}, {_clubId, 'c02', 'c03'});
      expect({for (final item in mineActive) item.clubId}, {_clubId, 'c02'});
    });

    test('leave: kulüp belgesi yoksa notFound, üyelik değişmez', () async {
      fake.put(_membership());

      final result = await fake.leave(clubId: _clubId, userId: _uid);

      expect(result.errorOrNull, FirestoreError.notFound);
      expect(
        fake.memberships['${_clubId}_$_uid']!.status,
        MembershipStatus.active,
      );
    });

    test('updateApplicationNote: bekleyen başvurunun notu değişir, '
        '`noteUpdates`e düşer; üyelik ve akış değişmez; e-posta '
        'korunur', () async {
      clubs.put(_clubId, memberCount: _memberCount);
      fake.put(
        _membership(status: MembershipStatus.pending),
        email: _email,
        note: 'Eski not',
      );
      final events = <FakeMembershipEvent>[];
      final subscription = fake.watchMyMemberships(_uid).listen(events.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();
      final before = fake.memberships['${_clubId}_$_uid'];

      final result = await fake.updateApplicationNote(
        clubId: _clubId,
        userId: _uid,
        note: 'Güncel not.',
      );
      await pumpEventQueue();

      expect(result.isSuccess, isTrue);
      expect(fake.noteUpdates, [
        (clubId: _clubId, userId: _uid, note: 'Güncel not.'),
      ]);
      final contact = fake.contacts['${_clubId}_$_uid']!;
      expect(contact.note, 'Güncel not.');
      expect(contact.email, _email);
      expect(contact.updatedAt, _now);
      expect(fake.memberships['${_clubId}_$_uid'], same(before));
      // Yalnızca ilk anlık görüntü: not düzenleme üyelik akışını tetiklemez.
      expect(events, hasLength(1));
      expect(clubs.clubs[_clubId]!.memberCount, _memberCount);
    });

    test('updateApplicationNote: bekleyen değilse conflict, iletişim belgesi '
        'yoksa notFound, failNext düşürür; `noteUpdates` boş kalır', () async {
      clubs.put(_clubId);
      Future<FirestoreResult<void>> edit() => fake.updateApplicationNote(
        clubId: _clubId,
        userId: _uid,
        note: 'Güncel not.',
      );

      expect((await edit()).errorOrNull, FirestoreError.conflict);
      fake.put(_membership(), email: _email);
      expect((await edit()).errorOrNull, FirestoreError.conflict);

      fake
        ..put(_membership(status: MembershipStatus.pending))
        ..contacts.clear();
      expect((await edit()).errorOrNull, FirestoreError.notFound);

      fake
        ..put(_membership(status: MembershipStatus.pending), email: _email)
        ..failNext(FirestoreError.unavailable);
      expect((await edit()).errorOrNull, FirestoreError.unavailable);
      expect(fake.noteUpdates, isEmpty);
      expect(fake.contacts['${_clubId}_$_uid']!.note, '');
    });

    test('geçersiz kimlik invalidArgument; failNext sıradaki çağrıyı '
        'düşürür ve hiçbir şey yazılmaz', () async {
      clubs.put(_clubId);
      expect(
        (await fake.getMembership('c/1', _uid)).errorOrNull,
        FirestoreError.invalidArgument,
      );
      expect(
        (await fake.watchMyMemberships('').first).errorOrNull,
        FirestoreError.invalidArgument,
      );

      fake.failNext(FirestoreError.unavailable);
      final failed = await fake.apply(
        clubId: _clubId,
        applicant: _applicant,
        email: _email,
        note: '',
      );
      expect(failed.errorOrNull, FirestoreError.unavailable);
      expect(fake.memberships, isEmpty);
      expect(fake.applied, isEmpty);
    });
  });

  group('T-15 · FakeMembershipRepository ↔ FirebaseMembershipRepository', () {
    /// Gerçek repository'yi bellekteki veritabanında aynı ön koşulla koşar.
    Future<_Outcome> runReal(
      ClubModel? club,
      MembershipModel? prior,
      Future<FirestoreResult<Object?>> Function(MembershipRepository) operation,
    ) async {
      final db = FakeFirebaseFirestore();
      final service = FirebaseFirestoreService(db);
      final repository = FirebaseMembershipRepository(
        service,
        FirebaseActivityRepository(service),
        FakeNotificationDispatcher(),
        FakeAppClock(_now),
      );
      final membershipRef = db.doc('memberships/${_clubId}_$_uid');
      final contactRef = membershipRef.collection('private').doc('contact');
      // Gerçek repository anlık görüntüyü güncel kullanıcı belgesinden okur.
      await db.doc('users/$_uid').set(_applicant.toJson());
      if (club != null) await db.doc('clubs/$_clubId').set(club.toJson());
      if (prior != null) {
        await membershipRef.set(prior.toJson());
        await contactRef.set(
          const MembershipContactModel(
            email: _email,
            emailLower: _email,
            note: 'Eski not',
          ).toJson(),
        );
      }

      final result = await operation(repository);

      final membership = (await repository.getMembership(
        _clubId,
        _uid,
      )).dataOrNull;
      final contact = (await repository.readContact(_clubId, _uid)).dataOrNull;
      final clubData = (await db.doc('clubs/$_clubId').get()).data();
      return (
        error: result.errorOrNull,
        detail: _detailOf(result),
        status: membership?.status,
        role: membership?.role,
        priorCount: membership?.priorCount,
        note: contact?.note,
        memberCount: clubData?['memberCount'] as int?,
      );
    }

    /// Fake'i aynı ön koşulla koşar.
    Future<_Outcome> runFake(
      ClubModel? Function(FakeClubRepository) seedClub,
      MembershipModel? prior,
      Future<FirestoreResult<Object?>> Function(MembershipRepository) operation,
    ) async {
      final clubs = FakeClubRepository();
      final fake = FakeMembershipRepository(FakeAppClock(_now), clubs: clubs);
      seedClub(clubs);
      if (prior != null) fake.put(prior, email: _email, note: 'Eski not');

      final result = await operation(fake);

      const key = '${_clubId}_$_uid';
      return (
        error: result.errorOrNull,
        detail: _detailOf(result),
        status: fake.memberships[key]?.status,
        role: fake.memberships[key]?.role,
        priorCount: fake.memberships[key]?.priorCount,
        note: fake.contacts[key]?.note,
        memberCount: clubs.clubs[_clubId]?.memberCount,
      );
    }

    test('önceki durum × kulüp biçimi × çağrı: iki taraf aynı sonucu ve aynı '
        'son durumu üretir', () async {
      var successes = 0;
      final errors = <FirestoreError>{};
      for (final MapEntry(key: clubName, value: seedClub) in _clubs.entries) {
        for (final MapEntry(key: priorName, value: prior) in _priors.entries) {
          for (final MapEntry(key: name, value: operation)
              in _operations.entries) {
            final club = seedClub(FakeClubRepository());
            // Kulüp belgesi olmayan üyelikten ayrılma gerçek Firestore'da
            // işlemi `not-found` ile düşürür; bellekteki veritabanı bunu
            // sonuç yerine yakalanamayan hata olarak verir. Bu birleşim
            // yalnızca fake tarafında ayrıca sınanır (aşağıda).
            if (club == null && name == 'leave') continue;

            final real = await runReal(club, prior, operation);
            final fake = await runFake(seedClub, prior, operation);

            expect(
              fake,
              real,
              reason: '$name · kulüp $clubName · önce $priorName',
            );
            if (real.error case final error?) {
              errors.add(error);
            } else {
              successes++;
            }
          }
        }
      }
      // Tablo boş geçmesin: mutlu yollar ve her hata türü görülmüş olmalı.
      expect(successes, greaterThan(20));
      expect(
        errors,
        containsAll([
          FirestoreError.conflict,
          FirestoreError.ruleViolation,
          FirestoreError.notFound,
          FirestoreError.invalidArgument,
        ]),
      );
    });
  });
}

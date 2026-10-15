// T-29 · AccountDeletionRepository + MembershipRepository.anonymizeChunk
// (M14): hesap silme dizisi — ön denetim (başkan engeli), `markDeleted` (tek
// batch; TAM anonimleştirme alan listesi, dokunulmayan alanlar), plan (W-80:
// bitmemiş / geçmiş etkinlik kaydı ayrımı; başkan üyeliği; kişisel belgeler),
// katılım parçası (transaction, sayaç −1), üyelik parçası (M14 geçişleri,
// `memberCount` ±, iletişim belgesi, idempotentlik, kimlik birleşimi), parça
// sınırı, ilerleme, yarıda kesilip yeniden başlatma, geçersiz girdi ve hata
// eşlemesi (PLAN §10.4; domain-model §11; sözleşme docs/plans/T-29.md §4;
// Q-11, D-10, CD-137, CD-144, W-64, W-80).
//
// Mutlu yollar `fake_cloud_firestore` ile (Q-06; Rules çalışmaz — yetki
// emülatör testlerinde, `firebase/test/rules/account_deletion.test.js`);
// transaction yazımları kayıt tutan servis çiftiyle, kesinti test içi
// [_InterruptingService] ile, hata yolları el yazımı SDK çiftleriyle.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../fakes/fake_app_clock.dart';
import '../fakes/fake_notification_dispatcher.dart';
import '../fakes/fake_ticket_code_generator.dart';
import '../fakes/recording_firestore_service.dart';
import '../fakes/recording_storage_service.dart';
import '../fakes/sdk_firestore_stubs.dart';

const String _uid = 'u_ayse';
const String _other = 'u_can';
const String _userPath = 'users/u_ayse';
const String _accountPath = 'users/u_ayse/private/account';

/// Gerçek zaman geçirmeyen yeniden deneme (3 deneme, bekleme yok).
final RetryPolicy _instantRetry = RetryPolicy(wait: (_) async {});

/// Geçersiz belge kimlikleri (W-54).
const List<String> _invalidIds = ['', 'u/1', '..', '__id__'];

final DateTime _now = DateTime.utc(2026, 10, 14, 9);

/// Tohum belgelerin zaman damgası (sunucu zamanından ayırt edilir).
final DateTime _seededAt = DateTime.utc(2026, 10, 1, 8);
final Timestamp _seededTs = Timestamp.fromDate(_seededAt);

/// Bitmemiş etkinlik (W-80: kaydı vazgeçilir).
final DateTime _futureEnd = _now.add(const Duration(days: 6));

/// Bitmiş etkinlik (W-80: kaydı korunur).
final DateTime _pastEnd = _now.subtract(const Duration(days: 1));

/// Saat kayması payı içinde biten etkinlik (korunur: Rules sunucu saatiyle
/// reddedebilir).
final DateTime _skewEnd = _now.add(const Duration(minutes: 2));

const UserModel _profile = UserModel(
  uid: _uid,
  name: 'Ayşe Işık',
  nameLower: 'ayşe ışık',
  avatarSeed: 'seed-ayse',
  avatarPath: 'avatars/u_ayse/a1.jpg',
  department: 'd02',
  year: YearLevel.second,
  interests: ['i01', 'i02'],
  bio: 'Flutter sever',
  profileComplete: true,
);

const MembershipApplicantModel _applicant = MembershipApplicantModel(
  name: 'Ayşe Işık',
  avatarSeed: 'seed-ayse',
  department: 'd02',
  year: YearLevel.second,
);

/// `Anonymization.applicantPayload` — beklenen ham değer.
const Json _anonymousApplicant = {
  'name': 'Silinmiş kullanıcı',
  'department': null,
  'year': null,
  'avatarSeed': 'deleted',
};

/// İki belge hali arasında değeri değişen, eklenen ya da kalkan anahtarlar.
Set<String> _changedKeys(Json before, Json after) => {
  for (final key in {...before.keys, ...after.keys})
    if (!before.containsKey(key) ||
        !after.containsKey(key) ||
        !const DeepCollectionEquality().equals(before[key], after[key]))
      key,
};

void main() {
  late FakeFirebaseFirestore db;
  late RecordingFirestoreService service;
  late FakeAppClock clock;
  late AccountDeletionRepository repository;
  late MembershipRepository memberships;

  MembershipRepository membershipsOn(FirestoreService firestore) =>
      FirebaseMembershipRepository(
        firestore,
        FirebaseActivityRepository(firestore),
        FakeNotificationDispatcher(),
        clock,
      );

  AccountDeletionRepository repositoryOn(
    FirestoreService firestore, {
    MembershipRepository? memberships,
  }) => FirebaseAccountDeletionRepository(
    firestore,
    memberships ?? membershipsOn(firestore),
    FirebaseRsvpRepository(firestore, FakeTicketCodeGenerator(), clock),
    FirebaseEventRepository(
      firestore,
      RecordingStorageService(),
      FirebaseActivityRepository(firestore),
      clock,
      SequenceRandom(List<int>.generate(64, (i) => i)),
    ),
    clock,
    retry: _instantRetry,
  );

  /// Her çağrısı [code] hatasıyla biten veritabanına bağlı repository.
  AccountDeletionRepository failing(String code) => repositoryOn(
    FirebaseFirestoreService(StubFirestore(error: firestoreException(code))),
  );

  Future<Json?> read(String path) async => (await db.doc(path).get()).data();

  Future<int?> memberCount(String clubId) async =>
      (await read('clubs/$clubId'))!['memberCount'] as int?;

  /// Etkinliğin `[goingCount, waitlistCount]` sayaçları.
  Future<List<Object?>> counters(String eventId) async {
    final event = (await read('events/$eventId'))!;
    return [event['goingCount'], event['waitlistCount']];
  }

  List<Map<String, Object?>> writes() => [
    for (final write in service.writes)
      {'op': write.op, 'path': write.path, 'data': write.data},
  ];

  Future<void> seedUser({UserStatus status = UserStatus.active}) async {
    await db.doc(_userPath).set({
      ..._profile.toJson(),
      'status': status.json,
      'createdAt': _seededTs,
      'updatedAt': _seededTs,
      'isDeleted': false,
      'deletedAt': null,
      'deletedBy': null,
    });
    await db.doc(_accountPath).set({
      'email': 'Ayse.Isik@ogr.gumushane.edu.tr',
      'emailLower': 'ayse.isik@ogr.gumushane.edu.tr',
      'fcmTokens': [
        {'token': 'tok-1', 'platform': 'ios'},
      ],
      'lastLoginAt': _seededTs,
      'suspendReason': null,
      'createdAt': _seededTs,
      'updatedAt': _seededTs,
      'isDeleted': false,
      'deletedAt': null,
      'deletedBy': null,
    });
  }

  /// Hesabı doğrudan `deleted` yapar (markDeleted sonrası durum).
  Future<void> seedDeletedUser() async {
    await seedUser();
    await db.doc(_userPath).update({
      ...Anonymization.userPayload(_uid),
    });
  }

  Future<void> seedClub(String clubId, {int memberCount = 10}) =>
      db.doc('clubs/$clubId').set({
        'memberCount': memberCount,
        'updatedAt': _seededTs,
      });

  Future<void> seedMembership(
    String clubId,
    MembershipStatus status, {
    ClubRole role = ClubRole.member,
    MembershipApplicantModel applicant = _applicant,
    bool contact = true,
    String userId = _uid,
  }) async {
    await seedClub(clubId);
    await db
        .doc('memberships/${clubId}_$userId')
        .set(
          MembershipModel(
            clubId: clubId,
            userId: userId,
            applicant: applicant,
            status: status,
            role: role,
            createdAt: _seededAt,
            updatedAt: _seededAt,
          ).toJson(),
        );
    if (contact) {
      await db.doc('memberships/${clubId}_$userId/private/contact').set({
        'email': 'Ayse.Isik@ogr.gumushane.edu.tr',
        'emailLower': 'ayse.isik@ogr.gumushane.edu.tr',
        'note': 'Mobil geliştirmeye ilgim var.',
        'createdAt': _seededTs,
        'updatedAt': _seededTs,
        'isDeleted': false,
        'deletedAt': null,
        'deletedBy': null,
      });
    }
  }

  Future<void> seedEvent(
    String eventId, {
    required DateTime endsAt,
    int goingCount = 3,
    int waitlistCount = 2,
    bool isDeleted = false,
  }) => db
      .doc('events/$eventId')
      .set(
        EventModel(
          id: eventId,
          clubId: 'c01',
          createdBy: 'u_pres',
          title: 'Flutter Atölyesi',
          type: EventType.training,
          startsAt: endsAt.subtract(const Duration(hours: 2)),
          endsAt: endsAt,
          coverPalette: ClubPalette.red,
          coverPattern: ClubPattern.dots,
          status: EventStatus.published,
          goingCount: goingCount,
          waitlistCount: waitlistCount,
          createdAt: _seededAt,
          updatedAt: _seededAt,
          isDeleted: isDeleted,
        ).toJson(),
      );

  RsvpModel rsvpOf(
    String eventId,
    RsvpStatus status, {
    String userId = _uid,
  }) => RsvpModel(
    eventId: eventId,
    clubId: 'c01',
    userId: userId,
    ticketCode: 'GU-ABCD-EFGH',
    status: status,
    createdAt: _seededAt,
    updatedAt: _seededAt,
  );

  /// Etkinlik + [_uid] kullanıcısının kaydı.
  Future<RsvpModel> seedRsvp(
    String eventId,
    RsvpStatus status, {
    DateTime? endsAt,
    bool eventDeleted = false,
  }) async {
    await seedEvent(
      eventId,
      endsAt: endsAt ?? _futureEnd,
      isDeleted: eventDeleted,
    );
    final rsvp = rsvpOf(eventId, status);
    await db.doc('rsvps/${eventId}_$_uid').set(rsvp.toJson());
    return rsvp;
  }

  Future<void> seedPersonal(
    String collection,
    String id, {
    required String ownerField,
    String owner = _uid,
    bool isDeleted = false,
  }) => db.doc('$collection/$id').set({
    ownerField: owner,
    'createdAt': _seededTs,
    'updatedAt': _seededTs,
    'isDeleted': isDeleted,
    'deletedAt': null,
    'deletedBy': null,
  });

  MembershipModel membershipOf(
    String clubId,
    MembershipStatus status, {
    ClubRole role = ClubRole.member,
    String userId = _uid,
  }) => MembershipModel(
    clubId: clubId,
    userId: userId,
    applicant: _applicant,
    status: status,
    role: role,
  );

  setUp(() {
    db = FakeFirebaseFirestore();
    service = RecordingFirestoreService(FirebaseFirestoreService(db));
    clock = FakeAppClock(_now);
    memberships = membershipsOn(service);
    repository = repositoryOn(service);
  });

  group('T-29 · precheck · başkan engeli', () {
    test('etkin başkanlık → blockedByPresidency (kulüpler kimlik sırasıyla); '
        'başkan olmayan etkin rol, bekleyen ve geçmiş başkanlık sayılmaz; '
        'yazım yok', () async {
      await seedMembership(
        'c02',
        MembershipStatus.active,
        role: ClubRole.president,
      );
      await seedMembership(
        'c01',
        MembershipStatus.active,
        role: ClubRole.president,
      );
      await seedMembership(
        'c03',
        MembershipStatus.active,
        role: ClubRole.board,
      );
      await seedMembership(
        'c04',
        MembershipStatus.left,
        role: ClubRole.president,
      );
      await seedMembership('c05', MembershipStatus.active, userId: _other);

      final result = await repository.precheck(_uid);

      expect(
        result.dataOrNull,
        const DeletionPrecheck.blockedByPresidency(['c01', 'c02']),
      );
      expect(service.writes, isEmpty);
      expect(service.outsideWrites, 0);
    });

    test('başkanlık yok → ready', () async {
      await seedMembership(
        'c01',
        MembershipStatus.active,
        role: ClubRole.board,
      );
      await seedMembership('c02', MembershipStatus.pending);

      expect(
        (await repository.precheck(_uid)).dataOrNull,
        const DeletionPrecheck.ready(),
      );
    });
  });

  group('T-29 · markDeleted · adım 1 (dönüşü olmayan nokta)', () {
    test('TAM anonimleştirme alan listesi: users ve private/account tek '
        'batch; her alanın beklenen değeri; avatarSeed / staff / '
        'profileComplete / createdAt / lastLoginAt / suspendReason '
        'dokunulmaz', () async {
      await seedUser();
      final userBefore = (await read(_userPath))!;
      final accountBefore = (await read(_accountPath))!;

      final result = await repository.markDeleted(_uid);

      expect(result.isSuccess, isTrue);
      // Tek batch, transaction yok.
      expect(service.outsideWrites, 1);
      expect(service.transactions, 0);

      final user = (await read(_userPath))!;
      expect(_changedKeys(userBefore, user), {
        'name',
        'nameLower',
        'bio',
        'interests',
        'avatarPath',
        'department',
        'year',
        'status',
        'isDeleted',
        'deletedAt',
        'deletedBy',
        'updatedAt',
      });
      expect(user['name'], 'Silinmiş kullanıcı');
      expect(user['name'], Anonymization.deletedUserName);
      expect(user['nameLower'], 'silinmiş kullanıcı');
      expect(user['bio'], '');
      expect(user['interests'], isEmpty);
      expect(user, containsPair('avatarPath', null));
      expect(user, containsPair('department', null));
      expect(user, containsPair('year', null));
      expect(user['status'], 'deleted');
      expect(user['isDeleted'], isTrue);
      expect(user['deletedBy'], _uid);
      expect(user['deletedAt'], isA<Timestamp>());
      expect(user['updatedAt'], isA<Timestamp>());
      expect(user['updatedAt'], isNot(_seededTs));
      expect(user['avatarSeed'], 'seed-ayse');
      expect(user['staff'], isFalse);
      expect(user['profileComplete'], isTrue);
      expect(user['createdAt'], _seededTs);

      final account = (await read(_accountPath))!;
      expect(_changedKeys(accountBefore, account), {
        'email',
        'emailLower',
        'fcmTokens',
        'updatedAt',
      });
      expect(account['email'], '');
      expect(account['emailLower'], '');
      expect(account['fcmTokens'], isEmpty);
      expect(account['updatedAt'], isNot(_seededTs));
      expect(account['lastLoginAt'], _seededTs);
      expect(account, containsPair('suspendReason', null));
    });

    test('zaten silinmiş → yazmadan başarı (idempotent)', () async {
      await seedDeletedUser();

      final result = await repository.markDeleted(_uid);

      expect(result.isSuccess, isTrue);
      expect(service.outsideWrites, 0);
    });

    test('askıdaki hesap → failedPrecondition, yazım yok; belge yok → '
        'notFound', () async {
      expect(
        (await repository.markDeleted(_uid)).errorOrNull,
        FirestoreError.notFound,
      );
      await seedUser(status: UserStatus.suspended);

      final result = await repository.markDeleted(_uid);

      expect(result.errorOrNull, FirestoreError.failedPrecondition);
      expect(service.outsideWrites, 0);
      expect((await read(_userPath))!['name'], 'Ayşe Işık');
    });
  });

  group('T-29 · buildPlan · güncel durumdan kalan iş', () {
    test('hesap silinmemiş → failedPrecondition (plan çıkarılmaz)', () async {
      await seedUser();

      expect(
        (await repository.buildPlan(_uid)).errorOrNull,
        FirestoreError.failedPrecondition,
      );
    });

    test('W-80: yalnızca bitmemiş etkinliğin going / waitlist kaydı; geçmiş, '
        'saat payı içinde biten, silinmiş etkinlik ve attended / cancelled '
        'kayıtlar plana girmez', () async {
      await seedDeletedUser();
      final going = await seedRsvp('e01', RsvpStatus.going);
      final waitlist = await seedRsvp('e02', RsvpStatus.waitlist);
      await seedRsvp('e03', RsvpStatus.going, endsAt: _pastEnd);
      await seedRsvp('e04', RsvpStatus.waitlist, endsAt: _skewEnd);
      await seedRsvp('e05', RsvpStatus.going, eventDeleted: true);
      await seedRsvp('e06', RsvpStatus.attended);
      await seedRsvp('e07', RsvpStatus.cancelled);
      // Etkinliği hiç olmayan (okunamayan) açık kayıt.
      await db
          .doc('rsvps/e08_u_ayse')
          .set(rsvpOf('e08', RsvpStatus.waitlist).toJson());

      final plan = (await repository.buildPlan(_uid)).dataOrNull!;

      expect(plan.rsvps.map((r) => r.eventId), ['e01', 'e02']);
      expect(plan.rsvps.map((r) => r.status), [going.status, waitlist.status]);
      // Bitişi bilinemeyen (silinmiş / okunamayan etkinlik) açık kayıtlar
      // ayrı kümededir: etkinlik okunmadan denenir (güvenlik incelemesi).
      expect(plan.unreadableRsvps.map((r) => r.eventId), ['e05', 'e08']);
      expect(plan.chunkCount, 1 + 2);
    });

    test('üyelikler: active / pending ve anlık görüntüsü anonim olmayan '
        'üyelikler (etkin ve geçmiş başkanlık dahil); anlık görüntüsü anonim '
        'etkin başkan ve geçmiş üyelik girmez — kişisel belgeler: silinmemiş, '
        'sahibi olunan bildirim / kayıt / engel', () async {
      await seedDeletedUser();
      await seedMembership('c01', MembershipStatus.active);
      await seedMembership('c02', MembershipStatus.pending);
      await seedMembership('c03', MembershipStatus.left);
      await seedMembership(
        'c04',
        MembershipStatus.left,
        applicant: FirebaseMembershipRepository.anonymizedApplicant,
      );
      await seedMembership(
        'c05',
        MembershipStatus.active,
        role: ClubRole.president,
      );
      await seedMembership(
        'c06',
        MembershipStatus.removed,
        role: ClubRole.president,
      );
      await seedMembership(
        'c07',
        MembershipStatus.active,
        role: ClubRole.advisor,
      );
      await seedMembership('c08', MembershipStatus.active, userId: _other);
      await seedMembership(
        'c09',
        MembershipStatus.active,
        role: ClubRole.president,
        applicant: FirebaseMembershipRepository.anonymizedApplicant,
      );
      await seedPersonal('notifications', 'n01', ownerField: 'userId');
      await seedPersonal(
        'notifications',
        'n02',
        ownerField: 'userId',
        isDeleted: true,
      );
      await seedPersonal(
        'notifications',
        'n03',
        ownerField: 'userId',
        owner: _other,
      );
      await seedPersonal('savedPosts', 'u_ayse_p01', ownerField: 'userId');
      await seedPersonal('blocks', 'u_ayse_u_can', ownerField: 'blockerId');
      // Beni engelleyen: benim belgem değil.
      await seedPersonal(
        'blocks',
        'u_can_u_ayse',
        ownerField: 'blockerId',
        owner: _other,
      );

      final plan = (await repository.buildPlan(_uid)).dataOrNull!;

      expect(plan.memberships.map((m) => m.clubId), [
        'c01',
        'c02',
        'c03',
        'c05',
        'c06',
        'c07',
      ]);
      expect(plan.personalRefs, const [
        PersonalDocRef(PersonalDocKind.notification, 'n01'),
        PersonalDocRef(PersonalDocKind.savedPost, 'u_ayse_p01'),
        PersonalDocRef(PersonalDocKind.block, 'u_ayse_u_can'),
      ]);
      expect(service.outsideWrites, 0);
      expect(service.transactions, 0);
    });
  });

  group('T-29 · cancelRsvpChunk', () {
    test('going / waitlist → cancelled + ilgili sayaç −1, tek transaction; '
        'kayıtta yalnızca status + updatedAt, etkinlikte yalnızca sayaç + '
        'updatedAt (lastRsvpRef yok — W-64)', () async {
      final going = await seedRsvp('e01', RsvpStatus.going);
      final waitlist = await seedRsvp('e02', RsvpStatus.waitlist);

      final result = await repository.cancelRsvpChunk(_uid, [going, waitlist]);

      expect(result.isSuccess, isTrue);
      expect(service.transactions, 1);
      expect(service.outsideWrites, 0);
      expect(writes(), [
        {
          'op': 'update',
          'path': 'rsvps/e01_u_ayse',
          'data': {'status': 'cancelled', 'updatedAt': serverTimestampMark},
        },
        {
          'op': 'update',
          'path': 'events/e01',
          'data': {
            'goingCount': incrementMark,
            'updatedAt': serverTimestampMark,
          },
        },
        {
          'op': 'update',
          'path': 'rsvps/e02_u_ayse',
          'data': {'status': 'cancelled', 'updatedAt': serverTimestampMark},
        },
        {
          'op': 'update',
          'path': 'events/e02',
          'data': {
            'waitlistCount': incrementMark,
            'updatedAt': serverTimestampMark,
          },
        },
      ]);
      expect(await counters('e01'), [2, 2]);
      expect(await counters('e02'), [3, 1]);
      expect((await read('rsvps/e01_u_ayse'))!['status'], 'cancelled');
    });

    test('işlem içinde yeniden okunur: zaten vazgeçilmiş, yoklaması alınmış '
        've arada biten etkinliğin kaydı yazılmaz (W-80, CD-144)', () async {
      final cancelled = await seedRsvp('e01', RsvpStatus.going);
      await db.doc('rsvps/e01_u_ayse').update({'status': 'cancelled'});
      final attended = await seedRsvp('e02', RsvpStatus.going);
      await db.doc('rsvps/e02_u_ayse').update({'status': 'attended'});
      final ended = await seedRsvp('e03', RsvpStatus.going, endsAt: _pastEnd);

      final result = await repository.cancelRsvpChunk(_uid, [
        cancelled,
        attended,
        ended,
      ]);

      expect(result.isSuccess, isTrue);
      expect(service.writes, isEmpty);
      expect(await counters('e03'), [3, 2]);
      expect((await read('rsvps/e03_u_ayse'))!['status'], 'going');
    });

    test('kimlik birleşimi: rsvps/e01_u_ayse başka bir (etkinlik, kullanıcı) '
        'çiftinin kaydıysa permissionDenied, yazım yok', () async {
      await seedEvent('e01', endsAt: _futureEnd);
      // `e01_u` + `ayse` aynı kimliği üretir.
      await db
          .doc('rsvps/e01_u_ayse')
          .set(rsvpOf('e01_u', RsvpStatus.going, userId: 'ayse').toJson());

      final result = await repository.cancelRsvpChunk(_uid, [
        rsvpOf('e01', RsvpStatus.going),
      ]);

      expect(result.errorOrNull, FirestoreError.permissionDenied);
      expect(service.writes, isEmpty);
    });
  });

  group('T-29 · anonymizeChunk · M14', () {
    test('active üye / yönetim kurulu → left + memberCount −1; danışman → '
        'left, sayaç yok; pending → cancelled; geçmiş üyelik durumu aynı; '
        'hepsinde applicant anonim, contact boş; tek transaction, günlük / '
        'users / lastMembershipRef yazımı yok', () async {
      await seedMembership('c01', MembershipStatus.active);
      await seedMembership(
        'c02',
        MembershipStatus.active,
        role: ClubRole.board,
      );
      await seedMembership(
        'c03',
        MembershipStatus.active,
        role: ClubRole.advisor,
      );
      await seedMembership('c04', MembershipStatus.pending);
      await seedMembership('c05', MembershipStatus.rejected, contact: false);

      final result = await memberships.anonymizeChunk(
        uid: _uid,
        memberships: [
          membershipOf('c01', MembershipStatus.active),
          membershipOf('c02', MembershipStatus.active, role: ClubRole.board),
          membershipOf('c03', MembershipStatus.active, role: ClubRole.advisor),
          membershipOf('c04', MembershipStatus.pending),
          membershipOf('c05', MembershipStatus.rejected),
        ],
      );

      expect(result.isSuccess, isTrue);
      expect(service.transactions, 1);
      expect(service.outsideWrites, 0);
      Map<String, Object?> membership(String clubId, String? status) => {
        'op': 'update',
        'path': 'memberships/${clubId}_u_ayse',
        'data': {
          'status': ?status,
          'applicant': _anonymousApplicant,
          'updatedAt': serverTimestampMark,
        },
      };
      Map<String, Object?> counter(String clubId) => {
        'op': 'update',
        'path': 'clubs/$clubId',
        'data': {
          'memberCount': incrementMark,
          'updatedAt': serverTimestampMark,
        },
      };
      Map<String, Object?> contact(String clubId) => {
        'op': 'update',
        'path': 'memberships/${clubId}_u_ayse/private/contact',
        'data': {
          'email': '',
          'emailLower': '',
          'note': '',
          'updatedAt': serverTimestampMark,
        },
      };
      expect(writes(), [
        membership('c01', 'left'),
        counter('c01'),
        contact('c01'),
        membership('c02', 'left'),
        counter('c02'),
        contact('c02'),
        membership('c03', 'left'),
        contact('c03'),
        membership('c04', 'cancelled'),
        contact('c04'),
        membership('c05', null),
      ]);
      expect(await memberCount('c01'), 9);
      expect(await memberCount('c02'), 9);
      expect(await memberCount('c03'), 10);
      expect(await memberCount('c04'), 10);
      expect(await read('memberships/c05_u_ayse/private/contact'), isNull);
      final stored = (await read('memberships/c01_u_ayse'))!;
      expect(stored['applicant'], _anonymousApplicant);
      expect(stored['status'], 'left');
      expect(stored['role'], 'member');
      expect((await read('memberships/c05_u_ayse'))!['status'], 'rejected');
      expect(
        await read('memberships/c01_u_ayse/private/contact'),
        containsPair('note', ''),
      );
      expect((await db.collection('activity').get()).docs, isEmpty);
    });

    test('ikinci çalıştırma hiçbir şey yazmaz (idempotent); sayaç bir kez '
        'düşer', () async {
      await seedMembership('c01', MembershipStatus.active);
      final chunk = [membershipOf('c01', MembershipStatus.active)];
      await memberships.anonymizeChunk(uid: _uid, memberships: chunk);
      service.writes.clear();

      final again = await memberships.anonymizeChunk(
        uid: _uid,
        memberships: chunk,
      );

      expect(again.isSuccess, isTrue);
      expect(service.writes, isEmpty);
      expect(await memberCount('c01'), 9);
    });

    test('etkin başkan (güvenlik incelemesi): durum active kalır, applicant '
        've contact anonimleşir, sayaç oynamaz; parçadaki üye yine ayrılır; '
        'ikinci koşu yazmaz', () async {
      await seedMembership('c01', MembershipStatus.active);
      await seedMembership(
        'c02',
        MembershipStatus.active,
        role: ClubRole.president,
      );
      final chunk = [
        membershipOf('c01', MembershipStatus.active),
        membershipOf('c02', MembershipStatus.active, role: ClubRole.president),
      ];

      final result = await memberships.anonymizeChunk(
        uid: _uid,
        memberships: chunk,
      );

      expect(result.isSuccess, isTrue);
      final president = (await read('memberships/c02_u_ayse'))!;
      expect(
        [president['status'], president['role'], president['applicant']],
        ['active', 'president', _anonymousApplicant],
      );
      final contact = (await read('memberships/c02_u_ayse/private/contact'))!;
      expect(
        [contact['email'], contact['emailLower'], contact['note']],
        ['', '', ''],
      );
      expect(await memberCount('c02'), 10);
      expect((await read('memberships/c01_u_ayse'))!['status'], 'left');
      expect(await memberCount('c01'), 9);
      expect(
        writes().where((w) => w['path'] == 'memberships/c02_u_ayse'),
        [
          {
            'op': 'update',
            'path': 'memberships/c02_u_ayse',
            'data': {
              'applicant': _anonymousApplicant,
              'updatedAt': serverTimestampMark,
            },
          },
        ],
      );
      service.writes.clear();

      expect(
        (await memberships.anonymizeChunk(
          uid: _uid,
          memberships: chunk,
        )).isSuccess,
        isTrue,
      );
      expect(service.writes, isEmpty);
    });

    test('kimlik birleşimi: memberships/c01_u_ayse başka bir (kulüp, '
        'kullanıcı) çiftininse permissionDenied, yazım yok', () async {
      // `c01_u` + `ayse` aynı kimliği üretir.
      await db
          .doc('memberships/c01_u_ayse')
          .set(
            membershipOf(
              'c01_u',
              MembershipStatus.active,
              userId: 'ayse',
            ).toJson(),
          );

      final result = await memberships.anonymizeChunk(
        uid: _uid,
        memberships: [membershipOf('c01', MembershipStatus.active)],
      );

      expect(result.errorOrNull, FirestoreError.permissionDenied);
      expect(service.writes, isEmpty);
    });
  });

  group('T-29 · geçersiz girdi (yazım ve okuma yok)', () {
    test('parça sınırı, başka kullanıcının belgesi, aynı belge iki kez → '
        'invalidArgument; boş parça → okumadan başarı', () async {
      final six = [
        for (var i = 1; i <= Limits.accountDeletionChunk + 1; i++)
          membershipOf('c$i', MembershipStatus.active),
      ];
      final cases = <String, Future<FirestoreResult<void>> Function()>{
        'üyelik > chunk': () =>
            memberships.anonymizeChunk(uid: _uid, memberships: six),
        'başkasının üyeliği': () => memberships.anonymizeChunk(
          uid: _uid,
          memberships: [
            membershipOf('c01', MembershipStatus.active, userId: _other),
          ],
        ),
        'aynı kulüp iki kez': () => memberships.anonymizeChunk(
          uid: _uid,
          memberships: [
            membershipOf('c01', MembershipStatus.active),
            membershipOf('c01', MembershipStatus.pending),
          ],
        ),
        'kayıt > chunk': () => repository.cancelRsvpChunk(_uid, [
          for (var i = 1; i <= Limits.accountDeletionChunk + 1; i++)
            rsvpOf('e$i', RsvpStatus.going),
        ]),
        'başkasının kaydı': () => repository.cancelRsvpChunk(_uid, [
          rsvpOf('e01', RsvpStatus.going, userId: _other),
        ]),
        'aynı etkinlik iki kez': () => repository.cancelRsvpChunk(_uid, [
          rsvpOf('e01', RsvpStatus.going),
          rsvpOf('e01', RsvpStatus.waitlist),
        ]),
        'kişisel > batchMaxWrites': () => repository.softDeletePersonalChunk(
          _uid,
          [
            for (var i = 0; i <= Limits.batchMaxWrites; i++)
              PersonalDocRef(PersonalDocKind.notification, 'n$i'),
          ],
        ),
        'kişisel geçersiz kimlik': () => repository.softDeletePersonalChunk(
          _uid,
          const [PersonalDocRef(PersonalDocKind.block, 'a/b')],
        ),
      };
      for (final MapEntry(key: name, value: call) in cases.entries) {
        expect(
          (await call()).errorOrNull,
          FirestoreError.invalidArgument,
          reason: name,
        );
      }
      for (final empty in [
        () => memberships.anonymizeChunk(uid: _uid, memberships: const []),
        () => repository.cancelRsvpChunk(_uid, const []),
        () => repository.softDeletePersonalChunk(_uid, const []),
      ]) {
        expect((await empty()).isSuccess, isTrue);
      }
      expect(service.transactions, 0);
      expect(service.outsideWrites, 0);
    });

    test('geçersiz uid (W-54) → her üyede invalidArgument', () async {
      for (final uid in _invalidIds) {
        final results = [
          await repository.precheck(uid),
          await repository.markDeleted(uid),
          await repository.buildPlan(uid),
          await repository.cancelRsvpChunk(uid, const []),
          await repository.anonymizeMembershipChunk(uid, const []),
          await repository.softDeletePersonalChunk(uid, const []),
          await repository.resumeCleanup(uid),
        ];
        for (final result in results) {
          expect(result.errorOrNull, FirestoreError.invalidArgument);
        }
      }
      expect(service.transactions, 0);
      expect(service.outsideWrites, 0);
    });
  });

  group('T-29 · resumeCleanup · tam dizi, parçalar, yeniden başlatma', () {
    test(
      'tam dizi: markDeleted + resumeCleanup — katılım iptali, M14, '
      'kişisel soft delete; gönderi / destek talebi / settings / geçmiş '
      'kayıt / başkalarının belgeleri dokunulmaz; ilerleme 1/3…3/3',
      () async {
        await seedUser();
        await seedRsvp('e01', RsvpStatus.going);
        await seedRsvp('e02', RsvpStatus.going, endsAt: _pastEnd);
        await seedMembership('c01', MembershipStatus.active);
        await seedMembership('c02', MembershipStatus.pending);
        await seedPersonal('notifications', 'n01', ownerField: 'userId');
        await seedPersonal('savedPosts', 'u_ayse_p01', ownerField: 'userId');
        await seedPersonal('blocks', 'u_ayse_u_can', ownerField: 'blockerId');
        await seedPersonal(
          'blocks',
          'u_can_u_ayse',
          ownerField: 'blockerId',
          owner: _other,
        );
        final untouched = <String, Json>{
          'posts/p01': {
            'authorId': _uid,
            'text': 'Merhaba',
            'isDeleted': false,
          },
          'comments/k01': {'authorId': _uid, 'text': 'Katılıyorum'},
          'supportTickets/s01': {'userId': _uid, 'message': 'Yardım'},
          'settings/u_ayse': {'notifyEvents': true},
        };
        for (final MapEntry(key: path, value: data) in untouched.entries) {
          await db.doc(path).set(data);
        }
        final progress = <DeleteProgress>[];

        expect((await repository.markDeleted(_uid)).isSuccess, isTrue);
        final result = await repository.resumeCleanup(
          _uid,
          onProgress: progress.add,
        );

        expect(result.isSuccess, isTrue);
        expect(progress, const [
          DeleteProgress(done: 1, total: 3),
          DeleteProgress(done: 2, total: 3),
          DeleteProgress(done: 3, total: 3),
        ]);
        expect((await read('rsvps/e01_u_ayse'))!['status'], 'cancelled');
        expect(await counters('e01'), [2, 2]);
        expect((await read('rsvps/e02_u_ayse'))!['status'], 'going');
        expect(await counters('e02'), [3, 2]);
        expect((await read('memberships/c01_u_ayse'))!['status'], 'left');
        expect((await read('memberships/c02_u_ayse'))!['status'], 'cancelled');
        expect(await memberCount('c01'), 9);
        for (final clubId in ['c01', 'c02']) {
          expect(
            (await read('memberships/${clubId}_u_ayse'))!['applicant'],
            _anonymousApplicant,
          );
          final contact = (await read(
            'memberships/${clubId}_u_ayse/private/contact',
          ))!;
          expect(
            [contact['email'], contact['emailLower'], contact['note']],
            [
              '',
              '',
              '',
            ],
          );
        }
        for (final path in [
          'notifications/n01',
          'savedPosts/u_ayse_p01',
          'blocks/u_ayse_u_can',
        ]) {
          final doc = (await read(path))!;
          expect(doc['isDeleted'], isTrue, reason: path);
          expect(doc['deletedBy'], _uid, reason: path);
          expect(doc['deletedAt'], isA<Timestamp>(), reason: path);
        }
        expect((await read('blocks/u_can_u_ayse'))!['isDeleted'], isFalse);
        for (final MapEntry(key: path, value: data) in untouched.entries) {
          expect(await read(path), data, reason: path);
        }
        // Belge silinmez: kullanıcı belgesi yerinde, anonim.
        expect((await read(_userPath))!['status'], 'deleted');
        // Bitmiş temizlikte plan boştur; tekrar çağrı yazmaz.
        final writesBefore = (service.transactions, service.outsideWrites);
        expect((await repository.resumeCleanup(_uid)).isSuccess, isTrue);
        expect((service.transactions, service.outsideWrites), writesBefore);
      },
    );

    test('parça sınırı: 12 üyelik → 5 + 5 + 2 (üç transaction), 451 kişisel '
        'belge → 450 + 1; her parçada ilerleme', () async {
      await seedDeletedUser();
      for (var i = 1; i <= 12; i++) {
        await seedMembership(
          'c${i.toString().padLeft(2, '0')}',
          MembershipStatus.active,
        );
      }
      final plan = (await repository.buildPlan(_uid)).dataOrNull!;
      expect(plan.membershipChunks.map((chunk) => chunk.length), [5, 5, 2]);
      expect(
        DeletionPlan(
          personalRefs: [
            for (var i = 0; i < 451; i++)
              PersonalDocRef(PersonalDocKind.notification, 'n$i'),
          ],
        ).personalChunks.map((chunk) => chunk.length),
        [450, 1],
      );
      final progress = <DeleteProgress>[];

      final result = await repository.resumeCleanup(
        _uid,
        onProgress: progress.add,
      );

      expect(result.isSuccess, isTrue);
      expect(service.transactions, 3);
      expect(progress.map((p) => (p.done, p.total)), [(1, 3), (2, 3), (3, 3)]);
      for (var i = 1; i <= 12; i++) {
        expect(await memberCount('c${i.toString().padLeft(2, '0')}'), 9);
      }
    });

    test(
      'yarıda kesilme: 3. parçada ağ kalıcı gider → kalan parçalar da düşer '
      '(yeniden denemeler tükenir), ilk hata döner, kesinleşen parçalar '
      'kalır; 2. çalıştırma yalnızca kalan işi yapar (katılım yeniden '
      'yazılmaz, sayaçlar bir kez düşer); 3. çalıştırma boş',
      () async {
        await seedDeletedUser();
        for (var i = 1; i <= 6; i++) {
          await seedRsvp('e0$i', RsvpStatus.going);
        }
        for (var i = 1; i <= 7; i++) {
          await seedMembership('c0$i', MembershipStatus.active);
        }
        await seedPersonal('notifications', 'n01', ownerField: 'userId');
        final interrupting = _InterruptingService(
          FirebaseFirestoreService(db),
          failAtWrite: 3,
          lasting: true,
        );
        final firstProgress = <DeleteProgress>[];

        final first = await repositoryOn(
          interrupting,
        ).resumeCleanup(_uid, onProgress: firstProgress.add);

        expect(first.errorOrNull, FirestoreError.unavailable);
        expect(firstProgress, const [
          DeleteProgress(done: 1, total: 5),
          DeleteProgress(done: 2, total: 5),
        ]);
        for (var i = 1; i <= 6; i++) {
          expect((await read('rsvps/e0${i}_u_ayse'))!['status'], 'cancelled');
        }
        expect((await read('memberships/c01_u_ayse'))!['status'], 'active');

        final secondProgress = <DeleteProgress>[];
        final second = await repository.resumeCleanup(
          _uid,
          onProgress: secondProgress.add,
        );

        expect(second.isSuccess, isTrue);
        expect(secondProgress.map((p) => (p.done, p.total)), [
          (1, 3),
          (2, 3),
          (3, 3),
        ]);
        expect(
          service.writes.where((write) => write.path.startsWith('rsvps/')),
          isEmpty,
        );
        for (var i = 1; i <= 6; i++) {
          expect(await counters('e0$i'), [2, 2]);
        }
        for (var i = 1; i <= 7; i++) {
          expect(await memberCount('c0$i'), 9);
          expect((await read('memberships/c0${i}_u_ayse'))!['status'], 'left');
        }
        expect((await read('notifications/n01'))!['isDeleted'], isTrue);

        final writesBefore = (service.transactions, service.outsideWrites);
        final third = await repository.resumeCleanup(_uid);
        expect(third.isSuccess, isTrue);
        expect((service.transactions, service.outsideWrites), writesBefore);
      },
    );

    test('tek seferlik ağ hatası: parça RetryPolicy ile yeniden denenir, '
        'dizi ilk çalıştırmada tamamlanır', () async {
      await seedDeletedUser();
      await seedRsvp('e01', RsvpStatus.going);
      await seedMembership('c01', MembershipStatus.active);
      await seedPersonal('notifications', 'n01', ownerField: 'userId');
      final progress = <DeleteProgress>[];

      final result = await repositoryOn(
        _InterruptingService(FirebaseFirestoreService(db), failAtWrite: 2),
      ).resumeCleanup(_uid, onProgress: progress.add);

      expect(result.isSuccess, isTrue);
      expect(progress.map((p) => (p.done, p.total)), [(1, 3), (2, 3), (3, 3)]);
      expect((await read('memberships/c01_u_ayse'))!['status'], 'left');
      expect(await memberCount('c01'), 9);
      expect((await read('notifications/n01'))!['isDeleted'], isTrue);
    });

    test('bağımsız parçalar (güvenlik incelemesi): kalıcı hata veren üyelik '
        '(c01) parçasını öğe öğe yeniden koşturur — c02…c05 ve sonraki '
        'parça anonimleşir, kişisel belgeler silinir; ilk hata sonda döner; '
        "sonraki çalıştırma yalnızca c01'i dener", () async {
      await seedDeletedUser();
      for (var i = 1; i <= 7; i++) {
        await seedMembership('c0$i', MembershipStatus.active);
      }
      await seedPersonal('notifications', 'n01', ownerField: 'userId');
      final failing = _FailingClubMemberships(membershipsOn(service), 'c01');
      final progress = <DeleteProgress>[];

      final result = await repositoryOn(
        service,
        memberships: failing,
      ).resumeCleanup(_uid, onProgress: progress.add);

      expect(result.errorOrNull, FirestoreError.permissionDenied);
      expect((await read('memberships/c01_u_ayse'))!['status'], 'active');
      expect(await memberCount('c01'), 10);
      for (var i = 2; i <= 7; i++) {
        final membership = (await read('memberships/c0${i}_u_ayse'))!;
        expect(membership['status'], 'left', reason: 'c0$i');
        expect(membership['applicant'], _anonymousApplicant, reason: 'c0$i');
        expect(await memberCount('c0$i'), 9, reason: 'c0$i');
      }
      expect((await read('notifications/n01'))!['isDeleted'], isTrue);
      // Bozuk öğeli parça ilerlemeye sayılmaz: 2. üyelik parçası + kişisel.
      expect(progress.map((p) => (p.done, p.total)), [(1, 3), (2, 3)]);

      failing.calls.clear();
      final again = await repositoryOn(
        service,
        memberships: failing,
      ).resumeCleanup(_uid);
      expect(again.errorOrNull, FirestoreError.permissionDenied);
      expect(failing.calls, [
        ['c01'],
      ]);
    });

    test('okunamayan etkinlik (güvenlik incelemesi): plana okunamayan '
        'kümeyle giren (burada silinmiş) etkinlikteki açık kayıt etkinlik '
        'okunmadan vazgeçilir (sayaç −1, kayıt başına batch, transaction '
        'yok); Rules reddi / olmayan etkinlik ayrı testte', () async {
      await seedDeletedUser();
      await seedRsvp('e05', RsvpStatus.waitlist, eventDeleted: true);

      final result = await repository.resumeCleanup(_uid);

      expect(result.isSuccess, isTrue);
      expect((await read('rsvps/e05_u_ayse'))!['status'], 'cancelled');
      expect(await counters('e05'), [3, 1]);
      expect((service.transactions, service.outsideWrites), (0, 1));
    });

    test('hesap silinmemişken resumeCleanup → failedPrecondition, yazım '
        'yok', () async {
      await seedUser();
      await seedMembership('c01', MembershipStatus.active);

      final result = await repository.resumeCleanup(_uid);

      expect(result.errorOrNull, FirestoreError.failedPrecondition);
      expect(service.transactions, 0);
      expect(service.outsideWrites, 0);
    });
  });

  group('T-29 · cancelUnreadableRsvp', () {
    test('Rules reddi (bitmiş etkinlik — W-80) ve olmayan etkinlik başarıdır '
        '(kayıt korunur); ağ hatası döner', () async {
      final rsvp = rsvpOf('e01', RsvpStatus.going);
      expect(
        (await failing('permission-denied').cancelUnreadableRsvp(
          _uid,
          rsvp,
        )).isSuccess,
        isTrue,
      );
      expect(
        (await failing('not-found').cancelUnreadableRsvp(_uid, rsvp)).isSuccess,
        isTrue,
      );
      expect(
        (await failing(
          'unavailable',
        ).cancelUnreadableRsvp(_uid, rsvp)).errorOrNull,
        FirestoreError.unavailable,
      );
    });

    test('başka kullanıcının kaydı / geçersiz eventId → invalidArgument; '
        'açık olmayan kayıt → yazmadan başarı', () async {
      expect(
        (await repository.cancelUnreadableRsvp(
          _uid,
          rsvpOf('e01', RsvpStatus.going, userId: _other),
        )).errorOrNull,
        FirestoreError.invalidArgument,
      );
      expect(
        (await repository.cancelUnreadableRsvp(
          _uid,
          rsvpOf('e/1', RsvpStatus.going),
        )).errorOrNull,
        FirestoreError.invalidArgument,
      );
      for (final status in [RsvpStatus.cancelled, RsvpStatus.attended]) {
        expect(
          (await repository.cancelUnreadableRsvp(
            _uid,
            rsvpOf('e01', status),
          )).isSuccess,
          isTrue,
        );
      }
      expect(service.outsideWrites, 0);
    });
  });

  group('T-29 · hata eşlemesi', () {
    const codes = {
      'permission-denied': FirestoreError.permissionDenied,
      'unavailable': FirestoreError.unavailable,
    };
    for (final MapEntry(key: code, value: error) in codes.entries) {
      test('$code → $error (her üye)', () async {
        final on = failing(code);
        final results = [
          await on.precheck(_uid),
          await on.markDeleted(_uid),
          await on.buildPlan(_uid),
          await on.cancelRsvpChunk(_uid, [rsvpOf('e01', RsvpStatus.going)]),
          await on.anonymizeMembershipChunk(_uid, [
            membershipOf('c01', MembershipStatus.active),
          ]),
          await on.softDeletePersonalChunk(_uid, const [
            PersonalDocRef(PersonalDocKind.notification, 'n01'),
          ]),
          await on.resumeCleanup(_uid),
        ];
        for (final result in results) {
          expect(result.errorOrNull, error);
        }
      });
    }
  });
}

/// [failAtWrite]'inci yazım çağrısını (transaction ya da batch) gövdeyi hiç
/// çalıştırmadan ağ hatasıyla bitiren servis: uygulamanın / ağın parça
/// ortasında kesilmesini ([lasting]) ya da tek seferlik kesintiyi taklit
/// eder. Öncesi (ve geçici kesintide sonrası) [_inner]'a gider.
final class _InterruptingService implements FirestoreService {
  _InterruptingService(
    this._inner, {
    required this.failAtWrite,
    this.lasting = false,
  });

  final FirestoreService _inner;

  /// Başarısız olacak yazım çağrısının sırası (1'den başlar).
  final int failAtWrite;

  /// `true`: [failAtWrite]'inci ve sonraki TÜM yazımlar düşer (uygulama
  /// kapandı / ağ gitti); `false`: yalnızca o yazım (geçici kesinti).
  final bool lasting;

  int _writeCalls = 0;

  bool get _fails =>
      lasting ? ++_writeCalls >= failAtWrite : ++_writeCalls == failAtWrite;

  static const FirebaseFailure<Never, FirestoreError> _lost = FirebaseFailure(
    FirestoreError.unavailable,
    message: 'bağlantı koptu',
  );

  @override
  DocumentReference<Json> doc(String collectionPath, String id) =>
      _inner.doc(collectionPath, id);

  @override
  String newId(String collectionPath) => _inner.newId(collectionPath);

  @override
  Query<Json> collection(String path) => _inner.collection(path);

  @override
  Query<Json> collectionGroup(String collectionId) =>
      _inner.collectionGroup(collectionId);

  @override
  Future<FirestoreResult<FirestoreDoc?>> getDoc(DocumentReference<Json> ref) =>
      _inner.getDoc(ref);

  @override
  Future<FirestoreResult<FirestoreDoc?>> getDocFromCache(
    DocumentReference<Json> ref,
  ) => _inner.getDocFromCache(ref);

  @override
  Future<FirestoreResult<void>> setNetworkEnabled({required bool enabled}) =>
      _inner.setNetworkEnabled(enabled: enabled);

  @override
  Future<FirestoreResult<List<FirestoreDoc>>> getList(Query<Json> query) =>
      _inner.getList(query);

  @override
  Future<FirestoreResult<PageResult<FirestoreDoc>>> getPage(
    Query<Json> query,
    PageRequest page,
  ) => _inner.getPage(query, page);

  @override
  Stream<FirestoreResult<FirestoreDoc?>> watchDoc(
    DocumentReference<Json> ref,
  ) => _inner.watchDoc(ref);

  @override
  Stream<FirestoreResult<List<FirestoreDoc>>> watchList(Query<Json> query) =>
      _inner.watchList(query);

  @override
  Future<FirestoreResult<String>> add(String collectionPath, Json data) =>
      _inner.add(collectionPath, data);

  @override
  Future<FirestoreResult<void>> set(
    DocumentReference<Json> ref,
    Json data, {
    bool merge = false,
  }) => _inner.set(ref, data, merge: merge);

  @override
  Future<FirestoreResult<void>> update(
    DocumentReference<Json> ref,
    Json fields, {
    bool touchUpdatedAt = true,
  }) => _inner.update(ref, fields, touchUpdatedAt: touchUpdatedAt);

  @override
  Future<FirestoreResult<T>> runTransaction<T>(
    Future<T> Function(Transaction tx) body,
  ) async {
    if (_fails) return _lost;
    return _inner.runTransaction(body);
  }

  @override
  Future<FirestoreResult<void>> commitBatch(
    void Function(WriteBatch batch) build,
  ) async {
    if (_fails) return _lost;
    return _inner.commitBatch(build);
  }

  @override
  Future<FirestoreResult<void>> softDelete(
    DocumentReference<Json> ref, {
    required String actorId,
    WriteBatch? batch,
  }) => _inner.softDelete(ref, actorId: actorId, batch: batch);

  @override
  Future<FirestoreResult<void>> restore(
    DocumentReference<Json> ref, {
    WriteBatch? batch,
  }) => _inner.restore(ref, batch: batch);

  @override
  Future<FirestoreResult<int>> count(Query<Json> query) => _inner.count(query);

  @override
  Object serverTimestamp() => _inner.serverTimestamp();
}

/// [clubId] kulübünü içeren her `anonymizeChunk` parçasını kalıcı Rules
/// reddiyle (`permissionDenied` — ör. 0'a kaymış `memberCount`) bitiren
/// üyelik repository'si; diğer parçalar ve okumalar [_inner]'a gider.
/// [calls] her `anonymizeChunk` çağrısının kulüp kimlikleridir.
final class _FailingClubMemberships implements MembershipRepository {
  _FailingClubMemberships(this._inner, this.clubId);

  final MembershipRepository _inner;

  /// Kalıcı olarak reddedilen kulüp.
  final String clubId;

  final List<List<String>> calls = [];

  @override
  Future<FirestoreResult<void>> anonymizeChunk({
    required String uid,
    required List<MembershipModel> memberships,
  }) async {
    final clubs = [for (final m in memberships) m.clubId];
    calls.add(clubs);
    if (clubs.contains(clubId)) {
      return const FirebaseFailure(
        FirestoreError.permissionDenied,
        message: 'kalıcı ret',
      );
    }
    return _inner.anonymizeChunk(uid: uid, memberships: memberships);
  }

  @override
  Future<FirestoreResult<List<MembershipModel>>> listMine(
    String uid, {
    Set<MembershipStatus>? statuses,
  }) => _inner.listMine(uid, statuses: statuses);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

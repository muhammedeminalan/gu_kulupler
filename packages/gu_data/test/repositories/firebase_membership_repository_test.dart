// T-15 · MembershipRepository (başvuran / üye tarafı): üyelik durum
// makinesinin başvuran satırları — başvur (M1), anında katıl (M2), yeniden
// başvur / katıl (M3, M4 + bekleme süresi), isteği iptal et (M7), ayrıl (M8)
// — her geçişin geçerli kaynak durumları ve reddedilen kaynak durumları;
// yazılan belgeler ve ham yükleri (üyelik, `private/contact`, `memberCount`
// sayacı, günlük) tek transaction'da; bildirim çağrıları; kulüp koşulları;
// okumalar, süzgeçler ve sayfalama; geçersiz kimlik (W-54), ayrıştırma
// hatası ve hata eşlemesi (PLAN §10.4, §10.5, §10.6; domain-model §5;
// rules-spec §3.4, §4, §6; D-10, D-29, CD-41, CD-137, W-51). Güvenlik
// incelemesi vakaları (CD-137 madde 8q–8v): kulüp belgesine üyelik yolu
// yazılmaz, günlük kimliği sabittir, iptal edilen başvuru anında katılıma
// dönüşmez, anlık görüntü güncel kullanıcı belgesinden kurulur.
//
// T-16 · `updateApplicationNote`: bekleyen başvurunun notu yalnızca
// `private/contact` belgesinde değişir (üyelik, sayaç, günlük ve bildirim
// yok); bekleyen dışındaki her durumda çakışma; not zorunlu kulüpte boş not
// ve üst sınırı aşan not reddedilir (PLAN §10.4; rules-spec §3.4 U(b)).
//
// Mutlu yollar `fake_cloud_firestore` ile (Q-06); yazım kümesi kayıt tutan
// servis çiftiyle (`test/fakes/recording_firestore_service.dart`), hata
// yolları el yazımı SDK çiftleriyle (`test/fakes/sdk_firestore_stubs.dart`).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../fakes/fake_app_clock.dart';
import '../fakes/fake_notification_dispatcher.dart';
import '../fakes/recording_firestore_service.dart';
import '../fakes/sdk_firestore_stubs.dart';
import '../helpers/plan_repository_table.dart';
import '../helpers/plan_service_table.dart';

const String _interface =
    'packages/gu_data/lib/src/repositories/membership_repository.dart';
const String _implementation =
    'packages/gu_data/lib/src/repositories/firebase_membership_repository.dart';

const String _clubId = 'c01';
const String _uid = 'u_ayse';
const String _email = 'Ayse.Isik@ogr.gumushane.edu.tr';
const String _emailLower = 'ayse.isik@ogr.gumushane.edu.tr';
const String _oldEmail = 'eski@ogr.gumushane.edu.tr';
const String _clubPath = 'clubs/c01';
const String _membershipId = 'c01_u_ayse';
const String _membershipPath = 'memberships/c01_u_ayse';
const String _contactPath = 'memberships/c01_u_ayse/private/contact';
const String _userPath = 'users/u_ayse';
const int _memberCount = 12;

/// Geçersiz belge kimlikleri (W-54).
const List<String> _invalidIds = ['', 'c/1', '..', '__id__'];

final DateTime _now = DateTime.utc(2026, 10, 13, 9);
final DateTime _createdAt = DateTime.utc(2026, 3, 2, 8);
final DateTime _decidedAt = DateTime.utc(2026, 10, 1, 12);
final DateTime _retryAfter = _decidedAt.add(Limits.reapplyCooldown);

/// Başvuran profil (anlık görüntünün kaynağı).
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

const Json _applicantJson = {
  'name': 'Ayşe Işık',
  'department': 'd02',
  'year': '2',
  'avatarSeed': 'seed-ayse',
};

/// `BaseFieldsPayload.create()` yükü.
const Json _baseCreate = {
  'createdAt': serverTimestampMark,
  'updatedAt': serverTimestampMark,
  'isDeleted': false,
  'deletedAt': null,
  'deletedBy': null,
};

/// M1 / M2 — yeni üyelik belgesinin yükü (`null` alanların anahtarı yok).
Json _membershipCreate(String status) => {
  'clubId': _clubId,
  'userId': _uid,
  'status': status,
  'role': 'member',
  'applicant': _applicantJson,
  'priorCount': 0,
  'appliedAt': serverTimestampMark,
  ..._baseCreate,
};

/// M3 / M4 — var olan üyelik belgesinin güncelleme yükü.
Json _membershipReentry(String status, {required int priorCount}) => {
  'status': status,
  'role': 'member',
  'applicant': _applicantJson,
  'appliedAt': serverTimestampMark,
  'priorCount': priorCount,
  'retryAfter': null,
  'rejectReason': null,
  'rejectNote': null,
  'decidedAt': null,
  'decidedBy': null,
  'updatedAt': serverTimestampMark,
};

Json _membershipStatus(String status) => {
  'status': status,
  'updatedAt': serverTimestampMark,
};

Json _contactCreate(String note) => {
  'email': _email,
  'emailLower': _emailLower,
  'note': note,
  ..._baseCreate,
};

Json _contactNote(String note) => {
  'note': note,
  'updatedAt': serverTimestampMark,
};

/// `clubs.memberCount` ±1 yükü: yalnızca delta. Üyeliğin yolu herkese açık
/// kulüp belgesine yazılmaz (CD-137).
const Json _counter = {
  'memberCount': incrementMark,
  'updatedAt': serverTimestampMark,
};

Json _activity(String kind) => {
  'clubId': _clubId,
  'actorId': _uid,
  'kind': kind,
  'refs': {'userId': _uid},
  'createdAt': serverTimestampMark,
};

Map<String, Object?> _write(String op, String path, Json data) => {
  'op': op,
  'path': path,
  'data': data,
};

/// Günlük yazımı: kimlik sabittir — `{clubId}_{uid}_{kind}_{priorCount}`
/// ([priorCount] geçişten sonraki üyelik belgesinin değeri; CD-137).
Map<String, Object?> _activityWrite(String kind, int priorCount) => _write(
  'set',
  'activity/${_clubId}_${_uid}_${kind}_$priorCount',
  _activity(kind),
);

void main() {
  late FakeFirebaseFirestore db;
  late RecordingFirestoreService service;
  late FakeAppClock clock;
  late FakeNotificationDispatcher dispatcher;
  late MembershipRepository repository;

  MembershipRepository repositoryOn(FirestoreService firestore) =>
      FirebaseMembershipRepository(
        firestore,
        FirebaseActivityRepository(firestore),
        dispatcher,
        clock,
      );

  /// Her çağrısı [code] hatasıyla biten veritabanına bağlı repository.
  MembershipRepository failing(String code) => repositoryOn(
    FirebaseFirestoreService(StubFirestore(error: firestoreException(code))),
  );

  Future<Json?> read(String path) async => (await db.doc(path).get()).data();

  Future<List<Json>> activity() async => [
    for (final doc in (await db.collection('activity').get()).docs) doc.data(),
  ];

  /// Transaction'da kuyruğa giren yazımlar, sırayla.
  List<Map<String, Object?>> writes() => [
    for (final write in service.writes)
      _write(write.op, write.path, write.data),
  ];

  Future<void> seedClub({
    bool approvalRequired = true,
    bool applicationsOpen = true,
    bool requireNote = false,
    ClubStatus status = ClubStatus.active,
    bool isDeleted = false,
  }) => db
      .doc(_clubPath)
      .set(
        ClubModel(
          name: 'Yazılım Kulübü',
          nameLower: 'yazılım kulübü',
          categoryId: 'k01',
          iconName: 'code-xml',
          palette: ClubPalette.red,
          pattern: ClubPattern.dots,
          founded: 2015,
          presidentId: 'u_pres',
          memberCount: _memberCount,
          approvalRequired: approvalRequired,
          applicationsOpen: applicationsOpen,
          requireNote: requireNote,
          status: status,
          isDeleted: isDeleted,
        ).toJson(),
      );

  /// [status] durumunda bir üyelik belgesi kurar; `rejected` / `removed`
  /// belgesi karar alanlarını ve [_retryAfter] değerini taşır.
  Future<void> seedMembership(
    MembershipStatus status, {
    ClubRole role = ClubRole.member,
    int priorCount = 0,
    String clubId = _clubId,
    String userId = _uid,
    DateTime? appliedAt,
  }) {
    final decided =
        status == MembershipStatus.rejected ||
        status == MembershipStatus.removed;
    return db
        .doc('memberships/${clubId}_$userId')
        .set(
          MembershipModel(
            clubId: clubId,
            userId: userId,
            applicant: const MembershipApplicantModel(
              name: 'Eski Ad',
              avatarSeed: 'seed-eski',
              department: 'd09',
            ),
            status: status,
            role: role,
            priorCount: priorCount,
            appliedAt: appliedAt ?? _createdAt,
            decidedAt: decided ? _decidedAt : null,
            decidedBy: decided ? 'u_pres' : null,
            retryAfter: decided ? _retryAfter : null,
            rejectReason: decided ? RejectReason.other : null,
            rejectNote: decided ? 'gerekçe' : null,
            createdAt: _createdAt,
            updatedAt: _createdAt,
          ).toJson(),
        );
  }

  Future<void> seedContact({String note = 'eski not'}) => db
      .doc(_contactPath)
      .set(
        MembershipContactModel(
          email: _oldEmail,
          emailLower: _oldEmail,
          note: note,
          createdAt: _createdAt,
          updatedAt: _createdAt,
        ).toJson(),
      );

  Future<FirestoreResult<MembershipModel>> apply({
    String clubId = _clubId,
    UserModel applicant = _applicant,
    String email = _email,
    String note = '',
  }) => repository.apply(
    clubId: clubId,
    applicant: applicant,
    email: email,
    note: note,
  );

  Future<FirestoreResult<MembershipModel>> join({
    String clubId = _clubId,
    UserModel applicant = _applicant,
    String email = _email,
  }) => repository.joinInstant(
    clubId: clubId,
    applicant: applicant,
    email: email,
  );

  Future<FirestoreResult<void>> cancel() =>
      repository.cancelApplication(clubId: _clubId, userId: _uid);

  Future<FirestoreResult<void>> leave() =>
      repository.leave(clubId: _clubId, userId: _uid);

  Future<FirestoreResult<void>> editNote(String note) => repository
      .updateApplicationNote(clubId: _clubId, userId: _uid, note: note);

  /// [result] iş kuralı reddi mi ve `detail` [code] kodunu taşıyor mu?
  void expectViolation(
    FirestoreResult<Object?> result,
    FirestoreRuleCode code, {
    DateTime? retryAfter,
  }) {
    expect(result.errorOrNull, FirestoreError.ruleViolation);
    final detail = switch (result) {
      FirebaseFailure(:final detail) => detail,
      FirebaseSuccess() => null,
    };
    expect(detail, FirestoreFailureDetail(code, retryAfter: retryAfter));
  }

  /// Hiçbir belge yazılmadı, sayaç oynamadı, bildirim istenmedi.
  Future<void> expectNothingWritten() async {
    expect(service.writes, isEmpty);
    expect(service.outsideWrites, 0);
    expect(await activity(), isEmpty);
    expect(dispatcher.calls, isEmpty);
    final club = await read(_clubPath);
    if (club != null) {
      expect(club['memberCount'], _memberCount);
      expect(club, isNot(contains('lastMembershipRef')));
    }
  }

  setUp(() async {
    db = FakeFirebaseFirestore();
    service = RecordingFirestoreService(FirebaseFirestoreService(db));
    clock = FakeAppClock(_now);
    dispatcher = FakeNotificationDispatcher();
    repository = repositoryOn(service);
    // Başvuranın kullanıcı belgesi: anlık görüntü işlem içinde buradan okunur.
    await db.doc(_userPath).set(_applicant.toJson());
  });

  group('T-15 · MembershipRepository · sözleşme', () {
    test('PLAN §10.4 tablosunun T-15 ve T-16 üyeleri arayüzde aynı imzayla '
        'var; sonraki task üyeleri yok', () {
      final plan = readPlanRepositoryMembers('$MembershipRepository');
      final now = plan
          .where((row) => row.note == '(T-15)' || row.note == '(T-16)')
          .toList();
      // `reapply` ayrı bir üye değildir: `apply` ile aynı metottur.
      final reapply = now.singleWhere((row) => row.member == 'reapply');
      expect(reapply.signature, 'apply');
      final members = now.where((row) => row != reapply);

      expect(members.map((row) => row.member), [
        'watchMyMemberships',
        'getMembership',
        'apply',
        'joinInstant',
        'cancelApplication',
        'leave',
        'listActiveMembers',
        'updateApplicationNote',
        'listManagers',
        'listPending',
        'listMine',
        'readContact',
      ]);
      expect(interfaceMembers(_interface, '$MembershipRepository').toSet(), {
        for (final row in members) normalizeDartSource(row.signature),
      });
    });

    test('arayüzde ve uygulamada silme üyesi yok (D-10)', () {
      expect(deleteIdentifiersIn(_interface), isEmpty);
      expect(deleteIdentifiersIn(_implementation), isEmpty);
    });
  });

  group('T-15 · apply · M1 (belge yok → pending)', () {
    test('üyelik + private/contact + günlük tek transaction; not ve e-posta '
        'yalnızca contact belgesinde; sayaç oynamaz; yöneticilere bildirim '
        'istenir', () async {
      await seedClub();

      final result = await apply(note: 'Merhaba, katılmak istiyorum.');

      expect(writes(), [
        _write('set', _membershipPath, _membershipCreate('pending')),
        _write(
          'set',
          _contactPath,
          _contactCreate('Merhaba, katılmak istiyorum.'),
        ),
        _activityWrite('application_received', 0),
      ]);
      expect(service.transactions, 1);
      expect(service.outsideWrites, 0);
      // Belge yokken iletişim belgesi okunmaz.
      expect(service.reads, [_userPath, _clubPath, _membershipPath]);

      final membership = (await read(_membershipPath))!;
      expect(membership, isNot(contains('note')));
      expect(membership, isNot(contains('email')));
      final club = (await read(_clubPath))!;
      expect(club['memberCount'], _memberCount);
      expect(club, isNot(contains('lastMembershipRef')));
      expect(dispatcher.calls, const [
        DispatchCall(
          kind: 'notifyApplicationReceived',
          args: {'clubId': _clubId, 'applicantId': _uid, 'sequence': 0},
        ),
      ]);

      final model = result.dataOrNull!;
      expect(model.id, _membershipId);
      expect(model.status, MembershipStatus.pending);
      expect(model.role, ClubRole.member);
      expect(model.priorCount, 0);
      expect(model.applicant, MembershipApplicantModel.fromUser(_applicant));
      expect(model.appliedAt, _now);
    });

    test('anlık görüntü oturumdaki modelden değil güncel kullanıcı '
        'belgesinden kurulur (profil başka cihazda değişmiş)', () async {
      await seedClub();
      // Oturumdaki `_applicant` eski kaldı; belge yeni adı / bölümü taşıyor.
      await db
          .doc(_userPath)
          .set(
            _applicant
                .copyWith(
                  name: 'Ayşe Işık Demir',
                  nameLower: 'ayşe ışık demir',
                  avatarSeed: 'seed-yeni',
                  department: 'd05',
                  year: YearLevel.master,
                )
                .toJson(),
          );
      const fresh = {
        'name': 'Ayşe Işık Demir',
        'department': 'd05',
        'year': 'master',
        'avatarSeed': 'seed-yeni',
      };

      final result = await apply();

      expect((await read(_membershipPath))!['applicant'], fresh);
      expect(result.dataOrNull!.applicant.toJson(), fresh);
    });

    test('başvuranın kullanıcı belgesi ayrıştırılamıyorsa parse, yoksa '
        'notFound; hiçbir şey yazılmaz', () async {
      await seedClub();
      await db.doc(_userPath).set({'name': 5});
      expect((await apply()).errorOrNull, FirestoreError.parse);

      final other = _applicant.copyWith(uid: 'u_belgesiz');
      expect(
        (await apply(applicant: other)).errorOrNull,
        FirestoreError.notFound,
      );
      await expectNothingWritten();
    });

    test('bildirim hatası başvurunun sonucunu bozmaz', () async {
      await seedClub();
      dispatcher.failNextFanOut = FirestoreError.unavailable;

      final result = await apply();

      expect(result.isSuccess, isTrue);
      expect((await read(_membershipPath))!['status'], 'pending');
      expect(dispatcher.calls, hasLength(1));
    });

    test('kulüp not istiyorsa boş not reddedilir, dolu not geçer', () async {
      await seedClub(requireNote: true);

      for (final empty in ['', '   ']) {
        final rejected = await apply(note: empty);
        expect(rejected.errorOrNull, FirestoreError.invalidArgument);
      }
      await expectNothingWritten();

      expect((await apply(note: 'Not')).isSuccess, isTrue);
      expect((await read(_contactPath))!['note'], 'Not');
    });

    test(
      'sınırı aşan not ve izinsiz e-posta işlem açılmadan reddedilir',
      () async {
        await seedClub();

        final longNote = await apply(
          note: 'x' * (Limits.applicationNoteMax + 1),
        );
        final badEmail = await apply(email: 'ayse@hotmail.com');

        expect(longNote.errorOrNull, FirestoreError.invalidArgument);
        expect(badEmail.errorOrNull, FirestoreError.invalidArgument);
        expect(service.transactions, 0);
        await expectNothingWritten();
      },
    );
  });

  group('T-15 · joinInstant · M2 (belge yok → active)', () {
    test('üyelik + boş notlu contact + memberCount +1 + günlük tek '
        'transaction; bildirim istenmez', () async {
      await seedClub(approvalRequired: false);

      final result = await join();

      expect(writes(), [
        _write('set', _membershipPath, _membershipCreate('active')),
        _write('set', _contactPath, _contactCreate('')),
        _write('update', _clubPath, _counter),
        _activityWrite('member_joined', 0),
      ]);
      expect(service.transactions, 1);
      expect(service.outsideWrites, 0);

      final club = (await read(_clubPath))!;
      expect(club['memberCount'], _memberCount + 1);
      // Kulüp belgesi kimin katıldığını taşımaz (CD-137).
      expect(club, isNot(contains('lastMembershipRef')));
      expect(dispatcher.calls, isEmpty);
      expect(result.dataOrNull!.status, MembershipStatus.active);
      expect(result.dataOrNull!.isActiveMember, isTrue);
    });
  });

  group('T-15 · kulüp koşulu (apply ve joinInstant)', () {
    final enters =
        <String, Future<FirestoreResult<MembershipModel>> Function()>{
          'apply': () => apply(note: 'Not'),
          'joinInstant': join,
        };

    for (final MapEntry(key: name, value: enter) in enters.entries) {
      final instant = name == 'joinInstant';

      test('$name: kulüp yoksa ya da silinmişse notFound', () async {
        expect((await enter()).errorOrNull, FirestoreError.notFound);

        await seedClub(approvalRequired: !instant, isDeleted: true);
        expect((await enter()).errorOrNull, FirestoreError.notFound);
        await expectNothingWritten();
      });

      test('$name: askıdaki ya da başvuruya kapalı kulüpte '
          'applicationsClosed', () async {
        await seedClub(
          approvalRequired: !instant,
          status: ClubStatus.suspended,
        );
        expectViolation(await enter(), FirestoreRuleCode.applicationsClosed);

        await seedClub(approvalRequired: !instant, applicationsOpen: false);
        expectViolation(await enter(), FirestoreRuleCode.applicationsClosed);
        await expectNothingWritten();
      });

      test('$name: kulübün katılım biçimi çağrılan yolla uyuşmuyorsa '
          'conflict (belge yok / left)', () async {
        await seedClub(approvalRequired: instant);

        expect((await enter()).errorOrNull, FirestoreError.conflict);
        await seedMembership(MembershipStatus.left);
        expect((await enter()).errorOrNull, FirestoreError.conflict);
        await expectNothingWritten();
      });

      test('$name: ayrıştırılamayan kulüp belgesi parse', () async {
        await db.doc(_clubPath).set({'name': 5});

        expect((await enter()).errorOrNull, FirestoreError.parse);
        expect(service.writes, isEmpty);
      });

      test('$name: üyelik zaten pending / active ise conflict', () async {
        await seedClub(approvalRequired: !instant);

        for (final status in [
          MembershipStatus.pending,
          MembershipStatus.active,
        ]) {
          await seedMembership(status);
          expect((await enter()).errorOrNull, FirestoreError.conflict);
          expect((await read(_membershipPath))!['status'], status.json);
        }
        await expectNothingWritten();
      });
    }
  });

  group('T-15 · yeniden başvuru / katılma · M3 (left, cancelled)', () {
    for (final status in [MembershipStatus.left, MembershipStatus.cancelled]) {
      test('apply: ${status.json} → pending; priorCount +1, karar alanları '
          'null, createdAt korunur; contact belgesinde yalnızca not', () async {
        await seedClub();
        await seedMembership(status, priorCount: 2);
        await seedContact();

        final result = await apply(note: 'yeni not');

        expect(writes(), [
          _write(
            'update',
            _membershipPath,
            _membershipReentry('pending', priorCount: 3),
          ),
          _write('update', _contactPath, _contactNote('yeni not')),
          _activityWrite('application_received', 3),
        ]);
        expect(service.reads, [
          _userPath,
          _clubPath,
          _membershipPath,
          _contactPath,
        ]);
        expect(service.transactions, 1);

        final membership = (await read(_membershipPath))!;
        expect(membership['status'], 'pending');
        expect(membership['priorCount'], 3);
        expect(membership['applicant'], _applicantJson);
        expect(membership['createdAt'], Timestamp.fromDate(_createdAt));
        expect(membership, isNot(contains('note')));
        final contact = (await read(_contactPath))!;
        expect(contact['note'], 'yeni not');
        expect(contact['email'], _oldEmail);
        expect(contact['createdAt'], Timestamp.fromDate(_createdAt));
        expect(result.dataOrNull!.priorCount, 3);
        expect(result.dataOrNull!.createdAt, _createdAt);
        expect(dispatcher.calls.single.kind, 'notifyApplicationReceived');
      });
    }

    test('joinInstant: left → active; memberCount +1, contact notu '
        'boşalır', () async {
      await seedClub(approvalRequired: false);
      await seedMembership(MembershipStatus.left, priorCount: 1);
      await seedContact();

      final result = await join();

      expect(writes(), [
        _write(
          'update',
          _membershipPath,
          _membershipReentry('active', priorCount: 2),
        ),
        _write('update', _contactPath, _contactNote('')),
        _write('update', _clubPath, _counter),
        _activityWrite('member_joined', 2),
      ]);
      expect((await read(_clubPath))!['memberCount'], _memberCount + 1);
      expect((await read(_contactPath))!['email'], _oldEmail);
      expect(result.dataOrNull!.status, MembershipStatus.active);
      expect(dispatcher.calls, isEmpty);
    });

    // Onay dolanması (CD-137): çıkarılan / reddedilen → başvur (M4) → iptal
    // (M7) → anında katıl zinciri yönetici kararı olmadan üye yapardı.
    for (final approvalRequired in [false, true]) {
      test('joinInstant: cancelled → reapplyNeedsReview '
          '(approvalRequired: $approvalRequired); hiçbir şey '
          'yazılmaz', () async {
        await seedClub(approvalRequired: approvalRequired);
        await seedMembership(MembershipStatus.cancelled, priorCount: 1);

        expectViolation(await join(), FirestoreRuleCode.reapplyNeedsReview);
        expect((await read(_membershipPath))!['status'], 'cancelled');
        await expectNothingWritten();
      });
    }

    test('apply: onaysız kulüpte de cancelled → pending (yönetici onayına '
        'gider); sayaç oynamaz', () async {
      await seedClub(approvalRequired: false);
      await seedMembership(MembershipStatus.cancelled, priorCount: 1);

      final result = await apply();

      expect(result.dataOrNull!.status, MembershipStatus.pending);
      expect((await read(_membershipPath))!['priorCount'], 2);
      expect((await read(_clubPath))!['memberCount'], _memberCount);
    });

    test('iletişim belgesi olmayan üyelikte (yönetici eliyle açılmış) '
        'contact tam yazılır', () async {
      await seedClub();
      await seedMembership(MembershipStatus.left);

      await apply(note: 'ilk not');

      expect(
        writes()[1],
        _write('set', _contactPath, _contactCreate('ilk not')),
      );
    });
  });

  group('T-15 · tekrar başvuru · M4 (rejected, removed) + bekleme süresi', () {
    for (final status in [
      MembershipStatus.rejected,
      MembershipStatus.removed,
    ]) {
      test('apply: ${status.json} — 6 gün 23 saat sonra retryCooldown '
          '(+ detail.retryAfter), 7. günde pending', () async {
        await seedClub();
        await seedMembership(status);
        await seedContact();

        clock.set(_decidedAt.add(const Duration(days: 6, hours: 23)));
        expectViolation(
          await apply(note: 'tekrar'),
          FirestoreRuleCode.retryCooldown,
          retryAfter: _retryAfter,
        );
        expect((await read(_membershipPath))!['status'], status.json);
        await expectNothingWritten();

        clock.set(_decidedAt.add(Limits.reapplyCooldown));
        final result = await apply(note: 'tekrar');

        expect(result.dataOrNull!.status, MembershipStatus.pending);
        expect(writes(), [
          _write(
            'update',
            _membershipPath,
            _membershipReentry('pending', priorCount: 1),
          ),
          _write('update', _contactPath, _contactNote('tekrar')),
          _activityWrite('application_received', 1),
        ]);
        final membership = (await read(_membershipPath))!;
        for (final cleared in [
          'retryAfter',
          'rejectReason',
          'rejectNote',
          'decidedAt',
          'decidedBy',
        ]) {
          expect(membership[cleared], isNull, reason: cleared);
        }
      });

      test('joinInstant: ${status.json} — süre dolmadan retryCooldown, '
          'dolunca reapplyNeedsReview; hiçbir şey yazılmaz', () async {
        await seedClub(approvalRequired: false);
        await seedMembership(status);

        clock.set(_retryAfter.subtract(const Duration(seconds: 1)));
        expectViolation(
          await join(),
          FirestoreRuleCode.retryCooldown,
          retryAfter: _retryAfter,
        );

        clock.set(_retryAfter);
        expectViolation(await join(), FirestoreRuleCode.reapplyNeedsReview);
        expect((await read(_membershipPath))!['status'], status.json);
        await expectNothingWritten();
      });
    }

    test('onaysız kulüpte de M4 hedefi pending; sayaç oynamaz', () async {
      await seedClub(approvalRequired: false);
      await seedMembership(MembershipStatus.removed);
      clock.set(_retryAfter);

      final result = await apply();

      expect(result.dataOrNull!.status, MembershipStatus.pending);
      expect((await read(_membershipPath))!['status'], 'pending');
      expect((await read(_clubPath))!['memberCount'], _memberCount);
    });
  });

  group('T-15 · cancelApplication · M7 (pending → cancelled)', () {
    test('yalnızca durum ve updatedAt yazılır; sayaç, günlük ve bildirim '
        'yok', () async {
      await seedClub();
      await seedMembership(MembershipStatus.pending);

      final result = await cancel();

      expect(result.isSuccess, isTrue);
      expect(writes(), [
        _write('update', _membershipPath, _membershipStatus('cancelled')),
      ]);
      expect(service.transactions, 1);
      expect(service.outsideWrites, 0);
      expect((await read(_membershipPath))!['status'], 'cancelled');
      expect(await activity(), isEmpty);
      expect((await read(_clubPath))!['memberCount'], _memberCount);
      expect(dispatcher.calls, isEmpty);
    });

    test('pending olmayan (ya da olmayan) başvuru conflict', () async {
      await seedClub();

      expect((await cancel()).errorOrNull, FirestoreError.conflict);
      for (final status in MembershipStatus.values) {
        if (status == MembershipStatus.pending) continue;
        await seedMembership(status);
        expect(
          (await cancel()).errorOrNull,
          FirestoreError.conflict,
          reason: status.json,
        );
        expect((await read(_membershipPath))!['status'], status.json);
      }
      await expectNothingWritten();
    });
  });

  group('T-16 · updateApplicationNote · bekleyen başvurunun notu', () {
    test('yalnızca private/contact.note + updatedAt yazılır; üyelik, sayaç, '
        'günlük ve bildirim yok', () async {
      await seedClub();
      await seedMembership(MembershipStatus.pending);
      await seedContact();

      final result = await editNote('Güncel not.');

      expect(result.isSuccess, isTrue);
      expect(writes(), [
        _write('update', _contactPath, _contactNote('Güncel not.')),
      ]);
      expect(service.transactions, 1);
      expect(service.outsideWrites, 0);
      final contact = (await read(_contactPath))!;
      expect(contact['note'], 'Güncel not.');
      // E-posta yeniden yazılmaz.
      expect(contact['email'], _oldEmail);
      expect(contact['emailLower'], _oldEmail);
      expect((await read(_membershipPath))!['status'], 'pending');
      expect(await activity(), isEmpty);
      expect((await read(_clubPath))!['memberCount'], _memberCount);
      expect(dispatcher.calls, isEmpty);
    });

    test('pending olmayan (ya da olmayan) başvuruda conflict; not '
        'değişmez', () async {
      await seedClub();
      await seedContact();

      expect(
        (await editNote('Güncel not.')).errorOrNull,
        FirestoreError.conflict,
      );
      for (final status in MembershipStatus.values) {
        if (status == MembershipStatus.pending) continue;
        await seedMembership(status);
        expect(
          (await editNote('Güncel not.')).errorOrNull,
          FirestoreError.conflict,
          reason: status.json,
        );
      }
      expect((await read(_contactPath))!['note'], 'eski not');
      await expectNothingWritten();
    });

    test('not zorunlu kulüpte boş not invalidArgument; dolu not geçer; not '
        'istemeyen kulüpte not boşaltılabilir', () async {
      await seedClub(requireNote: true);
      await seedMembership(MembershipStatus.pending);
      await seedContact();

      // Yalnızca boşluk da "boş" sayılır (Rules `noteGiven` kırpılmış metni
      // ölçer — CD-138 madde 3).
      for (final empty in ['', ' ', '\n\n']) {
        expect(
          (await editNote(empty)).errorOrNull,
          FirestoreError.invalidArgument,
        );
      }
      expect(service.writes, isEmpty);
      expect((await editNote('Yeni not.')).isSuccess, isTrue);

      await seedClub();
      expect((await editNote('')).isSuccess, isTrue);
      expect((await read(_contactPath))!['note'], '');
    });

    test('üst sınır: applicationNoteMax geçer, +1 işlem açılmadan '
        'invalidArgument', () async {
      await seedClub();
      await seedMembership(MembershipStatus.pending);
      await seedContact();

      final atLimit = 'a' * Limits.applicationNoteMax;
      expect((await editNote(atLimit)).isSuccess, isTrue);
      expect(service.transactions, 1);

      expect(
        (await editNote('${atLimit}a')).errorOrNull,
        FirestoreError.invalidArgument,
      );
      expect(service.transactions, 1);
      expect((await read(_contactPath))!['note'], atLimit);
    });

    test('kulüp belgesi yok ya da kulüp silinmiş → notFound; askıdaki ve '
        'başvuruya kapalı kulüpte not düzenlenir', () async {
      await seedMembership(MembershipStatus.pending);
      await seedContact();

      expect((await editNote('x')).errorOrNull, FirestoreError.notFound);
      await seedClub(isDeleted: true);
      expect((await editNote('x')).errorOrNull, FirestoreError.notFound);
      expect(service.writes, isEmpty);

      await seedClub(status: ClubStatus.suspended, applicationsOpen: false);
      expect((await editNote('Güncel not.')).isSuccess, isTrue);
      expect((await read(_contactPath))!['note'], 'Güncel not.');
    });
  });

  group('T-15 · leave · M8 (active → left)', () {
    for (final role in [ClubRole.member, ClubRole.board]) {
      test(
        '${role.json}: durum + memberCount −1 + günlük tek transaction',
        () async {
          await seedClub();
          await seedMembership(
            MembershipStatus.active,
            role: role,
            priorCount: 3,
          );

          final result = await leave();

          expect(result.isSuccess, isTrue);
          expect(writes(), [
            _write('update', _membershipPath, _membershipStatus('left')),
            _write('update', _clubPath, _counter),
            // Ayrılma `priorCount`'u değiştirmez: kimlik mevcut değeri taşır.
            _activityWrite('member_left', 3),
          ]);
          expect(service.transactions, 1);
          expect(service.outsideWrites, 0);
          final club = (await read(_clubPath))!;
          expect(club['memberCount'], _memberCount - 1);
          // Kulüp belgesi kimin ayrıldığını taşımaz (CD-137).
          expect(club, isNot(contains('lastMembershipRef')));
          expect((await read(_membershipPath))!['status'], 'left');
          expect(dispatcher.calls, isEmpty);
        },
      );
    }

    test('askıdaki kulüpten de ayrılınır', () async {
      await seedClub(status: ClubStatus.suspended);
      await seedMembership(MembershipStatus.active);

      expect((await leave()).isSuccess, isTrue);
      expect((await read(_clubPath))!['memberCount'], _memberCount - 1);
    });

    test('başkan ayrılamaz (presidentCannotLeave), danışman üye sayılmaz '
        '(notMember)', () async {
      await seedClub();

      await seedMembership(MembershipStatus.active, role: ClubRole.president);
      expectViolation(await leave(), FirestoreRuleCode.presidentCannotLeave);

      await seedMembership(MembershipStatus.active, role: ClubRole.advisor);
      expectViolation(await leave(), FirestoreRuleCode.notMember);

      expect((await read(_membershipPath))!['status'], 'active');
      await expectNothingWritten();
    });

    test('active olmayan (ya da olmayan) üyelik conflict', () async {
      await seedClub();

      expect((await leave()).errorOrNull, FirestoreError.conflict);
      for (final status in MembershipStatus.values) {
        if (status == MembershipStatus.active) continue;
        await seedMembership(status);
        expect(
          (await leave()).errorOrNull,
          FirestoreError.conflict,
          reason: status.json,
        );
      }
      await expectNothingWritten();
    });
  });

  group('T-15 · okumalar', () {
    test('getMembership: belge → model, belge yok → null', () async {
      await seedMembership(MembershipStatus.rejected, priorCount: 1);

      final found = await repository.getMembership(_clubId, _uid);
      final missing = await repository.getMembership('c09', _uid);

      expect(found.dataOrNull!.id, _membershipId);
      expect(found.dataOrNull!.status, MembershipStatus.rejected);
      expect(found.dataOrNull!.retryAfter, _retryAfter);
      expect(missing.isSuccess, isTrue);
      expect(missing.dataOrNull, isNull);
    });

    test('readContact: e-posta ve başvuru notu; belge yok → null', () async {
      await seedContact(note: 'başvuru notu');

      final found = await repository.readContact(_clubId, _uid);
      final missing = await repository.readContact('c09', _uid);

      expect(found.dataOrNull!.email, _oldEmail);
      expect(found.dataOrNull!.note, 'başvuru notu');
      expect(missing.isSuccess, isTrue);
      expect(missing.dataOrNull, isNull);
    });

    test('watchMyMemberships: kullanıcının her durumdaki üyelikleri canlı '
        'gelir; başkasınınki gelmez', () async {
      await seedMembership(MembershipStatus.active);
      await seedMembership(MembershipStatus.left, clubId: 'c02');
      await seedMembership(MembershipStatus.active, userId: 'u_mehmet');
      final events = <FirestoreResult<List<MembershipModel>>>[];
      final subscription = repository
          .watchMyMemberships(_uid)
          .listen(events.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      await seedMembership(MembershipStatus.pending, clubId: 'c03');
      await pumpEventQueue();

      expect(
        {for (final item in events.first.dataOrNull!) item.clubId: item.status},
        {'c01': MembershipStatus.active, 'c02': MembershipStatus.left},
      );
      expect(
        {for (final item in events.last.dataOrNull!) item.clubId},
        {'c01', 'c02', 'c03'},
      );
    });

    test(
      'listMine: tüm durumlar; durum süzgeci; boş küme sorgusuz boş',
      () async {
        await seedMembership(MembershipStatus.active);
        await seedMembership(MembershipStatus.pending, clubId: 'c02');
        await seedMembership(MembershipStatus.left, clubId: 'c03');
        await seedMembership(MembershipStatus.active, userId: 'u_mehmet');

        final all = await repository.listMine(_uid);
        final open = await repository.listMine(
          _uid,
          statuses: {MembershipStatus.active, MembershipStatus.pending},
        );
        final none = await failing('permission-denied').listMine(
          _uid,
          statuses: const {},
        );

        expect(
          {for (final item in all.dataOrNull!) item.clubId},
          {
            'c01',
            'c02',
            'c03',
          },
        );
        expect(
          {for (final item in open.dataOrNull!) item.clubId},
          {'c01', 'c02'},
        );
        expect(none.dataOrNull, isEmpty);
      },
    );

    test('listActiveMembers: yalnızca bu kulübün aktif üyeleri, en yeni '
        'üstte, sayfalı; rol süzgeci', () async {
      Future<void> member(
        String userId,
        int day, {
        MembershipStatus status = MembershipStatus.active,
        ClubRole role = ClubRole.member,
        String clubId = _clubId,
      }) => seedMembership(
        status,
        role: role,
        clubId: clubId,
        userId: userId,
        appliedAt: DateTime.utc(2026, 9, day),
      );
      await member('u1', 1);
      await member('u2', 2, role: ClubRole.board);
      await member('u3', 3);
      await member('u4', 4, status: MembershipStatus.pending);
      await member('u5', 5, status: MembershipStatus.left);
      await member('u6', 6, clubId: 'c02');

      final first = await repository.listActiveMembers(
        _clubId,
        const PageRequest(limit: 2),
      );
      final second = await repository.listActiveMembers(
        _clubId,
        PageRequest(limit: 2, after: first.dataOrNull!.next),
      );
      final board = await repository.listActiveMembers(
        _clubId,
        const PageRequest(),
        role: ClubRole.board,
      );

      expect(
        [for (final item in first.dataOrNull!.items) item.userId],
        [
          'u3',
          'u2',
        ],
      );
      expect(first.dataOrNull!.hasMore, isTrue);
      expect(
        [for (final item in second.dataOrNull!.items) item.userId],
        ['u1'],
      );
      expect(second.dataOrNull!.hasMore, isFalse);
      expect([for (final item in board.dataOrNull!.items) item.userId], ['u2']);
    });

    test('listPending: yalnızca bekleyen başvurular, en yeni üstte', () async {
      await seedMembership(
        MembershipStatus.pending,
        userId: 'u1',
        appliedAt: DateTime.utc(2026, 9),
      );
      await seedMembership(
        MembershipStatus.pending,
        userId: 'u2',
        appliedAt: DateTime.utc(2026, 9, 2),
      );
      await seedMembership(MembershipStatus.active, userId: 'u3');
      await seedMembership(
        MembershipStatus.pending,
        clubId: 'c02',
        userId: 'u4',
      );

      final page = await repository.listPending(_clubId, const PageRequest());

      expect(
        [for (final item in page.dataOrNull!.items) item.userId],
        [
          'u2',
          'u1',
        ],
      );
      expect(page.dataOrNull!.hasMore, isFalse);
    });

    test('listManagers: aktif board ve president; üye, danışman ve '
        'ayrılmış yönetici gelmez', () async {
      await seedMembership(
        MembershipStatus.active,
        role: ClubRole.president,
        userId: 'u1',
      );
      await seedMembership(
        MembershipStatus.active,
        role: ClubRole.board,
        userId: 'u2',
      );
      await seedMembership(MembershipStatus.active, userId: 'u3');
      await seedMembership(
        MembershipStatus.active,
        role: ClubRole.advisor,
        userId: 'u4',
      );
      await seedMembership(
        MembershipStatus.left,
        role: ClubRole.board,
        userId: 'u5',
      );
      await seedMembership(
        MembershipStatus.active,
        role: ClubRole.board,
        clubId: 'c02',
        userId: 'u6',
      );

      final managers = await repository.listManagers(_clubId);

      expect(
        {for (final item in managers.dataOrNull!) item.userId},
        {
          'u1',
          'u2',
        },
      );
    });
  });

  group('T-15 · geçersiz kimlik, ayrıştırma ve hata eşlemesi', () {
    test('geçersiz kimlik invalidArgument döner, hiçbir çağrı yapılmaz '
        '(W-54)', () async {
      for (final id in _invalidIds) {
        final results = <FirestoreResult<Object?>>[
          await repository.getMembership(id, _uid),
          await repository.getMembership(_clubId, id),
          await apply(clubId: id),
          await apply(applicant: _applicant.copyWith(uid: id)),
          await join(clubId: id),
          await repository.cancelApplication(clubId: id, userId: _uid),
          await repository.cancelApplication(clubId: _clubId, userId: id),
          await repository.leave(clubId: id, userId: _uid),
          await repository.leave(clubId: _clubId, userId: id),
          await repository.updateApplicationNote(
            clubId: id,
            userId: _uid,
            note: '',
          ),
          await repository.updateApplicationNote(
            clubId: _clubId,
            userId: id,
            note: '',
          ),
          await repository.listActiveMembers(id, const PageRequest()),
          await repository.listManagers(id),
          await repository.listPending(id, const PageRequest()),
          await repository.listMine(id),
          await repository.readContact(id, _uid),
          await repository.readContact(_clubId, id),
          await repository.watchMyMemberships(id).single,
        ];
        for (final result in results) {
          expect(
            result.errorOrNull,
            FirestoreError.invalidArgument,
            reason: 'kimlik "$id"',
          );
        }
      }
      expect(service.transactions, 0);
      await expectNothingWritten();
    });

    test('ayrıştırılamayan üyelik belgesi parse (okuma ve geçiş)', () async {
      await seedClub();
      await db.doc(_membershipPath).set({
        'clubId': _clubId,
        'userId': _uid,
        'status': 'bilinmeyen',
        'applicant': _applicantJson,
      });

      final results = <FirestoreResult<Object?>>[
        await repository.getMembership(_clubId, _uid),
        await repository.listMine(_uid),
        await repository.watchMyMemberships(_uid).first,
        await apply(),
        await cancel(),
        await leave(),
        await editNote('Not.'),
      ];

      for (final result in results) {
        expect(result.errorOrNull, FirestoreError.parse);
      }
      expect(service.writes, isEmpty);
    });

    test('SDK hatası sözlüğe çevrilir; transaction hatasında bildirim '
        'istenmez', () async {
      final denied = failing('permission-denied');

      final results = <FirestoreResult<Object?>>[
        await denied.getMembership(_clubId, _uid),
        await denied.readContact(_clubId, _uid),
        await denied.listManagers(_clubId),
        await denied.listMine(_uid),
        await denied.apply(
          clubId: _clubId,
          applicant: _applicant,
          email: _email,
          note: '',
        ),
        await denied.joinInstant(
          clubId: _clubId,
          applicant: _applicant,
          email: _email,
        ),
        await denied.cancelApplication(clubId: _clubId, userId: _uid),
        await denied.leave(clubId: _clubId, userId: _uid),
        await denied.updateApplicationNote(
          clubId: _clubId,
          userId: _uid,
          note: 'Not.',
        ),
      ];

      for (final result in results) {
        expect(result.errorOrNull, FirestoreError.permissionDenied);
      }
      expect(dispatcher.calls, isEmpty);
    });
  });
}

// T-30 · MembershipRepository (yönetici geçişleri): üyelik durum makinesinin
// yönetici satırları — onay (M5), ret (M6), çıkarma (M9), rol (M10), devir
// (M11), kararı / çıkarmayı geri al (M12 a / b) — geçerli ve reddedilen
// kaynak durumları, çakışma; hiyerarşi (başkan > yönetim kurulu > üye;
// danışman hiçbir yönetici yazımı yapamaz — Q-09); 30 sn geri al penceresi;
// devrin tek transaction'ı; `memberCount` ±1 ve sayaç işaretçisi yan belgesi
// (`clubs/{c}/private/counter`, W-64) aynı işlemde; günlük kaydı (sabit
// kimlik, varsa yeniden yazılmaz); silinmiş başvuran / devir hedefi (W-89);
// kritik bildirimin aynı transaction'da ve yükü (sözleşme
// `docs/plans/T-30.md` §4 a–e; PLAN §10.4; domain-model §5; rules-spec §3.4).
//
// Mutlu yollar `fake_cloud_firestore` ile (Q-06); yazım kümesi kayıt tutan
// servis çiftiyle (`test/fakes/recording_firestore_service.dart`), hata
// eşlemesi el yazımı SDK çiftiyle (`test/fakes/sdk_firestore_stubs.dart`).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../fakes/fake_app_clock.dart';
import '../fakes/fake_notification_dispatcher.dart';
import '../fakes/recording_firestore_service.dart';
import '../fakes/sdk_firestore_stubs.dart';

const String _clubId = 'c01';
const String _target = 'u_ayse';
const String _president = 'u_president';
const String _board = 'u_board';
const String _super = 'u_super';

const String _clubPath = 'clubs/c01';
const String _counterPath = 'clubs/c01/private/counter';
const String _targetPath = 'memberships/c01_u_ayse';
const String _presidentPath = 'memberships/c01_u_president';
const String _targetUserPath = 'users/u_ayse';
const int _memberCount = 12;

final DateTime _now = DateTime.utc(2026, 10, 14, 9);
final DateTime _createdAt = DateTime.utc(2026, 3, 2, 8);

/// `retryAfter` = şimdi + 7 gün (istemci `Timestamp`'i).
final Timestamp _retryAfter = Timestamp.fromDate(
  _now.add(Limits.reapplyCooldown),
);

/// `clubs.memberCount` ±1 yükü: yalnızca delta (işaretçi kulüpte yok).
const Json _counter = {
  'memberCount': incrementMark,
  'updatedAt': serverTimestampMark,
};

/// Karar alanlarının boşaltılması (M12 a / b).
const Json _cleared = {
  'decidedAt': null,
  'decidedBy': null,
  'retryAfter': null,
  'rejectReason': null,
  'rejectNote': null,
  'updatedAt': serverTimestampMark,
};

Map<String, Object?> _write(String op, String path, Json data) => {
  'op': op,
  'path': path,
  'data': data,
};

/// Yönetici aktörlü sayaç geçişi: kulübe delta + yan belgeye işaretçi.
List<Map<String, Object?>> _counted(String userId) => [
  _write('update', _clubPath, _counter),
  _write('set', _counterPath, {
    'clubId': _clubId,
    'lastMembershipRef': 'memberships/${_clubId}_$userId',
    'updatedAt': serverTimestampMark,
  }),
];

Map<String, Object?> _activityWrite(
  String id, {
  required String actor,
  required String kind,
  required Json refs,
}) => _write('set', 'activity/$id', {
  'clubId': _clubId,
  'actorId': actor,
  'kind': kind,
  'refs': refs,
  'createdAt': serverTimestampMark,
});

UserModel _user(String uid, {UserStatus status = UserStatus.active}) =>
    UserModel(
      uid: uid,
      name: 'Kullanıcı $uid',
      nameLower: 'kullanıcı $uid',
      avatarSeed: 'seed-$uid',
      department: 'd02',
      year: YearLevel.second,
      interests: const ['i01'],
      profileComplete: true,
      status: status,
    );

/// Bildirim yazmayan, alıcı çözmeyen çözücü (kritik üyeler çağırmaz).
final class _NoResolver extends Fake implements RecipientResolver {}

void main() {
  late FakeFirebaseFirestore db;
  late RecordingFirestoreService service;
  late FakeAppClock clock;
  late FakeNotificationDispatcher dispatcher;
  late MembershipRepository repository;

  MembershipRepository repositoryOn(
    FirestoreService firestore, {
    NotificationDispatcher? notifications,
  }) => FirebaseMembershipRepository(
    firestore,
    FirebaseActivityRepository(firestore),
    notifications ?? dispatcher,
    clock,
  );

  Future<Json?> read(String path) async => (await db.doc(path).get()).data();

  Future<List<String>> activityIds() async => [
    for (final doc in (await db.collection('activity').get()).docs) doc.id,
  ];

  List<Map<String, Object?>> writes() => [
    for (final write in service.writes)
      _write(write.op, write.path, write.data),
  ];

  Future<void> seedMembership(
    String userId,
    MembershipStatus status, {
    ClubRole role = ClubRole.member,
    int priorCount = 0,
    String? decidedBy,
    DateTime? decidedAt,
    String clubIdField = _clubId,
    String? userIdField,
  }) => db
      .doc('memberships/${_clubId}_$userId')
      .set(
        MembershipModel(
          clubId: clubIdField,
          userId: userIdField ?? userId,
          applicant: const MembershipApplicantModel(
            name: 'Ad',
            avatarSeed: 'seed',
            department: 'd02',
          ),
          status: status,
          role: role,
          priorCount: priorCount,
          appliedAt: _createdAt,
          decidedAt: decidedAt,
          decidedBy: decidedBy,
          retryAfter:
              status == MembershipStatus.rejected ||
                  status == MembershipStatus.removed
              ? _retryAfter.toDate()
              : null,
          rejectReason:
              status == MembershipStatus.rejected ||
                  status == MembershipStatus.removed
              ? RejectReason.other
              : null,
          rejectNote:
              status == MembershipStatus.rejected ||
                  status == MembershipStatus.removed
              ? 'gerekçe'
              : null,
          createdAt: _createdAt,
          updatedAt: _createdAt,
        ).toJson(),
      );

  Future<void> seedUser(String uid, {UserStatus status = UserStatus.active}) =>
      db.doc('users/$uid').set(_user(uid, status: status).toJson());

  Future<void> reset() async {
    db = FakeFirebaseFirestore();
    service = RecordingFirestoreService(FirebaseFirestoreService(db));
    clock = FakeAppClock(_now);
    dispatcher = FakeNotificationDispatcher();
    repository = repositoryOn(service);
    await db
        .doc(_clubPath)
        .set(
          const ClubModel(
            name: 'Yazılım Kulübü',
            nameLower: 'yazılım kulübü',
            categoryId: 'k01',
            iconName: 'code-xml',
            palette: ClubPalette.red,
            pattern: ClubPattern.dots,
            founded: 2015,
            presidentId: _president,
            memberCount: _memberCount,
          ).toJson(),
        );
    await seedUser(_target);
    await seedUser(_president);
    await seedMembership(
      _president,
      MembershipStatus.active,
      role: ClubRole.president,
      priorCount: 2,
    );
  }

  /// [result] iş kuralı reddi mi ve `detail` [code] kodunu taşıyor mu?
  void expectViolation(
    FirestoreResult<Object?> result,
    FirestoreRuleCode code,
  ) {
    expect(result.errorOrNull, FirestoreError.ruleViolation);
    final detail = switch (result) {
      FirebaseFailure(:final detail) => detail,
      FirebaseSuccess() => null,
    };
    expect(detail, FirestoreFailureDetail(code));
  }

  /// Hiçbir belge yazılmadı, sayaç ve yan belge oynamadı, bildirim yok.
  Future<void> expectNothingWritten() async {
    expect(service.writes, isEmpty);
    expect(service.outsideWrites, 0);
    expect(dispatcher.calls, isEmpty);
    expect(await activityIds(), isEmpty);
    expect((await read(_clubPath))!['memberCount'], _memberCount);
    expect(await read(_counterPath), isNull);
  }

  setUp(reset);

  group('T-30 · approve · M5 (pending → active)', () {
    test('üyelik + memberCount +1 + yan belge işaretçisi + günlük + bildirim '
        "tek transaction'da; kulüp belgesine yol yazılmaz", () async {
      await seedMembership(_target, MembershipStatus.pending, priorCount: 1);

      final result = await repository.approve(
        clubId: _clubId,
        userId: _target,
        actorId: _board,
      );

      expect(result.isSuccess, isTrue);
      const activityId = 'c01_u_board_application_approved_u_ayse_1';
      expect(writes(), [
        _write('update', _targetPath, {
          'status': 'active',
          'role': 'member',
          'decidedAt': serverTimestampMark,
          'decidedBy': _board,
          'updatedAt': serverTimestampMark,
        }),
        ..._counted(_target),
        _activityWrite(
          activityId,
          actor: _board,
          kind: 'application_approved',
          refs: {'userId': _target},
        ),
      ]);
      expect(service.reads, [
        _targetPath,
        _targetUserPath,
        'activity/$activityId',
      ]);
      expect(service.transactions, 1);
      expect(service.outsideWrites, 0);
      expect(dispatcher.calls, const [
        DispatchCall(
          kind: 'notifyApplicationDecidedInTransaction',
          args: {'clubId': _clubId, 'applicantId': _target, 'approved': true},
          recipients: [_target],
        ),
      ]);
      expect(dispatcher.transactions, hasLength(1));
      final club = (await read(_clubPath))!;
      expect(club['memberCount'], _memberCount + 1);
      expect(club, isNot(contains('lastMembershipRef')));
      expect((await read(_targetPath))!['status'], 'active');
    });

    test('kaynak pending değilse (yok, active, rejected, removed, left, '
        'cancelled) conflict; hiçbir şey yazılmaz', () async {
      final sources = [null, ...MembershipStatus.values]
        ..remove(MembershipStatus.pending);
      for (final status in sources) {
        await reset();
        if (status != null) await seedMembership(_target, status);
        final result = await repository.approve(
          clubId: _clubId,
          userId: _target,
          actorId: _board,
        );
        expect(result.errorOrNull, FirestoreError.conflict, reason: '$status');
        await expectNothingWritten();
      }
    });

    test('W-89: başvuranın hesabı silinmiş ya da kullanıcı belgesi yoksa '
        'onay ve ret conflict; askıdaki hesap onaylanır', () async {
      await seedMembership(_target, MembershipStatus.pending);
      await seedUser(_target, status: UserStatus.deleted);
      final approved = await repository.approve(
        clubId: _clubId,
        userId: _target,
        actorId: _board,
      );
      final rejected = await repository.reject(
        clubId: _clubId,
        userId: _target,
        actorId: _board,
        reason: RejectReason.quota,
      );
      expect(approved.errorOrNull, FirestoreError.conflict);
      expect(rejected.errorOrNull, FirestoreError.conflict);

      await seedMembership('u_belgesiz', MembershipStatus.pending);
      final missing = await repository.approve(
        clubId: _clubId,
        userId: 'u_belgesiz',
        actorId: _board,
      );
      expect(missing.errorOrNull, FirestoreError.conflict);
      await expectNothingWritten();

      await seedUser(_target, status: UserStatus.suspended);
      final suspended = await repository.approve(
        clubId: _clubId,
        userId: _target,
        actorId: _board,
      );
      expect(suspended.isSuccess, isTrue);
    });

    test('aktör başvuranın kendisiyse permissionDenied, geçersiz kimlik '
        'invalidArgument — transaction açılmaz', () async {
      await seedMembership(_target, MembershipStatus.pending);

      final self = await repository.approve(
        clubId: _clubId,
        userId: _target,
        actorId: _target,
      );
      final invalid = [
        for (final (club, user, actor) in [
          ('c/1', _target, _board),
          (_clubId, '..', _board),
          (_clubId, _target, ''),
        ])
          await repository.approve(clubId: club, userId: user, actorId: actor),
      ];

      expect(self.errorOrNull, FirestoreError.permissionDenied);
      expect(
        invalid.map((r) => r.errorOrNull),
        everyElement(FirestoreError.invalidArgument),
      );
      expect(service.transactions, 0);
      await expectNothingWritten();
    });

    test('bileşik kimlik birleşimi: belgenin alanları başka üyeliği '
        'gösteriyorsa permissionDenied', () async {
      // `memberships/c01_u_ayse` = kulüp `c01_u` + kullanıcı `ayse` belgesi.
      await seedMembership(
        _target,
        MembershipStatus.pending,
        clubIdField: 'c01_u',
        userIdField: 'ayse',
      );

      final result = await repository.approve(
        clubId: _clubId,
        userId: _target,
        actorId: _board,
      );

      expect(result.errorOrNull, FirestoreError.permissionDenied);
      await expectNothingWritten();
    });
  });

  group('T-30 · reject · M6 (pending → rejected)', () {
    test('karar alanları + retryAfter (şimdi + 7 g) + günlük + bildirim; '
        'sayaç ve yan belge yok', () async {
      await seedMembership(_target, MembershipStatus.pending);

      final result = await repository.reject(
        clubId: _clubId,
        userId: _target,
        actorId: _president,
        reason: RejectReason.criteria,
        rejectNote: 'Koşullar sağlanmadı',
      );

      expect(result.isSuccess, isTrue);
      expect(writes(), [
        _write('update', _targetPath, {
          'status': 'rejected',
          'rejectReason': 'criteria',
          'rejectNote': 'Koşullar sağlanmadı',
          'retryAfter': _retryAfter,
          'decidedAt': serverTimestampMark,
          'decidedBy': _president,
          'updatedAt': serverTimestampMark,
        }),
        _activityWrite(
          'c01_u_president_application_rejected_u_ayse_0',
          actor: _president,
          kind: 'application_rejected',
          refs: {'userId': _target},
        ),
      ]);
      expect(dispatcher.calls, const [
        DispatchCall(
          kind: 'notifyApplicationDecidedInTransaction',
          args: {'clubId': _clubId, 'applicantId': _target, 'approved': false},
          recipients: [_target],
        ),
      ]);
      expect((await read(_clubPath))!['memberCount'], _memberCount);
      expect(await read(_counterPath), isNull);
    });

    test(
      'rejectNote sınırı aşarsa invalidArgument; transaction açılmaz',
      () async {
        await seedMembership(_target, MembershipStatus.pending);

        final result = await repository.reject(
          clubId: _clubId,
          userId: _target,
          actorId: _board,
          reason: RejectReason.other,
          rejectNote: 'x' * (Limits.rejectNoteMax + 1),
        );

        expect(result.errorOrNull, FirestoreError.invalidArgument);
        expect(service.transactions, 0);
        await expectNothingWritten();
      },
    );
  });

  group('T-30 · undoDecision · M12 (a) — 30 sn geri al', () {
    test('onay pencere içinde (29 sn) geri alınır: pending, karar alanları '
        'null, memberCount −1 + yan belge; günlük ve bildirim yok', () async {
      await seedMembership(
        _target,
        MembershipStatus.active,
        decidedBy: _board,
        decidedAt: _now.subtract(const Duration(seconds: 29)),
      );

      final result = await repository.undoDecision(
        clubId: _clubId,
        userId: _target,
        actorId: _board,
      );

      expect(result.isSuccess, isTrue);
      expect(writes(), [
        _write('update', _targetPath, {'status': 'pending', ..._cleared}),
        ..._counted(_target),
      ]);
      expect(service.reads, [_targetPath]);
      expect(dispatcher.calls, isEmpty);
      expect((await read(_clubPath))!['memberCount'], _memberCount - 1);
    });

    test(
      'ret geri alınır: rejected → pending, sayaç ve yan belge yok',
      () async {
        await seedMembership(
          _target,
          MembershipStatus.rejected,
          decidedBy: _board,
          decidedAt: _now.subtract(const Duration(seconds: 5)),
        );

        final result = await repository.undoDecision(
          clubId: _clubId,
          userId: _target,
          actorId: _board,
        );

        expect(result.isSuccess, isTrue);
        expect(writes(), [
          _write('update', _targetPath, {'status': 'pending', ..._cleared}),
        ]);
        expect((await read(_targetPath))!['retryAfter'], isNull);
      },
    );

    test('pencere dışı (tam 30 sn), başka yöneticinin kararı ve karar alanı '
        'olmayan üyelik kodsuz ruleViolation; hiçbir şey yazılmaz', () async {
      final cases = [
        (_board, _now.subtract(Limits.managerUndoWindow)),
        (_president, _now.subtract(const Duration(seconds: 1))),
        (null, null),
      ];
      for (final (decidedBy, decidedAt) in cases) {
        await reset();
        await seedMembership(
          _target,
          MembershipStatus.active,
          decidedBy: decidedBy,
          decidedAt: decidedAt,
        );
        final result = await repository.undoDecision(
          clubId: _clubId,
          userId: _target,
          actorId: _board,
        );
        expect(result.errorOrNull, FirestoreError.ruleViolation);
        expect(
          switch (result) {
            FirebaseFailure(:final detail) => detail,
            FirebaseSuccess() => 'başarı',
          },
          isNull,
        );
        await expectNothingWritten();
      }
    });

    test('kaynak active / rejected değilse conflict; pencere içinde rolü '
        'board olmuş onay geri alınmaz (conflict)', () async {
      for (final status in [
        null,
        MembershipStatus.pending,
        MembershipStatus.removed,
        MembershipStatus.left,
        MembershipStatus.cancelled,
      ]) {
        await reset();
        if (status != null) {
          await seedMembership(
            _target,
            status,
            decidedBy: _board,
            decidedAt: _now,
          );
        }
        final result = await repository.undoDecision(
          clubId: _clubId,
          userId: _target,
          actorId: _board,
        );
        expect(result.errorOrNull, FirestoreError.conflict, reason: '$status');
        await expectNothingWritten();
      }

      await reset();
      await seedMembership(
        _target,
        MembershipStatus.active,
        role: ClubRole.board,
        decidedBy: _board,
        decidedAt: _now,
      );
      final promoted = await repository.undoDecision(
        clubId: _clubId,
        userId: _target,
        actorId: _board,
      );
      expect(promoted.errorOrNull, FirestoreError.conflict);
      await expectNothingWritten();
    });

    test('aynı yönetici geri al + yeniden onay: günlük kaydı ikinci kez '
        'yazılmaz, sayaç ve bildirim yeniden yazılır', () async {
      await seedMembership(_target, MembershipStatus.pending);
      Future<FirestoreResult<void>> approve() => repository.approve(
        clubId: _clubId,
        userId: _target,
        actorId: _board,
      );

      expect((await approve()).isSuccess, isTrue);
      // Sunucu zamanı `decidedAt`'i fake veritabanında gerçek saattir: geri
      // alma penceresi o ana göre ölçülür.
      final decidedAt = (await repository.getMembership(
        _clubId,
        _target,
      )).dataOrNull!.decidedAt!;
      clock.set(decidedAt.add(const Duration(seconds: 3)));
      expect(
        (await repository.undoDecision(
          clubId: _clubId,
          userId: _target,
          actorId: _board,
        )).isSuccess,
        isTrue,
      );
      service.writes.clear();
      expect((await approve()).isSuccess, isTrue);

      expect(writes(), [
        _write('update', _targetPath, {
          'status': 'active',
          'role': 'member',
          'decidedAt': serverTimestampMark,
          'decidedBy': _board,
          'updatedAt': serverTimestampMark,
        }),
        ..._counted(_target),
      ]);
      expect(await activityIds(), [
        'c01_u_board_application_approved_u_ayse_0',
      ]);
      expect(dispatcher.calls, hasLength(2));
      expect((await read(_clubPath))!['memberCount'], _memberCount + 1);
    });
  });

  group('T-30 · remove · M9 (active → removed) + hiyerarşi', () {
    test('karar alanları + memberCount −1 + yan belge + günlük + bildirim '
        "tek transaction'da", () async {
      await seedMembership(_target, MembershipStatus.active, priorCount: 3);

      final result = await repository.remove(
        clubId: _clubId,
        userId: _target,
        actorId: _board,
        actorRole: ClubRole.board,
        rejectNote: 'Kurallara uymadı',
      );

      expect(result.isSuccess, isTrue);
      const activityId = 'c01_u_board_member_removed_u_ayse_3';
      expect(writes(), [
        _write('update', _targetPath, {
          'status': 'removed',
          'decidedAt': serverTimestampMark,
          'decidedBy': _board,
          'retryAfter': _retryAfter,
          'rejectReason': 'other',
          'rejectNote': 'Kurallara uymadı',
          'updatedAt': serverTimestampMark,
        }),
        ..._counted(_target),
        _activityWrite(
          activityId,
          actor: _board,
          kind: 'member_removed',
          refs: {'userId': _target},
        ),
      ]);
      // Hesabı silinmiş üye de çıkarılabilir: kullanıcı belgesi okunmaz.
      expect(service.reads, [_targetPath, 'activity/$activityId']);
      expect(service.transactions, 1);
      expect(dispatcher.calls, const [
        DispatchCall(
          kind: 'notifyRemovedInTransaction',
          args: {'clubId': _clubId, 'userId': _target},
          recipients: [_target],
        ),
      ]);
      expect((await read(_clubPath))!['memberCount'], _memberCount - 1);
    });

    test('hiyerarşi tablosu (sözleşme §4 c): başkan / süper member + board, '
        'kurul yalnızca member; üye çıkaramaz; danışman notMember; başkan '
        've danışman hedef çıkarılamaz', () async {
      const ok = 'ok';
      final cases = <(ClubRole, bool, ClubRole, Object)>[
        (ClubRole.president, false, ClubRole.member, ok),
        (ClubRole.president, false, ClubRole.board, ok),
        (ClubRole.board, false, ClubRole.member, ok),
        (
          ClubRole.board,
          false,
          ClubRole.board,
          FirestoreError.permissionDenied,
        ),
        (ClubRole.member, true, ClubRole.board, ok),
        (
          ClubRole.member,
          false,
          ClubRole.member,
          FirestoreError.permissionDenied,
        ),
        (ClubRole.advisor, false, ClubRole.member, FirestoreRuleCode.notMember),
        (
          ClubRole.president,
          false,
          ClubRole.president,
          FirestoreRuleCode.presidentCannotBeRemoved,
        ),
        (
          ClubRole.member,
          true,
          ClubRole.president,
          FirestoreRuleCode.presidentCannotBeRemoved,
        ),
        (
          ClubRole.president,
          false,
          ClubRole.advisor,
          FirestoreRuleCode.notMember,
        ),
      ];
      for (final (actorRole, isSuper, targetRole, expected) in cases) {
        await reset();
        await seedMembership(
          _target,
          MembershipStatus.active,
          role: targetRole,
        );
        final result = await repository.remove(
          clubId: _clubId,
          userId: _target,
          actorId: isSuper ? _super : _board,
          actorRole: actorRole,
          actorIsSuper: isSuper,
        );
        final label = '$actorRole super=$isSuper → $targetRole';
        switch (expected) {
          case ok:
            expect(result.isSuccess, isTrue, reason: label);
            expect((await read(_targetPath))!['status'], 'removed');
          case final FirestoreRuleCode code:
            expectViolation(result, code);
            await expectNothingWritten();
          case final FirestoreError error:
            expect(result.errorOrNull, error, reason: label);
            await expectNothingWritten();
        }
      }
    });

    test('W-89 (c): hesabı silinmiş üye çıkarılır; kendini çıkarma ve uzun '
        'not invalidArgument, aktif olmayan hedef conflict', () async {
      await seedMembership(_target, MembershipStatus.active);
      await seedUser(_target, status: UserStatus.deleted);
      final deleted = await repository.remove(
        clubId: _clubId,
        userId: _target,
        actorId: _president,
        actorRole: ClubRole.president,
      );
      expect(deleted.isSuccess, isTrue);

      await reset();
      await seedMembership(_target, MembershipStatus.active);
      final self = await repository.remove(
        clubId: _clubId,
        userId: _board,
        actorId: _board,
        actorRole: ClubRole.board,
      );
      final longNote = await repository.remove(
        clubId: _clubId,
        userId: _target,
        actorId: _board,
        actorRole: ClubRole.board,
        rejectNote: 'x' * (Limits.rejectNoteMax + 1),
      );
      expect(self.errorOrNull, FirestoreError.invalidArgument);
      expect(longNote.errorOrNull, FirestoreError.invalidArgument);
      expect(service.transactions, 0);

      await seedMembership(_target, MembershipStatus.pending);
      final pending = await repository.remove(
        clubId: _clubId,
        userId: _target,
        actorId: _board,
        actorRole: ClubRole.board,
      );
      expect(pending.errorOrNull, FirestoreError.conflict);
      await expectNothingWritten();
    });
  });

  group('T-30 · undoRemoval · M12 (b)', () {
    test('pencere içinde: removed → active (rol member), karar alanları null, '
        'memberCount +1 + yan belge; pencere dışı ruleViolation, kaynak '
        'removed değilse conflict', () async {
      await seedMembership(
        _target,
        MembershipStatus.removed,
        decidedBy: _president,
        decidedAt: _now.subtract(const Duration(seconds: 10)),
      );

      final result = await repository.undoRemoval(
        clubId: _clubId,
        userId: _target,
        actorId: _president,
      );

      expect(result.isSuccess, isTrue);
      expect(writes(), [
        _write('update', _targetPath, {
          'status': 'active',
          'role': 'member',
          ..._cleared,
        }),
        ..._counted(_target),
      ]);
      expect(dispatcher.calls, isEmpty);
      expect((await read(_clubPath))!['memberCount'], _memberCount + 1);

      await reset();
      await seedMembership(
        _target,
        MembershipStatus.removed,
        decidedBy: _president,
        decidedAt: _now.subtract(const Duration(seconds: 31)),
      );
      final late = await repository.undoRemoval(
        clubId: _clubId,
        userId: _target,
        actorId: _president,
      );
      expect(late.errorOrNull, FirestoreError.ruleViolation);

      await seedMembership(
        _target,
        MembershipStatus.rejected,
        decidedBy: _president,
        decidedAt: _now,
      );
      final rejected = await repository.undoRemoval(
        clubId: _clubId,
        userId: _target,
        actorId: _president,
      );
      expect(rejected.errorOrNull, FirestoreError.conflict);
      await expectNothingWritten();
    });
  });

  group('T-30 · changeRole · M10 (member ↔ board)', () {
    test('rol + günlük (refs userId, role) + bildirim; sayaç yok', () async {
      await seedMembership(_target, MembershipStatus.active, priorCount: 1);

      final result = await repository.changeRole(
        clubId: _clubId,
        userId: _target,
        role: ClubRole.board,
        actorId: _president,
      );

      expect(result.isSuccess, isTrue);
      const activityId = 'c01_u_president_role_changed_u_ayse_board_1';
      expect(writes(), [
        _write('update', _targetPath, {
          'role': 'board',
          'updatedAt': serverTimestampMark,
        }),
        _activityWrite(
          activityId,
          actor: _president,
          kind: 'role_changed',
          refs: {'userId': _target, 'role': 'board'},
        ),
      ]);
      expect(service.reads, [_targetPath, 'activity/$activityId']);
      expect(dispatcher.calls, const [
        DispatchCall(
          kind: 'notifyRoleChangedInTransaction',
          args: {'clubId': _clubId, 'userId': _target, 'role': ClubRole.board},
          recipients: [_target],
        ),
      ]);
      expect((await read(_clubPath))!['memberCount'], _memberCount);
    });

    test('geçersiz: yeni rol president / advisor ya da aynı rol '
        'invalidArgument; hedef başkan presidentCannotBeRemoved, danışman '
        'notMember, aktif değil conflict', () async {
      await seedMembership(_target, MembershipStatus.active);
      for (final role in [ClubRole.president, ClubRole.advisor]) {
        final result = await repository.changeRole(
          clubId: _clubId,
          userId: _target,
          role: role,
          actorId: _president,
        );
        expect(result.errorOrNull, FirestoreError.invalidArgument);
      }
      expect(service.transactions, 0);
      final same = await repository.changeRole(
        clubId: _clubId,
        userId: _target,
        role: ClubRole.member,
        actorId: _president,
      );
      expect(same.errorOrNull, FirestoreError.invalidArgument);

      final president = await repository.changeRole(
        clubId: _clubId,
        userId: _president,
        role: ClubRole.board,
        actorId: _president,
      );
      expectViolation(president, FirestoreRuleCode.presidentCannotBeRemoved);

      await seedMembership(
        _target,
        MembershipStatus.active,
        role: ClubRole.advisor,
      );
      final advisor = await repository.changeRole(
        clubId: _clubId,
        userId: _target,
        role: ClubRole.board,
        actorId: _president,
      );
      expectViolation(advisor, FirestoreRuleCode.notMember);

      await seedMembership(_target, MembershipStatus.pending);
      final pending = await repository.changeRole(
        clubId: _clubId,
        userId: _target,
        role: ClubRole.board,
        actorId: _president,
      );
      expect(pending.errorOrNull, FirestoreError.conflict);
      await expectNothingWritten();
    });

    test('rol gidip gelirse (board → member → board) aynı kayıt ikinci kez '
        'yazılmaz; bildirim her değişimde', () async {
      await seedMembership(_target, MembershipStatus.active);
      for (final role in [ClubRole.board, ClubRole.member, ClubRole.board]) {
        final result = await repository.changeRole(
          clubId: _clubId,
          userId: _target,
          role: role,
          actorId: _president,
        );
        expect(result.isSuccess, isTrue);
      }

      expect(
        await activityIds(),
        unorderedEquals([
          'c01_u_president_role_changed_u_ayse_board_0',
          'c01_u_president_role_changed_u_ayse_member_0',
        ]),
      );
      expect(dispatcher.calls, hasLength(3));
      expect((await read(_targetPath))!['role'], 'board');
    });
  });

  group('T-30 · transferPresidency · M11 (tek transaction)', () {
    test('eski başkan board, yeni başkan president, clubs.presidentId, tek '
        'günlük kaydı ve iki bildirim aynı transaction; sayaç yok', () async {
      await seedMembership(
        _target,
        MembershipStatus.active,
        role: ClubRole.board,
        priorCount: 4,
      );

      final result = await repository.transferPresidency(
        clubId: _clubId,
        fromUserId: _president,
        toUserId: _target,
        actorId: _president,
      );

      expect(result.isSuccess, isTrue);
      const activityId = 'c01_u_president_role_changed_u_ayse_president_4';
      expect(writes(), [
        _write('update', _presidentPath, {
          'role': 'board',
          'updatedAt': serverTimestampMark,
        }),
        _write('update', _targetPath, {
          'role': 'president',
          'updatedAt': serverTimestampMark,
        }),
        _write('update', _clubPath, {
          'presidentId': _target,
          'updatedAt': serverTimestampMark,
        }),
        _activityWrite(
          activityId,
          actor: _president,
          kind: 'role_changed',
          refs: {'userId': _target, 'role': 'president'},
        ),
      ]);
      expect(service.reads, [
        _presidentPath,
        _targetPath,
        _targetUserPath,
        'activity/$activityId',
      ]);
      expect(service.transactions, 1);
      expect(service.outsideWrites, 0);
      expect(dispatcher.calls, const [
        DispatchCall(
          kind: 'notifyRoleChangedInTransaction',
          args: {
            'clubId': _clubId,
            'userId': _target,
            'role': ClubRole.president,
          },
          recipients: [_target],
        ),
        DispatchCall(
          kind: 'notifyRoleChangedInTransaction',
          args: {
            'clubId': _clubId,
            'userId': _president,
            'role': ClubRole.board,
          },
          recipients: [_president],
        ),
      ]);
      expect(dispatcher.transactions.toSet(), hasLength(1));
      expect((await read(_presidentPath))!['role'], 'board');
      expect((await read(_targetPath))!['role'], 'president');
      final club = (await read(_clubPath))!;
      expect(club['presidentId'], _target);
      expect(club['memberCount'], _memberCount);
    });

    test('geçersiz: kendine devir invalidArgument; eski başkan değil, hedef '
        'danışman / bekleyen, W-89 (b) hedef hesabı silinmiş ya da askıda → '
        'conflict; hiçbir şey yazılmaz', () async {
      final self = await repository.transferPresidency(
        clubId: _clubId,
        fromUserId: _president,
        toUserId: _president,
        actorId: _president,
      );
      expect(self.errorOrNull, FirestoreError.invalidArgument);
      expect(service.transactions, 0);

      Future<FirestoreError?> transfer({
        String from = _president,
        String to = _target,
      }) async => (await repository.transferPresidency(
        clubId: _clubId,
        fromUserId: from,
        toUserId: to,
        actorId: _president,
      )).errorOrNull;

      // Eski "başkan" aslında üye.
      await seedMembership(_target, MembershipStatus.active);
      await seedMembership(
        _board,
        MembershipStatus.active,
        role: ClubRole.board,
      );
      expect(await transfer(from: _board), FirestoreError.conflict);

      for (final (status, role) in [
        (MembershipStatus.active, ClubRole.advisor),
        (MembershipStatus.pending, ClubRole.member),
        (MembershipStatus.left, ClubRole.member),
      ]) {
        await seedMembership(_target, status, role: role);
        expect(await transfer(), FirestoreError.conflict, reason: '$status');
      }

      await seedMembership(_target, MembershipStatus.active);
      for (final status in [UserStatus.deleted, UserStatus.suspended]) {
        await seedUser(_target, status: status);
        expect(await transfer(), FirestoreError.conflict, reason: '$status');
      }
      // Kullanıcı belgesi olmayan hedef.
      await seedMembership('u_belgesiz', MembershipStatus.active);
      expect(await transfer(to: 'u_belgesiz'), FirestoreError.conflict);
      await expectNothingWritten();
      expect((await read(_clubPath))!['presidentId'], _president);
    });
  });

  group('T-30 · kritik bildirim yükleri (gerçek dağıtıcı, aynı transaction)', () {
    test('onay, çıkarma, rol ve devrin bildirim belgeleri asıl işlemin '
        "transaction'ında; tür, alıcı ve refs Rules dallarıyla aynı", () async {
      final real = repositoryOn(
        service,
        notifications: ClientFanOutDispatcher(
          writer: FirebaseNotificationRepository(service),
          recipients: _NoResolver(),
        ),
      );
      await seedMembership(_target, MembershipStatus.pending);
      await seedMembership('u_can', MembershipStatus.active);
      await seedMembership(
        'u_ece',
        MembershipStatus.active,
        role: ClubRole.board,
      );
      await seedUser('u_ece');

      final results = [
        await real.approve(clubId: _clubId, userId: _target, actorId: _board),
        await real.remove(
          clubId: _clubId,
          userId: 'u_can',
          actorId: _president,
          actorRole: ClubRole.president,
        ),
        await real.changeRole(
          clubId: _clubId,
          userId: _target,
          role: ClubRole.board,
          actorId: _president,
        ),
        await real.transferPresidency(
          clubId: _clubId,
          fromUserId: _president,
          toUserId: 'u_ece',
          actorId: _president,
        ),
      ];

      expect(results.every((r) => r.isSuccess), isTrue);
      expect(service.transactions, 4);
      expect(service.outsideWrites, 0);
      final notifications = [
        for (final write in service.writes)
          if (write.path.startsWith('notifications/')) write,
      ];
      Json payload(String userId, String type, Json refs) => {
        'userId': userId,
        'type': type,
        'refs': refs,
        'read': false,
        'isDeleted': false,
        'createdAt': serverTimestampMark,
        'updatedAt': serverTimestampMark,
        'deletedAt': null,
        'deletedBy': null,
      };
      expect(
        [for (final n in notifications) n.data],
        [
          payload(_target, 'application_approved', {'clubId': _clubId}),
          payload('u_can', 'removed_from_club', {'clubId': _clubId}),
          payload(_target, 'role_changed', {
            'clubId': _clubId,
            'role': 'board',
          }),
          payload('u_ece', 'role_changed', {
            'clubId': _clubId,
            'role': 'president',
          }),
          payload(_president, 'role_changed', {
            'clubId': _clubId,
            'role': 'board',
          }),
        ],
      );
      // Kimlik `{type}_{olay anahtarı}_{alıcı}`; devrin iki olayı iki anahtar.
      final keys = [
        for (final n in notifications)
          RegExp(
            r'^notifications/[a-z_]+_([A-Za-z0-9]{20})_u_[a-z]+$',
          ).firstMatch(n.path)!.group(1),
      ];
      expect(keys.toSet(), hasLength(5));
      expect(
        (await db.collection('notifications').get()).docs,
        hasLength(5),
      );
    });
  });

  group('T-30 · hata eşlemesi', () {
    test('Rules reddi (yönetici olmayan, danışman, başka kulübün yöneticisi) '
        'her yönetici geçişinde permissionDenied olarak döner', () async {
      final failing = repositoryOn(
        FirebaseFirestoreService(
          StubFirestore(error: firestoreException('permission-denied')),
        ),
      );

      final results = [
        await failing.approve(clubId: _clubId, userId: _target, actorId: 'u_x'),
        await failing.reject(
          clubId: _clubId,
          userId: _target,
          actorId: 'u_x',
          reason: RejectReason.quota,
        ),
        await failing.undoDecision(
          clubId: _clubId,
          userId: _target,
          actorId: 'u_x',
        ),
        await failing.undoRemoval(
          clubId: _clubId,
          userId: _target,
          actorId: 'u_x',
        ),
        await failing.remove(
          clubId: _clubId,
          userId: _target,
          actorId: 'u_x',
          actorRole: ClubRole.board,
        ),
        await failing.changeRole(
          clubId: _clubId,
          userId: _target,
          role: ClubRole.board,
          actorId: 'u_x',
        ),
        await failing.transferPresidency(
          clubId: _clubId,
          fromUserId: _president,
          toUserId: _target,
          actorId: 'u_x',
        ),
      ];

      expect(
        results.map((r) => r.errorOrNull),
        everyElement(FirestoreError.permissionDenied),
      );
    });
  });
}

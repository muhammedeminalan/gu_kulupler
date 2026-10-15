// T-37 · AdminRepository (kulüp + kullanıcı yönetimi) ve süper admin üyelik
// geçişleri (`FirebaseMembershipRepository.assignPresident` / `setAdvisor` —
// M13): kulüp oluşturma (CD-63 ad benzersizliği, kulüp + başkan üyeliği +
// iletişim belgesi tek batch, yan belge yok), kimlik alanları (ad değişikliği
// benzersizliği, bağlı danışman korunur), görseller (süper admin; askıdaki
// kulüp de), kulüp / kullanıcı askısı (CD-133: gerekçe yalnızca
// `private/account`), başkan ataması (M11 ya da yeni hedef: üyelik +
// `presidentId` + `memberCount +1` + yan belge tek transaction — W-94;
// silinmiş eski başkan — W-90), danışman bağlama, `stats` sayaçları ve hata
// eşlemesi (sözleşme `docs/plans/T-37.md` §4 a; PLAN §10.4).
//
// Yetki Security Rules'tadır (claim — D-28; `firebase/test/rules/admin.test.js`):
// burada yazım içeriği ve reddin olduğu gibi döndüğü doğrulanır.
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../fakes/fake_app_clock.dart';
import '../fakes/fake_notification_dispatcher.dart';
import '../fakes/recording_firestore_service.dart';
import '../fakes/recording_storage_service.dart';
import '../fakes/scripted_auth_service.dart';
import '../fakes/sdk_firestore_stubs.dart';
import '../helpers/plan_service_table.dart';

const String _super = 'u_super';
const String _clubId = 'c01';
const String _clubPath = 'clubs/c01';
const String _counterPath = 'clubs/c01/private/counter';
const String _president = 'u_president';
const String _target = 'u_ayse';
const String _presidentPath = 'memberships/c01_u_president';
const String _targetPath = 'memberships/c01_u_ayse';
const String _targetContact = 'memberships/c01_u_ayse/private/contact';
const int _memberCount = 12;

final DateTime _now = DateTime.utc(2026, 10, 15, 9);

const ClubCreateInput _input = ClubCreateInput(
  name: 'Fotoğraf Kulübü',
  nameLower: 'fotoğraf kulübü',
  categoryId: 'k02',
  iconName: 'camera',
  founded: 2020,
  palette: ClubPalette.slate,
  pattern: ClubPattern.waves,
  summary: 'Kısa',
  about: 'Uzun',
  approvalRequired: false,
);

String _email(String uid) => '$uid@ogr.gumushane.edu.tr';

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

Json _applicant(String uid) =>
    MembershipApplicantModel.fromUser(_user(uid)).toJson();

Map<String, Object?> _write(String op, String path, Json data) => {
  'op': op,
  'path': path,
  'data': data,
};

void main() {
  late FakeFirebaseFirestore db;
  late RecordingFirestoreService service;
  late RecordingStorageService storage;
  late ScriptedAuthService auth;
  late FakeAppClock clock;
  late FakeNotificationDispatcher dispatcher;
  late AdminRepository repository;

  AdminRepository repositoryOn(FirestoreService firestore) {
    final activity = FirebaseActivityRepository(firestore);
    final random = SequenceRandom(const [0x0a, 0x1b, 0x2c, 0x3d]);
    return FirebaseAdminRepository(
      firestore: firestore,
      storage: storage,
      auth: auth,
      clock: clock,
      random: random,
      memberships: FirebaseMembershipRepository(
        firestore,
        activity,
        dispatcher,
        clock,
      ),
      reports: FirebaseReportModeration(
        firestore: firestore,
        auth: auth,
        posts: FirebasePostRepository(
          firestore,
          storage,
          activity,
          FirebaseAnnouncementCounterRepository(firestore, clock),
          clock,
          random,
        ),
        comments: FirebaseCommentRepository(firestore, clock),
        dispatcher: dispatcher,
      ),
      search: FirebaseUserSearch(
        firestore: firestore,
        users: FirebaseUserRepository(firestore, storage, clock, random),
      ),
    );
  }

  Future<Json?> read(String path) async => (await db.doc(path).get()).data();

  List<Map<String, Object?>> writes() => [
    for (final write in service.writes)
      _write(write.op, write.path, write.data),
  ];

  Future<void> seedUser(
    String uid, {
    UserStatus status = UserStatus.active,
  }) async {
    await db.doc('users/$uid').set(_user(uid, status: status).toJson());
    await db
        .doc('users/$uid/private/account')
        .set(
          UserAccountModel(
            email: status == UserStatus.deleted ? '' : _email(uid),
            emailLower: status == UserStatus.deleted ? '' : _email(uid),
          ).toJson(),
        );
  }

  Future<void> seedMembership(
    String userId,
    MembershipStatus status, {
    ClubRole role = ClubRole.member,
    int priorCount = 0,
  }) => db
      .doc('memberships/${_clubId}_$userId')
      .set(
        MembershipModel(
          clubId: _clubId,
          userId: userId,
          applicant: const MembershipApplicantModel(
            name: 'Eski ad',
            avatarSeed: 'eski',
          ),
          status: status,
          role: role,
          priorCount: priorCount,
          appliedAt: DateTime.utc(2026, 3, 2),
        ).toJson(),
      );

  Future<void> seedClub({
    String id = _clubId,
    String nameLower = 'yazılım kulübü',
    ClubAdvisorModel? advisor,
    bool isDeleted = false,
  }) => db
      .doc('clubs/$id')
      .set(
        ClubModel(
          name: 'Yazılım Kulübü',
          nameLower: nameLower,
          categoryId: 'k01',
          iconName: 'code-xml',
          palette: ClubPalette.red,
          pattern: ClubPattern.dots,
          founded: 2015,
          presidentId: _president,
          memberCount: _memberCount,
          advisor: advisor,
          isDeleted: isDeleted,
        ).toJson(),
      );

  Future<void> reset() async {
    db = FakeFirebaseFirestore();
    service = RecordingFirestoreService(FirebaseFirestoreService(db));
    storage = RecordingStorageService();
    auth = ScriptedAuthService()
      ..currentUser = const AuthUserInfo(
        uid: _super,
        email: 'super@gumushane.edu.tr',
        emailVerified: true,
      );
    clock = FakeAppClock(_now);
    dispatcher = FakeNotificationDispatcher();
    repository = repositoryOn(service);
    await seedClub();
    await seedUser(_president);
    await seedUser(_target);
    await seedMembership(
      _president,
      MembershipStatus.active,
      role: ClubRole.president,
      priorCount: 2,
    );
  }

  /// Hiçbir belge yazılmadı, sayaç / yan belge / bildirim yok.
  Future<void> expectNothingWritten() async {
    expect(service.writes, isEmpty);
    expect(service.outsideWrites, 0);
    expect(dispatcher.calls, isEmpty);
    expect((await read(_clubPath))!['memberCount'], _memberCount);
    expect((await read(_clubPath))!['presidentId'], _president);
    expect(await read(_counterPath), isNull);
  }

  setUp(reset);

  group('T-37 · createClub (tek batch, CD-63)', () {
    test('kulüp + başkan üyeliği + iletişim belgesi tek batch; memberCount 1, '
        'yan belge yok, danışman hesabı bağlanmaz (K-A)', () async {
      final result = await repository.createClub(
        _input,
        presidentUserId: _target,
        presidentUser: _user(_target),
        presidentEmail: _email(_target),
        advisor: const AdvisorInput(name: 'Ali Veli', title: 'Doç. Dr.'),
      );

      expect(result.isSuccess, isTrue);
      final club = result.dataOrNull!;
      expect(club.id, isNotEmpty);
      expect(service.transactions, 0);
      expect(service.outsideWrites, 1, reason: 'tek commitBatch');
      final doc = (await read('clubs/${club.id}'))!;
      expect(doc, {
        'name': 'Fotoğraf Kulübü',
        'nameLower': 'fotoğraf kulübü',
        'categoryId': 'k02',
        'iconName': 'camera',
        'palette': 'slate',
        'pattern': 'waves',
        'coverSeed': 'club-${club.id}',
        'logoPath': null,
        'coverPath': null,
        'memberCount': 1,
        'approvalRequired': false,
        'applicationsOpen': true,
        'requireNote': false,
        'founded': 2020,
        'summary': 'Kısa',
        'about': 'Uzun',
        'conditions': <Object?>[],
        'social': <String, Object?>{},
        'presidentId': _target,
        'pinnedPostId': null,
        'advisor': {'name': 'Ali Veli', 'title': 'Doç. Dr.', 'userId': null},
        'status': 'active',
        'suspendReason': null,
        'createdBy': _super,
        'createdAt': doc['createdAt'],
        'updatedAt': doc['updatedAt'],
        'isDeleted': false,
        'deletedAt': null,
        'deletedBy': null,
      });
      final membership = (await read('memberships/${club.id}_$_target'))!;
      expect(
        membership
          ..remove('appliedAt')
          ..remove('decidedAt'),
        {
          'clubId': club.id,
          'userId': _target,
          'status': 'active',
          'role': 'president',
          'applicant': _applicant(_target),
          'decidedBy': _super,
          'retryAfter': null,
          'rejectReason': null,
          'rejectNote': '',
          'priorCount': 0,
          'createdAt': membership['createdAt'],
          'updatedAt': membership['updatedAt'],
          'isDeleted': false,
          'deletedAt': null,
          'deletedBy': null,
        },
      );
      final contact = (await read(
        'memberships/${club.id}_$_target/private/contact',
      ))!;
      expect(contact['email'], _email(_target));
      expect(contact['emailLower'], _email(_target));
      expect(contact['note'], '');
      expect(await read('clubs/${club.id}/private/counter'), isNull);
      // Danışman üyeliği açılmaz (hesap bağlama yalnızca setAdvisor).
      final memberships = await db
          .collection('memberships')
          .where('clubId', isEqualTo: club.id)
          .get();
      expect(memberships.docs, hasLength(1));
      expect(club.memberCount, 1);
      expect(club.createdBy, _super);
      expect(
        club.advisor,
        const ClubAdvisorModel(name: 'Ali Veli', title: 'Doç. Dr.'),
      );
    });

    test('ad alınmışsa (silinmiş kulübün adı dahil) alreadyExists; hiçbir şey '
        'yazılmaz', () async {
      await seedClub(id: 'c09', nameLower: 'fotoğraf kulübü', isDeleted: true);

      final result = await repository.createClub(
        _input,
        presidentUserId: _target,
        presidentUser: _user(_target),
        presidentEmail: _email(_target),
      );

      expect(result.errorOrNull, FirestoreError.alreadyExists);
      expect(service.outsideWrites, 0);
      expect((await db.collection('clubs').get()).docs, hasLength(2));
    });

    test('başkan etkin değil → conflict; geçersiz alan / başka kullanıcının '
        'modeli → invalidArgument; oturum yok → unauthenticated', () async {
      Future<FirestoreError?> create({
        ClubCreateInput input = _input,
        UserModel? user,
        String email = 'u_ayse@ogr.gumushane.edu.tr',
      }) async => (await repository.createClub(
        input,
        presidentUserId: _target,
        presidentUser: user ?? _user(_target),
        presidentEmail: email,
      )).errorOrNull;

      for (final status in [UserStatus.suspended, UserStatus.deleted]) {
        expect(
          await create(user: _user(_target, status: status)),
          FirestoreError.conflict,
          reason: '$status',
        );
      }
      expect(
        await create(user: _user('u_other')),
        FirestoreError.invalidArgument,
      );
      expect(
        await create(email: 'x@example.com'),
        FirestoreError.invalidArgument,
      );
      for (final input in [
        const ClubCreateInput(
          name: '',
          nameLower: 'x',
          categoryId: 'k01',
          iconName: 'camera',
          founded: 2020,
          palette: ClubPalette.red,
          pattern: ClubPattern.dots,
        ),
        const ClubCreateInput(
          name: 'Ad',
          nameLower: 'ad',
          categoryId: 'k99',
          iconName: 'camera',
          founded: 2020,
          palette: ClubPalette.red,
          pattern: ClubPattern.dots,
        ),
        const ClubCreateInput(
          name: 'Ad',
          nameLower: 'ad',
          categoryId: 'k01',
          iconName: 'camera',
          founded: 2027,
          palette: ClubPalette.red,
          pattern: ClubPattern.dots,
        ),
      ]) {
        expect(await create(input: input), FirestoreError.invalidArgument);
      }
      auth.currentUser = null;
      expect(await create(), FirestoreError.unauthenticated);
      expect(service.outsideWrites, 0);
      expect((await db.collection('clubs').get()).docs, hasLength(1));
    });
  });

  group('T-37 · updateClubIdentity', () {
    test('yalnızca verilen alanlar + updatedAt; kendi adı serbest, bağlı '
        'danışman hesabı (advisor.userId) korunur', () async {
      await seedClub(
        advisor: const ClubAdvisorModel(
          name: 'Eski',
          title: 'Dr.',
          userId: 'u_hoca',
        ),
      );

      final result = await repository.updateClubIdentity(
        _clubId,
        const ClubIdentityPatch(
          name: 'Yazılım Kulübü',
          nameLower: 'yazılım kulübü',
          categoryId: 'k03',
          palette: ClubPalette.bordeaux,
          applicationsOpen: false,
          advisor: AdvisorInput(name: 'Yeni Hoca', title: 'Prof. Dr.'),
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(service.transactions, 1);
      expect(writes(), [
        _write('update', _clubPath, {
          'name': 'Yazılım Kulübü',
          'nameLower': 'yazılım kulübü',
          'categoryId': 'k03',
          'palette': 'bordeaux',
          'applicationsOpen': false,
          'advisor': {
            'name': 'Yeni Hoca',
            'title': 'Prof. Dr.',
            'userId': 'u_hoca',
          },
          'updatedAt': serverTimestampMark,
        }),
      ]);
    });

    test('ad başka kulübünse alreadyExists; bağlı danışman clearAdvisor ile '
        'kaldırılamaz → failedPrecondition; boş / eksik yama invalidArgument; '
        'kulüp yok ya da silinmiş → notFound', () async {
      await seedClub(id: 'c02', nameLower: 'satranç kulübü');
      expect(
        (await repository.updateClubIdentity(
          _clubId,
          const ClubIdentityPatch(
            name: 'Satranç Kulübü',
            nameLower: 'satranç kulübü',
          ),
        )).errorOrNull,
        FirestoreError.alreadyExists,
      );

      await seedClub(
        advisor: const ClubAdvisorModel(name: 'A', title: '', userId: 'u_h'),
      );
      expect(
        (await repository.updateClubIdentity(
          _clubId,
          const ClubIdentityPatch(clearAdvisor: true),
        )).errorOrNull,
        FirestoreError.failedPrecondition,
      );
      for (final patch in const [
        ClubIdentityPatch(),
        ClubIdentityPatch(name: 'Ad'),
        ClubIdentityPatch(founded: 1800),
      ]) {
        expect(
          (await repository.updateClubIdentity(_clubId, patch)).errorOrNull,
          FirestoreError.invalidArgument,
        );
      }
      await seedClub(id: 'c03', isDeleted: true, nameLower: 'silinmiş');
      for (final id in ['c03', 'c_yok']) {
        expect(
          (await repository.updateClubIdentity(
            id,
            const ClubIdentityPatch(summary: 'x'),
          )).errorOrNull,
          FirestoreError.notFound,
        );
      }
      expect(service.writes, isEmpty);
      expect(service.outsideWrites, 0);
    });

    test('hesabı bağlanmamış danışman clearAdvisor ile kaldırılır (advisor: '
        'null)', () async {
      await seedClub(
        advisor: const ClubAdvisorModel(name: 'A', title: ''),
      );
      final result = await repository.updateClubIdentity(
        _clubId,
        const ClubIdentityPatch(clearAdvisor: true),
      );
      expect(result.isSuccess, isTrue);
      expect((await read(_clubPath))!['advisor'], isNull);
    });
  });

  group('T-37 · updateClubMedia (süper admin)', () {
    test(
      'askıdaki kulüpte de yüklenir: clubId + uploaderId üst verisi, yollar '
      'tek güncellemeyle; günlük yok. Kulüp yoksa dosya gönderilmez',
      () async {
        await db.doc(_clubPath).update({'status': 'suspended'});
        final result = await repository.updateClubMedia(
          _clubId,
          uploaderId: _super,
          logo: ClubMediaUpload(bytes: Uint8List(8), contentType: 'image/png'),
        );

        expect(result.isSuccess, isTrue);
        expect(storage.uploads, hasLength(1));
        final upload = storage.uploads.single;
        expect(
          upload.path,
          matches(RegExp(r'^clubs/c01/20261015T090000Z_[0-9a-f]{16}\.png$')),
        );
        expect(upload.customMetadata, {
          'clubId': _clubId,
          'uploaderId': _super,
        });
        final club = (await read(_clubPath))!;
        expect(club['logoPath'], upload.path);
        expect(result.dataOrNull, ClubMediaPaths(logoPath: upload.path));
        expect(service.outsideWrites, 1);
        expect((await db.collection('activity').get()).docs, isEmpty);

        final missing = await repository.updateClubMedia(
          'c_yok',
          uploaderId: _super,
          cover: ClubMediaUpload(bytes: Uint8List(8), contentType: 'image/png'),
        );
        expect(
          missing.errorOrNull,
          const MediaDocumentError(FirestoreError.notFound),
        );
        expect(storage.uploads, hasLength(1));
      },
    );
  });

  group('T-37 · kulüp askısı (DLG-28)', () {
    test(
      'suspendClub: status + suspendReason tek güncelleme; activateClub '
      'gerekçeyi boşaltır; geçersiz gerekçe yazmadan invalidArgument',
      () async {
        expect(
          (await repository.suspendClub(
            _clubId,
            reason: 'Kural ihlali',
          )).isSuccess,
          isTrue,
        );
        var club = (await read(_clubPath))!;
        expect(club['status'], 'suspended');
        expect(club['suspendReason'], 'Kural ihlali');
        // Gerekçe değişimi serbest (yeniden deneme güvenli).
        expect(
          (await repository.suspendClub(_clubId, reason: 'Güncel')).isSuccess,
          isTrue,
        );
        expect((await repository.activateClub(_clubId)).isSuccess, isTrue);
        club = (await read(_clubPath))!;
        expect(club['status'], 'active');
        expect(club['suspendReason'], isNull);
        expect(service.outsideWrites, 3);

        for (final reason in ['', 'x' * (Limits.adminReasonMax + 1)]) {
          expect(
            (await repository.suspendClub(_clubId, reason: reason)).errorOrNull,
            FirestoreError.invalidArgument,
          );
        }
        expect(service.outsideWrites, 3);
      },
    );
  });

  group('T-37 · kullanıcı askısı (DLG-30, CD-133)', () {
    test(
      'suspendUser: users.status + private/account.suspendReason tek '
      'işlem; gerekçe users belgesine yazılmaz; activateUser geri alır',
      () async {
        final result = await repository.suspendUser(_target, reason: 'Spam');

        expect(result.isSuccess, isTrue);
        expect(service.transactions, 1);
        expect(writes(), [
          _write('update', 'users/$_target', {
            'status': 'suspended',
            'updatedAt': serverTimestampMark,
          }),
          _write('update', 'users/$_target/private/account', {
            'suspendReason': 'Spam',
            'updatedAt': serverTimestampMark,
          }),
        ]);
        expect(
          await read('users/$_target'),
          isNot(contains('suspendReason')),
        );

        expect((await repository.activateUser(_target)).isSuccess, isTrue);
        expect((await read('users/$_target'))!['status'], 'active');
        expect(
          (await read('users/$_target/private/account'))!['suspendReason'],
          isNull,
        );
        expect(service.outsideWrites, 0);
      },
    );

    test('silinmiş hesap conflict, olmayan hesap notFound, geçersiz gerekçe '
        've kendi hesabı invalidArgument; hiçbir şey yazılmaz', () async {
      await seedUser('u_silinmis', status: UserStatus.deleted);
      expect(
        (await repository.suspendUser('u_silinmis', reason: 'x')).errorOrNull,
        FirestoreError.conflict,
      );
      expect(
        (await repository.activateUser('u_silinmis')).errorOrNull,
        FirestoreError.conflict,
      );
      expect(
        (await repository.suspendUser('u_yok', reason: 'x')).errorOrNull,
        FirestoreError.notFound,
      );
      expect(
        (await repository.suspendUser(_target, reason: '')).errorOrNull,
        FirestoreError.invalidArgument,
      );
      // Süper admin kendi hesabını değiştiremez (güvenlik incelemesi T-37).
      await seedUser(_super, status: UserStatus.suspended);
      expect(
        (await repository.suspendUser(_super, reason: 'x')).errorOrNull,
        FirestoreError.invalidArgument,
      );
      expect(
        (await repository.activateUser(_super)).errorOrNull,
        FirestoreError.invalidArgument,
      );
      expect(service.writes, isEmpty);
      expect((await read('users/u_silinmis'))!['status'], 'deleted');
    });
  });

  group('T-37 · assignPresident (tek transaction)', () {
    const activityId = 'c01_u_super_role_changed_u_ayse_president_0';
    const notifications = [
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
    ];

    test('yeni hedef (üyeliği yok): üyelik active/president + contact + eski '
        'başkan board + kulüpte tek güncelleme {presidentId, memberCount +1} + '
        'yan belge hedefi gösterir (W-94) + günlük + 2 bildirim', () async {
      final result = await repository.assignPresident(
        clubId: _clubId,
        toUserId: _target,
        actorId: _super,
      );

      expect(result.isSuccess, isTrue);
      expect(service.transactions, 1);
      expect(service.outsideWrites, 0);
      expect(writes(), [
        _write('update', _presidentPath, {
          'role': 'board',
          'updatedAt': serverTimestampMark,
        }),
        _write('set', _targetPath, {
          'clubId': _clubId,
          'userId': _target,
          'status': 'active',
          'role': 'president',
          'applicant': _applicant(_target),
          'appliedAt': serverTimestampMark,
          'decidedAt': serverTimestampMark,
          'decidedBy': _super,
          'retryAfter': null,
          'rejectReason': null,
          'rejectNote': '',
          'priorCount': 0,
          'createdAt': serverTimestampMark,
          'updatedAt': serverTimestampMark,
          'isDeleted': false,
          'deletedAt': null,
          'deletedBy': null,
        }),
        _write('set', _targetContact, {
          'email': _email(_target),
          'emailLower': _email(_target),
          'note': '',
          'createdAt': serverTimestampMark,
          'updatedAt': serverTimestampMark,
          'isDeleted': false,
          'deletedAt': null,
          'deletedBy': null,
        }),
        _write('update', _clubPath, {
          'presidentId': _target,
          'memberCount': incrementMark,
          'updatedAt': serverTimestampMark,
        }),
        _write('set', _counterPath, {
          'clubId': _clubId,
          'lastMembershipRef': 'memberships/c01_u_ayse',
          'updatedAt': serverTimestampMark,
        }),
        _write('set', 'activity/$activityId', {
          'clubId': _clubId,
          'actorId': _super,
          'kind': 'role_changed',
          'refs': {'userId': _target, 'role': 'president'},
          'createdAt': serverTimestampMark,
        }),
      ]);
      expect(dispatcher.calls, notifications);
      expect(dispatcher.transactions.toSet(), hasLength(1));
      final club = (await read(_clubPath))!;
      expect(club['presidentId'], _target);
      expect(club['memberCount'], _memberCount + 1);
      expect(club, isNot(contains('lastMembershipRef')));
    });

    test('geçmiş üyelik (left) + iletişim belgesi: update, priorCount korunur, '
        'contact yalnızca e-posta (not kalır)', () async {
      await seedMembership(_target, MembershipStatus.left, priorCount: 3);
      await db.doc(_targetContact).set({
        'email': 'eski@ogr.gumushane.edu.tr',
        'emailLower': 'eski@ogr.gumushane.edu.tr',
        'note': 'eski not',
      });

      final result = await repository.assignPresident(
        clubId: _clubId,
        toUserId: _target,
        actorId: _super,
      );

      expect(result.isSuccess, isTrue);
      final target = (await read(_targetPath))!;
      expect(target['status'], 'active');
      expect(target['role'], 'president');
      expect(target['priorCount'], 3);
      expect(target['applicant'], _applicant(_target));
      expect(target['rejectNote'], '');
      final contact = (await read(_targetContact))!;
      expect(contact['email'], _email(_target));
      expect(contact['note'], 'eski not');
      expect((await read(_clubPath))!['memberCount'], _memberCount + 1);
      expect(
        (await read(_counterPath))!['lastMembershipRef'],
        'memberships/c01_u_ayse',
      );
      expect(
        writes().where(
          (w) =>
              w['path'] ==
              'activity/c01_u_super_role_changed_u_ayse_president_3',
        ),
        hasLength(1),
      );
    });

    test('hedef etkin üye: M11 devri (üç yazım + günlük), sayaç ve yan belge '
        'yok', () async {
      await seedMembership(_target, MembershipStatus.active, priorCount: 1);

      final result = await repository.assignPresident(
        clubId: _clubId,
        toUserId: _target,
        actorId: _super,
      );

      expect(result.isSuccess, isTrue);
      expect(
        [for (final w in writes()) '${w['op']} ${w['path']}'],
        [
          'update $_presidentPath',
          'update $_targetPath',
          'update $_clubPath',
          'set activity/c01_u_super_role_changed_u_ayse_president_1',
        ],
      );
      expect(dispatcher.calls, notifications);
      final club = (await read(_clubPath))!;
      expect(club['presidentId'], _target);
      expect(club['memberCount'], _memberCount);
      expect(await read(_counterPath), isNull);
    });

    test('W-90: hesabı silinmiş eski başkan da board olur', () async {
      await seedUser(_president, status: UserStatus.deleted);

      final result = await repository.assignPresident(
        clubId: _clubId,
        toUserId: _target,
        actorId: _super,
      );

      expect(result.isSuccess, isTrue);
      expect((await read(_presidentPath))!['role'], 'board');
      expect((await read(_presidentPath))!['status'], 'active');
      expect((await read(_clubPath))!['presidentId'], _target);
    });

    test('reddedilenler: zaten başkan invalidArgument; bekleyen hedef, askıda '
        '/ silinmiş hesap → conflict; danışman → ruleViolation(notMember); '
        'kulüp yok → notFound; hiçbir şey yazılmaz', () async {
      Future<FirestoreResult<void>> assign([String to = _target]) =>
          repository.assignPresident(
            clubId: _clubId,
            toUserId: to,
            actorId: _super,
          );

      expect(
        (await assign(_president)).errorOrNull,
        FirestoreError.invalidArgument,
      );
      await seedMembership(_target, MembershipStatus.pending);
      expect((await assign()).errorOrNull, FirestoreError.conflict);

      await seedMembership(
        _target,
        MembershipStatus.active,
        role: ClubRole.advisor,
      );
      final advisor = await assign();
      expect(advisor.errorOrNull, FirestoreError.ruleViolation);
      expect(
        (advisor as FirebaseFailure).detail,
        const FirestoreFailureDetail(FirestoreRuleCode.notMember),
      );

      for (final membership in [null, MembershipStatus.active]) {
        for (final status in [UserStatus.suspended, UserStatus.deleted]) {
          await reset();
          if (membership != null) await seedMembership(_target, membership);
          await seedUser(_target, status: status);
          expect(
            (await assign()).errorOrNull,
            FirestoreError.conflict,
            reason: '$membership / $status',
          );
          await expectNothingWritten();
        }
      }
      expect(
        (await repository.assignPresident(
          clubId: 'c_yok',
          toUserId: _target,
          actorId: _super,
        )).errorOrNull,
        FirestoreError.notFound,
      );
      await expectNothingWritten();
    });
  });

  group('T-37 · setAdvisor (M13, tek transaction, memberCount yok)', () {
    const advisorRecord = ClubAdvisorModel(name: 'Ali Veli', title: 'Doç. Dr.');

    test('bağla: üyelik active/advisor + contact + clubs advisor.userId; sayaç '
        've yan belge yok; ikinci çağrı yazmaz', () async {
      await seedClub(advisor: advisorRecord);

      final result = await repository.setAdvisor(
        clubId: _clubId,
        userId: _target,
        active: true,
      );

      expect(result.isSuccess, isTrue);
      expect(writes(), [
        _write('set', _targetPath, {
          'clubId': _clubId,
          'userId': _target,
          'status': 'active',
          'role': 'advisor',
          'applicant': _applicant(_target),
          'appliedAt': serverTimestampMark,
          'decidedAt': null,
          'decidedBy': null,
          'retryAfter': null,
          'rejectReason': null,
          'rejectNote': '',
          'priorCount': 0,
          'createdAt': serverTimestampMark,
          'updatedAt': serverTimestampMark,
          'isDeleted': false,
          'deletedAt': null,
          'deletedBy': null,
        }),
        _write('set', _targetContact, {
          'email': _email(_target),
          'emailLower': _email(_target),
          'note': '',
          'createdAt': serverTimestampMark,
          'updatedAt': serverTimestampMark,
          'isDeleted': false,
          'deletedAt': null,
          'deletedBy': null,
        }),
        _write('update', _clubPath, {
          'advisor.userId': _target,
          'updatedAt': serverTimestampMark,
        }),
      ]);
      final club = (await read(_clubPath))!;
      expect(club['advisor'], {
        'name': 'Ali Veli',
        'title': 'Doç. Dr.',
        'userId': _target,
      });
      expect(club['memberCount'], _memberCount);
      expect(await read(_counterPath), isNull);

      service.writes.clear();
      expect(
        (await repository.setAdvisor(
          clubId: _clubId,
          userId: _target,
          active: true,
        )).isSuccess,
        isTrue,
      );
      expect(service.writes, isEmpty);
    });

    test('kaldır: üyelik left + advisor.userId null (ad / ünvan kalır); '
        'danışman değilse conflict', () async {
      await seedClub(advisor: advisorRecord.copyWith(userId: _target));
      await seedMembership(
        _target,
        MembershipStatus.active,
        role: ClubRole.advisor,
      );

      final result = await repository.setAdvisor(
        clubId: _clubId,
        userId: _target,
        active: false,
      );

      expect(result.isSuccess, isTrue);
      expect((await read(_targetPath))!['status'], 'left');
      expect((await read(_clubPath))!['advisor'], {
        'name': 'Ali Veli',
        'title': 'Doç. Dr.',
        'userId': null,
      });
      expect(
        (await repository.setAdvisor(
          clubId: _clubId,
          userId: _target,
          active: false,
        )).errorOrNull,
        FirestoreError.conflict,
      );
    });

    test('kaldır, bayat bağ (güvenlik incelemesi T-37): danışman hesabını '
        'sildi, üyelik zaten left → yalnızca advisor.userId null; sonra '
        'conflict', () async {
      await seedClub(advisor: advisorRecord.copyWith(userId: _target));
      await seedMembership(
        _target,
        MembershipStatus.left,
        role: ClubRole.advisor,
      );
      final before = await read(_targetPath);

      final result = await repository.setAdvisor(
        clubId: _clubId,
        userId: _target,
        active: false,
      );

      expect(result.isSuccess, isTrue);
      expect(await read(_targetPath), before);
      expect((await read(_clubPath))!['advisor'], {
        'name': 'Ali Veli',
        'title': 'Doç. Dr.',
        'userId': null,
      });
      expect(
        (await repository.setAdvisor(
          clubId: _clubId,
          userId: _target,
          active: false,
        )).errorOrNull,
        FirestoreError.conflict,
      );
    });

    test('danışman kaydı yok → failedPrecondition; başka hesap bağlı, hedef '
        'etkin üye / bekleyen ya da hesabı askıda → conflict', () async {
      expect(
        (await repository.setAdvisor(
          clubId: _clubId,
          userId: _target,
          active: true,
        )).errorOrNull,
        FirestoreError.failedPrecondition,
      );

      Future<FirestoreError?> bind() async => (await repository.setAdvisor(
        clubId: _clubId,
        userId: _target,
        active: true,
      )).errorOrNull;

      await seedClub(advisor: advisorRecord.copyWith(userId: 'u_hoca'));
      expect(await bind(), FirestoreError.conflict);
      await seedClub(advisor: advisorRecord);
      for (final status in [
        MembershipStatus.active,
        MembershipStatus.pending,
      ]) {
        await seedMembership(_target, status);
        expect(await bind(), FirestoreError.conflict, reason: '$status');
      }
      await seedMembership(_target, MembershipStatus.left);
      await seedUser(_target, status: UserStatus.suspended);
      expect(await bind(), FirestoreError.conflict);
      expect(service.writes, isEmpty);
    });
  });

  group('T-37 · stats ve devredilen okumalar', () {
    test('dört count(): etkin kulüp, silinmemiş kullanıcı, açık şikayet, '
        'yaklaşan yayımdaki etkinlik', () async {
      await seedClub(id: 'c02', nameLower: 'b');
      await db.doc('clubs/c02').update({'status': 'suspended'});
      await seedClub(id: 'c03', nameLower: 'c', isDeleted: true);
      await seedUser('u_silinmis', status: UserStatus.deleted);
      await db.doc('users/u_silinmis').update({'isDeleted': true});
      for (final (id, status) in [
        ('r1', 'open'),
        ('r2', 'open'),
        ('r3', 'resolved'),
      ]) {
        await db.doc('reports/$id').set({'status': status});
      }
      for (final (id, status, deleted, startsAt) in [
        ('e1', 'published', false, _now.add(const Duration(days: 1))),
        ('e2', 'published', false, _now.subtract(const Duration(hours: 1))),
        ('e3', 'draft', false, _now.add(const Duration(days: 1))),
        ('e4', 'published', true, _now.add(const Duration(days: 1))),
      ]) {
        await db.doc('events/$id').set({
          'status': status,
          'isDeleted': deleted,
          'startsAt': Timestamp.fromDate(startsAt),
        });
      }

      final result = await repository.stats();

      expect(
        result.dataOrNull,
        const AdminStats(
          clubCount: 1,
          userCount: 2,
          openReportCount: 2,
          upcomingEventCount: 1,
        ),
      );
    });

    test(
      'listManagerUserIds FirebaseUserSearch sonucunu olduğu gibi döner',
      () async {
        await seedMembership(
          'u_kurul',
          MembershipStatus.active,
          role: ClubRole.board,
        );
        await seedMembership('u_uye', MembershipStatus.active);

        expect(
          (await repository.listManagerUserIds()).dataOrNull,
          {_president, 'u_kurul'},
        );
      },
    );
  });

  group('T-37 · hata eşlemesi ve sözleşme', () {
    test('Rules reddi (claim yok) her yazımda ve sayaçta permissionDenied '
        'olarak döner', () async {
      final failing = repositoryOn(
        FirebaseFirestoreService(
          StubFirestore(error: firestoreException('permission-denied')),
        ),
      );

      final results = <FirestoreResult<Object?>>[
        await failing.createClub(
          _input,
          presidentUserId: _target,
          presidentUser: _user(_target),
          presidentEmail: _email(_target),
        ),
        await failing.updateClubIdentity(
          _clubId,
          const ClubIdentityPatch(summary: 'x'),
        ),
        await failing.suspendClub(_clubId, reason: 'x'),
        await failing.activateClub(_clubId),
        await failing.assignPresident(
          clubId: _clubId,
          toUserId: _target,
          actorId: _super,
        ),
        await failing.setAdvisor(
          clubId: _clubId,
          userId: _target,
          active: true,
        ),
        await failing.suspendUser(_target, reason: 'x'),
        await failing.activateUser(_target),
        await failing.stats(),
      ];

      expect(
        results.map((r) => r.errorOrNull),
        everyElement(FirestoreError.permissionDenied),
      );
      expect(
        (await failing.updateClubMedia(
          _clubId,
          uploaderId: _super,
          logo: ClubMediaUpload(bytes: Uint8List(8), contentType: 'image/png'),
        )).errorOrNull,
        const MediaDocumentError(FirestoreError.permissionDenied),
      );
      expect(storage.uploads, isEmpty);
    });

    test('arayüzde ve uygulamada silme üyesi yok (D-10)', () {
      for (final file in [
        'packages/gu_data/lib/src/repositories/admin_repository.dart',
        'packages/gu_data/lib/src/repositories/firebase_admin_repository.dart',
      ]) {
        expect(deleteIdentifiersIn(file), isEmpty, reason: file);
      }
    });
  });
}

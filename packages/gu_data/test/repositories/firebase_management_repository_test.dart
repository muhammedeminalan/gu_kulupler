// T-30 · ManagementRepository (kompozisyon): üyelik kararları, rol / devir,
// etkinlik geçişleri, gönderi / yorum moderasyonu olduğu gibi devredilir
// (sonuç değişmez, fan-out yok); toplu karar her başvuru için ayrı işlem
// (`BulkResult`); çok alıcılı bildirim (`event_new`, `event_cancelled`,
// `announcement`) yalnızca asıl yazım kesinleşince ve en iyi çabayla; kulüp
// ayarı tek batch (yalnızca yama alanları + `updatedAt` + `settings_changed`
// günlüğü) ve sınır denetimleri; danışman salt okunur (PLAN §10.4, §10.5;
// rules-spec §3.3, §5; docs/plans/T-30.md §4 a, c; Q-09, D-10, W-83).
//
// Devredilen repository'ler ve alıcı çözücü çağrıları kaydeden el yazımı
// çiftlerdir (`_Script`); ayar yazımı `fake_cloud_firestore` + kayıt tutan
// servis çiftiyle. Yetki Security Rules'tadır: burada reddin olduğu gibi
// döndüğü doğrulanır.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../fakes/fake_notification_dispatcher.dart';
import '../fakes/recording_firestore_service.dart';
import '../fakes/sdk_firestore_stubs.dart';
import '../helpers/plan_repository_table.dart';
import '../helpers/plan_service_table.dart';

const String _interface =
    'packages/gu_data/lib/src/repositories/management_repository.dart';
const String _implementation =
    'packages/gu_data/lib/src/repositories/firebase_management_repository.dart';

const String _clubId = 'c01';
const String _clubPath = 'clubs/c01';
const String _eventId = 'e01';
const String _postId = 'p01';
const String _actor = 'u_board';
const String _ayse = 'u_ayse';

/// Devredilen çağrıların ortak kaydı: her çağrı `ad arg1 arg2 …` etiketiyle
/// sırayla yazılır; [fail] etiket ya da yalnızca ad ile eşleşen çağrıyı o
/// hatayla bitirir (yoksa başarı).
final class _Script {
  final List<String> calls = [];
  final Map<String, FirestoreError> fail = {};

  FirestoreResult<T> answer<T>(
    String method,
    List<Object?> args,
    FirestoreResult<T> success,
  ) {
    final label = [method, ...args].join(' ');
    calls.add(label);
    final error = fail[label] ?? fail[method];
    return error == null ? success : FirebaseFailure(error);
  }
}

final class _Memberships extends Fake implements MembershipRepository {
  _Memberships(this._s);

  final _Script _s;

  @override
  Future<FirestoreResult<void>> approve({
    required String clubId,
    required String userId,
    required String actorId,
  }) async => _s.answer('approve', [
    clubId,
    userId,
    actorId,
  ], const FirebaseSuccess(null));

  @override
  Future<FirestoreResult<void>> reject({
    required String clubId,
    required String userId,
    required String actorId,
    required RejectReason reason,
    String rejectNote = '',
  }) async => _s.answer('reject', [
    clubId,
    userId,
    actorId,
    reason.json,
    rejectNote,
  ], const FirebaseSuccess(null));

  @override
  Future<FirestoreResult<void>> undoDecision({
    required String clubId,
    required String userId,
    required String actorId,
  }) async => _s.answer('undoDecision', [
    clubId,
    userId,
    actorId,
  ], const FirebaseSuccess(null));

  @override
  Future<FirestoreResult<void>> undoRemoval({
    required String clubId,
    required String userId,
    required String actorId,
  }) async => _s.answer('undoRemoval', [
    clubId,
    userId,
    actorId,
  ], const FirebaseSuccess(null));

  @override
  Future<FirestoreResult<void>> remove({
    required String clubId,
    required String userId,
    required String actorId,
    required ClubRole actorRole,
    bool actorIsSuper = false,
    String rejectNote = '',
  }) async => _s.answer('remove', [
    clubId,
    userId,
    actorId,
    actorRole.json,
    actorIsSuper,
    rejectNote,
  ], const FirebaseSuccess(null));

  @override
  Future<FirestoreResult<void>> changeRole({
    required String clubId,
    required String userId,
    required ClubRole role,
    required String actorId,
  }) async => _s.answer('changeRole', [
    clubId,
    userId,
    role.json,
    actorId,
  ], const FirebaseSuccess(null));

  @override
  Future<FirestoreResult<void>> transferPresidency({
    required String clubId,
    required String fromUserId,
    required String toUserId,
    required String actorId,
  }) async => _s.answer('transferPresidency', [
    clubId,
    fromUserId,
    toUserId,
    actorId,
  ], const FirebaseSuccess(null));
}

final class _Events extends Fake implements EventRepository {
  _Events(this._s);

  final _Script _s;

  /// `getEvent` sonucu.
  EventModel event = _event(_clubId);

  @override
  Future<FirestoreResult<void>> publish(
    String eventId, {
    required String actorId,
  }) async =>
      _s.answer('publish', [eventId, actorId], const FirebaseSuccess(null));

  @override
  Future<FirestoreResult<void>> cancel(
    String eventId, {
    required String reason,
    required String actorId,
  }) async => _s.answer('cancel', [
    eventId,
    reason,
    actorId,
  ], const FirebaseSuccess(null));

  @override
  Future<FirestoreResult<void>> unpublish(String eventId) async =>
      _s.answer('unpublish', [eventId], const FirebaseSuccess(null));

  @override
  Future<FirestoreResult<EventModel>> getEvent(String eventId) async =>
      _s.answer('getEvent', [eventId], FirebaseSuccess(event));
}

final class _Posts extends Fake implements PostRepository {
  _Posts(this._s);

  final _Script _s;

  @override
  Future<FirestoreResult<PostModel>> create(
    PostDraft draft, {
    required String authorId,
    required String clubId,
    required String postId,
  }) async => _s.answer(
    'create',
    [postId, authorId, clubId],
    FirebaseSuccess(
      PostModel(
        id: postId,
        clubId: clubId,
        authorId: authorId,
        text: draft.text,
        type: draft.type,
        title: draft.title,
        pushSent: draft.pushSent,
      ),
    ),
  );

  @override
  Future<FirestoreResult<void>> pin(
    String postId, {
    required String clubId,
  }) async => _s.answer('pin', [postId, clubId], const FirebaseSuccess(null));

  @override
  Future<FirestoreResult<void>> unpin(
    String postId, {
    required String clubId,
  }) async => _s.answer('unpin', [postId, clubId], const FirebaseSuccess(null));

  @override
  Future<FirestoreResult<void>> softDeletePost(
    String postId, {
    required String actorId,
    required String clubId,
  }) async => _s.answer('softDeletePost', [
    postId,
    actorId,
    clubId,
  ], const FirebaseSuccess(null));
}

final class _Comments extends Fake implements CommentRepository {
  _Comments(this._s);

  final _Script _s;

  @override
  Future<FirestoreResult<void>> softDeleteComment(
    String commentId, {
    required String postId,
    required String actorId,
  }) async => _s.answer('softDeleteComment', [
    commentId,
    postId,
    actorId,
  ], const FirebaseSuccess(null));
}

final class _Clubs extends Fake implements ClubRepository {
  _Clubs(this._s);

  final _Script _s;

  @override
  Future<FirestoreResult<ClubModel>> getClub(String clubId) async =>
      _s.answer('getClub', [clubId], const FirebaseSuccess(_club));
}

final class _Recipients extends Fake implements RecipientResolver {
  _Recipients(this._s);

  final _Script _s;

  static const List<String> ids = ['u_x', 'u_y'];

  @override
  Future<FirestoreResult<RecipientSet>> eventNew(
    EventModel event,
    ClubModel club,
  ) async => _s.answer('eventNew', [
    event.id,
    club.id,
  ], const FirebaseSuccess(RecipientSet(ids: ids)));

  @override
  Future<FirestoreResult<List<String>>> rsvpUsersOf(
    String eventId,
    String clubId,
    Set<RsvpStatus> statuses,
  ) async => _s.answer('rsvpUsersOf', [
    eventId,
    clubId,
    [for (final status in statuses) status.json].join(','),
  ], const FirebaseSuccess(ids));

  @override
  Future<FirestoreResult<List<String>>> membersOf(
    String clubId, {
    String? excludeUserId,
  }) async => _s.answer('membersOf', [
    clubId,
    excludeUserId,
  ], const FirebaseSuccess(ids));
}

EventModel _event(String clubId) => EventModel(
  id: _eventId,
  clubId: clubId,
  createdBy: _actor,
  title: 'Flutter Atölyesi',
  type: EventType.training,
  startsAt: DateTime.utc(2026, 10, 20, 15),
  endsAt: DateTime.utc(2026, 10, 20, 17),
  coverPalette: ClubPalette.red,
  coverPattern: ClubPattern.dots,
  status: EventStatus.published,
);

const ClubModel _club = ClubModel(
  id: _clubId,
  name: 'Robotik',
  nameLower: 'robotik',
  categoryId: 'k01',
  iconName: 'robot',
  palette: ClubPalette.red,
  pattern: ClubPattern.dots,
  founded: 2020,
  presidentId: 'u_pres',
);

/// Ayar testlerinin kulüp belgesi (ham; sayaç ve kilitli alanlar dahil).
Json _clubDoc({bool isDeleted = false}) => {
  'name': 'Robotik',
  'nameLower': 'robotik',
  'categoryId': 'k01',
  'iconName': 'robot',
  'palette': 'red',
  'pattern': 'dots',
  'founded': 2020,
  'presidentId': 'u_pres',
  'memberCount': 5,
  'summary': 'Eski özet',
  'about': 'Eski metin',
  'conditions': <String>[],
  'social': <String, Object?>{},
  'approvalRequired': true,
  'applicationsOpen': true,
  'requireNote': false,
  'status': 'active',
  'createdAt': Timestamp.fromDate(DateTime.utc(2026)),
  'updatedAt': Timestamp.fromDate(DateTime.utc(2026)),
  'isDeleted': isDeleted,
  'deletedAt': null,
  'deletedBy': null,
};

void main() {
  late _Script script;
  late _Events events;
  late FakeNotificationDispatcher dispatcher;
  late FakeFirebaseFirestore db;
  late RecordingFirestoreService service;
  late ManagementRepository repository;

  ManagementRepository repositoryOn(FirestoreService firestore) =>
      FirebaseManagementRepository(
        firestore: firestore,
        memberships: _Memberships(script),
        events: events,
        posts: _Posts(script),
        comments: _Comments(script),
        clubs: _Clubs(script),
        activity: FirebaseActivityRepository(firestore),
        notifications: dispatcher,
        recipients: _Recipients(script),
      );

  setUp(() {
    script = _Script();
    events = _Events(script);
    dispatcher = FakeNotificationDispatcher();
    db = FakeFirebaseFirestore();
    service = RecordingFirestoreService(FirebaseFirestoreService(db));
    repository = repositoryOn(service);
  });

  group('T-30 · ManagementRepository · sözleşme', () {
    test('PLAN §10.4 tablosundaki 19 üye arayüzde aynı imzayla var; başka üye '
        'yok', () {
      final plan = readPlanRepositoryMembers('$ManagementRepository');

      expect(plan, hasLength(19));
      expect(interfaceMembers(_interface, '$ManagementRepository').toSet(), {
        for (final row in plan) normalizeDartSource(row.signature),
      });
    });

    test('arayüzde ve uygulamada silme üyesi yok (D-10)', () {
      expect(deleteIdentifiersIn(_interface), isEmpty);
      expect(deleteIdentifiersIn(_implementation), isEmpty);
    });

    test('isReadOnly: yalnızca danışman salt okunur (TST-26, Q-09)', () {
      expect(
        {
          for (final access in ClubAccess.values)
            access: repository.isReadOnly(access),
        },
        {
          for (final access in ClubAccess.values)
            access: access == ClubAccess.advisor,
        },
      );
    });
  });

  group('T-30 · devredilen yazımlar', () {
    final rows =
        <
          String,
          (Future<FirestoreResult<void>> Function(ManagementRepository), String)
        >{
          'approveApplication → MembershipRepository.approve (M5)': (
            (r) => r.approveApplication(
              clubId: _clubId,
              userId: _ayse,
              actorId: _actor,
            ),
            'approve c01 u_ayse u_board',
          ),
          'rejectApplication → reject (M6)': (
            (r) => r.rejectApplication(
              clubId: _clubId,
              userId: _ayse,
              actorId: _actor,
              reason: RejectReason.quota,
              rejectNote: 'Kontenjan doldu',
            ),
            'reject c01 u_ayse u_board quota Kontenjan doldu',
          ),
          'undoDecision → undoDecision (M12 a)': (
            (r) => r.undoDecision(
              clubId: _clubId,
              userId: _ayse,
              actorId: _actor,
            ),
            'undoDecision c01 u_ayse u_board',
          ),
          'undoRemoval → undoRemoval (M12 b)': (
            (r) =>
                r.undoRemoval(clubId: _clubId, userId: _ayse, actorId: _actor),
            'undoRemoval c01 u_ayse u_board',
          ),
          'removeMember (danışman aktörü de) → remove (M9; ret kararı '
              'MembershipRepository + Rules)': (
            (r) => r.removeMember(
              clubId: _clubId,
              userId: _ayse,
              actorId: 'u_advisor',
              actorRole: ClubRole.advisor,
              rejectNote: 'Kurallar',
            ),
            'remove c01 u_ayse u_advisor advisor false Kurallar',
          ),
          'changeRole → changeRole (M10)': (
            (r) => r.changeRole(
              clubId: _clubId,
              userId: _ayse,
              role: ClubRole.board,
              actorId: 'u_pres',
            ),
            'changeRole c01 u_ayse board u_pres',
          ),
          'transferPresidency → transferPresidency (M11)': (
            (r) => r.transferPresidency(
              clubId: _clubId,
              fromUserId: 'u_pres',
              toUserId: _ayse,
              actorId: 'u_pres',
            ),
            'transferPresidency c01 u_pres u_ayse u_pres',
          ),
          'unpublishEvent → EventRepository.unpublish (K-F)': (
            (r) => r.unpublishEvent(_eventId),
            'unpublish e01',
          ),
          'pinPost → PostRepository.pin': (
            (r) => r.pinPost(_postId, clubId: _clubId),
            'pin p01 c01',
          ),
          'unpinPost → unpin (TST-53)': (
            (r) => r.unpinPost(_postId, clubId: _clubId),
            'unpin p01 c01',
          ),
          'moderatePost → softDeletePost (DLG-29)': (
            (r) => r.moderatePost(_postId, clubId: _clubId, actorId: _actor),
            'softDeletePost p01 u_board c01',
          ),
          'moderateComment → CommentRepository.softDeleteComment': (
            (r) => r.moderateComment(
              'k01',
              postId: _postId,
              clubId: _clubId,
              actorId: _actor,
            ),
            'softDeleteComment k01 p01 u_board',
          ),
        };
    for (final MapEntry(key: name, value: (invoke, call)) in rows.entries) {
      test('$name: argümanlar ve sonuç (başarı / ret) aynen; fan-out ve '
          'kendi yazımı yok', () async {
        expect((await invoke(repository)).isSuccess, isTrue);
        script.fail[call] = FirestoreError.permissionDenied;
        expect(
          (await invoke(repository)).errorOrNull,
          FirestoreError.permissionDenied,
        );

        expect(script.calls, [call, call]);
        expect(dispatcher.calls, isEmpty);
        expect(service.outsideWrites + service.transactions, 0);
      });
    }
  });

  group('T-30 · toplu karar (DLG-17)', () {
    test('approveMany: her başvuru ayrı işlem, sırayla, tekilleştirilmiş; '
        'conflict → conflicted, başka hata → failed', () async {
      script.fail
        ..['approve c01 u2 u_board'] = FirestoreError.conflict
        ..['approve c01 u3 u_board'] = FirestoreError.permissionDenied;

      final result = await repository.approveMany(
        clubId: _clubId,
        userIds: const ['u1', 'u2', 'u3', 'u1', 'u4'],
        actorId: _actor,
      );

      expect(
        result.dataOrNull,
        const BulkResult(
          succeeded: ['u1', 'u4'],
          conflicted: ['u2'],
          failed: ['u3'],
        ),
      );
      expect(script.calls, [
        for (final user in ['u1', 'u2', 'u3', 'u4'])
          'approve c01 $user u_board',
      ]);
    });

    test('rejectMany: her başvuruya aynı neden ve not; geçersiz kulüp / '
        'aktör → invalidArgument, hiçbir karar verilmez', () async {
      final result = await repository.rejectMany(
        clubId: _clubId,
        userIds: const ['u1', 'u2'],
        actorId: _actor,
        reason: RejectReason.criteria,
        rejectNote: 'Not',
      );
      expect(result.dataOrNull, const BulkResult(succeeded: ['u1', 'u2']));
      expect(script.calls, [
        'reject c01 u1 u_board criteria Not',
        'reject c01 u2 u_board criteria Not',
      ]);

      script.calls.clear();
      final invalid = await repository.approveMany(
        clubId: 'a/b',
        userIds: const ['u1'],
        actorId: _actor,
      );
      expect(invalid.errorOrNull, FirestoreError.invalidArgument);
      expect(script.calls, isEmpty);
    });
  });

  group('T-30 · etkinlik yayın / iptal + fan-out', () {
    Future<FirestoreResult<void>> publish({bool notify = true}) =>
        repository.publishEvent(
          _eventId,
          clubId: _clubId,
          actorId: _actor,
          notifyMembers: notify,
        );

    test('publishEvent(notifyMembers): yayın kesinleşince etkinlik + kulüp '
        'okunur, alıcılar eventNew → notifyEventNew', () async {
      expect((await publish()).isSuccess, isTrue);

      expect(script.calls, [
        'publish e01 u_board',
        'getEvent e01',
        'getClub c01',
        'eventNew e01 c01',
      ]);
      expect(dispatcher.calls, [
        const DispatchCall(
          kind: 'notifyEventNew',
          args: {'eventId': _eventId, 'clubId': _clubId},
          recipients: _Recipients.ids,
        ),
      ]);
    });

    test('publishEvent: bildirimsiz yayın, yayın reddi (Rules / danışman) ve '
        'başka kulübün etkinliği fan-out yapmaz; fan-out hatası sonucu '
        'bozmaz', () async {
      expect((await publish(notify: false)).isSuccess, isTrue);
      expect(script.calls, ['publish e01 u_board']);

      script
        ..calls.clear()
        ..fail['publish'] = FirestoreError.permissionDenied;
      expect((await publish()).errorOrNull, FirestoreError.permissionDenied);
      expect(script.calls, ['publish e01 u_board']);

      script
        ..calls.clear()
        ..fail.clear();
      events.event = _event('c99');
      expect((await publish()).isSuccess, isTrue);
      expect(script.calls, ['publish e01 u_board', 'getEvent e01']);
      expect(dispatcher.calls, isEmpty);

      events.event = _event(_clubId);
      script.fail['eventNew'] = FirestoreError.permissionDenied;
      expect((await publish()).isSuccess, isTrue);
      expect(dispatcher.calls, isEmpty);

      script.fail.clear();
      dispatcher.failNextFanOut = FirestoreError.unavailable;
      expect((await publish()).isSuccess, isTrue);
      expect(dispatcher.calls.single.kind, 'notifyEventNew');
    });

    test('cancelEvent: iptal kesinleşince going + waitlist kayıtlıları '
        'notifyEventCancelled; iptal reddinde alıcı okunmaz; fan-out hatası '
        'sonucu bozmaz', () async {
      Future<FirestoreResult<void>> cancel() => repository.cancelEvent(
        _eventId,
        clubId: _clubId,
        reason: 'Hava',
        actorId: _actor,
      );

      expect((await cancel()).isSuccess, isTrue);
      expect(script.calls, [
        'cancel e01 Hava u_board',
        'rsvpUsersOf e01 c01 going,waitlist',
      ]);
      expect(dispatcher.calls, [
        const DispatchCall(
          kind: 'notifyEventCancelled',
          args: {'eventId': _eventId, 'clubId': _clubId},
          recipients: _Recipients.ids,
        ),
      ]);

      dispatcher.failNextFanOut = FirestoreError.unavailable;
      expect((await cancel()).isSuccess, isTrue);

      script
        ..calls.clear()
        ..fail['cancel'] = FirestoreError.failedPrecondition;
      dispatcher.calls.clear();
      expect((await cancel()).errorOrNull, FirestoreError.failedPrecondition);
      expect(script.calls, ['cancel e01 Hava u_board']);
      expect(dispatcher.calls, isEmpty);
    });
  });

  group('T-30 · publishPost', () {
    Future<FirestoreResult<PostModel>> publish(PostDraft draft) =>
        repository.publishPost(
          draft,
          clubId: _clubId,
          authorId: _actor,
          postId: _postId,
        );

    test('bildirimli duyuru: oluşturma kesinleşince üyeler (yazar hariç) '
        'notifyAnnouncement; yazılan model döner', () async {
      final result = await publish(
        const PostDraft(
          type: PostType.announcement,
          title: 'Genel kurul',
          text: 'Cuma 18.00',
          pushSent: true,
        ),
      );

      expect(result.dataOrNull?.id, _postId);
      expect(script.calls, ['create p01 u_board c01', 'membersOf c01 u_board']);
      expect(dispatcher.calls, [
        const DispatchCall(
          kind: 'notifyAnnouncement',
          args: {'postId': _postId, 'clubId': _clubId},
          recipients: _Recipients.ids,
        ),
      ]);
    });

    test('bildirimsiz duyuru, gönderi ve oluşturma reddi fan-out '
        'yapmaz', () async {
      await publish(
        const PostDraft(
          type: PostType.announcement,
          title: 'Not',
          text: 'Sessiz duyuru',
        ),
      );
      await publish(const PostDraft(type: PostType.post, text: 'Merhaba'));
      script.fail['create'] = FirestoreError.ruleViolation;
      final denied = await publish(
        const PostDraft(
          type: PostType.announcement,
          title: 'Kota',
          text: 'Günün hakkı doldu',
          pushSent: true,
        ),
      );

      expect(denied.errorOrNull, FirestoreError.ruleViolation);
      expect(script.calls, everyElement(startsWith('create ')));
      expect(dispatcher.calls, isEmpty);
    });
  });

  group('T-30 · updateClubSettings (MGT-09)', () {
    Future<FirestoreResult<void>> update(
      ClubSettingsPatch patch, {
      ManagementRepository? on,
    }) => (on ?? repository).updateClubSettings(
      _clubId,
      patch,
      actorId: _actor,
    );

    Future<Json> club() async => (await db.doc(_clubPath).get()).data()!;

    Future<List<Json>> activity() async => [
      for (final doc in (await db.collection('activity').get()).docs)
        doc.data(),
    ];

    test('tek batch: kulüpte yalnızca yama alanları + updatedAt değişir; '
        'settings_changed günlüğü (otomatik kimlik, refs boş) aynı '
        'batch', () async {
      await db.doc(_clubPath).set(_clubDoc());
      final before = await club();

      final result = await update(
        const ClubSettingsPatch(
          summary: 'Yeni özet',
          conditions: ['Öğrenci olmak'],
          social: ClubSocialModel(instagram: '@gu_robotik'),
          applicationsOpen: false,
          palette: ClubPalette.slate,
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(service.outsideWrites, 1);
      expect(service.transactions, 0);
      final after = await club();
      expect(
        {
          for (final key in after.keys)
            if (after[key].toString() != before[key].toString()) key,
        },
        {
          'summary',
          'conditions',
          'social',
          'applicationsOpen',
          'palette',
          'updatedAt',
        },
      );
      expect(after, containsPair('social', {'instagram': '@gu_robotik'}));
      final entries = await activity();
      expect(entries, hasLength(1));
      expect(entries.single, {
        'clubId': _clubId,
        'actorId': _actor,
        'kind': 'settings_changed',
        'refs': <String, Object?>{},
        'createdAt': isA<Timestamp>(),
      });
    });

    final invalid = <String, ClubSettingsPatch>{
      'boş yama': const ClubSettingsPatch(),
      'özet sınırı aşıyor': ClubSettingsPatch(
        summary: 'a' * (Limits.clubSummaryMax + 1),
      ),
      'hakkında sınırı aşıyor': ClubSettingsPatch(
        about: 'a' * (Limits.clubAboutMax + 1),
      ),
      'koşul sayısı sınırı aşıyor': ClubSettingsPatch(
        conditions: List.filled(Limits.conditionsMax + 1, 'Madde'),
      ),
      'instagram biçimi': const ClubSettingsPatch(
        social: ClubSocialModel(instagram: 'gu robotik'),
      ),
      'e-posta biçimi': const ClubSettingsPatch(
        social: ClubSocialModel(email: 'robotik'),
      ),
      'web şeması': const ClubSettingsPatch(
        social: ClubSocialModel(web: 'ftp://gu.edu.tr'),
      ),
      'boş kapak tohumu': const ClubSettingsPatch(coverSeed: ''),
    };
    for (final MapEntry(key: name, value: patch) in invalid.entries) {
      test('$name → invalidArgument, okuma ve yazım yok', () async {
        await db.doc(_clubPath).set(_clubDoc());

        expect(
          (await update(patch)).errorOrNull,
          FirestoreError.invalidArgument,
        );
        expect(service.outsideWrites, 0);
        expect(await activity(), isEmpty);
      });
    }

    test('kulüp yok / silinmiş → notFound; Rules reddi (danışman, üye, '
        'askıdaki kulüp) → permissionDenied; üçünde de yazım yok', () async {
      const patch = ClubSettingsPatch(requireNote: true);
      expect((await update(patch)).errorOrNull, FirestoreError.notFound);

      await db.doc(_clubPath).set(_clubDoc(isDeleted: true));
      expect((await update(patch)).errorOrNull, FirestoreError.notFound);
      expect(service.outsideWrites, 0);

      await db.doc(_clubPath).set(_clubDoc());
      final denied = repositoryOn(
        FirebaseFirestoreService(
          FailingBatchFirestore(
            db,
            error: firestoreException('permission-denied'),
          ),
        ),
      );
      expect(
        (await update(patch, on: denied)).errorOrNull,
        FirestoreError.permissionDenied,
      );
      expect((await club())['requireNote'], isFalse);
      expect(await activity(), isEmpty);
    });
  });
}

// T-30 · ManagementRepository (kompozisyon): üyelik kararları, rol / devir,
// etkinlik geçişleri, gönderi / yorum moderasyonu olduğu gibi devredilir
// (sonuç değişmez, fan-out yok); toplu karar her başvuru için ayrı işlem
// (`BulkResult`); çok alıcılı bildirim (`event_new`, `event_cancelled`,
// `announcement`) yalnızca asıl yazım kesinleşince ve en iyi çabayla; kulüp
// ayarı tek batch (yalnızca yama alanları + `updatedAt` + `settings_changed`
// günlüğü) ve sınır denetimleri; danışman salt okunur (PLAN §10.4, §10.5;
// rules-spec §3.3, §5; docs/plans/T-30.md §4 a, c; Q-09, D-10, W-83).
// T-36: kulüp görselleri (`updateClubMedia`) — ön denetim dosya gönderilmeden,
// ön okuma (yok / silinmiş → yükleme yok), `clubs/{clubId}/{yeni ad}`
// yüklemeleri yalnızca `clubId` + `uploaderId` üst verisiyle, sonra yollar +
// günlük tek batch; kısmi hata dosyayı silmez (D-10).
//
// Devredilen repository'ler ve alıcı çözücü çağrıları kaydeden el yazımı
// çiftlerdir (`_Script`); ayar yazımı `fake_cloud_firestore` + kayıt tutan
// servis çiftiyle. Yetki Security Rules'tadır: burada reddin olduğu gibi
// döndüğü doğrulanır.
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../fakes/fake_app_clock.dart';
import '../fakes/fake_notification_dispatcher.dart';
import '../fakes/recording_firestore_service.dart';
import '../fakes/recording_storage_service.dart';
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

/// Görsel yüklemesinin sabit saati ve rastgele baytları (dosya adı:
/// `20261015T090000Z_<16 hex>`; ilk 8 bayt logo, sonraki 8 bayt kapak).
final DateTime _uploadedAt = DateTime.utc(2026, 10, 15, 9);
const List<int> _randomBytes = [
  0x0a, 0x1b, 0x2c, 0x3d, 0x4e, 0x5f, 0x60, 0x71, //
  0x81, 0x92, 0xa3, 0xb4, 0xc5, 0xd6, 0xe7, 0xf8,
];
const String _logoPath = 'clubs/c01/20261015T090000Z_0a1b2c3d4e5f6071.jpg';
const String _coverPath = 'clubs/c01/20261015T090000Z_8192a3b4c5d6e7f8.png';
const List<String> _invalidIds = ['', 'c/1', '..', '__id__'];
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
  Future<FirestoreResult<ClubModel>> getClub(
    String clubId, {
    bool forceRefresh = false,
  }) async => _s.answer('getClub', [clubId], const FirebaseSuccess(_club));
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
  late RecordingStorageService storage;
  late ManagementRepository repository;

  ManagementRepository repositoryOn(FirestoreService firestore) =>
      FirebaseManagementRepository(
        firestore: firestore,
        storage: storage,
        clock: FakeAppClock(_uploadedAt),
        // 16 bayt: aynı saniyede yüklenen logo ve kapağın adları ayrışır.
        random: SequenceRandom(_randomBytes),
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
    storage = RecordingStorageService();
    repository = repositoryOn(service);
  });

  group('T-30 · ManagementRepository · sözleşme', () {
    test('PLAN §10.4 tablosundaki 19 üye arayüzde aynı imzayla var; tablo '
        'dışı tek üye T-36 `updateClubMedia` (PLAN §5 satır 731)', () {
      final plan = readPlanRepositoryMembers('$ManagementRepository');
      final planned = {
        for (final row in plan) normalizeDartSource(row.signature),
      };
      final members = interfaceMembers(
        _interface,
        '$ManagementRepository',
      ).toSet();

      expect(plan.length, greaterThanOrEqualTo(19));
      expect(members.containsAll(planned), isTrue);
      expect(members.difference(planned).map((m) => m.split('(').first), {
        if (!planned.any((m) => m.contains('updateClubMedia(')))
          'Future<MediaUpdateResult<ClubMediaPaths>>updateClubMedia',
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

    test('SHT-31 şablona dönüş: clearCoverPath → coverPath null, logoPath '
        'dokunulmaz; günlük aynı batch (dosya silinmez — D-10)', () async {
      await db.doc(_clubPath).set({
        ..._clubDoc(),
        'logoPath': 'clubs/c01/logo.jpg',
        'coverPath': 'clubs/c01/kapak.png',
      });

      final result = await update(
        const ClubSettingsPatch(
          pattern: ClubPattern.waves,
          clearCoverPath: true,
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(service.outsideWrites, 1);
      final after = await club();
      expect(after.containsKey('coverPath'), isTrue);
      expect(after['coverPath'], isNull);
      expect(after['logoPath'], 'clubs/c01/logo.jpg');
      expect(after['pattern'], 'waves');
      expect(await activity(), hasLength(1));
      expect(
        const ClubSettingsPatch(clearCoverPath: true).toJson(),
        {'coverPath': null},
      );
      expect(const ClubSettingsPatch().isEmpty, isTrue);
    });

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

  group('T-36 · updateClubMedia (MGT-09)', () {
    ClubMediaUpload image(String contentType, [int length = 3]) =>
        ClubMediaUpload(bytes: Uint8List(length), contentType: contentType);

    Future<MediaUpdateResult<ClubMediaPaths>> media({
      ManagementRepository? on,
      String clubId = _clubId,
      String uploaderId = _actor,
      ClubMediaUpload? logo,
      ClubMediaUpload? cover,
    }) => (on ?? repository).updateClubMedia(
      clubId,
      uploaderId: uploaderId,
      logo: logo,
      cover: cover,
    );

    Future<Json> club() async => (await db.doc(_clubPath).get()).data()!;

    Future<List<Json>> activity() async => [
      for (final doc in (await db.collection('activity').get()).docs)
        doc.data(),
    ];

    test('logo + kapak: önce logo, sonra kapak clubs/{clubId}/{yeni ad} '
        'yoluna yalnızca clubId + uploaderId üst verisiyle yüklenir; yollar + '
        'updatedAt ve settings_changed günlüğü tek batch', () async {
      await db.doc(_clubPath).set(_clubDoc());
      final before = await club();
      final logo = image('image/jpeg');

      final result = await media(logo: logo, cover: image('image/png'));

      expect(
        result.dataOrNull,
        const ClubMediaPaths(logoPath: _logoPath, coverPath: _coverPath),
      );
      expect(storage.uploads.map((u) => u.path), [_logoPath, _coverPath]);
      expect(storage.uploads.first.bytes, same(logo.bytes));
      expect(storage.uploads.map((u) => u.contentType), [
        'image/jpeg',
        'image/png',
      ]);
      for (final upload in storage.uploads) {
        // Rules: `metadata.clubId == klasör`, `uploaderId == request.auth.uid`.
        expect(upload.customMetadata, {
          'clubId': _clubId,
          'uploaderId': _actor,
        });
        expect(StoragePaths.isClubFile(upload.path, _clubId), isTrue);
      }
      expect(service.outsideWrites, 1);
      expect(service.transactions, 0);
      final after = await club();
      expect(
        {
          for (final key in after.keys)
            if (after[key].toString() != before[key].toString()) key,
        },
        {'logoPath', 'coverPath', 'updatedAt'},
      );
      expect(after, containsPair('logoPath', _logoPath));
      expect(after, containsPair('coverPath', _coverPath));
      expect(await activity(), [
        {
          'clubId': _clubId,
          'actorId': _actor,
          'kind': 'settings_changed',
          'refs': <String, Object?>{},
          'createdAt': isA<Timestamp>(),
        },
      ]);
    });

    test('yalnızca kapak: logoPath yazılmaz (eski değer kalır), sonuçta '
        'logoPath null', () async {
      await db.doc(_clubPath).set({..._clubDoc(), 'logoPath': 'eski'});

      final result = await media(cover: image('image/webp'));

      const cover = 'clubs/c01/20261015T090000Z_0a1b2c3d4e5f6071.webp';
      expect(result.dataOrNull, const ClubMediaPaths(coverPath: cover));
      expect(storage.uploads.single.path, cover);
      final after = await club();
      expect(after['logoPath'], 'eski');
      expect(after['coverPath'], cover);
    });

    test('ön denetim dosya gönderilmeden ve okumadan: geçersiz kimlik / '
        'görsel yok → belge hatası; izinsiz tür, boş, sınırdaki dosya → '
        'yükleme hatası (kapak geçersizse logo da yüklenmez)', () async {
      await db.doc(_clubPath).set(_clubDoc());
      final logo = image('image/jpeg');

      for (final id in _invalidIds) {
        for (final result in [
          await media(clubId: id, logo: logo),
          await media(uploaderId: id, logo: logo),
        ]) {
          expect(
            result.errorOrNull,
            const MediaDocumentError(FirestoreError.invalidArgument),
            reason: 'kimlik "$id"',
          );
        }
      }
      expect(
        (await media()).errorOrNull,
        const MediaDocumentError(FirestoreError.invalidArgument),
      );
      final rejected = <ClubMediaUpload, StorageError>{
        image('image/gif'): StorageError.invalidType,
        image('image/svg+xml'): StorageError.invalidType,
        image('image/jpeg', 0): StorageError.noFile,
        // Storage Rules `size < imageMaxBytes`: sınırın kendisi de ret.
        image('image/jpeg', Limits.imageMaxBytes): StorageError.sizeLimit,
      };
      for (final MapEntry(key: bad, value: error) in rejected.entries) {
        expect((await media(logo: bad)).errorOrNull, MediaUploadError(error));
        expect(
          (await media(logo: logo, cover: bad)).errorOrNull,
          MediaUploadError(error),
        );
      }
      expect(storage.uploads, isEmpty);
      expect(service.outsideWrites, 0);
      expect(await activity(), isEmpty);
    });

    test('kulüp yok / silinmiş → notFound, dosya gönderilmez (yetim dosya '
        'yok)', () async {
      expect(
        (await media(logo: image('image/jpeg'))).errorOrNull,
        const MediaDocumentError(FirestoreError.notFound),
      );
      await db.doc(_clubPath).set(_clubDoc(isDeleted: true));
      expect(
        (await media(logo: image('image/jpeg'))).errorOrNull,
        const MediaDocumentError(FirestoreError.notFound),
      );
      expect(storage.uploads, isEmpty);
      expect(service.outsideWrites, 0);
    });

    test('yükleme reddi (Storage Rules: yönetici değil) → yükleme hatası, '
        'yol yazılmaz; kapak reddedilirse yüklenen logo yerinde kalır '
        '(silinmez — D-10) ama logoPath da yazılmaz', () async {
      await db.doc(_clubPath).set(_clubDoc());
      final before = await club();

      storage.nextError = StorageError.unauthorized;
      expect(
        (await media(logo: image('image/jpeg'))).errorOrNull,
        const MediaUploadError(StorageError.unauthorized),
      );
      expect(storage.uploads, hasLength(1));

      storage.uploads.clear();
      // Logo geçer, kapak reddedilir.
      final split = FirebaseManagementRepository(
        firestore: service,
        storage: _FailSecondUpload(storage),
        clock: FakeAppClock(_uploadedAt),
        random: SequenceRandom(_randomBytes),
        memberships: _Memberships(script),
        events: events,
        posts: _Posts(script),
        comments: _Comments(script),
        clubs: _Clubs(script),
        activity: FirebaseActivityRepository(service),
        notifications: dispatcher,
        recipients: _Recipients(script),
      );
      expect(
        (await split.updateClubMedia(
          _clubId,
          uploaderId: _actor,
          logo: image('image/jpeg'),
          cover: image('image/png'),
        )).errorOrNull,
        const MediaUploadError(StorageError.unauthorized),
      );
      expect(storage.uploads.map((u) => u.path), [_logoPath, _coverPath]);
      expect(service.outsideWrites, 0);
      expect(await club(), before);
      expect(await activity(), isEmpty);
    });

    test('askıdaki kulüp → permissionDenied, dosya gönderilmez (yetim dosya '
        'yok — T-36 güvenlik incelemesi)', () async {
      await db.doc(_clubPath).set({..._clubDoc(), 'status': 'suspended'});
      final before = await club();

      expect(
        (await media(
          logo: image('image/jpeg'),
          cover: image('image/png'),
        )).errorOrNull,
        const MediaDocumentError(FirestoreError.permissionDenied),
      );
      expect(storage.uploads, isEmpty);
      expect(service.outsideWrites, 0);
      expect(await club(), before);
      expect(await activity(), isEmpty);
    });

    test('dosyalar yüklendi ama yol yazımı reddedildi (Rules: danışman / '
        'yönetici değil) → belge hatası; dosyalar yerinde, alanlar eski '
        'değerinde', () async {
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
        (await media(
          on: denied,
          logo: image('image/jpeg'),
          cover: image('image/png'),
        )).errorOrNull,
        const MediaDocumentError(FirestoreError.permissionDenied),
      );
      expect(storage.uploads, hasLength(2));
      final after = await club();
      expect(after.containsKey('logoPath'), isFalse);
      expect(after.containsKey('coverPath'), isFalse);
      expect(await activity(), isEmpty);
    });
  });
}

/// İlk yüklemeyi [_inner]'a geçiren, ikinciyi (kapak) Storage Rules reddi
/// gibi düşüren servis; iki yükleme de iç servisin `uploads` listesine
/// kaydedilir.
final class _FailSecondUpload implements StorageService {
  _FailSecondUpload(this._inner);

  final RecordingStorageService _inner;

  @override
  Future<StorageResult<String>> upload({
    required String path,
    required Uint8List bytes,
    required String contentType,
    Map<String, String> customMetadata = const {},
    void Function(double fraction)? onProgress,
  }) {
    if (_inner.uploads.isNotEmpty) {
      _inner.nextError = StorageError.unauthorized;
    }
    return _inner.upload(
      path: path,
      bytes: bytes,
      contentType: contentType,
      customMetadata: customMetadata,
      onProgress: onProgress,
    );
  }

  @override
  Future<StorageResult<String>> downloadUrl(String path) =>
      _inner.downloadUrl(path);

  @override
  Future<StorageResult<StorageFileInfo>> metadata(String path) =>
      _inner.metadata(path);
}

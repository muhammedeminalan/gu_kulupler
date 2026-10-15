// T-37 · FirebaseReportModeration (AdminRepository şikayet üyeleri;
// `docs/plans/T-37.md` §4 a.6, a.8): grup çözümü tek batch (roadmap), hedefin
// o anki tüm açık şikayetleri çözülür (T-40), `removed` gönderi / yorumu
// gizler (sayaç değişmez; zaten gizliyse gizleme yazılmaz), `report_resolved`
// alıcıları (şikayetçiler, tekil, tek olay anahtarı — W-84), bildirim
// yazılamazsa çözüm kesinleşmez, parçalama, hedef / kimlik / oturum
// denetimleri, listeler ve hata eşlemesi.
//
// Gerçek zincir: `FirebaseFirestoreService` + `fake_cloud_firestore` +
// `ClientFanOutDispatcher` + `FirebaseNotificationRepository`. "Tek batch"
// `RecordingFirestoreService` sayaçlarıyla kanıtlanır (commitBatch = 1 dış
// yazım çağrısı). Rules reddi (claim'siz) `FailingBatchFirestore` ile kurulur.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../fakes/fake_app_clock.dart';
import '../fakes/recording_firestore_service.dart';
import '../fakes/recording_storage_service.dart';
import '../fakes/scripted_auth_service.dart';
import '../fakes/sdk_firestore_stubs.dart';

const String _super = 'u_super';
const String _postId = 'p01';
const String _clubId = 'c01';

const ReportTarget _post = (
  type: ReportTargetType.post,
  id: _postId,
  clubId: _clubId,
);

final DateTime _now = DateTime.utc(2026, 10, 13, 9);

/// Alıcıları dağıtıcının çözdüğü üyeler bu testte çağrılmaz.
final class _NoResolver extends Fake implements RecipientResolver {}

void main() {
  late FakeFirebaseFirestore db;
  late RecordingFirestoreService recording;
  late ScriptedAuthService auth;
  late FirebaseReportModeration moderation;

  FirebaseReportModeration moderationOn(FirestoreService firestore) {
    final clock = FakeAppClock(_now);
    return FirebaseReportModeration(
      firestore: firestore,
      auth: auth,
      posts: FirebasePostRepository(
        firestore,
        RecordingStorageService(),
        FirebaseActivityRepository(firestore),
        FirebaseAnnouncementCounterRepository(firestore, clock),
        clock,
        SequenceRandom(const [0]),
      ),
      comments: FirebaseCommentRepository(firestore, clock),
      dispatcher: ClientFanOutDispatcher(
        writer: FirebaseNotificationRepository(firestore),
        recipients: _NoResolver(),
      ),
    );
  }

  /// [reporter] kullanıcısının [type] / [targetId] şikayeti; kimlik
  /// verilmezse kanonik (`FirestoreIds.report`).
  Future<String> seedReport(
    String reporter, {
    ReportTargetType type = ReportTargetType.post,
    String targetId = _postId,
    ReportStatus status = ReportStatus.open,
    String? id,
    int minute = 0,
  }) async {
    final reportId = id ?? FirestoreIds.report(reporter, type.json, targetId);
    await db.collection('reports').doc(reportId).set({
      'targetType': type.json,
      'targetId': targetId,
      if (type != ReportTargetType.user) 'targetClubId': _clubId,
      'reporterId': reporter,
      'reason': ReportReason.spam.json,
      'note': '',
      'status': status.json,
      if (status == ReportStatus.resolved) ...{
        'action': ReportAction.dismissed.json,
        'resolvedBy': 'u_other_super',
        'resolvedAt': Timestamp.fromDate(DateTime.utc(2026, 9)),
      },
      ...BaseFieldsPayload.create(),
      'createdAt': Timestamp.fromDate(DateTime.utc(2026, 10, 13, 8, minute)),
    });
    return reportId;
  }

  Future<void> seedContent(
    String collection,
    String id, {
    bool hidden = false,
  }) => db.collection(collection).doc(id).set({
    'clubId': _clubId,
    'authorId': 'u_author',
    'isHidden': hidden,
    'hiddenBy': hidden ? 'u_other_super' : null,
    'hiddenAt': null,
    'commentCount': 2,
    'likeCount': 3,
    'pinned': true,
    ...BaseFieldsPayload.create(),
  });

  Future<Json> report(String id) async =>
      (await db.collection('reports').doc(id).get()).data()!;

  Future<Json> content(String collection, String id) async =>
      (await db.collection(collection).doc(id).get()).data()!;

  Future<List<Json>> notifications() async => [
    for (final doc in (await db.collection('notifications').get()).docs)
      {'id': doc.id, ...doc.data()},
  ];

  setUp(() {
    db = FakeFirebaseFirestore();
    recording = RecordingFirestoreService(FirebaseFirestoreService(db));
    auth = ScriptedAuthService()
      ..currentUser = const AuthUserInfo(
        uid: _super,
        email: 'super@gumushane.edu.tr',
        emailVerified: true,
      );
    moderation = moderationOn(recording);
  });

  group('T-37 · resolveReports · grup (aynı hedef)', () {
    test('roadmap: grup çözümü tek batch — hedefin o anki TÜM açık şikayetleri '
        'resolved (T-40), gönderi gizlenir (sayaç / sabitleme değişmez), '
        'başka hedef ve önceden çözülmüş şikayet değişmez', () async {
      await seedContent('posts', _postId);
      final open = [
        await seedReport('u1'),
        await seedReport('u2'),
        await seedReport('u3'),
      ];
      final otherTarget = await seedReport('u1', targetId: 'p02');
      final alreadyResolved = await seedReport(
        'u4',
        status: ReportStatus.resolved,
      );
      final otherBefore = await report(otherTarget);
      final resolvedBefore = await report(alreadyResolved);

      // Yalnızca biri verilir: grup hedeften yeniden okunur.
      final result = await moderation.resolveReports(
        reportIds: [open.first],
        action: ReportAction.removed,
        actorId: _super,
        target: _post,
      );

      expect(result.isSuccess, isTrue);
      expect(recording.outsideWrites, 1, reason: 'tek commitBatch');
      expect(recording.transactions, 0);
      for (final id in open) {
        final data = await report(id);
        expect(data['status'], 'resolved', reason: id);
        expect(data['action'], 'removed');
        expect(data['resolvedBy'], _super);
        expect(data['resolvedAt'], isA<Timestamp>());
        expect(data['updatedAt'], isA<Timestamp>());
      }
      expect(await report(otherTarget), otherBefore);
      expect(await report(alreadyResolved), resolvedBefore);

      final post = await content('posts', _postId);
      expect(post['isHidden'], isTrue);
      expect(post['hiddenBy'], _super);
      expect(post['hiddenAt'], isA<Timestamp>());
      expect(post['commentCount'], 2);
      expect(post['likeCount'], 3);
      expect(post['pinned'], isTrue);
      expect(await notifications(), hasLength(3));
    });

    test('W-84: report_resolved her şikayetçiye bir kez (aynı şikayetçinin '
        'ikinci belgesi tekilleşir), tek olay anahtarı, refs.reportId = grup '
        'anahtarı', () async {
      await seedContent('posts', _postId);
      await seedReport('u1');
      await seedReport('u2');
      // Kanonik olmayan kimlikle aynı şikayetçinin ikinci açık belgesi.
      await seedReport('u1', id: 'legacy_u1_post_p01');

      final result = await moderation.resolveReports(
        reportIds: const [],
        action: ReportAction.dismissed,
        actorId: _super,
        target: _post,
      );

      expect(result.isSuccess, isTrue);
      final docs = await notifications();
      expect(docs.map((d) => d['userId']), unorderedEquals(['u1', 'u2']));
      expect(FirestoreIds.reportGroupKey('post', _postId), 'post_p01');
      for (final doc in docs) {
        expect(doc['type'], 'report_resolved');
        expect(doc['refs'], {'reportId': 'post_p01'});
        expect(doc['read'], isFalse);
      }
      final keys = {
        for (final doc in docs)
          (doc['id']! as String).replaceFirst(
            RegExp('_${doc['userId']}\$'),
            '',
          ),
      };
      expect(keys, hasLength(1), reason: 'tek olay anahtarı');
      expect(keys.single, startsWith('report_resolved_'));
      // dismissed içeriğe dokunmaz.
      expect((await content('posts', _postId))['isHidden'], isFalse);
      expect(
        (await report('legacy_u1_post_p01'))['status'],
        'resolved',
      );
    });

    test('hedefsiz: reportIds okunur, açık olmayan atlanır; suspended askı '
        'yazmaz, içerik değişmez', () async {
      await seedContent('posts', _postId);
      final open = await seedReport('u1');
      final resolved = await seedReport('u2', status: ReportStatus.resolved);
      final resolvedBefore = await report(resolved);
      final postBefore = await content('posts', _postId);

      final result = await moderation.resolveReports(
        reportIds: [open, resolved],
        action: ReportAction.suspended,
        actorId: _super,
      );

      expect(result.isSuccess, isTrue);
      expect((await report(open))['action'], 'suspended');
      expect(await report(resolved), resolvedBefore);
      expect(await content('posts', _postId), postBefore);
      expect(
        (await db.collection('users').get()).docs,
        isEmpty,
        reason: 'askı ayrı çağrıdır (suspendUser)',
      );
      expect((await notifications()).single['userId'], 'u1');
    });

    test('removed + yorum hedefi: yorum gizlenir; zaten gizli içerikte '
        'gizleme yazılmaz (Rules isHideToggle ikinciyi reddeder), şikayetler '
        'yine çözülür', () async {
      await seedContent('comments', 'cm01');
      await seedContent('posts', _postId, hidden: true);
      final onComment = await seedReport(
        'u1',
        type: ReportTargetType.comment,
        targetId: 'cm01',
      );
      final onHidden = await seedReport('u2');
      final hiddenBefore = await content('posts', _postId);

      final comment = await moderation.resolveReports(
        reportIds: [onComment],
        action: ReportAction.removed,
        actorId: _super,
      );
      final post = await moderation.resolveReports(
        reportIds: [onHidden],
        action: ReportAction.removed,
        actorId: _super,
        target: _post,
      );

      expect(comment.isSuccess, isTrue);
      expect(post.isSuccess, isTrue);
      final hidden = await content('comments', 'cm01');
      expect(hidden['isHidden'], isTrue);
      expect(hidden['hiddenBy'], _super);
      expect(await content('posts', _postId), hiddenBefore);
      expect((await report(onHidden))['status'], 'resolved');
    });

    test('unhide gizlenen içeriği geri getirir; çözülmüş şikayetler '
        'çözülmüş kalır', () async {
      await seedContent('posts', _postId);
      final id = await seedReport('u1');
      await moderation.resolveReports(
        reportIds: [id],
        action: ReportAction.removed,
        actorId: _super,
        target: _post,
      );

      final shown = await FirebasePostRepository(
        recording,
        RecordingStorageService(),
        FirebaseActivityRepository(recording),
        FirebaseAnnouncementCounterRepository(recording, FakeAppClock(_now)),
        FakeAppClock(_now),
        SequenceRandom(const [0]),
      ).unhide(_postId);

      expect(shown.isSuccess, isTrue);
      final post = await content('posts', _postId);
      expect(post['isHidden'], isFalse);
      expect(post['hiddenBy'], isNull);
      expect(post['hiddenAt'], isNull);
      expect((await report(id))['status'], 'resolved');
    });

    test('parçalama: 2n + gizleme > batchMaxWrites → iki batch, gizleme ilk '
        'parçada; her şikayet çözülür, her şikayetçiye bir bildirim', () async {
      await seedContent('posts', _postId);
      const n = 230; // 2·230 + 1 = 461 > 450
      for (var i = 0; i < n; i++) {
        await seedReport('u$i');
      }

      final result = await moderation.resolveReports(
        reportIds: const [],
        action: ReportAction.removed,
        actorId: _super,
        target: _post,
      );

      expect(result.isSuccess, isTrue);
      expect(recording.outsideWrites, 2);
      final reports = (await db.collection('reports').get()).docs;
      expect(reports.map((d) => d['status']), everyElement('resolved'));
      expect(await notifications(), hasLength(n));
      expect((await content('posts', _postId))['isHidden'], isTrue);
    });
  });

  group('T-37 · resolveReports · ret ve hata eşlemesi', () {
    test('açık şikayet kalmadıysa conflict; hiçbir şey yazılmaz', () async {
      await seedContent('posts', _postId);
      final id = await seedReport('u1', status: ReportStatus.resolved);

      final result = await moderation.resolveReports(
        reportIds: [id],
        action: ReportAction.removed,
        actorId: _super,
        target: _post,
      );

      expect(result.errorOrNull, FirestoreError.conflict);
      expect(recording.outsideWrites, 0);
      expect((await content('posts', _postId))['isHidden'], isFalse);
    });

    test('removed yalnızca post / comment: kullanıcı / kulüp / etkinlik '
        'hedefi ağ çağrısı yapmadan invalidArgument', () async {
      final service = FirebaseFirestoreService(
        StubFirestore(error: firestoreException('unavailable')),
      );
      final offline = moderationOn(service);
      for (final type in [
        ReportTargetType.user,
        ReportTargetType.club,
        ReportTargetType.event,
      ]) {
        final result = await offline.resolveReports(
          reportIds: const ['r1'],
          action: ReportAction.removed,
          actorId: _super,
          target: (type: type, id: 'x1', clubId: null),
        );
        expect(
          result.errorOrNull,
          FirestoreError.invalidArgument,
          reason: '$type',
        );
      }
    });

    test('başka hedefin şikayeti ya da karışık grup invalidArgument; olmayan '
        'şikayet notFound; yazım yok', () async {
      await seedContent('posts', _postId);
      final mine = await seedReport('u1');
      final other = await seedReport('u2', targetId: 'p02');

      final foreign = await moderation.resolveReports(
        reportIds: [mine, other],
        action: ReportAction.dismissed,
        actorId: _super,
        target: _post,
      );
      final mixed = await moderation.resolveReports(
        reportIds: [mine, other],
        action: ReportAction.dismissed,
        actorId: _super,
      );
      final missing = await moderation.resolveReports(
        reportIds: ['yok'],
        action: ReportAction.dismissed,
        actorId: _super,
      );

      expect(foreign.errorOrNull, FirestoreError.invalidArgument);
      expect(mixed.errorOrNull, FirestoreError.invalidArgument);
      expect(missing.errorOrNull, FirestoreError.notFound);
      expect(recording.outsideWrites, 0);
      expect((await report(mine))['status'], 'open');
    });

    test(
      'oturum yoksa unauthenticated; actorId oturumdaki kullanıcı değilse '
      'invalidArgument; geçersiz kimlik / boş istek invalidArgument',
      () async {
        final id = await seedReport('u1');
        Future<FirestoreError?> resolve({
          List<String>? ids,
          String actorId = _super,
          ReportTarget? target = _post,
        }) async => (await moderation.resolveReports(
          reportIds: ids ?? [id],
          action: ReportAction.dismissed,
          actorId: actorId,
          target: target,
        )).errorOrNull;

        expect(
          await resolve(actorId: 'u_baska'),
          FirestoreError.invalidArgument,
        );
        expect(
          await resolve(ids: const [], target: null),
          FirestoreError.invalidArgument,
        );
        for (final bad in ['', 'r/1', '..', '__id__']) {
          expect(await resolve(ids: [bad]), FirestoreError.invalidArgument);
          expect(await resolve(actorId: bad), FirestoreError.invalidArgument);
          expect(
            await resolve(
              target: (type: ReportTargetType.post, id: bad, clubId: _clubId),
            ),
            FirestoreError.invalidArgument,
          );
        }
        auth.currentUser = null;
        expect(await resolve(), FirestoreError.unauthenticated);
        expect(recording.outsideWrites, 0);
        expect((await report(id))['status'], 'open');
      },
    );

    test('kritik bildirim yazılamazsa (geçersiz şikayetçi kimliği) batch '
        'düşer: şikayet açık kalır, içerik gizlenmez', () async {
      await seedContent('posts', _postId);
      final id = await seedReport('u1', id: 'bad_reporter_post_p01');
      await db.collection('reports').doc(id).update({'reporterId': '__x__'});

      final result = await moderation.resolveReports(
        reportIds: [id],
        action: ReportAction.removed,
        actorId: _super,
        target: _post,
      );

      expect(result.errorOrNull, FirestoreError.invalidArgument);
      expect((await report(id))['status'], 'open');
      expect((await content('posts', _postId))['isHidden'], isFalse);
      expect(await notifications(), isEmpty);
    });

    test('Rules reddi (claim yok) permissionDenied olarak döner, hiçbir '
        'yazım uygulanmaz; okuma hatası aynen eşlenir', () async {
      await seedContent('posts', _postId);
      final id = await seedReport('u1');
      final denied = moderationOn(
        FirebaseFirestoreService(
          FailingBatchFirestore(
            db,
            error: firestoreException('permission-denied'),
          ),
        ),
      );
      final broken = moderationOn(
        FirebaseFirestoreService(
          StubFirestore(error: firestoreException('unavailable')),
        ),
      );

      final rejected = await denied.resolveReports(
        reportIds: [id],
        action: ReportAction.removed,
        actorId: _super,
        target: _post,
      );

      expect(rejected.errorOrNull, FirestoreError.permissionDenied);
      expect((await report(id))['status'], 'open');
      expect((await content('posts', _postId))['isHidden'], isFalse);
      expect(
        (await broken.resolveReports(
          reportIds: [id],
          action: ReportAction.dismissed,
          actorId: _super,
          target: _post,
        )).errorOrNull,
        FirestoreError.unavailable,
      );
    });
  });

  group('T-37 · şikayet listeleri', () {
    test(
      'listOpenReports / listReports(resolved): durum süzgeci, createdAt '
      'azalan, sayfa; listReportsForTarget yalnızca hedefin açıkları',
      () async {
        await seedReport('u1', minute: 1);
        await seedReport('u2', minute: 3);
        await seedReport('u3', minute: 2, targetId: 'p02');
        await seedReport('u4', minute: 4, status: ReportStatus.resolved);

        final open = (await moderation.listOpenReports(
          const PageRequest(limit: 2),
        )).dataOrNull!;
        final resolved = (await moderation.listReports(
          ReportStatus.resolved,
          const PageRequest(),
        )).dataOrNull!;
        final forTarget = (await moderation.listReportsForTarget(
          type: ReportTargetType.post,
          targetId: _postId,
        )).dataOrNull!;

        expect(open.items.map((r) => r.reporterId), ['u2', 'u3']);
        expect(open.hasMore, isTrue);
        expect(resolved.items.map((r) => r.reporterId), ['u4']);
        expect(resolved.items.single.action, ReportAction.dismissed);
        expect(
          forTarget.map((r) => r.reporterId),
          unorderedEquals(['u1', 'u2']),
        );
        expect(
          forTarget.map((r) => r.id),
          everyElement(endsWith('_post_p01')),
        );
      },
    );

    test('geçersiz hedef kimliği invalidArgument; okuma hatası aynen '
        'eşlenir', () async {
      final broken = moderationOn(
        FirebaseFirestoreService(
          StubFirestore(error: firestoreException('permission-denied')),
        ),
      );

      expect(
        (await moderation.listReportsForTarget(
          type: ReportTargetType.user,
          targetId: 'a/b',
        )).errorOrNull,
        FirestoreError.invalidArgument,
      );
      final results = <FirestoreResult<Object?>>[
        await broken.listOpenReports(const PageRequest()),
        await broken.listReports(
          ReportStatus.resolved,
          const PageRequest(),
        ),
        await broken.listReportsForTarget(
          type: ReportTargetType.post,
          targetId: _postId,
        ),
      ];
      expect(
        results.map((r) => r.errorOrNull),
        everyElement(FirestoreError.permissionDenied),
      );
    });
  });
}

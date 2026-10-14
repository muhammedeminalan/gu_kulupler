// T-25 · ClientFanOutDispatcher (Mod C; PLAN §10.5, §15.3;
// `docs/plans/T-25.md` §6 b–e, §8): üretim tablosundaki her tür için alıcı
// kümesi, `refs` ve kimlik (olay anahtarı — tek seferlik olayda olayın
// kimliği, CD-148); kritik türler çağıranın batch'ine eşzamanlı eklenir,
// geçersiz girdi çağrı anında fırlar ve batch'in tamamını düşürür; fan-out
// parçaları (1200 alıcı), tekilleştirme, yeniden deneme, belirsiz yeniden
// deneme, `permissionDenied`'de yarılama ve tek belgede ret; alıcı başına
// batch; yazan taraf tercih süzmez; hata yalıtımı. Yazıcı ve alıcı çözücü
// yerel el yazımı çiftlerdir; batch atomikliği gerçek servis +
// `fake_cloud_firestore` ile sınanır.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart'
    show FirebaseException, Transaction, WriteBatch;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../fakes/sdk_firestore_stubs.dart';
import '../helpers/repo_sources.dart';

const String _source =
    'packages/gu_data/lib/src/notifications/client_fan_out_dispatcher.dart';

/// `FirestoreIds.notification` kimliğinin dağıtıcı türlerindeki biçimi
/// (Rules `key.matches('^[A-Za-z0-9]{20}$')`).
final RegExp _eventKey = RegExp(r'^[A-Za-z0-9]{20}$');

/// Kayıt tutan [NotificationWriter]: anahtarlar sırayla üretilir, parça
/// sonuçları [script]'ten (boşsa başarı) gelir.
final class _RecordingWriter implements NotificationWriter {
  final List<String> keys = [];
  final List<({WriteBatch batch, NotificationDraft draft, String to})> added =
      [];
  final List<({NotificationDraft draft, List<String> ids})> chunks = [];
  final List<({Transaction tx, NotificationDraft draft, String to})> addedInTx =
      [];

  /// `createMany` çağrısı başına sonuç; `null` → yazılan = parça boyu.
  final List<FirestoreResult<int>?> script = [];

  /// Doluysa `createMany` fırlatır.
  Error? throwOnCreate;

  @override
  String newEventKey() {
    final key = 'K${keys.length}'.padRight(20, 'x');
    keys.add(key);
    return key;
  }

  @override
  void addToBatch(
    WriteBatch batch,
    NotificationDraft draft, {
    required String recipientId,
  }) {
    added.add((batch: batch, draft: draft, to: recipientId));
  }

  @override
  void addToTransaction(
    Transaction transaction,
    NotificationDraft draft, {
    required String recipientId,
  }) {
    addedInTx.add((tx: transaction, draft: draft, to: recipientId));
  }

  @override
  Future<FirestoreResult<int>> createMany(
    NotificationDraft draft,
    List<String> recipientIds,
  ) async {
    chunks.add((draft: draft, ids: List.of(recipientIds)));
    if (throwOnCreate case final error?) throw error;
    final scripted = script.isEmpty ? null : script.removeAt(0);
    return scripted ?? FirebaseSuccess(recipientIds.length);
  }

  /// Fan-out ile yazılan alıcılar (tüm parçalar, sırayla).
  List<String> get fannedOut => [for (final c in chunks) ...c.ids];
}

/// Hiçbir üyesi çağrılmayan transaction (yazıcı kaydeder).
final class _StubTransaction extends Fake implements Transaction {}

/// Yalnızca [managersOf] kullanılan alıcı çözücü.
final class _FakeResolver extends Fake implements RecipientResolver {
  FirestoreResult<List<String>> managers = const FirebaseSuccess([]);
  final List<String> managerCalls = [];

  @override
  Future<FirestoreResult<List<String>>> managersOf(String clubId) async {
    managerCalls.add(clubId);
    return managers;
  }
}

/// Bir parçalık yeniden deneme politikası: beklemeden 3 deneme.
final RetryPolicy _instantRetry = RetryPolicy(wait: (_) async {});

List<String> _users(int n) => [for (var i = 0; i < n; i++) 'u$i'];

/// [call] çağrı ANINDA (Future üretmeden) fırlattığı [FirebaseException]'ın
/// kodu; fırlatmazsa `null`.
String? _syncErrorCode(Future<Object?> Function() call) {
  try {
    unawaited(call());
  } on FirebaseException catch (error) {
    return error.code;
  }
  return null;
}

void main() {
  late _RecordingWriter writer;
  late _FakeResolver resolver;
  late List<(NotificationType, FirestoreResult<DispatchReport>)> issues;
  late ClientFanOutDispatcher dispatcher;

  setUp(() {
    writer = _RecordingWriter();
    resolver = _FakeResolver();
    issues = [];
    dispatcher = ClientFanOutDispatcher(
      writer: writer,
      recipients: resolver,
      retry: _instantRetry,
      onIssue: (type, result) => issues.add((type, result)),
    );
  });

  DispatchReport report(int requested, int written, [int failed = 0]) =>
      DispatchReport(
        requested: requested,
        written: written,
        failedChunks: failed,
      );

  group('T-25 · ClientFanOutDispatcher · kritik türler (aynı batch)', () {
    test("her tür tek alıcılı belgeyi çağıranın batch'ine ekler: tür, refs, "
        'çağrı başına yeni olay anahtarı; createMany / commit yok', () async {
      final batch = StubWriteBatch();
      final results = [
        await dispatcher.notifyApplicationDecided(
          clubId: 'c01',
          applicantId: 'u1',
          approved: true,
          batch: batch,
        ),
        await dispatcher.notifyApplicationDecided(
          clubId: 'c01',
          applicantId: 'u1',
          approved: false,
          batch: batch,
        ),
        await dispatcher.notifyRemoved(
          clubId: 'c01',
          userId: 'u2',
          batch: batch,
        ),
        await dispatcher.notifyRoleChanged(
          clubId: 'c01',
          userId: 'u3',
          role: ClubRole.board,
          batch: batch,
        ),
        await dispatcher.notifyWaitlistPromoted(
          eventId: 'e01',
          clubId: 'c01',
          userId: 'u4',
          batch: batch,
        ),
        await dispatcher.notifyReportResolved(
          reportGroupKey: 'post_p01',
          reporterIds: const ['u5', 'u6', 'u5'],
          batch: batch,
        ),
      ];

      expect(
        [for (final r in results) r.dataOrNull],
        [
          report(1, 1),
          report(1, 1),
          report(1, 1),
          report(1, 1),
          report(1, 1),
          report(2, 2),
        ],
      );
      expect(
        [
          for (final a in writer.added)
            (a.draft.type, a.to, a.draft.refs, a.draft.eventKey),
        ],
        [
          (
            NotificationType.applicationApproved,
            'u1',
            const NotificationRefsModel(clubId: 'c01'),
            writer.keys[0],
          ),
          (
            NotificationType.applicationRejected,
            'u1',
            const NotificationRefsModel(clubId: 'c01'),
            writer.keys[1],
          ),
          (
            NotificationType.removedFromClub,
            'u2',
            const NotificationRefsModel(clubId: 'c01'),
            writer.keys[2],
          ),
          (
            NotificationType.roleChanged,
            'u3',
            const NotificationRefsModel(clubId: 'c01', role: ClubRole.board),
            writer.keys[3],
          ),
          (
            NotificationType.waitlistPromoted,
            'u4',
            const NotificationRefsModel(clubId: 'c01', eventId: 'e01'),
            writer.keys[4],
          ),
          (
            NotificationType.reportResolved,
            'u5',
            const NotificationRefsModel(reportId: 'post_p01'),
            writer.keys[5],
          ),
          (
            NotificationType.reportResolved,
            'u6',
            const NotificationRefsModel(reportId: 'post_p01'),
            writer.keys[5],
          ),
        ],
      );
      // Her olay kendi anahtarını alır (onayla → geri al → yeniden onayla
      // aynı kimliğe düşmez — W-49); anahtar Rules biçiminde.
      expect(writer.keys.toSet(), hasLength(6));
      expect(writer.keys.every(_eventKey.hasMatch), isTrue);
      expect(
        FirestoreIds.notification(
          NotificationType.removedFromClub.json,
          writer.keys[2],
          'u2',
        ),
        'removed_from_club_${writer.keys[2]}_u2',
      );
      expect(writer.added.every((a) => identical(a.batch, batch)), isTrue);
      expect(writer.added, hasLength(7));
      expect(batch.writes, 0);
      expect(batch.commits, 0);
      expect(writer.chunks, isEmpty);
      expect(issues, isEmpty);
    });

    test('yazım eşzamanlıdır: commitBatch gövdesi sonucu beklemeden '
        'çağırabilir (Future tamamlanmadan batch dolu)', () {
      final batch = StubWriteBatch();

      final pending = dispatcher.notifyWaitlistPromoted(
        eventId: 'e01',
        clubId: 'c01',
        userId: 'u1',
        batch: batch,
      );

      expect(writer.added, hasLength(1));
      return expectLater(
        pending,
        completion(isA<FirebaseSuccess<DispatchReport, FirestoreError>>()),
      );
    });

    test('geçersiz alıcı ya da referans → çağrı anında invalid-argument '
        "FirebaseException (commitBatch gövdesi batch'i düşürür); batch'e "
        'hiçbir şey eklenmez, dinleyiciye gider', () {
      final batch = StubWriteBatch();

      final badRecipient = _syncErrorCode(
        () => dispatcher.notifyReportResolved(
          reportGroupKey: 'post_p01',
          reporterIds: const ['u1', 'a/b'],
          batch: batch,
        ),
      );
      final badClub = _syncErrorCode(
        () => dispatcher.notifyRemoved(clubId: '', userId: 'u1', batch: batch),
      );

      expect(badRecipient, 'invalid-argument');
      expect(badClub, 'invalid-argument');
      expect(writer.added, isEmpty);
      expect(issues.map((issue) => (issue.$1, issue.$2.errorOrNull)), [
        (NotificationType.reportResolved, FirestoreError.invalidArgument),
        (NotificationType.removedFromClub, FirestoreError.invalidArgument),
      ]);
    });

    group('gerçek commitBatch (fake_cloud_firestore)', () {
      late FakeFirebaseFirestore db;
      late FirebaseFirestoreService service;
      late ClientFanOutDispatcher real;

      setUp(() async {
        db = FakeFirebaseFirestore();
        service = FirebaseFirestoreService(db);
        real = ClientFanOutDispatcher(
          writer: FirebaseNotificationRepository(service),
          recipients: resolver,
        );
        await db.doc('rsvps/e01_u1').set({'status': 'waitlist'});
      });

      /// T-30 `promote` bileşimi: kayıt `waitlist → going` + kritik bildirim
      /// aynı eşzamanlı gövdede.
      Future<FirestoreResult<void>> promote(String userId) =>
          service.commitBatch((batch) {
            batch.update(service.doc(FirestoreCollections.rsvps, 'e01_u1'), {
              FirestoreFields.status: RsvpStatus.going.json,
            });
            unawaited(
              real.notifyWaitlistPromoted(
                eventId: 'e01',
                clubId: 'c01',
                userId: userId,
                batch: batch,
              ),
            );
          });

      test('geçersiz alıcılı terfi bildirimi → batch invalidArgument, '
          'terfi de UYGULANMAZ (asıl yazım bildirimsiz kesinleşmez)', () async {
        final result = await promote('a/b');

        expect(result.errorOrNull, FirestoreError.invalidArgument);
        expect((await db.doc('rsvps/e01_u1').get()).data(), {
          'status': 'waitlist',
        });
        expect((await db.collection('notifications').get()).docs, isEmpty);
      });

      test('geçerli terfi + bildirim birlikte kesinleşir', () async {
        final result = await promote('u1');

        expect(result.isSuccess, isTrue);
        expect((await db.doc('rsvps/e01_u1').get()).data()!['status'], 'going');
        final notes = (await db.collection('notifications').get()).docs;
        expect(notes.single.data()['type'], 'waitlist_promoted');
        expect(notes.single.id, startsWith('waitlist_promoted_'));
        expect(notes.single.id, endsWith('_u1'));
      });
    });
  });

  group('T-30 · ClientFanOutDispatcher · kritik türler (aynı transaction)', () {
    test("her …InTransaction üyesi tek belgeyi çağıranın transaction'ına "
        'ekler (batch karşılığıyla aynı tür / refs; batch ve fan-out yok); '
        'geçersiz alıcı çağrı anında invalid-argument fırlatır', () async {
      final tx = _StubTransaction();
      final results = [
        await dispatcher.notifyApplicationDecidedInTransaction(
          clubId: 'c01',
          applicantId: 'u1',
          approved: true,
          transaction: tx,
        ),
        await dispatcher.notifyApplicationDecidedInTransaction(
          clubId: 'c01',
          applicantId: 'u1',
          approved: false,
          transaction: tx,
        ),
        await dispatcher.notifyRemovedInTransaction(
          clubId: 'c01',
          userId: 'u2',
          transaction: tx,
        ),
        await dispatcher.notifyRoleChangedInTransaction(
          clubId: 'c01',
          userId: 'u3',
          role: ClubRole.board,
          transaction: tx,
        ),
        await dispatcher.notifyWaitlistPromotedInTransaction(
          eventId: 'e01',
          clubId: 'c01',
          userId: 'u4',
          transaction: tx,
        ),
      ];

      expect([
        for (final r in results) r.dataOrNull,
      ], List.filled(5, report(1, 1)));
      expect(writer.added, isEmpty);
      expect(writer.chunks, isEmpty);
      expect([for (final a in writer.addedInTx) a.tx], everyElement(same(tx)));
      expect(
        [for (final a in writer.addedInTx) (a.draft.type, a.to)],
        [
          (NotificationType.applicationApproved, 'u1'),
          (NotificationType.applicationRejected, 'u1'),
          (NotificationType.removedFromClub, 'u2'),
          (NotificationType.roleChanged, 'u3'),
          (NotificationType.waitlistPromoted, 'u4'),
        ],
      );
      expect(
        writer.addedInTx[3].draft.refs,
        const NotificationRefsModel(clubId: 'c01', role: ClubRole.board),
      );
      expect(
        writer.addedInTx[4].draft.refs,
        const NotificationRefsModel(clubId: 'c01', eventId: 'e01'),
      );
      expect({
        for (final a in writer.addedInTx) a.draft.eventKey,
      }, hasLength(5));

      expect(
        _syncErrorCode(
          () => dispatcher.notifyRemovedInTransaction(
            clubId: 'c01',
            userId: '',
            transaction: tx,
          ),
        ),
        'invalid-argument',
      );
      expect(writer.addedInTx, hasLength(5));
    });
  });

  group('T-25 · ClientFanOutDispatcher · fan-out türleri', () {
    test('announcement / event_new / event_cancelled: tekilleştirilmiş '
        "alıcılar, türün refs'i; tek seferlik olayda anahtar olayın kimliği "
        '(postId / eventId), yeniden yayında çağrı başına rastgele '
        '(CD-148)', () async {
      final results = [
        await dispatcher.notifyAnnouncement(
          postId: 'p01',
          clubId: 'c01',
          recipients: const ['u1', 'u2', 'u1'],
        ),
        await dispatcher.notifyEventNew(
          eventId: 'e01',
          clubId: 'c01',
          recipients: const ['u3'],
        ),
        await dispatcher.notifyEventCancelled(
          eventId: 'e02',
          clubId: 'c01',
          recipients: const ['u4', 'u5'],
        ),
      ];

      expect(
        [for (final r in results) r.dataOrNull],
        [
          report(2, 2),
          report(1, 1),
          report(2, 2),
        ],
      );
      expect(
        [
          for (final c in writer.chunks)
            (c.draft.type, c.draft.refs, c.draft.eventKey, c.ids.join(',')),
        ],
        [
          (
            NotificationType.announcement,
            const NotificationRefsModel(clubId: 'c01', postId: 'p01'),
            'p01',
            'u1,u2',
          ),
          (
            NotificationType.eventNew,
            const NotificationRefsModel(clubId: 'c01', eventId: 'e01'),
            writer.keys.single,
            'u3',
          ),
          (
            NotificationType.eventCancelled,
            const NotificationRefsModel(clubId: 'c01', eventId: 'e02'),
            'e02',
            'u4,u5',
          ),
        ],
      );
      expect(writer.added, isEmpty);
    });

    test('application_received: alıcılar managersOf(clubId) (başvuran '
        'hariç), alıcı başına ayrı batch, refs clubId + applicantId, anahtar '
        "başvurunun priorCount'u (CD-148)", () async {
      resolver.managers = const FirebaseSuccess(['m1', 'm2', 'u_app']);

      final result = await dispatcher.notifyApplicationReceived(
        clubId: 'c01',
        applicantId: 'u_app',
        sequence: 3,
      );

      expect(result.dataOrNull, report(2, 2));
      expect(resolver.managerCalls, ['c01']);
      expect(
        [for (final c in writer.chunks) c.ids],
        [
          ['m1'],
          ['m2'],
        ],
      );
      expect(
        writer.chunks.map((c) => c.draft).toSet().single,
        const NotificationDraft(
          type: NotificationType.applicationReceived,
          refs: NotificationRefsModel(
            clubId: 'c01',
            applicantId: 'u_app',
          ),
          eventKey: 'c01_u_app_3',
        ),
      );
      expect(writer.keys, isEmpty);
      expect(
        FirestoreIds.notification('application_received', 'c01_u_app_3', 'm1'),
        'application_received_c01_u_app_3_m1',
      );
    });

    test('negatif sıra → invalidArgument, yazım yok', () async {
      final result = await dispatcher.notifyApplicationReceived(
        clubId: 'c01',
        applicantId: 'u_app',
        sequence: -1,
      );

      expect(result.errorOrNull, FirestoreError.invalidArgument);
      expect(resolver.managerCalls, isEmpty);
      expect(writer.chunks, isEmpty);
    });

    test('1200 alıcı → Limits.notificationFanOutChunkSize boyutlu parçalar; '
        'tüm parçalar aynı anahtar, hiçbir alıcı iki kez yazılmaz', () async {
      final recipients = _users(1200);

      final result = await dispatcher.notifyAnnouncement(
        postId: 'p01',
        clubId: 'c01',
        recipients: [...recipients, ...recipients.take(10)],
      );

      const size = Limits.notificationFanOutChunkSize;
      expect(result.dataOrNull, report(1200, 1200));
      expect(writer.chunks, hasLength((1200 / size).ceil()));
      expect(writer.chunks.every((c) => c.ids.length <= size), isTrue);
      expect(writer.fannedOut, recipients);
      expect(writer.chunks.map((c) => c.draft.eventKey).toSet(), {'p01'});
    });

    test("aynı duyuru iki kez → AYNI belge kimliği (ikinci çağrı Rules'ta "
        'update → ret); yeniden yayın (event_new) yeni anahtar → farklı '
        'belge', () async {
      for (var i = 0; i < 2; i++) {
        await dispatcher.notifyAnnouncement(
          postId: 'p01',
          clubId: 'c01',
          recipients: const ['u1'],
        );
        await dispatcher.notifyEventNew(
          eventId: 'e01',
          clubId: 'c01',
          recipients: const ['u1'],
        );
      }

      Set<String> idsOf(NotificationType type) => {
        for (final c in writer.chunks)
          if (c.draft.type == type)
            FirestoreIds.notification(type.json, c.draft.eventKey, 'u1'),
      };
      expect(idsOf(NotificationType.announcement), {'announcement_p01_u1'});
      expect(idsOf(NotificationType.eventNew), hasLength(2));
    });

    test('new_report üretilmez (CD-37); system istemcide yazılmaz', () async {
      final newReport = await dispatcher.notifyNewReport(reportId: 'r01');
      final system = await dispatcher.notifySystem(
        userIds: const ['u1', 'u2', 'u1'],
        textKey: 'notifSystemMaintenance',
      );

      expect(newReport.dataOrNull, report(0, 0));
      expect(system.dataOrNull, report(2, 0));
      expect(writer.keys, isEmpty);
      expect(writer.chunks, isEmpty);
      expect(issues, isEmpty);
    });

    test('yazan taraf tercih / sessiz saat süzmez: verilen her alıcıya '
        'yazılır; dağıtıcı ayar okumaz (okuyan taraf süzer)', () async {
      final result = await dispatcher.notifyEventNew(
        eventId: 'e01',
        clubId: 'c01',
        recipients: const ['u_muted', 'u_quiet', 'u_off'],
      );

      expect(result.dataOrNull, report(3, 3));
      expect(writer.fannedOut, ['u_muted', 'u_quiet', 'u_off']);
      final source = readRepoFile(_source);
      expect(source, isNot(contains('UserSettingsModel')));
      expect(source, isNot(contains('SettingsRepository')));
    });
  });

  group('T-25 · ClientFanOutDispatcher · hata yalıtımı', () {
    test('geçici hata yeniden denenir (aynı parça, aynı anahtar)', () async {
      const size = Limits.notificationFanOutChunkSize;
      writer.script.addAll([
        const FirebaseFailure(FirestoreError.unavailable),
        null,
      ]);

      final result = await dispatcher.notifyAnnouncement(
        postId: 'p01',
        clubId: 'c01',
        recipients: _users(size * 2),
      );

      expect(result.dataOrNull, report(size * 2, size * 2));
      expect(writer.chunks, hasLength(3));
      expect(writer.chunks[0].ids, writer.chunks[1].ids);
      expect(issues, isEmpty);
    });

    test('yeniden denemede permissionDenied = ilk deneme sunucuda '
        'kesinleşmiş: parça yazılmış sayılır, kalan parçalar sürer', () async {
      const size = Limits.notificationFanOutChunkSize;
      writer.script.addAll([
        const FirebaseFailure(FirestoreError.unavailable),
        const FirebaseFailure(FirestoreError.permissionDenied),
      ]);

      final result = await dispatcher.notifyAnnouncement(
        postId: 'p01',
        clubId: 'c01',
        recipients: _users(size * 2),
      );

      expect(result.dataOrNull, report(size * 2, size * 2));
      expect([for (final c in writer.chunks) c.ids.length], [size, size, size]);
      expect(writer.fannedOut.skip(size), _users(size * 2));
    });

    test('permissionDenied çok belgeli parçayı yarılar (canlı istek sınırı); '
        'küçülen boy sonraki parçalarda sürer, herkes yazılır', () async {
      const size = Limits.notificationFanOutChunkSize;
      const half = (size + 1) ~/ 2;
      writer.script.add(const FirebaseFailure(FirestoreError.permissionDenied));

      final result = await dispatcher.notifyEventNew(
        eventId: 'e01',
        clubId: 'c01',
        recipients: _users(size * 2),
      );

      expect(result.dataOrNull, report(size * 2, size * 2));
      expect(writer.chunks.first.ids, hasLength(size));
      expect(writer.chunks.skip(1).every((c) => c.ids.length <= half), isTrue);
      expect(writer.fannedOut.skip(size), _users(size * 2));
      expect(issues, isEmpty);
    });

    test('tek belgeye kadar yarılanıp yine reddedilirse ret kuraldandır: '
        'kalan parçalar denenmez, dinleyiciye gider', () async {
      writer.script.addAll([
        for (var i = 0; i < 3; i++)
          const FirebaseFailure<int, FirestoreError>(
            FirestoreError.permissionDenied,
          ),
      ]);

      final result = await dispatcher.notifyEventCancelled(
        eventId: 'e01',
        clubId: 'c01',
        recipients: _users(4),
      );

      // 4 → 2 → 1 reddedildi; kalan 3 alıcı (tek belgelik 3 parça) denenmez.
      expect(result.dataOrNull, report(4, 0, 4));
      expect([for (final c in writer.chunks) c.ids.length], [4, 2, 1]);
      expect(issues.single.$1, NotificationType.eventCancelled);
    });

    test('application_received: bir yöneticinin reddi diğerlerini '
        'durdurmaz', () async {
      resolver.managers = const FirebaseSuccess(['m1', 'm2', 'm3']);
      writer.script.add(const FirebaseFailure(FirestoreError.permissionDenied));

      final result = await dispatcher.notifyApplicationReceived(
        clubId: 'c01',
        applicantId: 'u_app',
        sequence: 0,
      );

      expect(result.dataOrNull, report(3, 2, 1));
      expect(writer.fannedOut, ['m1', 'm2', 'm3']);
    });

    test('alıcı çözümü hatası FirebaseFailure olur; yazıcı istisnası parça '
        'hatasıdır — fan-out üyeleri fırlatmaz, eksik dağıtım dinleyiciye '
        'gider', () async {
      resolver.managers = const FirebaseFailure(
        FirestoreError.permissionDenied,
      );
      final unresolved = await dispatcher.notifyApplicationReceived(
        clubId: 'c01',
        applicantId: 'u_app',
        sequence: 0,
      );
      writer.throwOnCreate = StateError('yazıcı');
      final thrown = await dispatcher.notifyEventCancelled(
        eventId: 'e01',
        clubId: 'c01',
        recipients: const ['u1', 'a/b'],
      );

      expect(unresolved.errorOrNull, FirestoreError.permissionDenied);
      // Geçersiz kimlik yazılmaz (requested'e sayılır); istisna yeniden
      // denenmez.
      expect(thrown.dataOrNull, report(2, 0, 1));
      expect(writer.chunks.single.ids, ['u1']);
      expect(issues.map((issue) => issue.$1), [
        NotificationType.applicationReceived,
        NotificationType.eventCancelled,
      ]);
    });
  });

  test('T-25 · CD-147: dağıtıcı yalnızca arayüzlere bağlıdır (somut '
      "repository / servis içe aktarmaz) — Mod F'de ServerSideDispatcher "
      'ile değiştirilebilir', () {
    final imports = [
      for (final match in RegExp(
        "^import '([^']+)';",
        multiLine: true,
      ).allMatches(readRepoFile(_source)))
        match[1]!,
    ];

    expect(imports, isNotEmpty);
    expect(
      imports.where(
        (path) =>
            path.contains('/services/') ||
            path.contains('/repositories/firebase_'),
      ),
      isEmpty,
    );
    expect(dispatcher, isA<NotificationDispatcher>());
  });
}

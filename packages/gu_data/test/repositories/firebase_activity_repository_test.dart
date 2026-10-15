// T-15 · ActivityRepository: günlük kaydının yükü (batch ve transaction
// yolu; ortak alan yok, yalnızca dolu referanslar), kulüp günlüğünün sayfalı
// okunması (kulüp süzgeci, en yeni üstte, kategori süzgeci), geçersiz kimlik
// (W-54) ve ayrıştırma hatası (PLAN §9.6.13, §10.4; rules-spec §3.11, §6;
// domain-model §2.11; W-51).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../helpers/plan_repository_table.dart';
import '../helpers/plan_service_table.dart';
import '../helpers/repo_sources.dart';

const String _interface =
    'packages/gu_data/lib/src/repositories/activity_repository.dart';
const String _implementation =
    'packages/gu_data/lib/src/repositories/firebase_activity_repository.dart';
const String _clubId = 'c01';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreService service;
  late FirebaseActivityRepository repository;

  Future<List<Json>> entries() async => [
    for (final doc in (await db.collection('activity').get()).docs) doc.data(),
  ];

  Future<void> seed(
    String id,
    ActivityKind kind,
    int day, {
    String clubId = _clubId,
  }) => db.collection('activity').doc(id).set({
    'clubId': clubId,
    'actorId': 'u_pres',
    'kind': kind.json,
    'refs': const <String, Object?>{},
    'createdAt': Timestamp.fromDate(DateTime.utc(2026, 9, day)),
  });

  setUp(() {
    db = FakeFirebaseFirestore();
    service = FirebaseFirestoreService(db);
    repository = FirebaseActivityRepository(service);
  });

  group('T-15 · ActivityRepository · sözleşme', () {
    test('PLAN §10.4: arayüz listActivity + countByWeek (T-38) taşır '
        '(listKinds T-31 yazılmadı); addToBatch aynı imzayla uygulama '
        'sınıfında', () {
      final plan = readPlanRepositoryMembers('$ActivityRepository');
      final byMember = {for (final row in plan) row.member: row};

      expect(byMember.keys, [
        'listActivity',
        'listKinds',
        'countByWeek',
        'addToBatch',
      ]);
      expect(byMember['listKinds']!.note, '(T-31)');
      expect(byMember['countByWeek']!.note, '(T-38)');
      expect(interfaceMembers(_interface, '$ActivityRepository'), [
        normalizeDartSource(byMember['listActivity']!.signature),
        normalizeDartSource(byMember['countByWeek']!.signature),
      ]);
      // SDK tipi alan üye arayüz dosyasına giremez (sınır kuralı B08).
      expect(
        normalizeDartSource(readRepoFile(_implementation)),
        contains(normalizeDartSource(byMember['addToBatch']!.signature)),
      );
    });

    test('günlük değiştirilemez: silme ya da güncelleme üyesi yok', () {
      expect(deleteIdentifiersIn(_interface), isEmpty);
      expect(deleteIdentifiersIn(_implementation), isEmpty);
      expect(readRepoFile(_implementation), isNot(contains('.update(')));
    });
  });

  group('T-15 · ActivityRepository · kayıt ekleme', () {
    test('addToBatch: kulüp, aktör, tür, dolu referanslar ve sunucu zamanı; '
        'ortak alan (BaseFields) yok', () async {
      final result = await service.commitBatch((batch) {
        repository
          ..addToBatch(
            batch,
            const ActivityDraft(
              clubId: _clubId,
              actorId: 'u_ayse',
              kind: ActivityKind.memberJoined,
              refs: ActivityRefsModel(userId: 'u_ayse'),
            ),
          )
          ..addToBatch(
            batch,
            const ActivityDraft(
              clubId: _clubId,
              actorId: 'u_pres',
              kind: ActivityKind.settingsChanged,
            ),
          );
      });

      expect(result.isSuccess, isTrue);
      final written = {
        for (final entry in await entries()) entry['kind']: entry,
      };
      expect(written.keys, {'member_joined', 'settings_changed'});
      final joined = written['member_joined']!;
      expect(joined.keys.toSet(), {
        'clubId',
        'actorId',
        'kind',
        'refs',
        'createdAt',
      });
      expect(joined['clubId'], _clubId);
      expect(joined['actorId'], 'u_ayse');
      expect(joined['refs'], {'userId': 'u_ayse'});
      expect(joined['createdAt'], isA<Timestamp>());
      expect(written['settings_changed']!['refs'], isEmpty);
    });

    test('addToTransaction: aynı yük transaction içinde yazılır', () async {
      const draft = ActivityDraft(
        clubId: _clubId,
        actorId: 'u_pres',
        kind: ActivityKind.roleChanged,
        refs: ActivityRefsModel(userId: 'u_ayse', role: ClubRole.board),
      );

      final result = await service.runTransaction<void>(
        (tx) async => repository.addToTransaction(tx, draft),
      );

      expect(result.isSuccess, isTrue);
      final entry = (await entries()).single;
      expect(entry['kind'], 'role_changed');
      expect(entry['refs'], {'userId': 'u_ayse', 'role': 'board'});
      expect(repository.payload(draft).keys.toSet(), entry.keys.toSet());
      expect(draft.props, [
        _clubId,
        'u_pres',
        ActivityKind.roleChanged,
        const ActivityRefsModel(userId: 'u_ayse', role: ClubRole.board),
        null,
      ]);
    });

    test('sabit kimlikli kayıt o kimlikle yazılır; aynı geçişin ikinci kaydı '
        'yeni belge üretmez (CD-137)', () async {
      final id = FirestoreIds.activity(_clubId, 'u_ayse', 'member_joined', 2);
      final draft = ActivityDraft(
        clubId: _clubId,
        actorId: 'u_ayse',
        kind: ActivityKind.memberJoined,
        refs: const ActivityRefsModel(userId: 'u_ayse'),
        id: id,
      );

      for (var i = 0; i < 2; i++) {
        await service.runTransaction<void>(
          (tx) async => repository.addToTransaction(tx, draft),
        );
      }
      await service.commitBatch(
        (batch) => repository.addToBatch(batch, draft),
      );

      final docs = (await db.collection('activity').get()).docs;
      expect([for (final doc in docs) doc.id], [id]);
      // Kimlik belge alanı değildir (yük beş alandır).
      expect(docs.single.data(), isNot(contains('id')));
    });
  });

  group('T-15 · ActivityRepository · listActivity', () {
    test('yalnızca bu kulübün kayıtları, en yeni üstte, sayfalı', () async {
      await seed('a1', ActivityKind.memberJoined, 1);
      await seed('a2', ActivityKind.postCreated, 2);
      await seed('a3', ActivityKind.memberLeft, 3);
      await seed('a4', ActivityKind.memberJoined, 4, clubId: 'c02');

      final first = await repository.listActivity(
        _clubId,
        const PageRequest(limit: 2),
      );
      final second = await repository.listActivity(
        _clubId,
        PageRequest(limit: 2, after: first.dataOrNull!.next),
      );

      expect(
        [for (final item in first.dataOrNull!.items) item.id],
        [
          'a3',
          'a2',
        ],
      );
      expect(first.dataOrNull!.hasMore, isTrue);
      expect([for (final item in second.dataOrNull!.items) item.id], ['a1']);
      expect(second.dataOrNull!.hasMore, isFalse);
    });

    test('kategori süzgeci yalnızca o kategorinin türlerini getirir', () async {
      await seed('a1', ActivityKind.memberJoined, 1);
      await seed('a2', ActivityKind.postCreated, 2);
      await seed('a3', ActivityKind.applicationReceived, 3);
      await seed('a4', ActivityKind.eventPublished, 4);

      final membership = await repository.listActivity(
        _clubId,
        const PageRequest(),
        category: ActivityCategory.membership,
      );

      expect(
        [for (final item in membership.dataOrNull!.items) item.id],
        [
          'a3',
          'a1',
        ],
      );
      expect(
        membership.dataOrNull!.items.map((item) => item.category).toSet(),
        {ActivityCategory.membership},
      );
    });

    test('geçersiz kimlik invalidArgument (W-54); bozuk kayıt parse', () async {
      await db.collection('activity').doc('a1').set({
        'clubId': _clubId,
        'actorId': 5,
        'kind': 'member_joined',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 9)),
      });

      for (final id in ['', 'c/1', '..', '__id__']) {
        expect(
          (await repository.listActivity(id, const PageRequest())).errorOrNull,
          FirestoreError.invalidArgument,
        );
      }
      expect(
        (await repository.listActivity(
          _clubId,
          const PageRequest(),
        )).errorOrNull,
        FirestoreError.parse,
      );
    });
  });

  group('T-38 · ActivityRepository.countByWeek (CD-46)', () {
    // 1 Eylül 2026 Istanbul gün başı.
    final from = DateTime.utc(2026, 8, 31, 21);

    Future<void> seedAt(
      String id,
      ActivityKind kind,
      Duration offset, {
      String clubId = _clubId,
    }) => db.collection('activity').doc(id).set({
      'clubId': clubId,
      'actorId': 'u_pres',
      'kind': kind.json,
      'refs': const <String, Object?>{},
      'createdAt': Timestamp.fromDate(from.add(offset)),
    });

    test('tüm kulüpler, haftalık kovalar (yarı açık aralık), tür süzgeci; '
        'boş hafta 0', () async {
      const day = Duration(days: 1);
      await seedAt('a1', ActivityKind.memberJoined, Duration.zero);
      await seedAt(
        'a2',
        ActivityKind.applicationApproved,
        day * 7 - const Duration(seconds: 1),
        clubId: 'c02',
      );
      await seedAt('a3', ActivityKind.memberJoined, day * 7);
      await seedAt('a4', ActivityKind.memberLeft, day * 8);
      await seedAt('a5', ActivityKind.memberJoined, day * 21, clubId: 'c03');
      await seedAt('a6', ActivityKind.memberJoined, -day);
      await seedAt('a7', ActivityKind.memberJoined, day * 28);

      final result = await repository.countByWeek(
        kinds: {ActivityKind.memberJoined, ActivityKind.applicationApproved},
        fromUtc: from,
        weeks: 4,
      );

      expect(result.dataOrNull, [2, 1, 0, 1]);
    });

    test('boş tür kümesi / pozitif olmayan hafta → invalidArgument (sorgu '
        'yok)', () async {
      final empty = await repository.countByWeek(
        kinds: const {},
        fromUtc: from,
        weeks: 8,
      );
      final zero = await repository.countByWeek(
        kinds: const {ActivityKind.memberJoined},
        fromUtc: from,
        weeks: 0,
      );
      expect(empty.errorOrNull, FirestoreError.invalidArgument);
      expect(zero.errorOrNull, FirestoreError.invalidArgument);
    });
  });
}

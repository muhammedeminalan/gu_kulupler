// T-15 · ClubRepository: kulüp listesi (silinmemiş süzgeci, istemci
// sıralaması, üst sınır), tekil okuma (silinmiş = yok, askıdaki döner), toplu
// okuma (sıra, tekilleştirme, parçalama), ad benzersizliği sorgusu, geçersiz
// kimlik (W-54), ayrıştırma hatası ve hata eşlemesi (PLAN §10.3, §10.4;
// rules-spec §3.3, §6; D-10, CD-11, CD-63).
//
// Mutlu yollar `fake_cloud_firestore` ile (Q-06); hata yolları el yazımı SDK
// çiftleriyle (`test/fakes/sdk_firestore_stubs.dart`).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../fakes/fake_app_clock.dart';
import '../fakes/sdk_firestore_stubs.dart';
import '../helpers/plan_repository_table.dart';
import '../helpers/plan_service_table.dart';

const String _interface =
    'packages/gu_data/lib/src/repositories/club_repository.dart';
const String _implementation =
    'packages/gu_data/lib/src/repositories/firebase_club_repository.dart';

/// Geçersiz belge kimlikleri (W-54).
const List<String> _invalidIds = ['', 'c/1', '..', '__id__'];

/// Security Rules'un kimlik listeli kulüp sorgusuna davranışını taklit eden
/// servis: her liste okuması ret; tekil okumada [deniedIds] ret (silinmiş
/// kulüp), diğerleri [_inner] servisinden gelir.
final class _IdListDeniedService implements FirestoreService {
  _IdListDeniedService(this._inner, {required this.deniedIds});

  final FirestoreService _inner;

  /// Tekil okuması reddedilen kulüp kimlikleri.
  final Set<String> deniedIds;

  /// Tekil okunan kulüp kimlikleri, sırayla.
  final List<String> singleReads = [];

  @override
  DocumentReference<Json> doc(String collectionPath, String id) =>
      _inner.doc(collectionPath, id);

  @override
  Query<Json> collection(String path) => _inner.collection(path);

  @override
  Future<FirestoreResult<List<FirestoreDoc>>> getList(Query<Json> query) =>
      Future.value(const FirebaseFailure(FirestoreError.permissionDenied));

  @override
  Future<FirestoreResult<FirestoreDoc?>> getDoc(DocumentReference<Json> ref) {
    singleReads.add(ref.id);
    return deniedIds.contains(ref.id)
        ? Future.value(const FirebaseFailure(FirestoreError.permissionDenied))
        : _inner.getDoc(ref);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Okuma sayacı: tekil ve liste okumalarını sayar, [_inner] servisine iletir.
/// Yazımlar doğrudan iç servisten yapılır (yazım kancası oradadır).
final class _CountingReads implements FirestoreService {
  _CountingReads(this._inner);

  final FirestoreService _inner;

  /// `getDoc` çağrı sayısı.
  int docReads = 0;

  /// `getList` çağrı sayısı.
  int listReads = 0;

  @override
  DocumentReference<Json> doc(String collectionPath, String id) =>
      _inner.doc(collectionPath, id);

  @override
  Query<Json> collection(String path) => _inner.collection(path);

  @override
  Future<FirestoreResult<FirestoreDoc?>> getDoc(DocumentReference<Json> ref) {
    docReads++;
    return _inner.getDoc(ref);
  }

  @override
  Future<FirestoreResult<List<FirestoreDoc>>> getList(Query<Json> query) {
    listReads++;
    return _inner.getList(query);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeFirebaseFirestore db;
  late ClubRepository repository;

  Future<void> seed(
    String id, {
    String? nameLower,
    bool isDeleted = false,
    ClubStatus status = ClubStatus.active,
  }) => db
      .collection('clubs')
      .doc(id)
      .set(
        ClubModel(
          name: 'Kulüp $id',
          nameLower: nameLower ?? 'kulüp $id',
          categoryId: 'k01',
          iconName: 'code-xml',
          palette: ClubPalette.red,
          pattern: ClubPattern.dots,
          founded: 2015,
          presidentId: 'u_pres',
          status: status,
          isDeleted: isDeleted,
        ).toJson(),
      );

  /// Her çağrısı [code] hatasıyla biten veritabanına bağlı repository.
  ClubRepository failing(String code) => FirebaseClubRepository(
    FirebaseFirestoreService(StubFirestore(error: firestoreException(code))),
  );

  setUp(() {
    db = FakeFirebaseFirestore();
    repository = FirebaseClubRepository(FirebaseFirestoreService(db));
  });

  group('T-15 · ClubRepository · sözleşme', () {
    test('PLAN §10.4 tablosundaki üyeler arayüzde aynı imzayla var; yazma '
        'üyesi yok (salt okunur)', () {
      final plan = readPlanRepositoryMembers('$ClubRepository');

      expect(plan.map((row) => row.member), [
        'fetchActiveClubs',
        'watchActiveClubs',
        'getClub',
        'getClubs',
        'isNameTaken',
      ]);
      expect(interfaceMembers(_interface, '$ClubRepository').toSet(), {
        for (final row in plan) normalizeDartSource(row.signature),
      });
    });

    test('arayüzde ve uygulamada silme üyesi yok (D-10)', () {
      expect(deleteIdentifiersIn(_interface), isEmpty);
      expect(deleteIdentifiersIn(_implementation), isEmpty);
    });
  });

  group('T-15 · ClubRepository · fetchActiveClubs', () {
    test('silinmiş kulüp gelmez, askıdaki gelir; sıra nameLower', () async {
      await seed('c03', nameLower: 'zeytin');
      await seed('c01', nameLower: 'müzik', status: ClubStatus.suspended);
      await seed('c02', nameLower: 'dağcılık');
      await seed('c04', nameLower: 'atletizm', isDeleted: true);

      final clubs = (await repository.fetchActiveClubs()).dataOrNull!;

      expect([for (final club in clubs) club.id], ['c02', 'c01', 'c03']);
      expect(clubs[1].isSuspended, isTrue);
    });

    test('tek okuma en çok Limits.clubsFetchMax kulüp getirir', () async {
      for (var i = 0; i <= Limits.clubsFetchMax; i++) {
        await seed('c${i.toString().padLeft(3, '0')}');
      }

      final clubs = (await repository.fetchActiveClubs()).dataOrNull!;

      expect(clubs, hasLength(Limits.clubsFetchMax));
    });
  });

  group('T-15 · ClubRepository · getClub', () {
    test(
      'kulüp döner (askıdaki dahil); yok ya da silinmiş → notFound',
      () async {
        await seed('c01', status: ClubStatus.suspended);
        await seed('c02', isDeleted: true);

        final found = await repository.getClub('c01');
        final deleted = await repository.getClub('c02');
        final missing = await repository.getClub('c09');

        expect(found.dataOrNull!.id, 'c01');
        expect(found.dataOrNull!.isSuspended, isTrue);
        expect(deleted.errorOrNull, FirestoreError.notFound);
        expect(missing.errorOrNull, FirestoreError.notFound);
      },
    );

    test('ayrıştırılamayan belge parse', () async {
      await db.collection('clubs').doc('c01').set({
        'name': 5,
        'isDeleted': false,
      });

      expect(
        (await repository.getClub('c01')).errorOrNull,
        FirestoreError.parse,
      );
      expect(
        (await repository.fetchActiveClubs()).errorOrNull,
        FirestoreError.parse,
      );
    });
  });

  group('T-15 · ClubRepository · getClubs', () {
    test(
      'istenen sırada döner; tekrar, olmayan ve silinmiş kulüp atlanır',
      () async {
        await seed('c01');
        await seed('c02', isDeleted: true);
        await seed('c03');

        final clubs = await repository.getClubs(['c03', 'c09', 'c01', 'c03']);

        expect([for (final club in clubs.dataOrNull!) club.id], ['c03', 'c01']);
      },
    );

    test(
      '30 kimlikten fazlası parçalanır; boş liste sorgusuz boş döner',
      () async {
        final ids = [for (var i = 0; i < 35; i++) 'c${i + 10}'];
        for (final id in ids) {
          await seed(id);
        }

        final clubs = await repository.getClubs(ids);
        final none = await failing('permission-denied').getClubs(const []);

        expect([for (final club in clubs.dataOrNull!) club.id], ids);
        expect(none.dataOrNull, isEmpty);
      },
    );

    test('toplu sorgu reddedilirse (Rules: listede silinmiş / olmayan tek '
        'kimlik) kimlikler tek tek okunur; okunamayan atlanır', () async {
      await seed('c01');
      await seed('c02', isDeleted: true);
      await seed('c03');
      final service = _IdListDeniedService(
        FirebaseFirestoreService(db),
        deniedIds: {'c02'},
      );

      final clubs = await FirebaseClubRepository(
        service,
      ).getClubs(['c03', 'c02', 'c09', 'c01']);

      expect([for (final club in clubs.dataOrNull!) club.id], ['c03', 'c01']);
      expect(service.singleReads, ['c03', 'c02', 'c09', 'c01']);
    });

    test('hiçbir kimlik okunamıyorsa ret aynen döner (yetkisiz çağrı boş '
        'liste görmez)', () async {
      await seed('c01');
      final service = _IdListDeniedService(
        FirebaseFirestoreService(db),
        deniedIds: {'c01', 'c02'},
      );

      final clubs = await FirebaseClubRepository(
        service,
      ).getClubs(['c01', 'c02']);

      expect(clubs.errorOrNull, FirestoreError.permissionDenied);
    });
  });

  group('T-15 · ClubRepository · isNameTaken', () {
    test('ad varsa true (silinmiş kulübün adı da dolu), yoksa false', () async {
      await seed('c01', nameLower: 'yazılım kulübü');
      await seed('c02', nameLower: 'eski kulüp', isDeleted: true);

      expect(
        (await repository.isNameTaken('yazılım kulübü')).dataOrNull,
        isTrue,
      );
      expect((await repository.isNameTaken('eski kulüp')).dataOrNull, isTrue);
      expect((await repository.isNameTaken('satranç')).dataOrNull, isFalse);
    });

    test('geçersiz ad sorgu yapmadan invalidArgument', () async {
      final denied = failing('permission-denied');

      for (final name in ['', ' ', 'a', 'x' * (Limits.clubNameMax + 1)]) {
        expect(
          (await denied.isNameTaken(name)).errorOrNull,
          FirestoreError.invalidArgument,
          reason: '"$name"',
        );
      }
    });
  });

  group('T-15 · ClubRepository · geçersiz kimlik ve hata eşlemesi', () {
    test('geçersiz kimlik invalidArgument döner (W-54)', () async {
      for (final id in _invalidIds) {
        expect(
          (await repository.getClub(id)).errorOrNull,
          FirestoreError.invalidArgument,
        );
        expect(
          (await repository.getClubs(['c01', id])).errorOrNull,
          FirestoreError.invalidArgument,
        );
      }
    });

    test('SDK hatası sözlüğe çevrilir', () async {
      final denied = failing('permission-denied');

      final results = <FirestoreResult<Object?>>[
        await denied.fetchActiveClubs(),
        await denied.getClub('c01'),
        await denied.getClubs(['c01']),
        await denied.isNameTaken('yazılım kulübü'),
      ];

      for (final result in results) {
        expect(result.errorOrNull, FirestoreError.permissionDenied);
      }
    });
  });

  group('T-44 · ClubRepository · bellek önbelleği (D3-01)', () {
    late FakeAppClock clock;
    late FirebaseFirestoreService service;
    late _CountingReads reads;
    late ClubRepository cached;

    setUp(() async {
      clock = FakeAppClock(DateTime.utc(2026, 10, 15, 9));
      service = FirebaseFirestoreService(db);
      final caches = RepositoryReadCaches(clock);
      addTearDown(caches.dispose);
      service.addWriteListener(caches.onWrite);
      reads = _CountingReads(service);
      cached = FirebaseClubRepository(reads, cache: caches);
      await seed('c01');
      await seed('c02');
    });

    Future<String?> nameOf(String id) async =>
        (await cached.getClub(id)).dataOrNull?.name;

    test(
      'TTL içinde etkin liste ve kulüp ikinci kez okunmaz; liste okuması '
      'kulüpleri de yazar; süre dolunca ve forceRefresh ile okunur',
      () async {
        expect((await cached.fetchActiveClubs()).dataOrNull, hasLength(2));
        expect((await cached.fetchActiveClubs()).dataOrNull, hasLength(2));
        expect(await nameOf('c01'), 'Kulüp c01');
        expect((reads.listReads, reads.docReads), (1, 0));

        await cached.fetchActiveClubs(forceRefresh: true);
        await cached.getClub('c01', forceRefresh: true);
        expect((reads.listReads, reads.docReads), (2, 1));

        clock.advance(CachePolicy.clubTtl);
        await cached.getClub('c02');
        await cached.fetchActiveClubs();
        expect((reads.listReads, reads.docReads), (3, 2));
      },
    );

    test(
      'dönen liste kopyadır: çağıranın değişikliği önbelleği bozmaz',
      () async {
        final first = (await cached.fetchActiveClubs()).dataOrNull!..clear();
        expect(first, isEmpty);
        expect((await cached.fetchActiveClubs()).dataOrNull, hasLength(2));
      },
    );

    test('servis üzerinden kulübe tekil yazım, batch ve transaction ilgili '
        'kulübü ve etkin listeyi eşzamanlı geçersiz kılar', () async {
      await cached.fetchActiveClubs();
      final c01 = service.doc(FirestoreCollections.clubs, 'c01');
      final c02 = service.doc(FirestoreCollections.clubs, 'c02');

      await service.update(c01, {'name': 'Tekil'});
      expect(await nameOf('c01'), 'Tekil');
      expect(reads.docReads, 1);

      await service.commitBatch(
        (batch) => batch.update(c02, {'name': 'Batch'}),
      );
      expect(await nameOf('c02'), 'Batch');
      expect(reads.docReads, 2);

      await service.runTransaction((tx) async {
        await tx.get(c01);
        tx.update(c01, {'memberCount': 7});
      });
      expect((await cached.getClub('c01')).dataOrNull?.memberCount, 7);
      expect(reads.docReads, 3);

      // Liste de yeniden okunur ve yazımları görür.
      final list = (await cached.fetchActiveClubs()).dataOrNull!;
      expect(reads.listReads, 2);
      expect({for (final club in list) club.name}, {'Tekil', 'Batch'});
    });

    test('getClubs: önbellekteki kulüp bellekten, yalnızca eksik olan okunur; '
        'forceRefresh hepsini okur', () async {
      await cached.getClub('c01');
      // Servisi atlayan değişiklik (kanca yok): bellekteki kopya görünür.
      await db.collection('clubs').doc('c01').update({'name': 'Dolaylı'});

      final both = (await cached.getClubs(['c02', 'c01'])).dataOrNull!;
      expect([for (final club in both) club.id], ['c02', 'c01']);
      expect(both.last.name, 'Kulüp c01');
      expect(reads.listReads, 1);

      // İkisi de artık bellekte: okuma yok.
      await cached.getClubs(['c01', 'c02']);
      expect(reads.listReads, 1);

      final fresh = (await cached.getClubs([
        'c01',
      ], forceRefresh: true)).dataOrNull!;
      expect(fresh.single.name, 'Dolaylı');
      expect(reads.listReads, 2);
    });

    test('olmayan kulüp (notFound) ve hata önbelleğe yazılmaz; eşzamanlı '
        'aynı okuma birleşir', () async {
      expect(
        (await cached.getClub('c_yok')).errorOrNull,
        FirestoreError.notFound,
      );
      expect(
        (await cached.getClub('c_yok')).errorOrNull,
        FirestoreError.notFound,
      );
      expect(reads.docReads, 2);

      final results = await Future.wait([
        cached.getClub('c02'),
        cached.getClub('c02'),
      ]);
      expect(results.map((r) => r.dataOrNull?.id), ['c02', 'c02']);
      expect(reads.docReads, 3);
    });

    test('önbelleksiz repository (cache: null) her çağrıda okur', () async {
      final plain = FirebaseClubRepository(reads);
      await plain.getClub('c01');
      await plain.getClub('c01');
      expect(reads.docReads, 2);
    });
  });
}

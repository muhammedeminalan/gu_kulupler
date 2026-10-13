// T-19 · AnnouncementCounterRepository: günün (Istanbul) duyuru sayacı ve
// kalan hak; gün sınırı penceresinde komşu günün belgesi de okunur ve sayısı
// büyük olan döner (W-50, CD-129); pencere sınırları (`adjacentDayInstant` /
// `adjacentDayKey`); sayaç artışının yükü (`set(merge)`, +1, `lastPostRef`)
// ve hak dolunca yazımdan önce ret; geçersiz kimlik, ayrıştırma ve hata
// eşlemesi (PLAN §10.4; rules-spec §3.16; Q-10; docs/plans/T-19.md §6.c).
//
// Mutlu yollar `fake_cloud_firestore` ile (Q-06); hata yolları el yazımı SDK
// çiftleriyle (`test/fakes/sdk_firestore_stubs.dart`).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../fakes/fake_app_clock.dart';
import '../fakes/sdk_firestore_stubs.dart';
import '../helpers/plan_service_table.dart';
import '../helpers/repo_sources.dart';

const String _interface =
    'packages/gu_data/lib/src/repositories/'
    'announcement_counter_repository.dart';
const String _implementation =
    'packages/gu_data/lib/src/repositories/'
    'firebase_announcement_counter_repository.dart';

const String _clubId = 'c01';
const String _day13 = '20261013';
const String _day14 = '20261014';

/// Istanbul'da 13 Ekim 2026 12:00 — gün sınırı penceresinin dışında.
final DateTime _noon = DateTime.utc(2026, 10, 13, 9);

/// Istanbul'da 14 Ekim 00:00 (gün sınırı).
final DateTime _midnight = DateTime.utc(2026, 10, 13, 21);

/// Geçersiz belge kimlikleri (W-54).
const List<String> _invalidIds = ['', 'c/1', '..', '__id__'];

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreService service;
  late FakeAppClock clock;
  late FirebaseAnnouncementCounterRepository repository;

  Future<Json?> read(String dayKey) async =>
      (await db.doc('announcementCounters/${_clubId}_$dayKey').get()).data();

  Future<void> seed(String dayKey, int count, {String clubId = _clubId}) => db
      .doc('announcementCounters/${clubId}_$dayKey')
      .set(
        CounterModel(
          clubId: clubId,
          day:
              '${dayKey.substring(0, 4)}-${dayKey.substring(4, 6)}-'
              '${dayKey.substring(6)}',
          count: count,
          lastPostRef: 'posts/p_son',
        ).toJson(),
      );

  setUp(() {
    db = FakeFirebaseFirestore();
    service = FirebaseFirestoreService(db);
    clock = FakeAppClock(_noon);
    repository = FirebaseAnnouncementCounterRepository(service, clock);
  });

  group('T-19 · AnnouncementCounterRepository · sözleşme', () {
    test('PLAN §10.4 tablosunun okuma üyeleri arayüzde, SDK tipi alan '
        'addToBatch uygulama sınıfında aynı imzayla var', () {
      final rows = markdownTable(
        readRepoFile('docs/PLAN.md'),
        heading: '#### $AnnouncementCounterRepository ',
      ).rows;
      // Son satır ("gece yarısı kenarı") bir üye değil, davranış notudur.
      final signatures = {
        for (final row in rows)
          if (codeSpans(row[0]).isNotEmpty)
            codeSpans(row[0]).first: normalizeDartSource(
              codeSpans(row[1]).first,
            ),
      };
      final interface = normalizeDartSource(readRepoFile(_interface));
      final implementation = normalizeDartSource(readRepoFile(_implementation));

      expect(signatures.keys, ['getToday', 'remainingToday', 'addToBatch']);
      expect(interface, contains('${signatures['getToday']};'));
      expect(interface, contains('${signatures['remainingToday']};'));
      // Arayüz SDK tipi sızdırmaz (sınır kuralı B08).
      expect(interface, isNot(contains('WriteBatch')));
      expect(implementation, contains(signatures['addToBatch']));
    });

    test('sayaç silinmez ve sıfırlanmaz: silme üyesi yok (D-10)', () {
      expect(deleteIdentifiersIn(_interface), isEmpty);
      expect(deleteIdentifiersIn(_implementation), isEmpty);
    });
  });

  group('T-19 · getToday / remainingToday', () {
    test('pencere dışında yalnızca cihaz gününün belgesi: belge yok → null '
        've hakkın tamamı; belge → sayaç ve kalan hak', () async {
      await seed(_day14, 2);
      await seed(_day13, 2, clubId: 'c02');

      final none = await repository.getToday(_clubId);
      final full = await repository.remainingToday(_clubId);
      await seed(_day13, 1);
      final today = await repository.getToday(_clubId);
      final left = await repository.remainingToday(_clubId);

      expect(none.isSuccess, isTrue);
      expect(none.dataOrNull, isNull);
      expect(full.dataOrNull, Limits.announcementDailyLimit);
      expect(today.dataOrNull!.id, 'c01_$_day13');
      expect(today.dataOrNull!.day, '2026-10-13');
      expect(today.dataOrNull!.count, 1);
      expect(today.dataOrNull!.lastPostRef, 'posts/p_son');
      expect(left.dataOrNull, 1);
    });

    test('kalan hak negatif olmaz', () async {
      await seed(_day13, Limits.announcementDailyLimit + 1);

      expect((await repository.remainingToday(_clubId)).dataOrNull, 0);
    });

    test('gün başından sonraki pencere: dünün belgesi de okunur, sayısı '
        'büyük olan döner (vaat edilen hak kurallarda reddedilmez)', () async {
      clock.set(_midnight.add(const Duration(minutes: 2)));
      await seed(_day13, 2);

      final yesterdayFull = await repository.getToday(_clubId);
      final remaining = await repository.remainingToday(_clubId);

      expect(yesterdayFull.dataOrNull!.id, 'c01_$_day13');
      expect(remaining.dataOrNull, 0);
    });

    test('gün bitmeden önceki pencere: yarının belgesi de okunur; eşitlikte '
        'cihaz günü döner', () async {
      clock.set(_midnight.subtract(const Duration(minutes: 2)));
      await seed(_day13, 1);
      await seed(_day14, 1);

      final tie = await repository.getToday(_clubId);
      await seed(_day14, 2);
      final tomorrowFull = await repository.getToday(_clubId);

      expect(tie.dataOrNull!.id, 'c01_$_day13');
      expect(tomorrowFull.dataOrNull!.id, 'c01_$_day14');
    });

    test('pencere içinde iki belge de yoksa null', () async {
      clock.set(_midnight.add(const Duration(minutes: 2)));

      final result = await repository.getToday(_clubId);

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, isNull);
    });
  });

  group(
    'T-19 · gün sınırı penceresi (adjacentDayInstant / adjacentDayKey)',
    () {
      test('pencere: gün başından sonraki tolerans → dün; gün bitiminden '
          'önceki tolerans → yarın; dışında null', () {
        const tolerance = Limits.clockSkewTolerance;
        const second = Duration(seconds: 1);
        String? key(DateTime utc) =>
            AnnouncementCounterRepository.adjacentDayKey(clock, utc);

        expect(key(_noon), isNull);
        // Gün bitiminden önce: [gün sonu − tolerans, gün sonu) → yarın.
        expect(key(_midnight.subtract(tolerance).subtract(second)), isNull);
        expect(key(_midnight.subtract(tolerance)), _day14);
        expect(key(_midnight.subtract(second)), _day14);
        // Gün başından sonra: [gün başı, gün başı + tolerans) → dün.
        expect(key(_midnight), _day13);
        expect(key(_midnight.add(tolerance).subtract(second)), _day13);
        expect(key(_midnight.add(tolerance)), isNull);

        final instant = AnnouncementCounterRepository.adjacentDayInstant(
          clock,
          _midnight,
        )!;
        expect(clock.istanbulDay(instant), '2026-10-13');
      });
    },
  );

  group('T-19 · sayaç artışı (addToBatch / addToTransaction)', () {
    Future<FirestoreResult<void>> viaBatch(int previousCount, String postId) =>
        service.commitBatch(
          (batch) => repository.addToBatch(
            batch,
            clubId: _clubId,
            dayKey: _day13,
            day: '2026-10-13',
            previousCount: previousCount,
            postId: postId,
          ),
        );

    test('ilk artış belgeyi kurar, ikincisi yalnızca count + lastPostRef + '
        'updatedAt alanlarını değiştirir (set merge)', () async {
      final first = await viaBatch(0, 'p01');
      final created = (await read(_day13))!;
      final second = await service.runTransaction<void>((tx) async {
        repository.addToTransaction(
          tx,
          clubId: _clubId,
          dayKey: _day13,
          day: '2026-10-13',
          previousCount: 1,
          postId: 'p02',
        );
      });
      final updated = (await read(_day13))!;

      expect(first.isSuccess, isTrue);
      expect(created.keys.toSet(), {
        'clubId',
        'day',
        'count',
        'lastPostRef',
        'updatedAt',
      });
      expect(created['clubId'], _clubId);
      expect(created['day'], '2026-10-13');
      expect(created['count'], 1);
      expect(created['lastPostRef'], 'posts/p01');
      expect(created['updatedAt'], isA<Timestamp>());
      expect(second.isSuccess, isTrue);
      expect(updated['count'], 2);
      expect(updated['lastPostRef'], 'posts/p02');
      expect(updated.keys.toSet(), created.keys.toSet());
    });

    test('hak dolmuşsa artış işleme girmez: '
        'announcementLimit, belge değişmez', () async {
      await seed(_day13, Limits.announcementDailyLimit);
      final before = await read(_day13);

      final batched = await viaBatch(Limits.announcementDailyLimit, 'p03');
      final transacted = await service.runTransaction<void>((tx) async {
        repository.addToTransaction(
          tx,
          clubId: _clubId,
          dayKey: _day13,
          day: '2026-10-13',
          previousCount: Limits.announcementDailyLimit,
          postId: 'p03',
        );
      });

      for (final result in [batched, transacted]) {
        expect(result.errorOrNull, FirestoreError.ruleViolation);
        expect(
          switch (result) {
            FirebaseFailure(:final detail) => detail,
            FirebaseSuccess() => null,
          },
          const FirestoreFailureDetail(FirestoreRuleCode.announcementLimit),
        );
      }
      expect(await read(_day13), before);
    });
  });

  group('T-19 · geçersiz kimlik, ayrıştırma ve hata eşlemesi', () {
    test('geçersiz kimlik invalidArgument (W-54)', () async {
      for (final id in _invalidIds) {
        expect(
          (await repository.getToday(id)).errorOrNull,
          FirestoreError.invalidArgument,
          reason: 'kimlik "$id"',
        );
        expect(
          (await repository.remainingToday(id)).errorOrNull,
          FirestoreError.invalidArgument,
          reason: 'kimlik "$id"',
        );
      }
    });

    test('ayrıştırılamayan sayaç parse; SDK hatası sözlüğe çevrilir', () async {
      await db.doc('announcementCounters/c01_$_day13').set({'count': 'iki'});
      final denied = FirebaseAnnouncementCounterRepository(
        FirebaseFirestoreService(
          StubFirestore(error: firestoreException('permission-denied')),
        ),
        clock,
      );

      expect(
        (await repository.getToday(_clubId)).errorOrNull,
        FirestoreError.parse,
      );
      expect(
        (await repository.remainingToday(_clubId)).errorOrNull,
        FirestoreError.parse,
      );
      expect(
        (await denied.getToday(_clubId)).errorOrNull,
        FirestoreError.permissionDenied,
      );
      expect(
        (await denied.remainingToday(_clubId)).errorOrNull,
        FirestoreError.permissionDenied,
      );
    });

    test('pencere içinde komşu günün okuma hatası yutulmaz', () async {
      clock.set(_midnight.add(const Duration(minutes: 2)));
      await seed(_day14, 1);
      await db.doc('announcementCounters/c01_$_day13').set({'count': 'iki'});

      expect(
        (await repository.getToday(_clubId)).errorOrNull,
        FirestoreError.parse,
      );
    });
  });
}

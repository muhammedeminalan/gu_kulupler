// T-10 · FirestoreService: yol/kimlik kurucuları, okuma (tekil, liste, sayfa,
// sayım), yazma (add/set/update), soft delete / geri alma, batch, transaction,
// canlı dinleme, hata → FirebaseFailure eşlemesi, zaman aşımı ve "silme yok"
// sözleşmesi (PLAN §10.1–§10.3; soft-delete.md §3–§4, §7; D-10, D-34).
//
// Mutlu yollar `fake_cloud_firestore` ile (Q-06); hata ve zaman aşımı yolları
// el yazımı SDK çiftleriyle (`test/fakes/sdk_firestore_stubs.dart`).
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../fakes/sdk_firestore_stubs.dart';
import '../helpers/plan_service_table.dart';
import '../helpers/repo_sources.dart';

const String _source =
    'packages/gu_data/lib/src/services/firestore_service.dart';

/// Canlı (silinmemiş) gönderi belgesi.
Json _post(String text, {int order = 0}) => {
  'text': text,
  'order': order,
  ...BaseFieldsPayload.create(),
};

/// İki belge hali arasında değeri değişen, eklenen ya da kalkan anahtarlar.
Set<String> _changedKeys(Json before, Json after) => {
  for (final key in {...before.keys, ...after.keys})
    if (!before.containsKey(key) ||
        !after.containsKey(key) ||
        before[key] != after[key])
      key,
};

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreService service;
  late DocumentReference<Json> post;

  Future<Json?> read(DocumentReference<Json> ref) async =>
      (await ref.get()).data();

  Future<void> seed(Iterable<String> ids) async {
    var order = 0;
    for (final id in ids) {
      await db
          .collection(FirestoreCollections.posts)
          .doc(id)
          .set(_post(id, order: order++));
    }
  }

  Query<Json> liveOrdered() => service
      .collection(FirestoreCollections.posts)
      .where(FirestoreFields.isDeleted, isEqualTo: false)
      .orderBy('order');

  setUp(() {
    db = FakeFirebaseFirestore();
    service = FirebaseFirestoreService(db);
    post = service.doc(FirestoreCollections.posts, 'p01');
  });

  group('T-10 · FirestoreService · yol ve kimlik', () {
    test('doc: koleksiyon yolu + kimlik', () {
      expect(post.path, 'posts/p01');
      expect(post.id, 'p01');
    });

    test('doc: kimlik tek yol parçası olmalı — boş ya da "/" içeren kimlik '
        'başka bir yola dönüşemez (ArgumentError)', () {
      for (final id in ['', '/', 'a/b', 'p01/votes/u_ayse', '../users/u1']) {
        expect(
          () => service.doc(FirestoreCollections.posts, id),
          throwsArgumentError,
          reason: '"$id"',
        );
      }
    });

    test('newId: her çağrıda yeni kimlik üretir, belge yazmaz', () async {
      final first = service.newId(FirestoreCollections.posts);
      final second = service.newId(FirestoreCollections.posts);

      expect(first, isNotEmpty);
      expect(first, isNot(second));
      expect(
        (await db.collection(FirestoreCollections.posts).get()).docs,
        isEmpty,
      );
    });

    test(
      'collectionGroup: aynı adlı alt koleksiyonların hepsini sorgular',
      () async {
        for (final uid in ['u1', 'u2']) {
          await db
              .collection(FirestoreCollections.users)
              .doc(uid)
              .collection(FirestoreCollections.privateSub)
              .doc(FirestoreCollections.accountDoc)
              .set({'uid': uid});
        }

        final result = await service.getList(
          service.collectionGroup(FirestoreCollections.privateSub),
        );

        expect(
          [for (final doc in result.dataOrNull!) doc.path],
          unorderedEquals([
            'users/u1/private/account',
            'users/u2/private/account',
          ]),
        );
      },
    );

    test(
      'serverTimestamp: yazılınca sunucu zamanına çözülen nöbetçi',
      () async {
        final sentinel = service.serverTimestamp();

        await service.set(post, {'at': sentinel});

        expect(sentinel, isA<FieldValue>());
        expect((await read(post))!['at'], isA<Timestamp>());
      },
    );
  });

  group('T-10 · FirestoreService · okuma', () {
    test(
      'getDoc: var olan belge kimliği, yolu, verisi ve snapshot ile döner',
      () async {
        await post.set({'text': 'Merhaba'});

        final doc = (await service.getDoc(post)).dataOrNull!;

        expect(doc.id, 'p01');
        expect(doc.path, 'posts/p01');
        expect(doc.data, {'text': 'Merhaba'});
        expect(doc.snapshot.id, 'p01');
        expect(doc.toString(), 'FirestoreDoc(posts/p01)');
      },
    );

    test('getDoc: belge yoksa başarı + null (hata değil)', () async {
      final result = await service.getDoc(post);

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, isNull);
    });

    test(
      'getList: sorgu sırasıyla tüm belgeler; boş sonuç başarıdır',
      () async {
        final empty = await service.getList(liveOrdered());
        await seed(['a', 'b', 'c']);

        final full = await service.getList(liveOrdered());

        expect(empty.isSuccess, isTrue);
        expect(empty.dataOrNull, isEmpty);
        expect([for (final doc in full.dataOrNull!) doc.id], ['a', 'b', 'c']);
      },
    );

    test('count: eşleşen belge sayısı', () async {
      await seed(['a', 'b', 'c']);

      expect((await service.count(liveOrdered())).dataOrNull, 3);
    });

    test('silinmiş belge isDeleted == false süzgeçli sorgudan düşer, geri '
        'alınınca döner (soft-delete.md §4)', () async {
      await seed(['a', 'b', 'c']);
      final b = service.doc(FirestoreCollections.posts, 'b');
      Future<List<String>> liveIds() async => [
        for (final doc in (await service.getList(liveOrdered())).dataOrNull!)
          doc.id,
      ];

      await service.softDelete(b, actorId: 'u_ayse');
      final afterDelete = await liveIds();
      await service.restore(b);

      expect(afterDelete, ['a', 'c']);
      expect(await liveIds(), ['a', 'b', 'c']);
      expect((await service.count(liveOrdered())).dataOrNull, 3);
    });
  });

  group('T-10 · FirestoreService · sayfalama', () {
    test('dolu sayfa imleç taşır; imleç kaldığı yerden devam eder; eksik '
        'sayfa listeyi bitirir', () async {
      await seed(['a', 'b', 'c', 'd', 'e']);

      final first = (await service.getPage(
        liveOrdered(),
        const PageRequest(limit: 2),
      )).dataOrNull!;
      final second = (await service.getPage(
        liveOrdered(),
        PageRequest(limit: 2, after: first.next),
      )).dataOrNull!;
      final third = (await service.getPage(
        liveOrdered(),
        PageRequest(limit: 2, after: second.next),
      )).dataOrNull!;

      expect([for (final doc in first.items) doc.id], ['a', 'b']);
      expect(first.hasMore, isTrue);
      expect([for (final doc in second.items) doc.id], ['c', 'd']);
      expect(second.hasMore, isTrue);
      expect([for (final doc in third.items) doc.id], ['e']);
      expect(third.hasMore, isFalse);
      expect(third.next, isNull);
    });

    test(
      'son sayfa tam doluysa imleç verilir ve sonraki sayfa boş gelir',
      () async {
        await seed(['a', 'b']);

        final first = (await service.getPage(
          liveOrdered(),
          const PageRequest(limit: 2),
        )).dataOrNull!;
        final second = (await service.getPage(
          liveOrdered(),
          PageRequest(limit: 2, after: first.next),
        )).dataOrNull!;

        expect(first.hasMore, isTrue);
        expect(second.items, isEmpty);
        expect(second.hasMore, isFalse);
      },
    );

    test('varsayılan istek Limits.pageSize belge ister', () async {
      await seed([for (var i = 0; i < Limits.pageSize + 1; i++) 'p$i']);

      final page = (await service.getPage(
        service.collection(FirestoreCollections.posts),
        const PageRequest(),
      )).dataOrNull!;

      expect(page.items, hasLength(Limits.pageSize));
      expect(page.hasMore, isTrue);
    });

    test(
      'test imleci (PageCursor.fake) gerçek sorguda fırlatmaz, hata döner',
      () async {
        final result = await service.getPage(
          liveOrdered(),
          PageRequest(after: PageCursor.fake()),
        );

        expect(result.errorOrNull, FirestoreError.unknown);
      },
    );
  });

  group('T-10 · FirestoreService · yazma', () {
    test('add: otomatik kimlikle yazar ve kimliği döndürür', () async {
      final id = (await service.add(
        FirestoreCollections.posts,
        _post('Yeni'),
      )).dataOrNull!;

      final data = await read(service.doc(FirestoreCollections.posts, id));
      expect(id, isNotEmpty);
      expect(data!['text'], 'Yeni');
      expect(data[FirestoreFields.createdAt], isA<Timestamp>());
    });

    test(
      'set: belgeyi yazar; varsayılan (merge: false) eski alanları siler',
      () async {
        await service.set(post, {'text': 'bir', 'pinned': true});

        final result = await service.set(post, {'text': 'iki'});

        expect(result.isSuccess, isTrue);
        expect(await read(post), {'text': 'iki'});
      },
    );

    test('set(merge: true): var olan alanlar korunur', () async {
      await service.set(post, {'text': 'bir', 'pinned': true});

      await service.set(post, {'text': 'iki'}, merge: true);

      expect(await read(post), {'text': 'iki', 'pinned': true});
    });

    test(
      'update: yalnızca verilen alanları ve updatedAt alanını değiştirir',
      () async {
        await post.set({'text': 'bir', 'pinned': true});
        final before = (await read(post))!;

        final result = await service.update(post, {'text': 'iki'});

        final after = (await read(post))!;
        expect(result.isSuccess, isTrue);
        expect(_changedKeys(before, after), {
          'text',
          FirestoreFields.updatedAt,
        });
        expect(after['text'], 'iki');
        expect(after[FirestoreFields.updatedAt], isA<Timestamp>());
      },
    );

    test(
      'update: çağıranın verdiği updatedAt değeri sunucu zamanıyla ezilir',
      () async {
        await post.set({'text': 'bir'});

        await service.update(post, {
          FirestoreFields.updatedAt: 'istemci saati',
        });

        expect(
          (await read(post))![FirestoreFields.updatedAt],
          isA<Timestamp>(),
        );
      },
    );

    test(
      'update(touchUpdatedAt: false): updatedAt yazılmaz — beğeni yazımı '
      'yalnızca likes + likeCount alanlarına dokunur (rules-spec §3.5)',
      () async {
        await post.set({
          ..._post('Merhaba'),
          'likes': <String>[],
          'likeCount': 0,
        });
        final before = (await read(post))!;

        final result = await service.update(post, {
          'likes': FieldValue.arrayUnion(['u_ayse']),
          'likeCount': FieldValue.increment(1),
        }, touchUpdatedAt: false);

        final after = (await read(post))!;
        expect(result.isSuccess, isTrue);
        expect(_changedKeys(before, after), {'likes', 'likeCount'});
        expect(after['likes'], ['u_ayse']);
        expect(after['likeCount'], 1);
        expect(
          after[FirestoreFields.updatedAt],
          before[FirestoreFields.updatedAt],
        );
      },
    );

    test('update: boş alan kümesi → invalidArgument, belge değişmez', () async {
      await post.set({'text': 'bir'});

      final result = await service.update(post, {});

      expect(result.errorOrNull, FirestoreError.invalidArgument);
      expect(await read(post), {'text': 'bir'});
    });

    test('update: belge yoksa notFound (belge oluşturulmaz)', () async {
      final result = await service.update(post, {'text': 'iki'});

      expect(result.errorOrNull, FirestoreError.notFound);
      expect((await post.get()).exists, isFalse);
    });
  });

  group('T-10 · FirestoreService · softDelete / restore', () {
    test(
      'softDelete: tam olarak SoftDelete.payload alanlarını yazar',
      () async {
        await post.set(_post('Merhaba'));
        final before = (await read(post))!;

        final result = await service.softDelete(post, actorId: 'u_ayse');

        final after = (await read(post))!;
        expect(result.isSuccess, isTrue);
        expect(after[FirestoreFields.isDeleted], isTrue);
        expect(after[FirestoreFields.deletedBy], 'u_ayse');
        expect(after[FirestoreFields.deletedAt], isA<Timestamp>());
        expect(after[FirestoreFields.updatedAt], isA<Timestamp>());
        expect(after['text'], 'Merhaba');
        expect(
          _changedKeys(before, after).difference(SoftDelete.affectedKeys),
          isEmpty,
        );
        expect((await post.get()).exists, isTrue);
      },
    );

    test(
      'restore: isDeleted false; deletedAt ve deletedBy null YAZILIR',
      () async {
        await post.set(_post('Merhaba'));
        await service.softDelete(post, actorId: 'u_ayse');

        final result = await service.restore(post);

        final after = (await read(post))!;
        expect(result.isSuccess, isTrue);
        expect(after[FirestoreFields.isDeleted], isFalse);
        expect(after.containsKey(FirestoreFields.deletedAt), isTrue);
        expect(after[FirestoreFields.deletedAt], isNull);
        expect(after.containsKey(FirestoreFields.deletedBy), isTrue);
        expect(after[FirestoreFields.deletedBy], isNull);
        expect(after['text'], 'Merhaba');
      },
    );

    test('softDelete: boş actorId → invalidArgument, belge değişmez', () async {
      await post.set(_post('Merhaba'));

      final result = await service.softDelete(post, actorId: '');

      expect(result.errorOrNull, FirestoreError.invalidArgument);
      expect((await read(post))![FirestoreFields.isDeleted], isFalse);
    });

    test(
      'softDelete / restore: belge yoksa notFound (belge oluşturulmaz)',
      () async {
        final deleted = await service.softDelete(post, actorId: 'u_ayse');
        final restored = await service.restore(post);

        expect(deleted.errorOrNull, FirestoreError.notFound);
        expect(restored.errorOrNull, FirestoreError.notFound);
        expect((await post.get()).exists, isFalse);
      },
    );

    test("batch verilirse yazım batch'e eklenir; commitBatch gövdesinde "
        'beklemeden kullanılır', () async {
      await seed(['a', 'b']);
      final a = service.doc(FirestoreCollections.posts, 'a');
      final b = service.doc(FirestoreCollections.posts, 'b');
      await service.softDelete(b, actorId: 'u_ayse');
      late final Future<FirestoreResult<void>> queuedDelete;
      late final Future<FirestoreResult<void>> queuedRestore;

      final result = await service.commitBatch((batch) {
        queuedDelete = service.softDelete(a, actorId: 'u_ayse', batch: batch);
        queuedRestore = service.restore(b, batch: batch);
      });

      expect(result.isSuccess, isTrue);
      expect((await queuedDelete).isSuccess, isTrue);
      expect((await queuedRestore).isSuccess, isTrue);
      expect((await read(a))![FirestoreFields.isDeleted], isTrue);
      expect((await read(a))![FirestoreFields.deletedBy], 'u_ayse');
      expect((await read(b))![FirestoreFields.isDeleted], isFalse);
    });

    test('batch verilip commit edilmezse belge değişmez', () async {
      await seed(['a']);
      final a = service.doc(FirestoreCollections.posts, 'a');

      final result = await service.softDelete(
        a,
        actorId: 'u_ayse',
        batch: db.batch(),
      );

      expect(result.isSuccess, isTrue);
      expect((await read(a))![FirestoreFields.isDeleted], isFalse);
    });
  });

  group('T-10 · FirestoreService · commitBatch', () {
    test('set ve update yazımları birlikte uygulanır', () async {
      await seed(['a']);
      final a = service.doc(FirestoreCollections.posts, 'a');
      final b = service.doc(FirestoreCollections.posts, 'b');

      final result = await service.commitBatch((batch) {
        batch
          ..update(a, {'likeCount': 1})
          ..set(b, _post('b'))
          ..set(a, {'pinned': true}, SetOptions(merge: true));
      });

      expect(result.isSuccess, isTrue);
      expect((await read(a))!['likeCount'], 1);
      expect((await read(a))!['pinned'], isTrue);
      expect((await read(b))!['text'], 'b');
    });

    test('tam Limits.batchMaxWrites yazım kabul edilir', () async {
      final result = await service.commitBatch((batch) {
        for (var i = 0; i < Limits.batchMaxWrites; i++) {
          batch.set(service.doc(FirestoreCollections.posts, 'p$i'), {'i': i});
        }
      });

      expect(result.isSuccess, isTrue);
      expect(
        (await db.collection(FirestoreCollections.posts).get()).docs,
        hasLength(Limits.batchMaxWrites),
      );
    });

    test(
      'sınırı aşan batch → invalidArgument; hiçbir yazım uygulanmaz',
      () async {
        final result = await service.commitBatch((batch) {
          for (var i = 0; i <= Limits.batchMaxWrites; i++) {
            batch.set(service.doc(FirestoreCollections.posts, 'p$i'), {'i': i});
          }
        });

        expect(result.errorOrNull, FirestoreError.invalidArgument);
        expect(
          (await db.collection(FirestoreCollections.posts).get()).docs,
          isEmpty,
        );
      },
    );

    test('boş batch başarıdır ve sunucuya gidilmez', () async {
      final stub = StubFirestore(error: firestoreException('unavailable'));

      final result = await FirebaseFirestoreService(stub).commitBatch((_) {});

      expect(result.isSuccess, isTrue);
      expect(stub.batches.single.commits, 0);
    });

    test('gövde batch üzerinde silme çağıramaz: hata döner, hiçbir yazım '
        'uygulanmaz, belge yerinde kalır', () async {
      await seed(['a']);
      final a = service.doc(FirestoreCollections.posts, 'a');
      final b = service.doc(FirestoreCollections.posts, 'b');

      final result = await service.commitBatch((batch) {
        batch
          ..set(b, _post('b'))
          ..delete(a);
      });

      expect(result.errorOrNull, FirestoreError.unknown);
      expect((await a.get()).exists, isTrue);
      expect((await b.get()).exists, isFalse);
    });

    test('gövde commit çağıramaz (commit servisindir)', () async {
      final b = service.doc(FirestoreCollections.posts, 'b');

      final result = await service.commitBatch((batch) {
        batch.set(b, _post('b'));
        unawaited(batch.commit());
      });

      expect(result.errorOrNull, FirestoreError.unknown);
      expect((await b.get()).exists, isFalse);
    });

    test('async gövde → invalidArgument; beklemeden önce eklenen yazım da '
        'uygulanmaz', () async {
      final b = service.doc(FirestoreCollections.posts, 'b');

      final result = await service.commitBatch((batch) async {
        batch.set(b, _post('b'));
        await Future<void>.value();
        throw StateError('geç hata sızmamalı');
      });
      await pumpEventQueue();

      expect(result.errorOrNull, FirestoreError.invalidArgument);
      expect((await b.get()).exists, isFalse);
    });

    test('batch içindeki softDelete başarısızsa batch işlenmez: eşlik eden '
        'sayaç yazımı da uygulanmaz, commitBatch aynı hatayı döner', () async {
      await post.set({..._post('Merhaba'), 'commentCount': 1});
      final comment = service.doc(FirestoreCollections.comments, 'cm01');
      await comment.set(_post('yorum'));
      late final Future<FirestoreResult<void>> queued;

      final result = await service.commitBatch((batch) {
        queued = service.softDelete(comment, actorId: '', batch: batch);
        batch.update(post, {'commentCount': FieldValue.increment(-1)});
      });

      expect((await queued).errorOrNull, FirestoreError.invalidArgument);
      expect(result.errorOrNull, FirestoreError.invalidArgument);
      expect((result as FirebaseFailure).message, contains('actorId'));
      expect((await read(post))!['commentCount'], 1);
      expect((await read(comment))![FirestoreFields.isDeleted], isFalse);
    });

    test("batch içindeki restore'u SDK eşzamanlı reddederse commit çağrılmaz, "
        'SDK hatası döner', () async {
      final rejecting = _RejectingBatch();
      final stubbed = FirebaseFirestoreService(_BatchFirestore(rejecting));

      final result = await stubbed.commitBatch((batch) {
        unawaited(stubbed.restore(StubDocumentReference(), batch: batch));
      });

      expect(result.errorOrNull, FirestoreError.failedPrecondition);
      expect(rejecting.commits, 0);
    });

    test(
      'gövde ConflictException atarsa batch işlenmez, çakışma döner',
      () async {
        final b = service.doc(FirestoreCollections.posts, 'b');

        final result = await service.commitBatch((batch) {
          batch.set(b, _post('b'));
          throw const ConflictException.conflict();
        });

        expect(result.errorOrNull, FirestoreError.conflict);
        expect((await b.get()).exists, isFalse);
      },
    );
  });

  group('T-10 · FirestoreService · runTransaction', () {
    test('gövdenin değerini döndürür; okuma + yazma uygulanır', () async {
      await post.set({'likeCount': 4});

      final result = await service.runTransaction<int>((tx) async {
        final current = (await tx.get(post)).data()!['likeCount']! as int;
        tx
          ..update(post, {'likeCount': current + 1})
          ..set(service.doc(FirestoreCollections.activity, 'a1'), {
            'kind': 'like',
          });
        return current + 1;
      });
      await pumpEventQueue();

      expect(result.dataOrNull, 5);
      expect((await read(post))!['likeCount'], 5);
      expect(
        await read(service.doc(FirestoreCollections.activity, 'a1')),
        {'kind': 'like'},
      );
    });

    test('ConflictException(kural) → ruleViolation + detail', () async {
      const detail = FirestoreFailureDetail(
        FirestoreRuleCode.capacityFull,
        position: 3,
      );

      final result = await service.runTransaction<void>(
        (_) async => throw const ConflictException(
          FirestoreRuleCode.capacityFull,
          detail: detail,
        ),
      );

      expect(result.errorOrNull, FirestoreError.ruleViolation);
      expect((result as FirebaseFailure).detail, detail);
    });

    test('ConflictException.conflict() → conflict (kural kodu yok)', () async {
      final result = await service.runTransaction<void>(
        (_) async => throw const ConflictException.conflict(),
      );

      expect(result.errorOrNull, FirestoreError.conflict);
      expect((result as FirebaseFailure).detail, isNull);
    });

    test('gövde transaction üzerinde silme çağıramaz: hata döner, belge '
        'yerinde kalır', () async {
      await post.set({'text': 'Merhaba'});

      final result = await service.runTransaction<void>((tx) async {
        tx.delete(post);
      });
      await pumpEventQueue();

      expect(result.errorOrNull, FirestoreError.unknown);
      expect(await read(post), {'text': 'Merhaba'});
    });

    test('SDK en çok 3 deneme ve servis zaman aşımıyla çağrılır', () async {
      final stub = StubFirestore(error: firestoreException('aborted'));
      final stubbed = FirebaseFirestoreService(
        stub,
        timeout: const Duration(seconds: 7),
      );

      final result = await stubbed.runTransaction<void>((_) async {});

      expect(result.errorOrNull, FirestoreError.aborted);
      expect(stub.transactionMaxAttempts, 3);
      expect(stub.transactionTimeout, const Duration(seconds: 7));
    });
  });

  group('T-10 · FirestoreService · canlı dinleme', () {
    test('watchDoc: yok → null, yazılınca belge, değişince yeni hal', () async {
      final events = <FirestoreResult<FirestoreDoc?>>[];
      final subscription = service.watchDoc(post).listen(events.add);
      await pumpEventQueue();

      await post.set({'text': 'bir'});
      await pumpEventQueue();
      await post.update({'text': 'iki'});
      await pumpEventQueue();
      await subscription.cancel();

      expect(
        events,
        everyElement(isA<FirebaseSuccess<FirestoreDoc?, FirestoreError>>()),
      );
      expect(events.first.dataOrNull, isNull);
      expect(
        [for (final event in events.skip(1)) event.dataOrNull!.data['text']],
        ['bir', 'iki'],
      );
    });

    test('watchList: sorgu sonucu değiştikçe güncel liste', () async {
      final events = <List<String>>[];
      final subscription = service
          .watchList(liveOrdered())
          .listen(
            (event) => events.add([
              for (final doc in event.dataOrNull!) doc.id,
            ]),
          );
      await pumpEventQueue();

      await seed(['a']);
      await pumpEventQueue();
      await service.softDelete(
        service.doc(FirestoreCollections.posts, 'a'),
        actorId: 'u_ayse',
      );
      await pumpEventQueue();
      await subscription.cancel();

      expect(events.first, isEmpty);
      expect(events, contains(equals(['a'])));
      expect(events.last, isEmpty);
    });

    test('hata olayı FirebaseFailure olarak gelir ve akış kapanmaz', () async {
      await post.set({'text': 'bir'});
      final live = await post.get();
      final ref = StubDocumentReference();
      final query = StubQuery();
      final docEvents = <FirestoreResult<FirestoreDoc?>>[];
      final listEvents = <FirestoreResult<List<FirestoreDoc>>>[];
      var closed = false;
      final subscription = service
          .watchDoc(ref)
          .listen(docEvents.add, onDone: () => closed = true);
      final listSubscription = service.watchList(query).listen(listEvents.add);

      ref.snapshotEvents
        ..addError(firestoreException('permission-denied', message: 'ret'))
        ..add(live);
      query.snapshotEvents.addError(firestoreException('unavailable'));
      await pumpEventQueue();

      expect(docEvents, hasLength(2));
      expect(docEvents.first.errorOrNull, FirestoreError.permissionDenied);
      expect((docEvents.first as FirebaseFailure).message, 'ret');
      expect(docEvents.last.dataOrNull!.data, {'text': 'bir'});
      expect(listEvents.single.errorOrNull, FirestoreError.unavailable);
      expect(closed, isFalse);
      await subscription.cancel();
      await listSubscription.cancel();
    });
  });

  group('T-10 · FirestoreService · hata eşlemesi', () {
    const codes = {
      'permission-denied': FirestoreError.permissionDenied,
      'unauthenticated': FirestoreError.unauthenticated,
      'not-found': FirestoreError.notFound,
      'already-exists': FirestoreError.alreadyExists,
      'aborted': FirestoreError.aborted,
      'unavailable': FirestoreError.unavailable,
      'deadline-exceeded': FirestoreError.unavailable,
      'invalid-argument': FirestoreError.invalidArgument,
      'failed-precondition': FirestoreError.failedPrecondition,
      'resource-exhausted': FirestoreError.resourceExhausted,
      'cancelled': FirestoreError.cancelled,
      'internal': FirestoreError.unknown,
      'bilinmeyen-kod': FirestoreError.unknown,
    };

    test(
      'SDK kodu FirestoreError.fromCode ile çevrilir; ham mesaj taşınır',
      () async {
        for (final MapEntry(key: code, value: expected) in codes.entries) {
          final result = await service.getDoc(
            StubDocumentReference(
              error: firestoreException(code, message: 'ham $code'),
            ),
          );

          expect(result.errorOrNull, expected, reason: code);
          expect(
            (result as FirebaseFailure).message,
            'ham $code',
            reason: code,
          );
        }
      },
    );

    test('SDK dışı istisna ve Error → unknown (fırlatılmaz)', () async {
      for (final error in <Object>[
        const FormatException('bozuk'),
        StateError('durum'),
        'dizgi',
      ]) {
        final result = await service.getDoc(
          StubDocumentReference(error: error),
        );

        expect(result.errorOrNull, FirestoreError.unknown, reason: '$error');
        expect((result as FirebaseFailure).message, contains('$error'));
      }
    });

    test(
      'sonuç döndüren her metot SDK hatasını FirebaseFailure olarak verir',
      () async {
        final denied = firestoreException('permission-denied');
        final stubbed = FirebaseFirestoreService(StubFirestore(error: denied));
        final ref = StubDocumentReference(error: denied);
        final query = StubQuery(error: denied);

        final results = <String, FirestoreResult<Object?>>{
          'getDoc': await stubbed.getDoc(ref),
          'getList': await stubbed.getList(query),
          'getPage': await stubbed.getPage(query, const PageRequest()),
          'count': await stubbed.count(query),
          'add': await stubbed.add(FirestoreCollections.posts, {'text': 'x'}),
          'set': await stubbed.set(ref, {'text': 'x'}),
          'update': await stubbed.update(ref, {'text': 'x'}),
          'softDelete': await stubbed.softDelete(ref, actorId: 'u_ayse'),
          'restore': await stubbed.restore(ref),
          'commitBatch': await stubbed.commitBatch(
            (batch) => batch.set(ref, {'text': 'x'}),
          ),
          'runTransaction': await stubbed.runTransaction<void>((_) async {}),
        };

        for (final MapEntry(key: method, value: result) in results.entries) {
          expect(
            result.errorOrNull,
            FirestoreError.permissionDenied,
            reason: method,
          );
        }
      },
    );

    test('batch yazımı eşzamanlı reddederse softDelete / restore fırlatmaz, '
        'hata döndürür', () async {
      await post.set(_post('Merhaba'));

      final deleted = await service.softDelete(
        post,
        actorId: 'u_ayse',
        batch: _RejectingBatch(),
      );
      final restored = await service.restore(post, batch: _RejectingBatch());

      expect(deleted.errorOrNull, FirestoreError.failedPrecondition);
      expect(restored.errorOrNull, FirestoreError.failedPrecondition);
      expect((await read(post))![FirestoreFields.isDeleted], isFalse);
    });
  });

  group('T-10 · FirestoreService · zaman aşımı', () {
    testWidgets('varsayılan süre Limits.firestoreTimeout: süre dolmadan sonuç '
        'yok, dolunca timeout', (tester) async {
      final stubbed = FirebaseFirestoreService(StubFirestore());
      FirestoreResult<FirestoreDoc?>? read;
      FirestoreResult<void>? write;
      unawaited(
        stubbed.getDoc(StubDocumentReference()).then((r) => read = r),
      );
      unawaited(
        stubbed
            .set(StubDocumentReference(), {'text': 'x'})
            .then((r) => write = r),
      );

      await tester.pump(
        Limits.firestoreTimeout - const Duration(milliseconds: 1),
      );
      expect(read, isNull);
      expect(write, isNull);
      await tester.pump(const Duration(milliseconds: 1));

      expect(read!.errorOrNull, FirestoreError.timeout);
      expect(write!.errorOrNull, FirestoreError.timeout);
    });

    testWidgets('süre kurucudan değiştirilebilir', (tester) async {
      final stubbed = FirebaseFirestoreService(
        StubFirestore(),
        timeout: const Duration(seconds: 2),
      );
      FirestoreResult<List<FirestoreDoc>>? result;
      unawaited(stubbed.getList(StubQuery()).then((r) => result = r));

      await tester.pump(const Duration(seconds: 2));

      expect(result!.errorOrNull, FirestoreError.timeout);
    });
  });

  group('T-10 · FirestoreService · silme yok (D-10)', () {
    test('servis kaynağında delete ile başlayan hiçbir tanımlayıcı yok', () {
      expect(deleteIdentifiersIn(_source), isEmpty);
      expect(
        deleteIdentifiersIn(
          'packages/gu_data/lib/src/services/firestore_types.dart',
        ),
        isEmpty,
      );
    });

    test('PLAN §10.2 "YOK" satırı: arayüzde delete üyesi bulunmaz', () {
      expect(readPlanAbsentMembers('FirestoreService'), ['delete']);
    });

    test('PLAN §10.2 tablosundaki her üye arayüzde aynı imzayla var', () {
      final source = normalizeDartSource(readRepoFile(_source));

      for (final member in readPlanServiceMembers('FirestoreService')) {
        expect(
          source,
          contains('${normalizeDartSource(member.signature)};'),
          reason: member.member,
        );
      }
      expect(
        readPlanServiceMembers('FirestoreService').map((m) => m.member),
        containsAll(['getDoc', 'getPage', 'softDelete', 'restore', 'count']),
      );
      expect(
        readPlanServiceImplementation('FirestoreService'),
        '$FirebaseFirestoreService',
      );
    });
  });
}

/// Her yazımı eşzamanlı olarak reddeden batch (ör. başka veritabanının
/// belgesi verildiğinde SDK'nın davranışı).
final class _RejectingBatch implements WriteBatch {
  /// [commit] çağrı sayısı.
  int commits = 0;

  @override
  void update<T>(DocumentReference<T> document, T data) =>
      throw firestoreException('failed-precondition');

  @override
  Future<void> commit() async => commits++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// `batch()` çağrısında verilen batch'i döndüren veritabanı.
final class _BatchFirestore implements FirebaseFirestore {
  _BatchFirestore(this._batch);

  final WriteBatch _batch;

  @override
  WriteBatch batch() => _batch;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

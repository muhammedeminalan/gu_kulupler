// T-08 · BaseFieldsPayload + SoftDelete: yüklerin bir Firestore belgesine
// yazımı (oluştur → güncelle → sil → geri al), sorgu süzgeci ve batch
// (PLAN §9.2, §10.3; soft-delete.md §3–§4; D-10).
//
// Sahte veritabanı her testten ÖNCE kurulur: fake_cloud_firestore FieldValue
// fabrikasını kurulduğu anda değiştirir; nöbetçi değerler ondan sonra
// üretilmelidir. Bu yüzden yüklerin nöbetçi eşitliği ayrı dosyalarda
// (`base_fields_test.dart`, `soft_delete_test.dart`) sınanır.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

/// İki belge hali arasında değeri değişen, eklenen ya da kalkan anahtarlar.
Set<String> _changedKeys(
  Map<String, Object?> before,
  Map<String, Object?> after,
) => {
  for (final key in {...before.keys, ...after.keys})
    if (!before.containsKey(key) ||
        !after.containsKey(key) ||
        before[key] != after[key])
      key,
};

void main() {
  late FakeFirebaseFirestore db;
  late DocumentReference<Map<String, Object?>> post;

  Future<Map<String, Object?>> read() async => (await post.get()).data()!;

  setUp(() {
    db = FakeFirebaseFirestore();
    post = db.collection(FirestoreCollections.posts).doc('p01');
  });

  group('T-08 · BaseFieldsPayload · belgeye yazım', () {
    test('create: zaman damgaları sunucuda Timestamp olur', () async {
      await post.set({'text': 'Merhaba', ...BaseFieldsPayload.create()});

      final data = await read();
      expect(data['text'], 'Merhaba');
      expect(data['createdAt'], isA<Timestamp>());
      expect(data['updatedAt'], isA<Timestamp>());
    });

    test(
      'create: isDeleted false; silme alanları null olarak YAZILIR',
      () async {
        await post.set({'text': 'Merhaba', ...BaseFieldsPayload.create()});

        final data = await read();
        expect(data['isDeleted'], isFalse);
        expect(data.containsKey('deletedAt'), isTrue);
        expect(data['deletedAt'], isNull);
        expect(data.containsKey('deletedBy'), isTrue);
        expect(data['deletedBy'], isNull);
        expect(data.containsKey('createdBy'), isFalse);
      },
    );

    test('create(createdBy): oluşturan uid belgeye yazılır', () async {
      await post.set({
        'title': 'Kulüp',
        ...BaseFieldsPayload.create(createdBy: 'u_admin'),
      });

      expect((await read())['createdBy'], 'u_admin');
    });

    test('create: belgede çözülmemiş nöbetçi değer kalmaz', () async {
      await post.set({'text': 'Merhaba', ...BaseFieldsPayload.create()});

      expect((await read()).values, everyElement(isNot(isA<FieldValue>())));
    });

    test('update: yalnızca yama alanı ve updatedAt değişir', () async {
      await post.set({'text': 'Merhaba', ...BaseFieldsPayload.create()});
      final before = await read();

      await post.update({'text': 'Selam', ...BaseFieldsPayload.update()});

      final after = await read();
      expect(after['text'], 'Selam');
      expect(after['updatedAt'], isA<Timestamp>());
      expect(after['createdAt'], before['createdAt']);
      expect(after['isDeleted'], isFalse);
      expect(
        {'text', 'updatedAt'},
        containsAll(_changedKeys(before, after)),
      );
    });
  });

  group('T-08 · SoftDelete · belgeye yazım', () {
    setUp(() async {
      await post.set({'text': 'Merhaba', ...BaseFieldsPayload.create()});
    });

    test('payload: belge silinmiş olarak işaretlenir, içerik kalır', () async {
      final before = await read();

      await post.update(SoftDelete.payload(actorId: 'u_ayse'));

      final after = await read();
      expect(after['isDeleted'], isTrue);
      expect(after['deletedAt'], isA<Timestamp>());
      expect(after['deletedBy'], 'u_ayse');
      expect(after['updatedAt'], isA<Timestamp>());
      expect(after['text'], 'Merhaba', reason: 'veri kalır (hard delete yok)');
      expect(after['createdAt'], before['createdAt']);
      expect((await post.get()).exists, isTrue);
    });

    test('payload: yalnızca affectedKeys alanları değişir', () async {
      final before = await read();

      await post.update(SoftDelete.payload(actorId: 'u_ayse'));

      final changed = _changedKeys(before, await read());
      expect(SoftDelete.affectedKeys, containsAll(changed));
      expect(changed, containsAll(['isDeleted', 'deletedAt', 'deletedBy']));
    });

    test(
      'restorePayload: belge yeniden canlanır; silme alanları null',
      () async {
        await post.update(SoftDelete.payload(actorId: 'u_ayse'));

        await post.update(SoftDelete.restorePayload());

        final after = await read();
        expect(after['isDeleted'], isFalse);
        expect(after.containsKey('deletedAt'), isTrue, reason: 'alan kalkmaz');
        expect(after['deletedAt'], isNull);
        expect(after.containsKey('deletedBy'), isTrue, reason: 'alan kalkmaz');
        expect(after['deletedBy'], isNull);
        expect(after['updatedAt'], isA<Timestamp>());
        expect(after['text'], 'Merhaba');
      },
    );

    test('restorePayload: yalnızca affectedKeys alanları değişir', () async {
      await post.update(SoftDelete.payload(actorId: 'u_ayse'));
      final deleted = await read();

      await post.update(SoftDelete.restorePayload());

      final changed = _changedKeys(deleted, await read());
      expect(SoftDelete.affectedKeys, containsAll(changed));
      expect(changed, containsAll(['isDeleted', 'deletedAt', 'deletedBy']));
    });

    test('sil → geri al sonrası belge, silinmeden önceki alan kümesine '
        've değerlerine döner (updatedAt hariç)', () async {
      final before = await read();

      await post.update(SoftDelete.payload(actorId: 'u_ayse'));
      await post.update(SoftDelete.restorePayload());

      final after = await read();
      expect(after.keys.toSet(), before.keys.toSet());
      expect(
        {'updatedAt'},
        containsAll(_changedKeys(before, after)),
      );
    });

    test('ikinci kez silme son sileni kaydeder', () async {
      await post.update(SoftDelete.payload(actorId: 'u_ayse'));
      await post.update(SoftDelete.restorePayload());
      await post.update(SoftDelete.payload(actorId: 'u_mod'));

      final after = await read();
      expect(after['isDeleted'], isTrue);
      expect(after['deletedBy'], 'u_mod');
    });

    test('belgede çözülmemiş nöbetçi değer kalmaz', () async {
      await post.update(SoftDelete.payload(actorId: 'u_ayse'));
      expect((await read()).values, everyElement(isNot(isA<FieldValue>())));

      await post.update(SoftDelete.restorePayload());
      expect((await read()).values, everyElement(isNot(isA<FieldValue>())));
    });
  });

  group('T-08 · SoftDelete · okuma süzgeci ve batch', () {
    Future<List<String>> liveIds() async {
      final snapshot = await db
          .collection(FirestoreCollections.comments)
          .where(FirestoreFields.isDeleted, isEqualTo: false)
          .get();
      return [for (final doc in snapshot.docs) doc.id]..sort();
    }

    setUp(() async {
      for (final id in ['cm01', 'cm02', 'cm03']) {
        await db.collection(FirestoreCollections.comments).doc(id).set({
          'text': id,
          ...BaseFieldsPayload.create(),
        });
      }
    });

    test(
      'isDeleted == false süzgeci silineni gizler, geri alınanı gösterir',
      () async {
        final target = db.collection(FirestoreCollections.comments).doc('cm02');
        expect(await liveIds(), ['cm01', 'cm02', 'cm03']);

        await target.update(SoftDelete.payload(actorId: 'u_ayse'));
        expect(await liveIds(), ['cm01', 'cm03']);

        await target.update(SoftDelete.restorePayload());
        expect(await liveIds(), ['cm01', 'cm02', 'cm03']);
      },
    );

    test(
      'yeni oluşturulan belge süzgeçten geçer (isDeleted alanı var)',
      () async {
        await db.collection(FirestoreCollections.comments).doc('cm04').set({
          'text': 'cm04',
          ...BaseFieldsPayload.create(),
        });

        expect(await liveIds(), contains('cm04'));
      },
    );

    test(
      'silinen belge koleksiyonda durur (toplam belge sayısı değişmez)',
      () async {
        await db
            .collection(FirestoreCollections.comments)
            .doc('cm01')
            .update(SoftDelete.payload(actorId: 'u_ayse'));

        final all = await db.collection(FirestoreCollections.comments).get();
        expect(all.docs, hasLength(3));
      },
    );

    test('batch: silme ve sayaç düşümü aynı işlemde yazılır', () async {
      await post.set({'commentCount': 3, ...BaseFieldsPayload.create()});
      final comment = db.collection(FirestoreCollections.comments).doc('cm01');

      final batch = db.batch()
        ..update(comment, SoftDelete.payload(actorId: 'u_ayse'))
        ..update(post, {
          'commentCount': FieldValue.increment(-1),
          ...BaseFieldsPayload.update(),
        });
      await batch.commit();

      expect((await comment.get()).data()!['isDeleted'], isTrue);
      expect((await read())['commentCount'], 2);
      expect(await liveIds(), ['cm02', 'cm03']);
    });

    test('batch: geri alma ve sayaç artışı aynı işlemde yazılır', () async {
      await post.set({'commentCount': 2, ...BaseFieldsPayload.create()});
      final comment = db.collection(FirestoreCollections.comments).doc('cm01');
      await comment.update(SoftDelete.payload(actorId: 'u_ayse'));

      final batch = db.batch()
        ..update(comment, SoftDelete.restorePayload())
        ..update(post, {
          'commentCount': FieldValue.increment(1),
          ...BaseFieldsPayload.update(),
        });
      await batch.commit();

      expect((await comment.get()).data()!['isDeleted'], isFalse);
      expect((await comment.get()).data()!['deletedBy'], isNull);
      expect((await read())['commentCount'], 3);
      expect(await liveIds(), ['cm01', 'cm02', 'cm03']);
    });
  });
}

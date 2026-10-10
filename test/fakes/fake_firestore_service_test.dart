// T-10 · FakeFirestoreService sözleşmesi (PLAN §4.7): gerçek servis
// bellekteki veritabanında çalışır; üstüne çağrı günlüğü + failNext.
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';

import 'fake_firestore_service.dart';
import 'register_fakes.dart';

void main() {
  group('T-10 · FakeFirestoreService', () {
    test(
      'FirestoreService arayüzünü uygular; registerDefaultFakes kaydeder',
      () {
        addTearDown(GetIt.I.reset);
        registerDefaultFakes();
        expect(GetIt.I<FirestoreService>(), isA<FakeFirestoreService>());
      },
    );

    test(
      'yazılan belge okunur; softDelete belgeyi silmez, işaretler',
      () async {
        final fake = FakeFirestoreService();
        final ref = fake.doc(FirestoreCollections.clubs, 'c01');

        await fake.set(ref, {FirestoreFields.isDeleted: false});
        await fake.softDelete(ref, actorId: 'u1');

        final stored = (await fake.db.doc(ref.path).get()).data();
        expect(stored?[FirestoreFields.isDeleted], isTrue);
        expect(stored?[FirestoreFields.deletedBy], 'u1');
        expect(
          await fake.getDoc(ref),
          isA<FirebaseSuccess<FirestoreDoc?, FirestoreError>>().having(
            (r) => r.data?.id,
            'id',
            'c01',
          ),
        );
        expect(fake.calls.map((c) => c.method), [
          'set',
          'softDelete',
          'getDoc',
        ]);
      },
    );

    test('failNext tek seferlik: hata döner, veritabanına yazılmaz', () async {
      final fake = FakeFirestoreService()..failNext(FirestoreError.unavailable);
      final ref = fake.doc(FirestoreCollections.clubs, 'c01');

      final failed = await fake.set(ref, {FirestoreFields.isDeleted: false});
      expect(
        failed,
        isA<FirebaseFailure<void, FirestoreError>>().having(
          (r) => r.error,
          'error',
          FirestoreError.unavailable,
        ),
      );
      expect((await fake.db.doc(ref.path).get()).exists, isFalse);

      fake.failNext();
      expect(
        await fake.count(fake.collection(FirestoreCollections.clubs)),
        isA<FirebaseFailure<int, FirestoreError>>().having(
          (r) => r.error,
          'error',
          FirestoreError.unknown,
        ),
      );
      expect(
        await fake.count(fake.collection(FirestoreCollections.clubs)),
        isA<FirebaseSuccess<int, FirestoreError>>().having(
          (r) => r.data,
          'data',
          0,
        ),
      );
    });
  });
}

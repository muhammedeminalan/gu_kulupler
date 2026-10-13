// T-12 · RepositoryHelpers: dış girdiden gelen kimliklerin doğrulanması,
// alan doğrulama sonuçlarının tek başarısızlığa çevrilmesi, belgeden modele
// çeviri (`parse`), "silinmiş tekil belge = yok" kuralı ve liste çevirisi
// (PLAN §10.1, §10.3; borç W-54, CD-131).
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

void main() {
  late FirestoreService service;

  /// Veritabanına yazılıp okunan gerçek bir belge.
  Future<FirestoreDoc> docOf(String id, Json data) async {
    final ref = service.doc(FirestoreCollections.posts, id);
    await service.set(ref, data);
    return (await service.getDoc(ref)).dataOrNull!;
  }

  String textOf(FirestoreDoc doc) => doc.data['text']! as String;

  setUp(() => service = FirebaseFirestoreService(FakeFirebaseFirestore()));

  group('T-12 · RepositoryHelpers · kimlik', () {
    for (final id in [
      'u1',
      'u_p_c01',
      'AbC123xyz',
      'c-01',
      'a.b',
      '_x_',
      '__x',
    ]) {
      test('geçerli kimlik: "$id"', () {
        expect(RepositoryHelpers.isValidId(id), isTrue);
        expect(
          () => service.doc(FirestoreCollections.users, id),
          returnsNormally,
        );
      });
    }

    for (final id in [
      '',
      '/',
      'a/b',
      'users/u1',
      '.',
      '..',
      '__name__',
      '____',
    ]) {
      test('geçersiz kimlik: "$id"', () {
        expect(RepositoryHelpers.isValidId(id), isFalse);
      });
    }

    test('doc() ArgumentError atan her kimlik geçersiz sayılır (istisna '
        'repository dışına sızmaz)', () {
      for (final id in ['', '/', 'a/b', 'a/b/c']) {
        expect(
          () => service.doc(FirestoreCollections.users, id),
          throwsArgumentError,
        );
        expect(RepositoryHelpers.isValidId(id), isFalse, reason: id);
      }
    });

    test('isFieldPathSegment: geçerli kimlik + nokta ve ayrılmış karakter '
        'yok', () {
      for (final id in ['c01', 'AbC123', 'c-01', 'c_01']) {
        expect(RepositoryHelpers.isFieldPathSegment(id), isTrue, reason: id);
      }
      for (final id in ['', 'a/b', 'a.b', 'a~', 'a*', 'a[0', 'a]', '..']) {
        expect(RepositoryHelpers.isFieldPathSegment(id), isFalse, reason: id);
      }
    });

    test('rejectInvalidIds: hepsi geçerliyse null; ilk geçersiz kimliğin adı '
        'mesajdadır', () {
      expect(
        RepositoryHelpers.rejectInvalidIds<void>({'uid': 'u1', 'clubId': 'c1'}),
        isNull,
      );

      final rejected = RepositoryHelpers.rejectInvalidIds<int>({
        'uid': 'u1',
        'clubId': 'c/1',
        'eventId': '',
      });

      expect(rejected?.errorOrNull, FirestoreError.invalidArgument);
      expect((rejected! as FirebaseFailure).message, contains('clubId'));
    });

    test('subcollectionPath: <üst>/<kimlik>/<alt>', () {
      expect(
        RepositoryHelpers.subcollectionPath(
          FirestoreCollections.users,
          'u1',
          FirestoreCollections.privateSub,
        ),
        'users/u1/private',
      );
    });
  });

  group('T-12 · RepositoryHelpers · alan doğrulama', () {
    test('rejectInvalidFields: hepsi geçerliyse null; ilk hatalı alan ve '
        'hata türü mesajdadır', () {
      expect(
        RepositoryHelpers.rejectInvalidFields<void>({
          'name': null,
          'bio': null,
        }),
        isNull,
      );
      expect(RepositoryHelpers.rejectInvalidFields<void>(const {}), isNull);

      final rejected = RepositoryHelpers.rejectInvalidFields<void>({
        'name': null,
        'bio': FieldError.tooLong,
        'email': FieldError.empty,
      });

      expect(rejected?.errorOrNull, FirestoreError.invalidArgument);
      expect(
        (rejected! as FirebaseFailure).message,
        allOf(contains('bio'), contains('tooLong')),
      );
    });
  });

  group('T-12 · RepositoryHelpers · modele çeviri', () {
    test('parse: çeviri sonucu başarıdır', () async {
      final doc = await docOf('p01', {'text': 'Merhaba'});

      expect(RepositoryHelpers.parse(doc, textOf).dataOrNull, 'Merhaba');
    });

    test('parse: çevirinin fırlattığı her hata (istisna da, Error da) parse '
        'başarısızlığıdır; belge yolu mesajdadır', () async {
      final doc = await docOf('p01', {'text': 7});

      for (final thrower in <Object Function(FirestoreDoc)>[
        textOf,
        (_) => throw const FormatException('bozuk'),
        (_) => throw ArgumentError('bilinmeyen değer'),
        (doc) => UserModel.fromJson(doc.data, id: doc.id),
      ]) {
        final result = RepositoryHelpers.parse(doc, thrower);

        expect(result.errorOrNull, FirestoreError.parse);
        expect((result as FirebaseFailure).message, contains('posts/p01'));
      }
    });

    test('parseOrNull: belge yoksa başarı null', () {
      final result = RepositoryHelpers.parseOrNull(
        const FirebaseSuccess<FirestoreDoc?, FirestoreError>(null),
        textOf,
      );

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, isNull);
    });

    test(
      'parseOrNull: silinmiş belge notFound; includeDeleted ile döner',
      () async {
        final doc = await docOf('p01', {
          'text': 'Merhaba',
          ...BaseFieldsPayload.create(),
          ...SoftDelete.payload(actorId: 'u1'),
        });

        expect(RepositoryHelpers.isSoftDeleted(doc), isTrue);
        expect(
          RepositoryHelpers.parseOrNull(
            FirebaseSuccess(doc),
            textOf,
          ).errorOrNull,
          FirestoreError.notFound,
        );
        expect(
          RepositoryHelpers.parseOrNull(
            FirebaseSuccess(doc),
            textOf,
            includeDeleted: true,
          ).dataOrNull,
          'Merhaba',
        );
      },
    );

    test(
      'parseOrNull: canlı belge ve isDeleted alanı olmayan belge döner',
      () async {
        final live = await docOf('p01', {
          'text': 'Canlı',
          ...BaseFieldsPayload.create(),
        });
        final bare = await docOf('p02', {'text': 'Alansız'});

        expect(RepositoryHelpers.isSoftDeleted(bare), isFalse);
        expect(
          RepositoryHelpers.parseOrNull(
            FirebaseSuccess(live),
            textOf,
          ).dataOrNull,
          'Canlı',
        );
        expect(
          RepositoryHelpers.parseOrNull(
            FirebaseSuccess(bare),
            textOf,
          ).dataOrNull,
          'Alansız',
        );
      },
    );

    test('parseOrNull: okuma hatası mesaj ve ek bilgisiyle taşınır', () {
      const detail = FirestoreFailureDetail(FirestoreRuleCode.notMember);

      final result = RepositoryHelpers.parseOrNull(
        const FirebaseFailure<FirestoreDoc?, FirestoreError>(
          FirestoreError.permissionDenied,
          message: 'ham',
          detail: detail,
        ),
        textOf,
      );

      final failure = result as FirebaseFailure;
      expect(failure.error, FirestoreError.permissionDenied);
      expect(failure.message, 'ham');
      expect(failure.detail, detail);
    });

    test('parseOrNull: bozuk belge parse hatasıdır', () async {
      final doc = await docOf('p01', {'text': 7});

      expect(
        RepositoryHelpers.parseOrNull(FirebaseSuccess(doc), textOf).errorOrNull,
        FirestoreError.parse,
      );
    });

    test('parseAll: sırayı korur; boş liste başarıdır', () async {
      final docs = [
        await docOf('p01', {'text': 'bir'}),
        await docOf('p02', {'text': 'iki'}),
      ];

      expect(
        RepositoryHelpers.parseAll(FirebaseSuccess(docs), textOf).dataOrNull,
        ['bir', 'iki'],
      );
      expect(
        RepositoryHelpers.parseAll(
          const FirebaseSuccess<List<FirestoreDoc>, FirestoreError>([]),
          textOf,
        ).dataOrNull,
        isEmpty,
      );
    });

    test('parseAll: tek bozuk belge tüm sonucu parse hatası yapar (eksik '
        'liste dönmez)', () async {
      final docs = [
        await docOf('p01', {'text': 'bir'}),
        await docOf('p02', {'text': 2}),
        await docOf('p03', {'text': 'üç'}),
      ];

      final result = RepositoryHelpers.parseAll(FirebaseSuccess(docs), textOf);

      expect(result.errorOrNull, FirestoreError.parse);
      expect((result as FirebaseFailure).message, contains('posts/p02'));
    });

    test('parseAll: okuma hatası mesajıyla taşınır', () {
      final result = RepositoryHelpers.parseAll(
        const FirebaseFailure<List<FirestoreDoc>, FirestoreError>(
          FirestoreError.unavailable,
          message: 'ham',
        ),
        textOf,
      );

      expect(result.errorOrNull, FirestoreError.unavailable);
      expect((result as FirebaseFailure).message, 'ham');
    });

    test('whereInMax Firestore süzgeç sınırıdır (30)', () {
      expect(RepositoryHelpers.whereInMax, 30);
    });
  });

  group('T-15 · RepositoryHelpers · sayfa çevirisi', () {
    test('parsePage: sırayı ve imleci korur; bozuk belge parse hatası, okuma '
        'hatası aynen taşınır', () async {
      final docs = [
        await docOf('p01', {'text': 'bir'}),
        await docOf('p02', {'text': 'iki'}),
      ];
      final cursor = PageCursor(docs.last.snapshot);

      final page = RepositoryHelpers.parsePage(
        FirebaseSuccess(PageResult(items: docs, next: cursor)),
        textOf,
      );
      final broken = RepositoryHelpers.parsePage(
        FirebaseSuccess(
          PageResult(
            items: [
              ...docs,
              await docOf('p03', {'text': 3}),
            ],
          ),
        ),
        textOf,
      );
      final failed = RepositoryHelpers.parsePage(
        const FirebaseFailure<PageResult<FirestoreDoc>, FirestoreError>(
          FirestoreError.unavailable,
          message: 'ham',
        ),
        textOf,
      );

      expect(page.dataOrNull!.items, ['bir', 'iki']);
      expect(page.dataOrNull!.next, same(cursor));
      expect(broken.errorOrNull, FirestoreError.parse);
      expect(failed.errorOrNull, FirestoreError.unavailable);
      expect((failed as FirebaseFailure).message, 'ham');
    });
  });
}

// T-08 · Anonymization: anonimleştirme yüklerinin Firestore belgelerine yazımı
// (users, private/account, memberships + private/contact), sorgu süzgeci,
// yinelenebilirlik ve batch (PLAN §9.5, §10.4; domain-model §11; D-10).
//
// Sahte veritabanı her testten ÖNCE kurulur: fake_cloud_firestore FieldValue
// fabrikasını kurulduğu anda değiştirir; nöbetçi değerler ondan sonra
// üretilmelidir. Yüklerin nöbetçi eşitliği `anonymization_test.dart` içinde
// sınanır.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

const String _uid = 'u_ayse';
const String _clubId = 'c01';

/// İki belge hali arasında değeri değişen, eklenen ya da kalkan anahtarlar.
Set<String> _changedKeys(
  Map<String, Object?> before,
  Map<String, Object?> after,
) => {
  for (final key in {...before.keys, ...after.keys})
    if (!before.containsKey(key) ||
        !after.containsKey(key) ||
        !const DeepCollectionEquality().equals(before[key], after[key]))
      key,
};

/// Zaman damgası dışındaki alanlar (yinelenebilirlik karşılaştırması için).
Map<String, Object?> _withoutTimestamps(Map<String, Object?> data) => {
  for (final entry in data.entries)
    if (entry.value is! Timestamp) entry.key: entry.value,
};

void main() {
  late FakeFirebaseFirestore db;
  late DocumentReference<Map<String, Object?>> user;
  late DocumentReference<Map<String, Object?>> account;
  late DocumentReference<Map<String, Object?>> membership;
  late DocumentReference<Map<String, Object?>> contact;

  Future<Map<String, Object?>> read(
    DocumentReference<Map<String, Object?>> ref,
  ) async => (await ref.get()).data()!;

  setUp(() async {
    db = FakeFirebaseFirestore();
    user = db.collection(FirestoreCollections.users).doc(_uid);
    account = user
        .collection(FirestoreCollections.privateSub)
        .doc(FirestoreCollections.accountDoc);
    membership = db
        .collection(FirestoreCollections.memberships)
        .doc(FirestoreIds.membership(_clubId, _uid));
    contact = membership
        .collection(FirestoreCollections.privateSub)
        .doc(FirestoreCollections.contactDoc);

    await user.set({
      FirestoreFields.name: 'Ayşe Yılmaz',
      FirestoreFields.nameLower: 'ayşe yılmaz',
      FirestoreFields.avatarSeed: _uid,
      FirestoreFields.avatarPath: 'users/$_uid/20261008T201501Z_ab.jpg',
      FirestoreFields.department: 'd01',
      FirestoreFields.year: '3',
      FirestoreFields.interests: ['i01', 'i04'],
      FirestoreFields.bio: 'Doğa yürüyüşü ve fotoğraf.',
      FirestoreFields.status: 'active',
      FirestoreFields.staff: false,
      FirestoreFields.profileComplete: true,
      ...BaseFieldsPayload.create(),
    });
    await account.set({
      FirestoreFields.email: 'Ayse.Yilmaz@ogr.gumushane.edu.tr',
      FirestoreFields.emailLower: 'ayse.yilmaz@ogr.gumushane.edu.tr',
      FirestoreFields.fcmTokens: [
        {'token': 'jeton', 'platform': 'ios'},
      ],
      ...BaseFieldsPayload.create(),
    });
    await membership.set({
      FirestoreFields.clubId: _clubId,
      FirestoreFields.userId: _uid,
      FirestoreFields.role: RoleCodes.member,
      FirestoreFields.status: MembershipStatusCodes.active,
      FirestoreFields.applicant: {
        FirestoreFields.name: 'Ayşe Yılmaz',
        FirestoreFields.department: 'd01',
        FirestoreFields.year: '3',
        FirestoreFields.avatarSeed: _uid,
      },
      ...BaseFieldsPayload.create(),
    });
    await contact.set({
      FirestoreFields.email: 'Ayse.Yilmaz@ogr.gumushane.edu.tr',
      FirestoreFields.emailLower: 'ayse.yilmaz@ogr.gumushane.edu.tr',
      ...BaseFieldsPayload.create(),
    });
  });

  group('T-08 · Anonymization.userPayload · belgeye yazım', () {
    test(
      'kişisel alanlar boşaltılır, belge silinmiş olarak işaretlenir',
      () async {
        await user.update(Anonymization.userPayload(_uid));

        final data = await read(user);
        expect(data['name'], 'Silinmiş kullanıcı');
        expect(data['nameLower'], 'silinmiş kullanıcı');
        expect(data['bio'], '');
        expect(data['interests'], isEmpty);
        expect(data['status'], 'deleted');
        expect(data['isDeleted'], isTrue);
        expect(data['deletedAt'], isA<Timestamp>());
        expect(data['deletedBy'], _uid);
        expect(data['updatedAt'], isA<Timestamp>());
      },
    );

    test(
      'avatarPath, department ve year null olarak YAZILIR (alan kalır)',
      () async {
        await user.update(Anonymization.userPayload(_uid));

        final data = await read(user);
        for (final key in ['avatarPath', 'department', 'year']) {
          expect(data.containsKey(key), isTrue, reason: key);
          expect(data[key], isNull, reason: key);
        }
      },
    );

    test(
      'belge kalır (hard delete yok); kişisel olmayan alanlar değişmez',
      () async {
        final before = await read(user);

        await user.update(Anonymization.userPayload(_uid));

        final snapshot = await user.get();
        expect(snapshot.exists, isTrue);
        final after = snapshot.data()!;
        expect(after['avatarSeed'], _uid);
        expect(after['staff'], isFalse);
        expect(after['profileComplete'], isTrue);
        expect(after['createdAt'], before['createdAt']);
      },
    );

    test('yalnızca yükteki alanlar değişir', () async {
      final before = await read(user);

      await user.update(Anonymization.userPayload(_uid));

      expect(
        Anonymization.userPayload(_uid).keys.toSet(),
        containsAll(_changedKeys(before, await read(user))),
      );
    });

    test('önceki kişisel değerlerin hiçbiri belgede kalmaz', () async {
      final before = await read(user);

      await user.update(Anonymization.userPayload(_uid));

      final after = await read(user);
      for (final key in [
        'name',
        'nameLower',
        'avatarPath',
        'department',
        'year',
        'bio',
      ]) {
        expect(after[key], isNot(before[key]), reason: key);
      }
      expect(after.values, isNot(contains('Ayşe Yılmaz')));
      expect(after.values, isNot(contains('ayşe yılmaz')));
    });

    test('belgede çözülmemiş nöbetçi değer kalmaz', () async {
      await user.update(Anonymization.userPayload(_uid));

      expect(
        (await read(user)).values,
        everyElement(isNot(isA<FieldValue>())),
      );
    });

    test('servis birleşimi: {...userPayload, ...BaseFieldsPayload.update()} '
        'aynı anahtar kümesidir', () async {
      final merged = {
        ...Anonymization.userPayload(_uid),
        ...BaseFieldsPayload.update(),
      };

      expect(merged.keys.toList(), Anonymization.userPayload(_uid).keys);
      await user.update(merged);
      expect((await read(user))['status'], 'deleted');
    });

    test('silinmemiş süzgeci anonim kullanıcıyı listelemez; tekil okuma '
        'belgeyi yine verir', () async {
      await db.collection(FirestoreCollections.users).doc('u_can').set({
        FirestoreFields.name: 'Can',
        FirestoreFields.status: 'active',
        ...BaseFieldsPayload.create(),
      });

      await user.update(Anonymization.userPayload(_uid));

      final live = await db
          .collection(FirestoreCollections.users)
          .where(FirestoreFields.isDeleted, isEqualTo: false)
          .get();
      expect(live.docs.map((doc) => doc.id), ['u_can']);
      final deleted = await db
          .collection(FirestoreCollections.users)
          .where(FirestoreFields.status, isEqualTo: 'deleted')
          .get();
      expect(deleted.docs.map((doc) => doc.id), [_uid]);
      expect((await user.get()).data()!['name'], 'Silinmiş kullanıcı');
    });

    test('yinelenebilir: ikinci yazım zaman damgası dışında hiçbir şeyi '
        'değiştirmez', () async {
      await user.update(Anonymization.userPayload(_uid));
      final first = await read(user);

      await user.update(Anonymization.userPayload(_uid));

      final second = await read(user);
      expect(_withoutTimestamps(second), _withoutTimestamps(first));
      expect(second.keys.toSet(), first.keys.toSet());
    });
  });

  group('T-08 · Anonymization.accountPayload · belgeye yazım', () {
    test('e-posta alanları boşaltılır, jeton listesi temizlenir', () async {
      await account.update(Anonymization.accountPayload());

      final data = await read(account);
      expect(data['email'], '');
      expect(data['emailLower'], '');
      expect(data['fcmTokens'], isEmpty);
    });

    test(
      'yalnızca yükteki alanlar değişir; belge silinmiş işaretlenmez',
      () async {
        final before = await read(account);

        await account.update(Anonymization.accountPayload());

        final after = await read(account);
        expect(_changedKeys(before, after), {
          'email',
          'emailLower',
          'fcmTokens',
        });
        expect(after['isDeleted'], isFalse);
        expect(after['createdAt'], before['createdAt']);
      },
    );

    test('yinelenebilir', () async {
      await account.update(Anonymization.accountPayload());
      final first = await read(account);

      await account.update(Anonymization.accountPayload());

      expect(await read(account), first);
    });
  });

  group('T-08 · Anonymization.contactPayload · belgeye yazım', () {
    test('e-posta alanları boşaltılır', () async {
      await contact.update(Anonymization.contactPayload());

      final data = await read(contact);
      expect(data['email'], '');
      expect(data['emailLower'], '');
    });

    test('yalnızca yükteki alanlar değişir', () async {
      final before = await read(contact);

      await contact.update(Anonymization.contactPayload());

      expect(_changedKeys(before, await read(contact)), {
        'email',
        'emailLower',
      });
    });
  });

  group('T-08 · Anonymization.applicantPayload · belgeye yazım', () {
    test('başvuran anlık görüntüsü anonimleşir', () async {
      await membership.update(Anonymization.applicantPayload());

      expect((await read(membership))['applicant'], {
        'name': 'Silinmiş kullanıcı',
        'department': null,
        'year': null,
        'avatarSeed': 'deleted',
      });
    });

    // Gerçek Firestore `update` içindeki map değerini alanın tamamıyla
    // değiştirir; fake_cloud_firestore ise iç içe map'i birleştirir. Yük bu
    // farktan bağımsızdır: şemadaki dört anahtarın tamamını açıkça yazar.
    test('şemadaki dört anahtarın tamamı yazılır: önceki anlık görüntüden '
        'değer kalmaz', () async {
      final before =
          (await read(membership))['applicant']! as Map<String, Object?>;

      await membership.update(Anonymization.applicantPayload());

      final after =
          (await read(membership))['applicant']! as Map<String, Object?>;
      expect(after.keys.toSet(), before.keys.toSet());
      for (final key in before.keys) {
        expect(after[key], isNot(before[key]), reason: key);
      }
      expect(after.values, isNot(contains(_uid)));
    });

    test('üyeliğin kimlik, rol ve durum alanlarına dokunmaz', () async {
      final before = await read(membership);

      await membership.update(Anonymization.applicantPayload());

      final after = await read(membership);
      expect(_changedKeys(before, after), {'applicant'});
      expect(after['clubId'], _clubId);
      expect(after['userId'], _uid);
      expect(after['role'], RoleCodes.member);
      expect(after['status'], MembershipStatusCodes.active);
      expect(after['isDeleted'], isFalse);
    });

    test(
      'durum geçişiyle aynı güncellemede birleşir (active → left, M14)',
      () async {
        await membership.update({
          FirestoreFields.status: MembershipStatusCodes.left,
          ...Anonymization.applicantPayload(),
          ...BaseFieldsPayload.update(),
        });

        final data = await read(membership);
        expect(data['status'], MembershipStatusCodes.left);
        expect(
          (data['applicant']! as Map<String, Object?>)['name'],
          Anonymization.deletedUserName,
        );
        expect(data['isDeleted'], isFalse, reason: 'üyelik durum alanıdır');
      },
    );
  });

  group('T-08 · Anonymization · tek batch', () {
    test(
      'dört yük aynı batch içinde uygulanır; hiçbir belge kaldırılmaz',
      () async {
        final batch = db.batch()
          ..update(user, Anonymization.userPayload(_uid))
          ..update(account, Anonymization.accountPayload())
          ..update(membership, {
            FirestoreFields.status: MembershipStatusCodes.left,
            ...Anonymization.applicantPayload(),
            ...BaseFieldsPayload.update(),
          })
          ..update(contact, Anonymization.contactPayload());
        await batch.commit();

        expect((await read(user))['status'], 'deleted');
        expect((await read(account))['email'], '');
        expect((await read(membership))['status'], MembershipStatusCodes.left);
        expect((await read(contact))['email'], '');
        for (final ref in [user, account, membership, contact]) {
          expect((await ref.get()).exists, isTrue, reason: ref.path);
        }
      },
    );

    test('batch sonrası hiçbir belgede kullanıcının adı ya da e-postası '
        'kalmaz', () async {
      final batch = db.batch()
        ..update(user, Anonymization.userPayload(_uid))
        ..update(account, Anonymization.accountPayload())
        ..update(membership, Anonymization.applicantPayload())
        ..update(contact, Anonymization.contactPayload());
      await batch.commit();

      for (final ref in [user, account, membership, contact]) {
        final text = (await read(ref)).toString();
        expect(text, isNot(contains('Ayşe')), reason: ref.path);
        expect(text, isNot(contains('ayşe')), reason: ref.path);
        expect(text, isNot(contains('gumushane.edu.tr')), reason: ref.path);
        expect(text, isNot(contains('jeton')), reason: ref.path);
      }
    });
  });
}

// T-37 · FirebaseUserSearch (AdminRepository arama üyeleri; ADM-05,
// `docs/plans/T-37.md` §4 b): e-posta araması `collectionGroup('private')`
// üzerinden yalnızca `users/{uid}/private/account` sonuçlarını alır (üyelik
// iletişim belgeleri süzülür, uid tekil), ad araması `nameLower` öneki +
// silinmemiş, yönetici kümesi; hata eşlemesi. Rules'un "yalnızca süper admin"
// koşulu emülatör testindedir (C); burada okuma reddinin aynen döndüğü sınanır.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../fakes/fake_app_clock.dart';
import '../fakes/recording_storage_service.dart';
import '../fakes/sdk_firestore_stubs.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirebaseUserSearch search;

  FirebaseUserSearch searchOn(FirestoreService firestore) => FirebaseUserSearch(
    firestore: firestore,
    users: FirebaseUserRepository(
      firestore,
      RecordingStorageService(),
      FakeAppClock(DateTime.utc(2026, 10, 13, 9)),
      SequenceRandom(const [0]),
    ),
  );

  Future<void> seedUser(
    String uid, {
    required String nameLower,
    String? emailLower,
    bool deleted = false,
  }) async {
    await db.collection('users').doc(uid).set({
      'name': nameLower,
      'nameLower': nameLower,
      'avatarSeed': uid,
      ...BaseFieldsPayload.create(),
      'isDeleted': deleted,
    });
    if (emailLower != null) {
      await db.doc('users/$uid/private/account').set({
        'email': emailLower,
        'emailLower': emailLower,
        'fcmTokens': <Object?>[],
      });
    }
  }

  Future<void> seedMembership(
    String clubId,
    String uid,
    String role, {
    String status = 'active',
  }) => db.collection('memberships').doc('${clubId}_$uid').set({
    'clubId': clubId,
    'userId': uid,
    'status': status,
    'role': role,
  });

  setUp(() {
    db = FakeFirebaseFirestore();
    search = searchOn(FirebaseFirestoreService(db));
  });

  group('T-37 · findUserByEmail', () {
    test('yalnızca users/*/private/account sonuçları; üyelik iletişim belgesi '
        've sayaç süzülür, uid tekil, e-posta sırası; silinmiş hesabın boş '
        'e-postası çıkmaz', () async {
      await seedUser(
        'u_aysel',
        nameLower: 'aysel',
        emailLower: 'aysel@ogr.gumushane.edu.tr',
      );
      await seedUser(
        'u_ayse',
        nameLower: 'ayşe',
        emailLower: 'ayse@ogr.gumushane.edu.tr',
      );
      await seedUser(
        'u_mehmet',
        nameLower: 'mehmet',
        emailLower: 'mehmet@ogr.gumushane.edu.tr',
      );
      await seedUser(
        'u_gone',
        nameLower: 'silinmiş',
        emailLower: '',
        deleted: true,
      );
      // Aynı e-posta üyelik iletişim belgesinde de var (collectionGroup döndürür).
      await db.doc('memberships/c01_u_ayse/private/contact').set({
        'email': 'ayse@ogr.gumushane.edu.tr',
        'emailLower': 'ayse@ogr.gumushane.edu.tr',
        'note': '',
      });
      await db.doc('memberships/c02_u_x/private/contact').set({
        'email': 'ayse.x@ogr.gumushane.edu.tr',
        'emailLower': 'ayse.x@ogr.gumushane.edu.tr',
        'note': '',
      });
      await db.doc('clubs/c01/private/counter').set({'clubId': 'c01'});

      final found = (await search.findUserByEmail('ayse')).dataOrNull!;
      final exact = (await search.findUserByEmail(
        'mehmet@ogr.gumushane.edu.tr',
      )).dataOrNull!;

      expect(found.map((u) => u.uid), ['u_ayse', 'u_aysel']);
      expect(exact.map((u) => u.uid), ['u_mehmet']);
    });

    test('üyelik iletişim belgeleri ilk sayfayı doldursa da sonraki hesaplar '
        'imleçle bulunur (güvenlik incelemesi T-37)', () async {
      // u_alia'nın 60 iletişim belgesi + hesabı aynı e-postada: tek limit(50)
      // sayfası u_aliz'in hesabına hiç ulaşmazdı. (fake_cloud_firestore
      // imleci yalnızca belge kimliğiyle bulur — kimlikler tekil tutuldu;
      // gerçek SDK tam yolu kullanır.)
      await seedUser('u_alia', nameLower: 'ali a', emailLower: 'ali.a@x.tr');
      await seedUser('u_aliz', nameLower: 'ali z', emailLower: 'ali.z@x.tr');
      for (var i = 0; i < 60; i++) {
        await db.doc('memberships/c${i}_u_alia/private/contact$i').set({
          'email': 'ali.a@x.tr',
          'emailLower': 'ali.a@x.tr',
          'note': '',
        });
      }

      final found = (await search.findUserByEmail('ali')).dataOrNull!;

      expect(found.map((u) => u.uid), ['u_alia', 'u_aliz']);
    });

    test('boş girdi sorgu yapmadan boş döner; okuma reddi (süper admin '
        'değil) aynen eşlenir', () async {
      final denied = searchOn(
        FirebaseFirestoreService(
          StubFirestore(error: firestoreException('permission-denied')),
        ),
      );

      expect((await denied.findUserByEmail('')).dataOrNull, isEmpty);
      expect(
        (await denied.findUserByEmail('ayse')).errorOrNull,
        FirestoreError.permissionDenied,
      );
    });
  });

  group('T-37 · listUsersByName', () {
    test('nameLower öneki, silinmiş kullanıcı yok, nameLower artan, sayfa; '
        'boş önek ilk sayfa', () async {
      await seedUser('u3', nameLower: 'ayten');
      await seedUser('u1', nameLower: 'ayşe');
      await seedUser('u2', nameLower: 'aybars');
      await seedUser('u4', nameLower: 'ayla', deleted: true);
      await seedUser('u5', nameLower: 'mehmet');

      final first = (await search.listUsersByName(
        'ay',
        const PageRequest(limit: 2),
      )).dataOrNull!;
      final rest = (await search.listUsersByName(
        'ay',
        PageRequest(limit: 2, after: first.next),
      )).dataOrNull!;
      final all = (await search.listUsersByName(
        '',
        const PageRequest(limit: 10),
      )).dataOrNull!;

      expect(first.items.map((u) => u.uid), ['u2', 'u3']);
      expect(first.hasMore, isTrue);
      expect(rest.items.map((u) => u.uid), ['u1']);
      expect(rest.hasMore, isFalse);
      expect(all.items.map((u) => u.uid), ['u2', 'u3', 'u1', 'u5']);
    });
  });

  group('T-37 · listManagerUserIds', () {
    test('etkin board / president üyelikleri (tüm kulüpler), tekil küme; '
        'üye, danışman ve etkin olmayan yönetici yok', () async {
      await seedMembership('c01', 'u_pres', 'president');
      await seedMembership('c01', 'u_board', 'board');
      await seedMembership('c02', 'u_board', 'president');
      await seedMembership('c01', 'u_member', 'member');
      await seedMembership('c01', 'u_adv', 'advisor');
      await seedMembership('c02', 'u_left', 'board', status: 'left');

      final ids = (await search.listManagerUserIds()).dataOrNull;

      expect(ids, {'u_pres', 'u_board'});
    });

    test('okuma hatası aynen eşlenir (ad araması dahil)', () async {
      final broken = searchOn(
        FirebaseFirestoreService(
          StubFirestore(error: firestoreException('unavailable')),
        ),
      );

      expect(
        (await broken.listManagerUserIds()).errorOrNull,
        FirestoreError.unavailable,
      );
      expect(
        (await broken.listUsersByName('ay', const PageRequest())).errorOrNull,
        FirestoreError.unavailable,
      );
    });
  });
}

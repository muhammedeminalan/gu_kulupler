// T-25 · FirebaseRecipientResolver (PLAN §10.5 "Alıcı çözümü";
// `docs/plans/T-25.md` §6 d; CD-38, CD-139): `application_received`
// yöneticileri (board + president; danışman / üye / bekleyen hariç),
// `announcement` üyeleri (danışman ve yazar hariç), `event_cancelled`
// katılımcıları (yalnızca istenen durumlar, aynı etkinlik + kulüp),
// `event_new` = üyeler ∪ (public ise, H-25) tüm etkin kullanıcılar (yayıncı,
// silinmiş ve askıdaki kullanıcı hariç, `publicEventFanOutMax` kesimi →
// truncated),
// DLG-22 tahmini; geçersiz kimlik ve hata eşlemesi.
//
// Mutlu yollar `fake_cloud_firestore` ile (Q-06); hata yolu el yazımı SDK
// çiftiyle (`test/fakes/sdk_firestore_stubs.dart`).

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../fakes/sdk_firestore_stubs.dart';

const String _clubId = 'c01';
const String _publisher = 'u_pub';

/// `k01` kategorisi (ilgi alanları i01, i02, i15 …).
const ClubModel _club = ClubModel(
  id: _clubId,
  name: 'Yazılım Kulübü',
  nameLower: 'yazılım kulübü',
  categoryId: 'k01',
  iconName: 'code-xml',
  palette: ClubPalette.red,
  pattern: ClubPattern.dots,
  founded: 2015,
  presidentId: 'u_pres',
);

EventModel _event({EventVisibility visibility = EventVisibility.public}) =>
    EventModel(
      id: 'e01',
      clubId: _clubId,
      createdBy: _publisher,
      title: 'Atölye',
      type: EventType.training,
      startsAt: DateTime.utc(2026, 10, 20, 15),
      endsAt: DateTime.utc(2026, 10, 20, 17),
      visibility: visibility,
      coverPalette: ClubPalette.values.first,
      coverPattern: ClubPattern.values.first,
    );

void main() {
  late FakeFirebaseFirestore db;
  late FirebaseRecipientResolver resolver;

  RecipientResolver resolverOn(FirestoreService service) =>
      FirebaseRecipientResolver(service);

  Future<void> membership(
    String userId, {
    String role = 'member',
    String status = 'active',
    String clubId = _clubId,
  }) => db.doc('memberships/${clubId}_$userId').set({
    'clubId': clubId,
    'userId': userId,
    'role': role,
    'status': status,
  });

  Future<void> rsvp(
    String userId,
    String status, {
    String eventId = 'e01',
    String clubId = _clubId,
  }) => db.doc('rsvps/${eventId}_$userId').set({
    'eventId': eventId,
    'clubId': clubId,
    'userId': userId,
    'status': status,
  });

  Future<void> user(
    String uid, {
    List<String> interests = const ['i01'],
    bool isDeleted = false,
    String status = 'active',
  }) => db.doc('users/$uid').set({
    'name': 'Kullanıcı $uid',
    'nameLower': 'kullanıcı $uid',
    'avatarSeed': uid,
    'interests': interests,
    'status': status,
    'profileComplete': true,
    ...BaseFieldsPayload.create(),
    'isDeleted': isDeleted,
  });

  setUp(() async {
    db = FakeFirebaseFirestore();
    resolver =
        resolverOn(FirebaseFirestoreService(db)) as FirebaseRecipientResolver;
    await membership('u_pres', role: 'president');
    await membership('u_board', role: 'board');
    await membership('u_adv', role: 'advisor');
    await membership('u_m1');
    await membership(_publisher, role: 'board');
    await membership('u_pendingBoard', role: 'board', status: 'pending');
    await membership('u_left', status: 'left');
    await membership('u_other', clubId: 'c02', role: 'president');
  });

  test('managersOf: etkin board + president (danışman, üye, bekleyen, başka '
      'kulüp hariç)', () async {
    final result = await resolver.managersOf(_clubId);

    expect(result.dataOrNull?.toSet(), {'u_pres', 'u_board', _publisher});
  });

  test('membersOf: etkin üyeler, danışman ve excludeUserId hariç', () async {
    final result = await resolver.membersOf(
      _clubId,
      excludeUserId: _publisher,
    );

    expect(result.dataOrNull?.toSet(), {'u_pres', 'u_board', 'u_m1'});
  });

  test('rsvpUsersOf: yalnızca istenen durumlar, aynı etkinlik ve kulüp; boş '
      'küme sorgusuz boş', () async {
    await rsvp('u1', 'going');
    await rsvp('u2', 'waitlist');
    await rsvp('u3', 'cancelled');
    await rsvp('u4', 'going', eventId: 'e02');

    final result = await resolver.rsvpUsersOf('e01', _clubId, {
      RsvpStatus.going,
      RsvpStatus.waitlist,
    });
    final none = await resolver.rsvpUsersOf('e01', _clubId, const {});

    expect(result.dataOrNull?.toSet(), {'u1', 'u2'});
    expect(none.dataOrNull, isEmpty);
  });

  group('eventNew (CD-38)', () {
    test('public (H-25): üyeler ∪ tüm etkin kullanıcılar (tekil); yayıncı, '
        'silinmiş ve askıdaki kullanıcı hariç; tahmin = küme boyu', () async {
      await user('u_m1');
      await user('u_fan', interests: const ['i02', 'i40']);
      await user(_publisher);
      await user('u_gone', isDeleted: true);
      await user('u_banned', status: 'suspended');

      final set = await resolver.eventNew(_event(), _club);
      final estimate = await resolver.estimateEventNew(_event(), _club);

      expect(set.dataOrNull?.ids.toSet(), {
        'u_pres',
        'u_board',
        'u_m1',
        'u_fan',
      });
      expect(set.dataOrNull?.ids, hasLength(4));
      expect(set.dataOrNull?.truncated, isFalse);
      expect(estimate.dataOrNull, 4);
    });

    test('yalnızca üyelere açık etkinlik kullanıcıları sorgulamaz', () async {
      await user('u_fan');

      final set = await resolver.eventNew(
        _event(visibility: EventVisibility.membersOnly),
        _club,
      );

      expect(set.dataOrNull?.ids.toSet(), {'u_pres', 'u_board', 'u_m1'});
      expect(set.dataOrNull?.truncated, isFalse);
    });

    test('kullanıcı üst sınırı aşarsa en çok publicEventFanOutMax eklenir, '
        'truncated', () async {
      const max = FirebaseRecipientResolver.publicEventFanOutMax;
      for (var i = 0; i <= max; i++) {
        await user('fan$i');
      }

      final set = (await resolver.eventNew(_event(), _club)).dataOrNull!;

      expect(set.truncated, isTrue);
      expect(set.ids.where((id) => id.startsWith('fan')), hasLength(max));
      expect(set.ids, hasLength(max + 3));
    });

    test('etkinliğin kulübü ≠ club → invalidArgument', () async {
      final result = await resolver.eventNew(
        _event(),
        _club.copyWith(id: 'c02'),
      );

      expect(result.errorOrNull, FirestoreError.invalidArgument);
    });
  });

  test('geçersiz kimlik invalidArgument; okuma hatası aynen taşınır', () async {
    final failing = resolverOn(
      FirebaseFirestoreService(
        StubFirestore(error: firestoreException('permission-denied')),
      ),
    );

    expect(
      (await resolver.managersOf('a/b')).errorOrNull,
      FirestoreError.invalidArgument,
    );
    expect(
      (await resolver.rsvpUsersOf('', _clubId, {RsvpStatus.going})).errorOrNull,
      FirestoreError.invalidArgument,
    );
    expect(
      (await failing.membersOf(_clubId)).errorOrNull,
      FirestoreError.permissionDenied,
    );
    expect(
      (await failing.eventNew(_event(), _club)).errorOrNull,
      FirestoreError.permissionDenied,
    );
  });
}

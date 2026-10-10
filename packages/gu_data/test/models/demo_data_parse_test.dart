// T-09 · Demo veri ayrıştırma (PLAN §9.11, §9.12): `tool/seed/demo-data.json`
// içindeki HER belge §9.12 dönüşümüyle (`DemoDataFixture`) üretim şemasına
// çevrilir ve ilgili modele ayrışır; ayrışan model girdinin hiçbir alanını
// düşürmez. Sayılar dosyayla ve PLAN §9.11 ile eşittir; dönüşüm kuralları
// (yeniden hesaplanan sayaçlar, bölünen belgeler, türetilen alanlar) tek tek
// sabitlenir — T-10 tohumlayıcısı aynı sonuçları üretmelidir.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../fixtures/demo_data.dart';

/// Koleksiyon → model ayrıştırıcı. Dönüş değeri modelin kimliği ve
/// `toJson()` çıktısıdır (kimliksiz alt belgelerde kimlik `null`).
typedef _Parsed = ({String? id, Map<String, Object?> json});

final Map<String, _Parsed Function(Map<String, Object?> json, String id)>
_parsers = {
  FirestoreCollections.users: (json, id) {
    final model = UserModel.fromJson(json, id: id);
    return (id: model.uid, json: model.toJson());
  },
  FirestoreCollections.accountDoc: (json, id) =>
      (id: null, json: UserAccountModel.fromJson(json).toJson()),
  FirestoreCollections.blocks: (json, id) {
    final model = BlockModel.fromJson(json, id: id);
    return (id: model.id, json: model.toJson());
  },
  FirestoreCollections.clubs: (json, id) {
    final model = ClubModel.fromJson(json, id: id);
    return (id: model.id, json: model.toJson());
  },
  FirestoreCollections.memberships: (json, id) {
    final model = MembershipModel.fromJson(json, id: id);
    return (id: model.id, json: model.toJson());
  },
  FirestoreCollections.contactDoc: (json, id) =>
      (id: null, json: MembershipContactModel.fromJson(json).toJson()),
  FirestoreCollections.posts: (json, id) {
    final model = PostModel.fromJson(json, id: id);
    return (id: model.id, json: model.toJson());
  },
  FirestoreCollections.votesSub: (json, id) {
    final uid = DemoDataFixture.voteUid(id);
    final model = VoteModel.fromJson(json, id: uid);
    return (id: model.uid == uid ? id : model.uid, json: model.toJson());
  },
  FirestoreCollections.comments: (json, id) {
    final model = CommentModel.fromJson(json, id: id);
    return (id: model.id, json: model.toJson());
  },
  FirestoreCollections.events: (json, id) {
    final model = EventModel.fromJson(json, id: id);
    return (id: model.id, json: model.toJson());
  },
  FirestoreCollections.rsvps: (json, id) {
    final model = RsvpModel.fromJson(json, id: id);
    return (id: model.id, json: model.toJson());
  },
  FirestoreCollections.notifications: (json, id) {
    final model = NotificationModel.fromJson(json, id: id);
    return (id: model.id, json: model.toJson());
  },
  FirestoreCollections.reports: (json, id) {
    final model = ReportModel.fromJson(json, id: id);
    return (id: model.id, json: model.toJson());
  },
  FirestoreCollections.activity: (json, id) {
    final model = ActivityModel.fromJson(json, id: id);
    return (id: model.id, json: model.toJson());
  },
  FirestoreCollections.settings: (json, id) {
    final model = UserSettingsModel.fromJson(json, id: id);
    return (id: model.uid, json: model.toJson());
  },
  FirestoreCollections.savedPosts: (json, id) {
    final model = SavedPostModel.fromJson(json, id: id);
    return (id: model.id, json: model.toJson());
  },
  FirestoreCollections.announcementCounters: (json, id) {
    final model = CounterModel.fromJson(json, id: id);
    return (id: model.id, json: model.toJson());
  },
};

/// PLAN §9.11 belge sayıları.
const Map<String, int> _expectedCounts = {
  FirestoreCollections.users: 226,
  FirestoreCollections.accountDoc: 226,
  FirestoreCollections.blocks: 1,
  FirestoreCollections.clubs: 14,
  FirestoreCollections.memberships: 515,
  FirestoreCollections.contactDoc: 515,
  FirestoreCollections.posts: 36,
  FirestoreCollections.votesSub: 250,
  FirestoreCollections.comments: 41,
  FirestoreCollections.events: 22,
  FirestoreCollections.rsvps: 944,
  FirestoreCollections.notifications: 40,
  FirestoreCollections.reports: 11,
  FirestoreCollections.activity: 222,
  FirestoreCollections.settings: 226,
  FirestoreCollections.savedPosts: 2,
  FirestoreCollections.announcementCounters: 1,
};

/// `include_if_null: false` karşılığı: `null` değerler (iç içe map'lerde de)
/// atılır.
Object? _withoutNulls(Object? value) => switch (value) {
  final Map<Object?, Object?> map => {
    for (final MapEntry(:key, :value) in map.entries)
      if (value != null) key: _withoutNulls(value),
  },
  final List<Object?> list => [for (final item in list) _withoutNulls(item)],
  _ => value,
};

Map<String, Object?> _rawMap(String key) =>
    DemoDataFixture.raw[key]! as Map<String, Object?>;

Map<String, Object?> _rawDoc(String key, String id) =>
    _rawMap(key)[id]! as Map<String, Object?>;

DateTime _iso(Object? value) => DateTime.parse(value! as String).toUtc();

void main() {
  final docs = DemoDataFixture.build();
  final today = DemoDataFixture.today;

  ClubModel club(String id) => ClubModel.fromJson(
    DemoDataFixture.toFirestoreJson(FirestoreCollections.clubs, id),
    id: id,
  );
  EventModel event(String id) => EventModel.fromJson(
    DemoDataFixture.toFirestoreJson(FirestoreCollections.events, id),
    id: id,
  );
  PostModel post(String id) => PostModel.fromJson(
    DemoDataFixture.toFirestoreJson(FirestoreCollections.posts, id),
    id: id,
  );

  group('T-09 · demo veri · her belge modele ayrışır', () {
    test('dönüşüm 17 koleksiyon üretir; her birinin ayrıştırıcısı var', () {
      expect(docs.keys, DemoDataFixture.collections);
      expect(_parsers.keys.toSet(), DemoDataFixture.collections.toSet());
      expect(_expectedCounts.keys.toSet(), _parsers.keys.toSet());
    });

    test('belge sayıları PLAN §9.11 ve dosyayla eşit', () {
      expect({
        for (final entry in docs.entries) entry.key: entry.value.length,
      }, _expectedCounts);

      // Bire bir taşınan koleksiyonlar: dosyadaki kayıt sayısı.
      for (final MapEntry(key: collection, value: rawKey) in {
        FirestoreCollections.users: 'users',
        FirestoreCollections.accountDoc: 'users',
        FirestoreCollections.clubs: 'clubs',
        FirestoreCollections.memberships: 'memberships',
        FirestoreCollections.contactDoc: 'memberships',
        FirestoreCollections.posts: 'posts',
        FirestoreCollections.comments: 'comments',
        FirestoreCollections.events: 'events',
        FirestoreCollections.rsvps: 'rsvps',
        FirestoreCollections.notifications: 'notifications',
        FirestoreCollections.settings: 'settings',
      }.entries) {
        expect(
          docs[collection]!.keys,
          _rawMap(rawKey).keys,
          reason: collection,
        );
      }
      expect(
        docs[FirestoreCollections.activity],
        hasLength((DemoDataFixture.raw['activity']! as List<Object?>).length),
      );
    });

    for (final collection in DemoDataFixture.collections) {
      test('$collection: her belge hatasız ayrışır, kimliğini taşır ve '
          'girdinin hiçbir alanı düşmez', () {
        const equality = DeepCollectionEquality();
        final problems = <String>[];

        for (final MapEntry(key: id, value: json)
            in docs[collection]!.entries) {
          try {
            final parsed = _parsers[collection]!(json, id);
            if (parsed.id != null && parsed.id != id) {
              problems.add('$collection/$id: kimlik ${parsed.id}');
            }
            final expected = _withoutNulls(json);
            if (!equality.equals(parsed.json, expected)) {
              problems.add(
                '$collection/$id: toJson ${parsed.json} ≠ girdi $expected',
              );
            }
          } on Object catch (error) {
            problems.add('$collection/$id: $error');
          }
        }

        expect(problems.take(5), isEmpty, reason: '${problems.length} sorun');
      });
    }

    test('hiçbir belgede prototip anahtarı kalmaz (*_rel_days, id, stale, '
        'email …)', () {
      const prototypeOnly = {
        'id',
        'stale',
        'global',
        'blocked',
        'emailVerified',
        'advisorId',
        'commentIds',
        'hidden',
        'deleted',
        'reasons',
      };
      final leftovers = <String>{
        for (final MapEntry(key: collection, value: byId) in docs.entries)
          for (final json in byId.values)
            for (final key in json.keys)
              if (key.endsWith('_rel_days') || prototypeOnly.contains(key))
                '$collection.$key',
      };

      expect(leftovers, isEmpty);
      // E-posta yalnızca private alt belgelerinde (D-29).
      expect(
        docs[FirestoreCollections.users]!.values.where(
          (json) => json.containsKey('email'),
        ),
        isEmpty,
      );
    });
  });

  group('T-09 · demo veri · zaman kuralı', () {
    test('now = meta.today iken anlar dosyadaki ISO değeridir (UTC)', () {
      expect(today, DateTime.utc(2026, 10, 7, 21));
      expect(event('e01').startsAt, DateTime.utc(2026, 10, 9, 15));
      expect(event('e01').startsAt.isUtc, isTrue);
      expect(
        event('e01').createdAt,
        _iso(_rawDoc('events', 'e01')['createdAt']),
      );
      expect(event('e01').updatedAt, event('e01').createdAt);
    });

    test('ISO + (now − today) kuralı, now + rel_days ile yuvarlama payı '
        'içinde aynıdır (rel_days iki ondalık)', () {
      const tolerance = Duration(minutes: 7, seconds: 13);
      var checked = 0;
      var worst = Duration.zero;

      void walk(Object? node) {
        if (node is List<Object?>) {
          node.forEach(walk);
        } else if (node is Map<String, Object?>) {
          for (final MapEntry(:key, :value) in node.entries) {
            if (!key.endsWith('_rel_days')) {
              walk(value);
              continue;
            }
            final field = key.substring(0, key.length - '_rel_days'.length);
            final fromRelDays = today.add(
              Duration(
                milliseconds: ((value! as num) * Duration.millisecondsPerDay)
                    .round(),
              ),
            );
            final diff = _iso(node[field]).difference(fromRelDays).abs();
            if (diff > worst) worst = diff;
            checked++;
          }
        }
      }

      walk(DemoDataFixture.raw);

      expect(checked, 2729);
      expect(worst, lessThanOrEqualTo(tolerance));
    });

    test('başka bir "şimdi" her anı aynı miktarda kaydırır; sayaç günü '
        'bugüne taşınır', () {
      const shift = Duration(days: 3, hours: 2);
      final later = today.add(shift);

      final shifted = EventModel.fromJson(
        DemoDataFixture.toFirestoreJson(
          FirestoreCollections.events,
          'e01',
          now: later,
        ),
        id: 'e01',
      );
      expect(shifted.startsAt, event('e01').startsAt.add(shift));
      expect(shifted.createdAt, event('e01').createdAt!.add(shift));

      expect(
        DemoDataFixture.ids(
          FirestoreCollections.announcementCounters,
          now: later,
        ),
        ['c01_20261011'],
      );
    });
  });

  group('T-09 · demo veri · PLAN §9.12 dönüşüm kuralları', () {
    test('users: nameLower Türkçe küçük harf; askıdakiler neden taşır; '
        'e-posta account alt belgesinde', () {
      UserModel user(String id) => UserModel.fromJson(
        DemoDataFixture.toFirestoreJson(FirestoreCollections.users, id),
        id: id,
      );

      expect(user('u_ayse').nameLower, 'ayşe demir');
      expect(user('u_ayse').avatarPath, isNull);
      expect(user('u_ayse').createdAt, isNotNull);
      expect(user('u_ayse').isDeleted, isFalse);
      // Personelde ilgi alanı boş olabilir.
      expect(user('u_admin').staff, isTrue);
      expect(user('u_admin').interests, isEmpty);

      final suspended = [
        for (final id in DemoDataFixture.ids(FirestoreCollections.users))
          if (user(id).status == UserStatus.suspended) user(id),
      ];
      expect([for (final u in suspended) u.uid], ['u_suspended', 'u007']);
      expect(
        suspended.map((u) => u.suspendReason),
        everyElement(DemoDataFixture.seedSuspendReason),
      );
      expect(
        user('u_ayse').suspendReason,
        isNull,
      );

      final account = UserAccountModel.fromJson(
        DemoDataFixture.toFirestoreJson(
          FirestoreCollections.accountDoc,
          'u_ayse',
        ),
      );
      expect(account.email, 'ayse.demir@ogr.gumushane.edu.tr');
      expect(account.emailLower, account.email.toLowerCase());
      expect(account.fcmTokens, isEmpty);
      expect(account.lastLoginAt, isNull);
    });

    test('users.blocked dizisi blocks belgelerine bölünür', () {
      expect(DemoDataFixture.ids(FirestoreCollections.blocks), [
        'u_mehmet_u042',
      ]);
      final block = BlockModel.fromJson(
        DemoDataFixture.toFirestoreJson(
          FirestoreCollections.blocks,
          'u_mehmet_u042',
        ),
        id: 'u_mehmet_u042',
      );
      expect((block.blockerId, block.blockedId), ('u_mehmet', 'u042'));
    });

    test('clubs: memberCount aktif ve danışman olmayan üyelikten yeniden '
        'hesaplanır (demo değeri atılır)', () {
      expect(_rawDoc('clubs', 'c01')['memberCount'], 188);
      expect(club('c01').memberCount, 80);
      expect(club('c03').memberCount, 20);
    });

    test('clubs: nameLower, danışman ünvanı ayrılır, sabitlenen gönderi '
        'posts.pinned değerinden, createdBy süper admin', () {
      expect(club('c02').nameLower, 'girişimcilik ve inovasyon kulübü');
      expect(
        club('c03').advisor,
        const ClubAdvisorModel(
          name: 'Hakan Yalçın',
          title: 'Doç. Dr.',
          userId: 'u_a_c03',
        ),
      );
      expect(
        club('c01').advisor,
        const ClubAdvisorModel(
          name: 'Zeynep Arslan',
          title: 'Dr. Öğr. Üyesi',
          userId: 'u_zeynep',
        ),
      );
      expect(club('c01').pinnedPostId, 'p01');
      expect(
        [
          for (final id in DemoDataFixture.ids(FirestoreCollections.clubs))
            if (club(id).pinnedPostId != null) id,
        ],
        hasLength(8),
      );
      expect(club('c01').createdBy, DemoDataFixture.superAdminId);
      expect(club('c01').logoPath, isNull);
      expect(club('c01').coverPath, isNull);
      expect(club('c01').lastMembershipRef, isNull);
      expect(club('c01').social.instagram, '@guk_yazilim');
      expect(club('c14').status, ClubStatus.suspended);
      expect(club('c14').suspendReason, isNotEmpty);
    });

    test('memberships: başvuran anlık görüntüsü kullanıcıdan; e-posta contact '
        'alt belgesinde; createdAt = appliedAt', () {
      const id = 'c01_u_mehmet';
      final membership = MembershipModel.fromJson(
        DemoDataFixture.toFirestoreJson(FirestoreCollections.memberships, id),
        id: id,
      );
      final user = _rawDoc('users', 'u_mehmet');

      expect(
        membership.applicant,
        MembershipApplicantModel(
          name: user['name']! as String,
          department: user['department'] as String?,
          year: YearLevel.fromJson(user['year']! as String),
          avatarSeed: user['avatarSeed']! as String,
        ),
      );
      expect(membership.createdAt, membership.appliedAt);
      expect(membership.isActiveMember, isTrue);

      final contact = MembershipContactModel.fromJson(
        DemoDataFixture.toFirestoreJson(FirestoreCollections.contactDoc, id),
      );
      expect(contact.email, user['email']);

      // rejectNote yalnızca bazı kayıtlarda; eksikse null.
      final removed = MembershipModel.fromJson(
        DemoDataFixture.toFirestoreJson(
          FirestoreCollections.memberships,
          'c01_u154',
        ),
        id: 'c01_u154',
      );
      expect(removed.status, MembershipStatus.removed);
      expect(removed.rejectReason, RejectReason.other);
      expect(removed.rejectNote, isNotEmpty);
      expect(removed.retryAfter, isNotNull);
      expect(membership.rejectNote, isNull);
    });

    test('posts: beğeniler tekilleşir, sayaçlar hesaplanır, hidden/deleted '
        'yeniden adlandırılır', () {
      final rawLikes = _rawDoc('posts', 'p01')['likes']! as List<Object?>;
      final p01 = post('p01');

      expect(rawLikes.toSet().length, lessThan(rawLikes.length));
      expect(p01.likes, rawLikes.toSet().toList());
      for (final id in DemoDataFixture.ids(FirestoreCollections.posts)) {
        expect(post(id).likeCount, post(id).likes.length, reason: id);
        expect(post(id).likes.toSet(), hasLength(post(id).likes.length));
        expect(post(id).isHidden, isFalse, reason: id);
        expect(post(id).isDeleted, isFalse, reason: id);
      }
      expect(p01.commentCount, 3);
      expect(p01.lastCommentRef, isNull);
      expect(p01.pinned, isTrue);
      expect(p01.isAnnouncement, isTrue);
      expect(p01.title, isNotNull);
    });

    test('posts.images tohum dizgileri {path, w, h} olur; yol '
        'posts/{postId}/<damga>_<16 hex>.png', () {
      final images = post('p02').images;

      expect(images, hasLength(2));
      for (final image in images) {
        expect(
          image.path,
          matches(RegExp(r'^posts/p02/20260930T050000Z_[0-9a-f]{16}\.png$')),
        );
        expect((image.w, image.h), (1200, 900));
      }
      expect(images.first.path, isNot(images.last.path));
    });

    test('anket oyları votes alt belgelerine taşınır: kullanıcı başına ilk '
        'seçenek, createdAt = gönderi + 1 saat', () {
      final p04 = post('p04');
      final rawOptions =
          (_rawDoc('posts', 'p04')['poll']! as Map<String, Object?>)['options']!
              as List<Object?>;
      final rawVotes = [
        for (final option in rawOptions.cast<Map<String, Object?>>())
          for (final uid in option['votes']! as List<Object?>)
            (uid: uid! as String, optionId: option['id']! as String),
      ];
      final p04Votes = {
        for (final key in DemoDataFixture.ids(FirestoreCollections.votesSub))
          if (key.startsWith('p04/'))
            DemoDataFixture.voteUid(key): VoteModel.fromJson(
              DemoDataFixture.toFirestoreJson(
                FirestoreCollections.votesSub,
                key,
              ),
              id: DemoDataFixture.voteUid(key),
            ),
      };

      expect(p04.isPoll, isTrue);
      expect(
        [for (final option in p04.poll!.options) option.id],
        [
          'o1',
          'o2',
          'o3',
          'o4',
        ],
      );
      expect(p04.poll!.endsAt, DateTime.utc(2026, 10, 10, 23));
      // Birden çok seçenekte geçen kullanıcılar tek oya iner.
      expect(rawVotes, hasLength(41));
      expect(p04Votes, hasLength(38));
      for (final MapEntry(key: uid, value: vote) in p04Votes.entries) {
        expect(
          vote.optionId,
          rawVotes.firstWhere((v) => v.uid == uid).optionId,
          reason: uid,
        );
        expect(
          vote.createdAt,
          p04.createdAt!.add(const Duration(hours: 1)),
          reason: uid,
        );
      }
    });

    test('comments: clubId gönderiden kopyalanır', () {
      for (final id in DemoDataFixture.ids(FirestoreCollections.comments)) {
        final comment = CommentModel.fromJson(
          DemoDataFixture.toFirestoreJson(FirestoreCollections.comments, id),
          id: id,
        );
        expect(comment.clubId, post(comment.postId).clubId, reason: id);
      }
    });

    test('events: sayaçlar katılım kayıtlarından — goingCount kayıtlıdır '
        '(going + attended, CD-130); publishedAt taslakta null, diğerlerinde '
        'createdAt', () {
      final e03 = event('e03');
      final e19 = event('e19');

      expect(
        (e03.goingCount, e03.waitlistCount, e03.attendedCount),
        (
          30,
          4,
          0,
        ),
      );
      expect(event('e09').goingCount, 64);
      // e19: 4 "going" + 34 "attended" kayıt, kontenjan 40.
      expect((e19.goingCount, e19.attendedCount, e19.capacity), (38, 34, 40));
      expect(e19.isFull, isFalse);
      expect(e19.attendanceRate, 34 / 38);
      // Hiçbir etkinlikte yoklama kayıtlıyı, kayıtlı kontenjanı aşmaz.
      for (final id in DemoDataFixture.ids(FirestoreCollections.events)) {
        final model = event(id);
        expect(model.attendedCount, lessThanOrEqualTo(model.goingCount));
        expect(
          model.goingCount,
          lessThanOrEqualTo(model.capacity ?? model.goingCount),
          reason: id,
        );
      }
      expect(e03.lastRsvpRef, isNull);
      expect(e03.coverPath, isNull);
      expect(event('e22').status, EventStatus.draft);
      expect(event('e22').publishedAt, isNull);
      for (final id in ['e01', 'e21']) {
        expect(event(id).publishedAt, event(id).createdAt, reason: id);
      }
      expect(event('e21').status, EventStatus.cancelled);
    });

    test('rsvps: clubId etkinlikten; yoklaması alınan 105 kayıtta scannedBy '
        'kulüp başkanı', () {
      var scanned = 0;
      for (final id in DemoDataFixture.ids(FirestoreCollections.rsvps)) {
        final rsvp = RsvpModel.fromJson(
          DemoDataFixture.toFirestoreJson(FirestoreCollections.rsvps, id),
          id: id,
        );
        final clubId = _rawDoc('events', rsvp.eventId)['clubId'];

        expect(rsvp.clubId, clubId, reason: id);
        expect(rsvp.reminder, ReminderOption.oneHour, reason: id);
        if (rsvp.scannedAt == null) {
          expect(rsvp.scannedBy, isNull, reason: id);
        } else {
          scanned++;
          expect(
            rsvp.scannedBy,
            _rawDoc('clubs', clubId! as String)['presidentId'],
            reason: id,
          );
        }
      }
      expect(scanned, 105);
    });

    test('reports: şikayet grubu şikayetçi başına belgeye bölünür; '
        'targetClubId hedef türüne göre', () {
      ReportModel report(String id) => ReportModel.fromJson(
        DemoDataFixture.toFirestoreJson(FirestoreCollections.reports, id),
        id: id,
      );
      final ids = DemoDataFixture.ids(FirestoreCollections.reports);
      final byTarget = <String, List<ReportModel>>{};
      for (final id in ids) {
        final model = report(id);
        expect(
          id,
          FirestoreIds.report(
            model.reporterId,
            model.targetType.json,
            model.targetId,
          ),
        );
        byTarget
            .putIfAbsent(
              '${model.targetType.json}:${model.targetId}',
              () => [],
            )
            .add(model);
      }

      // r01 (post p17) üç şikayetçi → üç belge.
      expect(byTarget['post:p17'], hasLength(3));
      expect(byTarget['post:p17']!.map((r) => r.reporterId), [
        'u051',
        'u052',
        'u053',
      ]);
      expect(
        byTarget['post:p17']!.first.createdAt,
        DateTime.utc(2026, 10, 7, 10, 8, 42, 117),
      );
      expect(byTarget['post:p17']!.map((r) => r.targetClubId), {'c02'});
      expect(byTarget['comment:cm24']!.single.targetClubId, 'c09');
      expect(byTarget['club:c10']!.single.targetClubId, 'c10');
      expect(byTarget['user:u077']!.single.targetClubId, isNull);
      // Çözülmüş grup: durum, işlem ve çözen kopyalanır.
      expect(byTarget['user:u007'], hasLength(2));
      for (final resolved in byTarget['user:u007']!) {
        expect(resolved.status, ReportStatus.resolved);
        expect(resolved.action, ReportAction.suspended);
        expect(resolved.resolvedBy, DemoDataFixture.superAdminId);
        expect(resolved.resolvedAt, isNotNull);
      }
      expect(byTarget['post:p17']!.first.resolvedBy, isNull);
    });

    test('activity: kimlik alanı belge kimliği olur; BaseFields eklenmez', () {
      final json = DemoDataFixture.toFirestoreJson(
        FirestoreCollections.activity,
        'a_muzqv60t_o',
      );

      expect(json.keys, ['clubId', 'actorId', 'kind', 'refs', 'createdAt']);
      expect(json['createdAt'], isA<Timestamp>());
      final activity = ActivityModel.fromJson(json, id: 'a_muzqv60t_o');
      expect(activity.kind, ActivityKind.applicationApproved);
      expect(activity.refs.userId, 'u_ayse');
    });

    test('settings: updatedAt = şimdi; kulübe özgü tercihler korunur', () {
      final settings = UserSettingsModel.fromJson(
        DemoDataFixture.toFirestoreJson(
          FirestoreCollections.settings,
          'u_mehmet',
        ),
        id: 'u_mehmet',
      );

      expect(settings.updatedAt, today);
      expect(settings.clubs, {
        'c07': const ClubNotificationPrefsModel(posts: false),
      });
    });

    test('saved: kullanıcı başına dizi savedPosts belgelerine bölünür', () {
      expect(DemoDataFixture.ids(FirestoreCollections.savedPosts), [
        'u_mehmet_p01',
        'u_mehmet_p21',
      ]);
      final saved = SavedPostModel.fromJson(
        DemoDataFixture.toFirestoreJson(
          FirestoreCollections.savedPosts,
          'u_mehmet_p21',
        ),
        id: 'u_mehmet_p21',
      );
      expect(
        (saved.userId, saved.postId, saved.clubId),
        (
          'u_mehmet',
          'p21',
          'c07',
        ),
      );
      expect(saved.savedAt, today);
    });

    test('dailyAnnouncementCount: sayaç kimliği ve günü bugünün Istanbul '
        'gününe kayar', () {
      expect(_rawMap('dailyAnnouncementCount').keys, ['c01_2026-10-08']);
      const id = 'c01_20261008';
      expect(DemoDataFixture.ids(FirestoreCollections.announcementCounters), [
        id,
      ]);
      final counter = CounterModel.fromJson(
        DemoDataFixture.toFirestoreJson(
          FirestoreCollections.announcementCounters,
          id,
        ),
        id: id,
      );

      expect(
        (counter.clubId, counter.day, counter.count),
        (
          'c01',
          '2026-10-08',
          1,
        ),
      );
      expect(counter.lastPostRef, isNull);
      expect(counter.updatedAt, today);
      expect(counter.remaining, Limits.announcementDailyLimit - 1);
    });

    test('bilinmeyen koleksiyon ya da kimlik ArgumentError fırlatır', () {
      expect(
        () => DemoDataFixture.toFirestoreJson('yok', 'x'),
        throwsArgumentError,
      );
      expect(
        () => DemoDataFixture.toFirestoreJson(FirestoreCollections.clubs, 'x'),
        throwsArgumentError,
      );
    });
  });
}

// Demo veri okuyucu + PLAN §9.12 seed dönüşümünün Dart kopyası (PLAN §9.1,
// §9.11). `tool/seed/demo-data.json` prototip biçimindedir; buradaki dönüşüm
// her belgeyi üretim şemasına (PLAN §9.6) çevirir. T-10 tohumlayıcısı
// (`tool/seed/seed_emulator.js`) aynı kuralları uygular.
//
// Bu dosyanın iki birebir kopyası vardır (paket sınırı — kök testleri
// gu_data'nın test klasörünü göremez): `packages/gu_data/test/fixtures/
// demo_data.dart` (asıl) ve `test/fixtures/demo_data.dart` (kök fixture'ları);
// eşliği `test/fixtures/fixtures_test.dart` doğrular. Dosya bu yüzden kendi
// kendine yeter: başka test yardımcısı içe aktarmaz. JSON anahtarları bilerek
// dizgi olarak yazılır: dönüşüm, model anahtarlarını (`FirestoreFields`)
// ikinci bir kaynaktan doğrular.
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gu_data/gu_data.dart';

/// Üretim şemasına çevrilmiş demo veri: koleksiyon → belge kimliği → Firestore
/// map'i.
typedef DemoDocs = Map<String, Map<String, Map<String, Object?>>>;

/// `tool/seed/demo-data.json` okuyucu ve PLAN §9.12 dönüşümü.
///
/// Koleksiyon adları `FirestoreCollections` sabitleridir; alt belgeler kendi
/// adlarıyla anahtarlanır:
///
/// - [FirestoreCollections.accountDoc] — `users/{uid}/private/account`,
///   kimlik `uid`;
/// - [FirestoreCollections.contactDoc] — `memberships/{id}/private/contact`,
///   kimlik üyelik kimliği;
/// - [FirestoreCollections.votesSub] — `posts/{postId}/votes/{uid}`, kimlik
///   `'$postId/$uid'` ([voteKey]).
///
/// "Şimdi" verilmezse [today] (`meta.today`) kullanılır: sonuç deterministiktir
/// ve `FakeAppClock(DemoDataFixture.today)` ile aynı anı gösterir.
///
/// Zaman kuralı: her an `ISO + (now − meta.today)` olur; `*_rel_days`
/// anahtarları yazılmaz. Bu, PLAN §9.12'deki `now + rel_days` kuralının
/// yuvarlamasız karşılığıdır (`rel_days` iki ondalığa yuvarlıdır, ±7,2 dk;
/// eşdeğerliği `demo_data_parse_test.dart` doğrular): `now == meta.today` iken
/// an ISO'nun kendisidir (PLAN §9.12 `posts/p02/20260930T050000Z_…` örneği).
abstract final class DemoDataFixture {
  /// Depo köküne göre demo veri dosyası.
  static const String sourcePath = 'tool/seed/demo-data.json';

  /// Askıdaki kullanıcılara yazılan neden (PLAN §9.12 `SEED_SUSPEND_REASON`).
  static const String seedSuspendReason = 'Topluluk kurallarının ihlali.';

  /// Danışman adından ayrılan ünvanlar (PLAN §9.12 `SEED_TITLES`), sırayla
  /// denenir.
  static const List<String> seedTitles = [
    'Prof. Dr.',
    'Doç. Dr.',
    'Dr. Öğr. Üyesi',
    'Öğr. Gör.',
    'Dr.',
  ];

  /// Kulüpleri oluşturan ve şikayetleri çözen süper admin.
  static const String superAdminId = 'u_admin';

  /// Dönüşümün ürettiği koleksiyonlar (17).
  static const List<String> collections = [
    FirestoreCollections.users,
    FirestoreCollections.accountDoc,
    FirestoreCollections.blocks,
    FirestoreCollections.clubs,
    FirestoreCollections.memberships,
    FirestoreCollections.contactDoc,
    FirestoreCollections.posts,
    FirestoreCollections.votesSub,
    FirestoreCollections.comments,
    FirestoreCollections.events,
    FirestoreCollections.rsvps,
    FirestoreCollections.notifications,
    FirestoreCollections.reports,
    FirestoreCollections.activity,
    FirestoreCollections.settings,
    FirestoreCollections.savedPosts,
    FirestoreCollections.announcementCounters,
  ];

  static const SystemAppClock _calendar = SystemAppClock();

  static Map<String, Object?>? _raw;
  static final Map<DateTime, DemoDocs> _cache = {};

  /// Dosyanın ham içeriği (prototip biçimi).
  static Map<String, Object?> get raw => _raw ??=
      jsonDecode(_sourceFile().readAsStringSync()) as Map<String, Object?>;

  /// Demo verinin "bugün"ü (`meta.today`, UTC).
  static DateTime get today =>
      DateTime.parse(_map(raw['meta'])['today']! as String).toUtc();

  /// [collection] belgelerinin kimlikleri, dosya sırasıyla.
  static List<String> ids(String collection, {DateTime? now}) =>
      _collection(collection, now).keys.toList();

  /// [collection] içindeki [id] belgesinin Firestore map'i (üretim şeması;
  /// zamanlar `Timestamp`). Belge kimliği map'e girmez.
  ///
  /// Bilinmeyen koleksiyon ya da kimlik [ArgumentError] fırlatır.
  static Map<String, Object?> toFirestoreJson(
    String collection,
    String id, {
    DateTime? now,
  }) =>
      _collection(collection, now)[id] ??
      (throw ArgumentError.value(id, 'id', '$collection: belge yok'));

  /// Oy belgesinin dönüşüm anahtarı: `'$postId/$uid'`.
  static String voteKey(String postId, String uid) => '$postId/$uid';

  /// [voteKey] anahtarındaki oy verenin `uid`'i (oy belgesinin kimliği).
  static String voteUid(String key) => key.substring(key.indexOf('/') + 1);

  /// Tüm koleksiyonların dönüşümü. Aynı [now] için sonuç önbelleğe alınır.
  static DemoDocs build({DateTime? now}) {
    final at = (now ?? today).toUtc();
    return _cache[at] ??= _Converter(raw, at, at.difference(today)).convert();
  }

  static Map<String, Map<String, Object?>> _collection(
    String collection,
    DateTime? now,
  ) =>
      build(now: now)[collection] ??
      (throw ArgumentError.value(collection, 'collection', 'koleksiyon yok'));

  /// Çalışma dizininden yukarı doğru [sourcePath] içeren ilk dizindeki dosya
  /// (`flutter test` paket kökünde de depo kökünde de koşabilir).
  static File _sourceFile() {
    var dir = Directory.current.absolute;
    while (true) {
      final file = File('${dir.path}/$sourcePath');
      if (file.existsSync()) return file;
      final parent = dir.parent;
      if (parent.path == dir.path) {
        throw StateError(
          '$sourcePath bulunamadı: ${Directory.current.path}',
        );
      }
      dir = parent;
    }
  }
}

Map<String, Object?> _map(Object? value) => value! as Map<String, Object?>;

List<Object?> _list(Object? value) => value! as List<Object?>;

/// PLAN §9.12 satırlarının uygulaması; her metot bir koleksiyonu çevirir.
final class _Converter {
  _Converter(this.raw, this.now, this.shift);

  final Map<String, Object?> raw;

  /// Dönüşümün "şimdi"si (çalıştırma anı).
  final DateTime now;

  /// `now − meta.today`: dosyadaki her an bu kadar kaydırılır.
  final Duration shift;

  late final Map<String, Object?> users = _map(raw['users']);
  late final Map<String, Object?> clubs = _map(raw['clubs']);
  late final Map<String, Object?> memberships = _map(raw['memberships']);
  late final Map<String, Object?> posts = _map(raw['posts']);
  late final Map<String, Object?> comments = _map(raw['comments']);
  late final Map<String, Object?> events = _map(raw['events']);
  late final Map<String, Object?> rsvps = _map(raw['rsvps']);

  DemoDocs convert() => {
    FirestoreCollections.users: _users(),
    FirestoreCollections.accountDoc: _accounts(),
    FirestoreCollections.blocks: _blocks(),
    FirestoreCollections.clubs: _clubs(),
    FirestoreCollections.memberships: _memberships(),
    FirestoreCollections.contactDoc: _contacts(),
    FirestoreCollections.posts: _posts(),
    FirestoreCollections.votesSub: _votes(),
    FirestoreCollections.comments: _comments(),
    FirestoreCollections.events: _events(),
    FirestoreCollections.rsvps: _rsvps(),
    FirestoreCollections.notifications: _notifications(),
    FirestoreCollections.reports: _reports(),
    FirestoreCollections.activity: _activity(),
    FirestoreCollections.settings: _settings(),
    FirestoreCollections.savedPosts: _savedPosts(),
    FirestoreCollections.announcementCounters: _counters(),
  };

  // ── Ortak kurallar ───────────────────────────────────────────────────

  /// [doc] içindeki [field] anı: ISO dizgisi + [shift]; alan boşsa `null`.
  DateTime? _time(Map<String, Object?> doc, String field) {
    final iso = doc[field];
    return iso is String ? DateTime.parse(iso).toUtc().add(shift) : null;
  }

  Timestamp? _stamp(DateTime? time) =>
      time == null ? null : Timestamp.fromDate(time);

  /// BaseFields: `updatedAt = createdAt`, silinmemiş.
  Map<String, Object?> _base(DateTime? createdAt) => {
    'createdAt': _stamp(createdAt),
    'updatedAt': _stamp(createdAt),
    'isDeleted': false,
    'deletedAt': null,
    'deletedBy': null,
  };

  /// Seed betiğinin `tr_lower.js` kuralı: `İ→i`, `I→ı`, sonra küçük harf.
  String _trLower(String text) =>
      text.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();

  // ── users · account · blocks ─────────────────────────────────────────

  Map<String, Map<String, Object?>> _users() => {
    for (final MapEntry(key: uid, :value) in users.entries)
      uid: () {
        final user = _map(value);
        final name = user['name']! as String;
        return <String, Object?>{
          'name': name,
          'nameLower': _trLower(name),
          'avatarSeed': user['avatarSeed'],
          'avatarPath': null,
          'department': user['department'],
          'year': user['year'],
          'interests': user['interests'],
          'bio': user['bio'],
          'status': user['status'],
          'suspendReason': user['status'] == 'suspended'
              ? DemoDataFixture.seedSuspendReason
              : null,
          'staff': user['staff'],
          'profileComplete': user['profileComplete'],
          ..._base(_time(user, 'createdAt')),
        };
      }(),
  };

  Map<String, Map<String, Object?>> _accounts() => {
    for (final MapEntry(key: uid, :value) in users.entries)
      uid: _emailDoc(_map(value), _time(_map(value), 'createdAt'))
        ..addAll({'fcmTokens': <Object?>[], 'lastLoginAt': null}),
  };

  Map<String, Object?> _emailDoc(
    Map<String, Object?> user,
    DateTime? createdAt,
  ) {
    final email = user['email']! as String;
    return {
      'email': email,
      'emailLower': email.toLowerCase(),
      ..._base(createdAt),
    };
  }

  Map<String, Map<String, Object?>> _blocks() => {
    for (final MapEntry(key: uid, :value) in users.entries)
      for (final blocked in _list(_map(value)['blocked']).cast<String>())
        FirestoreIds.block(uid, blocked): {
          'blockerId': uid,
          'blockedId': blocked,
          ..._base(now),
        },
  };

  // ── clubs ────────────────────────────────────────────────────────────

  Map<String, Map<String, Object?>> _clubs() => {
    for (final MapEntry(key: clubId, :value) in clubs.entries)
      clubId: () {
        final club = _map(value);
        final name = club['name']! as String;
        return <String, Object?>{
          'name': name,
          'nameLower': _trLower(name),
          'categoryId': club['categoryId'],
          'iconName': club['iconName'],
          'palette': club['palette'],
          'pattern': club['pattern'],
          'coverSeed': club['coverSeed'],
          'logoPath': null,
          'coverPath': null,
          'memberCount': _memberCount(clubId),
          'approvalRequired': club['approvalRequired'],
          'applicationsOpen': club['applicationsOpen'],
          'requireNote': club['requireNote'],
          'founded': club['founded'],
          'summary': club['summary'],
          'about': club['about'],
          'conditions': club['conditions'],
          'social': club['social'],
          'presidentId': club['presidentId'],
          'pinnedPostId': _pinnedPostId(clubId),
          'advisor': _advisor(club['advisorId']! as String),
          'status': club['status'],
          'suspendReason': club['suspendReason'],
          'lastMembershipRef': null,
          'createdBy': DemoDataFixture.superAdminId,
          ..._base(_time(club, 'createdAt')),
        };
      }(),
  };

  /// Aktif ve danışman olmayan üyelik sayısı (demo'daki görsel sayı atılır).
  int _memberCount(String clubId) => memberships.values
      .map(_map)
      .where(
        (m) =>
            m['clubId'] == clubId &&
            m['status'] == 'active' &&
            m['role'] != 'advisor',
      )
      .length;

  String? _pinnedPostId(String clubId) {
    for (final MapEntry(key: postId, :value) in posts.entries) {
      final post = _map(value);
      if (post['clubId'] == clubId && post['pinned'] == true) return postId;
    }
    return null;
  }

  /// Danışman anlık görüntüsü: ad, [DemoDataFixture.seedTitles] önekiyle
  /// ünvan + ad olarak bölünür.
  Map<String, Object?> _advisor(String advisorId) {
    final fullName = _map(users[advisorId])['name']! as String;
    final title = DemoDataFixture.seedTitles
        .where((title) => fullName.startsWith('$title '))
        .firstOrNull;
    return {
      'name': title == null ? fullName : fullName.substring(title.length + 1),
      'title': title ?? '',
      'userId': advisorId,
    };
  }

  // ── memberships · contact ────────────────────────────────────────────

  Map<String, Map<String, Object?>> _memberships() => {
    for (final MapEntry(key: id, :value) in memberships.entries)
      id: () {
        final membership = _map(value);
        final user = _map(users[membership['userId']]);
        return <String, Object?>{
          'clubId': membership['clubId'],
          'userId': membership['userId'],
          'status': membership['status'],
          'role': membership['role'],
          'note': membership['note'],
          'applicant': {
            'name': user['name'],
            'department': user['department'],
            'year': user['year'],
            'avatarSeed': user['avatarSeed'],
          },
          'appliedAt': _stamp(_time(membership, 'appliedAt')),
          'decidedAt': _stamp(_time(membership, 'decidedAt')),
          'decidedBy': membership['decidedBy'],
          'retryAfter': _stamp(_time(membership, 'retryAfter')),
          'rejectReason': membership['rejectReason'],
          'rejectNote': membership['rejectNote'],
          'priorCount': membership['priorCount'],
          ..._base(_time(membership, 'appliedAt')),
        };
      }(),
  };

  Map<String, Map<String, Object?>> _contacts() => {
    for (final MapEntry(key: id, :value) in memberships.entries)
      id: _emailDoc(
        _map(users[_map(value)['userId']]),
        _time(_map(value), 'appliedAt'),
      ),
  };

  // ── posts · votes · comments ─────────────────────────────────────────

  Map<String, Map<String, Object?>> _posts() => {
    for (final MapEntry(key: postId, :value) in posts.entries)
      postId: () {
        final post = _map(value);
        final createdAt = _time(post, 'createdAt');
        final likes = _list(post['likes']).cast<String>().toSet().toList();
        final poll = post['poll'];
        return <String, Object?>{
          'clubId': post['clubId'],
          'authorId': post['authorId'],
          'type': post['type'],
          'title': post['title'],
          'text': post['text'],
          'images': [
            for (final seed in _list(post['images']).cast<String>())
              {
                'path': 'posts/$postId/${_fileName(createdAt!, seed)}',
                'w': 1200,
                'h': 900,
              },
          ],
          'poll': poll == null ? null : _poll(_map(poll)),
          'pinned': post['pinned'],
          'pushSent': post['pushSent'],
          'likes': likes,
          'likeCount': likes.length,
          'commentCount': comments.values
              .map(_map)
              .where((c) => c['postId'] == postId && c['deleted'] != true)
              .length,
          'lastCommentRef': null,
          'isHidden': post['hidden'],
          'hiddenBy': null,
          'hiddenAt': null,
          'editedAt': _stamp(_time(post, 'editedAt')),
          ..._base(createdAt),
          'isDeleted': post['deleted'],
        };
      }(),
  };

  Map<String, Object?> _poll(Map<String, Object?> poll) => {
    'options': [
      for (final option in _list(poll['options']).map(_map))
        {'id': option['id'], 'text': option['text']},
    ],
    'endsAt': _stamp(_time(poll, 'endsAt')),
    'showResultsAfterVote': poll['showResultsAfterVote'],
  };

  /// `StoragePaths.newFileName` şeması: `<UTC yyyyMMddTHHmmssZ>_<16 hex>.png`.
  /// Seed betiği 16 hex'i rastgele üretir; burada tohumdan türetilir
  /// (deterministik).
  String _fileName(DateTime createdAt, String seed) {
    String two(int value) => value.toString().padLeft(2, '0');
    final stamp =
        '${createdAt.year.toString().padLeft(4, '0')}${two(createdAt.month)}'
        '${two(createdAt.day)}T${two(createdAt.hour)}${two(createdAt.minute)}'
        '${two(createdAt.second)}Z';
    return '${stamp}_${_hex8(seed, 0x811c9dc5)}${_hex8(seed, 0x01000193)}.png';
  }

  /// [text] için 32 bit FNV-1a özeti (8 hex); [basis] başlangıç değeridir.
  String _hex8(String text, int basis) {
    var hash = basis;
    for (final unit in text.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  /// Her kullanıcının **ilk** geçtiği seçenek bir oy belgesi olur; çoklu
  /// seçenek tekrarları düşer. `createdAt = post.createdAt + 1 saat`.
  Map<String, Map<String, Object?>> _votes() => {
    for (final MapEntry(key: postId, :value) in posts.entries)
      if (_map(value)['poll'] case final Map<String, Object?> poll)
        ..._pollVotes(
          postId,
          poll,
          _time(_map(value), 'createdAt')!.add(const Duration(hours: 1)),
        ),
  };

  Map<String, Map<String, Object?>> _pollVotes(
    String postId,
    Map<String, Object?> poll,
    DateTime createdAt,
  ) {
    final votes = <String, Map<String, Object?>>{};
    for (final option in _list(poll['options']).map(_map)) {
      for (final uid in _list(option['votes']).cast<String>()) {
        votes.putIfAbsent(
          DemoDataFixture.voteKey(postId, uid),
          () => {'optionId': option['id'], 'createdAt': _stamp(createdAt)},
        );
      }
    }
    return votes;
  }

  Map<String, Map<String, Object?>> _comments() => {
    for (final MapEntry(key: commentId, :value) in comments.entries)
      commentId: () {
        final comment = _map(value);
        return <String, Object?>{
          'postId': comment['postId'],
          'clubId': _map(posts[comment['postId']])['clubId'],
          'authorId': comment['authorId'],
          'text': comment['text'],
          'isHidden': comment['hidden'],
          'hiddenBy': null,
          'hiddenAt': null,
          ..._base(_time(comment, 'createdAt')),
          'isDeleted': comment['deleted'],
        };
      }(),
  };

  // ── events · rsvps ───────────────────────────────────────────────────

  Map<String, Map<String, Object?>> _events() => {
    for (final MapEntry(key: eventId, :value) in events.entries)
      eventId: () {
        final event = _map(value);
        final createdAt = _time(event, 'createdAt');
        return <String, Object?>{
          'clubId': event['clubId'],
          'createdBy': event['createdBy'],
          'title': event['title'],
          'desc': event['desc'],
          'type': event['type'],
          'startsAt': _stamp(_time(event, 'startsAt')),
          'endsAt': _stamp(_time(event, 'endsAt')),
          'placeId': event['placeId'],
          'placeText': event['placeText'],
          'capacity': event['capacity'],
          'visibility': event['visibility'],
          'status': event['status'],
          'cancelReason': event['cancelReason'],
          'coverSeed': event['coverSeed'],
          'coverPalette': event['coverPalette'],
          'coverPattern': event['coverPattern'],
          'coverPath': null,
          'registrationOpen': event['registrationOpen'],
          'autoReminder': event['autoReminder'],
          // Kayıtlı = going + attended: yoklama goingCount'u düşürmez
          // (Rules `going→attended` = (0, 0, +1); CD-130).
          'goingCount':
              _rsvpCount(eventId, 'going') + _rsvpCount(eventId, 'attended'),
          'waitlistCount': _rsvpCount(eventId, 'waitlist'),
          'attendedCount': _rsvpCount(eventId, 'attended'),
          'lastRsvpRef': null,
          'publishedAt': event['status'] == 'draft' ? null : _stamp(createdAt),
          ..._base(createdAt),
        };
      }(),
  };

  int _rsvpCount(String eventId, String status) => rsvps.values
      .map(_map)
      .where((r) => r['eventId'] == eventId && r['status'] == status)
      .length;

  Map<String, Map<String, Object?>> _rsvps() => {
    for (final MapEntry(key: id, :value) in rsvps.entries)
      id: () {
        final rsvp = _map(value);
        final clubId = _map(events[rsvp['eventId']])['clubId']! as String;
        final scannedAt = _time(rsvp, 'scannedAt');
        return <String, Object?>{
          'eventId': rsvp['eventId'],
          'clubId': clubId,
          'userId': rsvp['userId'],
          'status': rsvp['status'],
          'reminder': rsvp['reminder'],
          'ticketCode': rsvp['ticketCode'],
          'waitlistAt': _stamp(_time(rsvp, 'waitlistAt')),
          'scannedAt': _stamp(scannedAt),
          'scannedBy': scannedAt == null
              ? null
              : _map(clubs[clubId])['presidentId'],
          ..._base(_time(rsvp, 'createdAt')),
        };
      }(),
  };

  // ── notifications · reports · activity ───────────────────────────────

  Map<String, Map<String, Object?>> _notifications() => {
    for (final MapEntry(key: id, :value) in _map(raw['notifications']).entries)
      id: () {
        final notification = _map(value);
        return <String, Object?>{
          'userId': notification['userId'],
          'type': notification['type'],
          'refs': notification['refs'],
          'read': notification['read'],
          ..._base(_time(notification, 'createdAt')),
        };
      }(),
  };

  /// Şikayet grubu şikayetçi başına bir belgeye bölünür.
  Map<String, Map<String, Object?>> _reports() => {
    for (final group in _map(raw['reports']).values.map(_map))
      for (final reason in _list(group['reasons']).map(_map))
        FirestoreIds.report(
          reason['reporterId']! as String,
          group['targetType']! as String,
          group['targetId']! as String,
        ): {
          'targetType': group['targetType'],
          'targetId': group['targetId'],
          'targetClubId': _targetClubId(
            group['targetType']! as String,
            group['targetId']! as String,
          ),
          'reporterId': reason['reporterId'],
          'reason': reason['reason'],
          'note': reason['note'],
          'status': group['status'],
          'action': group['action'],
          'resolvedAt': _stamp(_time(group, 'resolvedAt')),
          'resolvedBy': group['status'] == 'resolved'
              ? DemoDataFixture.superAdminId
              : null,
          ..._base(_time(reason, 'createdAt')),
        },
  };

  String? _targetClubId(String targetType, String targetId) =>
      switch (targetType) {
        'post' => _map(posts[targetId])['clubId'] as String?,
        'comment' =>
          _map(posts[_map(comments[targetId])['postId']])['clubId'] as String?,
        'club' => targetId,
        'event' => _map(events[targetId])['clubId'] as String?,
        _ => null,
      };

  /// Değiştirilemez günlük: BaseFields eklenmez, yalnızca `createdAt`.
  Map<String, Map<String, Object?>> _activity() => {
    for (final entry in _list(raw['activity']).map(_map))
      entry['id']! as String: {
        'clubId': entry['clubId'],
        'actorId': entry['actorId'],
        'kind': entry['kind'],
        'refs': entry['refs'],
        'createdAt': _stamp(_time(entry, 'createdAt')),
      },
  };

  // ── settings · savedPosts · announcementCounters ─────────────────────

  Map<String, Map<String, Object?>> _settings() => {
    for (final MapEntry(key: uid, :value) in _map(raw['settings']).entries)
      uid: {..._map(value), 'updatedAt': _stamp(now)},
  };

  Map<String, Map<String, Object?>> _savedPosts() => {
    for (final MapEntry(key: uid, :value) in _map(raw['saved']).entries)
      for (final postId in _list(value).cast<String>())
        FirestoreIds.savedPost(uid, postId): {
          'userId': uid,
          'postId': postId,
          'clubId': _map(posts[postId])['clubId'],
          'savedAt': _stamp(now),
          ..._base(now),
        },
  };

  /// Sayaç günü **bugüne** kaydırılır (Istanbul günü); demo'daki tarih atılır.
  Map<String, Map<String, Object?>> _counters() => {
    for (final MapEntry(:key, :value) in _map(
      raw['dailyAnnouncementCount'],
    ).entries)
      FirestoreIds.announcementCounter(
        key.substring(0, key.lastIndexOf('_')),
        DemoDataFixture._calendar.istanbulDayKey(now),
      ): {
        'clubId': key.substring(0, key.lastIndexOf('_')),
        'day': DemoDataFixture._calendar.istanbulDay(now),
        'count': value,
        'lastPostRef': null,
        'updatedAt': _stamp(now),
      },
  };
}

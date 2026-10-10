// T-08 · FirestoreFields: PLAN §9.6 tablolarıyla (ve gömülü model
// tanımlarıyla) ad + değer paritesi, tekillik, noktalı yollar ve kaynak
// dosya denetimi. Tablolar docs/PLAN.md'den okunur.
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../helpers/repo_sources.dart';

/// `FirestoreFields` üyelerinin gerçek değerleri. Dart'ta yansıma olmadığı
/// için elle tutulur; anahtar kümesi hem PLAN §9.6'dan türetilen kümeyle hem
/// de `firestore_fields.dart` kaynak dosyasındaki bildirimlerle
/// karşılaştırılır (eksik/fazla = kırmızı).
const Map<String, String> _actual = {
  'createdAt': FirestoreFields.createdAt,
  'updatedAt': FirestoreFields.updatedAt,
  'createdBy': FirestoreFields.createdBy,
  'isDeleted': FirestoreFields.isDeleted,
  'deletedAt': FirestoreFields.deletedAt,
  'deletedBy': FirestoreFields.deletedBy,
  'name': FirestoreFields.name,
  'nameLower': FirestoreFields.nameLower,
  'avatarSeed': FirestoreFields.avatarSeed,
  'avatarPath': FirestoreFields.avatarPath,
  'department': FirestoreFields.department,
  'year': FirestoreFields.year,
  'interests': FirestoreFields.interests,
  'bio': FirestoreFields.bio,
  'status': FirestoreFields.status,
  'suspendReason': FirestoreFields.suspendReason,
  'staff': FirestoreFields.staff,
  'profileComplete': FirestoreFields.profileComplete,
  'email': FirestoreFields.email,
  'emailLower': FirestoreFields.emailLower,
  'fcmTokens': FirestoreFields.fcmTokens,
  'lastLoginAt': FirestoreFields.lastLoginAt,
  'token': FirestoreFields.token,
  'platform': FirestoreFields.platform,
  'categoryId': FirestoreFields.categoryId,
  'iconName': FirestoreFields.iconName,
  'palette': FirestoreFields.palette,
  'pattern': FirestoreFields.pattern,
  'coverSeed': FirestoreFields.coverSeed,
  'logoPath': FirestoreFields.logoPath,
  'coverPath': FirestoreFields.coverPath,
  'memberCount': FirestoreFields.memberCount,
  'approvalRequired': FirestoreFields.approvalRequired,
  'applicationsOpen': FirestoreFields.applicationsOpen,
  'requireNote': FirestoreFields.requireNote,
  'founded': FirestoreFields.founded,
  'summary': FirestoreFields.summary,
  'about': FirestoreFields.about,
  'conditions': FirestoreFields.conditions,
  'social': FirestoreFields.social,
  'presidentId': FirestoreFields.presidentId,
  'pinnedPostId': FirestoreFields.pinnedPostId,
  'advisor': FirestoreFields.advisor,
  'lastMembershipRef': FirestoreFields.lastMembershipRef,
  'instagram': FirestoreFields.instagram,
  'web': FirestoreFields.web,
  'title': FirestoreFields.title,
  'userId': FirestoreFields.userId,
  'clubId': FirestoreFields.clubId,
  'role': FirestoreFields.role,
  'note': FirestoreFields.note,
  'applicant': FirestoreFields.applicant,
  'appliedAt': FirestoreFields.appliedAt,
  'decidedAt': FirestoreFields.decidedAt,
  'decidedBy': FirestoreFields.decidedBy,
  'retryAfter': FirestoreFields.retryAfter,
  'rejectReason': FirestoreFields.rejectReason,
  'rejectNote': FirestoreFields.rejectNote,
  'priorCount': FirestoreFields.priorCount,
  'authorId': FirestoreFields.authorId,
  'type': FirestoreFields.type,
  'text': FirestoreFields.text,
  'images': FirestoreFields.images,
  'poll': FirestoreFields.poll,
  'pinned': FirestoreFields.pinned,
  'pushSent': FirestoreFields.pushSent,
  'likes': FirestoreFields.likes,
  'likeCount': FirestoreFields.likeCount,
  'commentCount': FirestoreFields.commentCount,
  'lastCommentRef': FirestoreFields.lastCommentRef,
  'isHidden': FirestoreFields.isHidden,
  'hiddenBy': FirestoreFields.hiddenBy,
  'hiddenAt': FirestoreFields.hiddenAt,
  'editedAt': FirestoreFields.editedAt,
  'path': FirestoreFields.path,
  'w': FirestoreFields.w,
  'h': FirestoreFields.h,
  'options': FirestoreFields.options,
  'endsAt': FirestoreFields.endsAt,
  'showResultsAfterVote': FirestoreFields.showResultsAfterVote,
  'id': FirestoreFields.id,
  'optionId': FirestoreFields.optionId,
  'postId': FirestoreFields.postId,
  'desc': FirestoreFields.desc,
  'startsAt': FirestoreFields.startsAt,
  'placeId': FirestoreFields.placeId,
  'placeText': FirestoreFields.placeText,
  'capacity': FirestoreFields.capacity,
  'visibility': FirestoreFields.visibility,
  'cancelReason': FirestoreFields.cancelReason,
  'coverPalette': FirestoreFields.coverPalette,
  'coverPattern': FirestoreFields.coverPattern,
  'registrationOpen': FirestoreFields.registrationOpen,
  'autoReminder': FirestoreFields.autoReminder,
  'goingCount': FirestoreFields.goingCount,
  'waitlistCount': FirestoreFields.waitlistCount,
  'attendedCount': FirestoreFields.attendedCount,
  'lastRsvpRef': FirestoreFields.lastRsvpRef,
  'publishedAt': FirestoreFields.publishedAt,
  'eventId': FirestoreFields.eventId,
  'reminder': FirestoreFields.reminder,
  'ticketCode': FirestoreFields.ticketCode,
  'waitlistAt': FirestoreFields.waitlistAt,
  'scannedAt': FirestoreFields.scannedAt,
  'scannedBy': FirestoreFields.scannedBy,
  'refs': FirestoreFields.refs,
  'read': FirestoreFields.read,
  'applicantId': FirestoreFields.applicantId,
  'reportId': FirestoreFields.reportId,
  'textKey': FirestoreFields.textKey,
  'targetType': FirestoreFields.targetType,
  'targetId': FirestoreFields.targetId,
  'targetClubId': FirestoreFields.targetClubId,
  'reporterId': FirestoreFields.reporterId,
  'reason': FirestoreFields.reason,
  'action': FirestoreFields.action,
  'resolvedAt': FirestoreFields.resolvedAt,
  'resolvedBy': FirestoreFields.resolvedBy,
  'actorId': FirestoreFields.actorId,
  'kind': FirestoreFields.kind,
  'announcements': FirestoreFields.announcements,
  'eventReminders': FirestoreFields.eventReminders,
  'newEvents': FirestoreFields.newEvents,
  'applicationResults': FirestoreFields.applicationResults,
  'management': FirestoreFields.management,
  'system': FirestoreFields.system,
  'reminderTime': FirestoreFields.reminderTime,
  'quiet': FirestoreFields.quiet,
  'quietFrom': FirestoreFields.quietFrom,
  'quietTo': FirestoreFields.quietTo,
  'clubs': FirestoreFields.clubs,
  'events': FirestoreFields.events,
  'posts': FirestoreFields.posts,
  'muted': FirestoreFields.muted,
  'blockerId': FirestoreFields.blockerId,
  'blockedId': FirestoreFields.blockedId,
  'savedAt': FirestoreFields.savedAt,
  'ticketNo': FirestoreFields.ticketNo,
  'subject': FirestoreFields.subject,
  'message': FirestoreFields.message,
  'attachmentPaths': FirestoreFields.attachmentPaths,
  'day': FirestoreFields.day,
  'count': FirestoreFields.count,
  'lastPostRef': FirestoreFields.lastPostRef,
  'socialEmail': FirestoreFields.socialEmail,
  'socialInstagram': FirestoreFields.socialInstagram,
  'socialWeb': FirestoreFields.socialWeb,
  'advisorName': FirestoreFields.advisorName,
  'advisorTitle': FirestoreFields.advisorTitle,
  'advisorUserId': FirestoreFields.advisorUserId,
  'applicantName': FirestoreFields.applicantName,
  'applicantDepartment': FirestoreFields.applicantDepartment,
  'applicantYear': FirestoreFields.applicantYear,
  'applicantAvatarSeed': FirestoreFields.applicantAvatarSeed,
  'pollOptions': FirestoreFields.pollOptions,
  'pollEndsAt': FirestoreFields.pollEndsAt,
  'pollShowResultsAfterVote': FirestoreFields.pollShowResultsAfterVote,
  'refsClubId': FirestoreFields.refsClubId,
  'refsEventId': FirestoreFields.refsEventId,
  'refsPostId': FirestoreFields.refsPostId,
  'refsApplicantId': FirestoreFields.refsApplicantId,
  'refsReportId': FirestoreFields.refsReportId,
  'refsRole': FirestoreFields.refsRole,
  'refsTextKey': FirestoreFields.refsTextKey,
  'refsUserId': FirestoreFields.refsUserId,
  'clubsPrefix': FirestoreFields.clubsPrefix,
};

/// §9.6 tablolarının (+ BaseFields + gömülü model tanımlarının) verdiği
/// tekil ad sayısı. PLAN §4.2, §9.1, §9.5 ve §9.11 aynı sayıyı beyan eder
/// (v1'deki 145 sayım hatasıydı — CD-129); beyan tablodan türeyen sayıyla
/// karşılaştırılır.
const int _tableDerivedCount = 144;

/// §9.6 alt bölüm sayısı (18 koleksiyon / alt belge tablosu).
const int _tableCount = 18;

/// §9.6 tablolarının ortak başlığı.
const List<String> _tableHeader = [
  'Alan',
  'JSON',
  'Tip',
  'Null',
  'Varsayılan',
  'Validator',
  'Not',
];

/// §9.6'da tanımlı gömülü modeller (PLAN §9.1: "10 gömülü model").
const List<String> _embeddedModels = [
  'FcmTokenModel',
  'ClubSocialModel',
  'ClubAdvisorModel',
  'MembershipApplicantModel',
  'PostImageModel',
  'PollModel',
  'PollOptionModel',
  'NotificationRefsModel',
  'ActivityRefsModel',
  'ClubNotificationPrefsModel',
];

/// CD-41 sayaç–belge referans alanları.
const List<String> _counterRefFields = [
  'lastMembershipRef',
  'lastCommentRef',
  'lastRsvpRef',
  'lastPostRef',
];

final RegExp _identifier = RegExp(r'^[A-Za-z][A-Za-z0-9]*$');

/// §9.6 tablolarından bir satır: JSON anahtarı ve Dart tipi.
typedef _PlanField = ({String section, String json, String type});

/// PLAN §9.6'dan okunan her şey.
typedef _PlanSchema = ({
  List<_PlanField> fields,
  Set<String> baseKeys,
  Map<String, List<String>> embedded,
  int baseRowCount,
});

final String _plan = readRepoFile('docs/PLAN.md');

/// PLAN §9.6 bölümünün satırları (`### 9.6` – `### 9.7` arası).
List<String> _planSectionLines() {
  final lines = _plan.split('\n');
  final start = lines.indexWhere((l) => l.startsWith('### 9.6 '));
  final end = lines.indexWhere((l) => l.startsWith('### 9.7 '));
  if (start < 0 || end <= start) {
    throw StateError('PLAN §9.6 bölümü bulunamadı.');
  }
  return lines.sublist(start, end);
}

/// §9.2 `BaseFields` tablosundaki JSON anahtarları.
Set<String> _readBaseKeys() {
  final table = markdownTable(_plan, heading: '### 9.2 ');
  if (table.header.take(2).join('|') != 'Alan (Dart)|JSON') {
    throw StateError('PLAN §9.2 başlığı değişmiş: ${table.header}');
  }
  return {for (final row in table.rows) codeSpans(row[1]).single};
}

/// §9.6 metnindeki gömülü model tanımları: model adı → JSON anahtarları.
///
/// Tanım biçimi: `` `XModel` (`models/x_model.dart`[, gömülü]): `a` (…) ·
/// `b` (…) `` — anahtarlar satır başında ya da ` · ` ayracından sonra gelen,
/// hemen ardından parantez açılan kod parçalarıdır.
Map<String, List<String>> _readEmbeddedModels() {
  final definition = RegExp(
    r'^`(\w+Model)` \(`models/\w+\.dart`(?:, gömülü)?\): (.*)$',
  );
  final key = RegExp(r'(?:^| · )`(\w+)` \(');
  return {
    for (final line in _planSectionLines())
      if (definition.firstMatch(line) case final match?)
        match.group(1)!: [
          for (final k in key.allMatches(match.group(2)!)) k.group(1)!,
        ],
  };
}

/// §9.6'nın 18 tablosunu, §9.2 ortak alanlarını ve gömülü model tanımlarını
/// okur. Biçim beklenenden saparsa [StateError] fırlatır (sessizce eksik
/// küme dönmez).
_PlanSchema _readPlanSchema() {
  final fields = <_PlanField>[];
  var baseRowCount = 0;
  for (var i = 1; i <= _tableCount; i++) {
    final section = '9.6.$i';
    final table = markdownTable(_plan, heading: '#### $section ');
    if (table.header.join('|') != _tableHeader.join('|')) {
      throw StateError('PLAN §$section başlığı değişmiş: ${table.header}');
    }
    for (final row in table.rows) {
      final jsonCell = row[1];
      if (row[0].startsWith('BaseFields (5 alan)')) {
        baseRowCount++;
      } else if (jsonCell.startsWith('—')) {
        // Belge ID'si: JSON'a yazılmaz.
      } else if (codeSpans(jsonCell) case [
        final json,
      ] when jsonCell == '`$json`' && _identifier.hasMatch(json)) {
        fields.add((
          section: section,
          json: json,
          type: codeSpans(row[2]).single,
        ));
      } else {
        throw StateError('PLAN §$section satırı ayrıştırılamadı: $row');
      }
    }
  }
  return (
    fields: fields,
    baseKeys: _readBaseKeys(),
    embedded: _readEmbeddedModels(),
    baseRowCount: baseRowCount,
  );
}

/// PLAN'dan türetilen tekil (noktasız) JSON anahtarları: tablo satırları ∪
/// `BaseFields` ∪ gömülü model anahtarları.
Set<String> _planFlatKeys(_PlanSchema schema) => {
  for (final field in schema.fields) field.json,
  ...schema.baseKeys,
  for (final keys in schema.embedded.values) ...keys,
};

/// PLAN'dan türetilen noktalı yol sabitleri: ad → değer.
///
/// Tipi gömülü model (`XModel` / `XModel?`) olan her alan için
/// `<üst><Alt>` = `'üst.alt'`; tipi `Map<String, XModel>` olan alan için
/// `<üst>Prefix` = `'üst.'`. Liste alanlarının (`List<XModel>`) yolu yoktur.
Map<String, String> _planDottedPaths(_PlanSchema schema) {
  final paths = <String, String>{};
  for (final field in schema.fields) {
    final type = field.type;
    final bare = type.endsWith('?') ? type.substring(0, type.length - 1) : type;
    if (schema.embedded[bare] case final children?) {
      for (final child in children) {
        paths['${field.json}${_capitalize(child)}'] = '${field.json}.$child';
      }
    } else if (RegExp(r'^Map<String, (\w+Model)>$').firstMatch(bare)
        case final match?) {
      if (!schema.embedded.containsKey(match.group(1))) {
        throw StateError('Tanımsız gömülü model: $type');
      }
      paths['${field.json}Prefix'] = '${field.json}.';
    }
  }
  return paths;
}

String _capitalize(String value) =>
    '${value[0].toUpperCase()}${value.substring(1)}';

/// `firestore_fields.dart` içindeki `static const String` bildirimleri.
Map<String, String> _readSourceMembers() {
  final source = readRepoFile(
    'packages/gu_data/lib/src/constants/firestore_fields.dart',
  );
  final members = <String, String>{};
  for (final match in RegExp(
    r"^ {2}static const String (\w+) =\s*'([^']*)';",
    multiLine: true,
  ).allMatches(source)) {
    if (members.containsKey(match.group(1))) {
      throw StateError('Aynı ad iki kez bildirilmiş: ${match.group(1)}');
    }
    members[match.group(1)!] = match.group(2)!;
  }
  return members;
}

/// Noktasız sabitler (JSON anahtarları).
Map<String, String> get _flat => {
  for (final MapEntry(:key, :value) in _actual.entries)
    if (!value.contains('.')) key: value,
};

/// Noktalı yol sabitleri.
Map<String, String> get _dotted => {
  for (final MapEntry(:key, :value) in _actual.entries)
    if (value.contains('.')) key: value,
};

/// Demo veride olup üretim şemasında **olmayan** prototip anahtarları
/// (PLAN §9.12: atılır ya da başka alana/belgeye dönüştürülür).
const Set<String> _prototypeOnlyKeys = {
  'blocked', // → blocks/{uid}_{blockedId}
  'emailVerified', // → Auth emülatörü
  'global', // → custom claim superadmin
  'advisorId', // → advisor.userId
  'stale', // atılır
  'commentIds', // → commentCount
  'hidden', // → isHidden
  'deleted', // → isDeleted
  'votes', // → posts/{id}/votes/{uid}
  'reasons', // → şikayetçi başına belge
};

/// [value] içindeki tüm map anahtarlarını toplar. `settings.clubs` haritasının
/// anahtarları kulüp ID'sidir (alan adı değil) ve atlanır; değerleri gezilir.
void _collectKeys(Object? value, Set<String> into, {bool dynamicKeys = false}) {
  if (value is Map<String, Object?>) {
    for (final MapEntry(:key, value: child) in value.entries) {
      if (!dynamicKeys) into.add(key);
      _collectKeys(
        child,
        into,
        dynamicKeys: !dynamicKeys && key == FirestoreFields.clubs,
      );
    }
  } else if (value is List<Object?>) {
    for (final item in value) {
      _collectKeys(item, into);
    }
  }
}

void main() {
  final schema = _readPlanSchema();
  final planFlat = _planFlatKeys(schema);
  final planDotted = _planDottedPaths(schema);

  group('T-08 · FirestoreFields · PLAN §9.6 okuyucu', () {
    test('18 tablo okunur; BaseFields satırı 14 tabloda', () {
      expect({
        for (final f in schema.fields) f.section,
      }, hasLength(_tableCount));
      // BaseFields taşımayan dört belge (§9.2): votes, activity, settings,
      // announcementCounters.
      expect(schema.baseRowCount, _tableCount - 4);
    });

    test('§9.2 ortak alanları: 6 anahtar', () {
      expect(schema.baseKeys, {
        'createdAt',
        'updatedAt',
        'createdBy',
        'isDeleted',
        'deletedAt',
        'deletedBy',
      });
    });

    test('10 gömülü model tanımı okunur', () {
      expect(schema.embedded.keys, unorderedEquals(_embeddedModels));
      for (final MapEntry(key: model, value: keys) in schema.embedded.entries) {
        expect(keys, isNotEmpty, reason: model);
        expect(keys.toSet(), hasLength(keys.length), reason: model);
      }
    });

    test('gömülü model anahtarları PLAN metniyle birebir', () {
      expect(schema.embedded, {
        'FcmTokenModel': ['token', 'platform', 'updatedAt'],
        'ClubSocialModel': ['email', 'instagram', 'web'],
        'ClubAdvisorModel': ['name', 'title', 'userId'],
        'MembershipApplicantModel': [
          'name',
          'department',
          'year',
          'avatarSeed',
        ],
        'PostImageModel': ['path', 'w', 'h'],
        'PollModel': ['options', 'endsAt', 'showResultsAfterVote'],
        'PollOptionModel': ['id', 'text'],
        'NotificationRefsModel': [
          'clubId',
          'eventId',
          'postId',
          'applicantId',
          'reportId',
          'role',
          'textKey',
        ],
        'ActivityRefsModel': ['userId', 'eventId', 'postId', 'role'],
        'ClubNotificationPrefsModel': [
          'announcements',
          'events',
          'posts',
          'muted',
        ],
      });
    });

    test('tablo başına alan sayısı (belge ID ve BaseFields satırları hariç): '
        'toplam 163, tekil 125', () {
      final perSection = <String, int>{};
      for (final field in schema.fields) {
        perSection.update(field.section, (n) => n + 1, ifAbsent: () => 1);
      }

      expect(perSection, {
        '9.6.1': 12,
        '9.6.2': 4,
        '9.6.3': 25,
        '9.6.4': 13,
        '9.6.5': 2,
        '9.6.6': 17,
        '9.6.7': 2,
        '9.6.8': 7,
        '9.6.9': 24,
        '9.6.10': 9,
        '9.6.11': 4,
        '9.6.12': 10,
        '9.6.13': 5,
        '9.6.14': 12,
        '9.6.15': 2,
        '9.6.16': 4,
        '9.6.17': 6,
        '9.6.18': 5,
      });
      expect(schema.fields, hasLength(163));
      expect({for (final f in schema.fields) f.json}, hasLength(125));
    });
  });

  group('T-08 · FirestoreFields · PLAN §9.6 paritesi', () {
    test('tablolardaki her JSON anahtarı sabitlerde var', () {
      for (final field in schema.fields) {
        expect(
          _flat[field.json],
          field.json,
          reason: '§${field.section} `${field.json}`',
        );
      }
    });

    test('BaseFields anahtarlarının her biri sabitlerde var', () {
      for (final key in schema.baseKeys) {
        expect(_flat[key], key);
      }
    });

    test('gömülü model anahtarlarının her biri sabitlerde var', () {
      for (final MapEntry(key: model, value: keys) in schema.embedded.entries) {
        for (final key in keys) {
          expect(_flat[key], key, reason: '$model.$key');
        }
      }
    });

    test('noktasız sabit kümesi = PLAN anahtar kümesi (fazla/eksik yok)', () {
      expect(_flat.keys.toSet().difference(planFlat), isEmpty);
      expect(planFlat.difference(_flat.keys.toSet()), isEmpty);
      expect(_flat.keys.toSet(), planFlat);
    });

    test('tekil ad sayısı: tablolardan türeyen $_tableDerivedCount', () {
      expect(planFlat, hasLength(_tableDerivedCount));
      expect(_flat, hasLength(_tableDerivedCount));
    });

    test('PLAN §9.5 beyanı = tablolardan türeyen sayı', () {
      final declared = RegExp(
        r'Tekil ad sayısı: (\d+) \(§9\.6 tablolarından sayılmıştır',
      ).allMatches(_plan);

      expect(declared, hasLength(1));
      expect(int.parse(declared.single.group(1)!), planFlat.length);
      expect(int.parse(declared.single.group(1)!), _flat.length);
    });

    test('PLAN §4.2, §9.1 ve §9.11 aynı sayıyı beyan eder (tek sayı, dört '
        'yerde)', () {
      final declarations = [
        // §4.2 ağaç satırı.
        RegExp(r'her JSON anahtarı; (\d+) tekil ad — §9\.5'),
        // §9.1 dosya tablosu.
        RegExp(r'\(toplam (\d+) tekil ad, §9\.5;'),
        // §9.11 test tablosu.
        RegExp(r'\((\d+) tekil ad \+ noktalı yollar\)'),
      ];

      for (final pattern in declarations) {
        final matches = pattern.allMatches(_plan);

        expect(matches, hasLength(1), reason: pattern.pattern);
        expect(
          int.parse(matches.single.group(1)!),
          planFlat.length,
          reason: pattern.pattern,
        );
      }
      expect(_plan, isNot(contains('145 tekil ad')));
    });

    test('docs/plans/T-08.md kapsam satırı aynı sayıları taşır', () {
      final taskPlan = readRepoFile('docs/plans/T-08.md');
      final dotted = _actual.length - _flat.length;

      expect(
        taskPlan,
        contains(
          '`FirestoreFields` (${planFlat.length} tekil ad + $dotted noktalı '
          'yol)',
        ),
      );
    });

    test('CD-41 referans alanları dahil', () {
      for (final name in _counterRefFields) {
        expect(_flat[name], name);
        expect(planFlat, contains(name));
      }
    });

    test('belge ID alanları (uid, docId) sabit değildir; id yalnızca anket '
        'seçeneği anahtarıdır', () {
      expect(_actual.keys, isNot(contains('uid')));
      expect(_actual.keys, isNot(contains('docId')));
      expect(_actual.values, isNot(contains('uid')));
      expect(FirestoreFields.id, 'id');
      expect(schema.embedded['PollOptionModel'], contains('id'));
      expect(
        {for (final f in schema.fields) f.json},
        isNot(contains('id')),
        reason: 'hiçbir koleksiyon tablosunda `id` JSON anahtarı yok',
      );
    });
  });

  group('T-08 · FirestoreFields · noktalı yollar', () {
    test('PLAN §9.5 örnekleri birebir', () {
      expect(FirestoreFields.socialEmail, 'social.email');
      expect(FirestoreFields.pollEndsAt, 'poll.endsAt');
      expect(FirestoreFields.clubsPrefix, 'clubs.');
      expect(
        _plan,
        allOf(
          contains("`FirestoreFields.socialEmail = 'social.email'`"),
          contains("`FirestoreFields.pollEndsAt = 'poll.endsAt'`"),
          contains("`FirestoreFields.clubsPrefix = 'clubs.'`"),
        ),
      );
    });

    test('gömülü nesne tipli her alanın alt anahtarları için yol sabiti var '
        '(fazla/eksik yok)', () {
      expect(_dotted, planDotted);
    });

    test('21 alt alan yolu + 1 önek', () {
      expect(_dotted, hasLength(22));
      expect(_dotted.values.where((v) => v.endsWith('.')), ['clubs.']);
    });

    test('gömülü nesne taşıyan üst alanlar: social, advisor, applicant, poll, '
        'refs (+ clubs haritası)', () {
      expect(
        {for (final path in _dotted.values) path.split('.').first},
        {'social', 'advisor', 'applicant', 'poll', 'refs', 'clubs'},
      );
    });

    test('her yolun iki parçası da noktasız sabittir', () {
      for (final MapEntry(key: name, value: path) in _dotted.entries) {
        final parts = path.split('.');

        expect(parts, hasLength(2), reason: name);
        expect(_flat, contains(parts.first), reason: name);
        if (parts.last.isNotEmpty) {
          expect(_flat, contains(parts.last), reason: name);
        }
      }
    });

    test('yol sabitleri noktasız sabitlerden kurulabilir', () {
      expect(
        FirestoreFields.socialEmail,
        '${FirestoreFields.social}.${FirestoreFields.email}',
      );
      expect(
        FirestoreFields.advisorUserId,
        '${FirestoreFields.advisor}.${FirestoreFields.userId}',
      );
      expect(
        FirestoreFields.applicantAvatarSeed,
        '${FirestoreFields.applicant}.${FirestoreFields.avatarSeed}',
      );
      expect(
        FirestoreFields.pollShowResultsAfterVote,
        '${FirestoreFields.poll}.${FirestoreFields.showResultsAfterVote}',
      );
      expect(
        FirestoreFields.refsTextKey,
        '${FirestoreFields.refs}.${FirestoreFields.textKey}',
      );
      expect(FirestoreFields.clubsPrefix, '${FirestoreFields.clubs}.');
    });

    test('kulüp tercihi yolu önek + clubId + tercih anahtarı ile kurulur', () {
      const clubId = 'c07';

      expect(
        '${FirestoreFields.clubsPrefix}$clubId.${FirestoreFields.muted}',
        'clubs.c07.muted',
      );
      expect(
        schema.embedded['ClubNotificationPrefsModel'],
        [
          FirestoreFields.announcements,
          FirestoreFields.events,
          FirestoreFields.posts,
          FirestoreFields.muted,
        ],
      );
    });

    test('liste elemanı anahtarlarının noktalı yolu yoktur', () {
      for (final parent in ['fcmTokens', 'images', 'options', 'likes']) {
        expect(
          _dotted.values.where((path) => path.startsWith('$parent.')),
          isEmpty,
          reason: parent,
        );
      }
    });
  });

  group('T-08 · FirestoreFields · adlar ve değerler', () {
    test('toplam 166 sabit: 144 anahtar + 22 yol', () {
      expect(_actual, hasLength(166));
      expect(_flat.length + _dotted.length, _actual.length);
    });

    test('tüm değerler tekildir', () {
      expect(_actual.values.toSet(), hasLength(_actual.length));
    });

    test('noktasız sabitte Dart adı = JSON anahtarı (field_rename: none)', () {
      for (final MapEntry(key: name, value: json) in _flat.entries) {
        expect(json, name);
      }
    });

    test('her değer geçerli bir alan adıdır (ASCII, harfle başlar, ayrılmış '
        'ad değil)', () {
      for (final MapEntry(key: name, value: json) in _flat.entries) {
        expect(json, matches(_identifier), reason: name);
        expect(json, matches(RegExp('^[a-z]')), reason: name);
        expect(json, isNot(startsWith('__')), reason: name);
      }
      for (final MapEntry(key: name, value: path) in _dotted.entries) {
        expect(
          path,
          matches(RegExp(r'^[a-z][A-Za-z]*\.(?:[a-z][A-Za-z]*)?$')),
          reason: name,
        );
      }
    });

    test('ad sözlüğündeki yasak eş adlar yok', () {
      // PLAN §9.1 ad sözlüğü ve §9.12: prototip adları üretim şemasında yok.
      for (final name in [..._prototypeOnlyKeys, 'docId', 'uid', 'memberIds']) {
        expect(_actual.keys, isNot(contains(name)), reason: name);
      }
    });
  });

  group('T-08 · FirestoreFields · kaynak dosya', () {
    test('kaynak üyeleri = test tablosu (ad + değer; fazla/eksik yok)', () {
      expect(_readSourceMembers(), _actual);
    });

    test('kaynak sırası: önce 144 anahtar, sonra 22 yol', () {
      final values = _readSourceMembers().values.toList();
      final firstDotted = values.indexWhere((v) => v.contains('.'));

      expect(firstDotted, _tableDerivedCount);
      expect(values.skip(firstDotted), everyElement(contains('.')));
    });

    test('kaynak dosyada static const String dışında üye yok', () {
      final source = readRepoFile(
        'packages/gu_data/lib/src/constants/firestore_fields.dart',
      );
      final memberLines = source
          .substring(source.indexOf('abstract final class FirestoreFields {'))
          .split('\n')
          .where((line) => RegExp('^ {2}[A-Za-z_@]').hasMatch(line));

      expect(memberLines, hasLength(_actual.length));
      expect(memberLines, everyElement(startsWith('  static const String ')));
    });

    test('her sabitin belge yorumu var', () {
      final lines = readRepoFile(
        'packages/gu_data/lib/src/constants/firestore_fields.dart',
      ).split('\n');

      for (var i = 0; i < lines.length; i++) {
        if (lines[i].startsWith('  static const String ')) {
          expect(lines[i - 1], startsWith('  ///'), reason: lines[i]);
        }
      }
    });
  });

  group('T-08 · FirestoreFields · diğer belgelerle uyum', () {
    test('soft-delete.md §3 affectedKeys anahtarları sabittir', () {
      final match = RegExp(
        r'affectedKeys = \{([^}]*)\}',
      ).firstMatch(readRepoFile('docs/soft-delete.md'))!;
      final keys = [
        for (final k in RegExp(r"'(\w+)'").allMatches(match.group(1)!))
          k.group(1)!,
      ];

      expect(keys, [
        FirestoreFields.isDeleted,
        FirestoreFields.deletedAt,
        FirestoreFields.deletedBy,
        FirestoreFields.updatedAt,
      ]);
    });

    test('domain-model §2 tablolarındaki her alan adı sabittir', () {
      final domainModel = readRepoFile('docs/domain-model.md');
      final names = <String>{};
      for (final heading in ['### 2.1 ', '### 2.3 ', '### 2.4 ', '### 2.7 ']) {
        final table = markdownTable(domainModel, heading: heading);
        for (final row in table.rows) {
          for (final span in codeSpans(row.first)) {
            final name = span.endsWith('?')
                ? span.substring(0, span.length - 1)
                : span;
            if (name != 'BaseFields') names.add(name);
          }
        }
      }

      expect(names.length, greaterThan(60));
      expect(names.difference(_flat.keys.toSet()), isEmpty);
    });

    test('Rules taslağı §3.3 kulüp güncelleme alan listeleri sabittir', () {
      final line = readRepoFile('docs/firestore-rules-spec.md')
          .split('\n')
          .singleWhere(
            (l) => l.startsWith('- **U (yönetim `board|president`)'),
          );
      final lists = [
        for (final span in codeSpans(line))
          if (span.contains(', ')) span.split(', '),
      ];

      expect(lists, hasLength(2));
      expect(lists.first, hasLength(13));
      expect(lists.last, hasLength(7));
      for (final name in lists.expand((list) => list)) {
        expect(_flat[name], name);
      }
    });

    test('demo verideki her anahtar ya sabittir ya da §9.12 prototip '
        'anahtarıdır', () {
      final demo = readRepoJson('tool/seed/demo-data.json');
      final keys = <String>{};
      for (final collection in [
        'users',
        'clubs',
        'memberships',
        'posts',
        'comments',
        'events',
        'rsvps',
        'notifications',
        'reports',
        'activity',
        'settings',
      ]) {
        final docs = demo[collection];
        final values = docs is Map<String, Object?> ? docs.values : docs;
        for (final doc in values! as Iterable<Object?>) {
          _collectKeys(doc, keys);
        }
      }
      final unknown = keys.where(
        (key) =>
            !_flat.containsKey(key) &&
            !_prototypeOnlyKeys.contains(key) &&
            !key.endsWith('_rel_days'),
      );

      expect(keys.length, greaterThan(100));
      expect(unknown, isEmpty);
      expect(
        _prototypeOnlyKeys.difference(keys),
        isEmpty,
        reason: 'istisna listesinde demo veride olmayan anahtar var',
      );
    });
  });

  group('T-08 · FirestoreFields · sabit kullanım', () {
    test('sabitler const bağlamda kullanılabilir', () {
      const payload = <String, Object?>{
        FirestoreFields.isDeleted: false,
        FirestoreFields.deletedAt: null,
        FirestoreFields.deletedBy: null,
      };
      const keys = {FirestoreFields.memberCount, FirestoreFields.updatedAt};

      expect(payload.keys, ['isDeleted', 'deletedAt', 'deletedBy']);
      expect(keys, {'memberCount', 'updatedAt'});
    });

    test('PLAN §9.5 örnek sabitleri', () {
      expect(FirestoreFields.isDeleted, 'isDeleted');
      expect(FirestoreFields.memberCount, 'memberCount');
    });
  });
}

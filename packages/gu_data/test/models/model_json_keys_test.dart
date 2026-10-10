// T-09 · JSON anahtar paritesi (PLAN §9.5, §9.11): her modelin `toJson()`
// anahtarları `FirestoreFields` içindedir; 28 modelin anahtar birleşimi
// `FirestoreFields`'in noktasız 144 adına eşittir (fazla / eksik = kırmızı) ve
// her noktalı yol gerçek bir gömülü anahtarı gösterir. Model listesi
// `lib/src/models/` kaynak dosyalarından doğrulanır: yeni model buraya
// eklenmeden geçmez.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../helpers/repo_sources.dart';

final DateTime _at = DateTime.utc(2026, 10, 8, 12);

const ClubSocialModel _social = ClubSocialModel(
  email: 'yazilim@gumushane.edu.tr',
  instagram: '@guk_yazilim',
  web: 'https://kulupler.gumushane.edu.tr/yazilim',
);
const ClubAdvisorModel _advisor = ClubAdvisorModel(
  name: 'Zeynep Arslan',
  title: 'Dr. Öğr. Üyesi',
  userId: 'u_zeynep',
);
const MembershipApplicantModel _applicant = MembershipApplicantModel(
  name: 'Ayşe Demir',
  avatarSeed: 'u_ayse',
  department: 'd01',
  year: YearLevel.first,
);
const PostImageModel _image = PostImageModel(
  path: 'posts/p02/20260930T050000Z_3f9a1c2b7d4e5f60.png',
  w: 1200,
  h: 900,
);
const PollOptionModel _option = PollOptionModel(id: 'o1', text: 'Evet');
final PollModel _poll = PollModel(options: const [_option], endsAt: _at);
const NotificationRefsModel _notificationRefs = NotificationRefsModel(
  clubId: 'c01',
  eventId: 'e01',
  postId: 'p01',
  applicantId: 'u_ayse',
  reportId: 'r01',
  role: ClubRole.board,
  textKey: 'welcome',
);
const ActivityRefsModel _activityRefs = ActivityRefsModel(
  userId: 'u_ayse',
  eventId: 'e01',
  postId: 'p01',
  role: ClubRole.board,
);
const ClubNotificationPrefsModel _clubPrefs = ClubNotificationPrefsModel();
final FcmTokenModel _fcmToken = FcmTokenModel(
  token: 'jeton',
  platform: 'ios',
  updatedAt: _at,
);

/// Sınıf adı → null olabilen **her** alanı dolu örneğin `toJson()` çıktısı
/// (`include_if_null: false` null alanı yazmaz; anahtar görünsün diye dolu).
final Map<String, Map<String, Object?>> _fullJson = {
  'ActivityModel': ActivityModel(
    id: 'a1',
    clubId: 'c01',
    actorId: 'u_p_c01',
    kind: ActivityKind.roleChanged,
    refs: _activityRefs,
    createdAt: _at,
  ).toJson(),
  'ActivityRefsModel': _activityRefs.toJson(),
  'BlockModel': BlockModel(
    blockerId: 'u_mehmet',
    blockedId: 'u042',
    createdAt: _at,
    updatedAt: _at,
    isDeleted: true,
    deletedAt: _at,
    deletedBy: 'u_mehmet',
  ).toJson(),
  'ClubAdvisorModel': _advisor.toJson(),
  'ClubModel': ClubModel(
    id: 'c01',
    name: 'Yazılım Topluluğu',
    nameLower: 'yazılım topluluğu',
    categoryId: 'k01',
    iconName: 'code-xml',
    palette: ClubPalette.red,
    pattern: ClubPattern.mountain,
    founded: 2015,
    presidentId: 'u_p_c01',
    coverSeed: 'club-c01',
    logoPath: 'clubs/c01/20261008T201501Z_3f9a1c2b7d4e5f60.jpg',
    coverPath: 'clubs/c01/20261008T201502Z_3f9a1c2b7d4e5f61.jpg',
    memberCount: 80,
    summary: 'Özet',
    about: 'Hakkında',
    conditions: const ['Aktif öğrenci olmak'],
    social: _social,
    pinnedPostId: 'p01',
    advisor: _advisor,
    status: ClubStatus.suspended,
    suspendReason: 'Neden',
    lastMembershipRef: 'memberships/c01_u_ayse',
    createdBy: 'u_admin',
    createdAt: _at,
    updatedAt: _at,
    isDeleted: true,
    deletedAt: _at,
    deletedBy: 'u_admin',
  ).toJson(),
  'ClubNotificationPrefsModel': _clubPrefs.toJson(),
  'ClubSocialModel': _social.toJson(),
  'CommentModel': CommentModel(
    id: 'cm01',
    postId: 'p01',
    clubId: 'c01',
    authorId: 'u_ayse',
    text: 'Yorum',
    isHidden: true,
    hiddenBy: 'u_admin',
    hiddenAt: _at,
    createdAt: _at,
    updatedAt: _at,
    isDeleted: true,
    deletedAt: _at,
    deletedBy: 'u_ayse',
  ).toJson(),
  'CounterModel': CounterModel(
    clubId: 'c01',
    day: '2026-10-08',
    count: 1,
    lastPostRef: 'posts/p01',
    updatedAt: _at,
  ).toJson(),
  'EventModel': EventModel(
    id: 'e01',
    clubId: 'c01',
    title: 'Atölye',
    type: EventType.training,
    startsAt: _at,
    endsAt: _at,
    coverPalette: ClubPalette.red,
    coverPattern: ClubPattern.lines,
    createdBy: 'u_p_c01',
    desc: 'Açıklama',
    placeId: 'pl04',
    placeText: 'B Blok 204',
    capacity: 40,
    status: EventStatus.cancelled,
    cancelReason: 'Neden',
    coverSeed: 'event-e01',
    coverPath: 'events/e01/20261008T201501Z_3f9a1c2b7d4e5f60.jpg',
    lastRsvpRef: 'rsvps/e01_u_ayse',
    publishedAt: _at,
    createdAt: _at,
    updatedAt: _at,
    isDeleted: true,
    deletedAt: _at,
    deletedBy: 'u_p_c01',
  ).toJson(),
  'FcmTokenModel': _fcmToken.toJson(),
  'MembershipApplicantModel': _applicant.toJson(),
  'MembershipContactModel': MembershipContactModel(
    email: 'ayse.demir@ogr.gumushane.edu.tr',
    emailLower: 'ayse.demir@ogr.gumushane.edu.tr',
    createdAt: _at,
    updatedAt: _at,
    isDeleted: true,
    deletedAt: _at,
    deletedBy: 'u_ayse',
  ).toJson(),
  'MembershipModel': MembershipModel(
    clubId: 'c01',
    userId: 'u_ayse',
    applicant: _applicant,
    status: MembershipStatus.rejected,
    note: 'Not',
    appliedAt: _at,
    decidedAt: _at,
    decidedBy: 'u_p_c01',
    retryAfter: _at,
    rejectReason: RejectReason.quota,
    rejectNote: 'Kontenjan doldu',
    priorCount: 1,
    createdAt: _at,
    updatedAt: _at,
    isDeleted: true,
    deletedAt: _at,
    deletedBy: 'u_ayse',
  ).toJson(),
  'NotificationModel': NotificationModel(
    id: 'n001',
    userId: 'u_ayse',
    type: NotificationType.roleChanged,
    refs: _notificationRefs,
    read: true,
    createdAt: _at,
    updatedAt: _at,
    isDeleted: true,
    deletedAt: _at,
    deletedBy: 'u_ayse',
  ).toJson(),
  'NotificationRefsModel': _notificationRefs.toJson(),
  'PollModel': _poll.toJson(),
  'PollOptionModel': _option.toJson(),
  'PostImageModel': _image.toJson(),
  'PostModel': PostModel(
    id: 'p01',
    clubId: 'c01',
    authorId: 'u_p_c01',
    text: 'Metin',
    type: PostType.poll,
    title: 'Başlık',
    images: const [_image],
    poll: _poll,
    pinned: true,
    pushSent: true,
    likes: const ['u_ayse'],
    likeCount: 1,
    commentCount: 1,
    lastCommentRef: 'comments/cm01',
    isHidden: true,
    hiddenBy: 'u_admin',
    hiddenAt: _at,
    editedAt: _at,
    createdAt: _at,
    updatedAt: _at,
    isDeleted: true,
    deletedAt: _at,
    deletedBy: 'u_p_c01',
  ).toJson(),
  'ReportModel': ReportModel(
    targetType: ReportTargetType.post,
    targetId: 'p17',
    reporterId: 'u051',
    reason: ReportReason.spam,
    targetClubId: 'c02',
    note: 'Not',
    status: ReportStatus.resolved,
    action: ReportAction.removed,
    resolvedAt: _at,
    resolvedBy: 'u_admin',
    createdAt: _at,
    updatedAt: _at,
    isDeleted: true,
    deletedAt: _at,
    deletedBy: 'u_admin',
  ).toJson(),
  'RsvpModel': RsvpModel(
    eventId: 'e01',
    clubId: 'c01',
    userId: 'u_ayse',
    ticketCode: 'GU-CWV4-JMW9',
    status: RsvpStatus.attended,
    reminder: ReminderOption.oneHour,
    waitlistAt: _at,
    scannedAt: _at,
    scannedBy: 'u_p_c01',
    createdAt: _at,
    updatedAt: _at,
    isDeleted: true,
    deletedAt: _at,
    deletedBy: 'u_ayse',
  ).toJson(),
  'SavedPostModel': SavedPostModel(
    userId: 'u_mehmet',
    postId: 'p01',
    clubId: 'c01',
    savedAt: _at,
    createdAt: _at,
    updatedAt: _at,
    isDeleted: true,
    deletedAt: _at,
    deletedBy: 'u_mehmet',
  ).toJson(),
  'SupportTicketModel': SupportTicketModel(
    id: 't1',
    ticketNo: 'GU-7K3Q9X',
    userId: 'u_ayse',
    subject: SupportSubject.bug,
    message: 'Mesaj',
    attachmentPaths: const [
      'support/GU-7K3Q9X/20261008T201501Z_3f9a1c2b7d4e5f60.jpg',
    ],
    status: TicketStatus.closed,
    createdAt: _at,
    updatedAt: _at,
    isDeleted: true,
    deletedAt: _at,
    deletedBy: 'u_ayse',
  ).toJson(),
  'UserAccountModel': UserAccountModel(
    email: 'ayse.demir@ogr.gumushane.edu.tr',
    emailLower: 'ayse.demir@ogr.gumushane.edu.tr',
    fcmTokens: [_fcmToken],
    lastLoginAt: _at,
    createdAt: _at,
    updatedAt: _at,
    isDeleted: true,
    deletedAt: _at,
    deletedBy: 'u_ayse',
  ).toJson(),
  'UserModel': UserModel(
    uid: 'u_ayse',
    name: 'Ayşe Demir',
    nameLower: 'ayşe demir',
    avatarSeed: 'u_ayse',
    avatarPath: 'users/u_ayse/20261008T201501Z_3f9a1c2b7d4e5f60.jpg',
    department: 'd01',
    year: YearLevel.first,
    interests: const ['i01'],
    bio: 'Bio',
    status: UserStatus.suspended,
    suspendReason: 'Neden',
    staff: true,
    profileComplete: true,
    createdAt: _at,
    updatedAt: _at,
    isDeleted: true,
    deletedAt: _at,
    deletedBy: 'u_ayse',
  ).toJson(),
  'UserSettingsModel': UserSettingsModel(
    uid: 'u_ayse',
    clubs: const {'c07': _clubPrefs},
    updatedAt: _at,
  ).toJson(),
  'VoteModel': VoteModel(
    uid: 'u_ayse',
    optionId: 'o1',
    createdAt: _at,
  ).toJson(),
};

/// `FirestoreFields` sabit değerleri (kaynak dosyadan).
final List<String> _fieldValues = [
  for (final match
      in RegExp(
        r"^\s+static const String \w+ = '([^']+)';$",
        multiLine: true,
      ).allMatches(
        readRepoFile(
          'packages/gu_data/lib/src/constants/firestore_fields.dart',
        ),
      ))
    match.group(1)!,
];

/// Noktasız adlar: belge ve gömülü model JSON anahtarları.
final Set<String> _plainNames = {
  for (final value in _fieldValues)
    if (!value.contains('.')) value,
};

/// Noktalı yollar (`social.email` …; `clubs.` öneki dahil).
final Set<String> _dottedPaths = {
  for (final value in _fieldValues)
    if (value.contains('.')) value,
};

void main() {
  group('T-09 · model JSON anahtarları ↔ FirestoreFields', () {
    test('liste lib/src/models altındaki 28 model sınıfının tamamıdır', () {
      final declared = <String>[
        for (final file
            in Directory('$repoRoot/packages/gu_data/lib/src/models')
                .listSync()
                .whereType<File>()
                .where((file) => file.path.endsWith('_model.dart')))
          for (final match in RegExp(
            r'^final class (\w+Model) ',
            multiLine: true,
          ).allMatches(file.readAsStringSync()))
            match.group(1)!,
      ]..sort();

      expect(declared, hasLength(28));
      expect(_fullJson.keys.toList()..sort(), declared);
    });

    test('FirestoreFields: 144 noktasız ad + 22 noktalı yol', () {
      expect(_fieldValues.toSet(), hasLength(_fieldValues.length));
      expect(_plainNames, hasLength(144));
      expect(_dottedPaths, hasLength(22));
    });

    for (final MapEntry(key: model, value: json) in _fullJson.entries) {
      test('$model: toJson anahtarları FirestoreFields içinde', () {
        expect(json, isNotEmpty);
        expect(json.keys.toSet().difference(_plainNames), isEmpty);
      });
    }

    test('tüm modellerin anahtar birleşimi = FirestoreFields noktasız adları '
        '(fazla / eksik yok)', () {
      final union = {for (final json in _fullJson.values) ...json.keys};

      expect(_plainNames.difference(union), isEmpty, reason: 'kullanılmayan');
      expect(union.difference(_plainNames), isEmpty, reason: 'tanımsız');
    });

    test('her noktalı yol bir modelin gömülü map anahtarını gösterir; '
        'clubs. öneki ayar haritasının önekidir', () {
      final unresolved = <String>[];
      for (final path in _dottedPaths.difference({
        FirestoreFields.clubsPrefix,
      })) {
        final [parent, child] = path.split('.');
        final found = _fullJson.values.any(
          (json) => switch (json[parent]) {
            final Map<String, Object?> nested => nested.containsKey(child),
            _ => false,
          },
        );
        if (!found) unresolved.add(path);
      }

      expect(unresolved, isEmpty);
      expect(FirestoreFields.clubsPrefix, '${FirestoreFields.clubs}.');
      expect(
        _fullJson['UserSettingsModel']![FirestoreFields.clubs],
        isA<Map<String, Object?>>(),
      );
    });

    test(
      'belge kimliği hiçbir modelin JSON çıktısına girmez (id yalnızca anket '
      'seçeneğinin kendi alanıdır)',
      () {
        expect(
          [
            for (final MapEntry(key: model, value: json) in _fullJson.entries)
              if (json.containsKey(FirestoreFields.id)) model,
          ],
          ['PollOptionModel'],
        );
        expect(
          _fullJson.values.where((json) => json.containsKey('uid')),
          isEmpty,
        );
      },
    );
  });
}

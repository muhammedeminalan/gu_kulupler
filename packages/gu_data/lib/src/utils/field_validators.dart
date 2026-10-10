import 'package:gu_data/src/constants/firestore_ids.dart';
import 'package:gu_data/src/constants/limits.dart';
import 'package:gu_data/src/constants/static_tables.dart';
import 'package:gu_data/src/core/app_clock.dart';
import 'package:gu_data/src/models/enums/membership_status.dart';
import 'package:gu_data/src/models/enums/post_type.dart';
import 'package:gu_data/src/models/enums/reject_reason.dart';
import 'package:gu_data/src/models/enums/reminder_option.dart';
import 'package:gu_data/src/models/enums/report_target_type.dart';
import 'package:gu_data/src/utils/email_domain_validator.dart';

/// Bir alan değerinin neden geçersiz olduğu (PLAN §9.1).
///
/// Kullanıcıya gösterilecek metin uygulama katmanında seçilir (ARB); bu enum
/// yalnızca hatanın türünü taşır.
enum FieldError {
  /// Zorunlu değer yok: boş (ya da yalnızca boşluk) metin, boş liste, eksik
  /// alan.
  empty,

  /// Alt sınırın altında: çok kısa metin ya da çok az öğe.
  tooShort,

  /// Üst sınırın üstünde: çok uzun metin ya da çok fazla öğe.
  tooLong,

  /// Biçim bozuk, değer bilinen tabloda yok ya da başka bir alanla tutarsız.
  invalidFormat,

  /// Sayı, an ya da seçenek izinli aralığın / kümenin dışında.
  outOfRange,
}

/// Alan doğrulayıcıları — PLAN §9.6 tablolarının "Validator" sütunu (PLAN
/// §9.1).
///
/// ViewModel formları ve repository ön koşulları doğrulamayı **yalnızca
/// buradan** çağırır; modeller kendini doğrulamaz (okunan belge hoşgörüyle
/// ayrışır). Her kural tek statik fonksiyondur: geçerliyse `null`, değilse
/// ilk [FieldError] döner. Sınırlar `Limits`, tablolar `StaticTables`,
/// desenler `FirestoreIds` / `Limits` kaynaklıdır; Security Rules aynı
/// sayıları uygular — burada geçen değer Rules'ta da geçer.
///
/// Metin uzunluğu Rules `size()` ile her yorumda uyumlu olsun diye temkinli
/// ölçülür: üst sınır UTF-16 birimiyle (`String.length`), alt sınır kod
/// noktasıyla (`runes`). Girdi kırpılmaz; yalnızca boşluktan oluşan zorunlu
/// metin [FieldError.empty] sayılır.
///
/// Burada **olmayan** sütun girdileri (CD-130): enum üyeliği (tip sistemi),
/// Storage yolları (`StoragePaths.is…`, T-10), sunucu zamanı alanları,
/// belgeler arası eşitlikler (`clubId == post.clubId`, `applicant.name` —
/// repository kaynak belgeden kurar), durum geçişleri (repository geçiş
/// tabloları) ve sayaç değişmezleri (delta yazımıyla sağlanır).
abstract final class FieldValidators {
  // ── Ortak ────────────────────────────────────────────────────────────

  /// "Boş değil" kuralı: belge kimliği parçaları (`clubId`, `userId`,
  /// `postId`, `eventId`, `authorId`, `reporterId` …), `avatarSeed`,
  /// `coverSeed`, `iconName`, `presidentId`.
  ///
  /// `FirestoreIds` üreticileri saf birleştirmedir; boş parçayla `_u1` gibi
  /// kimlik üretmemek için parçalar önce bununla denetlenir.
  static FieldError? requiredId(String value) =>
      value.isEmpty ? FieldError.empty : null;

  /// Sayaç alanları (`memberCount`, `goingCount`, `waitlistCount`,
  /// `attendedCount`, `commentCount`, `priorCount`): `≥ 0`.
  static FieldError? counter(int value) =>
      value < 0 ? FieldError.outOfRange : null;

  /// Yönetici gerekçesi: `users.suspendReason`, `clubs.suspendReason`,
  /// `events.cancelReason` (1 – `Limits.adminReasonMax`).
  static FieldError? adminReason(String value) =>
      _text(value, min: 1, max: Limits.adminReasonMax);

  // ── users · private/account · private/contact ────────────────────────

  /// `users.name`, `clubs.advisor.name` (`Limits.nameMin` –
  /// `Limits.nameMax`).
  static FieldError? name(String value) =>
      _text(value, min: Limits.nameMin, max: Limits.nameMax);

  /// `users.nameLower` (2 – 60). `name` ile eşitliğe bakmaz: değeri çağıran
  /// `trLower()` ile üretir (CD-11).
  static FieldError? nameLower(String value) =>
      _text(value, min: Limits.nameMin, max: Limits.nameMax);

  /// `users.bio` (≤ `Limits.bioMax`).
  static FieldError? bio(String value) => _text(value, max: Limits.bioMax);

  /// `users.department`: `StaticTables.departmentIds` içinde.
  static FieldError? department(String id) => _known(
    id,
    StaticTables.departmentIds,
  );

  /// `users.interests`: her öğe `StaticTables.interestIds` içinde, tekrarsız,
  /// `Limits.interestsMin` – `Limits.interestsMax` adet. Personelde
  /// ([staff]) boş liste serbesttir.
  static FieldError? interests(List<String> ids, {bool staff = false}) {
    if (ids.isEmpty && staff) return null;
    if (ids.length < Limits.interestsMin) {
      return ids.isEmpty ? FieldError.empty : FieldError.tooShort;
    }
    if (ids.length > Limits.interestsMax) return FieldError.tooLong;
    if (ids.toSet().length != ids.length) return FieldError.invalidFormat;
    return ids.every(StaticTables.interestIds.contains)
        ? null
        : FieldError.invalidFormat;
  }

  /// Üniversite e-postası (`account.email`, `contact.email`; D-27): biçim
  /// bozuksa [FieldError.invalidFormat], alan adı izinli listede değilse
  /// [FieldError.outOfRange].
  static FieldError? universityEmail(String value) {
    if (value.isEmpty) return FieldError.empty;
    if (!EmailDomainValidator.isWellFormed(value)) {
      return FieldError.invalidFormat;
    }
    return EmailDomainValidator.isAllowedDomain(value)
        ? null
        : FieldError.outOfRange;
  }

  /// `emailLower == email.toLowerCase()` (ASCII küçültme).
  static FieldError? emailLower(String emailLower, {required String email}) =>
      emailLower == email.toLowerCase() ? null : FieldError.invalidFormat;

  /// `account.fcmTokens` uzunluğu (≤ `Limits.fcmTokensMax`).
  static FieldError? fcmTokenCount(int count) =>
      count > Limits.fcmTokensMax ? FieldError.tooLong : null;

  /// `fcmTokens[].platform`: `Limits.platforms` içinde.
  static FieldError? platform(String value) => _known(value, Limits.platforms);

  // ── clubs ────────────────────────────────────────────────────────────

  /// `clubs.name` (1 – `Limits.clubNameMax`).
  static FieldError? clubName(String value) =>
      _text(value, min: 1, max: Limits.clubNameMax);

  /// `clubs.nameLower` (2 – `Limits.clubNameMax`; Rules `size() in 2..60`).
  static FieldError? clubNameLower(String value) =>
      _text(value, min: Limits.nameMin, max: Limits.clubNameMax);

  /// `clubs.categoryId`: `StaticTables.categoryIds` içinde.
  static FieldError? categoryId(String id) => _known(
    id,
    StaticTables.categoryIds,
  );

  /// `clubs.founded`: `Limits.foundedMin` ≤ yıl ≤ `Limits.foundedMax(clock)`.
  static FieldError? founded(int year, AppClock clock) =>
      year < Limits.foundedMin || year > Limits.foundedMax(clock)
      ? FieldError.outOfRange
      : null;

  /// `clubs.summary` (≤ `Limits.clubSummaryMax`).
  static FieldError? clubSummary(String value) =>
      _text(value, max: Limits.clubSummaryMax);

  /// `clubs.about` (≤ `Limits.clubAboutMax`).
  static FieldError? clubAbout(String value) =>
      _text(value, max: Limits.clubAboutMax);

  /// `clubs.conditions`: en çok `Limits.conditionsMax` madde; her madde 1 –
  /// `Limits.conditionTextMax`.
  static FieldError? conditions(List<String> items) {
    if (items.length > Limits.conditionsMax) return FieldError.tooLong;
    return _firstError(
      items,
      (item) => _text(item, min: 1, max: Limits.conditionTextMax),
    );
  }

  /// `clubs.social.email`: biçimce geçerli adres (alan adı kısıtı yok).
  static FieldError? socialEmail(String value) =>
      EmailDomainValidator.isWellFormed(value)
      ? null
      : FieldError.invalidFormat;

  /// `clubs.social.instagram`: `Limits.instagramHandlePattern`.
  static FieldError? instagram(String value) => _matches(value, _instagram);

  /// `clubs.social.web`: `http` / `https` şemalı, alan adı dolu URL.
  static FieldError? web(String value) {
    final uri = Uri.tryParse(value);
    final ok =
        uri != null && _webSchemes.contains(uri.scheme) && uri.host.isNotEmpty;
    return ok ? null : FieldError.invalidFormat;
  }

  // ── memberships ──────────────────────────────────────────────────────

  /// `memberships.note` (≤ `Limits.applicationNoteMax`); kulüp not istiyorsa
  /// ([requireNote]) boş olamaz.
  static FieldError? applicationNote(
    String value, {
    required bool requireNote,
  }) => _text(
    value,
    min: requireNote ? 1 : 0,
    max: Limits.applicationNoteMax,
  );

  /// `memberships.rejectNote` (≤ `Limits.rejectNoteMax`).
  static FieldError? rejectNote(String value) =>
      _text(value, max: Limits.rejectNoteMax);

  /// `memberships.rejectReason`: `rejected` ⇒ dolu; `removed` ⇒ `other`
  /// (M9).
  static FieldError? rejectReason(
    RejectReason? reason, {
    required MembershipStatus status,
  }) => switch (status) {
    MembershipStatus.rejected when reason == null => FieldError.empty,
    MembershipStatus.removed when reason != RejectReason.other =>
      FieldError.outOfRange,
    _ => null,
  };

  // ── posts · comments ─────────────────────────────────────────────────

  /// `posts.text` (1 – `Limits.postTextMax`); anket sorusu da bu alandadır.
  static FieldError? postText(String value) =>
      _text(value, min: 1, max: Limits.postTextMax);

  /// `posts.title`: duyuruda 1 – `Limits.postTitleMax`; diğer türlerde
  /// `null` olmalıdır.
  static FieldError? postTitle(String? value, {required PostType type}) {
    if (type != PostType.announcement) {
      return value == null ? null : FieldError.invalidFormat;
    }
    return _text(value ?? '', min: 1, max: Limits.postTitleMax);
  }

  /// `posts.images` uzunluğu (≤ `Limits.postImagesMax`).
  static FieldError? postImageCount(int count) =>
      count > Limits.postImagesMax ? FieldError.tooLong : null;

  /// `type == poll ⇔ poll != null`: anket gönderisinde anket eksikse
  /// [FieldError.empty], başka türde anket varsa [FieldError.invalidFormat].
  static FieldError? postPoll({
    required PostType type,
    required bool hasPoll,
  }) {
    if (type == PostType.poll) return hasPoll ? null : FieldError.empty;
    return hasPoll ? FieldError.invalidFormat : null;
  }

  /// `pushSent == true ⇒ type == announcement`.
  static FieldError? pushSent({
    required PostType type,
    required bool pushSent,
  }) => pushSent && type != PostType.announcement
      ? FieldError.invalidFormat
      : null;

  /// `poll.options` metinleri: `Limits.pollOptionsMin` –
  /// `Limits.pollOptionsMax` seçenek; her biri 1 –
  /// `Limits.pollOptionTextMax`.
  static FieldError? pollOptions(List<String> texts) {
    if (texts.isEmpty) return FieldError.empty;
    if (texts.length < Limits.pollOptionsMin) return FieldError.tooShort;
    if (texts.length > Limits.pollOptionsMax) return FieldError.tooLong;
    return _firstError(
      texts,
      (text) => _text(text, min: 1, max: Limits.pollOptionTextMax),
    );
  }

  /// Anket süresi (gün): `Limits.pollDurationsDays` içinde.
  static FieldError? pollDurationDays(int days) =>
      Limits.pollDurationsDays.contains(days) ? null : FieldError.outOfRange;

  /// `comments.text` (1 – `Limits.commentMax`).
  static FieldError? comment(String value) =>
      _text(value, min: 1, max: Limits.commentMax);

  // ── events · rsvps ───────────────────────────────────────────────────

  /// `events.title` (1 – `Limits.eventTitleMax`).
  static FieldError? eventTitle(String value) =>
      _text(value, min: 1, max: Limits.eventTitleMax);

  /// `events.desc` (≤ `Limits.eventDescMax`).
  static FieldError? eventDesc(String value) =>
      _text(value, max: Limits.eventDescMax);

  /// `events.placeId`: `StaticTables.placeIds` içinde.
  static FieldError? placeId(String id) => _known(id, StaticTables.placeIds);

  /// `events.placeText` (≤ `Limits.placeTextMax`).
  static FieldError? placeText(String value) =>
      _text(value, max: Limits.placeTextMax);

  /// `events.capacity`: `null` = sınırsız; doluysa `≥ 1` ve kayıtlı sayısının
  /// ([goingCount]) altına inemez.
  static FieldError? capacity(int? value, {int goingCount = 0}) =>
      value != null && (value < 1 || value < goingCount)
      ? FieldError.outOfRange
      : null;

  /// `events.endsAt > startsAt`.
  static FieldError? eventEnd(DateTime endsAt, {required DateTime startsAt}) =>
      endsAt.isAfter(startsAt) ? null : FieldError.outOfRange;

  /// Yayın koşulu: `events.startsAt > şimdi`.
  static FieldError? eventStart(DateTime startsAt, AppClock clock) =>
      startsAt.isAfter(clock.nowUtc()) ? null : FieldError.outOfRange;

  /// `rsvps.ticketCode`: `FirestoreIds.ticketCodePattern`.
  static FieldError? ticketCode(String value) => _matches(value, _ticketCode);

  // ── reports · blocks ─────────────────────────────────────────────────

  /// `reports.note` (≤ `Limits.reportNoteMax`).
  static FieldError? reportNote(String value) =>
      _text(value, max: Limits.reportNoteMax);

  /// Şikayet hedefi: [targetId] ve [reporterId] dolu; kullanıcı kendini
  /// şikayet edemez; `post/comment/club/event` hedefinde [targetClubId] dolu,
  /// `user` hedefinde `null` (CD-33).
  static FieldError? reportTarget({
    required ReportTargetType targetType,
    required String targetId,
    required String reporterId,
    required String? targetClubId,
  }) {
    if (targetId.isEmpty || reporterId.isEmpty) return FieldError.empty;
    if (targetType == ReportTargetType.user) {
      return targetId == reporterId || targetClubId != null
          ? FieldError.invalidFormat
          : null;
    }
    return targetClubId == null || targetClubId.isEmpty
        ? FieldError.empty
        : null;
  }

  /// Engelleme çifti: iki kimlik de dolu ve `blockedId != blockerId`.
  static FieldError? blockTarget({
    required String blockerId,
    required String blockedId,
  }) {
    if (blockerId.isEmpty || blockedId.isEmpty) return FieldError.empty;
    return blockerId == blockedId ? FieldError.invalidFormat : null;
  }

  // ── settings ─────────────────────────────────────────────────────────

  /// `settings.reminderTime`: yalnızca `oneHour` ve `oneDay` (CD-34; Rules
  /// `in ['1h', '1d']`). `rsvps.reminder` dört değeri de taşır, doğrulama
  /// gerektirmez.
  static FieldError? reminderTime(ReminderOption value) =>
      _settingsReminders.contains(value) ? null : FieldError.outOfRange;

  /// `settings.quietFrom` / `quietTo`: `HH:mm` (`Limits.timeOfDayPattern`).
  static FieldError? timeOfDay(String value) => _matches(value, _timeOfDay);

  // ── supportTickets ───────────────────────────────────────────────────

  /// `supportTickets.ticketNo`: `FirestoreIds.supportTicketNoPattern`.
  static FieldError? supportTicketNo(String value) =>
      _matches(value, _supportTicketNo);

  /// `supportTickets.message` (1 – `Limits.supportMessageMax`).
  static FieldError? supportMessage(String value) =>
      _text(value, min: 1, max: Limits.supportMessageMax);

  /// `supportTickets.attachmentPaths` uzunluğu
  /// (≤ `Limits.supportAttachmentsMax`).
  static FieldError? supportAttachmentCount(int count) =>
      count > Limits.supportAttachmentsMax ? FieldError.tooLong : null;

  // ── announcementCounters ─────────────────────────────────────────────

  /// `announcementCounters.day`: `yyyy-MM-dd` biçiminde ve bugünün Istanbul
  /// günü (`AppClock.istanbulDay`).
  static FieldError? announcementDay(String day, AppClock clock) {
    if (!_isoDay.hasMatch(day)) return FieldError.invalidFormat;
    return day == clock.istanbulDay(clock.nowUtc())
        ? null
        : FieldError.outOfRange;
  }

  /// `announcementCounters.count`: `0` – `Limits.announcementDailyLimit`.
  static FieldError? announcementCount(int count) =>
      count < 0 || count > Limits.announcementDailyLimit
      ? FieldError.outOfRange
      : null;

  // ── Yardımcılar ──────────────────────────────────────────────────────

  static FieldError? _text(String value, {required int max, int min = 0}) {
    if (min > 0 && value.trim().isEmpty) return FieldError.empty;
    if (value.runes.length < min) return FieldError.tooShort;
    return value.length > max ? FieldError.tooLong : null;
  }

  static FieldError? _matches(String value, RegExp pattern) =>
      pattern.hasMatch(value) ? null : FieldError.invalidFormat;

  static FieldError? _known(String id, Set<String> table) =>
      table.contains(id) ? null : FieldError.invalidFormat;

  static FieldError? _firstError(
    List<String> items,
    FieldError? Function(String item) validate,
  ) {
    for (final item in items) {
      final error = validate(item);
      if (error != null) return error;
    }
    return null;
  }

  static final RegExp _instagram = RegExp(Limits.instagramHandlePattern);
  static final RegExp _timeOfDay = RegExp(Limits.timeOfDayPattern);
  static final RegExp _isoDay = RegExp(Limits.isoDayPattern);
  static final RegExp _ticketCode = RegExp(FirestoreIds.ticketCodePattern);
  static final RegExp _supportTicketNo = RegExp(
    FirestoreIds.supportTicketNoPattern,
  );

  static const Set<String> _webSchemes = {'http', 'https'};
  static const Set<ReminderOption> _settingsReminders = {
    ReminderOption.oneHour,
    ReminderOption.oneDay,
  };
}

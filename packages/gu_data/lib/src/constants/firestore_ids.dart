import 'package:gu_data/src/constants/limits.dart';

/// Bileşik belge ID üreticileri ve biçim desenleri (PLAN §9.4, §10.3; D-25,
/// D-30).
///
/// Bileşik ID'ler yalnızca **üretilir**, parçalanarak okunmaz: kullanıcı
/// ID'leri `_` içerebilir (`u_p_c01`), bu yüzden `clubId`/`userId`,
/// `eventId`/`userId` her zaman belge alanlarından okunur — ters çözüm metodu
/// yoktur. Tek ayrıştırıcı [parseTicketQr]'dir (QR yükü dış girdidir).
///
/// Üreticiler saf dizge birleştirmedir; parçaların boş olmaması çağıranın
/// sorumluluğudur (`FieldValidators.requiredId`). Sabit belge adları
/// (`account`, `contact`) `FirestoreCollections` içindedir.
abstract final class FirestoreIds {
  // ── Bileşik belge ID'leri ────────────────────────────────────────────

  /// `memberships/{clubId}_{userId}`.
  static String membership(String clubId, String userId) =>
      '$clubId$_separator$userId';

  /// `rsvps/{eventId}_{userId}`.
  static String rsvp(String eventId, String userId) =>
      '$eventId$_separator$userId';

  /// `blocks/{blockerId}_{blockedId}`.
  static String block(String blockerId, String blockedId) =>
      '$blockerId$_separator$blockedId';

  /// `savedPosts/{userId}_{postId}`.
  static String savedPost(String userId, String postId) =>
      '$userId$_separator$postId';

  /// `reports/{reporterId}_{targetType}_{targetId}` — aynı kullanıcı aynı
  /// hedefi yalnızca bir kez şikayet edebilir. [targetType] enum'un JSON
  /// değeridir (`post`, `comment`, `user`, `club`, `event`).
  static String report(String reporterId, String targetType, String targetId) =>
      '$reporterId$_separator$targetType$_separator$targetId';

  /// `announcementCounters/{clubId}_{yyyyMMdd}` — [dayKey]
  /// `AppClock.istanbulDayKey` çıktısıdır.
  static String announcementCounter(String clubId, String dayKey) =>
      '$clubId$_separator$dayKey';

  /// `notifications/{type}_{refId}_{userId}` — deterministik ID; aynı
  /// bildirimin yeniden yazımı çift kayıt üretmez. [type] enum'un JSON
  /// değeri, [refId] türün ana referansıdır (PLAN §9.4).
  ///
  /// Saf birleştirmedir: aynı üçlü her zaman aynı kimliği verir. Bu yüzden
  /// [refId] **olay başına tekil** olmalıdır. Aynı (tür, referans, alıcı)
  /// ikinci kez oluşabiliyorsa (onayla → geri al → yeniden onayla, rol
  /// değişimi, yeniden başvuru …) çağıran [refId]'ye olayı ayırt eden bir parça
  /// ekler: var olan belgeye yazım Security Rules'ta güncelleme sayılır,
  /// güncelleme yalnızca bildirimin sahibine açıktır ve yazım — içinde olduğu
  /// batch ile birlikte — `permission-denied` alır.
  static String notification(String type, String refId, String userId) =>
      '$type$_separator$refId$_separator$userId';

  /// `posts/{postId}/votes/{uid}` — bir kullanıcı bir oy.
  static String vote(String uid) => uid;

  // ── Tohumlar ve gömülü ID'ler ────────────────────────────────────────

  /// `clubs.coverSeed` değeri: `club-{clubId}`.
  static String clubCoverSeed(String clubId) => 'club-$clubId';

  /// `events.coverSeed` değeri: `event-{eventId}`.
  static String eventCoverSeed(String eventId) => 'event-$eventId';

  /// `poll.options[].id` değeri: `o1`–`o4` ([index] sıfır tabanlı).
  ///
  /// [index] `0 ≤ index < Limits.pollOptionsMax` aralığında değilse
  /// [RangeError] fırlatır (`votes.optionId` yalnızca bu kümeden olabilir).
  static String pollOption(int index) {
    RangeError.checkValueInInterval(
      index,
      0,
      Limits.pollOptionsMax - 1,
      'index',
    );
    return 'o${index + 1}';
  }

  // ── Bilet kodu, destek numarası ve QR yükü ───────────────────────────

  /// Bilet kodu deseni (`rsvps.ticketCode`): `GU-XXXX-XXXX`, 32'lik alfabe
  /// (`I O 0 1` yok — `TicketCodeGenerator.alphabet`). `RegExp` kaynağıdır;
  /// Rules §3.8 ile aynı.
  static const String ticketCodePattern =
      r'^GU-[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}$';

  /// Destek talebi numarası deseni (`supportTickets.ticketNo`): `GU-XXXXXX`.
  /// `RegExp` kaynağıdır; Rules §3.15 ile aynı.
  static const String supportTicketNoPattern = r'^GU-[A-HJ-NP-Z2-9]{6}$';

  /// QR yükü sürüm öneki (D-30).
  static const String ticketQrVersion = 'v1';

  /// Bilet QR içeriği: `gu:ticket:v1:{eventId}:{code}` (D-30).
  ///
  /// Saf birleştirmedir; girdileri doğrulamaz. Yük imza taşımaz: doğrulama,
  /// etkinliğe kapsamlı Firestore aramasıyla yapılır.
  static String ticketQrPayload(String eventId, String code) =>
      '$_qrScheme$_qrSeparator$_qrKind$_qrSeparator$ticketQrVersion'
      '$_qrSeparator$eventId$_qrSeparator$code';

  /// Okutulan QR içeriğini ayrıştırır; geçerli değilse `null` döner.
  ///
  /// Yük **tam olarak** `gu:ticket:v1:{eventId}:{code}` biçiminde olmalıdır:
  /// beş `:` ile ayrılmış parça, sürüm [ticketQrVersion], `eventId` boş
  /// olmayan tek bir yol parçası (`:` ve `/` içermez) ve `code`
  /// [ticketCodePattern] ile eşleşir. Girdi kırpılmaz ve harf duyarlıdır;
  /// baştaki/sondaki boşluk, küçük harfli kod ya da başka sürüm `null`'dır.
  static ({String eventId, String code})? parseTicketQr(String payload) {
    final parts = payload.split(_qrSeparator);
    if (parts.length != _qrPartCount) return null;
    final [scheme, kind, version, eventId, code] = parts;
    if (scheme != _qrScheme || kind != _qrKind || version != ticketQrVersion) {
      return null;
    }
    if (eventId.isEmpty || eventId.contains(_pathSeparator)) return null;
    if (!_ticketCode.hasMatch(code)) return null;
    return (eventId: eventId, code: code);
  }

  static final RegExp _ticketCode = RegExp(ticketCodePattern);

  static const String _separator = '_';
  static const String _qrSeparator = ':';
  static const String _qrScheme = 'gu';
  static const String _qrKind = 'ticket';
  static const String _pathSeparator = '/';
  static const int _qrPartCount = 5;
}

import 'package:gu_data/src/core/app_clock.dart';

/// İş kuralı sınırları — planın **tek** sabit listesi (PLAN §9.8, CD-31).
///
/// Üye adları ve değerleri PLAN §9.8 tablosuyla birebirdir; tabloda olmayan
/// hiçbir üye bu sınıfa eklenmez (`limits_test.dart` tabloyu `docs/PLAN.md`'den
/// okuyup ad ve değer paritesini doğrular). Security Rules'taki her sayısal
/// literal `// limit: <ad>` yorumuyla bu sınıfa bağlanır
/// (`tool/check_rules_parity.js`, T-10).
///
/// Sunum süreleri burada **yoktur** (CD-24, CD-58): toast ve splash animasyonu
/// `GuMotion`'da, uygulama gecikmeleri `AppDurations`'tadır. Süreler
/// [Duration]; desenler `RegExp` kaynağı olarak [String].
abstract final class Limits {
  // ── Kimlik (Auth) ────────────────────────────────────────────────────

  /// Şifre en az uzunluğu (AUT-02 kayıt, AUT-04 sıfırlama).
  static const int passwordMinLength = 8;

  /// Şifre deseni: en az bir büyük harf + bir rakam + [passwordMinLength]
  /// karakter. `RegExp(unicode: true)` ile derlenir (`\p{Lu}` Türkçe büyük
  /// harfleri kapsar).
  static const String passwordPattern = r'^(?=.*\p{Lu})(?=.*\d).{8,}$';

  /// Kilitlenmeden önceki hatalı giriş denemesi sayısı (AUT-01
  /// `LoginThrottle`).
  static const int loginMaxFailedAttempts = 5;

  /// Hatalı giriş kilidinin süresi (AUT-01 `LoginThrottle`, DLG-02).
  static const Duration loginLockout = Duration(seconds: 30);

  /// Doğrulama e-postasını yeniden gönderme bekleme süresi (AUT-03).
  static const Duration verificationResendCooldown = Duration(seconds: 60);

  /// `AuthService` çağrılarının zaman aşımı.
  static const Duration authTimeout = Duration(seconds: 15);

  // ── Altyapı ──────────────────────────────────────────────────────────

  /// `FirestoreService` çağrılarının zaman aşımı.
  static const Duration firestoreTimeout = Duration(seconds: 10);

  /// `StorageService.upload` zaman aşımı.
  static const Duration storageUploadTimeout = Duration(seconds: 60);

  /// `RetryPolicy` bekleme süreleri; deneme sayısı = liste uzunluğu.
  static const List<Duration> retryBackoff = [
    Duration(milliseconds: 250),
    Duration(milliseconds: 500),
    Duration(milliseconds: 1000),
  ];

  /// Tek `WriteBatch` içindeki yazma üst sınırı (Firestore 500 sınırının
  /// altında pay).
  static const int batchMaxWrites = 450;

  /// SYS-01 oturum durumu bekleme üst sınırı (animasyon süresi
  /// `GuMotion.splash`).
  static const Duration splashTimeout = Duration(seconds: 20);

  // ── Kullanıcı ────────────────────────────────────────────────────────

  /// Ad en az uzunluğu (`users.name`, `nameLower`, `applicant.name`,
  /// `advisor.name`); Rules `// limit: nameMin`.
  static const int nameMin = 2;

  /// Ad en çok uzunluğu; Rules `// limit: nameMax`.
  static const int nameMax = 60;

  /// Kulüp adı en çok uzunluğu (`clubs.name`, `nameLower`); Rules
  /// `// limit: clubNameMax` (CD-30).
  static const int clubNameMax = 60;

  /// İlgi alanı en az sayısı (AUT-05, PRF-02); Rules `// limit: interestsMin`.
  static const int interestsMin = 1;

  /// İlgi alanı en çok sayısı; Rules `// limit: interestsMax`.
  static const int interestsMax = 5;

  /// Biyografi en çok uzunluğu (`users.bio`); Rules `// limit: bioMax`.
  static const int bioMax = 140;

  /// Yönetsel gerekçe en çok uzunluğu (`users.suspendReason`,
  /// `clubs.suspendReason`, `events.cancelReason`); Rules
  /// `// limit: adminReasonMax` (CD-30).
  static const int adminReasonMax = 300;

  /// `account.fcmTokens` en çok eleman sayısı; Rules `// limit: fcmTokensMax`
  /// (Mod C'de liste hep boş).
  static const int fcmTokensMax = 10;

  /// `FcmTokenModel.platform` için izinli değerler.
  static const Set<String> platforms = {'ios', 'android'};

  // ── Kulüp ────────────────────────────────────────────────────────────

  /// Kulüp kısa açıklaması en çok uzunluğu (`clubs.summary`); Rules
  /// `// limit: clubSummaryMax`.
  static const int clubSummaryMax = 160;

  /// Kulüp uzun açıklaması en çok uzunluğu (`clubs.about`); Rules
  /// `// limit: clubAboutMax`.
  static const int clubAboutMax = 1000;

  /// Üyelik koşulu en çok sayısı (`clubs.conditions.length`); Rules
  /// `// limit: conditionsMax` (CD-30).
  static const int conditionsMax = 10;

  /// Tek üyelik koşulu metninin en çok uzunluğu (`clubs.conditions[i]`);
  /// Rules `// limit: conditionTextMax` (CD-30).
  static const int conditionTextMax = 120;

  /// Kuruluş yılı alt sınırı (`clubs.founded`); Rules `// limit: foundedMin`
  /// (CD-30).
  static const int foundedMin = 1900;

  /// Kuruluş yılı üst sınırı: [clock] anının UTC yılı. Rules karşılığı
  /// `founded <= request.time.year()` (CD-30).
  static int foundedMax(AppClock clock) => clock.nowUtc().year;

  /// Instagram kullanıcı adı deseni (`social.instagram`; baştaki `@`
  /// isteğe bağlı). Rules `matches` ile aynı desen (RP03, CD-30).
  static const String instagramHandlePattern = r'^@?[A-Za-z0-9._]{1,30}$';

  // ── Üyelik ───────────────────────────────────────────────────────────

  /// Başvuru notu en çok uzunluğu (`memberships.note`); Rules
  /// `// limit: applicationNoteMax`.
  static const int applicationNoteMax = 300;

  /// Ret notu en çok uzunluğu (`memberships.rejectNote`); Rules
  /// `// limit: rejectNoteMax`.
  static const int rejectNoteMax = 200;

  /// Ret/çıkarma sonrası yeniden başvuru bekleme süresi (`retryAfter`);
  /// Rules `// limit: reapplyCooldown`.
  static const Duration reapplyCooldown = Duration(days: 7);

  /// Yöneticinin kendi kararını geri alabileceği pencere (M12); Rules
  /// `// limit: managerUndoWindow`.
  static const Duration managerUndoWindow = Duration(seconds: 30);

  /// İstemci–sunucu saat kayması toleransı (`retryAfter`, `poll.endsAt`
  /// Rules pencereleri); Rules `// limit: clockSkewToleranceMinutes` (CD-32).
  static const Duration clockSkewTolerance = Duration(minutes: 5);

  // ── Gönderi, anket, yorum ────────────────────────────────────────────

  /// Gönderi metni en çok uzunluğu (`posts.text`); Rules
  /// `// limit: postTextMax`.
  static const int postTextMax = 1000;

  /// Duyuru başlığı en çok uzunluğu (`posts.title`); Rules
  /// `// limit: postTitleMax`.
  static const int postTitleMax = 80;

  /// Gönderi başına en çok görsel (`posts.images`); Rules
  /// `// limit: postImagesMax`.
  static const int postImagesMax = 4;

  /// Tek görselin en çok boyutu, bayt (5 MB); Storage Rules
  /// `// limit: imageMaxBytes`.
  static const int imageMaxBytes = 5 * 1024 * 1024;

  /// Anket seçeneği en az sayısı (`poll.options`); Rules
  /// `// limit: pollOptionsMin`.
  static const int pollOptionsMin = 2;

  /// Anket seçeneği en çok sayısı; Rules `// limit: pollOptionsMax`.
  static const int pollOptionsMax = 4;

  /// Anket seçeneği metni en çok uzunluğu (`poll.options[].text`); Rules
  /// `// limit: pollOptionTextMax` (CD-30).
  static const int pollOptionTextMax = 60;

  /// Anket süresi seçenekleri, gün (FED-03 süre seçici; `poll.endsAt`).
  static const List<int> pollDurationsDays = [1, 3, 7];

  /// Yorum en çok uzunluğu (`comments.text`); Rules `// limit: commentMax`.
  static const int commentMax = 500;

  /// Yorum karakter sayacının görünmeye başladığı uzunluk (FED-02, SHT-09).
  static const int commentCounterFrom = 400;

  // ── Etkinlik ─────────────────────────────────────────────────────────

  /// Etkinlik başlığı en çok uzunluğu (`events.title`); Rules
  /// `// limit: eventTitleMax`.
  static const int eventTitleMax = 80;

  /// Etkinlik açıklaması en çok uzunluğu (`events.desc`); Rules
  /// `// limit: eventDescMax`.
  static const int eventDescMax = 1000;

  /// Serbest mekân metni en çok uzunluğu (`events.placeText`); Rules
  /// `// limit: placeTextMax` (CD-30).
  static const int placeTextMax = 120;

  /// MGT-04 "Kopyala" işleminde tarihin kaydırıldığı süre.
  static const Duration eventCopyShift = Duration(days: 7);

  /// Yoklama penceresinin etkinlik başlangıcından önceki payı (K-G); Rules
  /// `// limit: attendanceWindowBefore`.
  static const Duration attendanceWindowBefore = Duration(hours: 2);

  /// Yoklama penceresinin etkinlik bitişinden sonraki payı (K-G); Rules
  /// `// limit: attendanceWindowAfter`.
  static const Duration attendanceWindowAfter = Duration(hours: 6);

  // ── Şikayet, destek, duyuru ──────────────────────────────────────────

  /// Şikayet notu en çok uzunluğu (`reports.note`); Rules
  /// `// limit: reportNoteMax`.
  static const int reportNoteMax = 300;

  /// Destek mesajı en çok uzunluğu (`supportTickets.message`); Rules
  /// `// limit: supportMessageMax`.
  static const int supportMessageMax = 500;

  /// Destek talebi başına en çok ek (`supportTickets.attachmentPaths`);
  /// Rules `// limit: supportAttachmentsMax`.
  static const int supportAttachmentsMax = 1;

  /// Kulüp başına günlük (Istanbul günü) duyuru sınırı
  /// (`announcementCounters.count`); Rules
  /// `// limit: announcementDailyLimit`.
  static const int announcementDailyLimit = 2;

  // ── Ayarlar ──────────────────────────────────────────────────────────

  /// `HH:mm` saat deseni (`settings.quietFrom/quietTo`); Rules ile aynı
  /// (RP03).
  static const String timeOfDayPattern = r'^([01]\d|2[0-3]):[0-5]\d$';

  /// Sessiz saat başlangıcı varsayılanı (`UserSettingsModel.defaults`).
  static const String quietFromDefault = '22:00';

  /// Sessiz saat bitişi varsayılanı (`UserSettingsModel.defaults`).
  static const String quietToDefault = '08:00';

  /// `yyyy-MM-dd` gün deseni (`announcementCounters.day`).
  static const String isoDayPattern = r'^\d{4}-\d{2}-\d{2}$';

  // ── Listeler, arama, bildirim ────────────────────────────────────────

  /// Saklanan son arama sayısı (CLB-02).
  static const int recentSearchesMax = 6;

  /// Arama girdisi bekleme süresi (CLB-02, EVT-01).
  static const Duration searchDebounce = Duration(milliseconds: 250);

  /// Sayfalı sorguların sayfa boyutu.
  static const int pageSize = 20;

  /// CLB-01 tek seferlik kulüp çekiminin üst sınırı.
  static const int clubsFetchMax = 50;

  /// EVT-01 tek seferlik yaklaşan etkinlik çekiminin üst sınırı.
  static const int upcomingEventsFetchMax = 200;

  /// `NotificationRepository.watchInbox` belge sınırı.
  static const int notificationInboxLimit = 100;

  /// Okunmamış rozetinde gösterilen en büyük sayı (üstü `9+`).
  static const int unreadBadgeMax = 9;

  /// `ClientFanOutDispatcher` parça boyutu (başlangıç değeri; T-25 bütçe
  /// ölçümü günceller).
  static const int notificationFanOutChunkSize = 50;

  /// `event_new` ilgi-eşleşmeli alıcı üst sınırı
  /// (`UserRepository.listByInterests`, CD-38).
  static const int eventNewInterestFanOutMax = 200;

  /// Hesap silmede tek parçadaki üyelik sayısı (T-29 bütçe ölçümüyle
  /// sabitlenir).
  static const int accountDeletionChunk = 5;

  /// Istanbul'un UTC'ye göre sabit kayması (DST yok); Rules
  /// `// limit: istanbulUtcOffset`.
  static const Duration istanbulUtcOffset = Duration(hours: 3);
}

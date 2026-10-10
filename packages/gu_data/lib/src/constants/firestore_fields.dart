/// Firestore belge alan adları — JSON anahtarlarının **tek** kaynağı
/// (PLAN §9.5, §9.6; D-15).
///
/// PLAN §9.6 tablolarındaki (ve gömülü model tanımlarındaki) her JSON anahtarı
/// burada aynı adla bir `static const String` sabitidir; sorgu, yük ve Rules
/// parite testlerinde alan adı elle yazılmaz. Aynı anahtar birden çok
/// koleksiyonda geçiyorsa (`clubId`, `status`, `name` …) **bir kez** tanımlanır
/// ve belge yorumunda kullanıldığı yerler listelenir.
///
/// Gömülü nesne (map) anahtarları ayrıca noktalı yol sabiti olarak verilir:
/// `<üst><Alt>` = `'üst.alt'` ([socialEmail], [pollEndsAt] …). Bu yollar
/// `update` yüklerinde tek bir alt alanı yazmak ve Rules `touches([...])`
/// listeleriyle parite kurmak içindir. Liste elemanı anahtarlarının
/// (`fcmTokens[]`, `images[]`, `poll.options[]`) noktalı yolu yoktur.
///
/// Belge ID'leri (`uid`, `id`) JSON'a yazılmaz; bu yüzden sabitleri yoktur
/// ([id] yalnızca `poll.options[].id` anahtarıdır). Koleksiyon adları
/// `FirestoreCollections`, bileşik belge ID'leri `FirestoreIds` içindedir.
abstract final class FirestoreFields {
  // ── Ortak alanlar — BaseFields (§9.2) ────────────────────────────────

  /// Oluşturulma anı (sunucu zamanı). `BaseFields`; ayrıca `votes` ve
  /// `activity` belgelerinin tek zaman alanı.
  static const String createdAt = 'createdAt';

  /// Son güncelleme anı (sunucu zamanı). `BaseFields`; ayrıca `settings`,
  /// `announcementCounters` ve `fcmTokens[]` elemanları.
  static const String updatedAt = 'updatedAt';

  /// Belgeyi oluşturan uid — yalnızca `clubs` (süper admin) ve `events`
  /// (yönetici).
  static const String createdBy = 'createdBy';

  /// Soft delete bayrağı (D-10); okuma sorguları `isDeleted == false` süzer.
  static const String isDeleted = 'isDeleted';

  /// Soft delete anı (sunucu zamanı); geri almada `null` yazılır.
  static const String deletedAt = 'deletedAt';

  /// Soft delete yapan uid; geri almada `null` yazılır.
  static const String deletedBy = 'deletedBy';

  // ── users/{uid} (§9.6.1) ─────────────────────────────────────────────

  /// Görünen ad: `users`, `clubs`, `applicant` ve `advisor`.
  static const String name = 'name';

  /// Adın Türkçe küçük harfli kopyası (arama/sıralama): `users`, `clubs`.
  static const String nameLower = 'nameLower';

  /// Avatar rengi/harfi tohumu: `users`, `applicant`.
  static const String avatarSeed = 'avatarSeed';

  /// Kullanıcı avatarının Storage yolu (`users/{uid}/{file}`).
  static const String avatarPath = 'avatarPath';

  /// Bölüm ID'si (`d01`–`d24`): `users`, `applicant`.
  static const String department = 'department';

  /// Sınıf düzeyi (`YearLevel`): `users`, `applicant`.
  static const String year = 'year';

  /// İlgi alanı ID'leri (`i01`–`i16`).
  static const String interests = 'interests';

  /// Kullanıcı biyografisi.
  static const String bio = 'bio';

  /// Durum: `users`, `clubs`, `memberships`, `events`, `rsvps`, `reports`,
  /// `supportTickets` (her biri kendi enum'uyla).
  static const String status = 'status';

  /// Askıya alma nedeni: `users`, `clubs`.
  static const String suspendReason = 'suspendReason';

  /// Akademik/idari personel bayrağı (yalnızca seed/admin betiği yazar).
  static const String staff = 'staff';

  /// Profil kurulumu (AUT-05) tamamlandı mı?
  static const String profileComplete = 'profileComplete';

  // ── users/{uid}/private/account (§9.6.2) ─────────────────────────────

  /// E-posta: `private/account`, `private/contact` ve `social` (D-29: e-posta
  /// `users` belgesinde yoktur).
  static const String email = 'email';

  /// E-postanın küçük harfli kopyası (ADM-05 araması): `private/account`,
  /// `private/contact`.
  static const String emailLower = 'emailLower';

  /// FCM jetonları listesi (`FcmTokenModel`; Mod C'de hep boş — CD-62).
  static const String fcmTokens = 'fcmTokens';

  /// Son giriş anı (sunucu zamanı).
  static const String lastLoginAt = 'lastLoginAt';

  /// `fcmTokens[]` elemanı: FCM jetonu.
  static const String token = 'token';

  /// `fcmTokens[]` elemanı: platform (`Limits.platforms`).
  static const String platform = 'platform';

  // ── clubs/{clubId} (§9.6.3) ──────────────────────────────────────────

  /// Kulüp kategorisi ID'si (`k01`–`k08`).
  static const String categoryId = 'categoryId';

  /// Kulüp amblemi ikon adı (Lucide).
  static const String iconName = 'iconName';

  /// Kulüp kapak paleti (`ClubPalette`).
  static const String palette = 'palette';

  /// Kulüp kapak deseni (`ClubPattern`).
  static const String pattern = 'pattern';

  /// Kapak deseni tohumu: `clubs` (`club-{id}`), `events` (`event-{id}`).
  static const String coverSeed = 'coverSeed';

  /// Kulüp logosunun Storage yolu.
  static const String logoPath = 'logoPath';

  /// Özel kapak görselinin Storage yolu: `clubs`, `events` (K-C).
  static const String coverPath = 'coverPath';

  /// Aktif üye sayacı (danışman hariç); yalnızca ±1 batch'iyle değişir.
  static const String memberCount = 'memberCount';

  /// Katılım yönetici onayı gerektirir mi?
  static const String approvalRequired = 'approvalRequired';

  /// Kulüp başvurulara açık mı?
  static const String applicationsOpen = 'applicationsOpen';

  /// Başvuruda not zorunlu mu?
  static const String requireNote = 'requireNote';

  /// Kuruluş yılı.
  static const String founded = 'founded';

  /// Kulüp kısa özeti.
  static const String summary = 'summary';

  /// Kulüp hakkında metni.
  static const String about = 'about';

  /// Katılım koşulları listesi.
  static const String conditions = 'conditions';

  /// Kulüp iletişim bilgileri nesnesi (`ClubSocialModel`).
  static const String social = 'social';

  /// Kulüp başkanının uid'i (üyelik belgesiyle tutarlı).
  static const String presidentId = 'presidentId';

  /// Sabitlenmiş gönderinin ID'si (kulüp başına en çok bir).
  static const String pinnedPostId = 'pinnedPostId';

  /// Danışman nesnesi (`ClubAdvisorModel`, K-A).
  static const String advisor = 'advisor';

  /// `memberCount` ±1 batch'inde yazılan üyelik belgesi yolu (CD-41).
  static const String lastMembershipRef = 'lastMembershipRef';

  /// `social` alt alanı: Instagram kullanıcı adı.
  static const String instagram = 'instagram';

  /// `social` alt alanı: web adresi.
  static const String web = 'web';

  /// Başlık/ünvan: `advisor` (ünvan), `posts` (duyuru başlığı), `events`.
  static const String title = 'title';

  /// Kullanıcı uid'i: `memberships`, `rsvps`, `notifications`, `savedPosts`,
  /// `supportTickets`, `advisor` ve `activity.refs`.
  static const String userId = 'userId';

  // ── memberships/{clubId}_{userId} (§9.6.4, §9.6.5) ───────────────────

  /// Kulüp ID'si: `memberships`, `posts`, `comments`, `events`, `rsvps`,
  /// `activity`, `savedPosts`, `announcementCounters` ve
  /// `notifications.refs`.
  static const String clubId = 'clubId';

  /// Kulüp rolü (`ClubRole`): `memberships` ve `refs` nesneleri.
  static const String role = 'role';

  /// Serbest not: `memberships` (başvuru notu), `reports` (şikayet notu).
  static const String note = 'note';

  /// Başvuru anındaki başvuran görüntüsü (`MembershipApplicantModel`).
  static const String applicant = 'applicant';

  /// Başvuru anı (sunucu zamanı).
  static const String appliedAt = 'appliedAt';

  /// Karar (onay/red/çıkarma) anı (sunucu zamanı).
  static const String decidedAt = 'decidedAt';

  /// Kararı veren yöneticinin uid'i.
  static const String decidedBy = 'decidedBy';

  /// Yeniden başvurunun mümkün olduğu an (`Limits.reapplyCooldown`).
  static const String retryAfter = 'retryAfter';

  /// Red nedeni (`RejectReason`).
  static const String rejectReason = 'rejectReason';

  /// Red notu.
  static const String rejectNote = 'rejectNote';

  /// Önceki başvuru sayısı.
  static const String priorCount = 'priorCount';

  // ── posts/{postId} (§9.6.6) ──────────────────────────────────────────

  /// Yazar uid'i: `posts`, `comments`.
  static const String authorId = 'authorId';

  /// Tür: `posts` (`PostType`), `events` (`EventType`), `notifications`
  /// (`NotificationType`).
  static const String type = 'type';

  /// Metin: `posts` (anket sorusu dahil), `comments`, `poll.options[]`.
  static const String text = 'text';

  /// Gönderi görselleri listesi (`PostImageModel`, K-B).
  static const String images = 'images';

  /// Anket nesnesi (`PollModel`).
  static const String poll = 'poll';

  /// Gönderi sabit mi? (`clubs.pinnedPostId` kopyası).
  static const String pinned = 'pinned';

  /// Duyuru bildirimi gönderildi mi? (günlük duyuru limiti sayımı).
  static const String pushSent = 'pushSent';

  /// Beğenen uid'ler listesi.
  static const String likes = 'likes';

  /// Beğeni sayacı (`likes` uzunluğu).
  static const String likeCount = 'likeCount';

  /// Yorum sayacı.
  static const String commentCount = 'commentCount';

  /// `commentCount` ±1 batch'inde yazılan yorum belgesi yolu (CD-41).
  static const String lastCommentRef = 'lastCommentRef';

  /// Moderasyonla gizlendi mi?: `posts`, `comments`.
  static const String isHidden = 'isHidden';

  /// Gizleyen uid: `posts`, `comments`.
  static const String hiddenBy = 'hiddenBy';

  /// Gizlenme anı (sunucu zamanı): `posts`, `comments`.
  static const String hiddenAt = 'hiddenAt';

  /// Yazarın son düzenleme anı (sunucu zamanı).
  static const String editedAt = 'editedAt';

  /// `images[]` elemanı: Storage yolu.
  static const String path = 'path';

  /// `images[]` elemanı: genişlik (piksel).
  static const String w = 'w';

  /// `images[]` elemanı: yükseklik (piksel).
  static const String h = 'h';

  /// `poll` alt alanı: seçenekler listesi (`PollOptionModel`).
  static const String options = 'options';

  /// Bitiş anı: `poll` (anket kapanışı), `events` (etkinlik bitişi).
  static const String endsAt = 'endsAt';

  /// `poll` alt alanı: sonuçlar oy verdikten sonra mı görünür?
  static const String showResultsAfterVote = 'showResultsAfterVote';

  /// `poll.options[]` elemanı: seçenek ID'si (`o1`–`o4`). Belge ID'si
  /// **değildir** (belge ID'leri JSON'a yazılmaz).
  static const String id = 'id';

  // ── posts/{postId}/votes/{uid} (§9.6.7) ──────────────────────────────

  /// Oy verilen seçeneğin ID'si.
  static const String optionId = 'optionId';

  // ── comments/{commentId} (§9.6.8) ────────────────────────────────────

  /// Gönderi ID'si: `comments`, `savedPosts` ve `refs` nesneleri.
  static const String postId = 'postId';

  // ── events/{eventId} (§9.6.9) ────────────────────────────────────────

  /// Etkinlik açıklaması.
  static const String desc = 'desc';

  /// Etkinlik başlangıç anı.
  static const String startsAt = 'startsAt';

  /// Mekân tablosu ID'si.
  static const String placeId = 'placeId';

  /// Serbest metin mekân.
  static const String placeText = 'placeText';

  /// Kontenjan (`null` = sınırsız).
  static const String capacity = 'capacity';

  /// Görünürlük (`EventVisibility`).
  static const String visibility = 'visibility';

  /// Etkinlik iptal nedeni (DLG-23).
  static const String cancelReason = 'cancelReason';

  /// Etkinlik kapak paleti (`ClubPalette`).
  static const String coverPalette = 'coverPalette';

  /// Etkinlik kapak deseni (`ClubPattern`).
  static const String coverPattern = 'coverPattern';

  /// Etkinlik kaydı açık mı?
  static const String registrationOpen = 'registrationOpen';

  /// Otomatik hatırlatma açık mı?
  static const String autoReminder = 'autoReminder';

  /// "Katılıyor" sayacı.
  static const String goingCount = 'goingCount';

  /// Bekleme listesi sayacı.
  static const String waitlistCount = 'waitlistCount';

  /// Yoklaması alınan katılımcı sayacı.
  static const String attendedCount = 'attendedCount';

  /// Etkinlik sayaçlarının ±1 batch'inde yazılan rsvp belgesi yolu (CD-41).
  static const String lastRsvpRef = 'lastRsvpRef';

  /// Yayınlanma anı (sunucu zamanı).
  static const String publishedAt = 'publishedAt';

  // ── rsvps/{eventId}_{userId} (§9.6.10) ───────────────────────────────

  /// Etkinlik ID'si: `rsvps` ve `refs` nesneleri.
  static const String eventId = 'eventId';

  /// Hatırlatma seçimi (`ReminderOption`).
  static const String reminder = 'reminder';

  /// Bilet kodu (`GU-XXXX-XXXX`, D-30).
  static const String ticketCode = 'ticketCode';

  /// Bekleme listesine giriş anı (sunucu zamanı; sıra hesabı).
  static const String waitlistAt = 'waitlistAt';

  /// Biletin okutulduğu an (sunucu zamanı).
  static const String scannedAt = 'scannedAt';

  /// Yoklamayı alan yöneticinin uid'i.
  static const String scannedBy = 'scannedBy';

  // ── notifications/{id} (§9.6.11) ─────────────────────────────────────

  /// Referans nesnesi: `notifications` (`NotificationRefsModel`), `activity`
  /// (`ActivityRefsModel`).
  static const String refs = 'refs';

  /// Bildirim okundu mu?
  static const String read = 'read';

  /// `notifications.refs` alt alanı: başvuranın uid'i.
  static const String applicantId = 'applicantId';

  /// `notifications.refs` alt alanı: şikayet ID'si.
  static const String reportId = 'reportId';

  /// `notifications.refs` alt alanı: sistem bildirimi metin anahtarı.
  static const String textKey = 'textKey';

  // ── reports/{reporterId}_{targetType}_{targetId} (§9.6.12) ───────────

  /// Şikayet hedefinin türü (`ReportTargetType`).
  static const String targetType = 'targetType';

  /// Şikayet hedefinin ID'si.
  static const String targetId = 'targetId';

  /// Şikayet hedefinin bağlı olduğu kulüp (kullanıcı hedefinde `null`).
  static const String targetClubId = 'targetClubId';

  /// Şikayet eden uid.
  static const String reporterId = 'reporterId';

  /// Şikayet nedeni (`ReportReason`).
  static const String reason = 'reason';

  /// Çözüm eylemi (`ReportAction`).
  static const String action = 'action';

  /// Şikayetin çözüldüğü an (sunucu zamanı).
  static const String resolvedAt = 'resolvedAt';

  /// Şikayeti çözen süper adminin uid'i.
  static const String resolvedBy = 'resolvedBy';

  // ── activity/{id} (§9.6.13) ──────────────────────────────────────────

  /// Eylemi yapan uid.
  static const String actorId = 'actorId';

  /// Faaliyet türü (`ActivityKind`).
  static const String kind = 'kind';

  // ── settings/{uid} (§9.6.14) ─────────────────────────────────────────

  /// Duyuru bildirimleri: `settings` (genel) ve kulüp başına tercih.
  static const String announcements = 'announcements';

  /// Etkinlik hatırlatmaları tercihi.
  static const String eventReminders = 'eventReminders';

  /// Yeni etkinlik bildirimleri tercihi.
  static const String newEvents = 'newEvents';

  /// Başvuru sonucu bildirimleri tercihi.
  static const String applicationResults = 'applicationResults';

  /// Yönetim bildirimleri tercihi.
  static const String management = 'management';

  /// Sistem bildirimleri tercihi.
  static const String system = 'system';

  /// Varsayılan hatırlatma zamanı (`ReminderOption`; `1h` ya da `1d`).
  static const String reminderTime = 'reminderTime';

  /// Sessiz saatler açık mı?
  static const String quiet = 'quiet';

  /// Sessiz saat başlangıcı (`HH:mm`).
  static const String quietFrom = 'quietFrom';

  /// Sessiz saat bitişi (`HH:mm`).
  static const String quietTo = 'quietTo';

  /// Kulüp başına bildirim tercihleri haritası (anahtar = `clubId`;
  /// `ClubNotificationPrefsModel`).
  static const String clubs = 'clubs';

  /// Kulüp başına tercih: etkinlik bildirimleri.
  static const String events = 'events';

  /// Kulüp başına tercih: gönderi bildirimleri.
  static const String posts = 'posts';

  /// Kulüp başına tercih: kulüp sessize alındı mı?
  static const String muted = 'muted';

  // ── blocks/{blockerId}_{blockedId} (§9.6.15) ─────────────────────────

  /// Engelleyen uid.
  static const String blockerId = 'blockerId';

  /// Engellenen uid.
  static const String blockedId = 'blockedId';

  // ── savedPosts/{userId}_{postId} (§9.6.16) ───────────────────────────

  /// Kaydetme anı (sunucu zamanı; PRF-04 sıralaması).
  static const String savedAt = 'savedAt';

  // ── supportTickets/{id} (§9.6.17) ────────────────────────────────────

  /// Destek talebi numarası (`GU-XXXXXX`).
  static const String ticketNo = 'ticketNo';

  /// Destek konusu (`SupportSubject`).
  static const String subject = 'subject';

  /// Destek mesajı.
  static const String message = 'message';

  /// Destek eki Storage yolları listesi.
  static const String attachmentPaths = 'attachmentPaths';

  // ── announcementCounters/{clubId}_{yyyyMMdd} (§9.6.18) ───────────────

  /// Istanbul günü (`yyyy-MM-dd`).
  static const String day = 'day';

  /// O günkü bildirimli duyuru sayısı.
  static const String count = 'count';

  /// `count` +1 batch'inde yazılan gönderi belgesi yolu (CD-41).
  static const String lastPostRef = 'lastPostRef';

  // ── Noktalı yollar — gömülü nesne alt alanları (§9.5) ────────────────

  /// `clubs.social.email`.
  static const String socialEmail = 'social.email';

  /// `clubs.social.instagram`.
  static const String socialInstagram = 'social.instagram';

  /// `clubs.social.web`.
  static const String socialWeb = 'social.web';

  /// `clubs.advisor.name`.
  static const String advisorName = 'advisor.name';

  /// `clubs.advisor.title`.
  static const String advisorTitle = 'advisor.title';

  /// `clubs.advisor.userId`.
  static const String advisorUserId = 'advisor.userId';

  /// `memberships.applicant.name`.
  static const String applicantName = 'applicant.name';

  /// `memberships.applicant.department`.
  static const String applicantDepartment = 'applicant.department';

  /// `memberships.applicant.year`.
  static const String applicantYear = 'applicant.year';

  /// `memberships.applicant.avatarSeed`.
  static const String applicantAvatarSeed = 'applicant.avatarSeed';

  /// `posts.poll.options`.
  static const String pollOptions = 'poll.options';

  /// `posts.poll.endsAt`.
  static const String pollEndsAt = 'poll.endsAt';

  /// `posts.poll.showResultsAfterVote`.
  static const String pollShowResultsAfterVote = 'poll.showResultsAfterVote';

  /// `refs.clubId` (`notifications`).
  static const String refsClubId = 'refs.clubId';

  /// `refs.eventId` (`notifications`, `activity`).
  static const String refsEventId = 'refs.eventId';

  /// `refs.postId` (`notifications`, `activity`).
  static const String refsPostId = 'refs.postId';

  /// `refs.applicantId` (`notifications`).
  static const String refsApplicantId = 'refs.applicantId';

  /// `refs.reportId` (`notifications`).
  static const String refsReportId = 'refs.reportId';

  /// `refs.role` (`notifications`, `activity`).
  static const String refsRole = 'refs.role';

  /// `refs.textKey` (`notifications`).
  static const String refsTextKey = 'refs.textKey';

  /// `refs.userId` (`activity`).
  static const String refsUserId = 'refs.userId';

  /// `settings.clubs.{clubId}.<tercih>` yollarının öneki; kulüp ID'si ve
  /// tercih anahtarı ([announcements], [events], [posts], [muted]) eklenir.
  static const String clubsPrefix = 'clubs.';
}

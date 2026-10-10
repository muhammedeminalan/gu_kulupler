/// Firestore koleksiyon, alt koleksiyon ve sabit belge adları (PLAN §9.5,
/// D-25).
///
/// 15 kök koleksiyon + 2 alt koleksiyon ([privateSub], [votesSub]) + 2 sabit
/// belge adı ([accountDoc], [contactDoc]). Yol parçaları kodda elle yazılmaz;
/// `FirestoreService.doc/collection` yalnızca bu sabitlerle çağrılır (D-15).
abstract final class FirestoreCollections {
  /// `users/{uid}` — kullanıcı profili (e-posta taşımaz, D-29).
  static const String users = 'users';

  /// `users/{uid}/private` ve `memberships/{id}/private` alt koleksiyonu;
  /// aynı zamanda koleksiyon grubu adı (`collectionGroup('private')`, ADM-05).
  static const String privateSub = 'private';

  /// `users/{uid}/private/account` — tek belge (e-posta, FCM jetonları).
  static const String accountDoc = 'account';

  /// `clubs/{clubId}` — kulüpler.
  static const String clubs = 'clubs';

  /// `memberships/{clubId}_{userId}` — üyelik ve başvurular.
  static const String memberships = 'memberships';

  /// `memberships/{id}/private/contact` — tek belge (başvuran e-postası).
  static const String contactDoc = 'contact';

  /// `posts/{postId}` — gönderi, duyuru ve anketler.
  static const String posts = 'posts';

  /// `posts/{postId}/votes/{uid}` alt koleksiyonu — anket oyları.
  static const String votesSub = 'votes';

  /// `comments/{commentId}` — yorumlar.
  static const String comments = 'comments';

  /// `events/{eventId}` — etkinlikler.
  static const String events = 'events';

  /// `rsvps/{eventId}_{userId}` — etkinlik katılımları ve biletler.
  static const String rsvps = 'rsvps';

  /// `notifications/{notificationId}` — uygulama içi bildirimler.
  static const String notifications = 'notifications';

  /// `reports/{reporterId}_{targetType}_{targetId}` — şikayetler.
  static const String reports = 'reports';

  /// `activity/{activityId}` — değiştirilemez faaliyet günlüğü.
  static const String activity = 'activity';

  /// `settings/{uid}` — kullanıcı ayarları ve bildirim tercihleri.
  static const String settings = 'settings';

  /// `blocks/{blockerId}_{blockedId}` — engellenen kullanıcılar.
  static const String blocks = 'blocks';

  /// `savedPosts/{userId}_{postId}` — kaydedilen gönderiler.
  static const String savedPosts = 'savedPosts';

  /// `supportTickets/{ticketId}` — destek talepleri.
  static const String supportTickets = 'supportTickets';

  /// `announcementCounters/{clubId}_{yyyyMMdd}` — günlük duyuru sayaçları.
  static const String announcementCounters = 'announcementCounters';
}

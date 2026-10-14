import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/app_router.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';
import 'package:gu_kulupler/product/service/local_reminder_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notification_navigator.g.dart';

/// Bildirim türü → hedef konum tablosu (PLAN §13.7, navigation.md §4.1).
///
/// Saf: ağ / router bilmez; [NotificationNavigator] varlık kontrolünden ve
/// `hasTicket` çözümünden sonra bu tabloyu kullanır.
///
/// | Tür | Konum | Dal |
/// |---|---|---|
/// | `applicationReceived` | `/clubs/{clubId}` (**geçici**; T-32 `ManageApplicationsRoute` — W-28) | clubs |
/// | `applicationApproved`, `roleChanged` | `/clubs/{clubId}` | clubs |
/// | `applicationRejected`, `removedFromClub` | `/clubs/{clubId}/application` | clubs |
/// | `announcement` | `/clubs/{clubId}/posts/{postId}?tab=posts` | clubs |
/// | `eventNew` | `/events/{eventId}` | events |
/// | `eventCancelled` | `/events/{eventId}?showCancelled=true` | events |
/// | `eventReminder`, `waitlistPromoted` | `hasTicket` → `/events/{eventId}/ticket`, değilse `/events/{eventId}` | events |
/// | `reportResolved` | `null` (rota yok; yalnızca TST-17) | — |
/// | `newReport` | `/admin` (**geçici**; T-40 `AdminReportsRoute(reportId:)` — W-29) | admin |
/// | `system`, `unknown` (varsayılan) | `/profile/settings/about` (`AboutRoute`, SET-04) | profile |
///
/// Türün gerektirdiği kimlik ([NotificationRefsModel]) eksikse hedef
/// SYS-04'tür ([AppPaths.notFound]).
abstract final class NotificationTargets {
  /// [type] bildiriminin [refs] ile açılacak konumu; `null` → rota yok
  /// (`reportResolved`: yalnızca TST-17). [hasTicket] yalnızca
  /// `eventReminder` / `waitlistPromoted` için anlamlıdır
  /// (`rsvp.status ∈ {going, attended}` — PLAN §15.8, CD-72).
  static String? locationFor(
    NotificationType type,
    NotificationRefsModel refs, {
    required bool hasTicket,
  }) {
    final clubId = refs.clubId;
    final eventId = refs.eventId;
    final postId = refs.postId;
    return switch (type) {
      // TODO(T-32): `ManageApplicationsRoute(clubId:)` + 250 ms sonra SHT-19
      // (W-28); o güne kadar kulüp sayfası.
      NotificationType.applicationReceived => _club(clubId),
      NotificationType.applicationApproved ||
      NotificationType.roleChanged => _club(clubId),
      NotificationType.applicationRejected ||
      NotificationType.removedFromClub =>
        clubId == null
            ? AppPaths.notFound
            : ClubApplicationRoute(clubId: clubId).location,
      NotificationType.announcement =>
        clubId == null || postId == null
            ? AppPaths.notFound
            : _postInPostsTab(clubId, postId),
      NotificationType.eventNew =>
        eventId == null
            ? AppPaths.notFound
            : EventDetailRoute(eventId: eventId).location,
      NotificationType.eventCancelled =>
        eventId == null
            ? AppPaths.notFound
            : EventDetailRoute(eventId: eventId, showCancelled: true).location,
      NotificationType.eventReminder || NotificationType.waitlistPromoted =>
        eventId == null
            ? AppPaths.notFound
            : hasTicket
            ? TicketRoute(eventId: eventId).location
            : EventDetailRoute(eventId: eventId).location,
      NotificationType.reportResolved => null,
      // TODO(T-40): `AdminReportsRoute(reportId: refs.reportId)` + 250 ms
      // sonra SHT-26 (W-29); o güne kadar Admin sekme kökü.
      NotificationType.newReport => const AdminRoute().location,
      // SET-04 Hakkında (PLAN §13.7; yığın Profil → Ayarlar → Hakkında).
      NotificationType.system ||
      NotificationType.unknown => const AboutRoute().location,
    };
  }

  /// [type] türünün hedef varlık kontrolü ister mi (gönderi / etkinlik
  /// silinmiş ya da gizliyse SYS-04 — PLAN §13.7 adım 3).
  static bool needsExistenceCheck(NotificationType type) => switch (type) {
    NotificationType.announcement ||
    NotificationType.eventNew ||
    NotificationType.eventCancelled ||
    NotificationType.eventReminder ||
    NotificationType.waitlistPromoted => true,
    _ => false,
  };

  /// [type] açıldıktan sonra gecikmeli bir sheet açar mı
  /// (`AppDurations.postNavigationSheetDelay`; SHT-19 / SHT-26).
  static bool opensSheetAfterNavigation(NotificationType type) =>
      type == NotificationType.applicationReceived ||
      type == NotificationType.newReport;

  static String _club(String? clubId) => clubId == null
      ? AppPaths.notFound
      : ClubDetailRoute(clubId: clubId).location;

  /// Gönderi detayı; yığındaki kulüp sayfası "Gönderiler" sekmesinde açılır
  /// (`?tab=posts` — go_router sorguyu üst rotayla paylaşır).
  static String _postInPostsTab(String clubId, String postId) {
    final tabQuery = Uri.parse(
      ClubDetailRoute(clubId: clubId, tab: ClubDetailTab.posts).location,
    ).queryParameters;
    return Uri.parse(
      PostDetailRoute(clubId: clubId, postId: postId).location,
    ).replace(queryParameters: tabQuery).toString();
  }
}

/// Bildirim / yerel hatırlatıcı dokunuşu → hedef ekran (PLAN §15.8, CD-72).
///
/// Akış ([open]): (1) okunmamışsa `notificationRepository.markRead` (en iyi
/// çaba, gezinmeyi beklemez; `markAsRead: false` → çağıran kendisi işaretler);
/// (2) `eventReminder` / `waitlistPromoted` için `hasTicket`
/// (`rsvpRepository.getMine`: `going` / `attended`); (3) hedef varlık
/// kontrolü ([NotificationTargets.needsExistenceCheck]) — gönderi
/// (`postRepository.getPost`) yok / silinmiş / gizli / okunamıyor, etkinlik
/// (`eventRepository.getEvent`) yok / silinmiş → `NotFoundRoute` (SYS-04);
/// etkinliğin `permissionDenied`'ı ve ağ hataları hedef ekranda çözülür
/// (CD-57: EVT-02 TST-X18); (4) [go] — `AppNavigator.openInTab` kuralı
/// (sekme değişir, yığın `kök → … → hedef`); (5) `applicationReceived` /
/// `newReport` için gecikmeli sheet (T-32 / T-40; W-28 / W-29).
/// `reportResolved` → yalnızca TST-17.
///
/// [openPayload] yerel hatırlatıcı dokunuşudur: `eventReminder` satırıyla
/// aynı çözüm + hatırlatıcının liste belgesi (`createSelf`, CD-44).
///
/// Bağımlılıklar `ProjectDependencyMixin`'den (D-04); router ve oturum
/// değerleri kurucudan gelir ([notificationNavigatorProvider]). Hiçbir metot
/// fırlatmaz: okuma / yazma hatası günlüğe düşer.
final class NotificationNavigator with ProjectDependencyMixin {
  /// [router] üzerinden gezinen çözücü; [userId] oturumdaki kullanıcı
  /// (`null` → oturum yok, gezinme yapılmaz).
  NotificationNavigator({
    required this.router,
    required this.userId,
    required this.isSuperAdmin,
  });

  /// Uygulamanın tek router'ı.
  final GoRouter router;

  /// Oturumdaki kullanıcı; `null` → gezinme yapılmaz.
  final String? userId;

  /// Süper admin mi (`newReport` sheet'i yalnızca ona).
  final bool isSuperAdmin;

  /// Yerel hatırlatıcı yükünün (`event_reminder:<eventId>`) etkinlik
  /// kimliği; tanınmayan / bozuk yük → `null`
  /// (`LocalReminderService.eventIdOfPayload` ile aynı çözüm).
  static String? parsePayload(String? payload) =>
      LocalReminderService.eventIdOfPayload(payload);

  /// [notification] bildirimini okundu işaretler ([markAsRead] `false` →
  /// çağıran işaretler) ve hedefine gider. Oturum yoksa etkisizdir.
  Future<void> open(
    NotificationModel notification, {
    bool markAsRead = true,
  }) async {
    final uid = userId;
    if (uid == null) return;
    if (markAsRead && !notification.read && notification.id.isNotEmpty) {
      unawaited(_markRead(notification.id));
    }
    final type = notification.type;
    final refs = notification.refs;
    final eventId = refs.eventId;
    final hasTicket =
        _ticketMatters(type) &&
        eventId != null &&
        await _hasTicket(uid, eventId);
    final location = NotificationTargets.locationFor(
      type,
      refs,
      hasTicket: hasTicket,
    );
    if (location == null) {
      feedback.showToast(ToastId.tst17);
      return;
    }
    if (location != AppPaths.notFound &&
        NotificationTargets.needsExistenceCheck(type) &&
        !await _targetExists(type, refs)) {
      go(AppPaths.notFound);
      return;
    }
    go(location);
    // TODO(T-32): `applicationReceived` → `AppDurations
    // .postNavigationSheetDelay` sonra SHT-19 (üyelik hâlâ `pending` ise; W-28).
    // TODO(T-40): `newReport` → aynı gecikmeyle SHT-26 (süper admin; W-29).
  }

  /// Yerel hatırlatıcı dokunuşu (sıcak: `onDidReceiveNotificationResponse`;
  /// soğuk: splash sonrası `initialLaunchPayload`) → `eventReminder`
  /// satırıyla aynı çözüm: bilet varsa `TicketRoute`, değilse
  /// `EventDetailRoute`; etkinlik yok / silinmiş → SYS-04. Hatırlatıcının
  /// liste belgesi yazılır (`createSelf`, en iyi çaba; tekil kimlik çift
  /// yazımı önler). Bozuk yük ya da oturum yok → gezinme yok +
  /// `AppLogger.warn`.
  Future<void> openPayload(String payload) async {
    final eventId = parsePayload(payload);
    if (eventId == null) {
      AppLogger.warn('Hatırlatıcı yükü tanınmadı: $payload');
      return;
    }
    final uid = userId;
    if (uid == null) {
      AppLogger.warn('Hatırlatıcı dokunuşu oturumsuz: yönlendirilmedi');
      return;
    }
    var clubId = '';
    switch (await eventRepository.getEvent(eventId)) {
      case FirebaseSuccess(data: final event) when !event.isDeleted:
        clubId = event.clubId;
        unawaited(_recordReminder(uid, eventId, clubId));
      case FirebaseSuccess() || FirebaseFailure(error: FirestoreError.notFound):
        go(AppPaths.notFound);
        return;
      case FirebaseFailure(:final error):
        // Yetki / ağ: etkinlik ekranı kendi durumunu gösterir (CD-57).
        AppLogger.warn('Hatırlatıcı etkinliği okunamadı: ${error.name}');
    }
    final location = NotificationTargets.locationFor(
      NotificationType.eventReminder,
      NotificationRefsModel(eventId: eventId, clubId: clubId),
      hasTicket: await _hasTicket(uid, eventId),
    );
    if (location != null) go(location);
  }

  /// [location] konumunu ev sekmesinde açar (Q-20 = A; `openInTab` ile
  /// aynı kural: `go` dalı kendisi seçer).
  void go(String location) {
    assert(
      GuTab.ofLocation(Uri.parse(location)) != null ||
          location == AppPaths.notFound,
      'NotificationNavigator.go: "$location" bir sekme ağacında değil',
    );
    router.go(location);
  }

  /// Hedefi bilete göre değişen türler (`hasTicket` okunur).
  static bool _ticketMatters(NotificationType type) =>
      type == NotificationType.eventReminder ||
      type == NotificationType.waitlistPromoted;

  /// Kullanıcının [eventId] bileti var mı: kayıt `going` ya da `attended`
  /// (PLAN §15.8; `waitlist` bilet değildir — CD-72). Okuma hatası → `false`.
  Future<bool> _hasTicket(String uid, String eventId) async {
    final read = await rsvpRepository.getMine(eventId: eventId, userId: uid);
    switch (read) {
      case FirebaseSuccess(:final data):
        return data != null &&
            !data.isDeleted &&
            (data.status == RsvpStatus.going ||
                data.status == RsvpStatus.attended);
      case FirebaseFailure(:final error):
        AppLogger.warn('Bilet durumu okunamadı: ${error.name}');
        return false;
    }
  }

  /// [type] hedefi hâlâ gösterilebilir mi (PLAN §13.7 adım 3)? Belirsiz
  /// hata (ağ vb.) `true` sayılır: hedef ekran kendi hata durumunu çizer.
  Future<bool> _targetExists(
    NotificationType type,
    NotificationRefsModel refs,
  ) async {
    if (type == NotificationType.announcement) {
      final postId = refs.postId;
      if (postId == null) return false;
      return switch (await postRepository.getPost(postId)) {
        FirebaseSuccess(data: final post) =>
          !post.isDeleted && !post.isHidden && post.clubId == refs.clubId,
        // Gönderi detayı ikisini de "bulunamadı" sayar (FED-02).
        FirebaseFailure(
          error: FirestoreError.notFound || FirestoreError.permissionDenied,
        ) =>
          false,
        FirebaseFailure() => true,
      };
    }
    final eventId = refs.eventId;
    if (eventId == null) return false;
    return switch (await eventRepository.getEvent(eventId)) {
      FirebaseSuccess(data: final event) => !event.isDeleted,
      FirebaseFailure(error: FirestoreError.notFound) => false,
      // `permissionDenied` (üyelere özel / taslak) EVT-02'de TST-X18 olur
      // (CD-57).
      FirebaseFailure() => true,
    };
  }

  Future<void> _markRead(String notificationId) async {
    final marked = await notificationRepository.markRead(notificationId);
    if (marked case FirebaseFailure(:final error)) {
      AppLogger.warn('Bildirim okundu işaretlenemedi: ${error.name}');
    }
  }

  Future<void> _recordReminder(
    String uid,
    String eventId,
    String clubId,
  ) async {
    final written = await notificationRepository.createSelf(
      userId: uid,
      eventId: eventId,
      clubId: clubId,
    );
    if (written case FirebaseFailure(:final error)) {
      AppLogger.warn('Hatırlatıcı bildirimi yazılamadı: ${error.name}');
    }
  }
}

/// Uygulama ömrü boyunca tek [NotificationNavigator]; oturum kullanıcısı ya
/// da süper admin bayrağı değişince yeniden kurulur.
@Riverpod(keepAlive: true)
NotificationNavigator notificationNavigator(Ref ref) {
  final (uid, isSuperAdmin) = ref.watch(
    sessionViewModelProvider.select((s) => (s.uid, s.isSuperAdmin)),
  );
  return NotificationNavigator(
    router: ref.watch(appRouterProvider),
    userId: uid,
    isSuperAdmin: isSuperAdmin,
  );
}

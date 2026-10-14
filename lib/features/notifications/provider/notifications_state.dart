import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/notification/notification_lookups.dart';

/// NTF-01 filtre çipleri (`NTF-01.filter.<name>`; kategori
/// `registry.json#notifCat` — `NotificationType.category`).
enum NotificationFilter {
  /// Tümü.
  all,

  /// Kulüp kategorisi.
  clubs,

  /// Etkinlik kategorisi.
  events,

  /// Sistem kategorisi.
  system,

  /// Yalnızca okunmamışlar.
  unread,
}

/// NTF-01 gün grupları (Istanbul günü, `AppClock`) — prototip
/// `time.group.*` (`screens-events.js:101`): bugün; dün; "bu hafta" = dünden
/// önceki 6 gün (bugünün başından 7 gün geriye kadar); daha önce.
enum NotificationDay {
  /// Bugün.
  today,

  /// Dün.
  yesterday,

  /// Bu hafta (dünden önceki 6 gün).
  week,

  /// Daha önce.
  earlier,
}

/// NTF-01'de bir gün grubu ve bildirimleri (en yeni üstte).
final class NotificationSection extends Equatable {
  /// [day] grubunun [items] bildirimleri.
  const NotificationSection({required this.day, required this.items});

  /// Grup.
  final NotificationDay day;

  /// Gruptaki bildirimler.
  final List<NotificationModel> items;

  @override
  List<Object?> get props => [day, items];
}

/// NTF-01 "Bildirimler" + sekme rozeti durumu (PLAN §12.6
/// `NotificationsViewModel`).
///
/// * [raw] canlı akıştır (`watchInbox`, `isDeleted == false`).
/// * [items] tercih süzgeci (`NotificationPreferenceFilter`) + [filter]
///   uygulanmış liste; [sections] aynı listenin gün grupları.
/// * [unreadCount] tercih süzgecinden geçen okunmamışlar ([filter]'dan
///   bağımsız) — sekme rozeti (`countBadgeLabel`: 9 üstü "9+").
/// * [sessionStartedAt] TST-55 eşiği: bu andan sonra düşen bildirim ön
///   plan bandını tetikler.
/// * [lookups] metinlerin adları (kulüp / etkinlik / gönderi / başvuran;
///   silinmiş hedef → "İçerik kaldırıldı").
final class NotificationsState extends Equatable {
  /// Varsayılan: içerik yok.
  const NotificationsState({
    required this.sessionStartedAt,
    this.raw = const [],
    this.settings,
    this.filter = NotificationFilter.all,
    this.items = const [],
    this.sections = const [],
    this.unreadCount = 0,
    this.showPermissionBanner = false,
    this.pendingUndo,
    this.incoming,
    this.isFetching = false,
    this.isError = false,
    this.isMarkingAll = false,
    this.lookups = const NotificationLookups(),
    this.isBannerDismissed = false,
  });

  /// TST-55 eşiği (ViewModel kuruluş anı, UTC).
  final DateTime sessionStartedAt;

  /// Canlı akışın son anlık görüntüsü (en yeni üstte).
  final List<NotificationModel> raw;

  /// Kullanıcı tercihleri; okunmadıysa `null` (süzgeç uygulanmaz).
  final UserSettingsModel? settings;

  /// Seçili filtre çipi.
  final NotificationFilter filter;

  /// Süzülmüş ve filtrelenmiş liste.
  final List<NotificationModel> items;

  /// [items]'ın gün grupları (boş grup yok).
  final List<NotificationSection> sections;

  /// Süzülmüş okunmamış sayısı (rozet).
  final int unreadCount;

  /// İzin bandı görünür mü (`NTF-01.enable` / `NTF-01.dismissBanner`).
  final bool showPermissionBanner;

  /// Kaydırarak silinen, TST-16 "Geri al" bekleyen bildirim.
  final NotificationModel? pendingUndo;

  /// Ön planda yeni düşen bildirim (TST-55 bandı); gösterilince `null`.
  final NotificationModel? incoming;

  /// İlk anlık görüntü bekleniyor (iskelet).
  final bool isFetching;

  /// Akış hata verdi (hata görünümü + "Yeniden dene").
  final bool isError;

  /// "Tümünü okundu say" yazımı sürüyor.
  final bool isMarkingAll;

  /// Bildirim metinlerinin adları (`refs` kimliklerinden toplu okunur).
  final NotificationLookups lookups;

  /// İzin bandı bu oturumda kapatıldı mı (`NTF-01.dismissBanner`; izin
  /// yeniden okunsa da band dönmez — prototip `ui.dismissedNotifBanner`).
  final bool isBannerDismissed;

  /// Liste boş mu (süzgeç + filtre sonrası).
  bool get isEmpty => items.isEmpty;

  @override
  List<Object?> get props => [
    sessionStartedAt,
    raw,
    settings,
    filter,
    items,
    sections,
    unreadCount,
    showPermissionBanner,
    pendingUndo,
    incoming,
    isFetching,
    isError,
    isMarkingAll,
    lookups,
    isBannerDismissed,
  ];

  /// Değişen alanlarla kopya; [clearPendingUndo] / [clearIncoming] /
  /// [clearSettings] ilgili alanı `null` yapar.
  NotificationsState copyWith({
    DateTime? sessionStartedAt,
    List<NotificationModel>? raw,
    UserSettingsModel? settings,
    bool clearSettings = false,
    NotificationFilter? filter,
    List<NotificationModel>? items,
    List<NotificationSection>? sections,
    int? unreadCount,
    bool? showPermissionBanner,
    NotificationModel? pendingUndo,
    bool clearPendingUndo = false,
    NotificationModel? incoming,
    bool clearIncoming = false,
    bool? isFetching,
    bool? isError,
    bool? isMarkingAll,
    NotificationLookups? lookups,
    bool? isBannerDismissed,
  }) => NotificationsState(
    sessionStartedAt: sessionStartedAt ?? this.sessionStartedAt,
    raw: raw ?? this.raw,
    settings: clearSettings ? null : settings ?? this.settings,
    filter: filter ?? this.filter,
    items: items ?? this.items,
    sections: sections ?? this.sections,
    unreadCount: unreadCount ?? this.unreadCount,
    showPermissionBanner: showPermissionBanner ?? this.showPermissionBanner,
    pendingUndo: clearPendingUndo ? null : pendingUndo ?? this.pendingUndo,
    incoming: clearIncoming ? null : incoming ?? this.incoming,
    isFetching: isFetching ?? this.isFetching,
    isError: isError ?? this.isError,
    isMarkingAll: isMarkingAll ?? this.isMarkingAll,
    lookups: lookups ?? this.lookups,
    isBannerDismissed: isBannerDismissed ?? this.isBannerDismissed,
  );
}

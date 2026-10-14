import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/navigation/manage_events_tab.dart';

/// MGT-04 "Etkinlik yönetimi" ekranının durumu (PLAN §12.6
/// `ManageEventsViewModel`).
///
/// * [events] kulübün silinmemiş bütün etkinlikleridir (taslaklar dahil, tek
///   sayfa — `listClubEvents(includeDrafts: true)`, `startsAt ↓`); sekmeler
///   istemcide süzülür ([eventsOf]): "geçmiş" türetilmiştir (yayında ve
///   `endsAt < şimdi` — domain-model §2.7), bu yüzden süzgeç şimdiki anı
///   ister.
/// * [access] `advisor` → [isReadOnly] (Q-09: salt okunur bant, FAB yok,
///   yazan SHT-23 satırları TST-26).
final class ManageEventsState extends Equatable {
  /// Varsayılan: içerik yok, "Yayında" sekmesi.
  const ManageEventsState({
    this.access = ClubAccess.visitor,
    this.role,
    this.club,
    this.tab = ManageEventsTab.published,
    this.events = const [],
    this.isFetching = false,
    this.isRefreshing = false,
    this.isError = false,
  });

  /// Oturumdaki kullanıcının kulübe erişimi.
  final ClubAccess access;

  /// Oturumdaki kullanıcının kulüpteki aktif rolü (başlık rozeti).
  final ClubRole? role;

  /// Kulüp (başlıktaki ad); okunamadıysa `null`.
  final ClubModel? club;

  /// Seçili sekme (`MGT-04.tab.<name>`).
  final ManageEventsTab tab;

  /// Kulübün silinmemiş etkinlikleri, en yeni başlangıç üstte.
  final List<EventModel> events;

  /// İlk yükleme / "Yeniden dene" sürüyor (iskelet).
  final bool isFetching;

  /// Çek-yenile sürüyor (içerik ekranda kalır).
  final bool isRefreshing;

  /// İlk yükleme başarısız (hata görünümü).
  final bool isError;

  /// Danışman bakışı (Q-09).
  bool get isReadOnly => access == ClubAccess.advisor;

  /// Süper admin bakışı (başlık rozeti).
  bool get isSuperAdmin => access == ClubAccess.superAdmin;

  /// [tab] sekmesinin etkinlikleri [now] anına göre (prototip
  /// `screens-manage.js:80`):
  ///
  /// * taslak / iptal → durumu eşleşenler;
  /// * yayında → yayında ve `endsAt >= now`; geçmiş → yayında ve
  ///   `endsAt < now`;
  /// * sıra: geçmişte en yeni başlangıç üstte, diğerlerinde en yakın üstte.
  List<EventModel> eventsOf(ManageEventsTab tab, DateTime now) {
    final listed = [
      for (final event in events)
        if (_inTab(event, tab, now)) event,
    ];
    return tab == ManageEventsTab.past
        ? (listed..sort((a, b) => b.startsAt.compareTo(a.startsAt)))
        : (listed..sort((a, b) => a.startsAt.compareTo(b.startsAt)));
  }

  /// Seçili sekmenin etkinlikleri ([eventsOf]).
  List<EventModel> visibleAt(DateTime now) => eventsOf(tab, now);

  /// [id] kimlikli etkinlik; yoksa `null`.
  EventModel? find(String id) {
    for (final event in events) {
      if (event.id == id) return event;
    }
    return null;
  }

  static bool _inTab(EventModel event, ManageEventsTab tab, DateTime now) =>
      switch (tab) {
        ManageEventsTab.draft => event.status == EventStatus.draft,
        ManageEventsTab.cancelled => event.status == EventStatus.cancelled,
        ManageEventsTab.published =>
          event.status == EventStatus.published && !event.endsAt.isBefore(now),
        ManageEventsTab.past =>
          event.status == EventStatus.published && event.endsAt.isBefore(now),
      };

  /// Verilen alanları değiştirilmiş kopya. [clearRole] rolü siler.
  ManageEventsState copyWith({
    ClubAccess? access,
    ClubRole? role,
    bool clearRole = false,
    ClubModel? club,
    ManageEventsTab? tab,
    List<EventModel>? events,
    bool? isFetching,
    bool? isRefreshing,
    bool? isError,
  }) => ManageEventsState(
    access: access ?? this.access,
    role: clearRole ? null : role ?? this.role,
    club: club ?? this.club,
    tab: tab ?? this.tab,
    events: events ?? this.events,
    isFetching: isFetching ?? this.isFetching,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    isError: isError ?? this.isError,
  );

  @override
  List<Object?> get props => [
    access,
    role,
    club,
    tab,
    events,
    isFetching,
    isRefreshing,
    isError,
  ];
}

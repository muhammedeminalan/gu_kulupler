import 'dart:async';

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/events/provider/event_filter_state.dart';
import 'package:gu_kulupler/features/events/provider/event_list_state.dart';
import 'package:gu_kulupler/product/event/event_pool.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'event_list_view_model.g.dart';

/// EVT-01 "Etkinlikler" ekranının ViewModel'i (PLAN §12.6; prototip
/// `S['EVT-01']`, `screens-events.js:17–33`).
///
/// * **İstemci birleştirme** (rules-spec §9.5): açılışta tek seferde,
///   eşzamanlı okunur — kulüpler (`fetchActiveClubs`, ≤ `Limits.clubsFetchMax`;
///   kart kulüp adı + askı süzgeci), herkese açık yaklaşanlar
///   (`listPublicUpcoming`), kullanıcının **etkin** üyesi olduğu her kulüp için
///   üyelere özel yaklaşanlar (`listMembersUpcoming`; en çok
///   [memberQueriesMax] sorgu) ve kullanıcının katılım kayıtları
///   (`rsvpRepository.listMine`). Alt sınır bugünün Istanbul başlangıcıdır
///   (bugün başlamış, sürmekte olan etkinlik "Bugün"de görünür).
/// * Birleştirme ([mergeEvents]): aynı etkinlik bir kez, askıdaki / okunmayan
///   kulübün etkinliği yok, `startsAt ↑`.
/// * Süzme, çip ve sıralama istemcidedir (`EventListState.visibleAt`).
///
/// | Okuma | Başarısız | Sonuç |
/// |---|---|---|
/// | kulüpler / herkese açık | ilk okuma | hata görünümü |
/// | | çek-yenile | içerik kalır; içerik yoksa hata görünümü |
/// | üyelere özel (kulüp başına) | — | günlüğe düşer, o kulüp atlanır |
/// | katılım kayıtları | — | günlüğe düşer, kartlar durumsuz |
///
/// Katılım akışı ve gezinme view'dadır (`runEventJoinFlow`, T-23); akış kayıt
/// yazdıysa view [refresh] çağırır.
///
/// Design: EVT-01
@riverpod
final class EventListViewModel extends _$EventListViewModel
    with ProjectDependencyMixin {
  /// Üyelere özel etkinlik sorgusu sayısının üst sınırı (okuma maliyeti;
  /// görünür kulüp sayısının üst sınırı kadar).
  static const int memberQueriesMax = Limits.clubsFetchMax;

  bool _isLoading = false;

  @override
  EventListState build() {
    ref.listen(sessionViewModelProvider, (_, session) => _onSession(session));
    // Etkinlikler ilk karede okunmaya başlar; view ayrıca çağırmaz.
    unawaited(Future<void>.microtask(_load));
    final today = EventListState.istanbulCalendarDay(appClock.nowUtc());
    return EventListState(
      memberClubIds: _memberClubIds(ref.read(sessionViewModelProvider)),
      calendarMonth: DateTime(today.year, today.month),
      selectedDay: today,
      isFetching: true,
    );
  }

  /// Etkinlikleri yeniden okur — hata görünümündeki "Yeniden dene". Süren
  /// okuma varken gelen çağrı yok sayılır.
  Future<void> fetch() async {
    if (!ref.mounted || _isLoading) return;
    state = state.copyWith(isFetching: true, isError: false);
    await _load();
  }

  /// Çek-yenile (`EVT-01.refresh`) ve katılım akışı sonrası: iskelet
  /// göstermeden yeniler. Okunamazsa var olan içerik kalır; içerik yoksa
  /// hata görünümü.
  Future<void> refresh() async {
    if (!ref.mounted || _isLoading || state.isRefreshing) return;
    state = state.copyWith(isRefreshing: true);
    await _load(refreshing: true);
  }

  /// Liste ↔ takvim (`EVT-01.view.<kip>`).
  void setMode(EventListMode mode) {
    if (mode == state.mode) return;
    state = state.copyWith(mode: mode);
  }

  /// Hızlı çip (`EVT-01.chip.<id>`; tek seçim).
  void setChip(EventListChip chip) {
    if (chip == state.chip) return;
    state = state.copyWith(chip: chip);
  }

  /// SHT-11 "Uygula": süzgeç ve sıralamayı uygular.
  void setFilter(EventFilterState filter) {
    if (filter == state.filter) return;
    state = state.copyWith(filter: filter);
  }

  /// "Filtreleri temizle" (`EVT-01.clearFilters`): süzgeç ve çip sıfırlanır
  /// (`screens-events.js:30`).
  void clearFilters() {
    state = state.copyWith(
      filter: EventFilterState.none,
      chip: EventListChip.all,
    );
  }

  /// [filter] süzgecine uyan etkinlik sayısı (SHT-11 "Uygula ({count})";
  /// çip uygulanmaz — `sheets.js:54`).
  int countFor(EventFilterState filter) =>
      filter.apply(state.upcomingAt(appClock.nowUtc()), clock: appClock).length;

  /// Takvim gün seçimi (`EVT-01.day.<gün>`; takvim günü).
  void selectDay(DateTime day) {
    final next = DateTime(day.year, day.month, day.day);
    if (next == state.selectedDay) return;
    state = state.copyWith(selectedDay: next);
  }

  /// Takvim ay değişimi (`EVT-01.prevMonth` / `.nextMonth` / `.today`).
  void setMonth(DateTime month) {
    final next = DateTime(month.year, month.month);
    if (next == state.calendarMonth) return;
    state = state.copyWith(calendarMonth: next);
  }

  /// Devre dışı "Kayıtlar kapalı" kart düğmesi → TST-X2.
  void showRegistrationClosed() => feedback.showToast(ToastId.tstX2);

  /// Etkinlik sorgularının sonuçlarını birleştirir (`EventPool.merge`):
  /// başarısız sorgu günlüğe düşer ve atlanır; aynı etkinlik bir kez;
  /// yalnızca [clubIds] kulüplerinin etkinlikleri; başlangıca göre artan
  /// (eşitlikte kimlik).
  static List<EventModel> mergeEvents({
    required Set<String> clubIds,
    required List<FirestoreResult<List<EventModel>>> results,
  }) => EventPool.merge(
    clubIds: clubIds,
    results: results,
    logLabel: 'Üyelere özel etkinlikler okunamadı',
  );

  /// Katılım kayıtları → etkinlik başına en yeni kayıt (`listMine` en yeni
  /// üstte döner).
  static Map<String, RsvpModel> latestRsvps(Iterable<RsvpModel> rsvps) {
    final byEvent = <String, RsvpModel>{};
    for (final rsvp in rsvps) {
      byEvent.putIfAbsent(rsvp.eventId, () => rsvp);
    }
    return byEvent;
  }

  static Set<String> _memberClubIds(SessionState session) => {
    for (final MapEntry(key: clubId, value: membership)
        in session.memberships.entries)
      if (membership.status == MembershipStatus.active) clubId,
  };

  /// Oturumdaki etkin üyelikler değişti: çip / kart kararı güncellenir; yeni
  /// bir kulübe üye olunduysa üyelere özel etkinlikleri için yeniden okunur.
  void _onSession(SessionState session) {
    final next = _memberClubIds(session);
    final current = state.memberClubIds;
    if (next.length == current.length && next.containsAll(current)) return;
    final added = next.difference(current).isNotEmpty;
    state = state.copyWith(memberClubIds: next);
    if (added && !state.isFetching) unawaited(refresh());
  }

  /// Kaynakları okur ve birleştirir. [refreshing] → okunamazsa içerik kalır.
  Future<void> _load({bool refreshing = false}) async {
    if (!ref.mounted || _isLoading) return;
    _isLoading = true;
    final from = appClock.istanbulStartOfDay(appClock.nowUtc());
    final session = ref.read(sessionViewModelProvider);
    final uid = session.uid;
    final memberClubIds = _memberClubIds(
      session,
    ).take(memberQueriesMax).toList(growable: false);
    final (clubs, publicEvents, memberEvents, rsvps) = await (
      clubRepository.fetchActiveClubs(),
      eventRepository.listPublicUpcoming(fromUtc: from),
      Future.wait([
        for (final clubId in memberClubIds)
          eventRepository.listMembersUpcoming(clubId, fromUtc: from),
      ]),
      uid == null
          ? Future<FirestoreResult<List<RsvpModel>>>.value(
              const FirebaseSuccess(<RsvpModel>[]),
            )
          : rsvpRepository.listMine(uid),
    ).wait;
    _isLoading = false;
    if (!ref.mounted) return;
    if (clubs case FirebaseFailure(:final error, :final message)) {
      AppLogger.warn('Kulüpler okunamadı: ${error.name}', error: message);
      return _failed(refreshing: refreshing);
    }
    if (publicEvents case FirebaseFailure(:final error, :final message)) {
      AppLogger.warn('Etkinlikler okunamadı: ${error.name}', error: message);
      return _failed(refreshing: refreshing);
    }
    final pool = [
      for (final club in clubs.dataOrNull ?? const <ClubModel>[])
        if (!club.isSuspended) club,
    ];
    state = state.copyWith(
      clubs: pool,
      events: mergeEvents(
        clubIds: {for (final club in pool) club.id},
        results: [publicEvents, ...memberEvents],
      ),
      rsvps: _rsvpsOf(rsvps),
      isFetching: false,
      isRefreshing: false,
      isError: false,
    );
  }

  /// Okuma başarısız: ilk okumada hata görünümü; çek-yenilemede içerik kalır
  /// (içerik yoksa hata görünümü).
  void _failed({required bool refreshing}) {
    state = state.copyWith(
      isFetching: false,
      isRefreshing: false,
      isError: !refreshing || state.events.isEmpty,
    );
  }

  /// Katılım kayıtları; okunamazsa öncekiler kalır (kartlar durumsuz).
  Map<String, RsvpModel> _rsvpsOf(FirestoreResult<List<RsvpModel>> result) {
    switch (result) {
      case FirebaseSuccess(:final data):
        return latestRsvps(data);
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn(
          'Katılım kayıtları okunamadı: ${error.name}',
          error: message,
        );
        return state.rsvps;
    }
  }
}

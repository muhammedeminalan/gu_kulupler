import 'dart:async';

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/management/provider/manage_events_state.dart';
import 'package:gu_kulupler/features/management/provider/manage_view_model.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/mixin/external_link_mixin.dart';
import 'package:gu_kulupler/product/mixin/manage_event_actions_mixin.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';
import 'package:gu_kulupler/product/navigation/manage_events_tab.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'manage_events_view_model.g.dart';

/// MGT-04 "Etkinlik yönetimi" ViewModel'i (PLAN §12.6; prototip
/// `MgtEvents`, `screens-manage.js:77–83`). Kulüp başına ayrı örnek (family
/// `clubId`).
///
/// * Okuma: kulüp + kulübün silinmemiş bütün etkinlikleri tek sayfada
///   (`eventRepository.listClubEvents(includeDrafts: true)`, en çok
///   `Limits.upcomingEventsFetchMax`); sekmeler istemcide
///   (`ManageEventsState.eventsOf`).
/// * SHT-23 akışları (çoğalt, taslağa al, iptal, taslak silme + geri al,
///   paylaş) EVT-02 ile **ortak** `ManageEventActionsMixin`'dedir; bu
///   ViewModel yalnızca kancalarla listeyi iyimser günceller.
///
/// | İşlem | Sonuç | Geri bildirim |
/// |---|---|---|
/// | [openMenu] → çoğalt | yeni taslak listeye girer | TST-13 → MGT-05 (kopya) |
/// | [openMenu] → taslağa al | satır "Taslak" sekmesine geçer | TST-X19 |
/// | [openMenu] → iptal (DLG-23) | satır "İptal" sekmesine geçer | TST-48 |
/// | [openMenu] → sil (DLG-31) | satır düşer | TST-45 "Geri al" |
/// | hepsi | yazılamadı | iyimser değişiklik geri alınır → TST-24 · TST-X18 (çakışmada liste yenilenir) |
///
/// Danışman (Q-09) yazamaz ve düzenleme / yoklama açamaz: TST-26.
///
/// Design: MGT-04
@riverpod
final class ManageEventsViewModel extends _$ManageEventsViewModel
    with
        ProjectDependencyMixin,
        WriteGuardMixin,
        ExternalLinkMixin,
        ManageEventActionsMixin {
  /// Süren tam okuma (ilk yükleme / yenileme).
  Future<void>? _loading;

  @override
  ManageEventsState build(String clubId) {
    ref.listen(sessionViewModelProvider, (_, session) {
      final access = session.accessTo(clubId);
      final role = session.roleIn(clubId);
      if (access == state.access && role == state.role) return;
      state = state.copyWith(
        access: access,
        role: role,
        clearRole: role == null,
      );
    });
    // Etkinlikler ilk karede okunmaya başlar; view ayrıca çağırmaz.
    unawaited(Future<void>.microtask(_startLoad));
    final session = ref.read(sessionViewModelProvider);
    return ManageEventsState(
      access: session.accessTo(clubId),
      role: session.roleIn(clubId),
      isFetching: true,
    );
  }

  // ───────────────────────────────── okuma ──────────────────────────────────

  /// "Yeniden dene" (`MGT-04.retry`): iskeletle baştan okur.
  Future<void> fetch() async {
    if (!ref.mounted || _loading != null) return;
    state = state.copyWith(isFetching: true, isError: false);
    await _startLoad();
  }

  /// Çek-yenile: içerik kalarak baştan okur.
  Future<void> refresh() async {
    if (!ref.mounted || _loading != null || state.isRefreshing) return;
    state = state.copyWith(isRefreshing: true);
    await _startLoad();
  }

  // ─────────────────────────────── gezinme ──────────────────────────────────

  /// Sekme (`MGT-04.tab.<name>`; rota `?tab=`).
  void setTab(ManageEventsTab tab) {
    if (!ref.mounted || tab == state.tab) return;
    state = state.copyWith(tab: tab);
  }

  // ───────────────────────────────── yazma ──────────────────────────────────

  /// Danışman bakışında yazan eyleme dokunuldu → TST-26.
  void onReadOnlyTap() => feedback.showToast(ToastId.tst26);

  /// Yazan / formu açan eylemden önce ("Etkinlik" FAB): danışmansa TST-26 ve
  /// `false`.
  bool ensureWritable() {
    if (!state.isReadOnly) return true;
    onReadOnlyTap();
    return false;
  }

  /// Satır menüsü (`MGT-04.menu.<id>`): SHT-23 → `ManageEventActionsMixin`.
  /// Gezinme (düzenle, kopya, katılımcılar, yoklama) view'a döner.
  Future<ManageEventOutcome> openMenu(
    EventModel event,
    ManageEventTexts texts,
  ) => openEventMenu(event, texts);

  @override
  SessionState? get eventSession =>
      ref.mounted ? ref.read(sessionViewModelProvider) : null;

  @override
  void onEventChanged(EventModel event) {
    if (!ref.mounted || state.find(event.id) == null) return;
    state = state.copyWith(
      events: [for (final e in state.events) e.id == event.id ? event : e],
    );
    _refreshPanel();
  }

  @override
  void onEventRemoved(EventModel event) {
    if (!ref.mounted) return;
    state = state.copyWith(
      events: [
        for (final e in state.events)
          if (e.id != event.id) e,
      ],
    );
  }

  @override
  void onEventRestored(EventModel event) => _insert(event);

  @override
  void onEventAdded(EventModel event) => _insert(event);

  @override
  void onEventListStale(String clubId) {
    if (ref.mounted) unawaited(refresh());
  }

  // ─────────────────────────────── yardımcılar ──────────────────────────────

  /// [event]'i (aynı kimliğin eskisi yerine) `startsAt ↓` sırasına koyar.
  void _insert(EventModel event) {
    if (!ref.mounted) return;
    final events = [
      for (final e in state.events)
        if (e.id != event.id) e,
      event,
    ]..sort((a, b) => b.startsAt.compareTo(a.startsAt));
    state = state.copyWith(events: events);
  }

  /// MGT-01 paneli yaşıyorsa (yaklaşan etkinlikler, sayaç) içerik kalarak
  /// yenilenir.
  void _refreshPanel() {
    if (!ref.mounted) return;
    final panel = manageViewModelProvider(clubId);
    if (!ref.exists(panel)) return;
    unawaited(ref.read(panel.notifier).refresh());
  }

  Future<void> _startLoad() {
    final running = _loading;
    if (running != null) return running;
    final future = _load().whenComplete(() => _loading = null);
    return _loading = future;
  }

  /// Kulübü ve etkinlikleri baştan okur; ilk yüklemeyi / yenilemeyi bitirir.
  /// Etkinlikler okunamazsa (ve ekranda içerik yoksa) hata görünümü; kulüp
  /// okunamazsa liste yine gösterilir.
  Future<void> _load() async {
    final (club, events) = await (
      clubRepository.getClub(clubId),
      eventRepository.listClubEvents(
        clubId,
        const PageRequest(limit: Limits.upcomingEventsFetchMax),
        includeDrafts: true,
      ),
    ).wait;
    if (!ref.mounted) return;
    if (club case FirebaseFailure(:final error)) {
      AppLogger.warn('Etkinlik yönetimi: kulüp okunamadı: ${error.name}');
    }
    switch (events) {
      case FirebaseSuccess(:final data):
        state = state.copyWith(
          club: club.dataOrNull,
          events: [
            for (final e in data.items)
              if (!e.isDeleted) e,
          ],
          isFetching: false,
          isRefreshing: false,
          isError: false,
        );
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn(
          'Kulüp etkinlikleri okunamadı: ${error.name}',
          error: message,
        );
        state = state.copyWith(
          club: club.dataOrNull,
          isFetching: false,
          isRefreshing: false,
          isError: state.events.isEmpty,
        );
    }
  }
}

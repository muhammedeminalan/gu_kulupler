import 'dart:async';
import 'dart:math' as math;

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/events/provider/my_events_state.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/dialog_spec.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'my_events_view_model.g.dart';

/// Bir etkinlik sayfasının okuma sonucu.
typedef _Page = ({Map<String, EventModel> events, Map<String, String> names});

/// EVT-04 "Etkinliklerim" ekranının ViewModel'i (PLAN §12.6; prototip
/// `S['EVT-04']`, `screens-events.js:90–95`).
///
/// * Açılışta kullanıcının kayıtları tek sorguyla okunur
///   (`rsvpRepository.listMine`; repository imleç sunmaz — tam liste).
///   Etkinlikler kayıt sırasıyla [Limits.pageSize]'lık sayfalarla
///   (`eventRepository.getEvents`, tekil okumalar) ve kulüp adları toplu
///   (`clubRepository.getClubs`) gelir; sonraki sayfa liste sonuna
///   yaklaşınca [loadMore] ile. Seçili sekme boş kalırsa sıradaki sayfalar
///   kendiliğinden okunur.
/// * Sekme ayrımı `MyEventsState.tabOf` (saat `appClock`): geçmiş =
///   `endsAt < şimdi` ya da iptal; yaklaşan = kayıtlı ve bitmemiş; bekleme =
///   bekleme listesinde ve bitmemiş.
/// * Sheet açma ve gezinme view'dadır; dialog ve toast'lar buradan.
///
/// | İşlem | Koruma | Yazım | Geri bildirim |
/// |---|---|---|---|
/// | [fetch] / [refresh] | — | — | okunamadı → hata görünümü / içerik kalır |
/// | [loadMore] | — | — | okunamadı → liste olduğu gibi (yeniden kaydırınca dener) |
/// | [leave] | bitti TST-X6 (W-81 (b)) → DLG-14 → çevrimdışı TST-24 | iyimser gizle → `rsvpRepository.cancel` → `localReminderService.cancel` | TST-42 · hata → satır geri gelir + TST-X6 / TST-24 / TST-X18 |
///
/// Design: EVT-04, DLG-14
@riverpod
final class MyEventsViewModel extends _$MyEventsViewModel
    with ProjectDependencyMixin, WriteGuardMixin {
  bool _isLoading = false;

  /// İçeriğin kuşağı: her tam okumada artar; eski kuşağın sayfası yazılmaz.
  int _generation = 0;

  @override
  MyEventsState build() {
    // İlk okuma ilk karede başlar; view ayrıca çağırmaz.
    unawaited(Future<void>.microtask(_load));
    return const MyEventsState(isFetching: true);
  }

  String? get _uid =>
      ref.mounted ? ref.read(sessionViewModelProvider).uid : null;

  /// Seçili sekmenin satırları, şimdiki saate göre.
  List<MyEventEntry> get visible => state.visibleAt(appClock.nowUtc());

  // ───────────────────────────────── okuma ──────────────────────────────────

  /// Kayıtları yeniden okur — hata görünümündeki "Yeniden dene".
  Future<void> fetch() async {
    if (!ref.mounted || _isLoading) return;
    state = state.copyWith(isFetching: true, isError: false);
    await _load();
  }

  /// Çek-yenile: iskelet göstermeden baştan okur. Okunamazsa var olan
  /// içerik kalır.
  Future<void> refresh() async {
    if (!ref.mounted || _isLoading || state.isRefreshing) return;
    state = state.copyWith(isRefreshing: true);
    await _load();
  }

  /// Sonraki sayfanın etkinlikleri (liste sonuna yaklaşınca). Okunamazsa
  /// liste olduğu gibi kalır.
  Future<void> loadMore() async {
    if (!ref.mounted || _isLoading || !state.wantsMore) return;
    await _loadNextPage();
  }

  /// Sekme (`EVT-04.tab.<id>`). Yeni sekme boşsa sıradaki sayfalar okunur.
  void setTab(MyEventsTab tab) {
    if (tab == state.tab) return;
    state = state.copyWith(tab: tab);
    unawaited(_fillCurrentTab());
  }

  // ─────────────────────────────── vazgeçme ─────────────────────────────────

  /// "Vazgeç" / "Ayrıl" (`EVT-04.leave.<eventId>`): etkinlik bittiyse TST-X6
  /// (W-81 (b)); DLG-14 (bekleme listesinde ayrı metin) onaylanırsa satır
  /// iyimser gizlenir ve kayıt iptal edilir → yerel hatırlatıcı kaldırılır →
  /// TST-42. Yazılamazsa satır geri gelir. `true` → vazgeçildi.
  Future<bool> leave(String eventId) async {
    final uid = _uid;
    final entry = state.entryOf(eventId);
    if (uid == null || entry == null || state.pendingIds.contains(eventId)) {
      return false;
    }
    final (rsvp, event) = entry;
    if (!event.endsAt.isAfter(appClock.nowUtc())) {
      feedback.showToast(ToastId.tstX6);
      return false;
    }
    final confirmed =
        await feedback.showDialog<bool>(
          DialogId.dlg14,
          params: {
            DialogParamKeys.waitlist: rsvp.status == RsvpStatus.waitlist,
          },
        ) ??
        false;
    if (!confirmed || !ref.mounted || !ensureOnline()) return false;
    state = state.copyWith(pendingIds: {...state.pendingIds, eventId});
    final result = await rsvpRepository.cancel(eventId: eventId, userId: uid);
    switch (result) {
      case FirebaseSuccess():
        if (ref.mounted) {
          state = state.copyWith(
            rsvps: [
              for (final item in state.rsvps)
                item.eventId == eventId
                    ? item.copyWith(status: RsvpStatus.cancelled)
                    : item,
            ],
            pendingIds: {...state.pendingIds}..remove(eventId),
          );
        }
        await localReminderService.cancel(rsvp.id);
        feedback.showToast(ToastId.tst42);
        return true;
      case FirebaseFailure(:final error, :final detail, :final message):
        if (ref.mounted) {
          state = state.copyWith(
            pendingIds: {...state.pendingIds}..remove(eventId),
          );
        }
        _showLeaveFailure(error, detail, message);
        return false;
    }
  }

  // ────────────────────────────────── iç ────────────────────────────────────

  /// Kayıtları ve ilk sayfanın etkinliklerini okur; seçili sekme boşsa
  /// sıradaki sayfalar okunur.
  Future<void> _load() async {
    if (!ref.mounted || _isLoading) return;
    final uid = _uid;
    if (uid == null) {
      state = state.copyWith(isFetching: false, isRefreshing: false);
      return;
    }
    _isLoading = true;
    try {
      final result = await rsvpRepository.listMine(uid);
      if (!ref.mounted) return;
      final List<RsvpModel> rsvps;
      switch (result) {
        case FirebaseSuccess(:final data):
          rsvps = [
            for (final rsvp in data)
              if (!rsvp.isDeleted && rsvp.status != RsvpStatus.cancelled) rsvp,
          ];
        case FirebaseFailure(:final error, :final message):
          AppLogger.warn(
            'Etkinliklerim okunamadı: ${error.name}',
            error: message,
          );
          _failLoad();
          return;
      }
      final generation = ++_generation;
      final page = await _readPage(rsvps, 0, const {});
      if (!ref.mounted || generation != _generation) return;
      if (page == null) {
        _failLoad();
        return;
      }
      state = state.copyWith(
        rsvps: rsvps,
        events: page.events,
        clubNames: {...state.clubNames, ...page.names},
        loadedCount: math.min(Limits.pageSize, rsvps.length),
        isFetching: false,
        isRefreshing: false,
        isLoadingMore: false,
        isError: false,
      );
    } finally {
      _isLoading = false;
    }
    await _fillCurrentTab();
  }

  void _failLoad() {
    state = state.copyWith(
      isFetching: false,
      isRefreshing: false,
      isError: state.loadedCount == 0,
    );
  }

  /// Seçili sekme boşken sıradaki sayfaları okur (sayfa okunamazsa durur).
  Future<void> _fillCurrentTab() async {
    while (ref.mounted &&
        !_isLoading &&
        state.wantsMore &&
        state.visibleAt(appClock.nowUtc()).isEmpty) {
      if (!await _loadNextPage()) return;
    }
  }

  /// Sıradaki sayfa; okunduysa `true`.
  Future<bool> _loadNextPage() async {
    final generation = _generation;
    final from = state.loadedCount;
    state = state.copyWith(isLoadingMore: true);
    final page = await _readPage(state.rsvps, from, state.clubNames);
    if (!ref.mounted) return false;
    if (generation != _generation || page == null) {
      // Liste bu arada baştan okundu ya da sayfa okunamadı.
      state = state.copyWith(isLoadingMore: false);
      return false;
    }
    state = state.copyWith(
      events: {...state.events, ...page.events},
      clubNames: {...state.clubNames, ...page.names},
      loadedCount: math.min(from + Limits.pageSize, state.rsvps.length),
      isLoadingMore: false,
    );
    return true;
  }

  /// [rsvps] listesinin [from] konumundan başlayan sayfasının etkinlikleri ve
  /// [known] dışındaki kulüp adları. Etkinlikler okunamazsa `null`; kulüp
  /// adları okunamazsa satırlar adsız çizilir.
  Future<_Page?> _readPage(
    List<RsvpModel> rsvps,
    int from,
    Map<String, String> known,
  ) async {
    final ids = [
      for (final rsvp in rsvps.skip(from).take(Limits.pageSize)) rsvp.eventId,
    ];
    if (ids.isEmpty) {
      return (
        events: const <String, EventModel>{},
        names: const <String, String>{},
      );
    }
    final result = await eventRepository.getEvents(ids);
    final List<EventModel> events;
    switch (result) {
      case FirebaseSuccess(:final data):
        events = data;
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn(
          'Etkinliklerim: etkinlikler okunamadı: ${error.name}',
          error: message,
        );
        return null;
    }
    final clubIds = {
      for (final event in events)
        if (!known.containsKey(event.clubId)) event.clubId,
    }.toList();
    final names = <String, String>{};
    if (clubIds.isNotEmpty) {
      switch (await clubRepository.getClubs(
        clubIds,
        forceRefresh: state.isRefreshing,
      )) {
        case FirebaseSuccess(:final data):
          for (final club in data) {
            names[club.id] = club.name;
          }
        case FirebaseFailure(:final error):
          AppLogger.warn('Etkinliklerim: kulüpler okunamadı: ${error.name}');
      }
    }
    return (
      events: {for (final event in events) event.id: event},
      names: names,
    );
  }

  /// Vazgeçme yazımının bildirimi: bitti TST-X6 · ağ TST-24 · yetki TST-X18;
  /// zaten iptal / yok / yoklaması alınmış → liste yenilenir; kalanı günlüğe.
  void _showLeaveFailure(
    FirestoreError error,
    Object? detail,
    String? message,
  ) {
    if (error == FirestoreError.ruleViolation &&
        detail is FirestoreFailureDetail &&
        detail.code == FirestoreRuleCode.eventEnded) {
      feedback.showToast(ToastId.tstX6);
      unawaited(refresh());
      return;
    }
    if (showWriteFailureToast(error)) return;
    AppLogger.warn('Katılımdan vazgeçilemedi: ${error.name}', error: message);
    if (error == FirestoreError.conflict ||
        error == FirestoreError.notFound ||
        error == FirestoreError.failedPrecondition) {
      unawaited(refresh());
    }
  }
}

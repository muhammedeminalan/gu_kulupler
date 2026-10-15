import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/profile/provider/my_clubs_state.dart';
import 'package:gu_kulupler/product/feedback/catalogs/toasts/toast_catalog.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/mixin/manage_member_actions_mixin.dart';
import 'package:gu_kulupler/product/mixin/membership_dialogs_mixin.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';
import 'package:gu_kulupler/product/navigation/my_clubs_tab.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'my_clubs_view_model.g.dart';

/// PRF-03 "Ayrıl" akışının sonucu ([MyClubsViewModel.leave]).
enum MyClubLeaveOutcome {
  /// Ayrılındı (TST-39 gösterildi).
  left,

  /// Kullanıcı vazgeçti (DLG-08 "Vazgeç", scrim, geri).
  cancelled,

  /// Başkan devretmeden ayrılamaz: DLG-09 "Tamam" ile kapandı.
  solePresident,

  /// DLG-09'da "Başkanlığı devret" seçildi: devir akışını view başlatır
  /// (SHT-25 → DLG-21, T-33).
  transferRequested,

  /// Ayrılma olmadı: süren işlem, çevrimdışı (TST-24), yetki yok (TST-X18)
  /// ya da beklenmeyen hata (satır geri döner).
  failed,
}

/// PRF-03 "Kulüplerim" ekranının ViewModel'i (PLAN §12.6; prototip
/// `S['PRF-03']`, `screens-profile.js:40–49`).
///
/// * Üyelikler oturumdan gelir (`SessionState.memberships` — tek canlı
///   dinleyici `watchMyMemberships`, her durum); ekran ayrıca sorgu atmaz.
///   Kulüpler toplu okunur (`clubRepository.getClubs`); akışa yeni kulüp
///   girerse yalnızca o kulüp okunur. Çek-yenile üyelikleri
///   `membershipRepository.listMine` ile, kulüpleri baştan okur.
/// * Ayrılma / iptal iyimserdir: satır onaydan sonra "Geçmiş"e geçer,
///   yazım reddedilirse eski sekmesine döner.
///
/// | İşlem | Koruma | Yazım | Geri bildirim |
/// |---|---|---|---|
/// | [fetch] / [refresh] | — | — | okunamadı → hata görünümü / içerik kalır |
/// | [cancelApplication] | DLG-07 → çevrimdışı TST-24 | iyimser `cancelled` → `cancelApplication` | TST-40 · hata → geri + TST-24 / TST-X18 |
/// | [leave] | başkan DLG-09 · DLG-08 → çevrimdışı TST-24 | iyimser `left` → `leave` | TST-39 · hata → geri + toast / DLG-09 |
/// | [reapply] | bekleme süresi → TST-X4 | — (başvuru CLB-05'te) | — |
/// | [transferPresidencyForLeave] (W-14) | DLG-09 "Başkanlığı devret" → SHT-25 → DLG-21 | M11 (`ManageMemberActionsMixin`) | TST-49; üyelikler yenilenir |
///
/// Design: PRF-03, DLG-07, DLG-08, DLG-09
@riverpod
final class MyClubsViewModel extends _$MyClubsViewModel
    with
        ProjectDependencyMixin,
        WriteGuardMixin,
        MembershipDialogsMixin,
        ManageMemberActionsMixin {
  bool _isLoading = false;

  /// Onay dialogu açık mı? Beklerken gelen ikinci istek yok sayılır.
  bool _isConfirming = false;

  @override
  MyClubsState build() {
    ref.listen(
      sessionViewModelProvider.select((session) => session.memberships),
      (_, next) => _onSessionMemberships(next),
    );
    // İlk okuma ilk karede başlar; view ayrıca çağırmaz.
    unawaited(Future<void>.microtask(_load));
    return MyClubsState(
      memberships: ref.read(sessionViewModelProvider).memberships,
      isFetching: true,
    );
  }

  String? get _uid =>
      ref.mounted ? ref.read(sessionViewModelProvider).uid : null;

  /// Seçili sekmenin satırları.
  List<MyClubEntry> get visible => state.visible;

  // ───────────────────────────────── okuma ──────────────────────────────────

  /// Kulüpleri yeniden okur — hata görünümündeki "Yeniden dene".
  Future<void> fetch() async {
    if (!ref.mounted || _isLoading) return;
    state = state.copyWith(isFetching: true, isError: false);
    await _load();
  }

  /// Çek-yenile: üyelikler (`listMine`) ve kulüpler baştan okunur. Okunamazsa
  /// var olan içerik kalır.
  Future<void> refresh() async {
    final uid = _uid;
    if (uid == null || _isLoading || state.isRefreshing) return;
    _isLoading = true;
    state = state.copyWith(isRefreshing: true);
    try {
      switch (await membershipRepository.listMine(uid)) {
        case FirebaseSuccess(:final data):
          if (!ref.mounted) return;
          state = state.copyWith(
            memberships: _withPending({
              for (final membership in data) membership.clubId: membership,
            }),
          );
        case FirebaseFailure(:final error, :final message):
          AppLogger.warn(
            'Kulüplerim: üyelikler okunamadı: ${error.name}',
            error: message,
          );
      }
      if (!ref.mounted) return;
      final ok = await _readClubs(state.memberships.keys, force: true);
      if (!ref.mounted) return;
      state = state.copyWith(
        isRefreshing: false,
        isError: !ok && state.isError,
      );
    } finally {
      _isLoading = false;
    }
  }

  /// Sekme (`PRF-03.tab.<id>`; rota `?tab=`).
  void setTab(MyClubsTab tab) {
    if (tab == state.tab) return;
    state = state.copyWith(tab: tab);
  }

  // ──────────────────────────────── eylemler ────────────────────────────────

  /// "İsteği iptal et" (`PRF-03.menu.<id>.cancel`): DLG-07 onayı → satır
  /// iyimser "Geçmiş"e geçer → `cancelApplication` → TST-40. Yazılamazsa
  /// satır "Bekleyen"e döner; başvuru bu arada karara bağlandıysa
  /// (`conflict`) üyelikler yenilenir. `true` → iptal edildi.
  Future<bool> cancelApplication(String clubId) async {
    final uid = _uid;
    final entry = state.entryOf(clubId);
    if (uid == null || entry == null || !_canStart(clubId)) return false;
    final (membership, club) = entry;
    if (membership.status != MembershipStatus.pending) return false;
    _isConfirming = true;
    final bool confirmed;
    try {
      confirmed = await confirmCancelApplication(clubName: club.name);
    } finally {
      _isConfirming = false;
    }
    if (!confirmed || !ref.mounted || !ensureOnline()) return false;
    _begin(membership.copyWith(status: MembershipStatus.cancelled));
    final result = await membershipRepository.cancelApplication(
      clubId: clubId,
      userId: uid,
    );
    switch (result) {
      case FirebaseSuccess():
        _end(clubId);
        feedback.showToast(ToastId.tst40);
        return true;
      case FirebaseFailure(:final error, :final message):
        _rollback(membership);
        _onWriteFailure(error, message, 'Başvuru iptal edilemedi');
        return false;
    }
  }

  /// "Kulüpten ayrıl" (`PRF-03.menu.<id>.leave`): başkan → DLG-09 (onay
  /// sorulmaz, `screens-profile.js:47`); diğerleri DLG-08 onayı → satır
  /// iyimser "Geçmiş"e geçer → `leave` → TST-39. Sunucu başkanlık kuralını
  /// söylerse satır döner ve DLG-09 gösterilir.
  Future<MyClubLeaveOutcome> leave(String clubId) async {
    final uid = _uid;
    final entry = state.entryOf(clubId);
    if (uid == null || entry == null || !_canStart(clubId)) {
      return MyClubLeaveOutcome.failed;
    }
    final (membership, club) = entry;
    if (membership.status != MembershipStatus.active) {
      return MyClubLeaveOutcome.failed;
    }
    _isConfirming = true;
    try {
      if (membership.role == ClubRole.president) return await _solePresident();
      if (!await confirmLeaveClub(clubName: club.name)) {
        return MyClubLeaveOutcome.cancelled;
      }
    } finally {
      _isConfirming = false;
    }
    if (!ref.mounted || !ensureOnline()) return MyClubLeaveOutcome.failed;
    _begin(membership.copyWith(status: MembershipStatus.left));
    final result = await membershipRepository.leave(
      clubId: clubId,
      userId: uid,
    );
    switch (result) {
      case FirebaseSuccess():
        _end(clubId);
        feedback.showToast(ToastId.tst39);
        return MyClubLeaveOutcome.left;
      case FirebaseFailure(
        error: FirestoreError.ruleViolation,
        detail: FirestoreFailureDetail(
          code: FirestoreRuleCode.presidentCannotLeave,
        ),
      ):
        _rollback(membership);
        return _solePresident();
      case FirebaseFailure(:final error, :final message):
        _rollback(membership);
        _onWriteFailure(error, message, 'Kulüpten ayrılınamadı');
        return MyClubLeaveOutcome.failed;
    }
  }

  /// "Tekrar başvur" (`PRF-03.menu.<id>.reapply`; reddedilen / çıkarılan):
  /// bekleme süresi dolmadıysa TST-X4 ([formatDate] ile biçimlenen tarih) →
  /// `false`; dolduysa `true` (view başvuru durumuna — CLB-05 — gider,
  /// başvuru orada yeniden açılır).
  bool reapply(String clubId, {required String Function(DateTime) formatDate}) {
    final membership = state.memberships[clubId];
    if (membership == null) return false;
    final until = membership.retryAfter;
    if (until != null && until.isAfter(appClock.nowUtc())) {
      feedback.showToast(
        ToastId.tstX4,
        params: ToastParams(date: formatDate(until)),
      );
      return false;
    }
    return true;
  }

  // ────────────────────────────────── iç ────────────────────────────────────

  /// İlk okuma: oturumdaki üyeliklerin kulüpleri.
  Future<void> _load() async {
    if (!ref.mounted || _isLoading) return;
    if (_uid == null) {
      state = state.copyWith(isFetching: false, isRefreshing: false);
      return;
    }
    _isLoading = true;
    final requested = state.memberships.keys.toSet();
    try {
      final ok = await _readClubs(requested);
      if (!ref.mounted) return;
      state = state.copyWith(
        isFetching: false,
        isError: !ok && state.clubs.isEmpty,
      );
    } finally {
      _isLoading = false;
    }
    // Okuma sürerken akışa giren kulüpler.
    final arrived = state.memberships.keys.toSet().difference(requested);
    if (arrived.isNotEmpty) unawaited(_readClubs(arrived));
  }

  /// [clubIds] kulüplerini okur ([force] değilse yalnızca bilinmeyenler).
  /// Okundu ya da okunacak kulüp yoksa `true`. Silinmiş / görünmeyen kulüp
  /// atlanır (hepsi görünmezse de boş sonuç sayılır).
  Future<bool> _readClubs(
    Iterable<String> clubIds, {
    bool force = false,
  }) async {
    final ids = [
      for (final id in clubIds)
        if (force || !state.clubs.containsKey(id)) id,
    ];
    if (ids.isEmpty) return true;
    // `force` (yenileme) bellek önbelleğini de atlar (T-44 · D3-01).
    switch (await clubRepository.getClubs(ids, forceRefresh: force)) {
      case FirebaseSuccess(:final data):
        if (ref.mounted) {
          state = state.copyWith(
            clubs: {
              ...state.clubs,
              for (final club in data) club.id: club,
            },
          );
        }
        return true;
      case FirebaseFailure(
        error: FirestoreError.permissionDenied || FirestoreError.notFound,
      ):
        return true;
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn(
          'Kulüplerim: kulüpler okunamadı: ${error.name}',
          error: message,
        );
        return false;
    }
  }

  /// Oturumun üyelik akışı değişti: yazımı süren satırlar iyimser hâlinde
  /// kalır; akışa yeni giren kulüpler okunur.
  void _onSessionMemberships(Map<String, MembershipModel> next) {
    if (!ref.mounted) return;
    state = state.copyWith(memberships: _withPending(next));
    if (!state.isFetching) unawaited(_readClubs(next.keys));
  }

  /// [memberships] + yazımı süren satırların iyimser kopyası.
  Map<String, MembershipModel> _withPending(
    Map<String, MembershipModel> memberships,
  ) => {
    ...memberships,
    for (final id in state.pendingIds) id: ?state.memberships[id],
  };

  bool _canStart(String clubId) =>
      !_isConfirming && !state.pendingIds.contains(clubId);

  /// İyimser geçiş: satır [optimistic] durumuyla yeni sekmesine geçer.
  void _begin(MembershipModel optimistic) {
    state = state.copyWith(
      memberships: {...state.memberships, optimistic.clubId: optimistic},
      pendingIds: {...state.pendingIds, optimistic.clubId},
    );
  }

  void _end(String clubId) {
    if (!ref.mounted) return;
    state = state.copyWith(pendingIds: {...state.pendingIds}..remove(clubId));
  }

  /// Yazım reddedildi: satır [previous] hâline döner.
  void _rollback(MembershipModel previous) {
    if (!ref.mounted) return;
    state = state.copyWith(
      memberships: {...state.memberships, previous.clubId: previous},
      pendingIds: {...state.pendingIds}..remove(previous.clubId),
    );
  }

  @override
  SessionState? get memberSession =>
      ref.mounted ? ref.read(sessionViewModelProvider) : null;

  /// DLG-09 "Başkanlığı devret" (W-14): [clubId] için SHT-25 → DLG-21 → M11
  /// → TST-49. Devredildiyse `true`.
  Future<bool> transferPresidencyForLeave(String clubId) =>
      transferPresidency(clubId);

  @override
  void onPresidencyTransferred(
    String clubId, {
    required String fromUserId,
    required String toUserId,
  }) {
    if (ref.mounted) unawaited(refresh());
  }

  Future<MyClubLeaveOutcome> _solePresident() async =>
      await showSolePresidentDialog()
      ? MyClubLeaveOutcome.transferRequested
      : MyClubLeaveOutcome.solePresident;

  /// Yazma hatası: ağ TST-24 · yetki TST-X18; durum çakışması (karar bu
  /// arada verildi) ya da kayıp belge → üyelikler yenilenir; kalanı günlüğe.
  void _onWriteFailure(FirestoreError error, String? message, String what) {
    if (showWriteFailureToast(error)) return;
    AppLogger.warn('$what: ${error.name}', error: message);
    if (error == FirestoreError.conflict ||
        error == FirestoreError.notFound ||
        error == FirestoreError.ruleViolation) {
      unawaited(refresh());
    }
  }
}

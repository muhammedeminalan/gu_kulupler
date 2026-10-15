import 'dart:async';

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/admin/provider/admin_clubs_state.dart';
import 'package:gu_kulupler/features/admin/provider/admin_president_candidates_mixin.dart';
import 'package:gu_kulupler/product/feedback/catalogs/toasts/toast_catalog.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';
import 'package:gu_kulupler/product/navigation/admin_clubs_tab.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'admin_clubs_view_model.g.dart';

/// ADM-02 "Kulüpler" ViewModel'i (PLAN §12 `AdminClubsViewModel`; prototip
/// `AdminClubs`, `screens-admin.js:29–35`).
///
/// * Okuma (ilk açılış, "Yeniden dene", çek-yenile): `clubRepository
///   .fetchActiveClubs()` (askıdakiler dahil) + başkan adları
///   (`userRepository.getUsers`; okunamazsa adlar çizilmez, liste kalır).
///   Sekme ([setTab]) ve arama ([setQuery]) istemcidedir.
/// * Askıya al ([suspend], DLG-28 neden zorunlu) / etkinleştir
///   ([activate]) iyimserdir: satır hemen öbür sekmeye geçer; yazım
///   başarısızsa geri döner. Başarı → TST-50.
/// * Başkanı değiştir ([presidentCandidates] → SHT-25 atama kipi →
///   [assignPresident]) → TST-49; ardından liste sessizce yenilenir (üye
///   sayısı değişebilir).
/// * `permissionDenied` → claim sunucudan yenilenir
///   (`SessionViewModel.refreshClaims` — CD-160); süper admin hâlâ
///   geçerliyse çağrı bir kez yinelenir, değilse router guard'ı (`S`)
///   sekmeyi kapatır (yazımda TST-X18).
/// * Çevrimdışı yazım TST-24 (`WriteGuardMixin`).
///
/// Design: ADM-02
@riverpod
final class AdminClubsViewModel extends _$AdminClubsViewModel
    with
        ProjectDependencyMixin,
        WriteGuardMixin,
        AdminPresidentCandidatesMixin {
  /// Okuma turu sayacı: eski turun geç gelen sonucu atılır.
  int _epoch = 0;

  @override
  AdminClubsState build() {
    unawaited(Future<void>.microtask(_load));
    return const AdminClubsState(isFetching: true);
  }

  /// "Yeniden dene" (`ADM-02.retry`): iskeletle baştan okur.
  Future<void> fetch() async {
    if (!ref.mounted) return;
    state = state.copyWith(isFetching: true, isError: false);
    await _load();
  }

  /// Çek-yenile: içerik kalır, liste yeniden okunur.
  Future<void> refresh() async {
    if (!ref.mounted || state.isRefreshing) return;
    if (!state.isLoaded) return fetch();
    state = state.copyWith(isRefreshing: true);
    await _load();
  }

  /// Sekme (`ADM-02.tab.<name>`).
  void setTab(AdminClubsTab tab) {
    if (tab == state.tab) return;
    state = state.copyWith(tab: tab);
  }

  /// Arama (`ADM-02.search`).
  void setQuery(String query) {
    if (query == state.query) return;
    state = state.copyWith(query: query);
  }

  /// DLG-28 "Askıya al" — [clubId] kulübünü [reason] gerekçesiyle askıya
  /// alır (iyimser; başarı → TST-50). Yazıldıysa `true`.
  Future<bool> suspend(String clubId, String reason) {
    final trimmed = reason.trim();
    return _setStatus(
      clubId,
      to: ClubStatus.suspended,
      reason: trimmed,
      call: () => adminRepository.suspendClub(clubId, reason: trimmed),
    );
  }

  /// DLG-28 "Etkinleştir" — askıdaki [clubId] kulübünü etkinleştirir
  /// (iyimser; başarı → TST-50). Yazıldıysa `true`.
  Future<bool> activate(String clubId) => _setStatus(
    clubId,
    to: ClubStatus.active,
    call: () => adminRepository.activateClub(clubId),
  );

  /// SHT-25 atama kipinin aday havuzu ([readPresidentCandidates]): kulübün
  /// başkanı ve bağlı danışmanı hariç. Okunamazsa `null` (ağ → TST-24,
  /// yetki → TST-X18).
  Future<List<UserModel>?> presidentCandidates(String clubId) async {
    final club = state.clubById(clubId);
    if (club == null || !ensureOnline()) return null;
    final excluded = {club.presidentId, club.advisor?.userId};
    final result = await _withClaims(
      () => readPresidentCandidates(excluded: excluded),
    );
    if (!ref.mounted) return null;
    switch (result) {
      case FirebaseSuccess(:final data):
        return data;
      case FirebaseFailure(:final error, :final message):
        if (!showWriteFailureToast(error)) {
          AppLogger.warn(
            'Başkan adayları okunamadı: ${error.name}',
            error: message,
          );
        }
        return null;
    }
  }

  /// SHT-25 "Başkan ata" — [clubId] kulübünün başkanlığını [user]'a verir
  /// (`adminRepository.assignPresident`; başarı → TST-49 + sessiz yenileme).
  /// Yazıldıysa `true`.
  Future<bool> assignPresident(String clubId, UserModel user) async {
    final club = state.clubById(clubId);
    final actorId = ref.read(sessionViewModelProvider).uid;
    if (club == null ||
        actorId == null ||
        state.pendingIds.contains(clubId) ||
        user.uid == club.presidentId) {
      return false;
    }
    if (!ensureOnline()) return false;
    _setPending(clubId, pending: true);
    final result = await _withClaims(
      () => adminRepository.assignPresident(
        clubId: clubId,
        toUserId: user.uid,
        actorId: actorId,
      ),
    );
    if (!ref.mounted) return false;
    _setPending(clubId, pending: false);
    switch (result) {
      case FirebaseSuccess():
        state = state.copyWith(
          clubs: _replace(club.copyWith(presidentId: user.uid)),
          presidents: {...state.presidents, user.uid: user},
        );
        feedback.showToast(ToastId.tst49, params: ToastParams(name: user.name));
        unawaited(refresh());
        return true;
      case FirebaseFailure(:final error, :final message):
        _onWriteFailure(error, message, 'Başkan atanamadı');
        return false;
    }
  }

  // ───────────────────────────────── yazım ──────────────────────────────────

  Future<bool> _setStatus(
    String clubId, {
    required ClubStatus to,
    required Future<FirestoreResult<void>> Function() call,
    String? reason,
  }) async {
    final original = state.clubById(clubId);
    if (original == null ||
        original.status == to ||
        state.pendingIds.contains(clubId)) {
      return false;
    }
    if (!ensureOnline()) return false;
    final suspending = to == ClubStatus.suspended;
    state = state.copyWith(
      clubs: _replace(
        original.copyWith(
          status: to,
          suspendReason: reason,
          clearSuspendReason: !suspending,
        ),
      ),
      pendingIds: {...state.pendingIds, clubId},
    );
    final result = await _withClaims(call);
    if (!ref.mounted) return false;
    switch (result) {
      case FirebaseSuccess():
        _setPending(clubId, pending: false);
        feedback.showToast(
          ToastId.tst50,
          params: ToastParams(suspended: suspending),
        );
        return true;
      case FirebaseFailure(:final error, :final message):
        state = state.copyWith(
          clubs: _replace(original),
          pendingIds: {...state.pendingIds}..remove(clubId),
        );
        _onWriteFailure(
          error,
          message,
          suspending ? 'Kulüp askıya alınamadı' : 'Kulüp etkinleştirilemedi',
        );
        return false;
    }
  }

  /// Yazma hatası: ağ TST-24 · yetki TST-X18; durum çakışması ya da kayıp
  /// belge → liste yenilenir; kalanı günlüğe.
  void _onWriteFailure(FirestoreError error, String? message, String what) {
    if (showWriteFailureToast(error)) return;
    AppLogger.warn('$what: ${error.name}', error: message);
    if (error == FirestoreError.conflict ||
        error == FirestoreError.notFound ||
        error == FirestoreError.ruleViolation) {
      unawaited(refresh());
    }
  }

  void _setPending(String clubId, {required bool pending}) {
    final ids = {...state.pendingIds};
    pending ? ids.add(clubId) : ids.remove(clubId);
    state = state.copyWith(pendingIds: ids);
  }

  /// [club] ile değiştirilmiş kulüp listesi (aynı sıra).
  List<ClubModel> _replace(ClubModel club) => [
    for (final c in state.clubs) c.id == club.id ? club : c,
  ];

  // ───────────────────────────────── okuma ──────────────────────────────────

  Future<void> _load() async {
    final epoch = ++_epoch;
    final clubs = await _withClaims(clubRepository.fetchActiveClubs);
    if (!_live(epoch)) return;
    switch (clubs) {
      case FirebaseSuccess(:final data):
        final presidents = await _readPresidents(data);
        if (!_live(epoch)) return;
        // Yazımı süren kulübün iyimser hâli korunur.
        final pending = state.pendingIds;
        state = state.copyWith(
          clubs: [
            for (final club in data)
              pending.contains(club.id)
                  ? state.clubById(club.id) ?? club
                  : club,
          ],
          presidents: presidents,
          isLoaded: true,
          isFetching: false,
          isRefreshing: false,
          isError: false,
        );
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn(
          'Admin kulüpleri okunamadı: ${error.name}',
          error: message,
        );
        // Çek-yenilemede eski içerik kalır; ilk açılışta hata görünümü.
        state = state.copyWith(
          isFetching: false,
          isRefreshing: false,
          isError: !state.isLoaded || state.isFetching,
        );
    }
  }

  /// [clubs] başkanlarının profilleri; okunamazsa öncekiler.
  Future<Map<String, UserModel>> _readPresidents(List<ClubModel> clubs) async {
    final ids = {for (final club in clubs) club.presidentId}.toList();
    if (ids.isEmpty) return const {};
    switch (await userRepository.getUsers(ids)) {
      case FirebaseSuccess(:final data):
        return {for (final user in data) user.uid: user};
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn(
          'Başkan adları okunamadı: ${error.name}',
          error: message,
        );
        return state.presidents;
    }
  }

  /// [call]'ı koşar; `permissionDenied` alınırsa claim'i yeniler ve süper
  /// admin hâlâ geçerliyse bir kez yineler (CD-160).
  Future<FirestoreResult<T>> _withClaims<T>(
    Future<FirestoreResult<T>> Function() call,
  ) async {
    final result = await call();
    if (result.errorOrNull != FirestoreError.permissionDenied || !ref.mounted) {
      return result;
    }
    final session = ref.read(sessionViewModelProvider.notifier);
    await session.refreshClaims();
    if (!ref.mounted || !ref.read(sessionViewModelProvider).isSuperAdmin) {
      return result;
    }
    return call();
  }

  bool _live(int epoch) => ref.mounted && epoch == _epoch;
}

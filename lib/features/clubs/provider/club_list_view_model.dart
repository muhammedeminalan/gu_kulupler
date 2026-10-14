import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show VoidCallback;

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/clubs/provider/club_detail_view_model.dart';
import 'package:gu_kulupler/features/clubs/provider/club_filters.dart';
import 'package:gu_kulupler/features/clubs/provider/club_list_state.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/mixin/club_join_mixin.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'club_list_view_model.g.dart';

/// CLB-01 "Kulüpler" ekranının ViewModel'i (PLAN §12.6; prototip
/// `S['CLB-01']`, `screens-clubs.js:19–33`).
///
/// * Kulüpleri açılışta tek seferde okur (`clubRepository.fetchActiveClubs`,
///   ≤ `Limits.clubsFetchMax`); süzme ve sıralama istemcidedir
///   (`ClubListState.visible`, `ClubFilters.apply`). Üyelikler oturumdan canlı
///   gelir.
/// * Yönetici önizlemesi (liste kartındaki avatar grubu, CD-139) kart ekrana
///   geldikçe okunur ve kulüp başına bir kez okunup saklanır ([loadPreview]).
/// * Sheet açma ve gezinme view'dadır; [join] hangisinin gerektiğini sonuç
///   değeriyle söyler (`ClubJoinMixin` — CLB-03 ile aynı çekirdek).
///
/// | İşlem | Sonuç | Geri bildirim |
/// |---|---|---|
/// | [join] | başvuru kapalı | TST-X1 |
/// | | bekleme sürüyor | view → CLB-05 |
/// | | onay gerekli / yeniden başvuru | view → SHT-05 |
/// | | onaysız kulüp: katıldı | kart anında "üye" + üye sayısı + 1, TST-34 |
/// | | onaysız kulüp: yazılamadı | geri alınır; TST-X1 · TST-X4 · TST-24 · TST-X18 |
/// | [refresh] | okunamadı | içerik kalır; içerik yoksa hata görünümü |
///
/// Design: CLB-01
@riverpod
final class ClubListViewModel extends _$ClubListViewModel
    with ProjectDependencyMixin, WriteGuardMixin, ClubJoinMixin {
  bool _isLoading = false;

  /// Yönetici önizlemesi okunmakta olan kulüpler (eşzamanlı tek okuma).
  final Set<String> _previewRequests = <String>{};

  /// Anında katılım yazımı süren kulüpler.
  final Set<String> _joinWrites = <String>{};

  @override
  ClubListState build() {
    ref.listen(sessionViewModelProvider, (_, session) => _onSession(session));
    // Kulüpler ilk karede okunmaya başlar; view ayrıca çağırmaz.
    unawaited(Future<void>.microtask(_load));
    return ClubListState(
      memberClubIds: _memberClubIds(ref.read(sessionViewModelProvider)),
      isFetching: true,
    );
  }

  /// Kulüpleri yeniden okur — hata görünümündeki "Yeniden dene". Süren okuma
  /// varken gelen çağrı yok sayılır.
  Future<void> fetch() async {
    if (!ref.mounted || _isLoading) return;
    state = state.copyWith(isFetching: true, isError: false);
    await _load();
  }

  /// Çek-yenile (`CLB-01.refresh`): listeyi iskelet göstermeden yeniler.
  /// Okunamazsa var olan içerik kalır; içerik yoksa hata görünümü.
  Future<void> refresh() async {
    if (!ref.mounted || _isLoading || state.isRefreshing) return;
    state = state.copyWith(isRefreshing: true);
    final result = await clubRepository.fetchActiveClubs();
    if (!ref.mounted) return;
    switch (result) {
      case FirebaseSuccess(:final data):
        state = state.copyWith(
          clubs: data,
          isRefreshing: false,
          isFetching: false,
          isError: false,
        );
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn('Kulüpler yenilenemedi: ${error.name}', error: message);
        state = state.copyWith(
          isRefreshing: false,
          isError: state.clubs.isEmpty,
        );
    }
  }

  /// Kategori çipi (`CLB-01.category.<id>`; `null` = "Tümü"). Seçili tek
  /// kategoriye yeniden dokunmak seçimi kaldırır (`screens-clubs.js:27`).
  void setCategory(String? categoryId) {
    final clear =
        categoryId == null || state.filters.singleCategoryId == categoryId;
    setFilters(
      state.filters.copyWith(categoryIds: clear ? const {} : {categoryId}),
    );
  }

  /// PRF-01 ilgi alanı çipi (`clubCategoryRequestProvider`): süzgeci tek
  /// [categoryId] kategorisine çevirir, diğer süzgeçler korunur
  /// (`screens-profile.js:16`). [setCategory]'den farkı: seçili kategoriye
  /// yeniden istek seçimi kaldırmaz.
  void showCategory(String categoryId) =>
      setFilters(state.filters.copyWith(categoryIds: {categoryId}));

  /// SHT-04 "Sonuçları göster": süzgeç ve sıralamayı uygular.
  void setFilters(ClubFilters filters) {
    if (filters == state.filters) return;
    state = state.copyWith(filters: filters);
  }

  /// "Filtreleri temizle" (`CLB-01.clearFilters`).
  void clearFilters() => setFilters(ClubFilters.none);

  /// [filters] süzgecine uyan kulüp sayısı (SHT-04 "Sonuçları göster (n)").
  int countFor(ClubFilters filters) =>
      filters.apply(state.clubs, memberClubIds: state.memberClubIds).length;

  /// Liste ↔ ızgara (`CLB-01.toggleView`).
  void toggleLayout() {
    state = state.copyWith(
      layout: state.layout == ClubListLayout.list
          ? ClubListLayout.grid
          : ClubListLayout.list,
    );
  }

  /// [clubId] kulübünün yönetici önizlemesini okur
  /// (`membershipRepository.listManagers`, CD-139). Kulüp başına bir kez
  /// okunur ve ViewModel yaşadıkça saklanır; okunamazsa kart avatar grubu
  /// olmadan kalır ve kart yeniden ekrana geldiğinde bir kez daha denenir.
  Future<void> loadPreview(String clubId) async {
    if (!ref.mounted ||
        state.managerPreviews.containsKey(clubId) ||
        !_previewRequests.add(clubId)) {
      return;
    }
    final result = await membershipRepository.listManagers(clubId);
    _previewRequests.remove(clubId);
    if (!ref.mounted) return;
    if (result case FirebaseSuccess(:final data)) {
      state = state.copyWith(
        managerPreviews: {
          ...state.managerPreviews,
          clubId: ClubDetailViewModel.presidentFirst(data),
        },
      );
    }
  }

  /// "Katıl" (`CLB-01.join.<clubId>`): katılım akışının girişi (prototip
  /// `startJoin`, `cards.js:12–18`; karar `ClubJoinMixin.joinGate`).
  ///
  /// Onaysız kulüpte katılım iyimserdir: kart hemen "üye" çizilir
  /// (`pendingJoinIds`) ve üye sayısı 1 artar; yazım başarısız olursa ikisi
  /// de geri alınır. Aynı kulüp için süren yazım varken gelen çağrı yok
  /// sayılır.
  ///
  /// [formatDate] TST-X4'ün `{date}` metnini üretir; [onOpenClub] TST-34'ün
  /// "Kulübe git" eylemidir.
  Future<JoinOutcome> join(
    String clubId, {
    required String Function(DateTime retryAfter) formatDate,
    VoidCallback? onOpenClub,
  }) async {
    final club = state.clubById(clubId);
    if (club == null ||
        club.isSuspended ||
        state.pendingJoinIds.contains(clubId)) {
      return JoinOutcome.failed;
    }
    final session = ref.read(sessionViewModelProvider);
    final membership = session.memberships[clubId];
    if (joinGate(club, membership) case final outcome?) return outcome;
    if (!ensureOnline()) return JoinOutcome.failed;
    final applicant = session.user;
    final email = authRepository.currentUser?.email;
    if (applicant == null || email == null) {
      AppLogger.warn('Kulübe katılınamadı: oturumda profil / e-posta yok');
      return JoinOutcome.failed;
    }

    _joinWrites.add(clubId);
    state = state.copyWith(
      clubs: _withMemberDelta(clubId, 1),
      pendingJoinIds: {...state.pendingJoinIds, clubId},
    );
    final result = await membershipRepository.joinInstant(
      clubId: clubId,
      applicant: applicant,
      email: email,
    );
    _joinWrites.remove(clubId);
    if (!ref.mounted) {
      return result.isSuccess ? JoinOutcome.joined : JoinOutcome.failed;
    }
    switch (result) {
      case FirebaseSuccess():
        // Oturum üyeliği gösterene dek kart iyimser kalır.
        _onSession(ref.read(sessionViewModelProvider));
        feedback.showToast(ToastId.tst34, onAction: onOpenClub);
        return JoinOutcome.joined;
      case FirebaseFailure(:final error, :final message, :final detail):
        state = state.copyWith(
          clubs: _withMemberDelta(clubId, -1),
          pendingJoinIds: {...state.pendingJoinIds}..remove(clubId),
        );
        return _joinFailed(
          clubId,
          membership,
          error,
          message,
          detail,
          formatDate,
        );
    }
  }

  /// SHT-05 onaysız kulüpte katılımla kapandı: TST-34 ([onOpenClub] "Kulübe
  /// git") ve listenin yenilenmesi (üye sayısı).
  void showJoined({VoidCallback? onOpenClub}) {
    feedback.showToast(ToastId.tst34, onAction: onOpenClub);
    unawaited(refresh());
  }

  static Set<String> _memberClubIds(SessionState session) => {
    for (final clubId in session.memberships.keys)
      if (session.roleIn(clubId) != null) clubId,
  };

  /// Oturumdaki üyelikler değişti: üye kulüpler güncellenir; oturuma yansıyan
  /// iyimser katılımlar `pendingJoinIds`'ten düşer.
  void _onSession(SessionState session) {
    final memberClubIds = _memberClubIds(session);
    final next = state.copyWith(
      memberClubIds: memberClubIds,
      pendingJoinIds: {
        for (final clubId in state.pendingJoinIds)
          if (_joinWrites.contains(clubId) || !memberClubIds.contains(clubId))
            clubId,
      },
    );
    if (next != state) state = next;
  }

  /// Kulüpleri okur ve ilk yüklemeyi bitirir.
  Future<void> _load() async {
    if (!ref.mounted || _isLoading) return;
    _isLoading = true;
    final result = await clubRepository.fetchActiveClubs();
    _isLoading = false;
    if (!ref.mounted) return;
    switch (result) {
      case FirebaseSuccess(:final data):
        state = state.copyWith(clubs: data, isFetching: false, isError: false);
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn('Kulüpler okunamadı: ${error.name}', error: message);
        state = state.copyWith(isFetching: false, isError: true);
    }
  }

  /// [clubId] kulübünün üye sayısı [delta] kadar değiştirilmiş liste (eksiye
  /// düşmez).
  List<ClubModel> _withMemberDelta(String clubId, int delta) => [
    for (final club in state.clubs)
      if (club.id == clubId)
        club.copyWith(memberCount: math.max(0, club.memberCount + delta))
      else
        club,
  ];

  Future<JoinOutcome> _joinFailed(
    String clubId,
    MembershipModel? membership,
    FirestoreError error,
    String? message,
    Object? detail,
    String Function(DateTime retryAfter) formatDate,
  ) async {
    final outcome = await joinRuleOutcome(
      error: error,
      detail: detail,
      membership: membership,
      formatDate: formatDate,
      reloadClub: () async {
        await refresh();
        return ref.mounted ? state.clubById(clubId) : null;
      },
    );
    if (outcome != null) return outcome;
    if (!ref.mounted || showWriteFailureToast(error)) return JoinOutcome.failed;
    // Kulüp silinmiş ya da beklenmeyen hata: liste gerçek durumu gösterir.
    AppLogger.warn('Kulübe katılınamadı: ${error.name}', error: message);
    unawaited(refresh());
    return JoinOutcome.failed;
  }
}

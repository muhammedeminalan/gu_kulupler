import 'dart:async';

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/managed_club_picker_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'managed_club_picker_view_model.g.dart';

/// SHT-18 "Yönetilen kulüp seç" sayfasının ViewModel'i (prototip
/// `sel.managedClubs`, `actions.js:32`).
///
/// * Hangi kulüplerin yönetildiği oturumdan gelir ([managedOf]); oturumda
///   kulüp belgesi (ad, ikon) yoktur, bu yüzden belgeler burada okunur
///   (`clubRepository.getClubs`). Sayfa her açılışta yeniden okur.
/// * Yönetilen kulüp kümesi sayfa açıkken değişirse (rol verildi / alındı)
///   belgeler yeniden okunur.
/// * Okunamazsa `isError` (sayfa "Yeniden dene" gösterir → [fetch]). Belgesi
///   olmayan ya da silinmiş kulüp sonuçta yoktur; satırı çizilmez.
///
/// Design: SHT-18
@riverpod
final class ManagedClubPickerViewModel extends _$ManagedClubPickerViewModel
    with ProjectDependencyMixin {
  bool _isLoading = false;

  /// Süren okuma bitince bir kez daha okunsun mu (küme okuma sırasında
  /// değişti)?
  bool _reloadPending = false;

  static const Set<ClubAccess> _managing = {
    ClubAccess.manager,
    ClubAccess.advisor,
  };

  /// [session] kullanıcısının yönettiği kulüplerin üyelikleri: **aktif** ve
  /// rolü yönetim kurulu / başkan (yazabilir) ya da danışman (salt okunur).
  /// Sıra `SessionState.memberships` sırasıdır.
  static List<MembershipModel> managedOf(SessionState session) => [
    for (final membership in session.memberships.values)
      if (_managing.contains(
        RolePolicy.accessOf(
          isSuper: false,
          status: membership.status,
          role: membership.role,
        ),
      ))
        membership,
  ];

  /// Yönetilen kulüp kümesinin karşılaştırma anahtarı (kimlikler, sırayla).
  static String _idsKey(SessionState session) => [
    for (final membership in managedOf(session)) membership.clubId,
  ].join(',');

  @override
  ManagedClubPickerState build() {
    ref.listen(sessionViewModelProvider, (previous, session) {
      if (previous != null && _idsKey(previous) == _idsKey(session)) return;
      unawaited(fetch());
    });
    // Kulüpler ilk karede okunmaya başlar; sayfa ayrıca çağırmaz.
    unawaited(Future<void>.microtask(_load));
    return ManagedClubPickerState(
      isFetching: managedOf(ref.read(sessionViewModelProvider)).isNotEmpty,
    );
  }

  /// Kulüpleri yeniden okur — hata görünümündeki "Yeniden dene". Süren okuma
  /// varken gelen çağrı o okuma bitince bir kez yinelenir.
  Future<void> fetch() async {
    if (!ref.mounted) return;
    if (_isLoading) {
      _reloadPending = true;
      return;
    }
    state = state.copyWith(isFetching: true, isError: false);
    await _load();
  }

  Future<void> _load() async {
    if (!ref.mounted || _isLoading) return;
    final clubIds = [
      for (final membership in managedOf(ref.read(sessionViewModelProvider)))
        membership.clubId,
    ];
    if (clubIds.isEmpty) {
      state = const ManagedClubPickerState();
      return;
    }
    _isLoading = true;
    final result = await clubRepository.getClubs(clubIds);
    _isLoading = false;
    if (!ref.mounted) return;
    if (_reloadPending) {
      _reloadPending = false;
      return _load();
    }
    switch (result) {
      case FirebaseSuccess(:final data):
        state = state.copyWith(
          clubs: {for (final club in data) club.id: club},
          isFetching: false,
          isError: false,
        );
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn(
          'Yönetilen kulüpler okunamadı: ${error.name}',
          error: message,
        );
        state = state.copyWith(isFetching: false, isError: true);
    }
  }
}

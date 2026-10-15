import 'dart:async';

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/admin/provider/admin_users_state.dart';
import 'package:gu_kulupler/product/feedback/catalogs/toasts/toast_catalog.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';
import 'package:gu_kulupler/product/navigation/admin_users_filter.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'admin_users_view_model.g.dart';

/// ADM-05 "Kullanıcılar" ViewModel'i (PLAN §12 `AdminUsersViewModel`;
/// prototip `AdminUsers`, `screens-admin.js:72–78`).
///
/// * Okuma (ilk açılış, "Yeniden dene", çek-yenile): arama girdisine göre
///   kullanıcılar + yönetici kimlikleri (`adminRepository
///   .listManagerUserIds`) + satırlardaki kulüp sayıları
///   (`membershipRepository.listMine`, etkin üyelikler; okunamazsa sayı
///   yazılmaz).
/// * Arama ([setQuery], `Limits.searchDebounce` sonra): girdide `@` varsa
///   e-posta öneki (`adminRepository.findUserByEmail` — collectionGroup),
///   yoksa ad öneki (`adminRepository.listUsersByName`, sayfalı —
///   [loadMore]); boş girdi varsayılan listeyi (ilk sayfa) okur.
/// * Süzgeç ([setFilter]) istemcidedir (`AdminUsersState.visible`).
/// * Askıya al ([suspend], DLG-30 neden zorunlu) / askıyı kaldır
///   ([unsuspend]) iyimserdir: rozet hemen değişir; yazım başarısızsa geri
///   döner. Başarı → TST-52. Oturumdaki süper adminin kendi hesabında yazım
///   yapılmaz (W-101 b; repository `invalidArgument`).
/// * `permissionDenied` → claim sunucudan yenilenir
///   (`SessionViewModel.refreshClaims` — CD-160); süper admin hâlâ
///   geçerliyse çağrı bir kez yinelenir, değilse router guard'ı (`S`)
///   sekmeyi kapatır (yazımda TST-X18).
/// * Çevrimdışı yazım TST-24 (`WriteGuardMixin`).
///
/// Design: ADM-05
@riverpod
final class AdminUsersViewModel extends _$AdminUsersViewModel
    with ProjectDependencyMixin, WriteGuardMixin {
  /// Okuma turu sayacı: eski turun (eski arama) geç gelen sonucu atılır.
  int _epoch = 0;

  /// Arama gecikmesi.
  Timer? _debounce;

  @override
  AdminUsersState build() {
    ref.onDispose(() => _debounce?.cancel());
    unawaited(Future<void>.microtask(_load));
    return const AdminUsersState(isFetching: true);
  }

  /// "Yeniden dene" (`ADM-05.retry`): iskeletle baştan okur.
  Future<void> fetch() async {
    if (!ref.mounted) return;
    state = state.copyWith(isFetching: true, isError: false);
    await _load();
  }

  /// Çek-yenile: içerik kalır, liste yeniden okunur (ilk sayfa).
  Future<void> refresh() async {
    if (!ref.mounted || state.isRefreshing) return;
    if (!state.isLoaded) return fetch();
    state = state.copyWith(isRefreshing: true);
    await _load();
  }

  /// Arama (`ADM-05.search`): girdi hemen yazılır, okuma
  /// `Limits.searchDebounce` sonra yapılır.
  void setQuery(String query) {
    if (query == state.query) return;
    state = state.copyWith(query: query);
    _debounce?.cancel();
    _debounce = Timer(Limits.searchDebounce, () => unawaited(_search()));
  }

  /// Süzgeç (`ADM-05.filter.<name>`).
  void setFilter(AdminUsersFilter filter) {
    if (filter == state.filter) return;
    state = state.copyWith(filter: filter);
  }

  /// Ad kipinde sonraki sayfa (liste sonuna yaklaşınca).
  Future<void> loadMore() async {
    final cursor = state.cursor;
    if (!ref.mounted ||
        cursor == null ||
        state.isLoadingMore ||
        state.isFetching ||
        state.isSearching ||
        !state.isLoaded) {
      return;
    }
    final epoch = _epoch;
    state = state.copyWith(isLoadingMore: true);
    final result = await _withClaims(
      () => adminRepository.listUsersByName(
        _needle,
        PageRequest(limit: Limits.adminSearchMax, after: cursor),
      ),
    );
    if (!ref.mounted) return;
    if (!_live(epoch)) {
      state = state.copyWith(isLoadingMore: false);
      return;
    }
    switch (result) {
      case FirebaseSuccess(:final data):
        final known = {for (final user in state.users) user.uid};
        final added = [
          for (final user in data.items)
            if (!known.contains(user.uid)) user,
        ];
        final counts = await _readClubCounts(added);
        if (!_live(epoch)) return;
        state = state.copyWith(
          users: [...state.users, ...added],
          clubCounts: {...state.clubCounts, ...counts},
          cursor: data.next,
          clearCursor: data.next == null,
          isLoadingMore: false,
        );
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn(
          'Kullanıcıların sonraki sayfası okunamadı: ${error.name}',
          error: message,
        );
        state = state.copyWith(isLoadingMore: false);
    }
  }

  /// DLG-30 "Askıya al" — [userId] hesabını [reason] gerekçesiyle askıya
  /// alır (iyimser; başarı → TST-52). Yazıldıysa `true`.
  Future<bool> suspend(String userId, String reason) {
    final trimmed = reason.trim();
    return _setStatus(
      userId,
      to: UserStatus.suspended,
      call: () => adminRepository.suspendUser(userId, reason: trimmed),
    );
  }

  /// DLG-30 "Askıyı kaldır" — askıdaki [userId] hesabını etkinleştirir
  /// (iyimser; başarı → TST-52). Yazıldıysa `true`.
  Future<bool> unsuspend(String userId) => _setStatus(
    userId,
    to: UserStatus.active,
    call: () => adminRepository.activateUser(userId),
  );

  /// [userId] oturumdaki kullanıcı mı? (Kendi satırında askı eylemi yok —
  /// W-101 b.)
  bool isSelf(String userId) =>
      ref.read(sessionViewModelProvider).uid == userId;

  // ───────────────────────────────── yazım ──────────────────────────────────

  Future<bool> _setStatus(
    String userId, {
    required UserStatus to,
    required Future<FirestoreResult<void>> Function() call,
  }) async {
    final original = state.userById(userId);
    if (original == null ||
        original.status == to ||
        original.isDeleted ||
        isSelf(userId) ||
        state.pendingIds.contains(userId)) {
      return false;
    }
    if (!ensureOnline()) return false;
    final suspending = to == UserStatus.suspended;
    state = state.copyWith(
      users: _replace(original.copyWith(status: to)),
      pendingIds: {...state.pendingIds, userId},
    );
    final result = await _withClaims(call);
    if (!ref.mounted) return false;
    switch (result) {
      case FirebaseSuccess():
        state = state.copyWith(
          pendingIds: {...state.pendingIds}..remove(userId),
        );
        feedback.showToast(
          ToastId.tst52,
          params: ToastParams(suspended: suspending),
        );
        return true;
      case FirebaseFailure(:final error, :final message):
        state = state.copyWith(
          users: _replace(original),
          pendingIds: {...state.pendingIds}..remove(userId),
        );
        _onWriteFailure(
          error,
          message,
          suspending ? 'Kullanıcı askıya alınamadı' : 'Askı kaldırılamadı',
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

  /// [user] ile değiştirilmiş kullanıcı listesi (aynı sıra).
  List<UserModel> _replace(UserModel user) => [
    for (final u in state.users) u.uid == user.uid ? user : u,
  ];

  // ───────────────────────────────── okuma ──────────────────────────────────

  /// Arama terimi (kırpılmış): ad kipinde Türkçe küçük harf (`nameLower`,
  /// CD-11); e-posta kipinde `toLowerCase` — `emailLower` yazılırken de
  /// böyledir (`I` → `i`; `trLower` `ı` üretirdi).
  String get _needle {
    final query = state.query.trim();
    return switch (UserSearchMode.of(query)) {
      UserSearchMode.name => query.trLower(),
      UserSearchMode.email => query.toLowerCase(),
    };
  }

  Future<void> _search() async {
    if (!ref.mounted) return;
    state = state.copyWith(isSearching: true, isError: false);
    await _load(withManagers: false);
  }

  Future<void> _load({bool withManagers = true}) async {
    final epoch = ++_epoch;
    final needle = _needle;
    final mode = UserSearchMode.of(needle);
    final usersCall = _withClaims(() => _read(needle, mode));
    final managersCall = withManagers
        ? _withClaims(adminRepository.listManagerUserIds)
        : null;
    final users = await usersCall;
    final managers = await managersCall;
    if (!_live(epoch)) return;
    switch (users) {
      case FirebaseSuccess(:final data):
        final counts = await _readClubCounts(data.items);
        if (!_live(epoch)) return;
        // Yazımı süren kullanıcının iyimser hâli korunur.
        final pending = state.pendingIds;
        state = state.copyWith(
          mode: mode,
          users: [
            for (final user in data.items)
              pending.contains(user.uid)
                  ? state.userById(user.uid) ?? user
                  : user,
          ],
          managerUserIds: _managersOf(managers),
          clubCounts: {...state.clubCounts, ...counts},
          cursor: data.next,
          clearCursor: data.next == null,
          isLoaded: true,
          isFetching: false,
          isSearching: false,
          isRefreshing: false,
          isError: false,
        );
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn(
          'Admin kullanıcıları okunamadı: ${error.name}',
          error: message,
        );
        // Çek-yenilemede eski içerik kalır; ilk açılış / aramada hata.
        state = state.copyWith(
          isFetching: false,
          isSearching: false,
          isRefreshing: false,
          isError: !state.isLoaded || state.isFetching || state.isSearching,
        );
    }
  }

  /// [needle] için kullanıcılar: e-posta kipinde tek okuma (imleç yok), ad
  /// kipinde ilk sayfa.
  Future<FirestoreResult<PageResult<UserModel>>> _read(
    String needle,
    UserSearchMode mode,
  ) async {
    switch (mode) {
      case UserSearchMode.name:
        return adminRepository.listUsersByName(
          needle,
          const PageRequest(limit: Limits.adminSearchMax),
        );
      case UserSearchMode.email:
        return switch (await adminRepository.findUserByEmail(needle)) {
          FirebaseSuccess(:final data) => FirebaseSuccess(
            PageResult(
              items: [
                for (final user in data)
                  if (!user.isDeleted) user,
              ],
            ),
          ),
          FirebaseFailure(:final error, :final message, :final detail) =>
            FirebaseFailure(error, message: message, detail: detail),
        };
    }
  }

  /// Yönetici kimlikleri; okunamadıysa (ya da okunmadıysa) öncekiler.
  Set<String> _managersOf(FirestoreResult<Set<String>>? result) {
    switch (result) {
      case null:
        return state.managerUserIds;
      case FirebaseSuccess(:final data):
        return data;
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn(
          'Yönetici kimlikleri okunamadı: ${error.name}',
          error: message,
        );
        return state.managerUserIds;
    }
  }

  /// [users] içinden sayısı bilinmeyenlerin etkin üyelik sayıları
  /// (`screens-admin.js:76` `myClubs`); okunamayan kullanıcı atlanır.
  Future<Map<String, int>> _readClubCounts(List<UserModel> users) async {
    final known = state.clubCounts;
    final ids = [
      for (final user in users)
        if (!known.containsKey(user.uid)) user.uid,
    ];
    if (ids.isEmpty) return const {};
    final results = await Future.wait([
      for (final uid in ids)
        membershipRepository.listMine(
          uid,
          statuses: const {MembershipStatus.active},
        ),
    ]);
    final counts = <String, int>{};
    for (var i = 0; i < ids.length; i++) {
      switch (results[i]) {
        case FirebaseSuccess(:final data):
          counts[ids[i]] = data.length;
        case FirebaseFailure(:final error):
          AppLogger.warn('Kulüp sayısı okunamadı: ${error.name}');
      }
    }
    return counts;
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

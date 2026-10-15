import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/settings/provider/blocked_users_state.dart';
import 'package:gu_kulupler/product/mixin/block_user_mixin.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'blocked_users_view_model.g.dart';

/// SET-02 "Engellenen kullanıcılar" ekranının ViewModel'i (PLAN §12.12;
/// prototip `S['SET-02']`, `screens-profile.js:73–76`).
///
/// * Engeller `blockRepository.listBlocked` ile, kullanıcılar toplu
///   `userRepository.getUsers` ile okunur; ikisinden biri okunamazsa hata
///   görünümü (içerik varken çek-yenilemede içerik kalır).
/// * "Engeli kaldır" `BlockUserMixin.unblockUser`'dır: onay sorulmaz
///   (prototip doğrudan `user.unblock` + TST-09), satır iyimser gizlenir →
///   `softDeleteBlock` → TST-09 "… için engel kaldırıldı." + "Geri al"
///   (`restoreBlock`). Yazım oturumdaki engel kümesine işlenir
///   (`SessionViewModel.setBlocked`).
/// * Oturumdaki engel kümesi başka ekranda değişirse (SET-02 → CLB-07
///   "Engeli kaldır", geri dönüş) satır eşitlenir.
///
/// | İşlem | Koruma | Yazım | Geri bildirim |
/// |---|---|---|---|
/// | [fetch] / [refresh] | — | — | okunamadı → hata görünümü / içerik kalır |
/// | [unblock] | çevrimdışı TST-24 | iyimser gizle → `softDeleteBlock` | TST-09 + "Geri al" (`restoreBlock`) · hata → geri + TST-24 / TST-X18 |
///
/// Design: SET-02, TST-09
@riverpod
final class BlockedUsersViewModel extends _$BlockedUsersViewModel
    with ProjectDependencyMixin, WriteGuardMixin, BlockUserMixin {
  bool _isLoading = false;

  /// Oturum; TST-09 "Geri al" ekran kapandıktan sonra da gelebildiği için
  /// engel işlemi başlarken alınır (`ref` kapanınca okunamaz).
  SessionViewModel? _session;

  @override
  BlockedUsersState build() {
    ref.listen(
      sessionViewModelProvider.select((session) => session.blockedUserIds),
      (previous, next) {
        if (previous == null) return;
        final hidden = {...state.unblockedIds}
          ..addAll(previous.difference(next))
          ..removeAll(next.difference(previous));
        if (!_sameIds(hidden, state.unblockedIds)) {
          state = state.copyWith(unblockedIds: hidden);
        }
      },
    );
    // İlk okuma ilk karede başlar; view ayrıca çağırmaz.
    unawaited(Future<void>.microtask(_load));
    return const BlockedUsersState(isFetching: true);
  }

  String? get _uid =>
      ref.mounted ? ref.read(sessionViewModelProvider).uid : null;

  @override
  String? get blockerId => _uid;

  @override
  void onBlockChanged(String userId, {required bool isBlocked}) {
    if (!ref.mounted) return;
    final hidden = {...state.unblockedIds};
    if (isBlocked) {
      hidden.remove(userId);
    } else {
      hidden.add(userId);
    }
    state = state.copyWith(unblockedIds: hidden);
  }

  @override
  void onBlockSaved(String userId, {required bool isBlocked}) =>
      _session?.setBlocked(userId, isBlocked: isBlocked);

  // ───────────────────────────────── okuma ──────────────────────────────────

  /// Engelleri yeniden okur — hata görünümündeki "Yeniden dene".
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

  // ──────────────────────────────── engel ───────────────────────────────────

  /// "Engeli kaldır" (`SET-02.unblock.<userId>`); [name] TST-09 metnindeki
  /// addır (satırda görünen ad). Satır yoksa ya da zaten kaldırıldıysa
  /// etkisizdir.
  Future<void> unblock(String userId, {required String name}) async {
    if (state.entryOf(userId) == null || state.unblockedIds.contains(userId)) {
      return;
    }
    _session = ref.read(sessionViewModelProvider.notifier);
    await unblockUser(userId: userId, name: name);
  }

  // ────────────────────────────────── iç ────────────────────────────────────

  /// Engelleri ve kullanıcıları okur (açılış, yeniden dene, çek-yenile).
  Future<void> _load() async {
    if (!ref.mounted || _isLoading) return;
    final uid = _uid;
    if (uid == null) {
      state = state.copyWith(isFetching: false, isRefreshing: false);
      return;
    }
    _isLoading = true;
    try {
      final entries = await _read(uid);
      if (!ref.mounted) return;
      if (entries == null) {
        state = state.copyWith(
          isFetching: false,
          isRefreshing: false,
          isError: state.items.isEmpty,
        );
        return;
      }
      state = state.copyWith(
        items: entries,
        // Kaldırılan engeller sunucudan dönmez.
        unblockedIds: const {},
        isFetching: false,
        isRefreshing: false,
        isError: false,
      );
    } finally {
      _isLoading = false;
    }
  }

  /// [uid] kullanıcısının engelleri ve engellenenler; okunamazsa `null`.
  Future<List<BlockedEntry>?> _read(String uid) async {
    final List<BlockModel> blocks;
    switch (await blockRepository.listBlocked(uid)) {
      case FirebaseSuccess(:final data):
        blocks = [...data]..sort(_byCreatedAt);
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn(
          'Engellenenler okunamadı: ${error.name}',
          error: message,
        );
        return null;
    }
    if (blocks.isEmpty) return const [];
    switch (await userRepository.getUsers([
      for (final block in blocks) block.blockedId,
    ], forceRefresh: state.isRefreshing)) {
      case FirebaseSuccess(:final data):
        final users = {for (final user in data) user.uid: user};
        return [for (final block in blocks) (block, users[block.blockedId])];
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn(
          'Engellenenler: kullanıcılar okunamadı: ${error.name}',
          error: message,
        );
        return null;
    }
  }

  /// İlk engellenen üstte; zamanı bilinmeyen sonda.
  static int _byCreatedAt(BlockModel a, BlockModel b) {
    final at = a.createdAt;
    final bt = b.createdAt;
    if (at == null || bt == null) {
      return at == bt ? 0 : (at == null ? 1 : -1);
    }
    return at.compareTo(bt);
  }

  static bool _sameIds(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);
}

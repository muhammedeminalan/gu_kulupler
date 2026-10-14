import 'dart:async';

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/profile/provider/saved_state.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'saved_view_model.g.dart';

/// Bir sayfanın okuma sonucu.
typedef _Page = ({
  List<SavedEntry> entries,
  PageCursor? next,
  Map<String, String> names,
});

/// PRF-04 "Kaydedilenler" ekranının ViewModel'i (PLAN §12.6; prototip
/// `S['PRF-04']`, `screens-profile.js:52–56`).
///
/// * Kayıtlar 20'lik sayfalarla okunur (`savedPostRepository.listSaved`,
///   en son kaydedilen üstte); sayfanın gönderileri tek tek
///   (`postRepository.getPost`, en çok 20) ve kulüp adları toplu
///   (`clubRepository.getClubs`) gelir. Okunamayan (silinmiş, gizlenmiş,
///   erişimi kalkmış) gönderi "İçerik kaldırıldı" satırıdır; bağlantı hatası
///   sayfanın tamamını düşürür.
/// * Ekran yalnızca "Kaydı kaldır" eylemini taşır (tasarım `PostCard`
///   değil, özet kart çizer — beğeni / menü yok); bu yüzden
///   `PostActionsMixin` karıştırılmaz.
///
/// | İşlem | Koruma | Yazım | Geri bildirim |
/// |---|---|---|---|
/// | [fetch] / [refresh] | — | — | okunamadı → hata görünümü / içerik kalır |
/// | [loadMore] | — | — | okunamadı → liste olduğu gibi |
/// | [unsave] | çevrimdışı TST-24 | iyimser gizle → `softDeleteSaved` | TST-11 + "Geri al" ([undoUnsave] → `restoreSaved`) · hata → geri + TST-24 / TST-X18 |
///
/// Design: PRF-04, TST-11
@riverpod
final class SavedViewModel extends _$SavedViewModel
    with ProjectDependencyMixin, WriteGuardMixin {
  bool _isLoading = false;

  /// İçeriğin kuşağı: her tam okumada artar; eski kuşağın sayfası yazılmaz.
  int _generation = 0;

  @override
  SavedState build() {
    // İlk okuma ilk karede başlar; view ayrıca çağırmaz.
    unawaited(Future<void>.microtask(_load));
    return const SavedState(isFetching: true);
  }

  String? get _uid =>
      ref.mounted ? ref.read(sessionViewModelProvider).uid : null;

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

  /// Sonraki sayfa (liste sonuna yaklaşınca). Okunamazsa liste olduğu gibi
  /// kalır.
  Future<void> loadMore() async {
    final uid = _uid;
    if (uid == null || _isLoading || !state.wantsMore) return;
    final generation = _generation;
    state = state.copyWith(isLoadingMore: true);
    final page = await _readPage(uid, state.cursor, state.clubNames);
    if (!ref.mounted) return;
    if (generation != _generation || page == null) {
      state = state.copyWith(isLoadingMore: false);
      return;
    }
    state = state.copyWith(
      items: [...state.items, ...page.entries],
      clubNames: {...state.clubNames, ...page.names},
      cursor: page.next,
      clearCursor: page.next == null,
      hasMore: page.next != null,
      isLoadingMore: false,
    );
  }

  // ─────────────────────────────── kaydı kaldır ──────────────────────────────

  /// "Kaydı kaldır" (`PRF-04.unsave.<postId>`): satır iyimser gizlenir →
  /// `softDeleteSaved` → TST-11 ("Kaydedilenlerden kaldırıldı." + "Geri
  /// al"). Yazılamazsa satır geri gelir.
  Future<void> unsave(String postId) async {
    final uid = _uid;
    if (uid == null ||
        state.entryOf(postId) == null ||
        state.unsavedIds.contains(postId) ||
        !ensureOnline()) {
      return;
    }
    state = state.copyWith(unsavedIds: {...state.unsavedIds, postId});
    final result = await savedPostRepository.softDeleteSaved(
      userId: uid,
      postId: postId,
    );
    switch (result) {
      case FirebaseSuccess():
        feedback.showToast(
          ToastId.tst11,
          onAction: () => unawaited(undoUnsave(postId, userId: uid)),
        );
      case FirebaseFailure(:final error, :final message):
        _show(postId);
        if (!showWriteFailureToast(error)) {
          AppLogger.warn('Kayıt kaldırılamadı: ${error.name}', error: message);
        }
    }
  }

  /// TST-11 "Geri al": kayıt geri yüklenir (`restoreSaved`, `savedAt`
  /// korunur — satır eski yerine döner). Toast ekrandan uzun yaşar: ekran
  /// kapandıysa yalnızca yazım yapılır. [userId] kaldırmayı yapan
  /// kullanıcıdır.
  Future<void> undoUnsave(String postId, {required String userId}) async {
    if (!ensureOnline()) return;
    _show(postId);
    final result = await savedPostRepository.restoreSaved(
      userId: userId,
      postId: postId,
    );
    switch (result) {
      case FirebaseSuccess():
        // Bu arada liste yenilendiyse satır listede yoktur: yeniden okunur.
        if (ref.mounted && state.entryOf(postId) == null) {
          unawaited(refresh());
        }
      case FirebaseFailure(:final error, :final message):
        if (ref.mounted) {
          state = state.copyWith(unsavedIds: {...state.unsavedIds, postId});
        }
        if (!showWriteFailureToast(error)) {
          AppLogger.warn('Kayıt geri alınamadı: ${error.name}', error: message);
        }
    }
  }

  // ────────────────────────────────── iç ────────────────────────────────────

  /// İlk sayfayı okur (açılış, yeniden dene, çek-yenile).
  Future<void> _load() async {
    if (!ref.mounted || _isLoading) return;
    final uid = _uid;
    if (uid == null) {
      state = state.copyWith(isFetching: false, isRefreshing: false);
      return;
    }
    _isLoading = true;
    final generation = ++_generation;
    try {
      final page = await _readPage(uid, null, state.clubNames);
      if (!ref.mounted || generation != _generation) return;
      if (page == null) {
        state = state.copyWith(
          isFetching: false,
          isRefreshing: false,
          isError: state.items.isEmpty,
        );
        return;
      }
      state = state.copyWith(
        items: page.entries,
        clubNames: {...state.clubNames, ...page.names},
        cursor: page.next,
        clearCursor: page.next == null,
        hasMore: page.next != null,
        // Kaldırılan kayıtlar sunucudan dönmez.
        unsavedIds: const {},
        isFetching: false,
        isRefreshing: false,
        isLoadingMore: false,
        isError: false,
      );
    } finally {
      _isLoading = false;
    }
  }

  /// [after] imlecinden sonraki kayıt sayfası, gönderileri ve [known]
  /// dışındaki kulüp adları. Kayıtlar okunamazsa ya da bir gönderi bağlantı
  /// hatası verirse `null`; kulüp adları okunamazsa kartlar adsız çizilir.
  Future<_Page?> _readPage(
    String uid,
    PageCursor? after,
    Map<String, String> known,
  ) async {
    final PageResult<SavedPostModel> page;
    switch (await savedPostRepository.listSaved(
      uid,
      PageRequest(after: after),
    )) {
      case FirebaseSuccess(:final data):
        page = data;
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn(
          'Kaydedilenler okunamadı: ${error.name}',
          error: message,
        );
        return null;
    }
    final results = await Future.wait([
      for (final saved in page.items) postRepository.getPost(saved.postId),
    ]);
    final entries = <SavedEntry>[];
    for (var i = 0; i < page.items.length; i++) {
      switch (results[i]) {
        case FirebaseSuccess(:final data):
          entries.add((page.items[i], data));
        case FirebaseFailure(:final error)
            when WriteGuardMixin.networkErrors.contains(error):
          AppLogger.warn('Kaydedilenler: gönderi okunamadı: ${error.name}');
          return null;
        case FirebaseFailure():
          // Silinmiş, gizlenmiş ya da erişimi kalkmış: "kaldırıldı" satırı.
          entries.add((page.items[i], null));
      }
    }
    final clubIds = {
      for (final (_, post) in entries)
        if (post != null && !known.containsKey(post.clubId)) post.clubId,
    }.toList();
    final names = <String, String>{};
    if (clubIds.isNotEmpty) {
      switch (await clubRepository.getClubs(clubIds)) {
        case FirebaseSuccess(:final data):
          for (final club in data) {
            names[club.id] = club.name;
          }
        case FirebaseFailure(:final error):
          AppLogger.warn('Kaydedilenler: kulüpler okunamadı: ${error.name}');
      }
    }
    return (entries: entries, next: page.next, names: names);
  }

  /// [postId] satırı yeniden görünür (geri alma, yazım hatası).
  void _show(String postId) {
    if (!ref.mounted) return;
    state = state.copyWith(unsavedIds: {...state.unsavedIds}..remove(postId));
  }
}

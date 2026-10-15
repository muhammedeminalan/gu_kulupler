import 'dart:async';

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/management/provider/manage_content_state.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/post_menu.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/mixin/block_user_mixin.dart';
import 'package:gu_kulupler/product/mixin/external_link_mixin.dart';
import 'package:gu_kulupler/product/mixin/post_actions_mixin.dart';
import 'package:gu_kulupler/product/mixin/report_received_mixin.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'manage_content_view_model.g.dart';

/// MGT-08 "İçerik yönetimi" ViewModel'i (PLAN §12.6; prototip `Content`,
/// `screens-manage.js:159–167`). Kulüp başına ayrı örnek (family `clubId`).
///
/// * Okuma: kulüp + silinmemiş gönderiler (gizlenmişler dahil) 20'lik
///   sayfalarla (`postRepository.listForManagement`, `createdAt ↓`);
///   sekme ve arama istemcidedir (`ManageContentState.visible`).
/// * Satır menüsü (`PopMenu id="MGT-08"`: sabitle / düzenle / sil) FED-01 /
///   FED-02 ile **ortak** `PostActionsMixin` çekirdeğini yürütür
///   ([runMenu] → `handlePostMenu`); bu ViewModel yalnızca kancalarla listeyi
///   iyimser günceller.
///
/// | İşlem | Sonuç | Geri bildirim |
/// |---|---|---|
/// | sabitle / kaldır | satırda iğne; kulüpte **tek** sabit (öncekinin iğnesi kalkar) | TST-53 |
/// | sil (DLG-10) | satır düşer (`softDeletePost`) | TST-45 "Geri al" (`restorePost`; sabit dönmez) |
/// | düzenle | yalnızca yazar (CD-141 (5)) → view FED-03 düzenleme kipine gider | — |
/// | hepsi | yazılamadı | iyimser değişiklik geri alınır → TST-24 · TST-X18 |
///
/// Danışman (Q-09) yazamaz: TST-26.
///
/// Design: MGT-08
@riverpod
final class ManageContentViewModel extends _$ManageContentViewModel
    with
        ProjectDependencyMixin,
        WriteGuardMixin,
        ExternalLinkMixin,
        BlockUserMixin,
        ReportReceivedMixin,
        PostActionsMixin {
  /// Süren tam okuma (ilk yükleme / yenileme).
  Future<void>? _loading;

  /// İçeriğin kuşağı: her tam okumada artar; eski kuşağın sayfası yazılmaz.
  int _generation = 0;

  @override
  ManageContentState build(String clubId) {
    ref.listen(sessionViewModelProvider, (_, session) {
      final access = session.accessTo(clubId);
      final role = session.roleIn(clubId);
      if (access == state.access &&
          role == state.role &&
          session.uid == state.uid) {
        return;
      }
      state = state.copyWith(
        access: access,
        role: role,
        clearRole: role == null,
        uid: session.uid,
      );
    });
    // Gönderiler ilk karede okunmaya başlar; view ayrıca çağırmaz.
    unawaited(Future<void>.microtask(_startLoad));
    final session = ref.read(sessionViewModelProvider);
    return ManageContentState(
      access: session.accessTo(clubId),
      role: session.roleIn(clubId),
      uid: session.uid,
      isFetching: true,
    );
  }

  // ───────────────────────────────── okuma ──────────────────────────────────

  /// "Yeniden dene" (`MGT-08.retry`): iskeletle baştan okur.
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

  /// Sonraki sayfa (liste sonuna yaklaşınca). Okunamazsa liste olduğu gibi
  /// kalır.
  Future<void> loadMore() async {
    final cursor = state.cursor;
    if (!ref.mounted || cursor == null || _loading != null) return;
    if (!state.wantsMore) return;
    final generation = _generation;
    state = state.copyWith(isLoadingMore: true);
    final result = await postRepository.listForManagement(
      clubId,
      PageRequest(after: cursor),
    );
    if (!ref.mounted) return;
    if (generation != _generation) {
      state = state.copyWith(isLoadingMore: false);
      return;
    }
    switch (result) {
      case FirebaseSuccess(:final data):
        final known = {for (final post in state.items) post.id};
        state = state.copyWith(
          items: [
            ...state.items,
            for (final post in data.items)
              if (known.add(post.id)) post,
          ],
          cursor: data.next,
          clearCursor: data.next == null,
          isLoadingMore: false,
        );
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn(
          'İçeriğin sonraki sayfası okunamadı: ${error.name}',
          error: message,
        );
        state = state.copyWith(isLoadingMore: false);
    }
  }

  // ─────────────────────────────── gezinme ──────────────────────────────────

  /// Sekme (`MGT-08.tab.<posts|announcements|polls>`).
  void setTab(PostType tab) {
    if (!ref.mounted || tab == state.tab) return;
    state = state.copyWith(tab: tab);
  }

  /// Arama alanı (`MGT-08.search`): başlık ve metin, Türkçe küçük harfle.
  void setQuery(String query) {
    if (!ref.mounted || query == state.query) return;
    state = state.copyWith(query: query);
  }

  // ───────────────────────────────── yazma ──────────────────────────────────

  /// Danışman bakışında yazan eyleme dokunuldu → TST-26.
  void onReadOnlyTap() => feedback.showToast(ToastId.tst26);

  /// Yazan / formu açan eylemden önce: danışmansa TST-26 ve `false`.
  bool ensureWritable() {
    if (!state.isReadOnly) return true;
    onReadOnlyTap();
    return false;
  }

  /// Satır menüsünde (`MGT-08.pin|edit|delete.<id>`) seçilen [action]'ı
  /// [postId] için yürütür (`PostActionsMixin.handlePostMenu`). Dönen değer
  /// view'a kalan iştir (düzenle → FED-03). [removedLabel] TST-45'teki addır
  /// (`l10n.feedTypePost`).
  Future<PostMenuOutcome> runMenu(
    PostMenuAction action,
    String postId, {
    required String removedLabel,
  }) async {
    final post = ref.mounted ? state.postById(postId) : null;
    if (post == null) return PostMenuOutcome.none;
    if (action == PostMenuAction.edit && !state.canEdit(post)) {
      return PostMenuOutcome.none;
    }
    return handlePostMenu(action, post, removedLabel: removedLabel);
  }

  // ──────────────────────── PostActionsMixin kancaları ──────────────────────

  @override
  String? get blockerId =>
      ref.mounted ? ref.read(sessionViewModelProvider).uid : null;

  @override
  ClubAccess postAccessOf(String clubId) => ref.mounted
      ? ref.read(sessionViewModelProvider).accessTo(clubId)
      : ClubAccess.visitor;

  @override
  PostModel? postOf(String postId) =>
      ref.mounted ? state.postById(postId) : null;

  @override
  PostModel? pinnedPostOf(String clubId) => ref.mounted ? state.pinned : null;

  @override
  void onPostChanged(PostModel post) {
    if (!ref.mounted) return;
    state = state.copyWith(
      items: [
        for (final other in state.items) other.id == post.id ? post : other,
      ],
    );
  }

  @override
  void onPostRemoved(PostModel post) {
    if (!ref.mounted) return;
    state = state.copyWith(
      items: [
        for (final other in state.items)
          if (other.id != post.id) other,
      ],
    );
  }

  /// Gönderi geri geldi: tarih sırasındaki yerine konur. Okunan sayfaların
  /// dışında kalan (daha eski) gönderi eklenmez — kendi sayfasıyla gelir.
  @override
  void onPostRestored(PostModel post) {
    if (!ref.mounted) return;
    final others = [
      for (final other in state.items)
        if (other.id != post.id) other,
    ];
    final inRange =
        !state.hasMore || others.isEmpty || !_isOlder(post, others.last);
    state = state.copyWith(
      items: inRange ? ([...others, post]..sort(_newestFirst)) : others,
    );
  }

  // Ekranda kaydetme / anket / şikayet / engelleme yoktur (tasarımın menüsü
  // yalnızca sabitle, düzenle, sil): kancalar etkisizdir.

  @override
  bool isPostSaved(String postId) => false;

  @override
  void onPostSavedChanged(String postId, {required bool isSaved}) {}

  @override
  String? myVoteOf(String postId) => null;

  @override
  Map<String, int>? pollResultsOf(String postId) => null;

  @override
  void onPollChanged(
    String postId, {
    required String? myOptionId,
    required Map<String, int> results,
  }) {}

  @override
  String? postAuthorName(String authorId) => null;

  @override
  void onBlockChanged(String userId, {required bool isBlocked}) {}

  // ────────────────────────────────── iç ────────────────────────────────────

  static int _newestFirst(PostModel a, PostModel b) =>
      _createdOf(b).compareTo(_createdOf(a));

  static bool _isOlder(PostModel post, PostModel than) =>
      _createdOf(post).isBefore(_createdOf(than));

  static DateTime _createdOf(PostModel post) =>
      post.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  Future<void> _startLoad() {
    final running = _loading;
    if (running != null) return running;
    final future = _load().whenComplete(() => _loading = null);
    return _loading = future;
  }

  /// Kulübü ve ilk sayfayı baştan okur; ilk yüklemeyi / yenilemeyi bitirir.
  /// Gönderiler okunamazsa (ve ekranda içerik yoksa) hata görünümü; kulüp
  /// okunamazsa liste yine gösterilir.
  Future<void> _load() async {
    final generation = ++_generation;
    final (club, page) = await (
      clubRepository.getClub(clubId, forceRefresh: true),
      postRepository.listForManagement(clubId, const PageRequest()),
    ).wait;
    if (!ref.mounted || generation != _generation) return;
    if (club case FirebaseFailure(:final error)) {
      AppLogger.warn('İçerik yönetimi: kulüp okunamadı: ${error.name}');
    }
    switch (page) {
      case FirebaseSuccess(:final data):
        state = state.copyWith(
          club: club.dataOrNull,
          items: data.items,
          cursor: data.next,
          clearCursor: data.next == null,
          isFetching: false,
          isRefreshing: false,
          isLoadingMore: false,
          isError: false,
        );
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn(
          'Kulüp gönderileri okunamadı: ${error.name}',
          error: message,
        );
        state = state.copyWith(
          club: club.dataOrNull,
          isFetching: false,
          isRefreshing: false,
          isError: state.items.isEmpty,
        );
    }
  }
}

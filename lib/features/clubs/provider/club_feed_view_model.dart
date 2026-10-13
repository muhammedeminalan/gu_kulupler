import 'dart:async';

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/clubs/provider/club_feed_state.dart';
import 'package:gu_kulupler/product/mixin/block_user_mixin.dart';
import 'package:gu_kulupler/product/mixin/external_link_mixin.dart';
import 'package:gu_kulupler/product/mixin/post_actions_mixin.dart';
import 'package:gu_kulupler/product/mixin/report_received_mixin.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'club_feed_view_model.g.dart';

/// Bir gönderi sayfasının kullanıcıya / yazara göre ek verisi: yazar
/// belgeleri ve gönderi → "kaydedilmiş mi" (okunamayan gönderi anahtarsız).
typedef _Extras = ({Map<String, UserModel> users, Map<String, bool> saved});

/// Açılışta / yenilemede okunan içerik.
typedef _Loaded = ({
  ClubModel? club,
  PageResult<PostModel> page,
  PostModel? pinned,
  Map<String, ClubRole>? roles,
  _Extras extras,
});

/// FED-01 "Akış" — CLB-03 "Gönderiler" sekmesinin ViewModel'i (PLAN §12.6,
/// CD-10; prototip `Feed`, `screens-clubs.js:59–72`).
///
/// * Açılışta üç okuma birlikte yapılır: kulüp (`pinnedPostId`), akışın ilk
///   sayfası (`postRepository.listFeed`, 20 + imleç) ve yöneticiler (yazar
///   rozetleri). Sabit gönderi ilk sayfada değilse ayrıca okunur
///   (`getPost`); okunamayan, gizlenmiş ya da silinmiş sabit gönderi "sabit
///   yok" sayılır, hata gösterilmez (W-70 a). Kalan sayfalar [loadMore] ile
///   gelir.
/// * Her sayfayla birlikte yazar belgeleri toplu (`userRepository.getUsers`),
///   kayıt durumları (`savedPostRepository.isSaved`) ve anketlerin oy durumu
///   (`PostActionsMixin.loadPollState`) okunur; bunlar okunamazsa gönderiler
///   yine çizilir.
/// * Tür süzgeci ve engellenen yazarların süzülmesi istemcidedir
///   (`ClubFeedState.visible`). Engellenenler oturumdan gelir; bu ekranda
///   yapılan engelleme oturuma yansıyana dek yerelde tutulur.
/// * Gönderi eylemleri (beğeni, kaydet, oy, paylaş, SHT-08 menüsü, kaldır,
///   sabitle, şikayet, engelle) `PostActionsMixin`'dedir; bu sınıf yalnızca
///   state'e erişimi verir. Gezinme ve SHT-09 / SHT-34 view'dadır.
///
/// | İşlem | Sonuç | Geri bildirim |
/// |---|---|---|
/// | [fetch] / [refresh] | okunamadı | hata görünümü / içerik kalır |
/// | [loadMore] | okunamadı | liste olduğu gibi kalır (yeniden kaydırınca dener) |
/// | [reloadPost] | gönderi yok / gizlenmiş | akıştan çıkar |
/// | beğeni / kaydet / oy / sabitle / kaldır | iyimser; yazılamadı | geri alınır + toast (`PostActionsMixin`) |
/// | danışman yazmayı denedi | — | TST-26 |
///
/// Design: FED-01
@riverpod
final class ClubFeedViewModel extends _$ClubFeedViewModel
    with
        ProjectDependencyMixin,
        WriteGuardMixin,
        ExternalLinkMixin,
        BlockUserMixin,
        ReportReceivedMixin,
        PostActionsMixin {
  bool _isLoading = false;

  /// İçeriğin kuşağı: her tam okumada artar; eski kuşağın sayfası yazılmaz.
  int _generation = 0;

  /// Bu ekranda yapılan engel değişiklikleri; oturumdaki kümenin üstüne
  /// uygulanır.
  final BlockOverrides _blocks = BlockOverrides();

  /// Oturum ViewModel'i (uygulama boyunca yaşar); bu ViewModel kapandıktan
  /// sonra gelen "Geri al" için saklanır.
  SessionViewModel? _session;

  @override
  ClubFeedState build(String clubId) {
    ref.listen(sessionViewModelProvider, (previous, session) {
      if (previous?.blockedUserIds == session.blockedUserIds) return;
      state = state.copyWith(
        blockedUserIds: _blocks.applyTo(session.blockedUserIds),
      );
    });
    _session = ref.read(sessionViewModelProvider.notifier);
    // Akış ilk karede okunmaya başlar; view ayrıca çağırmaz.
    unawaited(Future<void>.microtask(_load));
    return ClubFeedState(
      blockedUserIds: ref.read(sessionViewModelProvider).blockedUserIds,
      isFetching: true,
    );
  }

  // ───────────────────────────── okuma / süzgeç ─────────────────────────────

  /// Akışı yeniden okur — hata görünümündeki "Yeniden dene". Süren okuma
  /// varken gelen çağrı yok sayılır.
  Future<void> fetch() async {
    if (!ref.mounted || _isLoading) return;
    state = state.copyWith(isFetching: true, isError: false);
    await _load();
  }

  /// Yenileme: akışı iskelet göstermeden baştan okur. Okunamazsa var olan
  /// içerik kalır; içerik yoksa hata görünümü.
  Future<void> refresh() async {
    if (!ref.mounted || _isLoading || state.isRefreshing) return;
    state = state.copyWith(isRefreshing: true);
    await _load();
  }

  /// Sonraki sayfa (liste sonuna yaklaşınca). Okunamazsa liste olduğu gibi
  /// kalır; imleç korunur.
  Future<void> loadMore() async {
    final cursor = state.cursor;
    if (!ref.mounted ||
        cursor == null ||
        _isLoading ||
        state.isLoadingMore ||
        state.isError) {
      return;
    }
    final generation = _generation;
    state = state.copyWith(isLoadingMore: true);
    final result = await postRepository.listFeed(
      clubId,
      PageRequest(after: cursor),
    );
    if (!ref.mounted) return;
    if (generation != _generation) {
      // Akış bu arada baştan okundu: sayfa eski kuşağa aittir.
      state = state.copyWith(isLoadingMore: false);
      return;
    }
    switch (result) {
      case FirebaseSuccess(:final data):
        final known = {for (final post in state.posts) post.id};
        final fresh = [
          for (final post in data.items)
            if (known.add(post.id)) post,
        ];
        final extras = await _readExtras(fresh);
        if (!ref.mounted) return;
        if (generation != _generation) {
          state = state.copyWith(isLoadingMore: false);
          return;
        }
        state = state.copyWith(
          posts: [...state.posts, ...fresh],
          users: {...state.users, ...extras.users},
          savedPostIds: _mergedSaved(extras.saved),
          cursor: data.next,
          clearCursor: data.next == null,
          isLoadingMore: false,
        );
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn(
          'Akışın sonraki sayfası okunamadı: ${error.name}',
          error: message,
        );
        state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Tür çipi (`FED-01.filter.<id>`).
  void setFilter(FeedFilter filter) {
    if (filter == state.filter) return;
    state = state.copyWith(filter: filter);
  }

  /// [postId] gönderisini ve kullanıcıya göre durumunu (kayıt, anket oyu)
  /// yeniden okur — yorum sayfası (SHT-09) kapandıktan ya da gönderi
  /// detayından (FED-02) dönüldükten sonra kart güncellensin diye. Gönderi
  /// artık yoksa ya da gizlendiyse akıştan çıkar; başka hatada kopya olduğu
  /// gibi kalır.
  Future<void> reloadPost(String postId) async {
    if (!ref.mounted || state.postById(postId) == null) return;
    final uid = blockerId;
    final (result, saved) = await (
      postRepository.getPost(postId),
      uid == null
          ? Future<FirestoreResult<bool>?>.value()
          : savedPostRepository.isSaved(userId: uid, postId: postId),
    ).wait;
    if (!ref.mounted) return;
    final current = state.postById(postId);
    if (current == null) return;
    switch (result) {
      case FirebaseSuccess(:final data) when !data.isHidden:
        onPostChanged(data);
        if (saved case FirebaseSuccess(data: final isSaved)) {
          onPostSavedChanged(postId, isSaved: isSaved);
        }
        if (data.isPoll) await loadPollState(data);
      case FirebaseSuccess():
        onPostRemoved(current);
      case FirebaseFailure(
        error: FirestoreError.notFound || FirestoreError.permissionDenied,
      ):
        onPostRemoved(current);
      case FirebaseFailure(:final error):
        AppLogger.warn('Gönderi yeniden okunamadı: ${error.name}');
    }
  }

  // ─────────────────────── PostActionsMixin: state erişimi ──────────────────

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

  /// Gönderi değişti (beğeni, sabitleme, yeniden okuma): akıştaki kopya ve —
  /// sabitse — sabit gönderi yenilenir. Sabitlenen gönderi en üste çıkar,
  /// sabitliği kalkan sabit gönderi sıradaki yerine döner.
  @override
  void onPostChanged(PostModel post) {
    if (!ref.mounted) return;
    final wasPinned = state.pinned?.id == post.id;
    state = state.copyWith(
      posts: [
        for (final other in state.posts) other.id == post.id ? post : other,
      ],
      pinned: post.pinned ? post : null,
      clearPinned: wasPinned && !post.pinned,
    );
  }

  @override
  void onPostRemoved(PostModel post) {
    if (!ref.mounted) return;
    state = state.copyWith(
      posts: [
        for (final other in state.posts)
          if (other.id != post.id) other,
      ],
      clearPinned: state.pinned?.id == post.id,
    );
  }

  /// Gönderi geri geldi: tarih sırasındaki yerine konur. Okunan sayfalardan
  /// eski bir gönderi (sabitken kaldırılmış) listeye eklenmez — kendi
  /// sayfasıyla gelir.
  @override
  void onPostRestored(PostModel post) {
    if (!ref.mounted) return;
    final others = [
      for (final other in state.posts)
        if (other.id != post.id) other,
    ];
    final inRange =
        !state.hasMore || others.isEmpty || !_isOlder(post, others.last);
    state = state.copyWith(
      posts: inRange ? ([...others, post]..sort(_newestFirst)) : others,
      pinned: post.pinned ? post : null,
    );
  }

  @override
  bool isPostSaved(String postId) =>
      ref.mounted && state.savedPostIds.contains(postId);

  @override
  void onPostSavedChanged(String postId, {required bool isSaved}) {
    if (!ref.mounted) return;
    state = state.copyWith(savedPostIds: _mergedSaved({postId: isSaved}));
  }

  @override
  String? myVoteOf(String postId) => ref.mounted ? state.myVotes[postId] : null;

  @override
  Map<String, int>? pollResultsOf(String postId) =>
      ref.mounted ? state.pollResults[postId] : null;

  @override
  void onPollChanged(
    String postId, {
    required String? myOptionId,
    required Map<String, int> results,
  }) {
    if (!ref.mounted) return;
    state = state.copyWith(
      myVotes: {
        for (final MapEntry(:key, :value) in state.myVotes.entries)
          if (key != postId) key: value,
        postId: ?myOptionId,
      },
      pollResults: {...state.pollResults, postId: results},
    );
  }

  @override
  String? postAuthorName(String authorId) =>
      ref.mounted ? state.authorName(authorId) : null;

  // ──────────────────────────────── engelleme ───────────────────────────────

  @override
  void onBlockChanged(String userId, {required bool isBlocked}) {
    if (!ref.mounted) return;
    _blocks.mark(userId, isBlocked: isBlocked);
    state = state.copyWith(
      blockedUserIds: _blocks.applyTo(
        ref.read(sessionViewModelProvider).blockedUserIds,
      ),
    );
  }

  /// Engel yazıldı / geri alındı: oturumdaki engel kümesi anında güncellenir
  /// (öteki ekranlar da güncel kümeyi görür); yerel iyimser kayıt artık
  /// gerekmez. "Geri al" ekran kapandıktan sonra da gelebilir; oturum
  /// uygulama boyunca yaşadığından o durumda da eşitlenir.
  @override
  void onBlockSaved(String userId, {required bool isBlocked}) {
    _session?.setBlocked(userId, isBlocked: isBlocked);
    _blocks.settle(userId);
  }

  // ────────────────────────────────── iç ────────────────────────────────────

  /// Kayıt kümesine [changes] (gönderi → kaydedilmiş mi) uygulanmış hali.
  Set<String> _mergedSaved(Map<String, bool> changes) => {
    for (final postId in state.savedPostIds)
      if (changes[postId] ?? true) postId,
    for (final MapEntry(:key, :value) in changes.entries)
      if (value) key,
  };

  /// İçeriği baştan okur ve ilk yüklemeyi / yenilemeyi bitirir.
  Future<void> _load() async {
    if (!ref.mounted || _isLoading) return;
    _isLoading = true;
    final loaded = await _read();
    _isLoading = false;
    if (!ref.mounted) return;
    if (loaded == null) {
      state = state.copyWith(
        isFetching: false,
        isRefreshing: false,
        isError: state.posts.isEmpty && state.pinned == null,
      );
      return;
    }
    ++_generation;
    state = state.copyWith(
      club: loaded.club,
      posts: loaded.page.items,
      pinned: loaded.pinned,
      clearPinned: loaded.pinned == null,
      roles: loaded.roles,
      users: {...state.users, ...loaded.extras.users},
      savedPostIds: _mergedSaved(loaded.extras.saved),
      cursor: loaded.page.next,
      clearCursor: loaded.page.next == null,
      isFetching: false,
      isRefreshing: false,
      isLoadingMore: false,
      isError: false,
    );
  }

  /// Kulüp, akışın ilk sayfası, yöneticiler, sabit gönderi ve sayfanın ek
  /// verisi. Akış okunamazsa `null`; ötekiler okunamazsa akış yine gösterilir
  /// (sabit gönderi / rozet / yer tutucu paleti olmadan).
  Future<_Loaded?> _read() async {
    final (club, page, managers) = await (
      clubRepository.getClub(clubId),
      postRepository.listFeed(clubId, const PageRequest()),
      membershipRepository.listManagers(clubId),
    ).wait;
    if (club case FirebaseFailure(:final error)) {
      AppLogger.warn('Akış: kulüp okunamadı: ${error.name}');
    }
    if (managers case FirebaseFailure(:final error)) {
      AppLogger.warn('Akış: yöneticiler okunamadı: ${error.name}');
    }
    if (page case FirebaseFailure(:final error, :final message)) {
      AppLogger.warn('Akış okunamadı: ${error.name}', error: message);
      return null;
    }
    final posts = page.dataOrNull ?? const PageResult<PostModel>(items: []);
    final pinned = await _readPinned(
      club.dataOrNull?.pinnedPostId,
      posts.items,
    );
    final extras = await _readExtras([
      ...posts.items,
      if (pinned != null && !posts.items.contains(pinned)) pinned,
    ], reread: true);
    final managerList = managers.dataOrNull;
    return (
      club: club.dataOrNull,
      page: posts,
      pinned: pinned,
      roles: managerList == null
          ? null
          : {for (final manager in managerList) manager.userId: manager.role},
      extras: extras,
    );
  }

  /// Kulübün sabit gönderisi. İlk sayfadaysa oradaki kopya kullanılır;
  /// değilse [pinnedId] okunur. Okunamayan (üyeye gizlenmiş gönderi
  /// `permissionDenied`, silinmiş `notFound` döner), gizlenmiş ya da artık
  /// sabit olmayan gönderi "sabit yok"tur — hata gösterilmez (W-70 a).
  Future<PostModel?> _readPinned(String? pinnedId, List<PostModel> page) async {
    for (final post in page) {
      if (pinnedId == null ? post.pinned : post.id == pinnedId) {
        return post.pinned ? post : null;
      }
    }
    if (pinnedId == null) return null;
    final result = await postRepository.getPost(pinnedId);
    switch (result) {
      case FirebaseSuccess(:final data):
        final usable =
            data.clubId == clubId &&
            data.pinned &&
            !data.isHidden &&
            !data.isDeleted;
        return usable ? data : null;
      case FirebaseFailure(:final error):
        if (error != FirestoreError.permissionDenied &&
            error != FirestoreError.notFound) {
          AppLogger.warn('Sabit gönderi okunamadı: ${error.name}');
        }
        return null;
    }
  }

  /// [posts] sayfasının ek verisi: yazar belgeleri (toplu), kayıt durumları
  /// ve anketlerin oy durumu (ikincisi doğrudan state'e yazılır —
  /// `PostActionsMixin.loadPollState`). Okunamayan parça atlanır. [reread]
  /// `false` iken yalnızca belgesi henüz okunmamış yazarlar okunur.
  Future<_Extras> _readExtras(
    List<PostModel> posts, {
    bool reread = false,
  }) async {
    if (posts.isEmpty) {
      return (
        users: const <String, UserModel>{},
        saved: const <String, bool>{},
      );
    }
    final uid = blockerId;
    final authorIds = {
      for (final post in posts)
        if (reread || !state.users.containsKey(post.authorId)) post.authorId,
    }.toList();
    final (users, saved, _) = await (
      userRepository.getUsers(authorIds),
      uid == null
          ? Future.value(const <FirestoreResult<bool>>[])
          : Future.wait([
              for (final post in posts)
                savedPostRepository.isSaved(userId: uid, postId: post.id),
            ]),
      Future.wait([
        for (final post in posts)
          if (post.isPoll) loadPollState(post),
      ]),
    ).wait;
    if (users case FirebaseFailure(:final error)) {
      AppLogger.warn('Gönderi yazarları okunamadı: ${error.name}');
    }
    return (
      users: {
        for (final user in users.dataOrNull ?? const <UserModel>[])
          user.uid: user,
      },
      saved: {
        for (final (index, result) in saved.indexed)
          if (result case FirebaseSuccess(:final data)) posts[index].id: data,
      },
    );
  }

  /// Yayın anı; henüz sunucudan dönmediyse (yeni yazılmış) en yeni sayılır.
  static bool _isOlder(PostModel post, PostModel than) {
    final a = post.createdAt;
    final b = than.createdAt;
    return a != null && b != null && a.isBefore(b);
  }

  /// En yeni üstte; yayın anı olmayan (yeni yazılmış) gönderi en üstte.
  static int _newestFirst(PostModel a, PostModel b) {
    final left = a.createdAt;
    final right = b.createdAt;
    if (left == null) return right == null ? 0 : -1;
    if (right == null) return 1;
    return right.compareTo(left);
  }
}

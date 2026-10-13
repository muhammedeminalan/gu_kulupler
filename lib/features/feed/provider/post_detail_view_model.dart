import 'dart:async';

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/feed/provider/post_detail_state.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/user_menu_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/toasts/toast_catalog.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/mixin/block_user_mixin.dart';
import 'package:gu_kulupler/product/mixin/external_link_mixin.dart';
import 'package:gu_kulupler/product/mixin/post_actions_mixin.dart';
import 'package:gu_kulupler/product/mixin/report_received_mixin.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'post_detail_view_model.g.dart';

/// Yorum menüsünden sonra view'ın yapması gereken
/// ([PostDetailViewModel.openCommentMenu]). Sheet / dialog / toast
/// ViewModel'de biter; gezinme view'dadır.
enum CommentMenuOutcome {
  /// View'a iş düşmez.
  none,

  /// "Profili gör": view yorum sahibinin profiline gider (CLB-07).
  viewProfile,
}

/// FED-02 "Gönderi" ekranının ve SHT-09 "Yorumlar" sayfasının ViewModel'i
/// (PLAN §12.8; prototip `S['FED-02']`, `screens-clubs.js:165–178`;
/// `SHEETS['SHT-09']`, `sheets.js:45–48`).
///
/// * **Canlı veri** (PLAN §10.6 #3): gönderi (`postRepository.watchPost`) ve
///   yorumları (`commentRepository.watchComments`) yalnızca ekran / sayfa
///   açıkken dinlenir; ViewModel kapanınca abonelikler iptal edilir. Yazar
///   belgeleri toplu okunur (`userRepository.getUsers`) ve yorumlar
///   yazarlarıyla birlikte yayımlanır.
/// * **İçerik yok → SYS-04** ([PostDetailState.isNotFound]): gönderi yok,
///   silinmiş, gizlenmiş, başka kulübün ya da okuma yetkisi yok
///   (`permissionDenied` / `notFound`); yorum akışının `permissionDenied`
///   olayı da böyle sayılır (dinleme sürerken gönderi gizlendi — CD-141
///   madde 11, W-70).
/// * Gönderi eylemleri (beğeni, kayıt, oy, paylaş, SHT-08 menüsü)
///   `PostActionsMixin`'dedir; engelleme `BlockUserMixin`, şikayet onayı
///   `ReportReceivedMixin`.
/// * Engellenen yazarların yorumları istemcide süzülür
///   ([PostDetailState.visibleComments]); engellenenler oturumdan gelir, bu
///   ekranda yapılan engelleme oturuma yansıyana dek yerelde tutulur.
///
/// | İşlem | Koruma | Yazım | Geri bildirim |
/// |---|---|---|---|
/// | [sendComment] | boş / uzun metin · danışman TST-26 · çevrimdışı TST-24 | `commentRepository.add` | TST-12; hata → TST-24 / TST-X18 |
/// | [removeComment] | DLG-11 onayı → çevrimdışı TST-24 | iyimser `softDeleteComment` | TST-45 + "Geri al" (`restoreComment`) |
/// | [reportComment] | çevrimdışı (gönderimde) | SHT-10 → `report` | DLG-12 (→ "engelle" DLG-13) |
/// | [openCommentMenu] | — | kendi yorumu → DLG-11; başkası → SHT-27 | seçilen satıra göre |
///
/// Design: FED-02, DLG-11
@riverpod
final class PostDetailViewModel extends _$PostDetailViewModel
    with
        ProjectDependencyMixin,
        WriteGuardMixin,
        ExternalLinkMixin,
        BlockUserMixin,
        ReportReceivedMixin,
        PostActionsMixin {
  StreamSubscription<FirestoreResult<PostModel?>>? _postSubscription;
  StreamSubscription<FirestoreResult<List<CommentModel>>>?
  _commentsSubscription;

  /// Son yorum olayının sırası: yazarları okunurken yenisi gelen olay
  /// yayımlanmaz.
  int _commentsEvent = 0;

  /// Belgesi istenmiş kullanıcılar (yeniden okunmaz; silinmiş hesaplar dahil).
  final Set<String> _requestedUserIds = <String>{};

  /// Kaldırma onayı / yazımı süren yorumlar.
  final Set<String> _removingCommentIds = <String>{};

  /// Bu ekranda yapılan engel değişiklikleri; oturumdaki kümenin üstüne
  /// uygulanır.
  final BlockOverrides _blocks = BlockOverrides();

  /// Oturum ViewModel'i (uygulama boyunca yaşar); bu ViewModel kapandıktan
  /// sonra gelen "Geri al" için saklanır.
  late SessionViewModel _session;

  @override
  PostDetailState build({required String clubId, required String postId}) {
    ref
      ..listen(sessionViewModelProvider, (previous, session) {
        if (previous?.blockedUserIds == session.blockedUserIds) return;
        state = state.copyWith(
          blockedUserIds: _blocks.applyTo(session.blockedUserIds),
        );
      })
      ..onDispose(_cancel);
    _session = ref.read(sessionViewModelProvider.notifier);
    // Dinleme ilk karede başlar; view ayrıca çağırmaz.
    unawaited(Future<void>.microtask(_start));
    return PostDetailState(
      blockedUserIds: ref.read(sessionViewModelProvider).blockedUserIds,
      isFetching: true,
      isFetchingComments: true,
    );
  }

  // ───────────────────────── mixin'lere verilenler ──────────────────────────

  @override
  String? get blockerId =>
      ref.mounted ? ref.read(sessionViewModelProvider).uid : null;

  @override
  ClubAccess postAccessOf(String clubId) => ref.mounted
      ? ref.read(sessionViewModelProvider).accessTo(clubId)
      : ClubAccess.visitor;

  @override
  PostModel? postOf(String postId) {
    if (!ref.mounted) return null;
    final post = state.post;
    return post != null && post.id == postId ? post : null;
  }

  @override
  void onPostChanged(PostModel post) {
    if (!ref.mounted || post.id != postId) return;
    state = state.copyWith(post: post);
  }

  @override
  void onPostRemoved(PostModel post) {
    if (!ref.mounted || post.id != postId) return;
    state = state.copyWith(isRemoved: true);
  }

  @override
  void onPostRestored(PostModel post) {
    if (!ref.mounted || post.id != postId) return;
    state = state.copyWith(post: post, isRemoved: false);
  }

  @override
  bool isPostSaved(String postId) => ref.mounted && state.isSaved;

  @override
  void onPostSavedChanged(String postId, {required bool isSaved}) {
    if (!ref.mounted) return;
    state = state.copyWith(isSaved: isSaved);
  }

  @override
  String? myVoteOf(String postId) => ref.mounted ? state.myOptionId : null;

  @override
  Map<String, int>? pollResultsOf(String postId) =>
      ref.mounted ? state.pollResults : null;

  @override
  void onPollChanged(
    String postId, {
    required String? myOptionId,
    required Map<String, int> results,
  }) {
    if (!ref.mounted) return;
    state = state.copyWith(
      myOptionId: myOptionId,
      clearMyOptionId: myOptionId == null,
      pollResults: results,
    );
  }

  @override
  String? postAuthorName(String authorId) =>
      ref.mounted ? state.authorOf(authorId)?.name : null;

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

  /// Engel yazıldı / geri alındı: oturumdaki engel kümesi anında güncellenir;
  /// yerel iyimser kayıt artık gerekmez. "Geri al" ekran kapandıktan sonra da
  /// gelebilir; oturum uygulama boyunca yaşadığından o durumda da eşitlenir.
  @override
  void onBlockSaved(String userId, {required bool isBlocked}) {
    _session.setBlocked(userId, isBlocked: isBlocked);
    _blocks.settle(userId);
  }

  // ───────────────────────────────── okuma ──────────────────────────────────

  /// Gönderiyi ve yorumları yeniden dinler — hata görünümündeki "Yeniden
  /// dene".
  Future<void> fetch() async {
    if (!ref.mounted) return;
    state = state.copyWith(
      isFetching: true,
      isFetchingComments: true,
      isError: false,
      isCommentsError: false,
      isNotFound: false,
    );
    await _start();
  }

  // ──────────────────────────────── yorumlar ────────────────────────────────

  /// Yorum alanı (`FED-02.commentInput`, `SHT-09.input`): metin
  /// `Limits.commentMax` karakterde kesilir (`screens-clubs.js:177`).
  void setCommentDraft(String text) {
    final draft = _clamped(text);
    if (draft == state.commentDraft) return;
    state = state.copyWith(commentDraft: draft);
  }

  /// "Gönder" (`FED-02.sendComment`, `SHT-09.send`): kırpılmış metni yorum
  /// olarak yazar → TST-12; alan boşalır. Yeni yorum listeye canlı akıştan
  /// gelir.
  ///
  /// `true` → yorum yazıldı. `false` → oturum yok, boş / uzun metin, süren
  /// gönderim, danışman (TST-26), çevrimdışı (TST-24) ya da yazma hatası
  /// (metin alanda kalır).
  Future<bool> sendComment() async {
    final uid = blockerId;
    final text = state.commentDraft.trim();
    if (uid == null || state.isSendingComment) return false;
    if (FieldValidators.comment(text) != null) return false;
    if (!ensurePostWritable(clubId)) return false;
    state = state.copyWith(isSendingComment: true);
    final result = await commentRepository.add(
      postId: postId,
      clubId: clubId,
      authorId: uid,
      text: text,
    );
    if (ref.mounted) {
      state = state.copyWith(
        isSendingComment: false,
        commentDraft: result.isSuccess ? '' : null,
      );
    }
    switch (result) {
      case FirebaseSuccess():
        feedback.showToast(ToastId.tst12);
        return true;
      case FirebaseFailure(:final error, :final message):
        showPostWriteFailure(error, message, 'Yorum yazılamadı');
        return false;
    }
  }

  /// Yorumu kaldır (kendi yorumunun "…" düğmesi, `SHT-27.deleteComment`):
  /// DLG-11 onayı → `softDeleteComment` → TST-45 "{what} silindi." ("Geri al"
  /// → `restoreComment`). [what] toast'taki yerelleştirilmiş addır ("Yorum" —
  /// `l10n.feedComment`; view verir). Satır iyimser kaybolur.
  ///
  /// `true` → kaldırıldı. `false` → vazgeçildi, çevrimdışı (TST-24) ya da
  /// yazma hatası (satır geri gelir).
  Future<bool> removeComment(String commentId, {required String what}) async {
    final uid = blockerId;
    if (uid == null || state.commentById(commentId) == null) return false;
    if (!_removingCommentIds.add(commentId)) return false;
    try {
      final confirmed =
          await feedback.showDialog<bool>(DialogId.dlg11) ?? false;
      if (!confirmed || !ensureOnline()) return false;
      _setCommentRemoved(commentId, isRemoved: true);
      final result = await commentRepository.softDeleteComment(
        commentId,
        postId: postId,
        actorId: uid,
      );
      if (result case FirebaseFailure(:final error, :final message)) {
        _setCommentRemoved(commentId, isRemoved: false);
        showPostWriteFailure(error, message, 'Yorum kaldırılamadı');
        return false;
      }
      final post = postId;
      feedback.showToast(
        ToastId.tst45,
        params: ToastParams(what: what),
        onAction: () => unawaited(_undoRemoveComment(commentId, post)),
      );
      return true;
    } finally {
      _removingCommentIds.remove(commentId);
    }
  }

  /// "Yorumu şikayet et" (`SHT-27.reportComment`): SHT-10 (hedef = yorum) →
  /// `reportRepository.report` → DLG-12; "… kullanıcısını da engelle"
  /// seçilirse DLG-13.
  Future<void> reportComment(String commentId) async {
    final comment = state.commentById(commentId);
    if (comment == null) return;
    await _report(
      (type: ReportTargetType.comment, id: commentId, clubId: clubId),
      userId: comment.authorId,
    );
  }

  /// "Kullanıcıyı şikayet et" (`SHT-27.report`): SHT-10 (hedef = kullanıcı;
  /// kulüp yok — CD-33) → DLG-12 (→ DLG-13).
  Future<void> reportUser(String userId) => _report(
    (type: ReportTargetType.user, id: userId, clubId: null),
    userId: userId,
  );

  /// Yorum menüsü (`FED-02.commentMenu.<commentId>`; `screens-clubs.js:171`):
  /// kendi yorumunda doğrudan DLG-11; başkasının yorumunda SHT-27 — "Yorumu
  /// sil" yalnızca yöneticide (ve süper adminde) çizilir. Seçilen satır
  /// burada yürütülür; dönen değer view'a kalan iştir (gezinme).
  /// [removedLabel] TST-45'teki addır (`l10n.feedComment`).
  Future<CommentMenuOutcome> openCommentMenu(
    String commentId, {
    required String removedLabel,
  }) async {
    final uid = blockerId;
    final comment = state.commentById(commentId);
    if (uid == null || comment == null) return CommentMenuOutcome.none;
    final authorId = comment.authorId;
    if (authorId == uid) {
      await removeComment(commentId, what: removedLabel);
      return CommentMenuOutcome.none;
    }
    final name = state.authorOf(authorId)?.name;
    final canDelete = canManagePosts(clubId);
    final isBlocked = state.blockedUserIds.contains(authorId);
    final action = await feedback.showSheet<UserMenuAction>(
      SheetId.sht27,
      builder: (_) => UserMenuSheet(
        userId: authorId,
        userName: name,
        commentId: commentId,
        canDeleteComment: canDelete,
        isBlocked: isBlocked,
      ),
    );
    if (action == null || !ref.mounted) return CommentMenuOutcome.none;
    switch (action) {
      case UserMenuAction.viewProfile:
        return CommentMenuOutcome.viewProfile;
      case UserMenuAction.removeComment:
        await removeComment(commentId, what: removedLabel);
      case UserMenuAction.reportComment:
        await reportComment(commentId);
      case UserMenuAction.block:
        // Adı bilinmeyen (silinmiş) kullanıcı engellenmez.
        if (name != null) await blockUser(userId: authorId, name: name);
      case UserMenuAction.unblock:
        if (name != null) await unblockUser(userId: authorId, name: name);
      case UserMenuAction.report:
        await reportUser(authorId);
    }
    return CommentMenuOutcome.none;
  }

  // ────────────────────────────────── iç ────────────────────────────────────

  /// Canlı dinlemeyi (yeniden) başlatır ve gönderiden bağımsız içeriği okur.
  Future<void> _start() async {
    if (!ref.mounted) return;
    _cancel();
    _postSubscription = postRepository.watchPost(postId).listen(_onPost);
    _commentsSubscription = commentRepository
        .watchComments(postId, clubId: clubId)
        .listen((event) => unawaited(_onComments(event)));
    await _loadContext();
  }

  void _cancel() {
    unawaited(_postSubscription?.cancel());
    unawaited(_commentsSubscription?.cancel());
    _postSubscription = null;
    _commentsSubscription = null;
  }

  /// Gönderi olayı. Görünmeyen gönderi (yok / silinmiş / gizlenmiş / başka
  /// kulübün) ve okuma reddi "içerik yok"tur; diğer hatalarda eldeki içerik
  /// ekranda kalır.
  void _onPost(FirestoreResult<PostModel?> event) {
    if (!ref.mounted) return;
    switch (event) {
      case FirebaseSuccess(:final data?)
          when !data.isDeleted && !data.isHidden && data.clubId == clubId:
        final isFirst = state.post == null;
        state = state.copyWith(
          post: data,
          isFetching: false,
          isError: false,
          isNotFound: false,
        );
        if (isFirst) unawaited(_loadPostExtras(data));
      case FirebaseSuccess():
      case FirebaseFailure(
        error: FirestoreError.permissionDenied || FirestoreError.notFound,
      ):
        _markNotFound();
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn('Gönderi okunamadı: ${error.name}', error: message);
        state = state.copyWith(isFetching: false, isError: state.post == null);
    }
  }

  /// Yorum olayı. Yazar belgeleri okunduktan sonra yayımlanır; `permissionDenied`
  /// gönderinin görünmez olduğunu söyler (W-70).
  Future<void> _onComments(FirestoreResult<List<CommentModel>> event) async {
    if (!ref.mounted) return;
    final sequence = ++_commentsEvent;
    switch (event) {
      case FirebaseSuccess(:final data):
        await _loadUsers([for (final comment in data) comment.authorId]);
        if (!ref.mounted || sequence != _commentsEvent) return;
        state = state.copyWith(
          comments: data,
          isFetchingComments: false,
          isCommentsError: false,
        );
      case FirebaseFailure(error: FirestoreError.permissionDenied):
        _markNotFound();
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn('Yorumlar okunamadı: ${error.name}', error: message);
        // Eldeki yorumlar kalır; hiç okunamadıysa yorum bloğunda hata.
        state = state.copyWith(
          isFetchingComments: false,
          isCommentsError: state.isFetchingComments || state.isCommentsError,
        );
    }
  }

  /// "İçerik yok" (SYS-04). Gönderiyi bu ekran kaldırdıysa ekran zaten önceki
  /// sayfaya döner; durum değişmez.
  void _markNotFound() {
    if (state.isRemoved) return;
    state = state.copyWith(
      isFetching: false,
      isFetchingComments: false,
      isNotFound: true,
    );
  }

  /// Gönderiden bağımsız içerik: kulüp, yöneticilerin rolleri ve kayıt
  /// durumu. Okunamayan parça varsayılanıyla kalır.
  Future<void> _loadContext() async {
    final uid = blockerId;
    final (club, managers, saved) = await (
      clubRepository.getClub(clubId),
      membershipRepository.listManagers(clubId),
      uid == null
          ? Future<FirestoreResult<bool>>.value(const FirebaseSuccess(false))
          : savedPostRepository.isSaved(userId: uid, postId: postId),
    ).wait;
    if (!ref.mounted) return;
    if (club case FirebaseFailure(:final error)) {
      AppLogger.warn('Gönderi: kulüp okunamadı: ${error.name}');
    }
    if (managers case FirebaseFailure(:final error)) {
      AppLogger.warn('Gönderi: yöneticiler okunamadı: ${error.name}');
    }
    state = state.copyWith(
      club: club.dataOrNull,
      roles: switch (managers.dataOrNull) {
        null => null,
        final list => {
          for (final membership in list) membership.userId: membership.role,
        },
      },
      isSaved: saved.dataOrNull,
    );
  }

  /// İlk gönderi olayından sonra: yazarın belgesi ve anket durumu.
  Future<void> _loadPostExtras(PostModel post) async {
    await (_loadUsers([post.authorId]), loadPollState(post)).wait;
  }

  /// [userIds] içinden belgesi henüz istenmemiş olanları toplu okur.
  /// Okunamazsa satırlar "Silinmiş kullanıcı" çizilir ve sonraki olayda
  /// yeniden denenir.
  Future<void> _loadUsers(Iterable<String> userIds) async {
    final missing = {
      for (final userId in userIds)
        if (!_requestedUserIds.contains(userId)) userId,
    }.toList();
    if (missing.isEmpty) return;
    _requestedUserIds.addAll(missing);
    final result = await userRepository.getUsers(missing);
    if (!ref.mounted) return;
    switch (result) {
      case FirebaseSuccess(:final data):
        if (data.isEmpty) return;
        state = state.copyWith(
          users: {
            ...state.users,
            for (final user in data) user.uid: user,
          },
        );
      case FirebaseFailure(:final error):
        _requestedUserIds.removeAll(missing);
        AppLogger.warn('Yorum yazarları okunamadı: ${error.name}');
    }
  }

  /// SHT-10 → DLG-12 (`PostActionsMixin.reportContent`). [userId] şikayetin
  /// bağlı olduğu kullanıcıdır: adı biliniyorsa (ve kendisi ya da zaten
  /// engelli değilse) "… kullanıcısını da engelle" çizilir → DLG-13.
  Future<void> _report(ReportTarget target, {required String userId}) =>
      reportContent(
        target,
        userId: userId,
        blockableName: () {
          if (!ref.mounted || userId == blockerId) return null;
          if (state.blockedUserIds.contains(userId)) return null;
          return state.authorOf(userId)?.name;
        },
      );

  /// TST-45 "Geri al": [commentId] yorumu geri yüklenir; yazılamazsa yeniden
  /// gizlenir. Ekran kapandıktan sonra da gelebilir.
  Future<void> _undoRemoveComment(String commentId, String postId) async {
    if (!ensureOnline()) return;
    _setCommentRemoved(commentId, isRemoved: false);
    final result = await commentRepository.restoreComment(
      commentId,
      postId: postId,
    );
    if (result case FirebaseFailure(:final error, :final message)) {
      _setCommentRemoved(commentId, isRemoved: true);
      showPostWriteFailure(error, message, 'Yorum geri alınamadı');
    }
  }

  void _setCommentRemoved(String commentId, {required bool isRemoved}) {
    if (!ref.mounted) return;
    state = state.copyWith(
      removedCommentIds: isRemoved
          ? {...state.removedCommentIds, commentId}
          : {
              for (final id in state.removedCommentIds)
                if (id != commentId) id,
            },
    );
  }

  /// [text] metninin `Limits.commentMax` karakterle sınırlı hali; vekil çiftin
  /// ortasından kesilmez.
  static String _clamped(String text) {
    if (text.length <= Limits.commentMax) return text;
    final end = _isHighSurrogate(text.codeUnitAt(Limits.commentMax - 1))
        ? Limits.commentMax - 1
        : Limits.commentMax;
    return text.substring(0, end);
  }

  static bool _isHighSurrogate(int unit) => (unit & 0xFC00) == 0xD800;
}

import 'dart:async';

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/constants/app_constants.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/post_menu.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/report_reason_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/share_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/toasts/toast_catalog.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/mixin/block_user_mixin.dart';
import 'package:gu_kulupler/product/mixin/external_link_mixin.dart';
import 'package:gu_kulupler/product/mixin/report_received_mixin.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';

/// Anket oyunun sonucu ([PostActionsMixin.votePost]).
enum VoteOutcome {
  /// Oy yazıldı (TST-10 gösterildi).
  voted,

  /// Kullanıcı bu ankette zaten oy vermiş: oy değiştirilemez (TST-10
  /// gösterildi).
  alreadyVoted,

  /// Anketin süresi dolmuş; hiçbir şey yazılmadı, bildirim yok.
  closed,

  /// Oy yazılmadı: oturum / gönderi yok, danışman (TST-26), çevrimdışı
  /// (TST-24), yetki yok (TST-X18), süren oy işlemi ya da beklenmeyen hata.
  failed,
}

/// SHT-08 menü eyleminden sonra view'ın yapması gereken
/// ([PostActionsMixin.handlePostMenu]). Sheet / dialog / toast ViewModel'de
/// biter; gezinme view'dadır.
enum PostMenuOutcome {
  /// View'a iş düşmez.
  none,

  /// "Düzenle": view yazı düzenleme ekranına gider (FED-03 düzenleme kipi —
  /// W-25, T-21).
  edit,

  /// Gönderi kaldırıldı (TST-45 gösterildi): gönderi detayı (FED-02) önceki
  /// sayfaya döner; akış (FED-01) yerinde kalır.
  removed,
}

/// Süren gönderi işlemi türü (aynı gönderide aynı işlem ikinci kez
/// başlatılmaz).
enum _PostOp { like, save, vote, pin, remove }

/// Gönderi eylemlerinin ortak çekirdeği — `PostCard` gösteren her ViewModel
/// (FED-01 `ClubFeedViewModel`, FED-02 `PostDetailViewModel`; ileride MGT-08,
/// PRF-04) aynı korumayı, yazımı, geri almayı ve bildirimi buradan alır
/// (prototip `cards.js:83–127`, `sheets.js:40–43`, `dialogs.js:26`).
///
/// | İşlem | Koruma | Yazım | Geri bildirim |
/// |---|---|---|---|
/// | [togglePostLike] | danışman TST-26 · çevrimdışı TST-24 | iyimser `like` / `unlike` | hata → geri alınır + toast |
/// | [togglePostSave] | çevrimdışı TST-24 | iyimser `save` / `softDeleteSaved` | TST-11 + "Geri al" (`softDeleteSaved` / `restoreSaved`) |
/// | [votePost] | oy verilmiş → TST-10 · süresi dolmuş → sessiz · danışman TST-26 · çevrimdışı | iyimser `vote` → `countVotes` | TST-10; `alreadyExists` → gerçek oy okunur + TST-10 |
/// | [togglePostPin] | danışman · çevrimdışı | iyimser `pin` / `unpin` (önceki sabit kalkar) | TST-53 |
/// | [removePost] | danışman · çevrimdışı → DLG-10 onayı | iyimser `softDeletePost` | TST-45 + "Geri al" (`restorePost`) |
/// | [sharePost] | — | SHT-15 → kopyala / WhatsApp / e-posta (DLG-32) / sistem | TST-35 (kopyala) |
/// | [copyPostLink] | — | pano | TST-35 |
/// | [reportPost] | çevrimdışı (gönderimde) | SHT-10 → `report` | DLG-12 (→ "engelle" DLG-13) |
/// | [blockPostAuthor] | çevrimdışı | DLG-13 → `block` (`BlockUserMixin`) | TST-09 + "Geri al" |
///
/// Yazma hatası: iyimser değişiklik geri alınır; ağ → TST-24, yetki yok →
/// TST-X18 (`WriteGuardMixin.showWriteFailureToast`), diğerleri günlüğe düşer.
///
/// Tüketici dört mixin'i bundan **önce** karıştırır ve state'ine erişimi
/// soyut üyelerle verir:
///
/// ```dart
/// final class ClubFeedViewModel extends _$ClubFeedViewModel
///     with
///         ProjectDependencyMixin,
///         WriteGuardMixin,
///         ExternalLinkMixin,
///         BlockUserMixin,
///         ReportReceivedMixin,
///         PostActionsMixin {
///   @override
///   String? get blockerId => ref.read(sessionViewModelProvider).uid;
///
///   @override
///   ClubAccess postAccessOf(String clubId) =>
///       ref.read(sessionViewModelProvider).accessTo(clubId);
///
///   @override
///   PostModel? postOf(String postId) =>
///       ref.mounted ? state.postById(postId) : null;
///
///   @override
///   void onPostChanged(PostModel post) {
///     if (!ref.mounted) return;
///     state = state.copyWith(posts: state.replaced(post));
///   }
///   …
/// }
/// ```
///
/// TST-11 / TST-45 ekrandan uzun yaşar: "Geri al" ViewModel kapandıktan sonra
/// da gelebilir. Mixin o yolda yalnızca GetIt bağımlılıklarını ve yakaladığı
/// gönderiyi kullanır; tüketici soyut üyelerde `ref.mounted` denetler
/// (okuyanlar `null` / `false` döner, yazanlar hiçbir şey yapmaz).
///
/// Design: DLG-10
mixin PostActionsMixin
    on
        ProjectDependencyMixin,
        WriteGuardMixin,
        ExternalLinkMixin,
        BlockUserMixin,
        ReportReceivedMixin {
  /// Gönderi bağlantısındaki yol parçası (`/clubs/:clubId/posts/:postId`).
  static const String postsSegment = 'posts';

  final Set<(_PostOp, String)> _busyPostOps = <(_PostOp, String)>{};

  // ───────────────────────── tüketicinin verdikleri ─────────────────────────

  /// Eylemi yapan: oturumdaki kullanıcı (`BlockUserMixin.blockerId`); oturum
  /// yoksa `null` (hiçbir şey yazılmaz).
  String? get postActorId => blockerId;

  /// Kullanıcının [clubId] kulübüne erişim kipi (`SessionState.accessTo`).
  ClubAccess postAccessOf(String clubId);

  /// State'teki [postId] gönderisi; yoksa `null`.
  PostModel? postOf(String postId);

  /// [post] değişti (beğeni, sabitleme): tüketici state'teki kopyayı bununla
  /// değiştirir. İyimser çağrılır; yazma başarısızsa eski değerle yeniden
  /// çağrılır.
  void onPostChanged(PostModel post);

  /// [post] kaldırıldı: tüketici onu listeden çıkarır (FED-02: "içerik yok").
  /// İyimser çağrılır.
  void onPostRemoved(PostModel post);

  /// [post] geri geldi: kaldırma yazılamadı ya da "Geri al" seçildi. Tüketici
  /// gönderiyi eski yerine koyar.
  void onPostRestored(PostModel post);

  /// [postId] kullanıcının kaydedilenlerinde mi?
  bool isPostSaved(String postId);

  /// [postId] kaydı değişti. İyimser çağrılır; yazma başarısızsa ya da "Geri
  /// al" seçilirse ters değerle yeniden çağrılır.
  void onPostSavedChanged(String postId, {required bool isSaved});

  /// Kullanıcının [postId] anketinde seçtiği seçenek; oy vermediyse (ya da
  /// henüz okunmadıysa) `null`.
  String? myVoteOf(String postId);

  /// [postId] anketinin bilinen oy sayıları (seçenek → oy); henüz
  /// okunmadıysa `null`.
  Map<String, int>? pollResultsOf(String postId);

  /// [postId] anketinin durumu değişti: [myOptionId] kullanıcının oyu (`null`
  /// → oy yok), [results] seçenek başına oy sayısı. İkisi de mutlak değerdir
  /// (tüketici olduğu gibi yazar).
  void onPollChanged(
    String postId, {
    required String? myOptionId,
    required Map<String, int> results,
  });

  /// [authorId] kullanıcısının görünen adı (DLG-12 / DLG-13 / TST-09);
  /// bilinmiyorsa (silinmiş kullanıcı, belge okunmadı) `null`.
  String? postAuthorName(String authorId);

  /// [clubId] kulübünün state'teki sabit gönderisi; yoksa `null`. Yeni bir
  /// gönderi sabitlenince önceki sabit iyimser kaldırılır. Tek gönderi
  /// gösteren tüketici (FED-02) ezmez.
  PostModel? pinnedPostOf(String clubId) => null;

  // ──────────────────────────────── korumalar ───────────────────────────────

  /// Kullanıcı [clubId] kulübünün içeriğini yönetebilir mi (yönetim kurulu /
  /// başkan / süper admin): SHT-08'de "Sabitle" ve "Sil".
  bool canManagePosts(String clubId) => switch (postAccessOf(clubId)) {
    ClubAccess.manager || ClubAccess.superAdmin => true,
    _ => false,
  };

  /// [clubId] kulübünde yazılabilir mi (prototip `app.guard`, `core.js:621`):
  /// danışman salt okunurdur → TST-26; çevrimdışı → TST-24. `false` → çağıran
  /// hiçbir şey yazmadan çıkar.
  bool ensurePostWritable(String clubId) {
    if (postAccessOf(clubId) == ClubAccess.advisor) {
      feedback.showToast(ToastId.tst26);
      return false;
    }
    return ensureOnline();
  }

  // ───────────────────────────── beğeni / kayıt ─────────────────────────────

  /// Beğen / beğeniyi geri al (`<ID>.like.<postId>`). İyimserdir: sayaç ve
  /// kalp anında değişir; yazma başarısızsa geri alınır.
  Future<void> togglePostLike(String postId) async {
    final uid = postActorId;
    final post = postOf(postId);
    if (uid == null || post == null) return;
    if (!ensurePostWritable(post.clubId)) return;
    if (!_begin(_PostOp.like, postId)) return;
    final wasLiked = post.likedBy(uid);
    onPostChanged(post.withLike(uid, liked: !wasLiked));
    final result = wasLiked
        ? await postRepository.unlike(postId, uid: uid)
        : await postRepository.like(postId, uid: uid);
    _end(_PostOp.like, postId);
    if (result case FirebaseFailure(:final error, :final message)) {
      // Güncel kopya üzerinden geri alınır: bu arada gelen canlı değişiklik
      // (yorum sayacı) korunur.
      onPostChanged((postOf(postId) ?? post).withLike(uid, liked: wasLiked));
      showPostWriteFailure(error, message, 'Beğeni yazılamadı');
    }
  }

  /// Kaydet / kaydı kaldır (`<ID>.save.<postId>`, `SHT-08.save`). İyimserdir;
  /// başarıda TST-11 ("Geri al": kaydetme → `softDeleteSaved`, kaldırma →
  /// `restoreSaved`). Danışman da kaydedebilir (kayıt kişiseldir).
  Future<void> togglePostSave(String postId) async {
    final uid = postActorId;
    final post = postOf(postId);
    if (uid == null || post == null || !ensureOnline()) return;
    if (!_begin(_PostOp.save, postId)) return;
    final wasSaved = isPostSaved(postId);
    onPostSavedChanged(postId, isSaved: !wasSaved);
    final result = wasSaved
        ? await savedPostRepository.softDeleteSaved(userId: uid, postId: postId)
        : await savedPostRepository.save(
            userId: uid,
            postId: postId,
            clubId: post.clubId,
          );
    _end(_PostOp.save, postId);
    if (result case FirebaseFailure(:final error, :final message)) {
      onPostSavedChanged(postId, isSaved: wasSaved);
      showPostWriteFailure(error, message, 'Kayıt yazılamadı');
      return;
    }
    feedback.showToast(
      ToastId.tst11,
      params: ToastParams(saved: !wasSaved),
      onAction: () => unawaited(_undoSave(uid, postId, wasSaved: wasSaved)),
    );
  }

  /// TST-11 "Geri al": kayıt [wasSaved] durumuna döner — kaldırma geri
  /// alınıyorsa kayıt geri yüklenir (`restoreSaved`, `savedAt` korunur),
  /// kaydetme geri alınıyorsa kayıt silinmiş olarak işaretlenir.
  Future<void> _undoSave(
    String uid,
    String postId, {
    required bool wasSaved,
  }) async {
    if (!ensureOnline()) return;
    onPostSavedChanged(postId, isSaved: wasSaved);
    final result = wasSaved
        ? await savedPostRepository.restoreSaved(userId: uid, postId: postId)
        : await savedPostRepository.softDeleteSaved(
            userId: uid,
            postId: postId,
          );
    if (result case FirebaseFailure(:final error, :final message)) {
      onPostSavedChanged(postId, isSaved: !wasSaved);
      showPostWriteFailure(error, message, 'Kayıt geri alınamadı');
    }
  }

  // ────────────────────────────────── anket ─────────────────────────────────

  /// [post] anketinin kullanıcıya göre durumunu okur (kullanıcının oyu + oy
  /// sayıları) ve [onPollChanged] ile yazar. Okunamayan parça eski değeriyle
  /// kalır. Anket olmayan gönderide hiçbir şey yapmaz.
  Future<void> loadPollState(PostModel post) async {
    final uid = postActorId;
    final poll = post.poll;
    if (uid == null || poll == null) return;
    final (mine, counts) = await (
      postRepository.myVote(post.id, uid: uid),
      postRepository.countVotes(post.id, [
        for (final option in poll.options) option.id,
      ]),
    ).wait;
    onPollChanged(
      post.id,
      myOptionId: mine.isSuccess ? mine.dataOrNull : myVoteOf(post.id),
      results:
          counts.dataOrNull ?? pollResultsOf(post.id) ?? const <String, int>{},
    );
  }

  /// Anket oyu (`<ID>.vote.<postId>.<optionId>`; prototip `cards.js:85`).
  ///
  /// Oy değiştirilemez: kullanıcı oy verdiyse yalnızca TST-10 gösterilir.
  /// Süresi dolmuş ankette hiçbir şey olmaz. Yazım iyimserdir (seçenek
  /// işaretlenir, sayacı bir artar); başarıda TST-10 ve sayılar yeniden
  /// okunur. Sunucu "zaten oy verilmiş" derse (başka cihaz) gerçek oy okunur.
  Future<VoteOutcome> votePost(String postId, String optionId) async {
    final uid = postActorId;
    final post = postOf(postId);
    final poll = post?.poll;
    if (uid == null || post == null || poll == null) return VoteOutcome.failed;
    if (myVoteOf(postId) != null) {
      feedback.showToast(ToastId.tst10);
      return VoteOutcome.alreadyVoted;
    }
    if (post.pollEnded(appClock)) return VoteOutcome.closed;
    if (!ensurePostWritable(post.clubId)) return VoteOutcome.failed;
    if (!_begin(_PostOp.vote, postId)) return VoteOutcome.failed;
    final before = pollResultsOf(postId) ?? const <String, int>{};
    onPollChanged(
      postId,
      myOptionId: optionId,
      results: {...before, optionId: (before[optionId] ?? 0) + 1},
    );
    final result = await postRepository.vote(
      postId,
      uid: uid,
      optionId: optionId,
    );
    _end(_PostOp.vote, postId);
    switch (result) {
      case FirebaseSuccess():
        feedback.showToast(ToastId.tst10);
        await loadPollState(post);
        return VoteOutcome.voted;
      case FirebaseFailure(error: FirestoreError.alreadyExists):
        // Oy başka cihazdan verilmiş: iyimser sayaç geri alınır, gerçek oy ve
        // sayılar okunur (okunamazsa seçilen seçenek işaretli kalır).
        onPollChanged(postId, myOptionId: optionId, results: before);
        feedback.showToast(ToastId.tst10);
        await loadPollState(post);
        return VoteOutcome.alreadyVoted;
      case FirebaseFailure(:final error, :final message):
        onPollChanged(postId, myOptionId: null, results: before);
        showPostWriteFailure(error, message, 'Oy yazılamadı');
        return VoteOutcome.failed;
    }
  }

  // ──────────────────────────── sabitle / kaldır ────────────────────────────

  /// Sabitle / sabitlemeyi kaldır (`SHT-08.pin`) → TST-53. İyimserdir; kulüpte
  /// en çok bir sabit gönderi olur: yenisi sabitlenince [pinnedPostOf]
  /// sabitlikten çıkar.
  Future<void> togglePostPin(String postId) async {
    final post = postOf(postId);
    if (post == null || !ensurePostWritable(post.clubId)) return;
    if (!_begin(_PostOp.pin, postId)) return;
    final pin = !post.pinned;
    final other = pin ? pinnedPostOf(post.clubId) : null;
    final previous = other != null && other.id != postId ? other : null;
    if (previous != null) onPostChanged(previous.copyWith(pinned: false));
    onPostChanged(post.copyWith(pinned: pin));
    final result = pin
        ? await postRepository.pin(postId, clubId: post.clubId)
        : await postRepository.unpin(postId, clubId: post.clubId);
    _end(_PostOp.pin, postId);
    if (result case FirebaseFailure(:final error, :final message)) {
      onPostChanged((postOf(postId) ?? post).copyWith(pinned: !pin));
      if (previous != null) {
        onPostChanged(
          (postOf(previous.id) ?? previous).copyWith(pinned: true),
        );
      }
      showPostWriteFailure(error, message, 'Sabitleme yazılamadı');
      return;
    }
    feedback.showToast(ToastId.tst53, params: ToastParams(pinned: pin));
  }

  /// Gönderiyi kaldır (`SHT-08.delete`): DLG-10 onayı → `softDeletePost` →
  /// TST-45 "{what} silindi." ("Geri al" → `restorePost`; gönderi yeniden
  /// sabitlenmez). [what] toast'taki yerelleştirilmiş addır ("Gönderi" —
  /// `l10n.feedTypePost`; view verir).
  ///
  /// `true` → kaldırıldı. `false` → danışman (TST-26), çevrimdışı (TST-24),
  /// vazgeçildi ya da yazma hatası (gönderi geri gelir).
  Future<bool> removePost(String postId, {required String what}) async {
    final uid = postActorId;
    final post = postOf(postId);
    if (uid == null || post == null) return false;
    if (!ensurePostWritable(post.clubId)) return false;
    if (!_begin(_PostOp.remove, postId)) return false;
    try {
      final confirmed =
          await feedback.showDialog<bool>(DialogId.dlg10) ?? false;
      if (!confirmed || !ensureOnline()) return false;
      onPostRemoved(post);
      final result = await postRepository.softDeletePost(
        postId,
        actorId: uid,
        clubId: post.clubId,
      );
      if (result case FirebaseFailure(:final error, :final message)) {
        onPostRestored(post);
        showPostWriteFailure(error, message, 'Gönderi kaldırılamadı');
        return false;
      }
      feedback.showToast(
        ToastId.tst45,
        params: ToastParams(what: what),
        onAction: () => unawaited(_undoRemove(post)),
      );
      return true;
    } finally {
      _end(_PostOp.remove, postId);
    }
  }

  /// TST-45 "Geri al": [post] geri yüklenir. Kaldırma sabitlemeyi de
  /// kaldırdığından gönderi sabit olmadan döner.
  Future<void> _undoRemove(PostModel post) async {
    if (!ensureOnline()) return;
    final restored = post.copyWith(pinned: false);
    onPostRestored(restored);
    final result = await postRepository.restorePost(post.id);
    if (result case FirebaseFailure(:final error, :final message)) {
      onPostRemoved(restored);
      showPostWriteFailure(error, message, 'Gönderi geri alınamadı');
    }
  }

  // ───────────────────────── paylaş / şikayet / engel ───────────────────────

  /// [post] gönderisinin paylaşım bağlantısı
  /// (`AppConstants.shareBaseUrl` + `/clubs/:clubId/posts/:postId`).
  String postShareUrl(PostModel post) =>
      '${AppConstants.shareBaseUrl}${AppPaths.clubs}/${post.clubId}'
      '/$postsSegment/${post.id}';

  /// Paylaşım sayfasındaki ad: duyuruda başlık, değilse metin
  /// (`sheets.js:75`).
  String postShareTitle(PostModel post) => post.title ?? post.text;

  /// "Bağlantıyı kopyala" (`SHT-08.copyLink`) → TST-35.
  Future<void> copyPostLink(PostModel post) async {
    if (await shareService.copyText(postShareUrl(post))) {
      feedback.showToast(ToastId.tst35);
    }
  }

  /// "Paylaş" (`<ID>.share.<postId>`, `SHT-08.share`, `SHT-34.share`): SHT-15
  /// açılır ve seçilen yol uygulanır — kopyala → TST-35; WhatsApp / e-posta →
  /// harici bağlantı onayı (DLG-32); "Diğer…" → sistem paylaşım sayfası.
  Future<void> sharePost(String postId) async {
    final post = postOf(postId);
    if (post == null) return;
    final url = postShareUrl(post);
    final title = postShareTitle(post);
    final choice = await feedback.showSheet<ShareChoice>(
      SheetId.sht15,
      builder: (_) => ShareSheet(title: title, url: url),
    );
    switch (choice) {
      case null:
        return;
      case ShareChoice.copyLink:
        await copyPostLink(post);
      case ShareChoice.whatsapp:
        await openExternalLink(ShareLinks.whatsApp(url));
      case ShareChoice.email:
        await openExternalLink(ShareLinks.email(title));
      case ShareChoice.other:
        await shareService.shareText(url, subject: title);
    }
  }

  /// "Şikayet et" (`SHT-08.report`): SHT-10 → DLG-12 ([reportContent]).
  /// Yazarın adı biliniyorsa DLG-12'de "{ad} kullanıcısını da engelle"
  /// çizilir.
  Future<void> reportPost(String postId) async {
    final post = postOf(postId);
    if (post == null) return;
    await reportContent(
      (type: ReportTargetType.post, id: post.id, clubId: post.clubId),
      userId: post.authorId,
      blockableName: () =>
          post.authorId == postActorId ? null : postAuthorName(post.authorId),
    );
  }

  /// Şikayet akışının ortak çekirdeği (gönderi, yorum, kullanıcı): SHT-10'u
  /// [target] için açar → `reportRepository.report`
  /// (`ReportReceivedMixin.sendReport`) → DLG-12. [userId] şikayetin bağlı
  /// olduğu kullanıcıdır; [blockableName] onun adını verirse (kendisi, zaten
  /// engelli ya da adı bilinmeyen kullanıcıda `null`) DLG-12'de "{ad}
  /// kullanıcısını da engelle" çizilir; seçilirse DLG-13
  /// (`BlockUserMixin.blockUser`). Ad, sheet kapandıktan sonra sorulur.
  Future<void> reportContent(
    ReportTarget target, {
    required String userId,
    required String? Function() blockableName,
  }) async {
    final report = await feedback.showSheet<ReportReasonResult>(
      SheetId.sht10,
      builder: (_) => ReportReasonSheet(
        target: target,
        onSubmit: (result) =>
            sendReport(reporterId: postActorId, report: result),
      ),
    );
    if (report == null) return;
    final name = blockableName();
    final wantsBlock = await showReportReceivedDialog(blockableUserName: name);
    if (wantsBlock && name != null) {
      await blockUser(userId: userId, name: name);
    }
  }

  /// "Kullanıcıyı engelle" (`SHT-08.block`): DLG-13 → `block` → TST-09
  /// (`BlockUserMixin.blockUser`). Yazarın adı bilinmiyorsa (silinmiş
  /// kullanıcı) hiçbir şey yapılmaz.
  Future<bool> blockPostAuthor(String postId) async {
    final post = postOf(postId);
    final name = post == null ? null : postAuthorName(post.authorId);
    if (post == null || name == null) return false;
    return blockUser(userId: post.authorId, name: name);
  }

  // ─────────────────────────────── SHT-08 menü ──────────────────────────────

  /// Gönderi menüsü (`<ID>.menu.<postId>`): SHT-08'i açar ve seçilen satırı
  /// [handlePostMenu] ile yürütür. [removedLabel] TST-45'teki addır
  /// (`l10n.feedTypePost`).
  Future<PostMenuOutcome> openPostMenu(
    String postId, {
    required String removedLabel,
  }) async {
    final uid = postActorId;
    final post = postOf(postId);
    if (uid == null || post == null) return PostMenuOutcome.none;
    final action = await feedback.showSheet<PostMenuAction>(
      SheetId.sht08,
      builder: (_) => PostMenu(
        isOwn: post.authorId == uid,
        canManage: canManagePosts(post.clubId),
        isSaved: isPostSaved(postId),
        isPinned: post.pinned,
      ),
    );
    if (action == null) return PostMenuOutcome.none;
    return handlePostMenu(action, post, removedLabel: removedLabel);
  }

  /// SHT-08'de seçilen [action] satırını [post] için yürütür
  /// (`sheets.js:41–43`). Dönen değer view'a kalan iştir (gezinme).
  Future<PostMenuOutcome> handlePostMenu(
    PostMenuAction action,
    PostModel post, {
    required String removedLabel,
  }) async {
    switch (action) {
      case PostMenuAction.save || PostMenuAction.unsave:
        await togglePostSave(post.id);
      case PostMenuAction.share:
        await sharePost(post.id);
      case PostMenuAction.copyLink:
        await copyPostLink(post);
      case PostMenuAction.report:
        await reportPost(post.id);
      case PostMenuAction.blockAuthor:
        await blockPostAuthor(post.id);
      case PostMenuAction.edit:
        // Yazı düzenleme ekranına (FED-03 düzenleme kipi) view gider —
        // W-25, T-21.
        if (ensurePostWritable(post.clubId)) return PostMenuOutcome.edit;
      case PostMenuAction.pin || PostMenuAction.unpin:
        await togglePostPin(post.id);
      case PostMenuAction.remove:
        if (await removePost(post.id, what: removedLabel)) {
          return PostMenuOutcome.removed;
        }
    }
    return PostMenuOutcome.none;
  }

  // ────────────────────────────────── iç ────────────────────────────────────

  /// [op] işlemi [postId] için başlar; aynısı sürüyorsa `false`.
  bool _begin(_PostOp op, String postId) => _busyPostOps.add((op, postId));

  void _end(_PostOp op, String postId) => _busyPostOps.remove((op, postId));

  /// Yazma hatasının bildirimi: ağ → TST-24, yetki yok → TST-X18
  /// (`WriteGuardMixin.showWriteFailureToast`); diğerleri [what] ile günlüğe
  /// düşer. Gönderiye bağlı öteki yazımlar (yorum) da bunu kullanır.
  void showPostWriteFailure(
    FirestoreError error,
    String? message,
    String what,
  ) {
    if (showWriteFailureToast(error)) return;
    AppLogger.warn('$what: ${error.name}', error: message);
  }
}

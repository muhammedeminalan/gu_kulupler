// T-20 · PostActionsMixin — gönderi eylemlerinin ortak çekirdeği (FED-01,
// FED-02): beğeni / kayıt (iyimser + geri alma, TST-11 "Geri al"), anket oyu
// (TST-10), sabitleme (TST-53), kaldırma (DLG-10 → TST-45 "Geri al"),
// paylaşım (SHT-15 → TST-35), şikayet (SHT-10 → DLG-12 → DLG-13), SHT-08
// menü yönlendirmesi; danışman salt okunur (TST-26), çevrimdışı (TST-24).
// Referans: prototip cards.js:83–127, sheets.js:40–43, dialogs.js:26.
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/constants/app_constants.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/dialog_spec.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/post_menu.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/report_reason_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/share_sheet.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/mixin/block_user_mixin.dart';
import 'package:gu_kulupler/product/mixin/external_link_mixin.dart';
import 'package:gu_kulupler/product/mixin/post_actions_mixin.dart';
import 'package:gu_kulupler/product/mixin/report_received_mixin.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';
import 'package:gu_kulupler/product/service/share_service.dart';

import '../../fakes/fake_block_repository.dart';
import '../../fakes/fake_connectivity_service.dart';
import '../../fakes/fake_feedback_service.dart';
import '../../fakes/fake_post_repository.dart';
import '../../fakes/fake_report_repository.dart';
import '../../fakes/fake_saved_post_repository.dart';
import '../../fakes/fake_share_service.dart';
import '../../fakes/register_fakes.dart';
import '../../fixtures/post_model_fixtures.dart';
import '../../helpers/design_files.dart';

const String _uid = 'u_test';
const String _club = 'c01';
const String _what = 'Gönderi';

/// Gönderi gösteren bir ViewModel'in en küçük hali: state bellekte tutulur.
final class _Notifier
    with
        ProjectDependencyMixin,
        WriteGuardMixin,
        ExternalLinkMixin,
        BlockUserMixin,
        ReportReceivedMixin,
        PostActionsMixin {
  _Notifier(Iterable<PostModel> initial) {
    for (final post in initial) {
      posts[post.id] = post;
    }
  }

  final Map<String, PostModel> posts = <String, PostModel>{};
  final Set<String> saved = <String>{};
  final Map<String, String> myVotes = <String, String>{};
  final Map<String, Map<String, int>> results = <String, Map<String, int>>{};
  final Map<String, bool> blocks = <String, bool>{};
  final Map<String, String> names = <String, String>{};
  ClubAccess access = ClubAccess.member;
  String? uid = _uid;

  @override
  String? get blockerId => uid;

  @override
  void onBlockChanged(String userId, {required bool isBlocked}) =>
      blocks[userId] = isBlocked;

  @override
  ClubAccess postAccessOf(String clubId) => access;

  @override
  PostModel? postOf(String postId) => posts[postId];

  @override
  void onPostChanged(PostModel post) => posts[post.id] = post;

  @override
  void onPostRemoved(PostModel post) => posts.remove(post.id);

  @override
  void onPostRestored(PostModel post) => posts[post.id] = post;

  @override
  bool isPostSaved(String postId) => saved.contains(postId);

  @override
  void onPostSavedChanged(String postId, {required bool isSaved}) =>
      isSaved ? saved.add(postId) : saved.remove(postId);

  @override
  String? myVoteOf(String postId) => myVotes[postId];

  @override
  Map<String, int>? pollResultsOf(String postId) => results[postId];

  @override
  void onPollChanged(
    String postId, {
    required String? myOptionId,
    required Map<String, int> results,
  }) {
    if (myOptionId == null) {
      myVotes.remove(postId);
    } else {
      myVotes[postId] = myOptionId;
    }
    this.results[postId] = results;
  }

  @override
  String? postAuthorName(String authorId) => names[authorId];

  @override
  PostModel? pinnedPostOf(String clubId) => posts.values
      .where((post) => post.clubId == clubId && post.pinned)
      .firstOrNull;
}

void main() {
  late FakeFeedbackService feedback;
  late FakePostRepository postRepository;
  late FakeSavedPostRepository savedRepository;
  late FakeConnectivityService connectivity;
  late FakeShareService share;
  late PostModel announcement; // p01: sabit duyuru
  late PostModel images; // p02: görselli gönderi
  late PostModel poll; // p04: süresi dolmamış anket
  late _Notifier notifier;

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
    postRepository = GetIt.I<PostRepository>() as FakePostRepository;
    savedRepository = GetIt.I<SavedPostRepository>() as FakeSavedPostRepository;
    connectivity = GetIt.I<ConnectivityService>() as FakeConnectivityService;
    share = GetIt.I<ShareService>() as FakeShareService;
    final now = GetIt.I<AppClock>().nowUtc();
    announcement = PostModelFixtures.p01.copyWith(pinned: true);
    images = PostModelFixtures.p02.copyWith(pinned: false);
    poll = PostModelFixtures.p04.copyWith(
      poll: PostModelFixtures.p04.poll!.copyWith(
        endsAt: now.add(const Duration(days: 1)),
      ),
    );
    [announcement, images, poll].forEach(postRepository.put);
    notifier = _Notifier([announcement, images, poll])
      ..names[images.authorId] = 'Elif Demir';
    postRepository.calls.clear();
  });

  group('T-20 · PostActionsMixin · beğeni', () {
    test('beğen → iyimser + `like`; yeniden → `unlike`; toast yok', () async {
      final before = images.likeCount;
      await notifier.togglePostLike(images.id);

      expect(notifier.posts[images.id]!.likedBy(_uid), isTrue);
      expect(notifier.posts[images.id]!.likeCount, before + 1);
      expect(postRepository.posts[images.id]!.likedBy(_uid), isTrue);

      await notifier.togglePostLike(images.id);

      expect(notifier.posts[images.id]!.likedBy(_uid), isFalse);
      expect(notifier.posts[images.id]!.likeCount, before);
      expect(postRepository.callsTo('unlike'), hasLength(1));
      expect(feedback.toasts, isEmpty);
    });

    test('yazma hatası → geri alınır; yetki TST-X18, ağ TST-24', () async {
      for (final (error, toast) in [
        (FirestoreError.permissionDenied, ToastId.tstX18),
        (FirestoreError.unavailable, ToastId.tst24),
      ]) {
        feedback.toasts.clear();
        postRepository.failNext(error);
        await notifier.togglePostLike(images.id);

        expect(notifier.posts[images.id], images, reason: error.name);
        expect(feedback.toasts, [toast], reason: error.name);
      }
    });

    test('danışman → TST-26; çevrimdışı → TST-24; oturum yok → sessiz; '
        'hiçbiri yazmaz', () async {
      notifier.access = ClubAccess.advisor;
      await notifier.togglePostLike(images.id);
      notifier.access = ClubAccess.member;
      connectivity.isOffline = true;
      await notifier.togglePostLike(images.id);
      connectivity.isOffline = false;
      notifier.uid = null;
      await notifier.togglePostLike(images.id);

      expect(feedback.toasts, [ToastId.tst26, ToastId.tst24]);
      expect(postRepository.calls, isEmpty);
      expect(notifier.posts[images.id], images);
    });
  });

  group('T-20 · PostActionsMixin · kaydet (TST-11)', () {
    test('kaydet → TST-11 (eklendi); "Geri al" → kayıt kaldırılır', () async {
      await notifier.togglePostSave(images.id);

      expect(notifier.saved, {images.id});
      expect(feedback.toasts, [ToastId.tst11]);
      expect(feedback.toastParams.single.saved, isTrue);
      expect(
        savedRepository.callsTo('save').single.args,
        [_uid, images.id, _club],
      );

      feedback.tapToastAction();
      await pumpEventQueue();

      expect(notifier.saved, isEmpty);
      expect(savedRepository.callsTo('softDeleteSaved'), hasLength(1));
      expect(savedRepository.saved.values.single.isDeleted, isTrue);
    });

    test(
      'kaydı kaldır → TST-11 (kaldırıldı); "Geri al" → `restoreSaved`',
      () async {
        await notifier.togglePostSave(images.id);
        await notifier.togglePostSave(images.id);

        expect(notifier.saved, isEmpty);
        expect(feedback.toasts, [ToastId.tst11, ToastId.tst11]);
        expect(feedback.toastParams.last.saved, isFalse);

        feedback.tapToastAction();
        await pumpEventQueue();

        expect(notifier.saved, {images.id});
        expect(savedRepository.callsTo('restoreSaved'), hasLength(1));
        expect(savedRepository.saved.values.single.isDeleted, isFalse);
      },
    );

    test('yazma hatası → geri alınır + toast; "Geri al" hatası da geri '
        'alınır; çevrimdışı yazmaz', () async {
      savedRepository.failNext(FirestoreError.permissionDenied);
      await notifier.togglePostSave(images.id);
      expect(notifier.saved, isEmpty);
      expect(feedback.toasts, [ToastId.tstX18]);

      await notifier.togglePostSave(images.id);
      savedRepository.failNext(FirestoreError.unavailable);
      feedback.tapToastAction();
      await pumpEventQueue();
      expect(notifier.saved, {images.id});
      expect(feedback.toasts.last, ToastId.tst24);

      final writes = savedRepository.calls.length;
      connectivity.isOffline = true;
      await notifier.togglePostSave(images.id);
      expect(savedRepository.calls, hasLength(writes));
      expect(notifier.saved, {images.id});
    });
  });

  group('T-20 · PostActionsMixin · anket oyu (TST-10)', () {
    test('oy ver → seçenek işaretlenir, sayılar okunur, TST-10', () async {
      postRepository.votes[poll.id] = {'u_other': 'o1'};

      expect(await notifier.votePost(poll.id, 'o2'), VoteOutcome.voted);

      expect(notifier.myVotes[poll.id], 'o2');
      expect(notifier.results[poll.id], {'o1': 1, 'o2': 1, 'o3': 0, 'o4': 0});
      expect(postRepository.votes[poll.id]![_uid], 'o2');
      expect(feedback.toasts, [ToastId.tst10]);
    });

    test('oy verilmişse yalnızca TST-10 (yazım yok); sunucu "zaten var" '
        'derse gerçek oy okunur', () async {
      notifier.myVotes[poll.id] = 'o1';
      expect(
        await notifier.votePost(poll.id, 'o2'),
        VoteOutcome.alreadyVoted,
      );
      expect(postRepository.callsTo('vote'), isEmpty);
      expect(notifier.myVotes[poll.id], 'o1');

      notifier.myVotes.clear();
      postRepository.votes[poll.id] = {_uid: 'o3'};
      expect(
        await notifier.votePost(poll.id, 'o2'),
        VoteOutcome.alreadyVoted,
      );
      expect(notifier.myVotes[poll.id], 'o3');
      expect(notifier.results[poll.id]!['o3'], 1);
      expect(notifier.results[poll.id]!['o2'], 0);
      expect(feedback.toasts, [ToastId.tst10, ToastId.tst10]);
    });

    test('süresi dolmuş anket → sessiz; danışman → TST-26; yazma hatası → '
        'geri alınır', () async {
      notifier.access = ClubAccess.advisor;
      expect(await notifier.votePost(poll.id, 'o1'), VoteOutcome.failed);
      expect(feedback.toasts, [ToastId.tst26]);
      notifier.access = ClubAccess.member;

      postRepository.failNext(FirestoreError.unavailable);
      expect(await notifier.votePost(poll.id, 'o1'), VoteOutcome.failed);
      expect(notifier.myVotes, isEmpty);
      expect(notifier.results[poll.id], isEmpty);
      expect(feedback.toasts, [ToastId.tst26, ToastId.tst24]);

      final ended = poll.copyWith(
        poll: poll.poll!.copyWith(
          endsAt: GetIt.I<AppClock>().nowUtc().subtract(
            const Duration(minutes: 1),
          ),
        ),
      );
      notifier.posts[poll.id] = ended;
      final votes = postRepository.callsTo('vote').length;
      expect(await notifier.votePost(poll.id, 'o1'), VoteOutcome.closed);
      expect(postRepository.callsTo('vote'), hasLength(votes));
      expect(feedback.toasts, hasLength(2));
    });
  });

  group('T-20 · PostActionsMixin · sabitle (TST-53)', () {
    test('sabitle → önceki sabit kalkar, TST-53 (sabitlendi); kaldır → '
        'TST-53 (kaldırıldı)', () async {
      notifier.access = ClubAccess.manager;
      await notifier.togglePostPin(images.id);

      expect(notifier.posts[images.id]!.pinned, isTrue);
      expect(notifier.posts[announcement.id]!.pinned, isFalse);
      expect(postRepository.pinnedByClub[_club], images.id);
      expect(feedback.toasts, [ToastId.tst53]);
      expect(feedback.toastParams.single.pinned, isTrue);

      await notifier.togglePostPin(images.id);

      expect(notifier.posts[images.id]!.pinned, isFalse);
      expect(postRepository.pinnedByClub, isEmpty);
      expect(feedback.toastParams.last.pinned, isFalse);
    });

    test('yazma hatası → iki gönderi de eski haline döner; danışman → '
        'TST-26', () async {
      notifier.access = ClubAccess.manager;
      postRepository.failNext(FirestoreError.permissionDenied);
      await notifier.togglePostPin(images.id);

      expect(notifier.posts[images.id]!.pinned, isFalse);
      expect(notifier.posts[announcement.id]!.pinned, isTrue);
      expect(feedback.toasts, [ToastId.tstX18]);

      notifier.access = ClubAccess.advisor;
      await notifier.togglePostPin(images.id);
      expect(feedback.toasts.last, ToastId.tst26);
      expect(postRepository.callsTo('pin'), hasLength(1));
    });
  });

  group('DLG-10 · PostActionsMixin · gönderiyi kaldır (TST-45)', () {
    test('onay → `softDeletePost`, gönderi listeden çıkar, TST-45; "Geri '
        'al" → `restorePost` (sabit olmadan döner)', () async {
      notifier.access = ClubAccess.manager;
      feedback.nextDialogResult = true;

      expect(await notifier.removePost(announcement.id, what: _what), isTrue);

      expect(feedback.dialogs, [DialogId.dlg10]);
      expect(notifier.posts.containsKey(announcement.id), isFalse);
      expect(postRepository.posts[announcement.id]!.isDeleted, isTrue);
      expect(
        postRepository.callsTo('softDeletePost').single.args,
        [announcement.id, _uid, _club],
      );
      expect(feedback.toasts, [ToastId.tst45]);
      expect(feedback.toastParams.single.what, _what);

      feedback.tapToastAction();
      await pumpEventQueue();

      expect(notifier.posts[announcement.id]!.pinned, isFalse);
      expect(postRepository.posts[announcement.id]!.isDeleted, isFalse);
    });

    test('vazgeç → hiçbir şey; yazma hatası → gönderi geri gelir + toast; '
        'danışman → TST-26 (dialog yok)', () async {
      notifier.access = ClubAccess.manager;
      expect(await notifier.removePost(images.id, what: _what), isFalse);
      expect(postRepository.callsTo('softDeletePost'), isEmpty);

      feedback.nextDialogResult = true;
      postRepository.failNext(FirestoreError.permissionDenied);
      expect(await notifier.removePost(images.id, what: _what), isFalse);
      expect(notifier.posts[images.id], images);
      expect(feedback.toasts, [ToastId.tstX18]);

      notifier.access = ClubAccess.advisor;
      expect(await notifier.removePost(images.id, what: _what), isFalse);
      expect(feedback.dialogs, [DialogId.dlg10, DialogId.dlg10]);
      expect(feedback.toasts.last, ToastId.tst26);
    });

    test('`/// Design: DLG-10` izi mixin bildirimindedir; katalog kaydı '
        'yıkıcıdır', () {
      expect(
        readText('lib/product/mixin/post_actions_mixin.dart'),
        contains(RegExp(r'/// Design: DLG-10\s*\nmixin PostActionsMixin\b')),
      );
      for (final id in [DialogId.dlg10, DialogId.dlg11]) {
        final spec = DialogCatalog.of(id)!;
        expect(spec.isPrimaryDanger, isTrue, reason: id.designId);
        expect(spec.primaryAction, 'confirm', reason: id.designId);
        expect(spec.secondaryAction, 'cancel', reason: id.designId);
      }
    });
  });

  group('T-20 · PostActionsMixin · paylaş / şikayet', () {
    test('bağlantı = paylaşım kökü + gönderi rotası; SHT-15 kopyala → pano '
        '+ TST-35; "Diğer…" → sistem paylaşımı', () async {
      final url = notifier.postShareUrl(images);
      expect(
        url,
        AppConstants.shareBaseUrl +
            PostDetailRoute(clubId: _club, postId: images.id).location,
      );

      feedback.nextSheetResult = ShareChoice.copyLink;
      await notifier.sharePost(images.id);
      expect(feedback.sheets, [SheetId.sht15]);
      expect(share.copied, [url]);
      expect(feedback.toasts, [ToastId.tst35]);

      feedback.nextSheetResult = ShareChoice.other;
      await notifier.sharePost(images.id);
      expect(share.sharedTexts, [url]);

      await notifier.sharePost(images.id); // sayfa seçimsiz kapandı
      expect(share.sharedTexts, hasLength(1));
    });

    test('şikayet: SHT-10 → DLG-12 (yazar adıyla) → "engelle" → DLG-13 → '
        'engel yazılır; kendi gönderisinde ad verilmez', () async {
      const report = ReportReasonResult(
        target: (type: ReportTargetType.post, id: 'p02', clubId: _club),
        reason: ReportReason.spam,
      );
      feedback
        ..nextSheetResult = report
        ..dialogResults[DialogId.dlg12] = false
        ..dialogResults[DialogId.dlg13] = true;

      await notifier.reportPost(images.id);

      expect(feedback.sheets, [SheetId.sht10]);
      expect(feedback.dialogs, [DialogId.dlg12, DialogId.dlg13]);
      expect(feedback.dialogParams.first, {DialogParamKeys.name: 'Elif Demir'});
      expect(notifier.blocks, {images.authorId: true});
      expect(
        (GetIt.I<BlockRepository>() as FakeBlockRepository).callsTo('block'),
        hasLength(1),
      );
      expect(feedback.toasts, [ToastId.tst09]);

      feedback
        ..dialogs.clear()
        ..dialogParams.clear()
        ..nextSheetResult = report;
      notifier.uid = images.authorId;
      await notifier.reportPost(images.id);
      expect(feedback.dialogs, [DialogId.dlg12]);
      expect(feedback.dialogParams.single, isEmpty);

      // Sayfa gönderilmeden kapandı: DLG-12 açılmaz.
      feedback.dialogs.clear();
      await notifier.reportPost(images.id);
      expect(feedback.dialogs, isEmpty);
      expect(
        (GetIt.I<ReportRepository>() as FakeReportRepository).reports,
        isEmpty,
      );
    });
  });

  group('SHT-08 · PostActionsMixin · menü', () {
    test(
      'menü kullanıcıya göre açılır; seçim yoksa hiçbir şey olmaz',
      () async {
        expect(
          await notifier.openPostMenu(images.id, removedLabel: _what),
          PostMenuOutcome.none,
        );
        expect(feedback.sheets, [SheetId.sht08]);
        expect(feedback.toasts, isEmpty);
        expect(postRepository.calls, isEmpty);
      },
    );

    test('satırlar ortak eylemlere gider: kaydet → TST-11, bağlantı → '
        'TST-35, sabitle → TST-53, engelle → DLG-13', () async {
      notifier.access = ClubAccess.manager;
      Future<PostMenuOutcome> pick(PostMenuAction action) {
        feedback.nextSheetResult = action;
        return notifier.openPostMenu(images.id, removedLabel: _what);
      }

      expect(await pick(PostMenuAction.save), PostMenuOutcome.none);
      expect(await pick(PostMenuAction.copyLink), PostMenuOutcome.none);
      expect(await pick(PostMenuAction.pin), PostMenuOutcome.none);
      expect(await pick(PostMenuAction.blockAuthor), PostMenuOutcome.none);

      expect(feedback.toasts, [ToastId.tst11, ToastId.tst35, ToastId.tst53]);
      expect(notifier.saved, {images.id});
      expect(notifier.posts[images.id]!.pinned, isTrue);
      expect(feedback.dialogs, [DialogId.dlg13]);
    });

    test('"Sil" → DLG-10 → `removed`; "Düzenle" → `edit` (view FED-03\'e '
        'gider); danışmanda "Düzenle" → TST-26', () async {
      notifier.access = ClubAccess.manager;
      feedback.dialogResults[DialogId.dlg10] = true;
      expect(
        await notifier.handlePostMenu(
          PostMenuAction.remove,
          images,
          removedLabel: _what,
        ),
        PostMenuOutcome.removed,
      );
      expect(notifier.posts.containsKey(images.id), isFalse);

      expect(
        await notifier.handlePostMenu(
          PostMenuAction.edit,
          announcement,
          removedLabel: _what,
        ),
        PostMenuOutcome.edit,
      );

      notifier.access = ClubAccess.advisor;
      expect(
        await notifier.handlePostMenu(
          PostMenuAction.edit,
          announcement,
          removedLabel: _what,
        ),
        PostMenuOutcome.none,
      );
      expect(feedback.toasts.last, ToastId.tst26);
    });

    test('`actionsFor`: şikayet / engelle yalnızca başkasının gönderisinde; '
        'sabitle / sil yönetene; düzenle yalnızca yazar yöneticiye', () {
      List<String> rows({
        bool isOwn = false,
        bool canManage = false,
        bool isSaved = false,
        bool isPinned = false,
      }) => [
        for (final action in PostMenu.actionsFor(
          isOwn: isOwn,
          canManage: canManage,
          isSaved: isSaved,
          isPinned: isPinned,
        ))
          action.name,
      ];

      expect(rows(), ['save', 'share', 'copyLink', 'report', 'blockAuthor']);
      expect(rows(isOwn: true, isSaved: true), [
        'unsave',
        'share',
        'copyLink',
      ]);
      expect(rows(canManage: true, isPinned: true), [
        'save',
        'share',
        'copyLink',
        'report',
        'blockAuthor',
        'unpin',
        'remove',
      ]);
      expect(rows(isOwn: true, canManage: true), [
        'save',
        'share',
        'copyLink',
        'edit',
        'pin',
        'remove',
      ]);
      expect(notifier.canManagePosts(_club), isFalse);
      notifier.access = ClubAccess.superAdmin;
      expect(notifier.canManagePosts(_club), isTrue);
    });
  });
}

// FED-02 · PostDetailViewModel: canlı gönderi + yorum akışı (olay → state,
// kapanışta abonelik iptali), yazarların toplu okunması, "içerik yok" dalları
// (yok / silinmiş / gizli / başka kulüp / yorum akışı permissionDenied —
// W-70), hata, yorum yazma (sınır, boş, danışman TST-26, çevrimdışı TST-24,
// TST-12), yorum kaldırma (DLG-11 → TST-45 → Geri al), yorum menüsü (SHT-27),
// yorum şikayeti (SHT-10 → DLG-12 → DLG-13), iyimser beğeni geri alma,
// gönderi kaldırma — PLAN §12.8.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/feed/provider/post_detail_state.dart';
import 'package:gu_kulupler/features/feed/provider/post_detail_view_model.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/post_menu.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/report_reason_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/user_menu_sheet.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/mixin/post_actions_mixin.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';

import '../../../fakes/fake_block_repository.dart';
import '../../../fakes/fake_comment_repository.dart';
import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_post_repository.dart';
import '../../../fakes/fake_report_repository.dart';
import '../../../fakes/fake_user_repository.dart';
import '../../../fakes/register_fakes.dart';
import '../../../fixtures/user_model_fixtures.dart';
import '../../../helpers/test_container.dart';
import '../post_detail_test_support.dart';

const String _postLabel = 'Gönderi';
const String _commentLabel = 'Yorum';

void main() {
  late FakePostRepository posts;
  late FakeCommentRepository comments;
  late FakeUserRepository users;
  late FakeBlockRepository blocks;
  late FakeReportRepository reports;
  late FakeFeedbackService feedback;
  late FakeConnectivityService connectivity;

  final provider = postDetailViewModelProvider(
    clubId: kPostClubId,
    postId: kPostId,
  );

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    posts = GetIt.I<PostRepository>() as FakePostRepository;
    comments = GetIt.I<CommentRepository>() as FakeCommentRepository;
    users = GetIt.I<UserRepository>() as FakeUserRepository;
    blocks = GetIt.I<BlockRepository>() as FakeBlockRepository;
    reports = GetIt.I<ReportRepository>() as FakeReportRepository;
    feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
    connectivity = GetIt.I<ConnectivityService>() as FakeConnectivityService;
    await seedPost();
  });

  /// [session] oturumuyla, [of] ViewModel'i dinlenen kapsayıcı. İlk okuma
  /// **bekletilmez**.
  ProviderContainer containerOf({
    SessionState? session,
    PostDetailViewModelProvider? of,
  }) {
    final container = createContainer(
      overrides: [
        sessionViewModelProvider.overrideWithBuild(
          (ref, notifier) => session ?? postSession(),
        ),
      ],
    );
    addTearDown(container.listen(of ?? provider, (_, _) {}).close);
    return container;
  }

  /// İlk okuması bitmiş kapsayıcı (okuma çağrıları sayılmaz).
  Future<ProviderContainer> loaded({SessionState? session}) async {
    final container = containerOf(session: session);
    await pumpEventQueue();
    posts.calls.clear();
    comments.calls.clear();
    users.calls.clear();
    return container;
  }

  PostDetailViewModel vmOf(ProviderContainer container) =>
      container.read(provider.notifier);

  PostDetailState stateOf(ProviderContainer container) =>
      container.read(provider);

  /// Oturumdaki kullanıcının yazdığı yorum (yorum yazma akışıyla eklenir).
  Future<CommentModel> ownComment(ProviderContainer container) async {
    vmOf(container).setCommentDraft('Ben de geliyorum.');
    await vmOf(container).sendComment();
    await pumpEventQueue();
    feedback.resetFake();
    comments.calls.clear();
    return comments.added.single;
  }

  group('FED-02 · PostDetailViewModel · canlı okuma', () {
    test('ilk kare iskelet; ilk olaylarla gönderi, kulüp, yorumlar (eskiden '
        'yeniye), yazarlar (toplu), roller ve kayıt durumu gelir', () async {
      final container = containerOf();
      expect(stateOf(container).isFetching, isTrue);
      expect(stateOf(container).isFetchingComments, isTrue);
      expect(stateOf(container).post, isNull);

      await pumpEventQueue();
      final state = stateOf(container);
      expect(state.isFetching || state.isFetchingComments, isFalse);
      expect(state.isError || state.isNotFound, isFalse);
      expect(state.post, kPost);
      expect(state.club, kPostClub);
      expect(state.comments, kPostComments);
      expect(state.comments.map((comment) => comment.id), [
        'cm03',
        'cm02',
        'cm01',
      ]);
      expect(state.users.keys, {
        kPost.authorId,
        for (final comment in kPostComments) comment.authorId,
      });
      expect(state.roles, kPostRoles);
      expect(state.roles[kPost.authorId], ClubRole.president);
      expect(state.isSaved, isTrue);
      expect(posts.callsTo('watchPost'), hasLength(1));
      expect(posts.callsTo('getPost'), isEmpty);
      expect(comments.callsTo('watchComments'), hasLength(1));
      // Yorum yazarları tek çağrıda, gönderinin yazarı ayrı çağrıda okunur.
      expect(users.callsTo('getUsers'), hasLength(2));
    });

    test('akış olayı → state: gönderi değişir; yeni yorum yazarıyla birlikte '
        'gelir (yalnızca eksik yazar okunur)', () async {
      final container = await loaded();
      final edited = kPost.copyWith(text: 'Güncel metin');
      posts.put(edited);
      await pumpEventQueue();
      expect(stateOf(container).post, edited);

      final author = UserModelFixtures.byId('u123');
      users.users[author.uid] = author;
      final fresh = kOtherComment.copyWith(
        id: 'cm_new',
        authorId: author.uid,
        createdAt: kOtherComment.createdAt!.add(const Duration(hours: 1)),
      );
      comments.put(fresh);
      await pumpEventQueue();
      final state = stateOf(container);
      expect(state.comments, [...kPostComments, fresh]);
      expect(state.users[author.uid], author);
      expect(users.callsTo('getUsers').single.args, [
        [author.uid],
      ]);
    });

    test('ViewModel kapanınca iki dinleyici de iptal edilir', () async {
      final container = await loaded();
      expect(posts.activeListeners, 1);
      expect(comments.activeListeners, 1);
      container.dispose();
      await pumpEventQueue();
      expect(posts.activeListeners, 0);
      expect(comments.activeListeners, 0);
    });

    test('anket gönderisi: kullanıcının oyu ve oy sayıları okunur; oy '
        'iyimser işlenir → TST-10', () async {
      final poll = openPollPost();
      final pollProvider = postDetailViewModelProvider(
        clubId: kPostClubId,
        postId: poll.id,
      );
      final container = containerOf(of: pollProvider);
      await pumpEventQueue();
      expect(container.read(pollProvider).post, poll);
      expect(posts.callsTo('myVote'), hasLength(1));
      expect(posts.callsTo('countVotes'), hasLength(1));
      expect(container.read(pollProvider).myOptionId, isNull);

      final option = poll.poll!.options.first.id;
      final outcome = await container
          .read(pollProvider.notifier)
          .votePost(poll.id, option);
      expect(outcome, VoteOutcome.voted);
      expect(container.read(pollProvider).myOptionId, option);
      expect(container.read(pollProvider).pollResults[option], 1);
      expect(feedback.toasts, [ToastId.tst10]);
    });

    test('engellenen yazarın yorumu süzülür; oturumdaki engel kümesi '
        'değişince liste güncellenir', () async {
      final blocked = kOtherComment.authorId;
      final container = await loaded(session: postSession(blocked: {blocked}));
      expect(stateOf(container).comments, kPostComments);
      expect(
        stateOf(container).visibleComments,
        kPostComments.where((comment) => comment.authorId != blocked),
      );
    });
  });

  group('FED-02 · PostDetailViewModel · içerik yok (SYS-04)', () {
    Future<PostDetailState> stateFor(
      void Function() seed, {
      String clubId = kPostClubId,
    }) async {
      seed();
      final target = postDetailViewModelProvider(
        clubId: clubId,
        postId: kPostId,
      );
      final container = containerOf(of: target);
      await pumpEventQueue();
      return container.read(target);
    }

    test('gönderi yok (okuma reddi) → isNotFound', () async {
      final state = await stateFor(() => posts.posts.remove(kPostId));
      expect(state.isNotFound, isTrue);
      expect(state.isFetching || state.isError, isFalse);
      expect(state.post, isNull);
    });

    test('silinmiş gönderi → isNotFound', () async {
      final state = await stateFor(
        () => posts.put(kPost.copyWith(isDeleted: true)),
      );
      expect(state.isNotFound, isTrue);
    });

    test(
      'gizlenmiş gönderi (yazara / yöneticiye dönse de) → isNotFound',
      () async {
        final state = await stateFor(
          () => posts.put(kPost.copyWith(isHidden: true)),
        );
        expect(state.isNotFound, isTrue);
        expect(state.post, isNull);
      },
    );

    test('başka kulübün gönderisi → isNotFound', () async {
      final state = await stateFor(() {}, clubId: 'c02');
      expect(state.isNotFound, isTrue);
    });

    test('dinleme sürerken gönderi gizlenir → isNotFound; yorum akışının '
        'permissionDenied olayı da "içerik yok"tur (W-70)', () async {
      final container = await loaded();
      posts.put(kPost.copyWith(isHidden: true));
      await pumpEventQueue();
      expect(stateOf(container).isNotFound, isTrue);

      posts.put(kPost);
      final other = await loaded();
      expect(stateOf(other).isNotFound, isFalse);
      comments
          .watchCommentsController(kPostId)
          .add(const FirebaseFailure(FirestoreError.permissionDenied));
      await pumpEventQueue();
      expect(stateOf(other).isNotFound, isTrue);
      expect(stateOf(other).isCommentsError, isFalse);
    });
  });

  group('FED-02 · PostDetailViewModel · hata', () {
    test('gönderi okunamadı → isError (+ yorum bloğu hatası); "Yeniden dene" '
        'yeniden dinler', () async {
      final broken = postDetailViewModelProvider(
        clubId: kPostClubId,
        postId: 'a/b',
      );
      final container = containerOf(of: broken);
      await pumpEventQueue();
      var state = container.read(broken);
      expect(state.isError, isTrue);
      expect(state.isCommentsError, isTrue);
      expect(state.isFetching || state.isNotFound, isFalse);

      posts.calls.clear();
      await container.read(broken.notifier).fetch();
      await pumpEventQueue();
      state = container.read(broken);
      expect(posts.callsTo('watchPost'), hasLength(1));
      expect(state.isError, isTrue);
    });

    test('içerik varken gelen geçici hata içeriği silmez', () async {
      final container = await loaded();
      posts
          .watchPostController(kPostId)
          .add(const FirebaseFailure(FirestoreError.unavailable));
      comments
          .watchCommentsController(kPostId)
          .add(const FirebaseFailure(FirestoreError.unavailable));
      await pumpEventQueue();
      final state = stateOf(container);
      expect(state.post, kPost);
      expect(state.comments, kPostComments);
      expect(state.isError || state.isCommentsError, isFalse);
      expect(state.isNotFound, isFalse);
    });
  });

  group('FED-02 · PostDetailViewModel · yorum yaz', () {
    test('metin Limits.commentMax karakterde kesilir; gönder → kırpılmış '
        'metin yazılır, TST-12, alan boşalır, yorum akıştan gelir', () async {
      final container = await loaded();
      final vm = vmOf(container)
        ..setCommentDraft('x' * (Limits.commentMax + 7));
      expect(stateOf(container).commentDraft, hasLength(Limits.commentMax));

      vm.setCommentDraft('  Ben de geliyorum.  ');
      expect(stateOf(container).canSendComment, isTrue);
      expect(await vm.sendComment(), isTrue);
      await pumpEventQueue();

      expect(comments.callsTo('add').single.args, [
        kPostId,
        kPostClubId,
        kPostUid,
        'Ben de geliyorum.',
      ]);
      expect(feedback.toasts, [ToastId.tst12]);
      final state = stateOf(container);
      expect(state.commentDraft, isEmpty);
      expect(state.isSendingComment, isFalse);
      expect(state.comments.last, comments.added.single);
      expect(state.post!.commentCount, kPost.commentCount + 1);
    });

    test('boş metin gönderilmez; art arda iki gönderim tek yazım', () async {
      final container = await loaded();
      final vm = vmOf(container)..setCommentDraft('   ');
      expect(await vm.sendComment(), isFalse);
      expect(comments.callsTo('add'), isEmpty);

      vm.setCommentDraft('Tek yorum');
      final results = await Future.wait([vm.sendComment(), vm.sendComment()]);
      expect(results, [true, false]);
      expect(comments.callsTo('add'), hasLength(1));
    });

    test(
      'danışman → TST-26; çevrimdışı → TST-24; ikisinde de yazılmaz',
      () async {
        final advisor = await loaded(
          session: postSession(role: ClubRole.advisor),
        );
        vmOf(advisor).setCommentDraft('Yorum');
        expect(await vmOf(advisor).sendComment(), isFalse);
        expect(feedback.toasts, [ToastId.tst26]);

        feedback.resetFake();
        final member = await loaded();
        connectivity.isOffline = true;
        vmOf(member).setCommentDraft('Yorum');
        expect(await vmOf(member).sendComment(), isFalse);
        expect(feedback.toasts, [ToastId.tst24]);
        expect(comments.callsTo('add'), isEmpty);
        expect(stateOf(member).commentDraft, 'Yorum');
      },
    );

    test('yazma hatası (yetki yok) → TST-X18; metin alanda kalır', () async {
      final container = await loaded();
      vmOf(container).setCommentDraft('Yorum');
      comments.failNext(FirestoreError.permissionDenied);
      expect(await vmOf(container).sendComment(), isFalse);
      expect(feedback.toasts, [ToastId.tstX18]);
      expect(stateOf(container).commentDraft, 'Yorum');
      expect(stateOf(container).isSendingComment, isFalse);
    });
  });

  group('FED-02 · PostDetailViewModel · yorum kaldır / menü', () {
    test('kendi yorumu: "…" → doğrudan DLG-11 → satır kaybolur, '
        'softDeleteComment, TST-45 ("Yorum"); "Geri al" → restoreComment, '
        'satır geri gelir', () async {
      final container = await loaded();
      final mine = await ownComment(container);
      feedback.dialogResults[DialogId.dlg11] = true;

      final outcome = await vmOf(
        container,
      ).openCommentMenu(mine.id, removedLabel: _commentLabel);
      await pumpEventQueue();
      expect(outcome, CommentMenuOutcome.none);
      expect(feedback.sheets, isEmpty);
      expect(feedback.dialogs, [DialogId.dlg11]);
      expect(comments.callsTo('softDeleteComment').single.args, [
        mine.id,
        kPostId,
        kPostUid,
      ]);
      expect(feedback.toasts, [ToastId.tst45]);
      expect(feedback.toastParams.single.what, _commentLabel);
      expect(
        stateOf(container).visibleComments.map((comment) => comment.id),
        isNot(contains(mine.id)),
      );

      feedback.tapToastAction();
      await pumpEventQueue();
      expect(comments.callsTo('restoreComment').single.args, [
        mine.id,
        kPostId,
      ]);
      expect(
        stateOf(container).visibleComments.map((comment) => comment.id),
        contains(mine.id),
      );
    });

    test(
      'vazgeçilirse yazılmaz; yazma hatasında satır geri gelir + toast',
      () async {
        final container = await loaded();
        final mine = await ownComment(container);

        expect(
          await vmOf(container).removeComment(mine.id, what: _commentLabel),
          isFalse,
        );
        expect(comments.callsTo('softDeleteComment'), isEmpty);

        feedback.dialogResults[DialogId.dlg11] = true;
        comments.failNext(FirestoreError.unavailable);
        expect(
          await vmOf(container).removeComment(mine.id, what: _commentLabel),
          isFalse,
        );
        expect(feedback.toasts, [ToastId.tst24]);
        expect(stateOf(container).removedCommentIds, isEmpty);
        expect(
          stateOf(container).visibleComments.map((comment) => comment.id),
          contains(mine.id),
        );
      },
    );

    test('başkasının yorumu: SHT-27; "Profili gör" view\'a kalır; yönetici '
        '"Yorumu sil" → DLG-11 → kaldırılır', () async {
      final container = await loaded(
        session: postSession(role: ClubRole.board),
      );
      feedback.nextSheetResult = UserMenuAction.viewProfile;
      expect(
        await vmOf(
          container,
        ).openCommentMenu(kOtherComment.id, removedLabel: _commentLabel),
        CommentMenuOutcome.viewProfile,
      );
      expect(feedback.sheets, [SheetId.sht27]);

      feedback
        ..nextSheetResult = UserMenuAction.removeComment
        ..dialogResults[DialogId.dlg11] = true;
      await vmOf(
        container,
      ).openCommentMenu(kOtherComment.id, removedLabel: _commentLabel);
      await pumpEventQueue();
      expect(feedback.dialogs, [DialogId.dlg11]);
      expect(comments.callsTo('softDeleteComment'), hasLength(1));
      expect(
        stateOf(container).visibleComments,
        isNot(contains(kOtherComment)),
      );
    });

    test('SHT-27 "Engelle" → DLG-13 → yazarın yorumu süzülür + TST-09; '
        '"Geri al" → geri gelir', () async {
      final container = await loaded();
      feedback
        ..nextSheetResult = UserMenuAction.block
        ..dialogResults[DialogId.dlg13] = true;
      await vmOf(
        container,
      ).openCommentMenu(kOtherComment.id, removedLabel: _commentLabel);
      expect(feedback.dialogs, [DialogId.dlg13]);
      expect(feedback.toasts, [ToastId.tst09]);
      expect(blocks.callsTo('block'), hasLength(1));
      expect(
        stateOf(container).visibleComments,
        isNot(contains(kOtherComment)),
      );

      feedback.tapToastAction();
      await pumpEventQueue();
      expect(stateOf(container).visibleComments, contains(kOtherComment));
    });

    test('yorum şikayeti: SHT-10 (hedef = yorum) → DLG-12 (yazar adıyla) → '
        '"engelle" → DLG-13', () async {
      final container = await loaded();
      feedback
        ..nextSheetResult = ReportReasonResult(
          target: (
            type: ReportTargetType.comment,
            id: kOtherComment.id,
            clubId: kPostClubId,
          ),
          reason: ReportReason.spam,
        )
        ..dialogResults[DialogId.dlg12] = false
        ..dialogResults[DialogId.dlg13] = true;
      await vmOf(container).reportComment(kOtherComment.id);
      expect(feedback.sheets, [SheetId.sht10]);
      expect(feedback.dialogs, [DialogId.dlg12, DialogId.dlg13]);
      expect(blocks.callsTo('block'), hasLength(1));

      // Sayfa gönderilmeden kapandı: DLG-12 açılmaz.
      feedback.resetFake();
      await vmOf(container).reportComment(kPostComments.first.id);
      expect(feedback.dialogs, isEmpty);
      expect(reports.reports, isEmpty);
    });
  });

  group('FED-02 · PostDetailViewModel · gönderi eylemleri', () {
    test('beğeni iyimserdir; yazma hatasında geri alınır + TST-24', () async {
      final container = await loaded();
      await vmOf(container).togglePostLike(kPostId);
      expect(stateOf(container).post!.likedBy(kPostUid), isTrue);
      expect(stateOf(container).post!.likeCount, kPost.likeCount + 1);

      posts.failNext(FirestoreError.unavailable);
      final pending = vmOf(container).togglePostLike(kPostId);
      expect(stateOf(container).post!.likedBy(kPostUid), isFalse);
      await pending;
      expect(stateOf(container).post!.likedBy(kPostUid), isTrue);
      expect(feedback.toasts, [ToastId.tst24]);
    });

    test('danışman beğenemez → TST-26; kaydı kaldırma → TST-11, "Geri al" '
        'yeniden kaydeder', () async {
      final container = await loaded(
        session: postSession(role: ClubRole.advisor),
      );
      await vmOf(container).togglePostLike(kPostId);
      expect(feedback.toasts, [ToastId.tst26]);
      expect(posts.callsTo('like'), isEmpty);

      await vmOf(container).togglePostSave(kPostId);
      expect(stateOf(container).isSaved, isFalse);
      expect(feedback.toasts, [ToastId.tst26, ToastId.tst11]);
      feedback.tapToastAction();
      await pumpEventQueue();
      expect(stateOf(container).isSaved, isTrue);
    });

    test('SHT-08 "Sil" → DLG-10 → `removed`; bu sırada gelen "gönderi yok" '
        'olayı SYS-04 sayılmaz; "Geri al" gönderiyi geri getirir', () async {
      final container = await loaded(
        session: postSession(role: ClubRole.board),
      );
      feedback
        ..nextSheetResult = PostMenuAction.remove
        ..dialogResults[DialogId.dlg10] = true;
      final outcome = await vmOf(
        container,
      ).openPostMenu(kPostId, removedLabel: _postLabel);
      await pumpEventQueue();
      expect(outcome, PostMenuOutcome.removed);
      expect(feedback.sheets, [SheetId.sht08]);
      expect(feedback.toasts, [ToastId.tst45]);
      expect(stateOf(container).isRemoved, isTrue);
      expect(stateOf(container).isNotFound, isFalse);

      feedback.tapToastAction();
      await pumpEventQueue();
      expect(posts.callsTo('restorePost'), hasLength(1));
      expect(stateOf(container).isRemoved, isFalse);
      expect(stateOf(container).post!.isDeleted, isFalse);
    });
  });
}

// FED-01 · ClubFeedViewModel: ilk okuma (sabit gönderi, yazarlar, roller,
// kayıtlar, anket durumu; hata + yeniden dene), sabit gönderi okunamazsa
// "sabit yok" (W-70 a), sayfalama (20 + imleç), tür süzgeci, engellenenler,
// iyimser beğeni / kaydet + geri alma, anket (oy verildi / süre bitti /
// sonuç), danışman salt okunur (TST-26), kaldır (DLG-10 → TST-45 → Geri al),
// sabitle (TST-53), gönderiyi yeniden okuma — PLAN §12.6.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/clubs/provider/club_detail_view_model.dart';
import 'package:gu_kulupler/features/clubs/provider/club_feed_state.dart';
import 'package:gu_kulupler/features/clubs/provider/club_feed_view_model.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/mixin/post_actions_mixin.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';

import '../../../fakes/fake_club_repository.dart';
import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_membership_repository.dart';
import '../../../fakes/fake_post_repository.dart';
import '../../../fakes/fake_saved_post_repository.dart';
import '../../../fakes/fake_user_repository.dart';
import '../../../fakes/register_fakes.dart';
import '../../../helpers/test_container.dart';
import '../club_feed_test_support.dart';

void main() {
  late FakePostRepository posts;
  late FakeSavedPostRepository saved;
  late FakeClubRepository clubs;
  late FakeUserRepository users;
  late FakeFeedbackService feedback;
  late FakeConnectivityService connectivity;

  final provider = clubFeedViewModelProvider(kFeedClubId);

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    posts = feedPosts();
    saved = feedSaved();
    clubs = GetIt.I<ClubRepository>() as FakeClubRepository;
    users = GetIt.I<UserRepository>() as FakeUserRepository;
    feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
    connectivity = GetIt.I<ConnectivityService>() as FakeConnectivityService;
    seedFeed();
  });

  /// [session] oturumuyla, ViewModel'i dinlenen kapsayıcı; [states] verilirse
  /// her state değişimi sırayla eklenir. İlk okuma **bekletilmez**.
  ProviderContainer containerOf({
    SessionState? session,
    List<ClubFeedState>? states,
  }) {
    final container = createContainer(
      overrides: [
        sessionViewModelProvider.overrideWithBuild(
          (ref, notifier) => session ?? feedSession(),
        ),
      ],
    );
    addTearDown(
      container.listen(provider, (_, next) => states?.add(next)).close,
    );
    return container;
  }

  /// İlk okuması bitmiş kapsayıcı (okuma çağrıları sayılmaz).
  Future<ProviderContainer> loaded({
    SessionState? session,
    List<ClubFeedState>? states,
  }) async {
    final container = containerOf(session: session, states: states);
    await pumpEventQueue();
    states?.clear();
    posts.calls.clear();
    saved.calls.clear();
    users.calls.clear();
    return container;
  }

  ClubFeedViewModel vmOf(ProviderContainer container) =>
      container.read(provider.notifier);

  ClubFeedState stateOf(ProviderContainer container) =>
      container.read(provider);

  List<String> visibleIds(ProviderContainer container) => [
    for (final post in stateOf(container).visible) post.id,
  ];

  group('FED-01 · ClubFeedViewModel · yükleme', () {
    test('ilk kare iskelet; okuma sonrası sabit gönderi üstte, yazarlar '
        'toplu, roller, kayıtlar ve anket durumu', () async {
      final container = containerOf();
      expect(stateOf(container).isFetching, isTrue);
      expect(stateOf(container).visible, isEmpty);

      await pumpEventQueue();
      final state = stateOf(container);
      expect(state.isFetching, isFalse);
      expect(state.isError, isFalse);
      expect(state.club, kMembersClub);
      expect(state.posts, kFeedPosts);
      expect(state.pinned, kPinnedPost);
      expect(visibleIds(container), kFeedOrder);
      expect(state.hasMore, isFalse);
      expect(state.users, kFeedAuthors);
      expect(state.roles, kFeedRoles);
      expect(state.savedPostIds, kFeedSavedIds);
      expect(state.myVotes, isEmpty);
      expect(state.pollResults, {kPollPost.id: kPollResults});
      // Yazar belgeleri tek toplu okumayla; sabit gönderi ilk sayfada olduğu
      // için ayrıca okunmaz.
      expect(users.callsTo('getUsers'), hasLength(1));
      expect(posts.callsTo('getPost'), isEmpty);
      expect(state, loadedFeedState());
    });

    test('akış okunamadı → hata; "Yeniden dene" (fetch) yükler', () async {
      posts.failNext(FirestoreError.unavailable);
      final container = containerOf();
      await pumpEventQueue();
      expect(stateOf(container).isError, isTrue);
      expect(stateOf(container).isFetching, isFalse);
      expect(feedback.toasts, isEmpty);

      final states = <ClubFeedState>[];
      addTearDown(container.listen(provider, (_, s) => states.add(s)).close);
      await vmOf(container).fetch();
      expect(states.first.isFetching, isTrue);
      expect(states.first.isError, isFalse);
      expect(stateOf(container).isError, isFalse);
      expect(visibleIds(container), kFeedOrder);
    });

    test('yenileme okunamazsa içerik kalır (hata görünümü yok)', () async {
      final container = await loaded();
      posts.failNext(FirestoreError.unavailable);
      await vmOf(container).refresh();
      final state = stateOf(container);
      expect(state.isRefreshing, isFalse);
      expect(state.isError, isFalse);
      expect(visibleIds(container), kFeedOrder);
    });

    test('W-70 (a): sabit gönderi okunamıyor (yok / gizlenmiş) → "sabit '
        'yok", hata değil', () async {
      // İşaretçi olmayan bir gönderiyi gösteriyor: okuma `permissionDenied`.
      posts.put(kPinnedPost.copyWith(pinned: false));
      clubs.clubs[kFeedClubId] = kMembersClub.copyWith(pinnedPostId: 'p_yok');
      final container = containerOf();
      await pumpEventQueue();
      expect(stateOf(container).pinned, isNull);
      expect(stateOf(container).isError, isFalse);
      expect(stateOf(container).visible, hasLength(kFeedPosts.length));
      expect(posts.callsTo('getPost').single.args, ['p_yok']);
      container.dispose();

      // Sabit gönderi moderasyonla gizlenmiş: akışta da üstte de yok.
      clubs.clubs[kFeedClubId] = kMembersClub;
      posts.put(kPinnedPost.copyWith(isHidden: true));
      final hidden = containerOf();
      await pumpEventQueue();
      expect(stateOf(hidden).pinned, isNull);
      expect(stateOf(hidden).isError, isFalse);
      expect(visibleIds(hidden), isNot(contains(kPinnedPost.id)));
      expect(stateOf(hidden).visible, hasLength(kFeedPosts.length - 1));
    });

    test('sayfalama: ilk sayfa 20 + sayfa dışındaki sabit gönderi ayrıca '
        'okunur; loadMore kalanları ekler, sabit bir kez çizilir', () async {
      extraFeedPosts(18).forEach(posts.put);
      final container = containerOf();
      await pumpEventQueue();
      var state = stateOf(container);
      expect(state.posts, hasLength(Limits.pageSize));
      expect(state.hasMore, isTrue);
      expect(posts.callsTo('getPost').single.args, [kPinnedPost.id]);
      expect(state.pinned, kPinnedPost);
      expect(state.visible.first.id, kPinnedPost.id);
      expect(state.visible, hasLength(Limits.pageSize + 1));

      final states = <ClubFeedState>[];
      addTearDown(container.listen(provider, (_, s) => states.add(s)).close);
      await vmOf(container).loadMore();
      state = stateOf(container);
      expect(states.first.isLoadingMore, isTrue);
      expect(state.isLoadingMore, isFalse);
      expect(state.hasMore, isFalse);
      expect(state.posts, hasLength(kFeedPosts.length + 18));
      expect(state.visible, hasLength(kFeedPosts.length + 18));
      expect(
        state.visible.where((post) => post.id == kPinnedPost.id),
        hasLength(1),
      );

      // Akış bitti: yeni istek yapılmaz.
      posts.calls.clear();
      await vmOf(container).loadMore();
      expect(posts.callsTo('listFeed'), isEmpty);
    });

    test('sonraki sayfa okunamazsa liste ve imleç kalır', () async {
      extraFeedPosts(18).forEach(posts.put);
      final container = containerOf();
      await pumpEventQueue();
      posts.failNext(FirestoreError.unavailable);
      await vmOf(container).loadMore();
      final state = stateOf(container);
      expect(state.isLoadingMore, isFalse);
      expect(state.isError, isFalse);
      expect(state.hasMore, isTrue);
      expect(state.posts, hasLength(Limits.pageSize));
    });
  });

  group('T-44 · FED-01 · okuma maliyeti (D3-03, D3-08)', () {
    test(
      'kayıt durumları sayfa başına tek savedAmong (gönderi başına isSaved '
      'yok); roller CLB-03 kurulundan — akış listManagers çağırmaz',
      () async {
        final memberships =
            GetIt.I<MembershipRepository>() as FakeMembershipRepository;
        final container = containerOf();
        await pumpEventQueue();

        expect(saved.callsTo('savedAmong'), hasLength(1));
        expect(saved.callsTo('isSaved'), isEmpty);
        expect(stateOf(container).savedPostIds, kFeedSavedIds);
        expect(stateOf(container).roles, kFeedRoles);
        // Tek okuma CLB-03'ündür (kulüp sekmesi); akış yeniden okumaz.
        expect(memberships.callsTo('listManagers'), hasLength(1));
      },
    );

    test('loadMore tek savedAmong çağırır; savedAmong okunamazsa kayıt '
        'durumları önceki değerde kalır', () async {
      extraFeedPosts(18).forEach(posts.put);
      final container = await loaded();
      final before = stateOf(container).savedPostIds;

      saved.failNext(FirestoreError.unavailable);
      await vmOf(container).loadMore();

      expect(saved.callsTo('savedAmong'), hasLength(1));
      expect(saved.callsTo('isSaved'), isEmpty);
      expect(stateOf(container).savedPostIds, before);
      expect(stateOf(container).isError, isFalse);
    });

    test(
      'CLB-03 kurulu değişince (yenileme) yazar rolleri güncellenir',
      () async {
        final memberships =
            GetIt.I<MembershipRepository>() as FakeMembershipRepository;
        final container = await loaded();
        final president = kClubManagers.firstWhere(
          (m) => m.role == ClubRole.president,
        );
        final board = kClubManagers.firstWhere((m) => m.role == ClubRole.board);
        // Kurul üyesi üyeliğe düşürüldü: CLB-03 yenilemesi yeni kurulu okur.
        memberships.put(board.copyWith(role: ClubRole.member));

        await container
            .read(clubDetailViewModelProvider(kFeedClubId).notifier)
            .refresh();
        await pumpEventQueue();

        expect(stateOf(container).roles[president.userId], ClubRole.president);
        expect(stateOf(container).roles.containsKey(board.userId), isFalse);
      },
    );
  });

  group('FED-01 · ClubFeedViewModel · süzgeç ve engel', () {
    test('tür çipi görünen listeyi süzer (istemcide; okuma yok)', () async {
      final container = await loaded();
      final vm = vmOf(container)..setFilter(FeedFilter.announcements);
      expect(visibleIds(container), [kPinnedPost.id]);
      vm.setFilter(FeedFilter.polls);
      expect(visibleIds(container), [kPollPost.id]);
      vm.setFilter(FeedFilter.images);
      expect(visibleIds(container), hasLength(2));
      vm.setFilter(FeedFilter.all);
      expect(visibleIds(container), kFeedOrder);
      expect(posts.calls, isEmpty);
    });

    test('oturumda engellenen yazarın gönderileri akışta yok', () async {
      final blocked = kImagePost.authorId;
      final container = await loaded(session: feedSession(blocked: {blocked}));
      final state = stateOf(container);
      expect(state.posts, kFeedPosts);
      expect(state.visible.any((post) => post.authorId == blocked), isFalse);
      expect(
        state.visible,
        hasLength(kFeedPosts.where((p) => p.authorId != blocked).length),
      );
    });
  });

  group('FED-01 · ClubFeedViewModel · beğeni ve kaydet (iyimser)', () {
    test('beğen: sayaç anında artar ve yazılır', () async {
      final states = <ClubFeedState>[];
      final container = await loaded(states: states);
      final before = kImagePost.likeCount;
      await vmOf(container).togglePostLike(kImagePost.id);
      final post = stateOf(container).postById(kImagePost.id)!;
      expect(
        states.first.postById(kImagePost.id)!.likedBy(kMembersUid),
        isTrue,
      );
      expect(post.likedBy(kMembersUid), isTrue);
      expect(post.likeCount, before + 1);
      expect(posts.posts[kImagePost.id]!.likedBy(kMembersUid), isTrue);
      expect(feedback.toasts, isEmpty);
    });

    test('beğeni yazılamadı → geri alınır + TST-24; sabit gönderide de '
        'kopya tutarlı', () async {
      final states = <ClubFeedState>[];
      final container = await loaded(states: states);
      posts.failNext(FirestoreError.unavailable);
      await vmOf(container).togglePostLike(kPinnedPost.id);
      // Önce iyimser beğeni, sonra geri alma.
      expect(states.first.pinned!.likedBy(kMembersUid), isTrue);
      expect(states.first.pinned!.likeCount, kPinnedPost.likeCount + 1);
      final state = stateOf(container);
      expect(state.pinned, kPinnedPost);
      expect(state.postById(kPinnedPost.id), kPinnedPost);
      expect(state.posts, kFeedPosts);
      expect(feedback.toasts, [ToastId.tst24]);
    });

    test('kaydet → TST-11; "Geri al" kaydı kaldırır', () async {
      final container = await loaded();
      await vmOf(container).togglePostSave(kImagePost.id);
      expect(stateOf(container).savedPostIds, contains(kImagePost.id));
      expect(feedback.toasts, [ToastId.tst11]);
      expect(feedback.toastParams.single.saved, isTrue);
      expect(saved.callsTo('save'), hasLength(1));

      feedback.tapToastAction();
      await pumpEventQueue();
      expect(stateOf(container).savedPostIds, isNot(contains(kImagePost.id)));
      expect(saved.callsTo('softDeleteSaved'), hasLength(1));
    });

    test('kayıt kaldırma yazılamadı → kayıt geri gelir + TST-24', () async {
      final states = <ClubFeedState>[];
      final container = await loaded(states: states);
      saved.failNext(FirestoreError.unavailable);
      await vmOf(container).togglePostSave(kPinnedPost.id);
      expect(states.first.savedPostIds, isNot(contains(kPinnedPost.id)));
      expect(stateOf(container).savedPostIds, kFeedSavedIds);
      expect(feedback.toasts, [ToastId.tst24]);
    });

    test('çevrimdışı: beğeni ve kayıt yazılmaz → TST-24', () async {
      final container = await loaded();
      connectivity.isOffline = true;
      await vmOf(container).togglePostLike(kImagePost.id);
      await vmOf(container).togglePostSave(kImagePost.id);
      expect(stateOf(container), loadedFeedState());
      expect(posts.calls, isEmpty);
      expect(saved.calls, isEmpty);
      expect(feedback.toasts, [ToastId.tst24, ToastId.tst24]);
    });
  });

  group('FED-01 · ClubFeedViewModel · anket', () {
    final optionId = kPollPost.poll!.options.first.id;
    final otherId = kPollPost.poll!.options.last.id;

    test('oy ver → TST-10, seçenek işaretlenir, sonuç bir artar; ikinci oy '
        'yazılmaz (TST-10)', () async {
      final container = await loaded();
      final outcome = await vmOf(container).votePost(kPollPost.id, optionId);
      expect(outcome, VoteOutcome.voted);
      var state = stateOf(container);
      expect(state.myVotes, {kPollPost.id: optionId});
      expect(state.pollResults[kPollPost.id], {
        ...kPollResults,
        optionId: kPollResults[optionId]! + 1,
      });
      expect(feedback.toasts, [ToastId.tst10]);
      expect(posts.votes[kPollPost.id]![kMembersUid], optionId);

      posts.calls.clear();
      final again = await vmOf(container).votePost(kPollPost.id, otherId);
      expect(again, VoteOutcome.alreadyVoted);
      state = stateOf(container);
      expect(state.myVotes, {kPollPost.id: optionId});
      expect(posts.callsTo('vote'), isEmpty);
      expect(feedback.toasts, [ToastId.tst10, ToastId.tst10]);
    });

    test('daha önce verilmiş oy açılışta okunur (sonuçlar görünür)', () async {
      posts.votes[kPollPost.id]![kMembersUid] = otherId;
      final container = await loaded();
      final state = stateOf(container);
      expect(state.myVotes, {kPollPost.id: otherId});
      expect(
        state.pollResults[kPollPost.id]![otherId],
        kPollResults[otherId]! + 1,
      );
    });

    test('süresi dolmuş ankette oy yazılmaz, bildirim yok', () async {
      final container = await loaded();
      feedClock().set(kPollPost.poll!.endsAt);
      final outcome = await vmOf(container).votePost(kPollPost.id, optionId);
      expect(outcome, VoteOutcome.closed);
      expect(stateOf(container).myVotes, isEmpty);
      expect(stateOf(container).pollResults, {kPollPost.id: kPollResults});
      expect(posts.callsTo('vote'), isEmpty);
      expect(feedback.toasts, isEmpty);
    });

    test('oy yazılamadı → işaret ve sayaç geri alınır + TST-24', () async {
      final container = await loaded();
      posts.failNext(FirestoreError.unavailable);
      final outcome = await vmOf(container).votePost(kPollPost.id, optionId);
      expect(outcome, VoteOutcome.failed);
      expect(stateOf(container).myVotes, isEmpty);
      expect(stateOf(container).pollResults, {kPollPost.id: kPollResults});
      expect(feedback.toasts, [ToastId.tst24]);
    });
  });

  group('FED-01 · ClubFeedViewModel · danışman salt okunur', () {
    test('beğeni, oy, sabitleme ve kaldırma → TST-26; hiçbir şey '
        'yazılmaz', () async {
      final container = await loaded(
        session: feedSession(role: ClubRole.advisor),
      );
      final vm = vmOf(container);
      await vm.togglePostLike(kImagePost.id);
      final outcome = await vm.votePost(
        kPollPost.id,
        kPollPost.poll!.options.first.id,
      );
      await vm.togglePostPin(kImagePost.id);
      final removed = await vm.removePost(kImagePost.id, what: 'Gönderi');
      expect(outcome, VoteOutcome.failed);
      expect(removed, isFalse);
      expect(feedback.toasts, List.filled(4, ToastId.tst26));
      expect(feedback.dialogs, isEmpty);
      expect(posts.calls, isEmpty);
      expect(stateOf(container).posts, kFeedPosts);
    });

    test('danışman kaydedebilir (kayıt kişiseldir)', () async {
      final container = await loaded(
        session: feedSession(role: ClubRole.advisor),
      );
      await vmOf(container).togglePostSave(kImagePost.id);
      expect(stateOf(container).savedPostIds, contains(kImagePost.id));
      expect(feedback.toasts, [ToastId.tst11]);
    });
  });

  group('FED-01 · ClubFeedViewModel · yönetim', () {
    final manager = feedSession(role: ClubRole.board);

    test('kaldır: DLG-10 onayı → akıştan çıkar, TST-45; "Geri al" yerine '
        'koyar', () async {
      final container = await loaded(session: manager);
      feedback.nextDialogResult = true;
      final removed = await vmOf(
        container,
      ).removePost(kImagePost.id, what: 'Gönderi');
      expect(removed, isTrue);
      expect(feedback.dialogs, [DialogId.dlg10]);
      expect(visibleIds(container), isNot(contains(kImagePost.id)));
      expect(posts.posts[kImagePost.id]!.isDeleted, isTrue);
      expect(feedback.toasts, [ToastId.tst45]);
      expect(feedback.toastParams.single.what, 'Gönderi');

      feedback.tapToastAction();
      await pumpEventQueue();
      expect(visibleIds(container), kFeedOrder);
      expect(posts.posts[kImagePost.id]!.isDeleted, isFalse);
    });

    test('kaldırma yazılamadı → gönderi yerine döner + TST-24; '
        'vazgeçilirse hiçbir şey olmaz', () async {
      final container = await loaded(session: manager);
      feedback.nextDialogResult = false;
      expect(
        await vmOf(container).removePost(kImagePost.id, what: 'Gönderi'),
        isFalse,
      );
      expect(posts.calls, isEmpty);

      feedback.nextDialogResult = true;
      posts.failNext(FirestoreError.unavailable);
      expect(
        await vmOf(container).removePost(kPinnedPost.id, what: 'Gönderi'),
        isFalse,
      );
      expect(visibleIds(container), kFeedOrder);
      expect(stateOf(container).pinned, kPinnedPost);
      expect(feedback.toasts, [ToastId.tst24]);
    });

    test('sabitle: yeni gönderi en üste çıkar, önceki sabit sırasına döner '
        '→ TST-53; kaldırınca "sabit yok"', () async {
      final container = await loaded(session: manager);
      await vmOf(container).togglePostPin(kImagePost.id);
      var state = stateOf(container);
      expect(state.pinned!.id, kImagePost.id);
      expect(state.visible.first.id, kImagePost.id);
      expect(state.postById(kPinnedPost.id)!.pinned, isFalse);
      expect(state.visible, hasLength(kFeedPosts.length));
      expect(posts.pinnedByClub[kFeedClubId], kImagePost.id);
      expect(feedback.toasts, [ToastId.tst53]);
      expect(feedback.toastParams.single.pinned, isTrue);

      await vmOf(container).togglePostPin(kImagePost.id);
      state = stateOf(container);
      expect(state.pinned, isNull);
      expect(
        visibleIds(container),
        [for (final post in kFeedPosts) post.id],
      );
      expect(feedback.toastParams.last.pinned, isFalse);
    });
  });

  group('FED-01 · ClubFeedViewModel · reloadPost', () {
    test(
      'yorum sayacı ve kayıt güncellenir; gönderi yoksa akıştan çıkar',
      () async {
        final container = await loaded();
        posts.put(
          kImagePost.copyWith(commentCount: kImagePost.commentCount + 2),
        );
        await saved.save(
          userId: kMembersUid,
          postId: kImagePost.id,
          clubId: kFeedClubId,
        );
        await vmOf(container).reloadPost(kImagePost.id);
        var state = stateOf(container);
        expect(
          state.postById(kImagePost.id)!.commentCount,
          kImagePost.commentCount + 2,
        );
        expect(state.savedPostIds, contains(kImagePost.id));

        posts.put(kImagePost.copyWith(isDeleted: true));
        await vmOf(container).reloadPost(kImagePost.id);
        state = stateOf(container);
        expect(state.postById(kImagePost.id), isNull);
        expect(state.isError, isFalse);

        // Ağ hatasında kopya olduğu gibi kalır.
        posts.failNext(FirestoreError.unavailable);
        await vmOf(container).reloadPost(kPollPost.id);
        expect(stateOf(container).postById(kPollPost.id), kPollPost);
      },
    );
  });
}

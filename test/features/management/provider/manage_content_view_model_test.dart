// MGT-08 · ManageContentViewModel: yükleme (`listForManagement`, gizliler
// dahil, 20 + imleç), sekmeler ve arama (istemcide), sabitleme tek gönderi
// (yeni sabit eskisini kaldırır; hata → geri alınır), sil (DLG-10 → TST-45
// "Geri al"), düzenle yalnızca yazara, danışman TST-26 — PLAN §12.6,
// roadmap T-36 "sabitleme tek gönderi".
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/management/provider/manage_content_view_model.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/post_menu.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/mixin/post_actions_mixin.dart';

import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_post_repository.dart';
import '../../../fakes/register_fakes.dart';
import '../../../fixtures/post_model_fixtures.dart';
import '../../../helpers/test_container.dart';
import '../manage_test_support.dart';

void main() {
  late FakePostRepository posts;
  late FakeFeedbackService feedback;

  final provider = manageContentViewModelProvider(kManageClubId);

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    posts = GetIt.I<PostRepository>() as FakePostRepository;
    feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
    seedManage();
  });

  Future<ProviderContainer> loaded({SessionState? session}) async {
    final container = createContainer(
      overrides: [
        sessionViewModelProvider.overrideWithBuild(
          (ref, notifier) => session ?? manageSession(),
        ),
      ],
    );
    addTearDown(container.listen(provider, (_, _) {}).close);
    await pumpEventQueue();
    return container;
  }

  ManageContentViewModel vm(ProviderContainer c) => c.read(provider.notifier);

  List<String> visibleIds(ProviderContainer c) => [
    for (final post in c.read(provider).visible) post.id,
  ];

  List<String> pinnedIds(ProviderContainer c) => [
    for (final post in c.read(provider).items)
      if (post.pinned) post.id,
  ];

  Future<PostMenuOutcome> run(
    ProviderContainer c,
    PostMenuAction action,
    String postId,
  ) => vm(c).runMenu(action, postId, removedLabel: 'Gönderi');

  group('MGT-08 · yükleme, sekmeler ve arama', () {
    test('ilk sayfa listForManagement (20); sekmeler istemcide, en yeni '
        'üstte', () async {
      final c = await loaded();
      final state = c.read(provider);
      expect(state.isFetching, isFalse);
      expect(state.club, kManageClub);
      final call = posts.callsTo('listForManagement').single;
      expect(call.args[0], kManageClubId);
      expect((call.args[1]! as PageRequest).limit, Limits.pageSize);
      expect(visibleIds(c), ['p11', 'p12', 'p10', 'p13']);
      vm(c).setTab(PostType.announcement);
      expect(visibleIds(c), ['p08']);
      vm(c).setTab(PostType.poll);
      expect(visibleIds(c), ['p09']);
    });

    test('gizlenmiş gönderi yönetimde listelenir', () async {
      posts.put(PostModelFixtures.byId('p10').copyWith(isHidden: true));
      final c = await loaded();
      expect(visibleIds(c), contains('p10'));
      expect(c.read(provider).postById('p10')!.isHidden, isTrue);
    });

    test('arama başlık / metinde Türkçe küçük harfle süzer', () async {
      final c = await loaded();
      vm(c).setQuery('  DAĞCILIK ');
      expect(visibleIds(c), ['p11']);
      vm(c).setQuery('bakım günü');
      expect(visibleIds(c), ['p12']);
      vm(c).setQuery('yok-böyle-bir-şey');
      expect(visibleIds(c), isEmpty);
    });

    test('sayfalama: 20 + imleç; loadMore sonraki sayfayı ekler', () async {
      final base = PostModelFixtures.byId('p13');
      for (var i = 0; i < 20; i++) {
        posts.put(
          base.copyWith(
            id: 'old$i',
            createdAt: base.createdAt!.subtract(Duration(days: i + 1)),
          ),
        );
      }
      final c = await loaded();
      expect(c.read(provider).items, hasLength(20));
      expect(c.read(provider).wantsMore, isTrue);
      await vm(c).loadMore();
      final state = c.read(provider);
      expect(state.items, hasLength(26));
      expect(state.hasMore, isFalse);
      expect(posts.callsTo('listForManagement'), hasLength(2));
    });

    test('okunamadı → hata; "Yeniden dene" okur', () async {
      posts.failNext(FirestoreError.unavailable);
      final c = await loaded();
      expect(c.read(provider).isError, isTrue);
      await vm(c).fetch();
      expect(c.read(provider).isError, isFalse);
      expect(visibleIds(c), hasLength(4));
    });
  });

  group('MGT-08 · sabitleme tek gönderi (TST-53)', () {
    test('yeni sabitleme eskisini kaldırır: listede tek sabit', () async {
      final c = await loaded();
      expect(pinnedIds(c), ['p08']);
      await run(c, PostMenuAction.pin, 'p10');
      expect(pinnedIds(c), ['p10']);
      expect(posts.pinnedByClub[kManageClubId], 'p10');
      expect(posts.posts['p08']!.pinned, isFalse);
      expect(feedback.toasts, [ToastId.tst53]);
      await run(c, PostMenuAction.unpin, 'p10');
      expect(pinnedIds(c), isEmpty);
      expect(posts.pinnedByClub[kManageClubId], isNull);
    });

    test('yazılamadı → iki gönderi de eski hâline döner + TST-X18', () async {
      final c = await loaded();
      posts.failNext(FirestoreError.permissionDenied);
      await run(c, PostMenuAction.pin, 'p10');
      expect(pinnedIds(c), ['p08']);
      expect(feedback.toasts, [ToastId.tstX18]);
    });
  });

  group('MGT-08 · sil ve düzenle', () {
    test('sil: DLG-10 → satır düşer + TST-45; "Geri al" geri yükler', () async {
      final c = await loaded();
      feedback.nextDialogResult = true;
      final outcome = await run(c, PostMenuAction.remove, 'p12');
      expect(outcome, PostMenuOutcome.removed);
      expect(feedback.dialogs, [DialogId.dlg10]);
      expect(visibleIds(c), ['p11', 'p10', 'p13']);
      expect(posts.posts['p12']!.isDeleted, isTrue);
      expect(feedback.toasts, [ToastId.tst45]);
      feedback.tapToastAction();
      await pumpEventQueue();
      expect(visibleIds(c), ['p11', 'p12', 'p10', 'p13']);
      expect(posts.posts['p12']!.isDeleted, isFalse);
    });

    test('sil: vazgeçildi → yazım yok', () async {
      final c = await loaded();
      await run(c, PostMenuAction.remove, 'p12');
      expect(posts.callsTo('softDeletePost'), isEmpty);
      expect(visibleIds(c), hasLength(4));
    });

    test('düzenle yalnızca yazara: başkasının gönderisi → none', () async {
      posts.put(
        PostModelFixtures.byId(
          'p13',
        ).copyWith(id: 'mine', authorId: kManageUid),
      );
      final c = await loaded();
      expect(await run(c, PostMenuAction.edit, 'p10'), PostMenuOutcome.none);
      expect(await run(c, PostMenuAction.edit, 'mine'), PostMenuOutcome.edit);
    });
  });

  group('MGT-08 · danışman (Q-09)', () {
    test('salt okunur: sabitle / sil / FAB → TST-26, yazım yok', () async {
      final c = await loaded(session: manageSession(role: ClubRole.advisor));
      expect(c.read(provider).isReadOnly, isTrue);
      await run(c, PostMenuAction.pin, 'p10');
      await run(c, PostMenuAction.remove, 'p10');
      expect(vm(c).ensureWritable(), isFalse);
      expect(posts.callsTo('pin'), isEmpty);
      expect(posts.callsTo('softDeletePost'), isEmpty);
      expect(feedback.toasts, [ToastId.tst26, ToastId.tst26, ToastId.tst26]);
    });
  });
}

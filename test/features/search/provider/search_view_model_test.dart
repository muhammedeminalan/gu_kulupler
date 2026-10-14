// CLB-02 · SearchViewModel: ilk durum ve havuz okuma (askıdaki kulüp yok,
// önerilen kulüpler, yönetici önizlemeleri, hata + yeniden dene), sorgu
// (250 ms bekleme, Türkçe harf, kategori adı, boşaltma), sekme, son aramalar
// (yaz / kaldır / temizle TST-06 + geri al), katılım (TST-X1, başvuru gereği,
// bekleme, anında katılım TST-34, çevrimdışı TST-24, yetki TST-X18, art arda
// tetikleme) — PLAN §12.6.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/search/provider/search_scope.dart';
import 'package:gu_kulupler/features/search/provider/search_state.dart';
import 'package:gu_kulupler/features/search/provider/search_view_model.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/mixin/club_join_mixin.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';

import '../../../fakes/fake_app_preferences_store.dart';
import '../../../fakes/fake_club_repository.dart';
import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_event_repository.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_membership_repository.dart';
import '../../../fakes/fake_session_states.dart';
import '../../../fakes/register_fakes.dart';
import '../../../fixtures/membership_model_fixtures.dart';
import '../../../helpers/test_container.dart';
import '../search_test_support.dart';

/// TST-X4 tarih biçimleyicisinin test karşılığı.
String _formatDate(DateTime instant) => 'D:${instant.toIso8601String()}';

void main() {
  late FakeClubRepository clubs;
  late FakeMembershipRepository memberships;
  late FakeFeedbackService feedback;
  late FakeConnectivityService connectivity;
  late FakeAppPreferencesStore store;

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    clubs = GetIt.I<ClubRepository>() as FakeClubRepository;
    memberships = GetIt.I<MembershipRepository>() as FakeMembershipRepository;
    feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
    connectivity = GetIt.I<ConnectivityService>() as FakeConnectivityService;
    store = GetIt.I<AppPreferencesStore>() as FakeAppPreferencesStore;
    seedSearch();
  });

  /// Günlük satırlarını toplar (konsola düşmez); test sonunda özgün
  /// `debugPrint` geri kurulur.
  List<String> captureLogs() {
    final logs = <String>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
    addTearDown(() => debugPrint = original);
    return logs;
  }

  final provider = searchViewModelProvider(SearchScope.clubs);

  /// [session] oturumuyla, ViewModel'i dinlenen kapsayıcı. İlk okuma
  /// **bekletilmez**.
  ProviderContainer containerOf({
    SessionState? session,
    SearchScope scope = SearchScope.clubs,
  }) {
    final container = createContainer(
      overrides: [
        sessionViewModelProvider.overrideWithBuild(
          (ref, notifier) => session ?? kVisitorSession,
        ),
      ],
    );
    addTearDown(
      container.listen(searchViewModelProvider(scope), (_, _) {}).close,
    );
    return container;
  }

  /// Havuzu okunmuş kapsayıcı.
  Future<ProviderContainer> loaded({SessionState? session}) async {
    final container = containerOf(session: session);
    await pumpEventQueue();
    clubs.calls.clear();
    memberships.calls.clear();
    return container;
  }

  /// `testWidgets` içinde havuzu okunmuş kapsayıcı (sahte zamanda
  /// `pumpEventQueue` ilerlemez; mikro görevleri `tester.pump` boşaltır).
  Future<ProviderContainer> loadedIn(WidgetTester tester) async {
    final container = containerOf();
    await tester.pump();
    return container;
  }

  SearchViewModel vmOf(ProviderContainer container) =>
      container.read(provider.notifier);

  SearchState stateOf(ProviderContainer container) => container.read(provider);

  group('CLB-02 · SearchViewModel · ilk durum ve havuz', () {
    test('ilk durum: rotanın sekmesi, cihazdaki son aramalar, popüler '
        'aramalar, isFetching', () {
      store.values[AppPreferenceKeys.recentSearches] = kRecent;
      final container = containerOf(scope: SearchScope.events);
      final state = container.read(searchViewModelProvider(SearchScope.events));
      expect(state.scope, SearchScope.events);
      expect(state.recent, kRecent);
      expect(state.popular, StaticTables.popularSearches);
      expect(state.isFetching, isTrue);
      expect(state.clubPool, isEmpty);
    });

    test('havuz: askıdaki kulüp yok, nameLower sırası; önerilenler üye '
        'olunmayan ilk üç kulüp, ilgi alanı kategorisi önde; yönetici '
        'önizlemeleri okunur', () async {
      final manager = MembershipModelFixtures.byId('c09_u_p_c09');
      memberships.put(manager);
      // Tiyatro Kulübü üyesi; ilgi alanı yok.
      final session = FakeSessionStates.withMembership(
        kTheatre.id,
      ).copyWith(user: kUser.copyWith(interests: const []));
      final container = containerOf(session: session);
      await pumpEventQueue();

      final state = stateOf(container);
      expect(state.isFetching, isFalse);
      expect(state.isError, isFalse);
      expect(state.clubPool, kPool);
      // Tiyatro (üye) önerilmez; kalanlar havuz sırasıyla.
      expect(state.suggested, [kPhoto, kChess, kSoftware]);
      expect(state.managerPreviews[kChess.id], [manager]);
      expect(state.managerPreviews[kPhoto.id], isEmpty);
      expect(memberships.callsTo('listManagers'), hasLength(3));
    });

    test(
      'ilgi alanının kategorisindeki kulüp öne gelir; en çok üç öneri',
      () async {
        // i01 → k01: Yazılım ve Yapay Zekâ Topluluğu.
        final container = containerOf(
          session: kVisitorSession.copyWith(
            user: kUser.copyWith(interests: const ['i01']),
          ),
        );
        await pumpEventQueue();
        expect(stateOf(container).suggested, [kSoftware, kPhoto, kChess]);
        expect(
          stateOf(container).suggested,
          hasLength(SearchViewModel.suggestedMax),
        );
      },
    );

    test('havuz okunamazsa isError; loadPools yeniden okur', () async {
      final logs = captureLogs();
      clubs.failNext(FirestoreError.unavailable);
      final container = containerOf();
      await pumpEventQueue();
      expect(stateOf(container).isError, isTrue);
      expect(stateOf(container).isFetching, isFalse);
      expect(stateOf(container).clubPool, isEmpty);
      expect(logs.join('\n'), contains('Arama havuzu okunamadı'));

      final retry = vmOf(container).loadPools();
      expect(stateOf(container).isFetching, isTrue);
      expect(stateOf(container).isError, isFalse);
      await retry;
      expect(stateOf(container).isError, isFalse);
      expect(stateOf(container).clubPool, kPool);
    });
  });

  group('CLB-02 · SearchViewModel · etkinlik havuzu (W-19)', () {
    late FakeEventRepository events;

    setUp(() {
      events = GetIt.I<EventRepository>() as FakeEventRepository;
      seedSearchEvents();
    });

    test('ziyaretçi: herkese açık yaklaşanlar; askıdaki / havuz dışı kulüp ve '
        'geçmiş etkinlik yok; en yakın üstte', () async {
      final container = containerOf();
      await pumpEventQueue();
      expect(stateOf(container).eventPool, [kChessCup, kPhotoWalk]);
      expect(
        events.callsTo('listPublicUpcoming').single.args,
        [kDefaultFakeNowUtc],
      );
      expect(events.callsTo('listMembersUpcoming'), isEmpty);
    });

    test('üye: üye olunan kulübün üyelere özel yaklaşanları kulüp başına tek '
        'sorguyla eklenir', () async {
      final container = containerOf(session: kSoftwareMemberSession);
      await pumpEventQueue();
      expect(stateOf(container).eventPool, [
        kChessCup,
        kPhotoWalk,
        kHackathonPrep,
      ]);
      expect(events.membersUpcomingQueries, [kSoftware.id]);
    });

    test('etkinlik okuması düşerse kulüp araması sürer; havuz boş, günlüğe '
        'düşer', () async {
      final logs = captureLogs();
      events.failNext(FirestoreError.unavailable);
      final container = containerOf();
      await pumpEventQueue();
      expect(stateOf(container).isError, isFalse);
      expect(stateOf(container).clubPool, kPool);
      expect(stateOf(container).eventPool, isEmpty);
      expect(logs.join('\n'), contains('Arama etkinlik havuzu okunamadı'));
    });

    testWidgets('eşleşme: başlık, açıklama ve kayıtlı mekân adı (view verir)', (
      tester,
    ) async {
      final container = await loadedIn(tester);
      final vm = vmOf(container)..setQuery('SATRANÇ');
      await tester.pump(Limits.searchDebounce);
      expect(stateOf(container).eventResults, [kChessCup]);

      vm
        ..setPlaceLabels({kPhotoWalk.placeId!: 'Zigana Geçidi Başlangıcı'})
        ..setQuery('zİgana geçİdİ');
      await tester.pump(Limits.searchDebounce);
      expect(stateOf(container).eventResults, [kPhotoWalk]);
    });
  });

  group('CLB-02 · SearchViewModel · sorgu', () {
    testWidgets('sonuçlar Limits.searchDebounce sonra gelir; yazmaya devam '
        'edilirse bekleme yeniden başlar', (tester) async {
      final container = await loadedIn(tester);
      final vm = vmOf(container)..setQuery('sat');
      expect(stateOf(container).query, 'sat');
      expect(stateOf(container).isSearching, isTrue);
      expect(stateOf(container).clubResults, isEmpty);

      await tester.pump(
        Limits.searchDebounce - const Duration(milliseconds: 1),
      );
      expect(stateOf(container).isSearching, isTrue);
      vm.setQuery('satr');
      await tester.pump(
        Limits.searchDebounce - const Duration(milliseconds: 1),
      );
      expect(stateOf(container).isSearching, isTrue);
      await tester.pump(const Duration(milliseconds: 1));
      expect(stateOf(container).isSearching, isFalse);
      expect(stateOf(container).clubResults, [kChess]);
    });

    testWidgets('eşleşme Türkçe harf duyarsız; ad, özet / tanıtım ve '
        'kategori adında aranır; baştaki / sondaki boşluk sayılmaz', (
      tester,
    ) async {
      final container = await loadedIn(tester);
      final vm = vmOf(container)
        ..setCategoryLabels({kTheatre.categoryId: 'Kültür ve Sanat'})
        ..setQuery('  TİYATRO ');
      await tester.pump(Limits.searchDebounce);
      expect(stateOf(container).searchTerm, 'TİYATRO');
      expect(stateOf(container).clubResults, [kTheatre]);

      // Kategori adı (ARB'den view verir): büyük I → ı.
      vm.setQuery('KÜLTÜR');
      await tester.pump(Limits.searchDebounce);
      expect(stateOf(container).clubResults, [kTheatre]);

      // Yalnızca boşluk değişti: yeniden aranmaz.
      vm.setQuery('KÜLTÜR ');
      expect(stateOf(container).isSearching, isFalse);
      expect(stateOf(container).clubResults, [kTheatre]);

      vm.setQuery('bulunmayan terim');
      await tester.pump(Limits.searchDebounce);
      expect(stateOf(container).clubResults, isEmpty);
      expect(stateOf(container).eventResults, isEmpty);
    });

    testWidgets('alan boşalınca varsayılan görünüme hemen dönülür; bekleyen '
        'arama iptal olur', (tester) async {
      final container = await loadedIn(tester);
      final vm = vmOf(container)..setQuery('satranç');
      await tester.pump(Limits.searchDebounce);
      expect(stateOf(container).clubResults, [kChess]);

      vm
        ..setQuery('foto')
        ..setQuery('');
      expect(stateOf(container).hasTerm, isFalse);
      expect(stateOf(container).isSearching, isFalse);
      expect(stateOf(container).clubResults, isEmpty);
      await tester.pump(Limits.searchDebounce);
      expect(stateOf(container).clubResults, isEmpty);
    });

    testWidgets('havuz okunurken yazılan sorgu havuz gelince aranır', (
      tester,
    ) async {
      final container = containerOf();
      vmOf(container).setQuery('satranç');
      expect(stateOf(container).isFetching, isTrue);
      await tester.pump(Limits.searchDebounce);
      expect(stateOf(container).isFetching, isFalse);
      expect(stateOf(container).clubResults, [kChess]);
    });

    testWidgets('kapanan ViewModel bekleyen aramayı iptal eder', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          sessionViewModelProvider.overrideWithBuild(
            (ref, notifier) => kVisitorSession,
          ),
        ],
      );
      final subscription = container.listen(provider, (_, _) {});
      await tester.pump();
      container.read(provider.notifier).setQuery('foto');
      subscription.close();
      container.dispose();
      // Bekleyen zamanlayıcı kalsaydı test "Timer is still pending" ile
      // düşerdi.
      await tester.pump(Limits.searchDebounce);
    });

    test('setScope sekmeyi değiştirir', () async {
      final container = await loaded();
      vmOf(container).setScope(SearchScope.events);
      expect(stateOf(container).scope, SearchScope.events);
    });
  });

  group('CLB-02 · SearchViewModel · son aramalar', () {
    test('commitRecent: başa yazar, aynı terimi (Türkçe harf duyarsız) öne '
        'taşır, Limits.recentSearchesMax ile keser, cihaza yazar', () async {
      store.values[AppPreferenceKeys.recentSearches] = kRecent;
      final container = await loaded();
      final vm = vmOf(container);

      await vm.commitRecent('  SATRANÇ ');
      expect(stateOf(container).recent, [
        'SATRANÇ',
        'hackathon',
        'doğa yürüyüşü',
      ]);
      expect(store.recentSearches, stateOf(container).recent);

      await vm.commitRecent('   ');
      expect(stateOf(container).recent, hasLength(3));

      for (final term in ['a', 'b', 'c', 'd']) {
        await vm.commitRecent(term);
      }
      expect(stateOf(container).recent, [
        'd',
        'c',
        'b',
        'a',
        'SATRANÇ',
        'hackathon',
      ]);
      expect(stateOf(container).recent, hasLength(Limits.recentSearchesMax));
    });

    test('removeRecent terimi çıkarır ve cihaza yazar; yazım hatası '
        'kullanıcıya gösterilmez', () async {
      store.values[AppPreferenceKeys.recentSearches] = kRecent;
      final logs = captureLogs();
      final container = await loaded();
      store.failNext();
      await vmOf(container).removeRecent('doğa yürüyüşü');
      expect(logs.join('\n'), contains('Son aramalar yazılamadı'));
      expect(stateOf(container).recent, ['hackathon', 'satranç']);
      expect(store.recentSearches, ['hackathon', 'satranç']);
      expect(feedback.toasts, isEmpty);
    });

    test(
      'clearRecent → TST-06 (Geri al); geri al listeyi geri yazar',
      () async {
        store.values[AppPreferenceKeys.recentSearches] = kRecent;
        final container = await loaded();
        final vm = vmOf(container);

        await vm.clearRecent();
        expect(stateOf(container).recent, isEmpty);
        expect(stateOf(container).recentBackup, kRecent);
        expect(store.recentSearches, isEmpty);
        expect(feedback.toasts, [ToastId.tst06]);
        expect(feedback.hasToastAction, isTrue);

        feedback.tapToastAction();
        await pumpEventQueue();
        expect(stateOf(container).recent, kRecent);
        expect(stateOf(container).recentBackup, isEmpty);
        expect(store.recentSearches, kRecent);

        // Boş listede "Temizle" bir şey yapmaz.
        await vm.clearRecent();
        await vm.clearRecent();
        expect(feedback.toasts, [ToastId.tst06, ToastId.tst06]);
      },
    );
  });

  group('CLB-02 · SearchViewModel · katıl', () {
    test('başvurular kapalı → TST-X1, closed; yazım yok', () async {
      final container = await loaded();
      final outcome = await vmOf(
        container,
      ).join(kTheatre.id, formatDate: _formatDate);
      expect(outcome, JoinOutcome.closed);
      expect(feedback.toasts, [ToastId.tstX1]);
      expect(memberships.callsTo('joinInstant'), isEmpty);
    });

    test('onay gerekli → needsApplication; bekleme sürüyor → waiting; '
        'havuzda olmayan kulüp → failed', () async {
      final waiting = FakeSessionStates.withMembership(
        kPhoto.id,
        status: MembershipStatus.rejected,
      );
      final container = await loaded(
        session: waiting.copyWith(
          user: kUser,
          memberships: {
            kPhoto.id: waiting.memberships[kPhoto.id]!.copyWith(
              retryAfter: kDefaultFakeNowUtc.add(const Duration(days: 3)),
            ),
          },
        ),
      );
      final vm = vmOf(container);
      expect(
        await vm.join(kSoftware.id, formatDate: _formatDate),
        JoinOutcome.needsApplication,
      );
      expect(
        await vm.join(kPhoto.id, formatDate: _formatDate),
        JoinOutcome.waiting,
      );
      expect(
        await vm.join(kSuspended.id, formatDate: _formatDate),
        JoinOutcome.failed,
      );
      expect(feedback.toasts, isEmpty);
      expect(memberships.callsTo('joinInstant'), isEmpty);
    });

    test('onaysız kulüp → joinInstant, TST-34 ("Kulübe git"), üye sayısı '
        '+1; art arda dokunuş tek yazım', () async {
      final container = await loaded();
      final vm = vmOf(container);
      var opened = 0;

      final first = vm.join(
        kPhoto.id,
        formatDate: _formatDate,
        onOpenClub: () => opened++,
      );
      expect(stateOf(container).pendingJoinIds, {kPhoto.id});
      expect(
        await vm.join(kPhoto.id, formatDate: _formatDate),
        JoinOutcome.failed,
      );
      expect(await first, JoinOutcome.joined);

      expect(memberships.callsTo('joinInstant'), hasLength(1));
      expect(memberships.applied.single.clubId, kPhoto.id);
      expect(memberships.applied.single.email, kEmail);
      expect(stateOf(container).pendingJoinIds, isEmpty);
      expect(feedback.toasts, [ToastId.tst34]);
      feedback.tapToastAction();
      expect(opened, 1);
      for (final list in [
        stateOf(container).clubPool,
        stateOf(container).suggested,
      ]) {
        expect(
          list.firstWhere((c) => c.id == kPhoto.id).memberCount,
          kPhoto.memberCount + 1,
        );
      }
    });

    test('`showJoined` (SHT-05 katılımla kapandı): TST-34 ("Kulübe git") + '
        'üye sayısı +1; bilinmeyen kulüpte yalnızca toast', () async {
      final container = await loaded();
      final vm = vmOf(container);
      var opened = 0;

      vm.showJoined(kPhoto.id, onOpenClub: () => opened++);
      expect(feedback.toasts, [ToastId.tst34]);
      feedback.tapToastAction();
      expect(opened, 1);
      expect(
        stateOf(
          container,
        ).clubPool.firstWhere((c) => c.id == kPhoto.id).memberCount,
        kPhoto.memberCount + 1,
      );

      final before = stateOf(container);
      vm.showJoined('yok');
      expect(stateOf(container), before);
      expect(feedback.toasts, [ToastId.tst34, ToastId.tst34]);
    });

    test(
      'çevrimdışı → TST-24, yazım yok; sunucu yetki reddi → TST-X18',
      () async {
        final container = await loaded();
        final vm = vmOf(container);

        connectivity.isOffline = true;
        expect(
          await vm.join(kPhoto.id, formatDate: _formatDate),
          JoinOutcome.failed,
        );
        expect(feedback.toasts, [ToastId.tst24]);
        expect(memberships.callsTo('joinInstant'), isEmpty);

        connectivity.isOffline = false;
        memberships.failNext(FirestoreError.permissionDenied);
        expect(
          await vm.join(kPhoto.id, formatDate: _formatDate),
          JoinOutcome.failed,
        );
        expect(feedback.toasts, [ToastId.tst24, ToastId.tstX18]);
        expect(stateOf(container).pendingJoinIds, isEmpty);
      },
    );

    test('showApplicationsClosed → TST-X1', () async {
      final container = await loaded();
      vmOf(container).showApplicationsClosed();
      expect(feedback.toasts, [ToastId.tstX1]);
    });
  });
}

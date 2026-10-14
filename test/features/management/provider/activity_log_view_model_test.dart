// MGT-10 · ActivityLogViewModel: ilk okuma (kulüp + ilk sayfa + adlar), gün
// grupları (İstanbul günü), tanınmayan türün süzülmesi, ad çözümü (silinmiş
// kullanıcı / kaldırılmış etkinlik), tür grubu süzgeci (sorguda), sayfalama
// (20 + imleç), hata dalları (ilk okuma, yeniden dene, sonraki sayfa,
// çek-yenile), satır hedefleri — PLAN §12.6.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/management/provider/activity_log_state.dart';
import 'package:gu_kulupler/features/management/provider/activity_log_view_model.dart';
import 'package:gu_kulupler/l10n/app_localizations_tr.dart';
import 'package:gu_kulupler/product/widget/manage/activity_texts.dart';

import '../../../fakes/fake_event_repository.dart';
import '../../../fakes/register_fakes.dart';
import '../../../fixtures/club_model_fixtures.dart';
import '../../../helpers/test_container.dart';
import '../activity_log_test_support.dart';

final ActivityLogViewModelProvider _provider = activityLogViewModelProvider(
  kActClubId,
);

/// [count] sentetik gönderi kaydı (saatte bir, en yeni üstte).
List<ActivityModel> _posts(int count) => [
  for (var i = 0; i < count; i++)
    ActivityModel(
      id: 'x${i.toString().padLeft(2, '0')}',
      clubId: kActClubId,
      actorId: 'u151',
      kind: ActivityKind.postCreated,
      refs: ActivityRefsModel(postId: 'p$i'),
      createdAt: kActNowUtc.subtract(Duration(hours: i)),
    ),
];

void main() {
  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
  });

  ProviderContainer containerOf() {
    final container = createContainer(
      overrides: [
        sessionViewModelProvider.overrideWithBuild(
          (ref, notifier) => kActSession,
        ),
      ],
    );
    addTearDown(container.listen(_provider, (_, _) {}).close);
    return container;
  }

  Future<ProviderContainer> loaded() async {
    final container = containerOf();
    await settleActivity();
    return container;
  }

  group('ilk okuma', () {
    test('iskelet → kulüp, 16 kayıt, gün grupları, adlar', () async {
      seedActivity();
      final container = containerOf();
      expect(container.read(_provider).isFetching, isTrue);
      await settleActivity();
      final state = container.read(_provider);
      expect(state.isFetching, isFalse);
      expect(state.isError, isFalse);
      expect(state.club?.id, kActClubId);
      expect([for (final e in state.entries) e.id], kActIds);
      expect(state.hasMore, isFalse);
      // a105 (12 Ekim) · a062 (bugün) · a061 (dün) · …
      expect(
        [for (final s in state.sections) s.items.first.id].take(3),
        ['a105', 'a062', 'a061'],
      );
      expect(
        state.sections.expand((s) => s.items).length,
        state.entries.length,
      );
      expect(state.lookups.users.keys, contains('u151'));
      expect(state.lookups.eventTitles.keys, containsAll(['e16', 'e03']));
      final texts = ActivityTexts(AppLocalizationsTr());
      expect(
        texts.text(act('a062'), state.lookups).text,
        'Furkan Yılmaz bir anket açtı',
      );
    });

    test('tanınmayan tür listelenmez', () async {
      seedActivity(
        entries: [
          act('a062'),
          ActivityModel(
            id: 'zz',
            clubId: kActClubId,
            actorId: 'u151',
            kind: ActivityKind.unknown,
            createdAt: kActNowUtc,
          ),
        ],
      );
      final state = (await loaded()).read(_provider);
      expect([for (final e in state.entries) e.id], ['a062']);
    });

    test('bulunamayan kullanıcı / etkinlik → missing ("Silinmiş kullanıcı", '
        '"İçerik kaldırıldı")', () async {
      seedActivity(skipUsers: {'u151'});
      (GetIt.I<EventRepository>() as FakeEventRepository).events.remove('e16');
      final state = (await loaded()).read(_provider);
      expect(state.lookups.missing, containsAll(['u151', 'e16']));
      final l10n = AppLocalizationsTr();
      final texts = ActivityTexts(l10n);
      expect(
        texts.text(act('a062'), state.lookups).actorName,
        l10n.commonDeletedUser,
      );
      expect(
        texts.text(act('a105'), state.lookups).text,
        contains(l10n.notifTargetRemoved),
      );
    });

    test('okunamadı → hata; yeniden dene → dolu', () async {
      seedActivity();
      actRepo.failNext(FirestoreError.unavailable);
      final container = await loaded();
      expect(container.read(_provider).isError, isTrue);
      await container.read(_provider.notifier).fetch();
      final state = container.read(_provider);
      expect(state.isError, isFalse);
      expect(state.entries, hasLength(kActIds.length));
    });
  });

  group('süzgeç', () {
    test('tür grubu sorguda uygulanır; "Tümü" geri döner', () async {
      seedActivity();
      final container = await loaded();
      final notifier = container.read(_provider.notifier);
      await notifier.setCategory(ActivityCategory.event);
      var state = container.read(_provider);
      expect(state.category, ActivityCategory.event);
      expect([for (final e in state.entries) e.id], ['a105', 'a092', 'a108']);
      expect(
        actRepo.callsTo('listActivity').last.args.last,
        ActivityCategory.event,
      );

      await notifier.setCategory(ActivityCategory.settings);
      expect(
        [for (final e in container.read(_provider).entries) e.id],
        [
          'a117',
        ],
      );

      await notifier.setCategory(null);
      state = container.read(_provider);
      expect(state.category, isNull);
      expect(state.entries, hasLength(kActIds.length));
    });

    test('süzgeç sonucu boş → boş liste, hata yok', () async {
      seedActivity(entries: [act('a062')]);
      final container = await loaded();
      await container
          .read(_provider.notifier)
          .setCategory(ActivityCategory.settings);
      final state = container.read(_provider);
      expect(state.isEmpty, isTrue);
      expect(state.isError, isFalse);
      expect(state.isFetching, isFalse);
    });
  });

  group('sayfalama', () {
    test('20 + imleç; sonraki sayfa eklenir, liste biter', () async {
      seedActivity(entries: _posts(25));
      final container = await loaded();
      expect(container.read(_provider).entries, hasLength(Limits.pageSize));
      expect(container.read(_provider).hasMore, isTrue);
      await container.read(_provider.notifier).loadMore();
      final state = container.read(_provider);
      expect(state.entries, hasLength(25));
      expect(state.hasMore, isFalse);
      expect(state.isLoadingMore, isFalse);
    });

    test('sonraki sayfa okunamadı → liste ve imleç kalır', () async {
      seedActivity(entries: _posts(25));
      final container = await loaded();
      final cursor = container.read(_provider).cursor;
      actRepo.failNext(FirestoreError.unavailable);
      await container.read(_provider.notifier).loadMore();
      final state = container.read(_provider);
      expect(state.entries, hasLength(Limits.pageSize));
      expect(state.cursor, cursor);
      expect(state.isLoadingMore, isFalse);
      expect(state.isError, isFalse);
    });
  });

  group('çek-yenile', () {
    test('okunamadı → içerik kalır; okundu → yeni kayıt görünür', () async {
      seedActivity();
      final container = await loaded();
      final notifier = container.read(_provider.notifier);
      actRepo.failNext(FirestoreError.unavailable);
      await notifier.refresh();
      var state = container.read(_provider);
      expect(state.isError, isFalse);
      expect(state.isRefreshing, isFalse);
      expect(state.entries, hasLength(kActIds.length));

      actRepo.entries.add(_posts(1).single);
      await notifier.refresh();
      state = container.read(_provider);
      // a105 gelecekte (12 Ekim): yeni kayıt ikinci sırada.
      expect([for (final e in state.entries) e.id].take(2), ['a105', 'x00']);
    });
  });

  group('satır hedefi', () {
    test(
      'etkinlik · gönderi · başvuru · profil · ayar · kaldırılmış',
      () async {
        seedActivity();
        final container = await loaded();
        final vm = container.read(_provider.notifier);
        expect(
          vm.targetOf(act('a105')),
          const ActivityLogTarget(ActivityLogTargetKind.event, 'e16'),
        );
        expect(
          vm.targetOf(act('a062')),
          const ActivityLogTarget(ActivityLogTargetKind.post, 'p09'),
        );
        expect(
          vm.targetOf(act('a052')),
          const ActivityLogTarget(ActivityLogTargetKind.applications),
        );
        expect(
          vm.targetOf(act('a118')),
          const ActivityLogTarget(ActivityLogTargetKind.profile, 'u086'),
        );
        expect(
          vm.targetOf(
            const ActivityModel(
              clubId: kActClubId,
              actorId: 'u_burak',
              kind: ActivityKind.settingsChanged,
            ),
          ),
          const ActivityLogTarget(ActivityLogTargetKind.settings),
        );
        expect(
          vm.targetOf(
            const ActivityModel(
              clubId: kActClubId,
              actorId: 'u_burak',
              kind: ActivityKind.eventCancelled,
              refs: ActivityRefsModel(eventId: 'gone'),
            ),
          ),
          // Henüz okunmamış kimlik: hedef yine etkinlik.
          const ActivityLogTarget(ActivityLogTargetKind.event, 'gone'),
        );
      },
    );

    test('kaldırılmış etkinlik → hedef yok', () async {
      seedActivity();
      (GetIt.I<EventRepository>() as FakeEventRepository).events.remove('e16');
      final container = await loaded();
      expect(
        container.read(_provider.notifier).targetOf(act('a105')),
        const ActivityLogTarget(ActivityLogTargetKind.none),
      );
    });
  });

  test('State: props ve copyWith tüm alanları kapsar', () {
    const base = ActivityLogState();
    final changed = base.copyWith(
      club: ClubModelFixtures.byId(kActClubId),
      entries: [act('a062')],
      sections: [
        ActivityDaySection(day: kActNowUtc, items: [act('a062')]),
      ],
      category: ActivityCategory.content,
      isFetching: true,
      isLoadingMore: true,
      isRefreshing: true,
      isError: true,
    );
    expect(changed, isNot(base));
    expect(changed.props, hasLength(base.props.length));
    expect(changed.copyWith(clearCategory: true).category, isNull);
    expect(changed.copyWith(), changed);
  });
}

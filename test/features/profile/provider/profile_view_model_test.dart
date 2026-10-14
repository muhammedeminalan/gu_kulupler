// PRF-01 · ProfileViewModel: açılış (oturum + getClubs + listMine →
// istatistikler), yönetilen kulüpler (başkan / yönetim kurulu / danışman),
// oturumda yeni üyelik → eksik kulübün okunması, hata / yeniden dene /
// çek-yenile, profil fotoğrafı (SHT-16 seçimi → updateAvatar → TST-57;
// çevrimdışı TST-24; yazım hatası → önizleme geri alınır) (PLAN §12.6).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/profile/provider/profile_state.dart';
import 'package:gu_kulupler/features/profile/provider/profile_view_model.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';
import 'package:gu_kulupler/product/service/image_picker_service.dart';

import '../../../fakes/fake_app_preferences_store.dart';
import '../../../fakes/fake_club_repository.dart';
import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_image_picker_service.dart';
import '../../../fakes/fake_rsvp_repository.dart';
import '../../../fakes/fake_user_repository.dart';
import '../../../fakes/register_fakes.dart';
import '../../../fixtures/club_model_fixtures.dart';
import '../../../fixtures/membership_model_fixtures.dart';
import '../../../helpers/test_container.dart';
import '../profile_test_support.dart';

void main() {
  late FakeClubRepository clubs;
  late FakeRsvpRepository rsvps;
  late FakeUserRepository users;
  late FakeFeedbackService feedback;

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    clubs = GetIt.I<ClubRepository>() as FakeClubRepository;
    rsvps = GetIt.I<RsvpRepository>() as FakeRsvpRepository;
    users = GetIt.I<UserRepository>() as FakeUserRepository;
    feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
    seedProfile();
  });

  Future<ProviderContainer> loaded([SessionState? session]) async {
    final container = createContainer(
      overrides: [
        sessionViewModelProvider.overrideWithBuild(
          (ref, notifier) => session ?? profileSession(),
        ),
      ],
    );
    addTearDown(container.listen(profileViewModelProvider, (_, _) {}).close);
    await pumpEventQueue();
    return container;
  }

  ProfileState stateOf(ProviderContainer c) => c.read(profileViewModelProvider);

  ProfileViewModel vmOf(ProviderContainer c) =>
      c.read(profileViewModelProvider.notifier);

  List<String> idsOf(List<ProfileClub> entries) => [
    for (final entry in entries) entry.club.id,
  ];

  group('PRF-01 · açılış', () {
    test('oturumdan kullanıcı + üyelikler; kulüpler tek toplu sorgu; '
        'istatistikler 2 · 1 · 1', () async {
      final c = await loaded();
      final state = stateOf(c);
      expect(state.isFetching, isFalse);
      expect(state.isError, isFalse);
      expect(state.user, kProfileUser);
      expect(idsOf(state.myClubs), ['c01', 'c07']);
      expect(state.myClubs.map((e) => e.role), everyElement(ClubRole.member));
      expect(state.managedClubs, isEmpty);
      expect(
        state.stats,
        const ProfileStats(clubCount: 2, eventCount: 1, pendingCount: 1),
      );
      expect(clubs.callsTo('getClubs').single.args, [
        ['c01', 'c07'],
      ]);
      expect(rsvps.callsTo('listMine').single.args, [kProfileUid]);
    });

    test(
      'yönetilen kulüpler: başkan, yönetim kurulu, danışman; üye değil',
      () async {
        final c = await loaded(
          profileSession(
            memberships: profileMembershipsWithRoles({
              'c01': ClubRole.president,
              'c07': ClubRole.advisor,
              'c06': ClubRole.board, // bekleyen başvuru: rol taşımaz
            }),
          ),
        );
        expect(idsOf(stateOf(c).managedClubs), ['c01', 'c07']);

        final board = await loaded(
          profileSession(
            memberships: profileMembershipsWithRoles({'c07': ClubRole.board}),
          ),
        );
        expect(idsOf(stateOf(board).managedClubs), ['c07']);
      },
    );

    test('belgesi olmayan kulüp sayılmaz ve listelenmez', () async {
      clubs.clubs.remove('c07');
      final c = await loaded();
      expect(idsOf(stateOf(c).myClubs), ['c01']);
      expect(stateOf(c).stats.clubCount, 1);
    });

    test('oturumda yeni aktif üyelik → yalnızca eksik kulüp okunur', () async {
      final c = await loaded();
      clubs.calls.clear();
      final joined = MembershipModelFixtures.c01Mehmet.copyWith(
        id: FirestoreIds.membership('c03', kProfileUid),
        clubId: 'c03',
      );
      clubs.clubs['c03'] = ClubModelFixtures.byId('c03');
      c.read(sessionViewModelProvider.notifier).state = profileSession(
        memberships: [...kProfileMemberships, joined],
      );
      await pumpEventQueue();
      expect(clubs.callsTo('getClubs').single.args, [
        ['c03'],
      ]);
      expect(idsOf(stateOf(c).myClubs), ['c01', 'c07', 'c03']);
      expect(stateOf(c).stats.clubCount, 3);
    });
  });

  group('PRF-01 · hata ve yenileme', () {
    test('okunamadı → isError; "Yeniden dene" içeriği getirir', () async {
      clubs.failNext(FirestoreError.unavailable);
      final c = await loaded();
      expect(stateOf(c).isError, isTrue);
      expect(stateOf(c).isFetching, isFalse);

      await vmOf(c).fetch();
      expect(stateOf(c).isError, isFalse);
      expect(idsOf(stateOf(c).myClubs), ['c01', 'c07']);
    });

    test('çek-yenile hatası içeriği silmez', () async {
      final c = await loaded();
      rsvps.failNext(FirestoreError.unavailable);
      await vmOf(c).refresh();
      final state = stateOf(c);
      expect(state.isError, isFalse);
      expect(state.isRefreshing, isFalse);
      expect(idsOf(state.myClubs), ['c01', 'c07']);
    });
  });

  group('PRF-01 · profil fotoğrafı', () {
    setUp(() {
      (GetIt.I<AppPreferencesStore>() as FakeAppPreferencesStore)
              .values[AppPreferenceKeys.photoAccessExplained] =
          true;
    });

    test('galeri → updateAvatar (yamasız) → TST-57', () async {
      final c = await loaded();
      await vmOf(c).changeAvatar(MediaSource.gallery);
      final upload = users.callsTo('updateAvatar').single.args;
      expect(upload, [
        kProfileUid,
        kFakeJpeg.bytes.length,
        kFakeJpeg.contentType,
        null,
      ]);
      expect(feedback.toasts, [ToastId.tst57]);
      expect(stateOf(c).isUpdatingAvatar, isFalse);
    });

    test('vazgeçildi → yazım yok', () async {
      (GetIt.I<ImagePickerService>() as FakeImagePickerService).nextPick = null;
      final c = await loaded();
      await vmOf(c).changeAvatar(MediaSource.gallery);
      expect(users.callsTo('updateAvatar'), isEmpty);
      expect(feedback.toasts, isEmpty);
    });

    test('çevrimdışı → TST-24, yazım yok', () async {
      final c = await loaded();
      (GetIt.I<ConnectivityService>() as FakeConnectivityService).isOffline =
          true;
      await vmOf(c).changeAvatar(MediaSource.gallery);
      expect(users.callsTo('updateAvatar'), isEmpty);
      expect(feedback.toasts, [ToastId.tst24]);
    });

    test('yükleme ağ hatası → TST-24; önizleme geri alınır', () async {
      final c = await loaded();
      users.failNext(StorageError.retryLimitExceeded);
      await vmOf(c).changeAvatar(MediaSource.gallery);
      expect(feedback.toasts, [ToastId.tst24]);
      expect(stateOf(c).avatarPreview, isNull);
      expect(stateOf(c).isUpdatingAvatar, isFalse);
    });
  });
}

// ADM-04 · AdminReportsViewModel: yükleme (açık şikayetler — CD-37; hedef
// başına gruplama + satır önizlemeleri), sekme (çözülmüş tembel okunur),
// hedef türü süzgeci, SHT-26 açılışı (listede olmayan grup — `?reportId=`),
// çözümler (ihlal yok TST-56 · içerik kaldır TST-51 · kullanıcı askısı
// TST-52 · kulüp askısı TST-50; çözüm grubun TÜM açık belgelerini çözer,
// `report_resolved` şikayetçi başına; askı çözümden önce; iyimser + hata →
// geri), `permissionDenied` → claim yenileme (CD-160), çevrimdışı engel —
// PLAN §12 `AdminReportsViewModel`.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/admin/provider/admin_reports_state.dart';
import 'package:gu_kulupler/features/admin/provider/admin_reports_view_model.dart';
import 'package:gu_kulupler/features/admin/view/widget/report_detail_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/navigation/admin_reports_tab.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';

import '../../../fakes/fake_admin_repository.dart';
import '../../../fakes/fake_auth_repository.dart';
import '../../../fakes/fake_auth_service.dart';
import '../../../fakes/fake_club_repository.dart';
import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_post_repository.dart';
import '../../../fakes/fake_session_states.dart';
import '../../../fakes/fake_user_repository.dart';
import '../../../fakes/register_fakes.dart';
import '../../../helpers/test_container.dart';
import '../admin_reports_test_support.dart';

void main() {
  late FakeAdminRepository admin;
  late FakeFeedbackService feedback;

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    admin = GetIt.I<AdminRepository>() as FakeAdminRepository;
    feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
    seedAdminReports();
    // Aktör = oturumdaki süper admin (fake `resolveReports` denetler).
    (GetIt.I<AuthService>() as FakeAuthService).currentUser =
        const AuthUserInfo(
          uid: FakeSessionStates.uid,
          email: 'mehmet@ogr.gumushane.edu.tr',
          emailVerified: true,
          displayName: 'Mehmet',
        );
  });

  Future<ProviderContainer> loaded() async {
    final container = createContainer(
      overrides: [
        sessionViewModelProvider.overrideWithBuild(
          (ref, notifier) => FakeSessionStates.activeSuper,
        ),
      ],
    );
    addTearDown(
      container.listen(adminReportsViewModelProvider, (_, _) {}).close,
    );
    await pumpEventQueue();
    return container;
  }

  AdminReportsViewModel vm(ProviderContainer c) =>
      c.read(adminReportsViewModelProvider.notifier);

  AdminReportsState read(ProviderContainer c) =>
      c.read(adminReportsViewModelProvider);

  group('ADM-04 · AdminReportsViewModel · okuma, gruplama, süzgeç', () {
    test('açık şikayetler (CD-37): aynı hedefin 3 şikayeti tek grup; 5 grup '
        'son şikayete göre; önizlemeler toplu okunur', () async {
      final container = await loaded();
      final state = read(container);

      expect(admin.callsTo('listOpenReports'), hasLength(1));
      expect(admin.callsTo('listReports'), isEmpty);
      expect(state.isLoaded, isTrue);
      expect(state.isError, isFalse);
      expect(state.visible.map((g) => g.key), kOpenGroupKeys);
      expect(state.openCount, 5);
      final p17 = state.groupByKey('post_p17')!;
      expect(p17.count, 3);
      expect(p17.primaryReason, ReportReason.spam);

      expect(state.previews['post_p17']!.post!.id, 'p17');
      expect(state.previews['user_u077']!.user!.name, 'Nisa Yıldırım');
      expect(state.previews['club_c10']!.club!.name, 'E-Spor Kulübü');
      // Yorum hedefi okunamaz (`getComment` yok) → kayıt yok.
      expect(state.previews.containsKey('comment_cm24'), isFalse);
    });

    test('silinmiş hedef → boş önizleme (İçerik kaldırıldı)', () async {
      final posts = GetIt.I<PostRepository>() as FakePostRepository;
      posts.posts['p24'] = posts.posts['p24']!.copyWith(isDeleted: true);
      final container = await loaded();
      expect(read(container).previews['post_p24']!.isMissing, isTrue);
    });

    test(
      'süzgeç hedef türüne göre; çözüldü sekmesi ilk açılışta okunur',
      () async {
        final container = await loaded();

        vm(container).setTypeFilter(ReportTargetFilter.post);
        expect(read(container).visible.map((g) => g.key), [
          'post_p24',
          'post_p17',
        ]);

        vm(container).setTab(AdminReportsTab.resolved);
        expect(read(container).isFetching, isTrue);
        await pumpEventQueue();
        final state = read(container);
        expect(
          admin.callsTo('listReports').single.args.first,
          ReportStatus.resolved,
        );
        expect(state.isFetching, isFalse);
        expect(state.visible.map((g) => g.key), ['post_p13']);

        vm(container).setTypeFilter(ReportTargetFilter.all);
        expect(read(container).visible.map((g) => g.key), kResolvedGroupKeys);
      },
    );

    test('okuma hatası → hata; "Yeniden dene" düzeltir', () async {
      admin.failNext(FirestoreError.unavailable);
      final container = await loaded();
      expect(read(container).isError, isTrue);

      await vm(container).fetch();
      expect(read(container).isError, isFalse);
      expect(read(container).visible, hasLength(5));
    });

    test('permissionDenied → claim yenilenir; hâlâ süper admin → bir kez '
        'yinelenir (CD-160)', () async {
      final auth = GetIt.I<AuthRepository>() as FakeAuthRepository
        ..isSuperAdminResult = true;
      admin.failNext(FirestoreError.permissionDenied);

      final container = await loaded();

      expect(read(container).isError, isFalse);
      expect(admin.callsTo('listOpenReports'), hasLength(2));
      expect(auth.callsTo('isSuperAdmin').single.args, [true]);
    });
  });

  group('ADM-04 · AdminReportsViewModel · SHT-26 açılışı', () {
    test(
      'listedeki grup: önizleme (yazar dahil) + şikayetçiler okunur',
      () async {
        final container = await loaded();

        final group = await vm(container).openGroup('post_p17');
        await pumpEventQueue();

        expect(group!.count, 3);
        final state = read(container);
        expect(state.openGroupKey, 'post_p17');
        expect(state.targetPreview!.post!.id, 'p17');
        expect(state.targetPreview!.author!.uid, 'u044');
        expect(state.targetPreview!.suspendableUserId, 'u044');
        expect(state.reporters.keys, containsAll(['u051', 'u052', 'u053']));

        vm(container).closeGroup('post_p17');
        expect(read(container).openGroupKey, isNull);
        expect(read(container).targetPreview, isNull);
      },
    );

    test('listede olmayan grup (?reportId=): hedefin açık şikayetleri '
        'okunur; geçersiz anahtar → null', () async {
      final container = await loaded();
      admin.putReport(
        reporterId: 'u060',
        type: ReportTargetType.event,
        targetId: 'e05',
        targetClubId: 'c01',
      );

      final group = await vm(container).openGroup('event_e05');
      expect(group!.key, 'event_e05');
      expect(read(container).detailGroup, group);
      expect(
        admin.callsTo('listReportsForTarget').single.args,
        [ReportTargetType.event, 'e05'],
      );

      expect(await vm(container).openGroup('nope_x'), isNull);
      expect(await vm(container).openGroup('post_yok'), isNull);
    });
  });

  group('ADM-04 · AdminReportsViewModel · çözüm', () {
    test('ihlal yok → grubun TÜM açık belgeleri dismissed; şikayetçi başına '
        'report_resolved; satır çözüldüye geçer; TST-56', () async {
      final container = await loaded();
      // Listede olmayan (sonradan gelen) açık şikayet de çözülür.
      admin.putReport(
        reporterId: 'u060',
        type: ReportTargetType.post,
        targetId: 'p17',
        targetClubId: 'c05',
      );

      final ok = await vm(container).dismiss('post_p17');

      expect(ok, isTrue);
      final resolution = admin.resolutions.single;
      expect(resolution.groupKey, 'post_p17');
      expect(resolution.action, ReportAction.dismissed);
      expect(resolution.reportIds, hasLength(4));
      expect(
        resolution.reporterIds.toSet(),
        {'u051', 'u052', 'u053', 'u060'},
      );
      final state = read(container);
      expect(state.visible.map((g) => g.key), isNot(contains('post_p17')));
      expect(state.openCount, 4);
      expect(state.pendingActions, isEmpty);
      expect(feedback.toasts, [ToastId.tst56]);
    });

    test('içerik kaldır → removed + gönderi gizlenir; TST-51', () async {
      final container = await loaded();

      expect(await vm(container).removeContent('post_p24'), isTrue);

      expect(admin.resolutions.single.action, ReportAction.removed);
      expect(admin.resolutions.single.hidden, isTrue);
      final posts = GetIt.I<PostRepository>() as FakePostRepository;
      expect(posts.posts['p24']!.isHidden, isTrue);
      expect(feedback.toasts, [ToastId.tst51]);
      // Kullanıcı / kulüp hedefinde içerik kaldırılmaz.
      expect(await vm(container).removeContent('user_u077'), isFalse);
    });

    test('kullanıcı askısı: önce suspendUser (gerekçe kırpılır), sonra '
        'suspended çözüm; TST-52', () async {
      final container = await loaded();

      final ok = await vm(
        container,
      ).suspendUser('user_u077', userId: 'u077', reason: '  Taciz  ');

      expect(ok, isTrue);
      final names = admin.calls.map((c) => c.method).toList();
      expect(
        names.indexOf('suspendUser'),
        lessThan(names.indexOf('resolveReports')),
      );
      expect(admin.callsTo('suspendUser').single.args, ['u077', 'Taciz']);
      final users = GetIt.I<UserRepository>() as FakeUserRepository;
      expect(users.users['u077']!.status, UserStatus.suspended);
      expect(admin.resolutions.single.action, ReportAction.suspended);
      expect(feedback.toasts, [ToastId.tst52]);
      expect(feedback.toastParams.single.suspended, isTrue);
    });

    test('kulüp askısı: önce suspendClub, sonra çözüm; TST-50', () async {
      final container = await loaded();

      expect(
        await vm(container).suspendClub('club_c10', reason: 'Yanlış bilgi'),
        isTrue,
      );

      final clubs = GetIt.I<ClubRepository>() as FakeClubRepository;
      expect(clubs.clubs['c10']!.isSuspended, isTrue);
      expect(admin.resolutions.single.groupKey, 'club_c10');
      expect(feedback.toasts, [ToastId.tst50]);
    });

    test('askı başarısız → çözüm yazılmaz, satır geri döner, TST-24', () async {
      final container = await loaded();
      admin.failNext(FirestoreError.unavailable);

      final ok = await vm(
        container,
      ).suspendUser('user_u077', userId: 'u077', reason: 'Taciz');

      expect(ok, isFalse);
      expect(admin.callsTo('resolveReports'), isEmpty);
      final state = read(container);
      expect(state.visible.map((g) => g.key), kOpenGroupKeys);
      expect(state.pendingActions, isEmpty);
      expect(feedback.toasts, [ToastId.tst24]);
    });

    test(
      'çözüm sürerken satır hemen kalkar (iyimser); hata → geri döner',
      () async {
        final container = await loaded();
        admin.failNext(FirestoreError.unavailable);

        final future = vm(container).dismiss('post_p17');
        final during = read(container);
        expect(during.visible.map((g) => g.key), isNot(contains('post_p17')));
        expect(during.pendingActions, {'post_p17': ReportDetailAction.dismiss});

        expect(await future, isFalse);
        final state = read(container);
        expect(state.visible.map((g) => g.key), kOpenGroupKeys);
        expect(state.pendingActions, isEmpty);
        expect(admin.resolutions, isEmpty);
        expect(feedback.toasts, [ToastId.tst24]);
      },
    );

    test('çevrimdışı → yazım yok, TST-24', () async {
      final connectivity =
          GetIt.I<ConnectivityService>() as FakeConnectivityService;
      final container = await loaded();
      connectivity.isOffline = true;

      expect(await vm(container).dismiss('post_p17'), isFalse);
      expect(admin.callsTo('resolveReports'), isEmpty);
      expect(feedback.toasts, [ToastId.tst24]);
    });
  });
}

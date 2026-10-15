// CLB-07 · UserProfileViewModel (kullanıcı + açılış kulübü ailesi): açılış
// okuması (kullanıcı, ortak kulüpler, roller), gizlilik dalları (D-29: ortak
// kulüp, yönetici bağlamı, süper admin, kendi profili, Rules reddi), belge
// yok / okuma hatası / silinmiş kullanıcı, engelleme (DLG-13 → TST-09 →
// "Geri al"), engeli kaldırma (TST-09 → "Geri al"), yazma hataları (TST-24,
// TST-X18) ve kullanıcı şikayeti (SHT-10 → DLG-12 → DLG-13) — PLAN §12.6.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/clubs/provider/user_profile_state.dart';
import 'package:gu_kulupler/features/clubs/provider/user_profile_view_model.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/dialog_spec.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/report_reason_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/toasts/toast_catalog.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/service/share_service.dart';

import '../../../fakes/fake_management_repository.dart';
import '../../../fakes/fake_share_service.dart';
import '../../../fakes/register_fakes.dart';
import '../../../fixtures/membership_model_fixtures.dart';
import '../../../helpers/test_container.dart';
import '../user_profile_test_support.dart';

/// Kapsayıcıyı kurar, ViewModel'i canlı tutar ve açılış okumasını bekler.
Future<ProviderContainer> _container({
  SessionState? session,
  String userId = kUserId,
  String? clubId = kClubId,
}) async {
  final container = createContainer(
    overrides: [
      sessionViewModelProvider.overrideWithBuild(
        (_, _) => session ?? viewerSession(),
      ),
    ],
  );
  addTearDown(
    container
        .listen(profileProvider(userId: userId, clubId: clubId), (_, _) {})
        .close,
  );
  await pumpEventQueue();
  return container;
}

UserProfileViewModel _viewModel(ProviderContainer container) =>
    container.read(profileProvider().notifier);

UserProfileState _state(ProviderContainer container) =>
    container.read(profileProvider());

Set<String> _sessionBlocks(ProviderContainer container) =>
    container.read(sessionViewModelProvider).blockedUserIds;

/// Engel deposuna yapılan yazımlar, sırasıyla.
List<String> _blockWrites() => [
  for (final call in blocksFake().calls)
    if (const {
      'block',
      'softDeleteBlock',
      'restoreBlock',
    }.contains(call.method))
      call.method,
];

void main() {
  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
  });

  group('CLB-07 · UserProfileViewModel · yükleme', () {
    test('ilk durum okuyor; engel durumu ve "kendisi" oturumdan gelir', () {
      seedProfile();
      final container = createContainer(
        overrides: [
          sessionViewModelProvider.overrideWithBuild(
            (_, _) => viewerSession(blockedUserIds: {kUserId}),
          ),
        ],
      );
      addTearDown(container.listen(profileProvider(), (_, _) {}).close);
      expect(
        _state(container),
        const UserProfileState(isBlocked: true, isFetching: true),
      );
    });

    test('görünür profil: kullanıcı + ortak kulüp; bakanın aktif kulüpleri '
        'için birer üyelik okuması', () async {
      seedProfile();
      final container = await _container();

      expect(_state(container), kVisibleState);
      expect(_state(container).showsDetails, isTrue);
      expect(_state(container).canOpenMenu, isTrue);
      expect(usersFake().callsTo('getUser').single.args, [kUserId]);
      expect(
        [for (final c in membershipsFake().callsTo('getMembership')) c.args],
        [
          [kSharedClubId, kUserId],
          [kClubId, kUserId],
        ],
      );
      expect(clubsFake().callsTo('getClubs').single.args, [
        [kSharedClubId],
      ]);
    });

    test('ortak kulüpteki üye dışı rol rozet olur', () async {
      seedProfile(shared: false);
      membershipsFake().put(kUserInShared.copyWith(role: ClubRole.board));
      final container = await _container();

      expect(_state(container).roles, [ClubRole.board]);
      expect(_state(container).sharedClubIds, [kSharedClubId]);
    });

    test('ortak kulüp belgeleri okunamazsa çipler çizilmez; profil yine '
        'görünür', () async {
      seedProfile();
      clubsFake().failNext(FirestoreError.permissionDenied);
      final container = await _container();

      final state = _state(container);
      expect(state.sharedClubIds, [kSharedClubId]);
      expect(state.sharedClubs, isEmpty);
      expect(state.isHiddenByPrivacy, isFalse);
      expect(state.isError, isFalse);
    });

    test('gizlilik (D-29): ortak kulüp yok → gizli; kullanıcının aktif '
        'olmayan üyeliği ortak sayılmaz', () async {
      seedProfile(shared: false);
      membershipsFake().put(
        kUserInShared.copyWith(status: MembershipStatus.left),
      );
      final container = await _container();

      final state = _state(container);
      expect(state.user, kUser);
      expect(state.isHiddenByPrivacy, isTrue);
      expect(state.showsDetails, isFalse);
      expect(state.sharedClubIds, isEmpty);
      expect(clubsFake().callsTo('getClubs'), isEmpty);
    });

    test(
      'gizlilik: Rules üyelik okumasını reddederse ortak sayılmaz',
      () async {
        seedProfile();
        // İlk okuma (`c01`) reddedilir: Rules olmayan / görülemeyen belgeyi
        // `permission-denied` ile düşürür.
        membershipsFake().failNext(FirestoreError.permissionDenied);
        final container = await _container(
          session: viewerSession(memberships: [kViewerInShared]),
        );

        expect(_state(container).isHiddenByPrivacy, isTrue);
        expect(_state(container).isError, isFalse);
      },
    );

    test('yönetici bağlamı: bakan açılış kulübünün yöneticisi ve kullanıcının '
        'orada kaydı (bekleyen başvuru) var → görünür', () async {
      seedProfile(shared: false);
      final pending = MembershipModelFixtures.byId('c03_u_cem').copyWith(
        id: FirestoreIds.membership(kClubId, kUserId),
        userId: kUserId,
      );
      membershipsFake().put(pending);
      final container = await _container();

      final state = _state(container);
      expect(state.isHiddenByPrivacy, isFalse);
      expect(state.contextMembership, pending);
      expect(state.sharedClubIds, isEmpty);
    });

    test('süper admin ortak kulüp olmadan da görür; açılış kulübündeki '
        'üyelik okunur', () async {
      seedProfile(shared: false);
      final container = await _container(
        session: viewerSession(memberships: const [], isSuperAdmin: true),
      );

      expect(_state(container).isHiddenByPrivacy, isFalse);
      expect(membershipsFake().callsTo('getMembership').single.args, [
        kClubId,
        kUserId,
      ]);
    });

    test('kendi profili: görünür, menü yok, üyelik okunmaz; süper admin '
        'rozeti yalnızca burada', () async {
      seedProfile();
      final container = createContainer(
        overrides: [
          sessionViewModelProvider.overrideWithBuild(
            (_, _) => viewerSession(isSuperAdmin: true),
          ),
        ],
      );
      final provider = profileProvider(userId: kViewer.uid, clubId: null);
      addTearDown(container.listen(provider, (_, _) {}).close);
      await pumpEventQueue();

      final state = container.read(provider);
      expect(state.user, kViewer);
      expect(state.isSelf, isTrue);
      expect(state.isSuperAdmin, isTrue);
      expect(state.isHiddenByPrivacy, isFalse);
      expect(state.canOpenMenu, isFalse);
      expect(state.sharedClubIds, [kSharedClubId, kClubId]);
      expect(state.roles, [ClubRole.president]);
      expect(membershipsFake().callsTo('getMembership'), isEmpty);

      // Kendi kendini engelleme yok.
      await container.read(provider.notifier).toggleBlock();
      expect(feedbackFake().dialogs, isEmpty);
      expect(_blockWrites(), isEmpty);
    });

    test('belge yok → isNotFound; okuma hatası → isError, "Yeniden dene" '
        'toparlar', () async {
      seedProfile(withUser: false);
      final missing = await _container();
      expect(_state(missing).isNotFound, isTrue);
      expect(_state(missing).isFetching, isFalse);

      await GetIt.I.reset();
      registerDefaultFakes();
      seedProfile();
      usersFake().failNext(FirestoreError.unavailable);
      final failed = await _container();
      expect(_state(failed).isError, isTrue);
      expect(_state(failed).user, isNull);

      await _viewModel(failed).fetch();
      expect(_state(failed), kVisibleState);
    });

    test(
      'üyelik okumasında bağlantı hatası → isError (gizli sayılmaz)',
      () async {
        seedProfile();
        membershipsFake().failNext(FirestoreError.unavailable);
        final container = await _container();

        expect(_state(container).isError, isTrue);
        expect(_state(container).isHiddenByPrivacy, isFalse);
      },
    );

    test(
      'silinmiş kullanıcı: yalnızca belge; ilişkiler okunmaz, menü yok',
      () async {
        final deleted = kUser.copyWith(
          status: UserStatus.deleted,
          isDeleted: true,
        );
        seedProfile(user: deleted);
        final container = await _container();

        final state = _state(container);
        expect(state.user, deleted);
        expect(state.isDeletedUser, isTrue);
        expect(state.canOpenMenu, isFalse);
        expect(state.showsDetails, isFalse);
        expect(state.isHiddenByPrivacy, isFalse);
        expect(membershipsFake().callsTo('getMembership'), isEmpty);
      },
    );
  });

  group('CLB-07 · UserProfileViewModel · engelleme (DLG-13, TST-09)', () {
    test('engelle: DLG-13 onayı → block → TST-09 "… engellendi."; oturumdaki '
        'engel kümesi eşitlenir; "Geri al" → softDeleteBlock', () async {
      seedProfile();
      final container = await _container();
      feedbackFake().nextDialogResult = true;

      await _viewModel(container).toggleBlock();
      await pumpEventQueue();

      expect(feedbackFake().dialogs, [DialogId.dlg13]);
      expect(feedbackFake().dialogParams.single, {
        DialogParamKeys.name: kUser.name,
      });
      expect(_blockWrites(), ['block']);
      expect(blocksFake().callsTo('block').single.args, [kViewer.uid, kUserId]);
      expect(_state(container).isBlocked, isTrue);
      expect(_state(container).isActing, isFalse);
      expect(feedbackFake().toasts, [ToastId.tst09]);
      expect(feedbackFake().toastParams.single, ToastParams(name: kUser.name));
      expect(_sessionBlocks(container), {kUserId});

      feedbackFake().tapToastAction();
      await pumpEventQueue();

      expect(_blockWrites(), ['block', 'softDeleteBlock']);
      expect(_state(container).isBlocked, isFalse);
      expect(_sessionBlocks(container), isEmpty);
    });

    test('DLG-13 "Vazgeç" / scrim: hiçbir şey yazılmaz', () async {
      seedProfile();
      final container = await _container();
      for (final result in [false, null]) {
        feedbackFake().nextDialogResult = result;
        await _viewModel(container).toggleBlock();
      }

      expect(feedbackFake().dialogs, [DialogId.dlg13, DialogId.dlg13]);
      expect(_blockWrites(), isEmpty);
      expect(_state(container).isBlocked, isFalse);
      expect(feedbackFake().toasts, isEmpty);
    });

    test('engeli kaldır: onaysız softDeleteBlock → TST-09 "… için engel '
        'kaldırıldı."; "Geri al" → restoreBlock', () async {
      seedProfile();
      blocksFake().put(kViewer.uid, kUserId);
      final container = await _container(
        session: viewerSession(blockedUserIds: {kUserId}),
      );
      expect(_state(container).isBlocked, isTrue);

      await _viewModel(container).toggleBlock();
      await pumpEventQueue();

      expect(feedbackFake().dialogs, isEmpty);
      expect(_blockWrites(), ['softDeleteBlock']);
      expect(_state(container).isBlocked, isFalse);
      expect(
        feedbackFake().toastParams.single,
        ToastParams(name: kUser.name, unblocked: true),
      );
      expect(_sessionBlocks(container), isEmpty);

      feedbackFake().tapToastAction();
      await pumpEventQueue();

      expect(_blockWrites(), ['softDeleteBlock', 'restoreBlock']);
      expect(_state(container).isBlocked, isTrue);
      expect(_sessionBlocks(container), {kUserId});
    });

    test('yazma hatası: iyimser değişiklik geri alınır; yetki → TST-X18, ağ → '
        'TST-24; TST-09 gösterilmez', () async {
      seedProfile();
      final container = await _container();
      for (final (error, toast) in [
        (FirestoreError.permissionDenied, ToastId.tstX18),
        (FirestoreError.unavailable, ToastId.tst24),
      ]) {
        feedbackFake().resetFake();
        feedbackFake().nextDialogResult = true;
        blocksFake().failNext(error);

        await _viewModel(container).toggleBlock();

        expect(_state(container).isBlocked, isFalse, reason: error.name);
        expect(feedbackFake().toasts, [toast], reason: error.name);
      }
    });

    test('çevrimdışı: TST-24, hiçbir şey yazılmaz', () async {
      seedProfile();
      final container = await _container();
      connectivityFake().isOffline = true;
      feedbackFake().nextDialogResult = true;

      await _viewModel(container).toggleBlock();

      expect(_blockWrites(), isEmpty);
      expect(_state(container).isBlocked, isFalse);
      expect(feedbackFake().toasts, [ToastId.tst24]);
    });

    test('oturumdaki engel kümesi değişince state eşitlenir', () async {
      seedProfile();
      final container = await _container();

      container.read(sessionViewModelProvider.notifier).state = viewerSession(
        blockedUserIds: {kUserId},
      );
      expect(_state(container).isBlocked, isTrue);
    });
  });

  group('CLB-07 · UserProfileViewModel · şikayet (SHT-10, DLG-12)', () {
    const report = ReportReasonResult(
      target: (type: ReportTargetType.user, id: kUserId, clubId: null),
      reason: ReportReason.harassment,
    );

    test('şikayet kullanıcı hedefiyle yazılır; aynı kullanıcı yeniden '
        'bildirilirse de başarı; çevrimdışı → TST-24', () async {
      seedProfile();
      final container = await _container();
      final viewModel = _viewModel(container);

      expect(viewModel.reportTarget, report.target);
      expect(await viewModel.submitReport(report), isTrue);
      expect(reportsFake().callsTo('report').single.args, [
        kViewer.uid,
        report.target,
        ReportReason.harassment,
        '',
      ]);
      expect(await viewModel.submitReport(report), isTrue);

      connectivityFake().isOffline = true;
      expect(await viewModel.submitReport(report), isFalse);
      expect(feedbackFake().toasts, [ToastId.tst24]);
    });

    test('şikayet yazılamazsa sheet açık kalır: yetki → TST-X18, beklenmeyen '
        'hata → sessiz', () async {
      seedProfile();
      final container = await _container();
      for (final (error, toasts) in [
        (FirestoreError.permissionDenied, [ToastId.tstX18]),
        (FirestoreError.unknown, <ToastId>[]),
      ]) {
        feedbackFake().resetFake();
        reportsFake().failNext(error);
        expect(await _viewModel(container).submitReport(report), isFalse);
        expect(feedbackFake().toasts, toasts, reason: error.name);
      }
    });

    test(
      'DLG-12 kullanıcı adını taşır; "… da engelle" → DLG-13 → engellenir',
      () async {
        seedProfile();
        final container = await _container();
        // DLG-12: "… kullanıcısını da engelle" → false; DLG-13: onay.
        feedbackFake().nextDialogResult = false;
        feedbackFake().dialogResults[DialogId.dlg13] = true;

        await _viewModel(container).showReportReceived();

        expect(feedbackFake().dialogs, [DialogId.dlg12, DialogId.dlg13]);
        expect(feedbackFake().dialogParams.first, {
          DialogParamKeys.name: kUser.name,
        });
        expect(_blockWrites(), ['block']);
        expect(_state(container).isBlocked, isTrue);
      },
    );

    test('DLG-12 "Tamam": engelleme sorulmaz', () async {
      seedProfile();
      final container = await _container();
      feedbackFake().nextDialogResult = true;

      await _viewModel(container).showReportReceived();

      expect(feedbackFake().dialogs, [DialogId.dlg12]);
      expect(_blockWrites(), isEmpty);
    });
  });

  group('CLB-07 · UserProfileViewModel · yönetici kartı (W-69)', () {
    /// Kullanıcının açılış kulübündeki (`c03`) aktif üyeliği.
    MembershipModel inContext({ClubRole role = ClubRole.member}) =>
        kUserInShared.copyWith(
          id: FirestoreIds.membership(kClubId, kUserId),
          clubId: kClubId,
          role: role,
          status: MembershipStatus.active,
        );

    void seedContext({ClubRole role = ClubRole.member}) {
      seedProfile();
      final membership = inContext(role: role);
      membershipsFake()
        ..put(membership)
        ..contacts[membership.id] = MembershipContactModel(
          email: 'yigit@ogr.gumushane.edu.tr',
          emailLower: 'yigit@ogr.gumushane.edu.tr',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        );
    }

    FakeManagementRepository management() =>
        GetIt.I<ManagementRepository>() as FakeManagementRepository;

    test('başkan bakışı: aktif üyelik, e-posta, kulüp adı, rol atama yetkisi; '
        '"Kopyala" → TST-08', () async {
      seedContext();
      final container = await _container();
      final state = _state(container);
      expect(state.showsManagerCard, isTrue);
      expect(state.showsManagerActions, isTrue);
      expect(state.contactEmail, 'yigit@ogr.gumushane.edu.tr');
      expect(state.contextClubName, clubsFake().clubs[kClubId]!.name);
      expect(state.canAssignRoles, isTrue);

      await _viewModel(container).copyEmail();
      final share = GetIt.I<ShareService>() as FakeShareService;
      expect(share.copied, ['yigit@ogr.gumushane.edu.tr']);
      expect(feedbackFake().toasts, [ToastId.tst08]);
    });

    test(
      '"Rolü değiştir": SHT-22 → DLG-20 → yazılır, rol iyimser → TST-46',
      () async {
        seedContext();
        final container = await _container();
        feedbackFake()
          ..nextSheetResult = ClubRole.board
          ..dialogResults[DialogId.dlg20] = true;
        await _viewModel(container).changeRole();
        expect(management().callsTo('changeRole'), hasLength(1));
        expect(_state(container).contextMembership?.role, ClubRole.board);
        expect(feedbackFake().toasts, [ToastId.tst46]);
        expect(feedbackFake().toastParams.single.role, ClubRole.board.json);
      },
    );

    test('"Üyelikten çıkar": DLG-19 → yazılır → TST-47; "Geri al" üyeliği '
        'geri getirir', () async {
      seedContext();
      final container = await _container();
      feedbackFake().dialogResults[DialogId.dlg19] = 'Kural ihlali';
      expect(await _viewModel(container).remove(), isTrue);
      final id = FirestoreIds.membership(kClubId, kUserId);
      expect(
        membershipsFake().memberships[id]?.status,
        MembershipStatus.removed,
      );
      expect(feedbackFake().toasts, [ToastId.tst47]);

      feedbackFake().tapToastAction();
      await pumpEventQueue();
      expect(management().callsTo('undoRemoval'), hasLength(1));
      expect(
        membershipsFake().memberships[id]?.status,
        MembershipStatus.active,
      );
    });

    test('yönetim kurulu bakışı: rol atayamaz; yönetim kurulu üyesini '
        'çıkaramaz → TST-X18, dialog açılmaz', () async {
      seedContext(role: ClubRole.board);
      final board = kViewerInContext.copyWith(role: ClubRole.board);
      membershipsFake().put(board);
      final container = await _container(
        session: viewerSession(memberships: [kViewerInShared, board]),
      );
      expect(_state(container).canAssignRoles, isFalse);
      expect(await _viewModel(container).remove(), isFalse);
      expect(feedbackFake().dialogs, isEmpty);
      expect(feedbackFake().toasts, [ToastId.tstX18]);
      expect(management().callsTo('removeMember'), isEmpty);
    });

    test('bekleyen başvuru: kart çizilmez, e-posta okunmaz', () async {
      seedProfile();
      membershipsFake().put(
        inContext().copyWith(status: MembershipStatus.pending),
      );
      final container = await _container();
      expect(_state(container).showsManagerCard, isFalse);
      expect(_state(container).contactEmail, isNull);
      expect(membershipsFake().callsTo('readContact'), isEmpty);
    });
  });
  group('CLB-07 · UserProfileViewModel · süper admin bakışı (T-41)', () {
    const email = 'yigit.kilic@ogr.gumushane.edu.tr';

    void seedAccount() => usersFake().accounts[kUserId] = UserAccountModel(
      email: email,
      emailLower: email,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

    test('kulüp bağlamı olmadan: hesap e-postası (`getPrivateAccount`), '
        'e-posta kartı; "Kopyala" → TST-08', () async {
      seedProfile(shared: false);
      seedAccount();
      final container = await _container(
        session: viewerSession(memberships: const [], isSuperAdmin: true),
        clubId: null,
      );
      final provider = profileProvider(clubId: null);
      final state = container.read(provider);
      expect(state.isViewerSuperAdmin, isTrue);
      expect(state.isHiddenByPrivacy, isFalse);
      expect(state.showsManagerCard, isFalse);
      expect(state.showsContactCard, isTrue);
      expect(state.contactEmail, email);
      expect(usersFake().callsTo('getPrivateAccount').single.args, [kUserId]);

      await container.read(provider.notifier).copyEmail();
      final share = GetIt.I<ShareService>() as FakeShareService;
      expect(share.copied, [email]);
      expect(feedbackFake().toasts, [ToastId.tst08]);
    });

    test(
      'süper admin olmayan bakan hesap belgesini okumaz; kart yok',
      () async {
        seedProfile();
        seedAccount();
        final container = await _container(clubId: null);
        final state = container.read(profileProvider(clubId: null));
        expect(state.isViewerSuperAdmin, isFalse);
        expect(state.showsContactCard, isFalse);
        expect(state.contactEmail, isNull);
        expect(usersFake().callsTo('getPrivateAccount'), isEmpty);
      },
    );

    test('hesap belgesi yok: kart çizilmez', () async {
      seedProfile(shared: false);
      final container = await _container(
        session: viewerSession(memberships: const [], isSuperAdmin: true),
        clubId: null,
      );
      final state = container.read(profileProvider(clubId: null));
      expect(state.contactEmail, isNull);
      expect(state.showsContactCard, isFalse);
    });
  });
}

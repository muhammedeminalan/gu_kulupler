// T-11 · ProjectDependency: GetIt kayıtları, emülatörde yerel Remote Config /
// çökme servisleri (W-53), reset (D-04; PLAN §4.4).
// T-12 · kimlik ve profil repository'leri: kayıt, kayıtlı servislere bağlılık
// ve `ProjectDependencyMixin` getter'ları.
// T-14 · izin ve görsel seçici servisleri; profil fotoğrafı yüklemesinin
// kayıtlı Storage servisine bağlılığı.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/connectivity/connectivity_gate.dart';
import 'package:gu_kulupler/core/di/project_dependency.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/env/app_environment.dart';
import 'package:gu_kulupler/core/env/emulator_services.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/navigation/navigator_keys.dart';
import 'package:gu_kulupler/product/service/app_info_service.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';
import 'package:gu_kulupler/product/service/file_service.dart';
import 'package:gu_kulupler/product/service/image_picker_service.dart';
import 'package:gu_kulupler/product/service/local_reminder_service.dart';
import 'package:gu_kulupler/product/service/permission_service.dart';
import 'package:gu_kulupler/product/service/share_service.dart';
import 'package:gu_kulupler/product/service/url_launcher_service.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../fakes/fake_app_info_service.dart';
import '../../fakes/fake_app_preferences_store.dart';
import '../../fakes/fake_auth_service.dart';
import '../../fakes/fake_connectivity_service.dart';
import '../../fakes/fake_crash_service.dart';
import '../../fakes/fake_firestore_service.dart';
import '../../fakes/fake_image_picker_service.dart';
import '../../fakes/fake_permission_service.dart';
import '../../fakes/fake_remote_config_service.dart';
import '../../fakes/fake_share_service.dart';
import '../../fakes/fake_storage_service.dart';
import '../../fakes/fake_url_launcher_service.dart';
import '../../helpers/design_files.dart';
import '../../helpers/fake_app_clock.dart';

final class _Consumer with ProjectDependencyMixin {}

void main() {
  late GlobalKey<NavigatorState> navigatorKey;
  late GuToastController toastController;
  late FakeAuthService auth;
  late FakeFirestoreService firestore;
  late FakeStorageService storage;
  late FakeConnectivityService connectivity;
  late FakeAppInfoService appInfo;
  late FakeAppPreferencesStore prefs;

  /// Platform kanalı ve Firebase uygulaması isteyen her şey fake'tir; Remote
  /// Config ve çökme servisi **verilmez** (ortam seçimi sınanır).
  ProjectDependencyOverrides platformFakes({
    RemoteConfigService? remoteConfigService,
    CrashService? crashService,
    AppClock? appClock,
  }) => ProjectDependencyOverrides(
    authService: auth,
    firestoreService: firestore,
    storageService: storage,
    connectivityService: connectivity,
    appInfoService: appInfo,
    appPreferencesStore: prefs,
    remoteConfigService: remoteConfigService,
    crashService: crashService,
    appClock: appClock,
  );

  setUp(() async {
    await GetIt.I.reset();
    addTearDown(GetIt.I.reset);
    navigatorKey = GlobalKey<NavigatorState>();
    toastController = GuToastController();
    addTearDown(toastController.dispose);
    auth = FakeAuthService();
    firestore = FakeFirestoreService();
    storage = FakeStorageService();
    connectivity = FakeConnectivityService();
    appInfo = FakeAppInfoService();
    prefs = FakeAppPreferencesStore(loaded: false);
  });

  group('T-11 · ProjectDependency.setup', () {
    test('tüm servisleri kaydeder', () async {
      await ProjectDependency.setup(
        navigatorKey: navigatorKey,
        toastController: toastController,
        isEmulator: true,
        overrides: platformFakes(),
      );

      expect(GetIt.I<AuthService>(), same(auth));
      expect(GetIt.I<FirestoreService>(), same(firestore));
      expect(GetIt.I<StorageService>(), same(storage));
      expect(GetIt.I<RemoteConfigService>(), isA<RemoteConfigService>());
      expect(GetIt.I<CrashService>(), isA<CrashService>());
      expect(GetIt.I<AppClock>(), isA<SystemAppClock>());
      expect(GetIt.I<GuToastController>(), same(toastController));
      expect(GetIt.I<FeedbackService>(), isA<AppFeedbackService>());
      expect(GetIt.I<ConnectivityService>(), same(connectivity));
      expect(GetIt.I<ConnectivityGate>(), isA<ConnectivityGate>());
      expect(GetIt.I<AppInfoService>(), same(appInfo));
      expect(GetIt.I<AppPreferencesStore>(), same(prefs));
      // T-13 · verilmediyse gerçek uygulama (platform çağrısı kurulumda yok).
      expect(GetIt.I<UrlLauncherService>(), isA<DeviceUrlLauncherService>());
      // T-16 · sistem paylaşım sayfası (aynı kural).
      expect(GetIt.I<ShareService>(), isA<DeviceShareService>());
      // T-14 · izinler ve görsel seçimi (aynı kural).
      expect(GetIt.I<PermissionService>(), isA<DevicePermissionService>());
      expect(GetIt.I<ImagePickerService>(), isA<DeviceImagePickerService>());
      // T-23 · geçici dosya ve yerel hatırlatıcı (aynı kural).
      expect(GetIt.I<FileService>(), isA<DeviceFileService>());
      expect(
        GetIt.I<LocalReminderService>(),
        isA<FlutterLocalReminderService>(),
      );
    });

    test('PermissionService ve ImagePickerService verilen örneklerle '
        'kaydedilir; mixin onları görür (T-14)', () async {
      final permissions = FakePermissionService();
      final picker = FakeImagePickerService();
      await ProjectDependency.setup(
        navigatorKey: navigatorKey,
        toastController: toastController,
        isEmulator: true,
        overrides: ProjectDependencyOverrides(
          authService: auth,
          firestoreService: firestore,
          storageService: storage,
          connectivityService: connectivity,
          appInfoService: appInfo,
          appPreferencesStore: prefs,
          permissionService: permissions,
          imagePickerService: picker,
        ),
      );

      expect(GetIt.I<PermissionService>(), same(permissions));
      expect(GetIt.I<ImagePickerService>(), same(picker));
      expect(_Consumer().permissionService, same(permissions));
      expect(_Consumer().imagePickerService, same(picker));
    });

    test('UserRepository profil fotoğrafını kayıtlı StorageService ile '
        "yükler: dosya users/{uid}/ altına gider, yol Firestore'a yazılır "
        '(T-14)', () async {
      await ProjectDependency.setup(
        navigatorKey: navigatorKey,
        toastController: toastController,
        isEmulator: true,
        overrides: platformFakes(),
      );
      const uid = 'u_ayse';
      await firestore.set(firestore.doc(FirestoreCollections.users, uid), {
        ...const UserModel(
          name: 'Ayşe Işık',
          nameLower: 'ayşe ışık',
          avatarSeed: uid,
          department: 'd01',
          year: YearLevel.first,
          interests: ['i01'],
          profileComplete: true,
        ).toJson(),
        ...BaseFieldsPayload.create(),
      });

      final result = await GetIt.I<UserRepository>().updateAvatar(
        uid,
        bytes: kFakeJpeg.bytes,
        contentType: kFakeJpeg.contentType,
      );

      final path = result.dataOrNull;
      expect(path, isNotNull, reason: '$result');
      expect(StoragePaths.isUserAvatar(path!, uid), isTrue);
      expect(storage.uploads.keys, [path]);
      final user = (await GetIt.I<UserRepository>().getUser(uid)).dataOrNull!;
      expect(user.avatarPath, path);

      // Aynı saniyede ikinci yükleme: ad rastgele kısmıyla ayrışır (üzerine
      // yazma olmaz) — kaynak kriptografiktir.
      final second = await GetIt.I<UserRepository>().updateAvatar(
        uid,
        bytes: kFakeJpeg.bytes,
        contentType: kFakeJpeg.contentType,
      );
      expect(second.dataOrNull, isNot(path));
      expect(storage.uploads.keys, [path, second.dataOrNull]);
      expect(
        readText('lib/core/di/project_dependency.dart'),
        contains('Random.secure()'),
      );
    });

    test('UrlLauncherService verilen örnekle kaydedilir; mixin onu görür '
        '(T-13)', () async {
      final launcher = FakeUrlLauncherService();
      await ProjectDependency.setup(
        navigatorKey: navigatorKey,
        toastController: toastController,
        isEmulator: true,
        overrides: ProjectDependencyOverrides(
          authService: auth,
          firestoreService: firestore,
          storageService: storage,
          connectivityService: connectivity,
          appInfoService: appInfo,
          appPreferencesStore: prefs,
          urlLauncherService: launcher,
        ),
      );

      expect(GetIt.I<UrlLauncherService>(), same(launcher));
      expect(_Consumer().urlLauncherService, same(launcher));
    });

    test('ShareService verilen örnekle kaydedilir; mixin onu görür '
        '(T-16)', () async {
      final share = FakeShareService();
      await ProjectDependency.setup(
        navigatorKey: navigatorKey,
        toastController: toastController,
        isEmulator: true,
        overrides: ProjectDependencyOverrides(
          authService: auth,
          firestoreService: firestore,
          storageService: storage,
          connectivityService: connectivity,
          appInfoService: appInfo,
          appPreferencesStore: prefs,
          shareService: share,
        ),
      );

      expect(GetIt.I<ShareService>(), same(share));
      expect(_Consumer().shareService, same(share));
    });

    test('FeedbackService verilen kök gezgine ve toast denetleyicisine '
        'bağlanır (CD-128)', () async {
      await ProjectDependency.setup(
        navigatorKey: navigatorKey,
        toastController: toastController,
        isEmulator: true,
        overrides: platformFakes(),
      );
      final feedback = GetIt.I<FeedbackService>() as AppFeedbackService;
      expect(feedback.navigatorKey, same(navigatorKey));
      expect(feedback.toastController, same(toastController));
    });

    test('gezgin verilmezse FeedbackService router’ın kök gezginine '
        '(rootNavigatorKey) bağlanır', () async {
      await ProjectDependency.setup(
        toastController: toastController,
        isEmulator: true,
        overrides: platformFakes(),
      );
      final feedback = GetIt.I<FeedbackService>() as AppFeedbackService;
      expect(feedback.navigatorKey, same(rootNavigatorKey));
    });

    test("ConnectivityGate kayıtlı ConnectivityService'i okur", () async {
      await ProjectDependency.setup(
        navigatorKey: navigatorKey,
        toastController: toastController,
        isEmulator: true,
        overrides: platformFakes(),
      );
      final gate = GetIt.I<ConnectivityGate>();
      expect(gate.requireOnline().isSuccess, isTrue);
      connectivity.isOffline = true;
      expect(gate.requireOnline().errorOrNull, FirestoreError.offline);
    });

    test(
      'tercih deposu yalnızca kaydedilir; yüklemeyi açılış sırası yapar',
      () async {
        await ProjectDependency.setup(
          navigatorKey: navigatorKey,
          toastController: toastController,
          isEmulator: true,
          overrides: platformFakes(),
        );
        expect(prefs.callsTo('load'), isEmpty);
        expect(GetIt.I<AppPreferencesStore>().isLoaded, isFalse);
      },
    );

    test(
      "ProjectDependencyMixin getter'ları kayıtlı örnekleri döndürür",
      () async {
        final clock = FakeAppClock(DateTime.utc(2026, 10, 12));
        await ProjectDependency.setup(
          navigatorKey: navigatorKey,
          toastController: toastController,
          isEmulator: true,
          overrides: platformFakes(appClock: clock),
        );
        final consumer = _Consumer();
        expect(consumer.authService, same(auth));
        expect(consumer.feedback, same(GetIt.I<FeedbackService>()));
        expect(consumer.appClock, same(clock));
        expect(consumer.connectivityGate, same(GetIt.I<ConnectivityGate>()));
        expect(consumer.appPreferencesStore, same(prefs));
        expect(consumer.connectivityService, same(connectivity));
        expect(consumer.appInfoService, same(appInfo));
      },
    );

    test('ikinci setup (reset olmadan) hatadır: çift kayıt sessizce '
        'geçmez', () async {
      await ProjectDependency.setup(
        navigatorKey: navigatorKey,
        toastController: toastController,
        isEmulator: true,
        overrides: platformFakes(),
      );
      await expectLater(
        ProjectDependency.setup(
          navigatorKey: navigatorKey,
          toastController: toastController,
          isEmulator: true,
          overrides: platformFakes(),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('T-12 · ProjectDependency · repository kayıtları', () {
    test('Auth / User / Settings repository gerçek uygulamalarıyla '
        'kaydedilir; mixin getter’ları aynı örnekleri döndürür', () async {
      await ProjectDependency.setup(
        navigatorKey: navigatorKey,
        toastController: toastController,
        isEmulator: true,
        overrides: platformFakes(),
      );
      expect(GetIt.I<AuthRepository>(), isA<FirebaseAuthRepository>());
      expect(GetIt.I<UserRepository>(), isA<FirebaseUserRepository>());
      expect(GetIt.I<SettingsRepository>(), isA<FirebaseSettingsRepository>());

      final consumer = _Consumer();
      expect(consumer.authRepository, same(GetIt.I<AuthRepository>()));
      expect(consumer.userRepository, same(GetIt.I<UserRepository>()));
      expect(consumer.settingsRepository, same(GetIt.I<SettingsRepository>()));
    });

    test(
      'repository’ler kayıtlı servislerin ve saatin üstünde çalışır',
      () async {
        final clock = FakeAppClock(DateTime.utc(2026, 10, 12));
        await ProjectDependency.setup(
          navigatorKey: navigatorKey,
          toastController: toastController,
          isEmulator: true,
          overrides: platformFakes(appClock: clock),
        );
        const email = 'ayse@ogr.gumushane.edu.tr';
        final consumer = _Consumer();

        // AuthRepository → kayıtlı AuthService + AppClock (bekleme saati).
        final registered = await consumer.authRepository.register(
          email: email,
          password: 'Parola123',
          name: 'Ayşe Yılmaz',
        );
        expect(auth.callsTo('register'), hasLength(1));
        // CD-134: ad kayıtlı AuthService'e görünen ad olarak gider.
        expect(registered.dataOrNull!.displayName, 'Ayşe Yılmaz');
        expect(consumer.authRepository.currentUser, auth.currentUser);
        expect(
          consumer.authRepository.resendCooldownRemaining,
          Limits.verificationResendCooldown,
        );
        clock.advance(Limits.verificationResendCooldown);
        expect(consumer.authRepository.resendCooldownRemaining, isNull);

        // User / Settings repository → kayıtlı FirestoreService.
        final uid = registered.dataOrNull!.uid;
        final created = await consumer.userRepository.createProfile(
          uid: uid,
          email: email,
          name: 'Ayşe Işık',
          nameLower: 'ayşe ışık',
          avatarSeed: uid,
        );
        expect(created.isSuccess, isTrue);
        expect((await firestore.db.doc('users/$uid').get()).exists, isTrue);
        // Profil batch'i ayar belgesini de yazdı; okuma aynı veritabanından.
        final settings = await consumer.settingsRepository.getSettings(uid);
        expect(
          settings.dataOrNull?.copyWith(clearUpdatedAt: true),
          UserSettingsModel.defaults(uid),
        );
      },
    );

    test('reset repository kayıtlarını da siler', () async {
      await ProjectDependency.setup(
        navigatorKey: navigatorKey,
        toastController: toastController,
        isEmulator: true,
        overrides: platformFakes(),
      );
      await ProjectDependency.reset();
      expect(GetIt.I.isRegistered<AuthRepository>(), isFalse);
      expect(GetIt.I.isRegistered<UserRepository>(), isFalse);
      expect(GetIt.I.isRegistered<SettingsRepository>(), isFalse);
      expect(() => _Consumer().authRepository, throwsStateError);
    });
  });

  group('T-15 · ProjectDependency · kulüp ve üyelik kayıtları', () {
    test('beş repository gerçek uygulamalarıyla, bildirim dağıtıcısı '
        'istemci dağıtıcısı olarak kaydedilir (T-25, W-62); mixin '
        'getter’ları aynı örnekleri döndürür', () async {
      await ProjectDependency.setup(
        navigatorKey: navigatorKey,
        toastController: toastController,
        isEmulator: true,
        overrides: platformFakes(),
      );
      expect(GetIt.I<ClubRepository>(), isA<FirebaseClubRepository>());
      expect(
        GetIt.I<MembershipRepository>(),
        isA<FirebaseMembershipRepository>(),
      );
      expect(GetIt.I<ReportRepository>(), isA<FirebaseReportRepository>());
      expect(GetIt.I<BlockRepository>(), isA<FirebaseBlockRepository>());
      expect(GetIt.I<ActivityRepository>(), isA<FirebaseActivityRepository>());
      expect(GetIt.I<NotificationDispatcher>(), isA<ClientFanOutDispatcher>());

      final consumer = _Consumer();
      expect(consumer.clubRepository, same(GetIt.I<ClubRepository>()));
      expect(
        consumer.membershipRepository,
        same(GetIt.I<MembershipRepository>()),
      );
      expect(consumer.reportRepository, same(GetIt.I<ReportRepository>()));
      expect(consumer.blockRepository, same(GetIt.I<BlockRepository>()));
      expect(consumer.activityRepository, same(GetIt.I<ActivityRepository>()));
    });

    test('üyelik geçişi kayıtlı FirestoreService üzerinde üyelik + sayaç + '
        'günlüğü birlikte yazar; günlük kayıtlı ActivityRepository’den '
        'okunur', () async {
      await ProjectDependency.setup(
        navigatorKey: navigatorKey,
        toastController: toastController,
        isEmulator: true,
        overrides: platformFakes(
          appClock: FakeAppClock(DateTime.utc(2026, 10, 13)),
        ),
      );
      const applicant = UserModel(
        uid: 'u_ayse',
        name: 'Ayşe Işık',
        nameLower: 'ayşe ışık',
        avatarSeed: 'u_ayse',
        profileComplete: true,
      );
      // Anlık görüntü işlem içinde güncel kullanıcı belgesinden okunur.
      await firestore.db.doc('users/u_ayse').set(applicant.toJson());
      await firestore.db
          .doc('clubs/c01')
          .set(
            const ClubModel(
              name: 'Satranç Kulübü',
              nameLower: 'satranç kulübü',
              categoryId: 'k01',
              iconName: 'cpu',
              palette: ClubPalette.red,
              pattern: ClubPattern.dots,
              founded: 2015,
              presidentId: 'u_president',
              memberCount: 4,
              approvalRequired: false,
            ).toJson(),
          );
      final consumer = _Consumer();

      final joined = await consumer.membershipRepository.joinInstant(
        clubId: 'c01',
        applicant: applicant,
        email: 'ayse@ogr.gumushane.edu.tr',
      );

      expect(joined.dataOrNull?.status, MembershipStatus.active);
      final club = await consumer.clubRepository.getClub('c01');
      expect(club.dataOrNull?.memberCount, 5);
      final mine = await consumer.membershipRepository.listMine('u_ayse');
      expect(mine.dataOrNull?.single.clubId, 'c01');
      final log = await consumer.activityRepository.listActivity(
        'c01',
        const PageRequest(),
      );
      expect(log.dataOrNull?.items.single.kind, ActivityKind.memberJoined);
    });
  });

  group('T-25 · ProjectDependency · bildirim kayıtları', () {
    test('gelen kutusu repository’si gerçek uygulamasıyla kaydedilir; mixin '
        'getter’ı aynı örneği döndürür', () async {
      await ProjectDependency.setup(
        navigatorKey: navigatorKey,
        toastController: toastController,
        isEmulator: true,
        overrides: platformFakes(),
      );
      expect(
        GetIt.I<NotificationRepository>(),
        isA<FirebaseNotificationRepository>(),
      );
      expect(
        _Consumer().notificationRepository,
        same(GetIt.I<NotificationRepository>()),
      );
    });

    test('başvuru kayıtlı dağıtıcıyla etkin yöneticilere application_received '
        'yazar (danışmana ve başvurana değil); belge kayıtlı repository’nin '
        'gelen kutusunda görünür', () async {
      await ProjectDependency.setup(
        navigatorKey: navigatorKey,
        toastController: toastController,
        isEmulator: true,
        overrides: platformFakes(
          appClock: FakeAppClock(DateTime.utc(2026, 10, 13)),
        ),
      );
      const applicant = UserModel(
        uid: 'u_ayse',
        name: 'Ayşe Işık',
        nameLower: 'ayşe ışık',
        avatarSeed: 'u_ayse',
        profileComplete: true,
      );
      await firestore.db.doc('users/u_ayse').set(applicant.toJson());
      await firestore.db
          .doc('clubs/c01')
          .set(
            const ClubModel(
              name: 'Satranç Kulübü',
              nameLower: 'satranç kulübü',
              categoryId: 'k01',
              iconName: 'cpu',
              palette: ClubPalette.red,
              pattern: ClubPattern.dots,
              founded: 2015,
              presidentId: 'u_president',
              memberCount: 3,
            ).toJson(),
          );
      for (final (uid, role) in [
        ('u_president', ClubRole.president),
        ('u_board', ClubRole.board),
        ('u_advisor', ClubRole.advisor),
      ]) {
        await firestore.db
            .doc('memberships/c01_$uid')
            .set(
              MembershipModel(
                clubId: 'c01',
                userId: uid,
                applicant: MembershipApplicantModel(
                  name: 'Yönetici',
                  avatarSeed: uid,
                ),
                status: MembershipStatus.active,
                role: role,
              ).toJson(),
            );
      }
      final consumer = _Consumer();

      final applied = await consumer.membershipRepository.apply(
        clubId: 'c01',
        applicant: applicant,
        email: 'ayse@ogr.gumushane.edu.tr',
        note: '',
      );

      expect(applied.dataOrNull?.status, MembershipStatus.pending);
      final written = await firestore.db.collection('notifications').get();
      expect(
        written.docs.map((doc) => doc.data()['userId']).toSet(),
        {'u_president', 'u_board'},
      );
      expect(
        written.docs.map((doc) => doc.id),
        everyElement(startsWith('application_received_')),
      );
      final inbox = await consumer.notificationRepository
          .watchInbox('u_board')
          .first;
      expect(
        inbox.dataOrNull?.single.type,
        NotificationType.applicationReceived,
      );
      expect(inbox.dataOrNull?.single.refs.applicantId, 'u_ayse');
    });
  });

  group('T-19 · ProjectDependency · akış kayıtları', () {
    test('dört repository gerçek uygulamalarıyla kaydedilir; mixin '
        'getter’ları aynı örnekleri döndürür', () async {
      await ProjectDependency.setup(
        navigatorKey: navigatorKey,
        toastController: toastController,
        isEmulator: true,
        overrides: platformFakes(),
      );
      expect(GetIt.I<PostRepository>(), isA<FirebasePostRepository>());
      expect(GetIt.I<CommentRepository>(), isA<FirebaseCommentRepository>());
      expect(
        GetIt.I<SavedPostRepository>(),
        isA<FirebaseSavedPostRepository>(),
      );
      expect(
        GetIt.I<AnnouncementCounterRepository>(),
        isA<FirebaseAnnouncementCounterRepository>(),
      );

      final consumer = _Consumer();
      expect(consumer.postRepository, same(GetIt.I<PostRepository>()));
      expect(consumer.commentRepository, same(GetIt.I<CommentRepository>()));
      expect(
        consumer.savedPostRepository,
        same(GetIt.I<SavedPostRepository>()),
      );
      expect(
        consumer.announcementCounterRepository,
        same(GetIt.I<AnnouncementCounterRepository>()),
      );
    });

    test('bildirimli duyuru kayıtlı FirestoreService üzerinde gönderi + '
        'günlük + günün sayacını birlikte yazar; yorum gönderinin sayacını '
        'artırır; sayaç ve günlük kayıtlı repository’lerden okunur', () async {
      await ProjectDependency.setup(
        navigatorKey: navigatorKey,
        toastController: toastController,
        isEmulator: true,
        overrides: platformFakes(
          appClock: FakeAppClock(DateTime.utc(2026, 10, 13, 9)),
        ),
      );
      final consumer = _Consumer();

      final published = await consumer.postRepository.create(
        const PostDraft(
          type: PostType.announcement,
          title: 'Genel kurul',
          text: 'Cuma 14.00.',
          pushSent: true,
        ),
        authorId: 'u_president',
        clubId: 'c01',
        postId: 'p_new',
      );
      final comment = await consumer.commentRepository.add(
        postId: 'p_new',
        clubId: 'c01',
        authorId: 'u_ayse',
        text: 'Orada olacağım.',
      );
      await consumer.savedPostRepository.save(
        userId: 'u_ayse',
        postId: 'p_new',
        clubId: 'c01',
      );

      expect(published.dataOrNull?.pushSent, isTrue);
      final counter = await consumer.announcementCounterRepository.getToday(
        'c01',
      );
      expect(
        (counter.dataOrNull?.count, counter.dataOrNull?.lastPostRef),
        (1, 'posts/p_new'),
      );
      final post = await consumer.postRepository.getPost('p_new');
      expect(
        (post.dataOrNull?.commentCount, post.dataOrNull?.lastCommentRef),
        (1, 'comments/${comment.dataOrNull?.id}'),
      );
      final log = await consumer.activityRepository.listActivity(
        'c01',
        const PageRequest(),
      );
      expect(log.dataOrNull?.items.single.kind, ActivityKind.announcement);
      final saved = await consumer.savedPostRepository.isSaved(
        userId: 'u_ayse',
        postId: 'p_new',
      );
      expect(saved.dataOrNull, isTrue);
    });
  });

  group('T-28 · ProjectDependency · destek talepleri', () {
    test('repository gerçek uygulamasıyla kaydedilir; mixin getter’ı aynı '
        'örneği döndürür', () async {
      await ProjectDependency.setup(
        navigatorKey: navigatorKey,
        toastController: toastController,
        isEmulator: true,
        overrides: platformFakes(),
      );
      expect(GetIt.I<SupportRepository>(), isA<FirebaseSupportRepository>());
      expect(
        _Consumer().supportRepository,
        same(GetIt.I<SupportRepository>()),
      );
    });
  });

  group('T-29 · ProjectDependency · hesap silme', () {
    test('repository gerçek uygulamasıyla kaydedilir; mixin getter’ı aynı '
        'örneği döndürür', () async {
      await ProjectDependency.setup(
        navigatorKey: navigatorKey,
        toastController: toastController,
        isEmulator: true,
        overrides: platformFakes(),
      );
      expect(
        GetIt.I<AccountDeletionRepository>(),
        isA<FirebaseAccountDeletionRepository>(),
      );
      expect(
        _Consumer().accountDeletionRepository,
        same(GetIt.I<AccountDeletionRepository>()),
      );
    });
  });

  group('T-30 · ProjectDependency · yönetim ve yoklama', () {
    test('iki repository gerçek uygulamalarıyla kaydedilir; mixin '
        'getter’ları aynı örnekleri döndürür; danışman salt okunur', () async {
      await ProjectDependency.setup(
        navigatorKey: navigatorKey,
        toastController: toastController,
        isEmulator: true,
        overrides: platformFakes(),
      );
      expect(
        GetIt.I<ManagementRepository>(),
        isA<FirebaseManagementRepository>(),
      );
      expect(
        GetIt.I<AttendanceRepository>(),
        isA<FirebaseAttendanceRepository>(),
      );

      final consumer = _Consumer();
      expect(
        consumer.managementRepository,
        same(GetIt.I<ManagementRepository>()),
      );
      expect(
        consumer.attendanceRepository,
        same(GetIt.I<AttendanceRepository>()),
      );
      // T-34 · DLG-22 tahmini: dağıtıcının kullandığı çözücü.
      expect(GetIt.I<RecipientResolver>(), isA<FirebaseRecipientResolver>());
      expect(consumer.recipientResolver, same(GetIt.I<RecipientResolver>()));
      expect(
        consumer.managementRepository.isReadOnly(ClubAccess.advisor),
        isTrue,
      );
      expect(
        consumer.managementRepository.isReadOnly(ClubAccess.manager),
        isFalse,
      );
    });
  });

  group('T-22 · ProjectDependency · etkinlik ve katılım kayıtları', () {
    test('iki repository gerçek uygulamalarıyla kaydedilir; mixin '
        'getter’ları aynı örnekleri döndürür', () async {
      await ProjectDependency.setup(
        navigatorKey: navigatorKey,
        toastController: toastController,
        isEmulator: true,
        overrides: platformFakes(),
      );
      expect(GetIt.I<EventRepository>(), isA<FirebaseEventRepository>());
      expect(GetIt.I<RsvpRepository>(), isA<FirebaseRsvpRepository>());

      final consumer = _Consumer();
      expect(consumer.eventRepository, same(GetIt.I<EventRepository>()));
      expect(consumer.rsvpRepository, same(GetIt.I<RsvpRepository>()));
    });

    test('yayın kayıtlı FirestoreService üzerinde etkinlik + günlüğü birlikte '
        'yazar; katılım etkinliğin sayacını aynı işlemde artırır, vazgeçme '
        'azaltır; bilet kodu kriptografik üreticinin desenindedir', () async {
      final now = DateTime.utc(2026, 10, 13, 9);
      await ProjectDependency.setup(
        navigatorKey: navigatorKey,
        toastController: toastController,
        isEmulator: true,
        overrides: platformFakes(appClock: FakeAppClock(now)),
      );
      final consumer = _Consumer();

      final created = await consumer.eventRepository.create(
        EventDraft(
          title: 'Flutter atölyesi',
          type: EventType.training,
          startsAt: now.add(const Duration(days: 3)),
          endsAt: now.add(const Duration(days: 3, hours: 2)),
          capacity: 1,
          coverPalette: ClubPalette.red,
          coverPattern: ClubPattern.dots,
        ),
        clubId: 'c01',
        createdBy: 'u_president',
        status: EventStatus.published,
      );
      final eventId = created.dataOrNull!.id;
      final first = await consumer.rsvpRepository.join(
        eventId: eventId,
        clubId: 'c01',
        userId: 'u_ayse',
        reminder: ReminderOption.oneHour,
      );
      final second = await consumer.rsvpRepository.join(
        eventId: eventId,
        clubId: 'c01',
        userId: 'u_can',
        reminder: ReminderOption.none,
      );

      expect(first.dataOrNull?.status, RsvpStatus.going);
      expect(
        first.dataOrNull?.ticketCode,
        matches(FirestoreIds.ticketCodePattern),
      );
      expect(second.dataOrNull?.status, RsvpStatus.waitlist);
      var event = (await consumer.eventRepository.getEvent(eventId)).dataOrNull;
      expect((event?.goingCount, event?.waitlistCount), (1, 1));

      await consumer.rsvpRepository.cancel(eventId: eventId, userId: 'u_ayse');
      event = (await consumer.eventRepository.getEvent(eventId)).dataOrNull;
      // Mod C: boşalan yere kimse otomatik alınmaz.
      expect((event?.goingCount, event?.waitlistCount), (0, 1));
      final log = await consumer.activityRepository.listActivity(
        'c01',
        const PageRequest(),
      );
      expect(log.dataOrNull?.items.single.kind, ActivityKind.eventPublished);
    });
  });

  group('T-11 · ProjectDependency · emülatör ortamı (W-53)', () {
    test('emülatörde Remote Config ve çökme servisi yereldir: Firebase '
        "SDK'sına dokunulmaz", () async {
      // Testte Firebase uygulaması yoktur: SDK örneği istenseydi setup
      // fırlatırdı.
      await ProjectDependency.setup(
        navigatorKey: navigatorKey,
        toastController: toastController,
        isEmulator: true,
        overrides: platformFakes(),
      );
      expect(
        GetIt.I<RemoteConfigService>(),
        isA<EmulatorRemoteConfigService>(),
      );
      expect(GetIt.I<CrashService>(), isA<EmulatorCrashService>());
    });

    test(
      'üretim ortamında gerçek SDK istenir (testte Firebase uygulaması '
      'olmadığından kurulum durur — sessizce yerel servise düşmez)',
      () async {
        await expectLater(
          ProjectDependency.setup(
            navigatorKey: navigatorKey,
            toastController: toastController,
            // Varsayılan derleme sabitidir (emülatör derlemesinde true);
            // test ortamdan bağımsız kalsın diye açık verilir.
            // ignore: avoid_redundant_argument_values
            isEmulator: false,
            overrides: platformFakes(),
          ),
          throwsA(anything),
        );
        expect(GetIt.I.isRegistered<RemoteConfigService>(), isFalse);
        expect(GetIt.I.isRegistered<CrashService>(), isFalse);
      },
    );

    test('verilen servisler ortamdan bağımsız olarak kullanılır', () async {
      final config = FakeRemoteConfigService();
      final crash = FakeCrashService();
      await ProjectDependency.setup(
        navigatorKey: navigatorKey,
        toastController: toastController,
        // Varsayılan derleme sabitidir; ortamdan bağımsız kalsın diye açık.
        // ignore: avoid_redundant_argument_values
        isEmulator: false,
        overrides: platformFakes(
          remoteConfigService: config,
          crashService: crash,
        ),
      );
      expect(GetIt.I<RemoteConfigService>(), same(config));
      expect(GetIt.I<CrashService>(), same(crash));
    });

    test('varsayılan ortam bayrağı derleme sabitidir; test koşusunda '
        'emülatör değildir', () {
      expect(AppEnvironment.isEmulator, isFalse);
    });

    test(
      'Auth / Firestore / Storage örnekleri yalnızca AppEnvironment '
      'üzerinden alınır; kurulmamış ortamda setup StateError ile durur',
      () async {
        final source = readText('lib/core/di/project_dependency.dart');
        expect(source, contains('FirebaseAuthService(AppEnvironment.auth)'));
        expect(
          source,
          contains('FirebaseFirestoreService(AppEnvironment.firestore)'),
        );
        expect(
          source,
          contains('FirebaseStorageService(AppEnvironment.storage)'),
        );

        // Ortam kurulmadı (configure çağrılmadı) → gerçek uygulamaya düşmez.
        await expectLater(
          ProjectDependency.setup(
            navigatorKey: navigatorKey,
            toastController: toastController,
            isEmulator: true,
            overrides: ProjectDependencyOverrides(
              connectivityService: connectivity,
              appInfoService: appInfo,
              appPreferencesStore: prefs,
            ),
          ),
          throwsStateError,
        );
        // Yarım kayıt kalmaz.
        expect(GetIt.I.isRegistered<CrashService>(), isFalse);
        expect(GetIt.I.isRegistered<ConnectivityService>(), isFalse);
      },
    );
  });

  group('T-11 · ProjectDependency.reset', () {
    test('tüm kayıtları siler; ardından yeniden kurulabilir', () async {
      await ProjectDependency.setup(
        navigatorKey: navigatorKey,
        toastController: toastController,
        isEmulator: true,
        overrides: platformFakes(),
      );
      await ProjectDependency.reset();

      expect(GetIt.I.isRegistered<AuthService>(), isFalse);
      expect(GetIt.I.isRegistered<FeedbackService>(), isFalse);
      expect(GetIt.I.isRegistered<ConnectivityGate>(), isFalse);
      expect(GetIt.I.isRegistered<AppPreferencesStore>(), isFalse);
      expect(() => _Consumer().authService, throwsStateError);

      await ProjectDependency.setup(
        navigatorKey: navigatorKey,
        toastController: toastController,
        isEmulator: true,
        overrides: platformFakes(),
      );
      expect(GetIt.I<AuthService>(), same(auth));
    });
  });
}

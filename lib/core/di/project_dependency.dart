import 'dart:async';
import 'dart:math';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/connectivity/connectivity_gate.dart';
import 'package:gu_kulupler/core/env/app_environment.dart';
import 'package:gu_kulupler/core/env/emulator_services.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/navigation/navigator_keys.dart';
import 'package:gu_kulupler/product/service/app_info_service.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';
import 'package:gu_kulupler/product/service/file_service.dart';
import 'package:gu_kulupler/product/service/image_picker_service.dart';
import 'package:gu_kulupler/product/service/local_reminder_service.dart';
import 'package:gu_kulupler/product/service/permission_service.dart';
import 'package:gu_kulupler/product/service/qr_scanner_service.dart';
import 'package:gu_kulupler/product/service/share_service.dart';
import 'package:gu_kulupler/product/service/url_launcher_service.dart';
import 'package:gu_ui/gu_ui.dart';

/// [ProjectDependency.setup]'ın gerçek uygulama yerine kullanacağı örnekler.
///
/// Verilmeyen her servis gerçek uygulamasıyla kurulur. Yalnızca testte ve
/// platform kanalı olmayan ortamlarda doldurulur.
final class ProjectDependencyOverrides {
  /// Hiçbir şeyi değiştirmeyen boş küme.
  const ProjectDependencyOverrides({
    this.authService,
    this.firestoreService,
    this.storageService,
    this.remoteConfigService,
    this.crashService,
    this.appClock,
    this.connectivityService,
    this.appInfoService,
    this.urlLauncherService,
    this.shareService,
    this.permissionService,
    this.imagePickerService,
    this.fileService,
    this.localReminderService,
    this.messagingService,
    this.qrScannerService,
    this.appPreferencesStore,
  });

  /// `AuthService` yerine.
  final AuthService? authService;

  /// `FirestoreService` yerine.
  final FirestoreService? firestoreService;

  /// `StorageService` yerine.
  final StorageService? storageService;

  /// `RemoteConfigService` yerine.
  final RemoteConfigService? remoteConfigService;

  /// `CrashService` yerine.
  final CrashService? crashService;

  /// `AppClock` yerine.
  final AppClock? appClock;

  /// `ConnectivityService` yerine.
  final ConnectivityService? connectivityService;

  /// `AppInfoService` yerine.
  final AppInfoService? appInfoService;

  /// `UrlLauncherService` yerine.
  final UrlLauncherService? urlLauncherService;

  /// `ShareService` yerine.
  final ShareService? shareService;

  /// `PermissionService` yerine.
  final PermissionService? permissionService;

  /// `ImagePickerService` yerine.
  final ImagePickerService? imagePickerService;

  /// `FileService` yerine.
  final FileService? fileService;

  /// `LocalReminderService` yerine.
  final LocalReminderService? localReminderService;

  /// `MessagingService` yerine.
  final MessagingService? messagingService;

  /// `QrScannerService` yerine.
  final QrScannerService? qrScannerService;

  /// `AppPreferencesStore` yerine.
  final AppPreferencesStore? appPreferencesStore;
}

/// GetIt kayıtları — kompozisyon kökü (D-04; PLAN §4.4, §6.2).
///
/// Bu dosya ve `project_dependency_mixin.dart` dışında servis/repository
/// örneği **kurulmaz**. ViewModel'ler `ProjectDependencyMixin` getter'larını,
/// view'lar Riverpod sağlayıcılarını kullanır.
///
/// - Auth / Firestore / Storage örnekleri yalnızca `AppEnvironment.auth` /
///   `.firestore` / `.storage` üzerinden alınır (emülatörde ikinci Firebase
///   uygulaması — CD-131). `AppEnvironment.configure()` tamamlanmadıysa
///   [setup] `StateError` ile durur; hata yakalanıp devam edilmez.
/// - **Emülatörde Remote Config, çökme raporlama ve push gerçek projeye
///   gitmez** (W-53, T-42): emülatörleri yoktur ve SDK'ları varsayılan
///   (gerçek) Firebase uygulamasını kullanır. `ENV=emulator` iken yerel
///   uygulamalar kaydedilir ([EmulatorRemoteConfigService],
///   [EmulatorCrashService], [EmulatorMessagingService]).
abstract final class ProjectDependency {
  /// Tüm servisleri kaydeder. `Firebase.initializeApp` ve
  /// `AppEnvironment.configure()` sonrasında, `runApp` öncesinde bir kez
  /// çağrılır.
  ///
  /// [toastController] kök ağaçtaki `GuToastHost` ile paylaşılır. Overlay'ler
  /// (sheet / dialog / menü) router'ın kök gezginine (`rootNavigatorKey`)
  /// itilir: alt sekme çubuğunun üstünde dururlar ve geri tuşu önce onları
  /// kapatır. [navigatorKey], [isEmulator] ve [overrides] yalnızca testte
  /// verilir.
  static Future<void> setup({
    required GuToastController toastController,
    GlobalKey<NavigatorState>? navigatorKey,
    bool isEmulator = AppEnvironment.isEmulator,
    ProjectDependencyOverrides overrides = const ProjectDependencyOverrides(),
  }) async {
    // Önce tüm örnekler kurulur, sonra kaydedilir: kurulum yarıda kesilirse
    // (ör. ortam kurulmadan çağrı) GetIt yarım kayıtla kalmaz.
    final crashService =
        overrides.crashService ??
        (isEmulator
            ? const EmulatorCrashService()
            : FirebaseCrashService(FirebaseCrashlytics.instance));
    final remoteConfigService =
        overrides.remoteConfigService ??
        (isEmulator
            ? const EmulatorRemoteConfigService()
            : FirebaseRemoteConfigService(FirebaseRemoteConfig.instance));
    // Beklenmeyen veri / altyapı hataları (ayrıştırma, eksik indeks, kota,
    // program hatası) Crashlytics'e `nonFatal` gider (T-44 · D2-03); beklenen
    // hatalar (yetki, yok, çevrimdışı, zaman aşımı) yalnızca günlüktedir.
    void reportUnexpected(Object error, StackTrace stack, String reason) =>
        unawaited(
          crashService.recordError(error, stack, reason: reason),
        );
    // Firebase servisleri: örnekler yalnızca AppEnvironment üzerinden.
    final authService =
        overrides.authService ?? FirebaseAuthService(AppEnvironment.auth);
    final firestoreService =
        overrides.firestoreService ??
        FirebaseFirestoreService(
          AppEnvironment.firestore,
          onUnexpected: reportUnexpected,
        );
    final storageService =
        overrides.storageService ??
        FirebaseStorageService(AppEnvironment.storage);
    // Repository'ler (T-12): servislerin üstünde alan kuralları. Giriş kilidi
    // ve yeniden gönderme beklemesi bu tek örnekte (bellekte) yaşar.
    final appClock = overrides.appClock ?? const SystemAppClock();
    // T-44 · D3-01 · nadir değişen okumaların bellek içi önbelleği (kulüp
    // listesi / belgesi, herkese açık profil): tek örnek iki repository'de;
    // kendi yazımı (servis yazım kancası) ve oturum değişimi girdiyi atar.
    final readCaches = RepositoryReadCaches(appClock);
    final authRepository = FirebaseAuthRepository(authService, appClock);
    // Profil fotoğrafı yüklemesi repository metodudur (T-14): Storage servisi
    // ViewModel'lere açılmaz (PLAN §6.1). Dosya adının rastgele kısmı
    // kriptografik kaynaktan gelir: ad tahmin edilemez, üzerine yazma olmaz.
    final userRepository = FirebaseUserRepository(
      firestoreService,
      storageService,
      appClock,
      Random.secure(),
      cache: readCaches,
    );
    final settingsRepository = FirebaseSettingsRepository(firestoreService);
    // T-25 · bildirimler (W-62): istemci kendi yazar
    // (`ClientFanOutDispatcher`). Repository hem gelen kutusu yüzeyi hem
    // dağıtıcının yazma kapısıdır (`NotificationWriter`). T-42 (Mod F,
    // CD-165 hibrit): dağıtıcı DEĞİŞMEZ — sunucu yalnızca her yeni belgeden
    // push, `new_report` ve otomatik terfi üretir; `ServerSideDispatcher`
    // yazılmaz. Eksik kalan dağıtım günlüğe düşer (PLAN §10.5), kullanıcıya
    // gösterilmez.
    final notificationRepository = FirebaseNotificationRepository(
      firestoreService,
    );
    final recipientResolver = FirebaseRecipientResolver(
      firestoreService,
      userRepository,
    );
    final notificationDispatcher = ClientFanOutDispatcher(
      writer: notificationRepository,
      recipients: recipientResolver,
      onIssue: (type, result) =>
          reportDispatchIssue(type, result, crashService: crashService),
    );
    // T-15 · kulüp, üyelik, şikayet, engel, günlük. Günlük repository'si
    // üyelik geçişleriyle paylaşılır (kayıt asıl yazımla aynı işlemde
    // eklenir).
    final clubRepository = FirebaseClubRepository(
      firestoreService,
      cache: readCaches,
    );
    final activityRepository = FirebaseActivityRepository(firestoreService);
    final membershipRepository = FirebaseMembershipRepository(
      firestoreService,
      activityRepository,
      notificationDispatcher,
      appClock,
    );
    final reportRepository = FirebaseReportRepository(
      firestoreService,
      appClock,
    );
    final blockRepository = FirebaseBlockRepository(firestoreService);
    // T-19 · gönderi, yorum, kayıt, duyuru sayacı. Yayın işlemi günlük
    // kaydını ve (bildirimli duyuruda) günün sayacını aynı işlemde yazar:
    // gönderi repository'si kayıtlı günlük ve sayaç repository'lerini
    // paylaşır. Duyuru bildirimi burada dağıtılmaz (T-30 — PLAN §10.5).
    final announcementCounterRepository = FirebaseAnnouncementCounterRepository(
      firestoreService,
      appClock,
    );
    // T-21 · gönderi görselleri repository metoduyla yüklenir
    // (`uploadImages`); dosya adının rastgele kısmı kriptografik kaynaktan.
    final postRepository = FirebasePostRepository(
      firestoreService,
      storageService,
      activityRepository,
      announcementCounterRepository,
      appClock,
      Random.secure(),
    );
    final commentRepository = FirebaseCommentRepository(
      firestoreService,
      appClock,
    );
    final savedPostRepository = FirebaseSavedPostRepository(firestoreService);
    // T-22 · etkinlik ve katılım. Yayın / iptal günlük kaydı asıl yazımla aynı
    // işlemde yazılır (kayıtlı günlük repository'si paylaşılır); kapak
    // görseli repository metoduyla yüklenir, dosya adının ve bilet kodunun
    // rastgele kısmı kriptografik kaynaktan gelir. Bildirim dağıtımı burada
    // yapılmaz (T-30 — PLAN §10.5).
    final eventRepository = FirebaseEventRepository(
      firestoreService,
      storageService,
      activityRepository,
      appClock,
      Random.secure(),
    );
    final rsvpRepository = FirebaseRsvpRepository(
      firestoreService,
      SecureTicketCodeGenerator(),
      appClock,
    );
    // T-28 · destek talepleri. Ek talepten önce yüklenir (repository
    // metodu); talep numarası ve dosya adının rastgele kısmı kriptografik
    // kaynaktan gelir.
    final supportRepository = FirebaseSupportRepository(
      firestoreService,
      storageService,
      SecureTicketCodeGenerator(),
      appClock,
      Random.secure(),
    );
    // T-29 · hesap silme: üyelik, katılım ve etkinlik okumaları kayıtlı
    // repository'lerden; parçalar transaction / batch'tir (yeniden
    // başlatılabilir dizi — `docs/plans/T-29.md` §4).
    // T-30 · yönetim paneli: kompozisyon (üyelik, etkinlik, gönderi, yorum,
    // kulüp; ayar yazımı + günlük tek batch) ve fan-out alıcıları; yoklama /
    // terfi tek transaction (kayıt + sayaç + yan belge + terfi bildirimi).
    // T-36 · kulüp logosu / kapağı repository metoduyla yüklenir
    // (`updateClubMedia`); dosya adının rastgele kısmı kriptografik kaynaktan.
    final managementRepository = FirebaseManagementRepository(
      firestore: firestoreService,
      storage: storageService,
      clock: appClock,
      random: Random.secure(),
      memberships: membershipRepository,
      events: eventRepository,
      posts: postRepository,
      comments: commentRepository,
      clubs: clubRepository,
      activity: activityRepository,
      notifications: notificationDispatcher,
      recipients: recipientResolver,
    );
    final attendanceRepository = FirebaseAttendanceRepository(
      firestoreService,
      rsvpRepository,
      notificationDispatcher,
      appClock,
    );
    final accountDeletionRepository = FirebaseAccountDeletionRepository(
      firestoreService,
      membershipRepository,
      rsvpRepository,
      eventRepository,
      appClock,
    );
    // T-37 · süper admin (ADM-*): kompozisyon — başkan ataması / danışman
    // bağlama üyelik repository'sinde (M11 / M13; sayaç + yan belge + günlük
    // + bildirim tek işlem), şikayet çözümü gönderi / yorum gizleme +
    // `report_resolved` (kritik) ile tek batch, arama kayıtlı kullanıcı
    // repository'sinden. Yetki yalnızca Rules'ta (custom claim — D-28); kulüp
    // görselinin dosya adı kriptografik kaynaktan.
    final adminRepository = FirebaseAdminRepository(
      firestore: firestoreService,
      storage: storageService,
      auth: authService,
      clock: appClock,
      random: Random.secure(),
      memberships: membershipRepository,
      reports: FirebaseReportModeration(
        firestore: firestoreService,
        auth: authService,
        posts: postRepository,
        comments: commentRepository,
        dispatcher: notificationDispatcher,
      ),
      search: FirebaseUserSearch(
        firestore: firestoreService,
        users: userRepository,
      ),
    );
    // Cihaz servisleri (CD-08).
    final connectivityService =
        overrides.connectivityService ?? await _startConnectivity();
    final appInfoService =
        overrides.appInfoService ?? await PackageAppInfoService.load();

    RepositoryHelpers.onParseError = reportUnexpected;
    // Önbellek kancaları kayıttan hemen önce bağlanır (kurulum yarıda
    // kesilirse abonelik açık kalmaz): yazım → girdi atılır; uid değişimi /
    // çıkış → tüm önbellek temizlenir (hesaplar arası sızıntı yok).
    if (firestoreService case final FirestoreWriteSource writes) {
      writes.addWriteListener(readCaches.onWrite);
    }
    readCaches.bindSession(
      authService.authStateChanges().map((user) => user?.uid),
    );
    GetIt.I
      // Çökme raporlama ilk kayıttır: sonraki adımların günlüğü ona düşer.
      ..registerSingleton<CrashService>(crashService)
      ..registerSingleton<RemoteConfigService>(remoteConfigService)
      ..registerSingleton<AppClock>(appClock)
      ..registerSingleton<AuthService>(authService)
      ..registerSingleton<FirestoreService>(firestoreService)
      ..registerSingleton<StorageService>(storageService)
      // T-12 · kimlik ve profil repository'leri
      ..registerSingleton<RepositoryReadCaches>(
        readCaches,
        dispose: (caches) => caches.dispose(),
      )
      ..registerSingleton<AuthRepository>(authRepository)
      ..registerSingleton<UserRepository>(userRepository)
      ..registerSingleton<SettingsRepository>(settingsRepository)
      // T-15 · kulüp ve üyelik repository'leri; T-25 · bildirim dağıtıcısı
      // ve gelen kutusu
      ..registerSingleton<NotificationDispatcher>(notificationDispatcher)
      // T-34 · DLG-22 "{n}" tahmini (`estimateEventNew` — CD-38); dağıtıcıyla
      // aynı örnek (aynı iki sorgu).
      ..registerSingleton<RecipientResolver>(recipientResolver)
      ..registerSingleton<NotificationRepository>(notificationRepository)
      ..registerSingleton<ClubRepository>(clubRepository)
      ..registerSingleton<MembershipRepository>(membershipRepository)
      ..registerSingleton<ReportRepository>(reportRepository)
      ..registerSingleton<BlockRepository>(blockRepository)
      ..registerSingleton<ActivityRepository>(activityRepository)
      // T-19 · akış repository'leri
      ..registerSingleton<PostRepository>(postRepository)
      ..registerSingleton<CommentRepository>(commentRepository)
      ..registerSingleton<SavedPostRepository>(savedPostRepository)
      ..registerSingleton<AnnouncementCounterRepository>(
        announcementCounterRepository,
      )
      // T-22 · etkinlik ve katılım repository'leri
      ..registerSingleton<EventRepository>(eventRepository)
      ..registerSingleton<RsvpRepository>(rsvpRepository)
      // T-28 · destek talepleri
      ..registerSingleton<SupportRepository>(supportRepository)
      // T-29 · hesap silme
      ..registerSingleton<AccountDeletionRepository>(accountDeletionRepository)
      // T-30 · yönetim ve yoklama
      ..registerSingleton<ManagementRepository>(managementRepository)
      ..registerSingleton<AttendanceRepository>(attendanceRepository)
      ..registerSingleton<AdminRepository>(adminRepository)
      // Geri bildirim: router'ın kök gezgini + GuToastHost denetleyicisi
      // (CD-128).
      ..registerSingleton<GuToastController>(toastController)
      ..registerSingleton<FeedbackService>(
        AppFeedbackService(
          navigatorKey: navigatorKey ?? rootNavigatorKey,
          toastController: toastController,
        ),
      )
      ..registerSingleton<ConnectivityService>(connectivityService)
      // DebugMenu çevrimdışı simülasyonu Firestore ağını da kapatır
      // (T-44 · A4-08); koşul derleme sabiti — release'te dal düşer.
      ..registerSingleton<ConnectivityGate>(
        ConnectivityGate(
          connectivityService,
          setFirestoreNetwork: AppEnvironment.debugMenuEnabled
              ? firestoreService.setNetworkEnabled
              : null,
        ),
      )
      ..registerSingleton<AppInfoService>(appInfoService)
      ..registerSingleton<UrlLauncherService>(
        overrides.urlLauncherService ?? const DeviceUrlLauncherService(),
      )
      // T-16 · sistem paylaşım sayfası
      ..registerSingleton<ShareService>(
        overrides.shareService ?? const DeviceShareService(),
      )
      // T-14 · izinler ve görsel seçimi
      ..registerSingleton<PermissionService>(
        overrides.permissionService ?? const DevicePermissionService(),
      )
      ..registerSingleton<ImagePickerService>(
        overrides.imagePickerService ?? const DeviceImagePickerService(),
      )
      // T-23 · geçici dosya (.ics) ve yerel hatırlatıcı (CD-08, CD-09)
      ..registerSingleton<FileService>(
        overrides.fileService ?? const DeviceFileService(),
      )
      ..registerSingleton<LocalReminderService>(
        overrides.localReminderService ??
            FlutterLocalReminderService(clock: appClock),
      )
      // T-42 · push (Mod F, CD-165): izin PermissionService'te kalır; jeton
      // yazımı UserRepository'de (`SessionPushSync`).
      ..registerSingleton<MessagingService>(
        overrides.messagingService ??
            (isEmulator
                ? const EmulatorMessagingService()
                : FirebaseMessagingService()),
      )
      // T-35 · QR tarayıcı (MGT-07, D-30)
      ..registerSingleton<QrScannerService>(
        overrides.qrScannerService ?? const MobileQrScannerService(),
      )
      // Depo burada yalnızca kaydedilir; `AppBootstrap` `load()` çağırır.
      ..registerSingleton<AppPreferencesStore>(
        overrides.appPreferencesStore ?? SharedAppPreferencesStore(),
      );
  }

  /// Tüm kayıtları siler (test ve yeniden kurulum).
  static Future<void> reset() {
    RepositoryHelpers.onParseError = null;
    return GetIt.I.reset();
  }

  /// Eksik kalan bildirim dağıtımını günlüğe yazar (PLAN §10.5: uyarı;
  /// kullanıcıya hata gösterilmez). Dağıtım başarısızsa ya da parça
  /// yazılamadıysa [crashService]'e `nonFatal` da raporlanır (T-44 · D2-03);
  /// geçici ağ hatası (çevrimdışı, erişilemez, süre) yalnızca günlüktedir.
  /// Alıcı kimliği yazılmaz. Yalnızca dağıtıcının `onIssue` dinleyicisi
  /// çağırır (testte doğrudan).
  @visibleForTesting
  static void reportDispatchIssue(
    NotificationType type,
    FirestoreResult<DispatchReport> result, {
    required CrashService crashService,
  }) {
    AppLogger.warn(switch (result) {
      FirebaseSuccess(data: final report) =>
        'Bildirim dağıtımı eksik (${type.json}): ${report.written}/'
            '${report.requested}, başarısız parça ${report.failedChunks}',
      FirebaseFailure(:final error) =>
        'Bildirim dağıtılamadı (${type.json}): ${error.name}',
    });
    final reason = switch (result) {
      FirebaseSuccess(data: final report) when report.failedChunks > 0 =>
        'dispatch:${type.json} ${report.written}/${report.requested} '
            'failed=${report.failedChunks}',
      FirebaseFailure(:final error) when !_transientErrors.contains(error) =>
        'dispatch:${type.json} ${error.name}',
      _ => null,
    };
    if (reason == null) return;
    unawaited(
      crashService.recordError(
        StateError('notification dispatch incomplete'),
        StackTrace.current,
        reason: reason,
      ),
    );
  }

  /// Raporlanmayan (beklenen, geçici) dağıtım hataları.
  static const Set<FirestoreError> _transientErrors = {
    FirestoreError.unavailable,
    FirestoreError.timeout,
    FirestoreError.offline,
    FirestoreError.cancelled,
  };

  static Future<ConnectivityService> _startConnectivity() async {
    final service = DeviceConnectivityService();
    await service.start();
    return service;
  }
}

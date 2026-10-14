// Varsayılan fake kayıtları (CLAUDE.md §3, PLAN §16.2/§16.3).
//
// `pumpApp` her çağrıda `GetIt.I.reset()` sonrası bunu çağırır. Her fake
// kendi task'ında (T-10 servisler, T-12+ repository'ler) buraya bir satır
// ekler, ör.
//   GetIt.I.registerSingleton<AuthService>(FakeAuthService());
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/connectivity/connectivity_gate.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/service/app_info_service.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';
import 'package:gu_kulupler/product/service/file_service.dart';
import 'package:gu_kulupler/product/service/image_picker_service.dart';
import 'package:gu_kulupler/product/service/local_reminder_service.dart';
import 'package:gu_kulupler/product/service/permission_service.dart';
import 'package:gu_kulupler/product/service/share_service.dart';
import 'package:gu_kulupler/product/service/url_launcher_service.dart';

import '../helpers/fake_app_clock.dart';
import 'fake_account_deletion_repository.dart';
import 'fake_activity_repository.dart';
import 'fake_announcement_counter_repository.dart';
import 'fake_app_info_service.dart';
import 'fake_app_preferences_store.dart';
import 'fake_attendance_repository.dart';
import 'fake_auth_repository.dart';
import 'fake_auth_service.dart';
import 'fake_block_repository.dart';
import 'fake_club_repository.dart';
import 'fake_comment_repository.dart';
import 'fake_connectivity_service.dart';
import 'fake_crash_service.dart';
import 'fake_event_repository.dart';
import 'fake_feedback_service.dart';
import 'fake_file_service.dart';
import 'fake_firestore_service.dart';
import 'fake_image_picker_service.dart';
import 'fake_local_reminder_service.dart';
import 'fake_management_repository.dart';
import 'fake_membership_repository.dart';
import 'fake_notification_dispatcher.dart';
import 'fake_notification_repository.dart';
import 'fake_permission_service.dart';
import 'fake_post_repository.dart';
import 'fake_remote_config_service.dart';
import 'fake_report_repository.dart';
import 'fake_rsvp_repository.dart';
import 'fake_saved_post_repository.dart';
import 'fake_settings_repository.dart';
import 'fake_share_service.dart';
import 'fake_storage_service.dart';
import 'fake_support_repository.dart';
import 'fake_url_launcher_service.dart';
import 'fake_user_repository.dart';

/// Varsayılan [FakeAppClock] anı: 12 Ekim 2026 Pazartesi 19:30 Istanbul
/// (PLAN §14.7 örnek anı).
final DateTime kDefaultFakeNowUtc = DateTime.utc(2026, 10, 12, 16, 30);

/// Varsayılan fake'leri `GetIt.I`'ye kaydeder. `ConnectivityGate` gerçek
/// sınıftır ve kayıtlı `FakeConnectivityService`'i okur. `FakeAuthRepository`
/// kayıtlı `FakeAuthService` ve `FakeAppClock` üzerinde çalışır: servis
/// fake'ine yazılan oturum durumu repository'den de görülür.
/// `FakeMembershipRepository` kayıtlı `FakeClubRepository` ve `FakeAppClock`
/// üzerinde çalışır: kulüp koşulları ve `memberCount` aynı kulüp kümesinden
/// okunur / işlenir. T-19 fake'leri de paylaşımlıdır: `FakePostRepository`
/// bildirimli duyuruda kayıtlı `FakeAnnouncementCounterRepository` sayacını
/// artırır; `FakeCommentRepository` ve `FakeSavedPostRepository` gönderiyi
/// (varlık, `commentCount`) kayıtlı `FakePostRepository`'den okur / işler.
/// T-22: `FakeRsvpRepository` etkinliği ve sayaçlarını kayıtlı
/// `FakeEventRepository`'den okur / işler (kontenjan kararı, ±1).
/// T-29: `FakeAccountDeletionRepository` kayıtlı `FakeUserRepository` ve
/// `FakeMembershipRepository` üzerinde çalışır (profil anonimleştirmesi,
/// başkanlık ön denetimi, M14).
/// T-30: `FakeManagementRepository` kayıtlı üyelik / etkinlik / gönderi /
/// yorum fake'lerine devreder, ayarları kayıtlı `FakeClubRepository`'ye
/// yazar; `FakeAttendanceRepository` kayıtlı `FakeRsvpRepository` (ve onun
/// `FakeEventRepository`'si) üzerinde çalışır.
void registerDefaultFakes() {
  final connectivity = FakeConnectivityService();
  final authService = FakeAuthService();
  final clock = FakeAppClock(kDefaultFakeNowUtc);
  final clubs = FakeClubRepository();
  final users = FakeUserRepository();
  final memberships = FakeMembershipRepository(clock, clubs: clubs);
  final counters = FakeAnnouncementCounterRepository(clock);
  final posts = FakePostRepository(clock, counters: counters);
  final events = FakeEventRepository(clock);
  final comments = FakeCommentRepository(clock, posts: posts);
  final rsvps = FakeRsvpRepository(clock, events: events);
  GetIt.I
    ..registerSingleton<FeedbackService>(FakeFeedbackService())
    // T-10 · Firebase servisleri
    ..registerSingleton<AuthService>(authService)
    ..registerSingleton<FirestoreService>(FakeFirestoreService())
    ..registerSingleton<StorageService>(FakeStorageService())
    ..registerSingleton<RemoteConfigService>(FakeRemoteConfigService())
    ..registerSingleton<CrashService>(FakeCrashService())
    // T-11 · saat, cihaz servisleri, tercihler, çevrimdışı kapısı
    ..registerSingleton<AppClock>(clock)
    ..registerSingleton<ConnectivityService>(connectivity)
    ..registerSingleton<ConnectivityGate>(ConnectivityGate(connectivity))
    ..registerSingleton<AppInfoService>(FakeAppInfoService())
    ..registerSingleton<AppPreferencesStore>(FakeAppPreferencesStore())
    // T-12 · kimlik ve profil repository'leri
    ..registerSingleton<AuthRepository>(
      FakeAuthRepository(clock, service: authService),
    )
    ..registerSingleton<UserRepository>(users)
    ..registerSingleton<SettingsRepository>(FakeSettingsRepository())
    // T-15 · kulüp, üyelik, şikayet, engel, günlük, bildirim dağıtıcısı
    ..registerSingleton<ClubRepository>(clubs)
    ..registerSingleton<MembershipRepository>(memberships)
    ..registerSingleton<ReportRepository>(FakeReportRepository())
    ..registerSingleton<BlockRepository>(FakeBlockRepository())
    ..registerSingleton<ActivityRepository>(FakeActivityRepository())
    ..registerSingleton<NotificationDispatcher>(FakeNotificationDispatcher())
    // T-19 · gönderi, yorum, kayıt, duyuru sayacı
    ..registerSingleton<PostRepository>(posts)
    ..registerSingleton<CommentRepository>(comments)
    ..registerSingleton<SavedPostRepository>(
      FakeSavedPostRepository(clock, posts: posts),
    )
    ..registerSingleton<AnnouncementCounterRepository>(counters)
    // T-22 · etkinlik ve katılım
    ..registerSingleton<EventRepository>(events)
    ..registerSingleton<RsvpRepository>(rsvps)
    // T-25 · uygulama içi bildirimler (gelen kutusu, hatırlatıcı belgesi)
    ..registerSingleton<NotificationRepository>(
      FakeNotificationRepository(clock),
    )
    // T-28 · destek talepleri
    ..registerSingleton<SupportRepository>(FakeSupportRepository(clock))
    // T-29 · hesap silme
    ..registerSingleton<AccountDeletionRepository>(
      FakeAccountDeletionRepository(
        clock,
        users: users,
        memberships: memberships,
      ),
    )
    // T-30 · yönetim paneli (kompozisyon) ve yoklama / terfi
    ..registerSingleton<ManagementRepository>(
      FakeManagementRepository(
        memberships: memberships,
        events: events,
        posts: posts,
        comments: comments,
        clubs: clubs,
      ),
    )
    ..registerSingleton<AttendanceRepository>(
      FakeAttendanceRepository(clock, rsvps: rsvps),
    )
    // T-13 · dış bağlantı servisi
    ..registerSingleton<UrlLauncherService>(FakeUrlLauncherService())
    // T-16 · sistem paylaşım sayfası
    ..registerSingleton<ShareService>(FakeShareService())
    // T-14 · izinler ve görsel seçimi
    ..registerSingleton<PermissionService>(FakePermissionService())
    ..registerSingleton<ImagePickerService>(FakeImagePickerService())
    // T-23 · geçici dosya (.ics) ve yerel hatırlatıcı
    ..registerSingleton<FileService>(FakeFileService())
    ..registerSingleton<LocalReminderService>(FakeLocalReminderService(clock));
}

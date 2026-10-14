// T-11 · ProjectDependencyMixin: tembel getter'lar ve bilerek olmayan
// getter'lar (D-04; PLAN §6.1, §12.1).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/connectivity/connectivity_gate.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
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

import '../../fakes/fake_auth_service.dart';
import '../../fakes/register_fakes.dart';
import '../../helpers/design_files.dart';

final class _Consumer with ProjectDependencyMixin {}

void main() {
  setUp(() async {
    await GetIt.I.reset();
    addTearDown(GetIt.I.reset);
  });

  group('T-11 · ProjectDependencyMixin', () {
    test("her getter GetIt'teki kayıtlı örneği döndürür", () {
      registerDefaultFakes();
      final consumer = _Consumer();
      expect(consumer.authService, same(GetIt.I<AuthService>()));
      expect(consumer.feedback, same(GetIt.I<FeedbackService>()));
      expect(consumer.appClock, same(GetIt.I<AppClock>()));
      expect(consumer.connectivityGate, same(GetIt.I<ConnectivityGate>()));
      expect(
        consumer.appPreferencesStore,
        same(GetIt.I<AppPreferencesStore>()),
      );
      expect(
        consumer.connectivityService,
        same(GetIt.I<ConnectivityService>()),
      );
      expect(consumer.appInfoService, same(GetIt.I<AppInfoService>()));
      // T-12 · repository'ler
      expect(consumer.authRepository, same(GetIt.I<AuthRepository>()));
      expect(consumer.userRepository, same(GetIt.I<UserRepository>()));
      expect(consumer.settingsRepository, same(GetIt.I<SettingsRepository>()));
      // T-15 · kulüp, üyelik, şikayet, engel, günlük
      expect(consumer.clubRepository, same(GetIt.I<ClubRepository>()));
      expect(
        consumer.membershipRepository,
        same(GetIt.I<MembershipRepository>()),
      );
      expect(consumer.reportRepository, same(GetIt.I<ReportRepository>()));
      expect(consumer.blockRepository, same(GetIt.I<BlockRepository>()));
      expect(consumer.activityRepository, same(GetIt.I<ActivityRepository>()));
      // T-19 · gönderi, yorum, kayıt, duyuru sayacı
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
      // T-22 · etkinlik ve katılım
      expect(consumer.eventRepository, same(GetIt.I<EventRepository>()));
      expect(consumer.rsvpRepository, same(GetIt.I<RsvpRepository>()));
      // T-28 · destek talepleri
      expect(consumer.supportRepository, same(GetIt.I<SupportRepository>()));
      // T-29 · hesap silme
      expect(
        consumer.accountDeletionRepository,
        same(GetIt.I<AccountDeletionRepository>()),
      );
      // T-30 · yönetim ve yoklama
      expect(
        consumer.managementRepository,
        same(GetIt.I<ManagementRepository>()),
      );
      expect(
        consumer.attendanceRepository,
        same(GetIt.I<AttendanceRepository>()),
      );
      // T-13 · dış bağlantı servisi
      expect(
        consumer.urlLauncherService,
        same(GetIt.I<UrlLauncherService>()),
      );
      // T-16 · sistem paylaşım sayfası
      expect(consumer.shareService, same(GetIt.I<ShareService>()));
      // T-14 · izinler ve görsel seçimi
      expect(consumer.permissionService, same(GetIt.I<PermissionService>()));
      expect(
        consumer.imagePickerService,
        same(GetIt.I<ImagePickerService>()),
      );
      // T-23 · geçici dosya ve yerel hatırlatıcı
      expect(consumer.fileService, same(GetIt.I<FileService>()));
      expect(
        consumer.localReminderService,
        same(GetIt.I<LocalReminderService>()),
      );
    });

    test("getter'lar tembeldir: reset + yeni kayıt sonrası yeni örnek "
        'görülür', () async {
      registerDefaultFakes();
      final consumer = _Consumer();
      final first = consumer.authService;

      await GetIt.I.reset();
      final replacement = FakeAuthService();
      GetIt.I.registerSingleton<AuthService>(replacement);
      expect(consumer.authService, same(replacement));
      expect(consumer.authService, isNot(same(first)));
    });

    test('kayıtsız tip StateError verir (sessizce null dönmez)', () {
      final consumer = _Consumer();
      expect(() => consumer.authService, throwsStateError);
      expect(() => consumer.connectivityGate, throwsStateError);
    });

    test("yasak getter'lar yoktur: Firestore / Storage / Remote Config / "
        "çökme servisi ViewModel'e açılmaz (PLAN §6.1)", () {
      final source = readText('lib/core/di/project_dependency_mixin.dart');
      for (final forbidden in const [
        'firestoreService',
        'storageService',
        'remoteConfigService',
        'crashService',
        'calendarExportService',
        'pushTokenService',
        'FirestoreService',
        'StorageService',
        'RemoteConfigService',
        'CrashService',
      ]) {
        expect(source, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test('servis bulucu yalnızca kompozisyon kökü ve mixin dosyalarında '
        "çağrılır: view tarafı mixin'i (AppProviderMixin) onu içermez", () {
      expect(
        readText('lib/core/di/app_provider_mixin.dart'),
        isNot(contains('GetIt')),
      );
    });

    test("ViewModel'ler servis bulucuyu doğrudan çağırmaz; tek istisna "
        'AppGateViewModel (Remote Config geri düşüşü — CD-132)', () {
      // `@riverpod` sınıfı kurucu parametresiyle üretilemez: Remote Config
      // testte kurucudan, uygulamada GetIt kaydından okunur. Başka bir
      // ViewModel bu yola girmemelidir (mixin getter'ı kullanır).
      final offenders = [
        for (final entity in Directory('$repoRoot/lib').listSync(
          recursive: true,
        ))
          if (entity is File &&
              entity.path.endsWith('_view_model.dart') &&
              entity.readAsStringSync().contains('GetIt'))
            entity.path.substring(repoRoot.length + 1),
      ];
      expect(offenders, ['lib/product/init/app_gate_view_model.dart']);
    });
  });
}

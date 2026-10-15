// MGT-09 · ClubSettingsViewModel: açılış (kulüp belgesinden form), okuma
// hatası + yeniden dene, kirli takibi (eski değere dönüş temizler),
// doğrulama (e-posta / Instagram / web), kaydet (yalnızca değişen alanlar,
// Instagram `@`, TST-21), görsel yükleme sırası (updateClubMedia →
// updateClubSettings) ve yarıda kalan yazımın yeniden denenmesi, kilitli ad
// ve kategori (TST-20), başvuru kapatma (TST-21 → TST-54), danışman TST-26,
// değişiklik yok TST-X9, çevrimdışı TST-24 — PLAN §12.6.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/constants/app_durations.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/management/provider/club_settings_state.dart';
import 'package:gu_kulupler/features/management/provider/club_settings_view_model.dart';
import 'package:gu_kulupler/product/feedback/catalogs/toasts/toast_catalog.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';
import 'package:gu_kulupler/product/service/image_picker_service.dart';

import '../../../fakes/fake_club_repository.dart';
import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_management_repository.dart';
import '../../../fakes/register_fakes.dart';
import '../../../helpers/test_container.dart';
import '../club_settings_test_support.dart';
import '../manage_test_support.dart';

void main() {
  late FakeClubRepository clubs;
  late FakeManagementRepository management;
  late FakeFeedbackService feedback;

  final provider = clubSettingsViewModelProvider(kManageClubId);

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    clubs = GetIt.I<ClubRepository>() as FakeClubRepository;
    management = GetIt.I<ManagementRepository>() as FakeManagementRepository;
    feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
    seedClubSettings();
  });

  /// İlk okuması bitmiş kapsayıcı.
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
    management.calls.clear();
    return container;
  }

  List<String> managementCalls() => [
    for (final c in management.calls) c.method,
  ];

  group('MGT-09 · ClubSettingsViewModel · açılış', () {
    test('form kulüp belgesinden kurulur; temiz, düzenlenebilir', () async {
      final container = await loaded();
      final state = container.read(provider);
      expect(state, loadedSettingsState());
      expect(state.isDirty, isFalse);
      expect(state.canEdit, isTrue);
      expect(state.isReadOnly, isFalse);
      expect(state.instagram, '@guk_doga');
    });

    test('okunamayan kulüp → hata; "Yeniden dene" okur', () async {
      clubs.failNext(FirestoreError.unavailable);
      final container = await loaded();
      expect(container.read(provider).isError, isTrue);
      expect(container.read(provider).isLoading, isFalse);

      await container.read(provider.notifier).load();
      expect(container.read(provider).isError, isFalse);
      expect(container.read(provider).original, kManageClub);
    });

    test('silinmiş kulüp → hata', () async {
      clubs.clubs[kManageClubId] = kManageClub.copyWith(isDeleted: true);
      final container = await loaded();
      expect(container.read(provider).isError, isTrue);
    });

    test('danışman salt okunur; rolsüz kullanıcı ekranı göremez', () async {
      final advisor = await loaded(
        session: manageSession(role: ClubRole.advisor),
      );
      expect(advisor.read(provider).isReadOnly, isTrue);
      expect(advisor.read(provider).canView, isTrue);
      expect(advisor.read(provider).canEdit, isFalse);

      final member = await loaded(
        session: manageSession(role: ClubRole.member),
      );
      expect(member.read(provider).canView, isFalse);
    });
  });

  group('MGT-09 · ClubSettingsViewModel · kirli takibi', () {
    test('değişiklik kirletir; eski değere dönüş temizler', () async {
      final container = await loaded();
      final vm = container.read(provider.notifier)..setSummary('Yeni özet');
      expect(container.read(provider).isDirty, isTrue);
      vm.setSummary(kManageClub.summary);
      expect(container.read(provider).isDirty, isFalse);

      vm.setApplicationsOpen(value: false);
      expect(container.read(provider).isDirty, isTrue);
      vm.setApplicationsOpen(value: true);
      expect(container.read(provider).isDirty, isFalse);

      // Yalnızca baştaki / sondaki boşluk fark sayılmaz.
      vm.setAbout('${kManageClub.about}  ');
      expect(container.read(provider).isDirty, isFalse);
    });

    test('metinler sınırda kesilir', () async {
      final container = await loaded();
      container.read(provider.notifier)
        ..setSummary('a' * (Limits.clubSummaryMax + 5))
        ..setAbout('b' * (Limits.clubAboutMax + 5));
      final state = container.read(provider);
      expect(state.summary.length, Limits.clubSummaryMax);
      expect(state.about.length, Limits.clubAboutMax);
    });

    test('logo / kapak seçimi ve şablon kirletir', () async {
      final container = await loaded();
      final vm = container.read(provider.notifier);
      await vm.pickLogo(MediaSource.gallery);
      expect(container.read(provider).pendingLogo, isNotNull);
      expect(container.read(provider).isDirty, isTrue);

      final fresh = await loaded();
      fresh
          .read(provider.notifier)
          .setCoverTemplate(ClubPalette.slate, ClubPattern.waves, 'cover-x');
      final state = fresh.read(provider);
      expect(state.coverPalette, ClubPalette.slate);
      expect(state.coverSeed, 'cover-x');
      expect(state.isDirty, isTrue);
    });
  });

  group('MGT-09 · ClubSettingsViewModel · doğrulama', () {
    test('bozuk e-posta / Instagram / web → invalid, yazım yok; düzeltilen '
        'alanın hatası silinir', () async {
      final container = await loaded();
      final vm = container.read(provider.notifier)
        ..setEmail('doga@')
        ..setInstagram('guk doga!')
        ..setWeb('kulupler');
      expect(await vm.save(), ClubSettingsOutcome.invalid);
      expect(container.read(provider).errors, {
        ClubSettingsField.email: FormFieldError.invalidEmail,
        ClubSettingsField.instagram: FormFieldError.invalidFormat,
        ClubSettingsField.web: FormFieldError.invalidFormat,
      });
      expect(managementCalls(), isEmpty);

      vm.setEmail('doga@gumushane.edu.tr');
      expect(
        container.read(provider).errors.containsKey(ClubSettingsField.email),
        isFalse,
      );
    });

    test('boş iletişim alanları geçerlidir ve `null` yazılır', () async {
      final container = await loaded();
      final vm = container.read(provider.notifier)
        ..setEmail('')
        ..setWeb('  ');
      expect(await vm.save(), ClubSettingsOutcome.saved);
      expect(
        management.settingsUpdates.single.patch.social,
        const ClubSocialModel(instagram: '@guk_doga'),
      );
    });
  });

  group('MGT-09 · ClubSettingsViewModel · kaydet', () {
    test('yalnızca değişen alanlar yazılır; Instagram `@` alır; TST-21; '
        'form temizlenir', () async {
      final container = await loaded();
      final vm = container.read(provider.notifier)
        ..setSummary('  Yeni özet  ')
        ..setInstagram('guk_yeni')
        ..setRequireNote(value: false);
      expect(await vm.save(), ClubSettingsOutcome.saved);

      final update = management.settingsUpdates.single;
      expect(update.actorId, kManageUid);
      expect(
        update.patch,
        const ClubSettingsPatch(
          summary: 'Yeni özet',
          social: ClubSocialModel(
            email: 'doga@gumushane.edu.tr',
            instagram: '@guk_yeni',
            web: 'https://kulupler.gumushane.edu.tr/doga',
          ),
          requireNote: false,
        ),
      );
      expect(managementCalls(), ['updateClubSettings']);
      expect(feedback.toasts, [ToastId.tst21]);
      final state = container.read(provider);
      expect(state.isDirty, isFalse);
      expect(state.isSubmitting, isFalse);
      expect(state.instagram, '@guk_yeni');
      expect(state.summary, 'Yeni özet');
      expect(clubs.clubs[kManageClubId]!.requireNote, isFalse);
    });

    test('logo + kapak: önce updateClubMedia (yükleyen oturumdaki '
        'kullanıcı), sonra ayarlar; yollar forma işlenir', () async {
      final container = await loaded();
      final vm = container.read(provider.notifier);
      await vm.pickLogo(MediaSource.gallery);
      await vm.pickCover(MediaSource.gallery);
      vm.setApprovalRequired(value: false);

      expect(await vm.save(), ClubSettingsOutcome.saved);
      expect(managementCalls(), ['updateClubMedia', 'updateClubSettings']);
      expect(management.mediaUploads, hasLength(2));
      expect(
        management.mediaUploads.map((u) => u.uploaderId).toSet(),
        {kManageUid},
      );
      final logo = management.mediaUploads.firstWhere((u) => u.isLogo);
      final state = container.read(provider);
      expect(state.original!.logoPath, logo.path);
      expect(state.coverPath, isNotNull);
      expect(state.pendingLogo, isNull);
      expect(state.pendingCover, isNull);
      expect(state.isDirty, isFalse);
      expect(logo.path, startsWith('clubs/$kManageClubId/'));
    });

    test('yüklenmiş kapak yerine SHT-31 şablonu (belgedekiyle aynı bile '
        'olsa): kirletir; kayıt coverPath bırakır (clearCoverPath), dosya '
        'silinmez — T-36 güvenlik incelemesi', () async {
      clubs.clubs[kManageClubId] = kManageClub.copyWith(
        coverPath: 'clubs/$kManageClubId/kapak.png',
        logoPath: 'clubs/$kManageClubId/logo.png',
      );
      final container = await loaded();
      final vm = container.read(provider.notifier)
        ..setCoverTemplate(
          kManageClub.palette,
          kManageClub.pattern,
          kManageClub.coverSeed,
        );
      expect(container.read(provider).coverPath, isNull);
      expect(container.read(provider).isDirty, isTrue);

      expect(await vm.save(), ClubSettingsOutcome.saved);
      expect(managementCalls(), ['updateClubSettings']);
      expect(
        management.settingsUpdates.single.patch,
        const ClubSettingsPatch(clearCoverPath: true),
      );
      final club = clubs.clubs[kManageClubId]!;
      expect(club.coverPath, isNull);
      expect(club.logoPath, 'clubs/$kManageClubId/logo.png');
      final state = container.read(provider);
      expect(state.coverPath, isNull);
      expect(state.original!.coverPath, isNull);
      expect(state.isDirty, isFalse);
      expect(feedback.toasts, [ToastId.tst21]);
    });

    test('şablondan sonra yeni kapak seçilirse coverPath bırakılmaz '
        '(yükleme yazar)', () async {
      clubs.clubs[kManageClubId] = kManageClub.copyWith(
        coverPath: 'clubs/$kManageClubId/kapak.png',
      );
      final container = await loaded();
      final vm = container.read(provider.notifier)
        ..setCoverTemplate(ClubPalette.slate, ClubPattern.waves, 'cover-x');
      await vm.pickCover(MediaSource.gallery);

      expect(await vm.save(), ClubSettingsOutcome.saved);
      expect(managementCalls(), ['updateClubMedia', 'updateClubSettings']);
      expect(management.settingsUpdates.single.patch.clearCoverPath, isFalse);
      expect(
        clubs.clubs[kManageClubId]!.coverPath,
        management.mediaUploads.single.path,
      );
    });

    test('askıdaki kulüp: görsel gönderilmez → TST-X18', () async {
      clubs.clubs[kManageClubId] = kManageClub.copyWith(
        status: ClubStatus.suspended,
      );
      final container = await loaded();
      final vm = container.read(provider.notifier);
      await vm.pickLogo(MediaSource.gallery);

      expect(await vm.save(), ClubSettingsOutcome.failed);
      expect(management.mediaUploads, isEmpty);
      expect(feedback.toasts, [ToastId.tstX18]);
      expect(container.read(provider).pendingLogo, isNotNull);
    });

    test('yalnızca görsel değiştiyse ayar yazımı yapılmaz', () async {
      final container = await loaded();
      final vm = container.read(provider.notifier);
      await vm.pickLogo(MediaSource.gallery);
      expect(await vm.save(), ClubSettingsOutcome.saved);
      expect(managementCalls(), ['updateClubMedia']);
      expect(feedback.toasts, [ToastId.tst21]);
    });

    test('yükleme reddi → TST-X18, seçim korunur; ayar yazımı sonra düşerse '
        'yeniden denemede görsel yeniden yüklenmez', () async {
      final container = await loaded();
      final vm = container.read(provider.notifier);
      await vm.pickLogo(MediaSource.gallery);
      vm.setSummary('Yeni özet');

      management.failNext(StorageError.unauthorized);
      expect(await vm.save(), ClubSettingsOutcome.failed);
      expect(feedback.toasts, [ToastId.tstX18]);
      expect(container.read(provider).pendingLogo, isNotNull);
      expect(container.read(provider).isSubmitting, isFalse);
      expect(management.settingsUpdates, isEmpty);

      // 2. deneme: görsel yüklenir (seçim temizlenir), hemen ardından ayar
      // yazımı bilinmeyen hatayla düşer → hata bandı.
      management.calls.clear();
      var armed = true;
      final sub = container.listen(provider, (previous, next) {
        if (armed &&
            previous?.pendingLogo != null &&
            next.pendingLogo == null) {
          armed = false;
          management.failNext(FirestoreError.unknown);
        }
      });
      addTearDown(sub.close);
      expect(await vm.save(), ClubSettingsOutcome.failed);
      expect(managementCalls(), ['updateClubMedia', 'updateClubSettings']);
      expect(container.read(provider).isSubmitError, isTrue);
      expect(container.read(provider).pendingLogo, isNull);
      expect(container.read(provider).isDirty, isTrue);

      // 3. deneme: yalnızca ayarlar.
      management.calls.clear();
      expect(await vm.save(), ClubSettingsOutcome.saved);
      expect(managementCalls(), ['updateClubSettings']);
      expect(container.read(provider).isSubmitError, isFalse);
    });

    test('başvurular kapatılınca TST-21, ardından gecikmeyle TST-54 '
        '(kapatıldı)', () async {
      final container = await loaded();
      final vm = container.read(provider.notifier)
        ..setApplicationsOpen(value: false);
      expect(await vm.save(), ClubSettingsOutcome.saved);
      expect(feedback.toasts, [ToastId.tst21]);

      await Future<void>.delayed(AppDurations.applicationsToastDelay);
      await pumpEventQueue();
      expect(feedback.toasts, [ToastId.tst21, ToastId.tst54]);
      expect(feedback.toastParams.last, const ToastParams());
      expect(clubs.clubs[kManageClubId]!.applicationsOpen, isFalse);
    });

    test('değişiklik yok → TST-X9; çevrimdışı → TST-24, yazım yok', () async {
      final container = await loaded();
      final vm = container.read(provider.notifier);
      expect(await vm.save(), ClubSettingsOutcome.blocked);
      expect(feedback.toasts, [ToastId.tstX9]);

      (GetIt.I<ConnectivityService>() as FakeConnectivityService).isOffline =
          true;
      vm.setSummary('Yeni özet');
      expect(await vm.save(), ClubSettingsOutcome.blocked);
      expect(feedback.toasts.last, ToastId.tst24);
      expect(managementCalls(), isEmpty);
      expect(container.read(provider).isDirty, isTrue);
    });
  });

  group('MGT-09 · ClubSettingsViewModel · kilitli alanlar ve danışman', () {
    test('kilitli ad → TST-20; başka kategori → TST-20 (değer değişmez); '
        'aynı kategori sessiz', () async {
      final container = await loaded();
      final vm = container.read(provider.notifier)..onLockedNameTap();
      expect(feedback.toasts, [ToastId.tst20]);

      vm.selectCategory(kManageClub.categoryId);
      expect(feedback.toasts, [ToastId.tst20]);
      vm.selectCategory('k01');
      expect(feedback.toasts, [ToastId.tst20, ToastId.tst20]);
      expect(container.read(provider).isDirty, isFalse);
    });

    test('danışman: alan değişmez, TST-26; kaydet engellenir', () async {
      final container = await loaded(
        session: manageSession(role: ClubRole.advisor),
      );
      final vm = container.read(provider.notifier)
        ..setSummary('Yeni özet')
        ..setApplicationsOpen(value: false);
      await vm.pickLogo(MediaSource.gallery);
      expect(
        container.read(provider),
        loadedSettingsState(
          role: ClubRole.advisor,
        ),
      );
      expect(feedback.toasts.toSet(), {ToastId.tst26});

      expect(await vm.save(), ClubSettingsOutcome.blocked);
      vm.onSaveDisabledTap();
      expect(feedback.toasts.last, ToastId.tst26);
      expect(managementCalls(), isEmpty);
    });
  });
}

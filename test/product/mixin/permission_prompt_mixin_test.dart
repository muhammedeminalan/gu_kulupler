// DLG-03 · Bildirimleri açalım mı? · DLG-04 · Kamera erişimi · DLG-05 ·
// Fotoğraflarına erişim — `PermissionPromptMixin`: ön açıklama → sistem izni
// → görsel seçici sırası, TST-32 "Ayarlara git", TST-19, galeri için sistem
// izni istenmemesi (CD-16) ve DLG-05 onayının hatırlanması.
// Prototip: dialogs.js:10–17, sheets.js:80–81.
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/mixin/permission_prompt_mixin.dart';
import 'package:gu_kulupler/product/service/image_picker_service.dart';
import 'package:gu_kulupler/product/service/permission_service.dart';

import '../../fakes/fake_app_preferences_store.dart';
import '../../fakes/fake_feedback_service.dart';
import '../../fakes/fake_image_picker_service.dart';
import '../../fakes/fake_permission_service.dart';
import '../../fakes/register_fakes.dart';

/// Görsel seçen bir ViewModel'in en küçük hali.
final class _Notifier with ProjectDependencyMixin, PermissionPromptMixin {}

void main() {
  late FakeFeedbackService feedback;
  late FakePermissionService permissions;
  late FakeImagePickerService picker;
  late FakeAppPreferencesStore prefs;
  late _Notifier notifier;

  ImagePickError errorOf(ImagePickResult result) =>
      (result as ImagePickFailure).error;

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
    permissions = GetIt.I<PermissionService>() as FakePermissionService;
    picker = GetIt.I<ImagePickerService>() as FakeImagePickerService;
    prefs = GetIt.I<AppPreferencesStore>() as FakeAppPreferencesStore;
    notifier = _Notifier();
  });

  group('DLG-04 · Kamera erişimi · pickImage(camera)', () {
    test('izin zaten varsa dialog ve sistem penceresi açılmadan seçici '
        'açılır', () async {
      permissions.results[Permission.camera] = PermissionStatus.granted;

      final result = await notifier.pickImage(MediaSource.camera);

      expect(result.imageOrNull, same(kFakeJpeg));
      expect(feedback.dialogs, isEmpty);
      expect(permissions.requested, isEmpty);
      expect(picker.picks, [MediaSource.camera]);
      expect(feedback.toasts, isEmpty);
    });

    test('izin yoksa: DLG-04 (katalog kipi) → "İzin ver" → sistem kamera izni '
        '→ seçici; sırayla', () async {
      feedback.nextDialogResult = true;

      final result = await notifier.pickImage(MediaSource.camera);

      expect(result.imageOrNull, same(kFakeJpeg));
      expect(feedback.dialogs, [DialogId.dlg04]);
      expect(feedback.lastDialogBuilder, isNull);
      expect(permissions.requested, [Permission.camera]);
      expect(picker.picks, [MediaSource.camera]);
      expect(feedback.toasts, isEmpty);
      // Sıra: önce durum okunur, sonra istek yapılır.
      expect(permissions.calls.map((call) => call.method), [
        'isGranted',
        'request',
      ]);
    });

    test('"Şimdi değil" (false) ve scrim / geri (null): izin istenmez, seçici '
        'açılmaz, toast yok; sonuç iptal', () async {
      for (final choice in [false, null]) {
        feedback.nextDialogResult = choice;

        final result = await notifier.pickImage(MediaSource.camera);

        expect(result, isA<ImagePickCancelled>());
      }
      expect(feedback.dialogs, [DialogId.dlg04, DialogId.dlg04]);
      expect(permissions.requested, isEmpty);
      expect(picker.picks, isEmpty);
      expect(feedback.toasts, isEmpty);
    });

    for (final status in [
      PermissionStatus.denied,
      PermissionStatus.permanentlyDenied,
      PermissionStatus.restricted,
    ]) {
      test('sistem izni ${status.name}: TST-32 + "Ayarlara git" → sistem '
          'ayarları; seçici açılmaz; sonuç permissionDenied', () async {
        permissions.results[Permission.camera] = status;
        feedback.nextDialogResult = true;

        final result = await notifier.pickImage(MediaSource.camera);

        expect(errorOf(result), ImagePickError.permissionDenied);
        expect(permissions.requested, [Permission.camera]);
        expect(picker.picks, isEmpty);
        expect(feedback.toasts, [ToastId.tst32]);
        expect(feedback.hasToastAction, isTrue);
        expect(permissions.openedSettings, 0);

        feedback.tapToastAction();
        await Future<void>.delayed(Duration.zero);

        expect(permissions.openedSettings, 1);
      });
    }

    test('izin var görünürken seçici erişimi reddederse (izin bu arada '
        'kaldırıldı) TST-32 gösterilir', () async {
      permissions.results[Permission.camera] = PermissionStatus.granted;
      picker.permissionDenied = true;

      final result = await notifier.pickImage(MediaSource.camera);

      expect(errorOf(result), ImagePickError.permissionDenied);
      expect(picker.picks, [MediaSource.camera]);
      expect(feedback.toasts, [ToastId.tst32]);
      expect(feedback.hasToastAction, isTrue);
    });

    test('diğer seçici hataları aynen döner ve toast gösterilmez (çağıran '
        'kendi hata durumuna çevirir)', () async {
      permissions.results[Permission.camera] = PermissionStatus.granted;
      for (final error in [
        ImagePickError.tooLarge,
        ImagePickError.invalidType,
        ImagePickError.unreadable,
        ImagePickError.failed,
      ]) {
        picker.nextError = error;

        expect(errorOf(await notifier.pickImage(MediaSource.camera)), error);
      }
      expect(feedback.toasts, isEmpty);
    });

    test('seçicide vazgeçme iptal döner; toast yok', () async {
      permissions.results[Permission.camera] = PermissionStatus.granted;
      picker.nextPick = null;

      expect(
        await notifier.pickImage(MediaSource.camera),
        isA<ImagePickCancelled>(),
      );
      expect(feedback.toasts, isEmpty);
    });

    test('ensureCameraAccess: verildi → true; ön açıklamada vazgeçildi ya da '
        'reddedildi → false (ret TST-32 gösterir)', () async {
      feedback.nextDialogResult = false;
      expect(await notifier.ensureCameraAccess(), isFalse);
      expect(feedback.toasts, isEmpty);

      permissions.results[Permission.camera] = PermissionStatus.denied;
      feedback.nextDialogResult = true;
      expect(await notifier.ensureCameraAccess(), isFalse);
      expect(feedback.toasts, [ToastId.tst32]);

      permissions.results[Permission.camera] = PermissionStatus.granted;
      expect(await notifier.ensureCameraAccess(), isTrue);
      expect(feedback.dialogs, [DialogId.dlg04, DialogId.dlg04]);
      expect(picker.picks, isEmpty);
    });
  });

  group('DLG-05 · Fotoğraflarına erişim · pickImage(gallery)', () {
    test('ilk kez: DLG-05 (katalog kipi) → "İzin ver" → sistem seçicisi '
        'doğrudan açılır; SİSTEM İZNİ İSTENMEZ (CD-16) ve onay cihaza '
        'yazılır', () async {
      feedback.nextDialogResult = true;

      final result = await notifier.pickImage(MediaSource.gallery);

      expect(result.imageOrNull, same(kFakeJpeg));
      expect(feedback.dialogs, [DialogId.dlg05]);
      expect(feedback.lastDialogBuilder, isNull);
      expect(picker.picks, [MediaSource.gallery]);
      expect(permissions.calls, isEmpty);
      expect(prefs.photoAccessExplained, isTrue);
      expect(prefs.values[AppPreferenceKeys.photoAccessExplained], isTrue);
    });

    test('onay verildikten sonra açıklama yeniden gösterilmez', () async {
      feedback.nextDialogResult = true;
      await notifier.pickImage(MediaSource.gallery);

      await notifier.pickImage(MediaSource.gallery);
      await _Notifier().pickImage(MediaSource.gallery);

      expect(feedback.dialogs, [DialogId.dlg05]);
      expect(picker.picks, List.filled(3, MediaSource.gallery));
    });

    test('"Şimdi değil" ve scrim / geri: seçici açılmaz, onay yazılmaz; '
        'sonraki denemede yeniden sorulur', () async {
      for (final choice in [false, null]) {
        feedback.nextDialogResult = choice;

        expect(
          await notifier.pickImage(MediaSource.gallery),
          isA<ImagePickCancelled>(),
        );
      }
      expect(feedback.dialogs, [DialogId.dlg05, DialogId.dlg05]);
      expect(picker.picks, isEmpty);
      expect(prefs.photoAccessExplained, isFalse);
      expect(feedback.toasts, isEmpty);
    });

    test('onay kalıcı yazılamasa da seçici açılır (oturum boyunca '
        'geçerli)', () async {
      feedback.nextDialogResult = true;
      prefs.failNext();

      final result = await notifier.pickImage(MediaSource.gallery);

      expect(result.imageOrNull, same(kFakeJpeg));
      expect(prefs.photoAccessExplained, isTrue);
    });

    test(
      'ensureGalleryAccess: onay → true ve hatırlanır; ret → false',
      () async {
        feedback.nextDialogResult = false;
        expect(await notifier.ensureGalleryAccess(), isFalse);
        feedback.nextDialogResult = true;
        expect(await notifier.ensureGalleryAccess(), isTrue);
        expect(await notifier.ensureGalleryAccess(), isTrue);
        expect(feedback.dialogs, [DialogId.dlg05, DialogId.dlg05]);
        expect(picker.picks, isEmpty);
      },
    );

    test('galeri seçimi kamera iznini ya da kamera açıklamasını '
        'tetiklemez', () async {
      permissions.results[Permission.camera] = PermissionStatus.denied;
      feedback.nextDialogResult = true;

      await notifier.pickImage(MediaSource.gallery);

      expect(feedback.dialogs, isNot(contains(DialogId.dlg04)));
      expect(permissions.requested, isEmpty);
    });
  });

  group('pickImage · boyut sınırı', () {
    test('varsayılan Limits.imageMaxBytes; verilen sınır seçiciye '
        'aktarılır', () async {
      permissions.results[Permission.camera] = PermissionStatus.granted;

      await notifier.pickImage(MediaSource.camera);
      await notifier.pickImage(MediaSource.camera, maxBytes: 1024);

      expect(picker.calls.map((call) => call.args.last), [
        Limits.imageMaxBytes,
        1024,
      ]);
    });
  });

  group('DLG-03 · Bildirimleri açalım mı? · askNotificationPermission', () {
    test('"İzin ver" → sistem bildirim izni verildi → TST-19, true', () async {
      feedback.nextDialogResult = true;

      expect(await notifier.askNotificationPermission(), isTrue);

      expect(feedback.dialogs, [DialogId.dlg03]);
      expect(feedback.lastDialogBuilder, isNull);
      expect(permissions.requested, [Permission.notification]);
      expect(feedback.toasts, [ToastId.tst19]);
      expect(feedback.hasToastAction, isFalse);
    });

    test('iOS sessiz bildirim izni (provisional) verilmiş sayılır', () async {
      permissions.results[Permission.notification] =
          PermissionStatus.provisional;
      feedback.nextDialogResult = true;

      expect(await notifier.askNotificationPermission(), isTrue);
      expect(feedback.toasts, [ToastId.tst19]);
    });

    test('sistem izni reddedilirse false; toast yok', () async {
      for (final status in [
        PermissionStatus.denied,
        PermissionStatus.permanentlyDenied,
      ]) {
        permissions.results[Permission.notification] = status;
        feedback.nextDialogResult = true;

        expect(await notifier.askNotificationPermission(), isFalse);
      }
      expect(permissions.requested, List.filled(2, Permission.notification));
      expect(feedback.toasts, isEmpty);
    });

    test(
      '"Şimdi değil" ve scrim / geri: sistem izni istenmez, false',
      () async {
        for (final choice in [false, null]) {
          feedback.nextDialogResult = choice;

          expect(await notifier.askNotificationPermission(), isFalse);
        }
        expect(permissions.requested, isEmpty);
        expect(feedback.toasts, isEmpty);
      },
    );

    test('"bir kez" bayrağını okumaz ve yazmaz (çağıran işaretler)', () async {
      prefs.values[AppPreferenceKeys.notificationPermissionAsked] = true;
      feedback.nextDialogResult = true;

      await notifier.askNotificationPermission();

      expect(feedback.dialogs, [DialogId.dlg03]);
      expect(prefs.calls, isEmpty);
    });
  });
}

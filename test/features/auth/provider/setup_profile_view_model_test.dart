// AUT-05 · SetupProfileViewModel (PLAN §12.5): başlangıç kimliği, adım
// geçişleri ve doğrulama, ilgi alanı sınırı (TST-04), fotoğraf seçimi ve izin
// akışı (DLG-04, DLG-05, TST-32), gönderim sırası (W-56, W-57: createProfile
// → updateProfile → updateAvatar → oturum yenileme; TST-57, TST-05), hata
// yolları ve art arda tetik.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/auth/provider/setup_profile_state.dart';
import 'package:gu_kulupler/features/auth/provider/setup_profile_view_model.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';
import 'package:gu_kulupler/product/service/image_picker_service.dart';
import 'package:gu_kulupler/product/service/permission_service.dart';

import '../../../fakes/fake_app_preferences_store.dart';
import '../../../fakes/fake_auth_service.dart';
import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_image_picker_service.dart';
import '../../../fakes/fake_permission_service.dart';
import '../../../fakes/fake_user_repository.dart';
import '../../../fakes/register_fakes.dart';
import '../../../helpers/test_container.dart';

const String _uid = 'u1';
const String _email = 'ayse.yilmaz@ogr.gumushane.edu.tr';
const String _name = 'Ayşe Yılmaz';

FakeAuthService _auth() => GetIt.I<AuthService>() as FakeAuthService;

FakeUserRepository _users() => switch (GetIt.I<UserRepository>()) {
  final FakeUserRepository fake => fake,
  final _AvatarFailingUsers wrapper => wrapper._inner,
  final other => throw StateError('Beklenmeyen UserRepository: $other'),
};

FakeFeedbackService _feedback() =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;

FakeConnectivityService _connectivity() =>
    GetIt.I<ConnectivityService>() as FakeConnectivityService;

FakePermissionService _permissions() =>
    GetIt.I<PermissionService>() as FakePermissionService;

FakeImagePickerService _picker() =>
    GetIt.I<ImagePickerService>() as FakeImagePickerService;

FakeAppPreferencesStore _preferences() =>
    GetIt.I<AppPreferencesStore>() as FakeAppPreferencesStore;

/// Doğrulanmış oturum açar (profil belgesi henüz yok).
void _signIn({String? displayName = _name, String? email = _email}) =>
    _auth().currentUser = AuthUserInfo(
      uid: _uid,
      email: email,
      emailVerified: true,
      displayName: displayName,
    );

/// Kapsayıcıyı kurar, oturumu çözer ve ViewModel'i test boyunca canlı tutar.
Future<ProviderContainer> _container() async {
  final container = createContainer();
  addTearDown(container.listen(sessionViewModelProvider, (_, _) {}).close);
  await pumpEventQueue();
  addTearDown(
    container.listen(setupProfileViewModelProvider, (_, _) {}).close,
  );
  return container;
}

SetupProfileViewModel _viewModel(ProviderContainer container) =>
    container.read(setupProfileViewModelProvider.notifier);

SetupProfileState _state(ProviderContainer container) =>
    container.read(setupProfileViewModelProvider);

AuthStatus _status(ProviderContainer container) =>
    container.read(sessionViewModelProvider).status;

/// Formu son adıma kadar geçerli doldurur (fotoğrafsız).
Future<void> _fillValid(SetupProfileViewModel viewModel) async {
  await viewModel.next();
  viewModel
    ..setDepartment('d01')
    ..setYear(YearLevel.second);
  await viewModel.next();
  viewModel
    ..toggleInterest('i06')
    ..toggleInterest('i01');
}

void main() {
  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
  });

  group('AUT-05 · SetupProfileViewModel · başlangıç', () {
    test(
      'ad kimlik hesabının görünen adı, tohum uid; ilk adım, boş form',
      () async {
        _signIn();
        final container = await _container();

        expect(_status(container), AuthStatus.profileIncomplete);
        expect(
          _state(container),
          const SetupProfileState(name: _name, avatarSeed: _uid),
        );
      },
    );

    test(
      'görünen ad yoksa e-postanın yerel kısmı kullanılır (CD-134)',
      () async {
        _signIn(displayName: null);
        final container = await _container();

        expect(_state(container).name, 'ayse.yilmaz');
      },
    );

    test('yarım kalmış profil belgesi varsa ad, tohum ve personel bayrağı '
        'belgeden gelir', () async {
      _signIn();
      _users().users[_uid] = const UserModel(
        uid: _uid,
        name: 'Ayşe Y.',
        nameLower: 'ayşe y.',
        avatarSeed: 'tohum',
        staff: true,
      );
      final container = await _container();

      expect(
        _state(container),
        const SetupProfileState(
          name: 'Ayşe Y.',
          avatarSeed: 'tohum',
          isStaff: true,
        ),
      );
    });

    test('oturum yoksa kimlik alanları boştur', () async {
      final container = await _container();

      expect(_state(container), const SetupProfileState());
    });
  });

  group('AUT-05 · SetupProfileViewModel · adımlar ve doğrulama', () {
    test('next: fotoğraf adımı doğrulamasız geçilir', () async {
      _signIn();
      final container = await _container();

      expect(await _viewModel(container).next(), SetupProfileOutcome.advanced);
      expect(_state(container).step, SetupStep.info);
      expect(_state(container).errors, isEmpty);
      expect(_state(container).isDirty, isFalse);
    });

    test(
      'skipPhoto: eğitim adımına geçer, seçilmiş fotoğraf korunur',
      () async {
        _signIn();
        _preferences().values[AppPreferenceKeys.photoAccessExplained] = true;
        final container = await _container();
        final viewModel = _viewModel(container);
        await viewModel.pickAvatar(MediaSource.gallery);

        viewModel.skipPhoto();

        expect(_state(container).step, SetupStep.info);
        expect(_state(container).avatar, same(kFakeJpeg));
      },
    );

    test('next: eğitim adımında bölüm ve sınıf zorunlu', () async {
      _signIn();
      final container = await _container();
      final viewModel = _viewModel(container);
      await viewModel.next();

      expect(await viewModel.next(), SetupProfileOutcome.invalid);
      expect(_state(container).step, SetupStep.info);
      expect(_state(container).errors, {
        SetupProfileField.department: FormFieldError.required,
        SetupProfileField.year: FormFieldError.required,
      });
    });

    test('setDepartment / setYear değeri yazar, formu kirletir ve yalnızca '
        'kendi hatasını siler', () async {
      _signIn();
      final container = await _container();
      final viewModel = _viewModel(container);
      await viewModel.next();
      await viewModel.next();

      viewModel.setDepartment('d07');
      expect(_state(container).departmentId, 'd07');
      expect(_state(container).isDirty, isTrue);
      expect(_state(container).errors, {
        SetupProfileField.year: FormFieldError.required,
      });

      viewModel.setYear(YearLevel.master);
      expect(_state(container).year, YearLevel.master);
      expect(_state(container).errors, isEmpty);

      expect(await viewModel.next(), SetupProfileOutcome.advanced);
      expect(_state(container).step, SetupStep.interests);
    });

    test('validate: görünen adımın kurallarını çalıştırır', () async {
      _signIn();
      final container = await _container();
      final viewModel = _viewModel(container);

      expect(viewModel.validate(), isTrue);

      viewModel.setStep(SetupStep.interests);
      expect(viewModel.validate(), isFalse);
      expect(_state(container).errors, {
        SetupProfileField.interests: FormFieldError.required,
      });

      viewModel.toggleInterest('i03');
      expect(_state(container).errors, isEmpty);
      expect(viewModel.validate(), isTrue);
    });

    test(
      'back: önceki adıma döner, hataları siler; ilk adımda etkisiz',
      () async {
        _signIn();
        final container = await _container();
        final viewModel = _viewModel(container);
        await viewModel.next();
        await viewModel.next();
        expect(_state(container).errors, isNotEmpty);

        viewModel.back();
        expect(_state(container).step, SetupStep.photo);
        expect(_state(container).errors, isEmpty);

        viewModel.back();
        expect(_state(container).step, SetupStep.photo);
      },
    );

    test('setStep: aynı adımda durum değişmez; adım değişince sunucu hatası '
        'silinir', () async {
      _signIn();
      final container = await _container();
      final viewModel = _viewModel(container);
      final before = _state(container);

      viewModel.setStep(SetupStep.photo);
      expect(_state(container), same(before));

      await _fillValid(viewModel);
      _users().failNext(FirestoreError.permissionDenied);
      await viewModel.submit();
      expect(_state(container).submitError, SetupProfileError.unknown);

      viewModel.setStep(SetupStep.info);
      expect(_state(container).submitError, isNull);
    });

    test('personel: sınıf ve ilgi alanı zorunlu değildir', () async {
      _signIn();
      _users().users[_uid] = const UserModel(
        uid: _uid,
        name: _name,
        nameLower: 'ayşe yılmaz',
        avatarSeed: _uid,
        staff: true,
      );
      final container = await _container();
      final viewModel = _viewModel(container);
      await viewModel.next();

      expect(await viewModel.next(), SetupProfileOutcome.invalid);
      expect(_state(container).errors, {
        SetupProfileField.department: FormFieldError.required,
      });

      viewModel.setDepartment('d02');
      expect(await viewModel.next(), SetupProfileOutcome.advanced);
      expect(await viewModel.next(), SetupProfileOutcome.success);

      final patch = _users().profilePatches.single.patch;
      expect(patch.department, 'd02');
      expect(patch.year, isNull);
      expect(patch.interests, isEmpty);
      expect(patch.profileComplete, isTrue);
      expect(_users().createdProfiles, isEmpty);
      expect(_status(container), AuthStatus.active);
    });
  });

  group('AUT-05 · SetupProfileViewModel · ilgi alanları (TST-04)', () {
    test('toggleInterest seçer / kaldırır ve formu kirletir', () async {
      _signIn();
      final container = await _container();
      final viewModel = _viewModel(container);

      expect(viewModel.toggleInterest('i02'), isTrue);
      expect(viewModel.toggleInterest('i05'), isTrue);
      expect(_state(container).interests, {'i02', 'i05'});
      expect(_state(container).isDirty, isTrue);

      expect(viewModel.toggleInterest('i02'), isTrue);
      expect(_state(container).interests, {'i05'});
      expect(_feedback().toasts, isEmpty);
    });

    test('altıncı seçim yapılmaz: TST-04; seçimi kaldırmak sınırdayken de '
        'serbesttir', () async {
      _signIn();
      final container = await _container();
      final viewModel = _viewModel(container);
      const five = {'i01', 'i02', 'i03', 'i04', 'i05'};
      expect(five.length, Limits.interestsMax);
      five.forEach(viewModel.toggleInterest);

      expect(viewModel.toggleInterest('i06'), isFalse);
      expect(_state(container).interests, five);
      expect(_feedback().toasts, [ToastId.tst04]);

      expect(viewModel.toggleInterest('i01'), isTrue);
      expect(viewModel.toggleInterest('i06'), isTrue);
      expect(_state(container).interests, {'i02', 'i03', 'i04', 'i05', 'i06'});
      expect(_feedback().toasts, [ToastId.tst04]);
    });
  });

  group(
    'AUT-05 · SetupProfileViewModel · fotoğraf (DLG-04, DLG-05, TST-32)',
    () {
      test(
        'galeri: DLG-05 "İzin ver" → seçici → önizleme; onay hatırlanır',
        () async {
          _signIn();
          final container = await _container();
          final viewModel = _viewModel(container);
          _feedback().nextDialogResult = true;

          await viewModel.pickAvatar(MediaSource.gallery);

          expect(_feedback().dialogs, [DialogId.dlg05]);
          expect(_picker().picks, [MediaSource.gallery]);
          expect(_permissions().requested, isEmpty);
          expect(_state(container).avatar, same(kFakeJpeg));
          expect(_state(container).hasPhoto, isTrue);
          expect(_state(container).isDirty, isTrue);
          expect(_preferences().photoAccessExplained, isTrue);

          // İkinci seçimde ön açıklama yeniden sorulmaz.
          await viewModel.pickAvatar(MediaSource.gallery);
          expect(_feedback().dialogs, [DialogId.dlg05]);
          expect(_picker().picks, [MediaSource.gallery, MediaSource.gallery]);
        },
      );

      test(
        'galeri: DLG-05 "Şimdi değil" → seçici açılmaz, durum değişmez',
        () async {
          _signIn();
          final container = await _container();
          final before = _state(container);
          _feedback().nextDialogResult = false;

          await _viewModel(container).pickAvatar(MediaSource.gallery);

          expect(_feedback().dialogs, [DialogId.dlg05]);
          expect(_picker().picks, isEmpty);
          expect(_state(container), before);
          expect(_feedback().toasts, isEmpty);
        },
      );

      test(
        'kamera: DLG-04 "İzin ver" → sistem izni → çekim → önizleme',
        () async {
          _signIn();
          final container = await _container();
          _feedback().nextDialogResult = true;

          await _viewModel(container).pickAvatar(MediaSource.camera);

          expect(_feedback().dialogs, [DialogId.dlg04]);
          expect(_permissions().requested, [Permission.camera]);
          expect(_picker().picks, [MediaSource.camera]);
          expect(_state(container).avatar, same(kFakeJpeg));
        },
      );

      test('kamera: izin zaten verilmişse DLG-04 sorulmaz', () async {
        _signIn();
        _permissions().results[Permission.camera] = PermissionStatus.granted;
        final container = await _container();

        await _viewModel(container).pickAvatar(MediaSource.camera);

        expect(_feedback().dialogs, isEmpty);
        expect(_permissions().requested, isEmpty);
        expect(_state(container).hasPhoto, isTrue);
      });

      test('kamera: kalıcı ret → TST-32 "Ayarlara git" → sistem ayarları; '
          'fotoğraf ve hata yazılmaz', () async {
        _signIn();
        _permissions().results[Permission.camera] =
            PermissionStatus.permanentlyDenied;
        final container = await _container();
        _feedback().nextDialogResult = true;

        await _viewModel(container).pickAvatar(MediaSource.camera);

        expect(_feedback().dialogs, [DialogId.dlg04]);
        expect(_feedback().toasts, [ToastId.tst32]);
        expect(_picker().picks, isEmpty);
        expect(_state(container).avatar, isNull);
        expect(_state(container).errors, isEmpty);
        expect(_state(container).isDirty, isFalse);

        _feedback().tapToastAction();
        await pumpEventQueue();
        expect(_permissions().openedSettings, 1);
      });

      test('kamera: DLG-04 "Şimdi değil" → izin istenmez, toast yok', () async {
        _signIn();
        final container = await _container();
        _feedback().nextDialogResult = false;

        await _viewModel(container).pickAvatar(MediaSource.camera);

        expect(_permissions().requested, isEmpty);
        expect(_picker().picks, isEmpty);
        expect(_feedback().toasts, isEmpty);
        expect(_state(container).avatar, isNull);
      });

      test('seçiciden vazgeçilirse durum değişmez', () async {
        _signIn();
        _preferences().values[AppPreferenceKeys.photoAccessExplained] = true;
        _picker().nextPick = null;
        final container = await _container();
        final before = _state(container);

        await _viewModel(container).pickAvatar(MediaSource.gallery);

        expect(_picker().picks, [MediaSource.gallery]);
        expect(_state(container), before);
      });

      test('görsel işlenemezse fotoğraf alanına hata yazılır; sonraki başarılı '
          'seçim hatayı siler', () async {
        _signIn();
        _preferences().values[AppPreferenceKeys.photoAccessExplained] = true;
        final container = await _container();
        final viewModel = _viewModel(container);

        _picker().nextError = ImagePickError.tooLarge;
        await viewModel.pickAvatar(MediaSource.gallery);
        expect(_state(container).errors, {
          SetupProfileField.photo: FormFieldError.limitExceeded,
        });
        expect(_state(container).avatar, isNull);
        expect(_state(container).isDirty, isFalse);

        _picker().nextError = ImagePickError.unreadable;
        await viewModel.pickAvatar(MediaSource.gallery);
        expect(_state(container).errors, {
          SetupProfileField.photo: FormFieldError.invalidFormat,
        });
        expect(_feedback().toasts, isEmpty);

        await viewModel.pickAvatar(MediaSource.gallery);
        expect(_state(container).errors, isEmpty);
        expect(_state(container).avatar, same(kFakeJpeg));
      });

      test(
        'art arda pickAvatar: süren seçim varken ikinci çağrı yok sayılır',
        () async {
          _signIn();
          _preferences().values[AppPreferenceKeys.photoAccessExplained] = true;
          final container = await _container();
          final viewModel = _viewModel(container);

          await Future.wait([
            viewModel.pickAvatar(MediaSource.gallery),
            viewModel.pickAvatar(MediaSource.gallery),
          ]);
          expect(_picker().picks, [MediaSource.gallery]);

          await viewModel.pickAvatar(MediaSource.gallery);
          expect(_picker().picks, hasLength(2));
        },
      );
    },
  );

  group('AUT-05 · SetupProfileViewModel · gönderim', () {
    test('fotoğrafsız başarı: createProfile → updateProfile → oturum aktif → '
        'TST-05 (ilk ad)', () async {
      _signIn();
      final container = await _container();
      final viewModel = _viewModel(container);
      await _fillValid(viewModel);

      expect(await viewModel.next(), SetupProfileOutcome.success);

      final users = _users();
      expect(users.createdProfiles, [
        (
          uid: _uid,
          email: _email,
          name: _name,
          nameLower: 'ayşe yılmaz',
          avatarSeed: _uid,
        ),
      ]);
      // İlgi alanları seçim sırasıyla değil, tablo sırasıyla yazılır.
      expect(users.profilePatches, [
        (
          uid: _uid,
          patch: const UserProfilePatch(
            department: 'd01',
            year: YearLevel.second,
            interests: ['i01', 'i06'],
            profileComplete: true,
          ),
        ),
      ]);
      expect(users.avatarUploads, isEmpty);
      expect(
        [
          for (final call in users.calls)
            if (call.method != 'getUser') call.method,
        ],
        ['createProfile', 'updateProfile'],
      );
      expect(_status(container), AuthStatus.active);
      expect(_feedback().toasts, [ToastId.tst05]);
      expect(_feedback().toastParams.single.name, 'Ayşe');
      // Ekran yönlendirmeyle kapanana kadar form kilitlidir.
      expect(_state(container).isSubmitting, isTrue);
      expect(_state(container).submitError, isNull);
    });

    test('fotoğraflı başarı: updateAvatar profil yamasından SONRA ve yamasız '
        'çağrılır (W-57); TST-57 → TST-05', () async {
      _signIn();
      _preferences().values[AppPreferenceKeys.photoAccessExplained] = true;
      final container = await _container();
      final viewModel = _viewModel(container);
      await viewModel.pickAvatar(MediaSource.gallery);
      await _fillValid(viewModel);

      expect(await viewModel.submit(), SetupProfileOutcome.success);

      final users = _users();
      expect(
        [
          for (final call in users.calls)
            if (call.method != 'getUser') call.method,
        ],
        ['createProfile', 'updateProfile', 'updateAvatar'],
      );
      final upload = users.avatarUploads.single;
      expect(upload.uid, _uid);
      expect(upload.bytes, same(kFakeJpeg.bytes));
      expect(upload.contentType, 'image/jpeg');
      expect(upload.profile, isNull);
      expect(users.users[_uid]!.avatarPath, upload.path);
      expect(users.users[_uid]!.profileComplete, isTrue);
      expect(_feedback().toasts, [ToastId.tst57, ToastId.tst05]);
      expect(_feedback().visibleToast, ToastId.tst05);
      expect(_state(container).uploadProgress, 1);
      expect(_status(container), AuthStatus.active);
    });

    test('nameLower Türkçe küçük harfle üretilir (CD-11)', () async {
      _signIn(displayName: 'IŞIL İNCİ');
      final container = await _container();
      final viewModel = _viewModel(container);
      await _fillValid(viewModel);

      await viewModel.submit();

      expect(_users().createdProfiles.single.nameLower, 'ışıl inci');
      expect(_feedback().toastParams.single.name, 'IŞIL');
    });

    test('profil belgesi zaten varsa createProfile çağrılmaz', () async {
      _signIn();
      _users().users[_uid] = const UserModel(
        uid: _uid,
        name: _name,
        nameLower: 'ayşe yılmaz',
        avatarSeed: _uid,
      );
      final container = await _container();
      final viewModel = _viewModel(container);
      await _fillValid(viewModel);

      expect(await viewModel.submit(), SetupProfileOutcome.success);
      expect(_users().callsTo('createProfile'), isEmpty);
      expect(_users().profilePatches, hasLength(1));
    });

    test('ilgi alanı seçilmeden gönderim: hata, hiçbir şey yazılmaz', () async {
      _signIn();
      final container = await _container();
      final viewModel = _viewModel(container);
      await viewModel.next();
      viewModel
        ..setDepartment('d01')
        ..setYear(YearLevel.first);
      await viewModel.next();

      expect(await viewModel.next(), SetupProfileOutcome.invalid);
      expect(_state(container).errors, {
        SetupProfileField.interests: FormFieldError.required,
      });
      expect(_state(container).isSubmitting, isFalse);
      expect(_users().callsTo('createProfile'), isEmpty);
      expect(_users().callsTo('updateProfile'), isEmpty);
    });

    test('önceki adımda eksik alan varsa gönderim o adıma döner', () async {
      _signIn();
      final container = await _container();
      final viewModel = _viewModel(container)
        ..setStep(SetupStep.interests)
        ..toggleInterest('i01');

      expect(await viewModel.submit(), SetupProfileOutcome.invalid);
      expect(_state(container).step, SetupStep.info);
      expect(_state(container).errors, {
        SetupProfileField.department: FormFieldError.required,
        SetupProfileField.year: FormFieldError.required,
      });
      expect(_users().callsTo('createProfile'), isEmpty);
    });

    test('çevrimdışı: TST-24, hiçbir şey yazılmaz, form açık kalır', () async {
      _signIn();
      final container = await _container();
      final viewModel = _viewModel(container);
      await _fillValid(viewModel);
      _connectivity().isOffline = true;

      expect(await viewModel.submit(), SetupProfileOutcome.offline);
      expect(_feedback().toasts, [ToastId.tst24]);
      expect(_users().callsTo('createProfile'), isEmpty);
      expect(_state(container).isSubmitting, isFalse);
      expect(_state(container).submitError, isNull);
    });

    test('oturumda kimlik yoksa gönderim başarısız olur', () async {
      final container = await _container();
      final viewModel = _viewModel(container);
      await _fillValid(viewModel);

      expect(await viewModel.submit(), SetupProfileOutcome.failed);
      expect(_state(container).submitError, SetupProfileError.unknown);
      expect(_state(container).isSubmitting, isFalse);
      expect(_users().callsTo('createProfile'), isEmpty);
    });

    test('createProfile reddedilirse (doğrulanmamış oturum) profil yaması '
        'gönderilmez', () async {
      _signIn();
      final container = await _container();
      final viewModel = _viewModel(container);
      await _fillValid(viewModel);
      _users().failNext(FirestoreError.permissionDenied);

      expect(await viewModel.submit(), SetupProfileOutcome.failed);
      expect(_state(container).submitError, SetupProfileError.unknown);
      expect(_state(container).isSubmitting, isFalse);
      expect(_users().callsTo('updateProfile'), isEmpty);
      expect(_feedback().toasts, isEmpty);
      expect(_status(container), AuthStatus.profileIncomplete);
    });

    for (final error in [
      FirestoreError.unavailable,
      FirestoreError.timeout,
      FirestoreError.offline,
    ]) {
      test('ağ hatası (${error.name}): TST-24 + network', () async {
        _signIn();
        final container = await _container();
        final viewModel = _viewModel(container);
        await _fillValid(viewModel);
        _users().failNext(error);

        expect(await viewModel.submit(), SetupProfileOutcome.failed);
        expect(_state(container).submitError, SetupProfileError.network);
        expect(_feedback().toasts, [ToastId.tst24]);
        expect(_state(container).isSubmitting, isFalse);
      });
    }

    test('updateProfile başarısız olursa fotoğraf yüklenmez; yeniden deneme '
        'güvenlidir', () async {
      _signIn();
      _preferences().values[AppPreferenceKeys.photoAccessExplained] = true;
      // Profil belgesi var (createProfile atlanır): bekleyen hata
      // updateProfile çağrısına gider.
      final users = _users();
      users.users[_uid] = const UserModel(
        uid: _uid,
        name: _name,
        nameLower: 'ayşe yılmaz',
        avatarSeed: _uid,
      );
      final container = await _container();
      final viewModel = _viewModel(container);
      await viewModel.pickAvatar(MediaSource.gallery);
      await _fillValid(viewModel);

      users.failNext(FirestoreError.permissionDenied);
      expect(await viewModel.submit(), SetupProfileOutcome.failed);
      expect(users.callsTo('updateProfile'), hasLength(1));
      expect(users.callsTo('updateAvatar'), isEmpty);
      expect(users.users[_uid]!.profileComplete, isFalse);
      expect(_state(container).submitError, SetupProfileError.unknown);
      expect(_state(container).isSubmitting, isFalse);
      // Form ve seçilen fotoğraf yerinde.
      expect(_state(container).avatar, same(kFakeJpeg));
      expect(_state(container).interests, {'i01', 'i06'});

      expect(await viewModel.submit(), SetupProfileOutcome.success);
      expect(users.profilePatches, hasLength(1));
      expect(users.avatarUploads, hasLength(1));
      expect(_state(container).submitError, isNull);
      expect(_status(container), AuthStatus.active);
    });

    test('createProfile sonrası yarıda kalan gönderim yeniden denenince '
        'profil bir kez oluşur', () async {
      _signIn();
      final container = await _container();
      final viewModel = _viewModel(container);
      await _fillValid(viewModel);
      final users = _users()..failNext(FirestoreError.aborted);

      expect(await viewModel.submit(), SetupProfileOutcome.failed);
      expect(users.createdProfiles, isEmpty);

      expect(await viewModel.submit(), SetupProfileOutcome.success);
      expect(users.createdProfiles, hasLength(1));
      expect(users.profilePatches, hasLength(1));
    });

    test('fotoğraf yüklenemezse profil yine tamamlanır: TST-57 yok, TST-05 '
        'var', () async {
      _signIn();
      _preferences().values[AppPreferenceKeys.photoAccessExplained] = true;
      final users = await _failAvatarWith(StorageError.unauthorized);
      final container = await _container();
      final viewModel = _viewModel(container);
      await viewModel.pickAvatar(MediaSource.gallery);
      await _fillValid(viewModel);

      expect(await viewModel.submit(), SetupProfileOutcome.success);

      expect(users.callsTo('updateAvatar'), hasLength(1));
      expect(users.avatarUploads, isEmpty);
      expect(users.users[_uid]!.profileComplete, isTrue);
      expect(users.users[_uid]!.avatarPath, isNull);
      expect(_status(container), AuthStatus.active);
      expect(_feedback().toasts, [ToastId.tst05]);
      expect(_state(container).submitError, isNull);
    });

    for (final error in <Object>[
      StorageError.retryLimitExceeded,
      StorageError.timeout,
      FirestoreError.unavailable,
    ]) {
      test('fotoğraf bağlantı koptuğu için yüklenemezse ($error) profil '
          'tamamlanır ve karşılama yerine TST-24 gösterilir', () async {
        _signIn();
        _preferences().values[AppPreferenceKeys.photoAccessExplained] = true;
        final users = await _failAvatarWith(error);
        final container = await _container();
        final viewModel = _viewModel(container);
        await viewModel.pickAvatar(MediaSource.gallery);
        await _fillValid(viewModel);

        expect(await viewModel.submit(), SetupProfileOutcome.success);

        expect(users.users[_uid]!.profileComplete, isTrue);
        expect(users.users[_uid]!.avatarPath, isNull);
        expect(_status(container), AuthStatus.active);
        expect(_feedback().toasts, [ToastId.tst24]);
      });
    }

    test('oturum yenilenemezse form açılır; yeniden deneme tamamlar', () async {
      _signIn();
      _preferences().values[AppPreferenceKeys.photoAccessExplained] = true;
      final container = await _container();
      final viewModel = _viewModel(container);
      await viewModel.pickAvatar(MediaSource.gallery);
      await _fillValid(viewModel);
      final users = _users();

      // Yükleme kapıda beklerken kurulan hata sıradaki çağrıya — oturum
      // yenilemesindeki `getUser` okumasına — kalır.
      final gate = Completer<void>();
      users.avatarUploadGate = gate;
      final first = viewModel.submit();
      await pumpEventQueue();
      expect(users.callsTo('updateAvatar'), hasLength(1));
      users
        ..failNext(FirestoreError.unavailable)
        ..avatarUploadGate = null;
      gate.complete();

      expect(await first, SetupProfileOutcome.failed);
      expect(_status(container), AuthStatus.profileIncomplete);
      expect(_state(container).isSubmitting, isFalse);
      expect(_state(container).submitError, SetupProfileError.unknown);
      expect(_state(container).uploadProgress, isNull);
      expect(_feedback().toasts, [ToastId.tst57]);

      expect(await viewModel.submit(), SetupProfileOutcome.success);
      expect(users.createdProfiles, hasLength(1));
      expect(_status(container), AuthStatus.active);
      expect(_feedback().toasts.last, ToastId.tst05);
    });

    test(
      'art arda submit: süren gönderim varken ikinci çağrı yok sayılır',
      () async {
        _signIn();
        final container = await _container();
        final viewModel = _viewModel(container);
        await _fillValid(viewModel);

        final first = viewModel.submit();
        expect(_state(container).isSubmitting, isTrue);
        expect(await viewModel.submit(), SetupProfileOutcome.ignored);
        expect(await viewModel.next(), SetupProfileOutcome.ignored);
        expect(await first, SetupProfileOutcome.success);

        expect(_users().callsTo('createProfile'), hasLength(1));
        expect(_users().profilePatches, hasLength(1));
        expect(_feedback().toasts, [ToastId.tst05]);
      },
    );

    test('gönderim sürerken form kilitlidir', () async {
      _signIn();
      _preferences().values[AppPreferenceKeys.photoAccessExplained] = true;
      final container = await _container();
      final viewModel = _viewModel(container);
      await viewModel.pickAvatar(MediaSource.gallery);
      await _fillValid(viewModel);
      final gate = Completer<void>();
      _users().avatarUploadGate = gate;

      final pending = viewModel.submit();
      await pumpEventQueue();
      final locked = _state(container);
      expect(locked.isSubmitting, isTrue);
      expect(locked.uploadProgress, 1);

      expect(viewModel.toggleInterest('i09'), isFalse);
      viewModel
        ..setDepartment('d20')
        ..setYear(YearLevel.phd)
        ..setStep(SetupStep.photo)
        ..back()
        ..skipPhoto();
      await viewModel.pickAvatar(MediaSource.camera);
      expect(_state(container), locked);
      expect(_picker().picks, [MediaSource.gallery]);

      gate.complete();
      expect(await pending, SetupProfileOutcome.success);
    });
  });
}

/// Kayıtlı fake'i, `updateAvatar` çağrısını [error] ile düşüren bir
/// sarmalayıcıyla değiştirir ve içteki fake'i döndürür.
///
/// Ortak fake'in tek seferlik `failNext` hatası sıradaki **ilk** çağrıya
/// (`createProfile` / `updateProfile`) gider; yükleme adımını hedeflemek için
/// hata çağrı anında kurulur. [error] `StorageError` ise yükleme, değilse
/// belge adımı başarısız olur.
Future<FakeUserRepository> _failAvatarWith(Object error) async {
  final inner = _users();
  await GetIt.I.unregister<UserRepository>();
  GetIt.I.registerSingleton<UserRepository>(_AvatarFailingUsers(inner, error));
  return inner;
}

final class _AvatarFailingUsers implements UserRepository {
  _AvatarFailingUsers(this._inner, this._error);

  final FakeUserRepository _inner;
  final Object _error;

  @override
  Future<MediaUpdateResult<String>> updateAvatar(
    String uid, {
    required Uint8List bytes,
    required String contentType,
    UserProfilePatch? profile,
    void Function(double fraction)? onProgress,
  }) {
    _inner.failNext(_error);
    return _inner.updateAvatar(
      uid,
      bytes: bytes,
      contentType: contentType,
      profile: profile,
      onProgress: onProgress,
    );
  }

  @override
  Future<FirestoreResult<UserModel?>> getUser(String uid) =>
      _inner.getUser(uid);

  @override
  Future<FirestoreResult<List<UserModel>>> getUsers(List<String> uids) =>
      _inner.getUsers(uids);

  @override
  Future<FirestoreResult<void>> createProfile({
    required String uid,
    required String email,
    required String name,
    required String nameLower,
    required String avatarSeed,
  }) => _inner.createProfile(
    uid: uid,
    email: email,
    name: name,
    nameLower: nameLower,
    avatarSeed: avatarSeed,
  );

  @override
  Future<FirestoreResult<void>> updateProfile(
    String uid,
    UserProfilePatch patch,
  ) => _inner.updateProfile(uid, patch);

  @override
  Future<FirestoreResult<UserAccountModel?>> getPrivateAccount(String uid) =>
      _inner.getPrivateAccount(uid);

  @override
  Future<FirestoreResult<void>> touchLastLogin(String uid) =>
      _inner.touchLastLogin(uid);
}

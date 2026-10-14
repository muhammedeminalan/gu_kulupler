// PRF-02 · EditProfileViewModel (PLAN §12.6): formun oturumdaki profilden
// kurulması + e-postanın gizli hesap belgesinden okunması (D-29), kirli
// takibi, doğrulama dalları, ilgi alanı sınırı (TST-04), kilitli alan
// (TST-20), kaydetme (TST-X9, TST-21, TST-57, TST-24, TST-X18) ve fotoğraf
// akışı (updateAvatar + profil yaması tek yazım, CD-135).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/profile/provider/edit_profile_state.dart';
import 'package:gu_kulupler/features/profile/provider/edit_profile_view_model.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';
import 'package:gu_kulupler/product/service/image_picker_service.dart';

import '../../../fakes/fake_app_preferences_store.dart';
import '../../../fakes/fake_auth_service.dart';
import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_image_picker_service.dart';
import '../../../fakes/fake_user_repository.dart';
import '../../../fakes/register_fakes.dart';
import '../../../fixtures/user_model_fixtures.dart';
import '../../../helpers/test_container.dart';

const String _uid = 'u_mehmet';
const String _email = 'mehmet.kaya@ogr.gumushane.edu.tr';

/// Referans görüntüdeki kullanıcı (demo veri): d02, 3. sınıf, 4 ilgi alanı.
final UserModel _mehmet = UserModelFixtures.byId(_uid);

FakeUserRepository _users() => GetIt.I<UserRepository>() as FakeUserRepository;

FakeFeedbackService _feedback() =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;

FakeConnectivityService _connectivity() =>
    GetIt.I<ConnectivityService>() as FakeConnectivityService;

FakeImagePickerService _picker() =>
    GetIt.I<ImagePickerService>() as FakeImagePickerService;

/// Profili tamamlanmış [user] ile doğrulanmış oturum açar.
void _signIn([UserModel? user]) {
  final profile = user ?? _mehmet;
  _users()
    ..users[_uid] = profile
    ..accounts[_uid] = const UserAccountModel(
      email: _email,
      emailLower: _email,
    );
  (GetIt.I<AuthService>() as FakeAuthService).currentUser = AuthUserInfo(
    uid: _uid,
    email: _email,
    emailVerified: true,
    displayName: profile.name,
  );
}

/// Kapsayıcıyı kurar, oturumu çözer ve ViewModel'i test boyunca canlı tutar
/// (e-posta okuması da biter).
Future<ProviderContainer> _container() async {
  final container = createContainer();
  addTearDown(container.listen(sessionViewModelProvider, (_, _) {}).close);
  await pumpEventQueue();
  expect(container.read(sessionViewModelProvider).status, AuthStatus.active);
  addTearDown(container.listen(editProfileViewModelProvider, (_, _) {}).close);
  await pumpEventQueue();
  return container;
}

EditProfileViewModel _viewModel(ProviderContainer container) =>
    container.read(editProfileViewModelProvider.notifier);

EditProfileState _state(ProviderContainer container) =>
    container.read(editProfileViewModelProvider);

void main() {
  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
  });

  group('PRF-02 · EditProfileViewModel · kurulum', () {
    test('form oturumdaki profilden kurulur, e-posta private/account '
        'belgesinden okunur; form temiz', () async {
      _signIn();
      final container = await _container();
      final state = _state(container);

      expect(state.original, _mehmet);
      expect(state.name, 'Mehmet Kaya');
      expect(state.departmentId, 'd02');
      expect(state.year, YearLevel.third);
      expect(state.interests, {'i01', 'i06', 'i07', 'i11'});
      expect(state.bio, _mehmet.bio);
      expect(state.email, _email);
      expect(state.isDirty, isFalse);
      expect(_users().callsTo('getPrivateAccount'), hasLength(1));
    });

    test(
      'hesap belgesi okunamazsa e-posta boş kalır, form kullanılır',
      () async {
        _signIn();
        _users().accounts.remove(_uid);
        final container = await _container();

        expect(_state(container).email, isEmpty);
        expect(_state(container).original, isNotNull);
      },
    );
  });

  group('PRF-02 · EditProfileViewModel · kirli takibi ve sınırlar', () {
    test('değer özgün haline dönünce form temizlenir (ad kırpılır, ilgi '
        'alanı kümesi sırasız)', () async {
      _signIn();
      final container = await _container();
      final viewModel = _viewModel(container)..setName('Mehmet K.');
      expect(_state(container).isDirty, isTrue);

      viewModel.setName(' Mehmet Kaya ');
      expect(_state(container).isDirty, isFalse);

      expect(viewModel.toggleInterest('i01'), isTrue);
      expect(_state(container).isDirty, isTrue);
      expect(viewModel.toggleInterest('i01'), isTrue);
      expect(_state(container).isDirty, isFalse);

      viewModel
        ..setDepartment('d10')
        ..setYear(YearLevel.first);
      expect(_state(container).isDirty, isTrue);
    });

    test('biyografi Limits.bioMax karakterde kesilir', () async {
      _signIn();
      final container = await _container();

      _viewModel(container).setBio('a' * (Limits.bioMax + 15));

      expect(_state(container).bio, hasLength(Limits.bioMax));
      expect(_state(container).isDirty, isTrue);
    });

    test('5 ilgi alanı doluyken yeni seçim TST-04, seçim değişmez', () async {
      _signIn();
      final container = await _container();
      final viewModel = _viewModel(container);
      expect(viewModel.toggleInterest('i02'), isTrue);

      expect(viewModel.toggleInterest('i03'), isFalse);
      expect(_feedback().toasts, [ToastId.tst04]);
      expect(_state(container).interests, hasLength(Limits.interestsMax));
    });

    test('kilitli e-posta dokunuşu TST-20', () async {
      _signIn();
      final container = await _container();

      _viewModel(container).onLockedFieldTap();

      expect(_feedback().toasts, [ToastId.tst20]);
    });
  });

  group('PRF-02 · EditProfileViewModel · kaydet', () {
    test('değişiklik yoksa TST-X9, yazım yok', () async {
      _signIn();
      final container = await _container();

      expect(
        await _viewModel(container).save(),
        EditProfileOutcome.noChanges,
      );
      expect(_feedback().toasts, [ToastId.tstX9]);
      expect(_users().profilePatches, isEmpty);
    });

    test('doğrulama: boş ad zorunlu, tek harf kısa, ilgi alanı yok → '
        'yazım yok', () async {
      _signIn();
      final container = await _container();
      final viewModel = _viewModel(container)..setName('   ');
      _mehmet.interests.forEach(viewModel.toggleInterest);

      expect(await viewModel.save(), EditProfileOutcome.invalid);
      expect(_state(container).errors, {
        EditProfileField.name: FormFieldError.required,
        EditProfileField.interests: FormFieldError.required,
      });

      viewModel.setName('A');
      expect(_state(container).errors.keys, [EditProfileField.interests]);
      expect(await viewModel.save(), EditProfileOutcome.invalid);
      expect(
        _state(container).errors[EditProfileField.name],
        FormFieldError.tooShort,
      );
      expect(_users().profilePatches, isEmpty);
      expect(_feedback().toasts, isEmpty);
    });

    test('personelde ilgi alanı zorunlu değildir', () async {
      _signIn(_mehmet.copyWith(staff: true));
      final container = await _container();
      final viewModel = _viewModel(container);
      _mehmet.interests.forEach(viewModel.toggleInterest);

      expect(await viewModel.save(), EditProfileOutcome.saved);
      expect(_users().profilePatches.single.patch.interests, isEmpty);
    });

    test('başarı: yalnızca değişen alanlar yazılır (ad + nameLower, ilgi '
        'alanları tablo sırasıyla, kırpılmış biyografi); TST-21; form '
        'temiz', () async {
      _signIn();
      final container = await _container();
      final viewModel = _viewModel(container)
        ..setName('  İsmail Işık ')
        ..setBio(' Yeni biyografi ')
        ..toggleInterest('i11')
        ..toggleInterest('i02');

      expect(await viewModel.save(), EditProfileOutcome.saved);

      expect(
        _users().profilePatches.single.patch,
        const UserProfilePatch(
          name: 'İsmail Işık',
          nameLower: 'ismail ışık',
          interests: ['i01', 'i02', 'i06', 'i07'],
          bio: 'Yeni biyografi',
        ),
      );
      expect(_users().avatarUploads, isEmpty);
      expect(_feedback().toasts, [ToastId.tst21]);
      final state = _state(container);
      expect(state.isDirty, isFalse);
      expect(state.isSubmitting, isFalse);
      expect(state.name, 'İsmail Işık');
      expect(state.email, _email);
      expect(
        container.read(sessionViewModelProvider).user?.name,
        'İsmail Işık',
      );
    });

    test('yalnızca fotoğraf: yamasız updateAvatar, TST-57', () async {
      _signIn();
      (GetIt.I<AppPreferencesStore>() as FakeAppPreferencesStore)
              .values[AppPreferenceKeys.photoAccessExplained] =
          true;
      final container = await _container();
      final viewModel = _viewModel(container);
      await viewModel.pickAvatar(MediaSource.gallery);
      expect(_state(container).avatar, same(kFakeJpeg));
      expect(_state(container).isDirty, isTrue);

      expect(await viewModel.save(), EditProfileOutcome.saved);

      final upload = _users().avatarUploads.single;
      expect(upload.profile, isNull);
      expect(upload.contentType, 'image/jpeg');
      expect(_users().profilePatches, isEmpty);
      expect(_feedback().toasts, [ToastId.tst57]);
      expect(_state(container).avatar, isNull);
      expect(_state(container).original?.avatarPath, upload.path);
      expect(_state(container).isDirty, isFalse);
    });

    test('fotoğraf + ad: tek yazım (updateAvatar profile yaması), '
        'TST-21', () async {
      _signIn();
      (GetIt.I<AppPreferencesStore>() as FakeAppPreferencesStore)
              .values[AppPreferenceKeys.photoAccessExplained] =
          true;
      final container = await _container();
      final viewModel = _viewModel(container);
      await viewModel.pickAvatar(MediaSource.gallery);
      viewModel.setName('Mehmet K.');

      expect(await viewModel.save(), EditProfileOutcome.saved);

      expect(
        _users().avatarUploads.single.profile,
        const UserProfilePatch(name: 'Mehmet K.', nameLower: 'mehmet k.'),
      );
      expect(_users().profilePatches, isEmpty);
      expect(_feedback().toasts, [ToastId.tst21]);
    });

    test('görsel işlenemezse fotoğraf alanına hata yazılır', () async {
      _signIn();
      (GetIt.I<AppPreferencesStore>() as FakeAppPreferencesStore)
              .values[AppPreferenceKeys.photoAccessExplained] =
          true;
      final container = await _container();
      _picker().nextError = ImagePickError.tooLarge;

      await _viewModel(container).pickAvatar(MediaSource.gallery);

      expect(_state(container).avatar, isNull);
      expect(_state(container).errors, {
        EditProfileField.photo: FormFieldError.limitExceeded,
      });
      expect(_state(container).isDirty, isFalse);
    });

    test('çevrimdışı: TST-24, yazım yok, form yerinde', () async {
      _signIn();
      final container = await _container();
      _connectivity().isOffline = true;
      final viewModel = _viewModel(container)..setName('Mehmet K.');

      expect(await viewModel.save(), EditProfileOutcome.offline);
      expect(_feedback().toasts, [ToastId.tst24]);
      expect(_users().profilePatches, isEmpty);
      expect(_state(container).name, 'Mehmet K.');
    });

    test('ağ hatası TST-24, yetki hatası TST-X18; form değerleri ve kirli '
        'durum korunur', () async {
      _signIn();
      final container = await _container();
      final viewModel = _viewModel(container)..setName('Mehmet K.');

      _users().failNext(FirestoreError.unavailable);
      expect(await viewModel.save(), EditProfileOutcome.failed);
      _users().failNext(FirestoreError.permissionDenied);
      expect(await viewModel.save(), EditProfileOutcome.failed);

      expect(_feedback().toasts, [ToastId.tst24, ToastId.tstX18]);
      final state = _state(container);
      expect(state.isSubmitting, isFalse);
      expect(state.submitError, isNull);
      expect(state.isDirty, isTrue);
      expect(state.name, 'Mehmet K.');
    });

    test('diğer hata (yükleme reddi): toast yok, form altı hata; düzenleme '
        'hatayı siler', () async {
      _signIn();
      (GetIt.I<AppPreferencesStore>() as FakeAppPreferencesStore)
              .values[AppPreferenceKeys.photoAccessExplained] =
          true;
      final container = await _container();
      final viewModel = _viewModel(container);
      await viewModel.pickAvatar(MediaSource.gallery);
      _users().failNext(StorageError.unauthorized);

      expect(await viewModel.save(), EditProfileOutcome.failed);

      expect(_feedback().toasts, isEmpty);
      expect(_state(container).submitError, EditProfileError.unknown);
      expect(_state(container).avatar, same(kFakeJpeg));

      viewModel.setBio('x');
      expect(_state(container).submitError, isNull);
    });
  });
}

// PRF-02 · EditProfileState: kirli hesabı (özgün profile göre), personel
// bayrağı, props / copyWith (clear bayrakları).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/profile/provider/edit_profile_state.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';

import '../../../fakes/fake_image_picker_service.dart';
import '../../../fixtures/user_model_fixtures.dart';

final UserModel _user = UserModelFixtures.byId('u_mehmet');

final EditProfileState _form = EditProfileState(
  original: _user,
  name: _user.name,
  departmentId: _user.department,
  year: _user.year,
  interests: _user.interests.toSet(),
  bio: _user.bio,
);

void main() {
  group('PRF-02 · EditProfileState', () {
    test(
      'kurulmamış form temizdir; özgün değerlerle kurulan form temizdir',
      () {
        expect(const EditProfileState().isDirty, isFalse);
        expect(_form.isDirty, isFalse);
        expect(_form.isStaff, isFalse);
      },
    );

    test(
      'her alan ve yeni fotoğraf formu kirletir; boşluk farkı kirletmez',
      () {
        expect(_form.copyWith(name: '${_user.name}  ').isDirty, isFalse);
        expect(_form.copyWith(name: 'Başka').isDirty, isTrue);
        expect(_form.copyWith(departmentId: 'd10').isDirty, isTrue);
        expect(_form.copyWith(year: YearLevel.first).isDirty, isTrue);
        expect(_form.copyWith(bio: 'x').isDirty, isTrue);
        expect(_form.copyWith(interests: {'i01'}).isDirty, isTrue);
        final withPhoto = _form.copyWith(avatar: kFakeJpeg);
        expect(withPhoto.isDirty, isTrue);
        expect(withPhoto.hasProfileChanges, isFalse);
      },
    );

    test('copyWith: clear bayrakları ve tüm alanlar props içinde', () {
      final full = _form.copyWith(
        email: 'a@b.c',
        avatar: kFakeJpeg,
        uploadProgress: .5,
        errors: const {EditProfileField.name: FormFieldError.required},
        isSubmitting: true,
        submitError: EditProfileError.unknown,
        isError: true,
      );
      expect(full.props, hasLength(13));
      expect(full, isNot(_form));

      final cleared = full.copyWith(
        clearAvatar: true,
        clearUploadProgress: true,
        clearSubmitError: true,
      );
      expect(cleared.avatar, isNull);
      expect(cleared.uploadProgress, isNull);
      expect(cleared.submitError, isNull);
      expect(cleared.email, 'a@b.c');
      expect(_form.copyWith(), _form);
    });
  });
}

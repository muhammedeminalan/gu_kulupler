// AUT-05 · SetupProfileState: props / copyWith tüm alanlar (PLAN §12.16) ve
// türetilmiş değerler (adım numarası, fotoğraf, ilgi alanı sınırı, ilk ad).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/auth/provider/setup_profile_state.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';

import '../../../fakes/fake_image_picker_service.dart';

void main() {
  group('AUT-05 · SetupProfileState', () {
    const a = SetupProfileState();
    const errors = {SetupProfileField.year: FormFieldError.required};

    test('props tüm alanları içerir (alan sayısı = 13)', () {
      expect(a.props.length, 13);
    });

    test('varsayılanlar: ilk adım, boş form', () {
      expect(a.step, SetupStep.photo);
      expect(a.name, isEmpty);
      expect(a.avatarSeed, isEmpty);
      expect(a.isStaff, isFalse);
      expect(a.departmentId, isNull);
      expect(a.year, isNull);
      expect(a.interests, isEmpty);
      expect(a.avatar, isNull);
      expect(a.uploadProgress, isNull);
      expect(a.errors, isEmpty);
      expect(a.isDirty, isFalse);
      expect(a.isSubmitting, isFalse);
      expect(a.submitError, isNull);
    });

    test('copyWith her alanı taşır ve eşitliği bozar', () {
      expect(a.copyWith(step: SetupStep.info).step, SetupStep.info);
      expect(a.copyWith(step: SetupStep.info), isNot(a));
      expect(a.copyWith(name: 'Ayşe').name, 'Ayşe');
      expect(a.copyWith(name: 'Ayşe'), isNot(a));
      expect(a.copyWith(avatarSeed: 'u1').avatarSeed, 'u1');
      expect(a.copyWith(avatarSeed: 'u1'), isNot(a));
      expect(a.copyWith(isStaff: true).isStaff, isTrue);
      expect(a.copyWith(isStaff: true), isNot(a));
      expect(a.copyWith(departmentId: 'd01').departmentId, 'd01');
      expect(a.copyWith(departmentId: 'd01'), isNot(a));
      expect(a.copyWith(year: YearLevel.third).year, YearLevel.third);
      expect(a.copyWith(year: YearLevel.third), isNot(a));
      expect(a.copyWith(interests: const {'i01'}).interests, {'i01'});
      expect(a.copyWith(interests: const {'i01'}), isNot(a));
      expect(a.copyWith(avatar: kFakeJpeg).avatar, same(kFakeJpeg));
      expect(a.copyWith(avatar: kFakeJpeg), isNot(a));
      expect(a.copyWith(uploadProgress: 0.5).uploadProgress, 0.5);
      expect(a.copyWith(uploadProgress: 0.5), isNot(a));
      expect(a.copyWith(errors: errors).errors, errors);
      expect(a.copyWith(errors: errors), isNot(a));
      expect(a.copyWith(isDirty: true).isDirty, isTrue);
      expect(a.copyWith(isDirty: true), isNot(a));
      expect(a.copyWith(isSubmitting: true).isSubmitting, isTrue);
      expect(a.copyWith(isSubmitting: true), isNot(a));
      expect(
        a.copyWith(submitError: SetupProfileError.network).submitError,
        SetupProfileError.network,
      );
      expect(a.copyWith(submitError: SetupProfileError.network), isNot(a));
    });

    test('copyWith parametresiz aynı değeri verir', () {
      final b = a.copyWith(
        step: SetupStep.interests,
        name: 'Ayşe Yılmaz',
        avatarSeed: 'u1',
        isStaff: true,
        departmentId: 'd01',
        year: YearLevel.prep,
        interests: const {'i01', 'i02'},
        avatar: kFakeJpeg,
        uploadProgress: 1,
        errors: errors,
        isDirty: true,
        isSubmitting: true,
        submitError: SetupProfileError.unknown,
      );
      expect(b.copyWith(), b);
      expect(b.copyWith().avatar, same(kFakeJpeg));
    });

    test('clear bayrakları fotoğrafı, ilerlemeyi ve sunucu hatasını siler; '
        'aynı adlı parametreden önce gelir', () {
      final b = a.copyWith(
        avatar: kFakeJpeg,
        uploadProgress: 0.4,
        submitError: SetupProfileError.network,
      );
      expect(b.copyWith(clearAvatar: true).avatar, isNull);
      expect(b.copyWith(clearAvatar: true, avatar: kFakeJpeg).avatar, isNull);
      expect(b.copyWith(clearUploadProgress: true).uploadProgress, isNull);
      expect(
        b.copyWith(clearUploadProgress: true, uploadProgress: 1).uploadProgress,
        isNull,
      );
      expect(b.copyWith(clearSubmitError: true).submitError, isNull);
      expect(
        b
            .copyWith(
              clearSubmitError: true,
              submitError: SetupProfileError.unknown,
            )
            .submitError,
        isNull,
      );
    });

    test('ilgi alanları küme eşitliğiyle karşılaştırılır (sıra önemsiz)', () {
      expect(
        a.copyWith(interests: const {'i01', 'i02'}),
        a.copyWith(interests: const {'i02', 'i01'}),
      );
    });

    test('hasPhoto: fotoğraf seçildiyse true', () {
      expect(a.hasPhoto, isFalse);
      expect(a.copyWith(avatar: kFakeJpeg).hasPhoto, isTrue);
    });

    test('canAddInterest: Limits.interestsMax dolunca false', () {
      final four = {for (var i = 1; i < Limits.interestsMax; i++) 'i0$i'};
      expect(a.canAddInterest, isTrue);
      expect(a.copyWith(interests: four).canAddInterest, isTrue);
      expect(
        a.copyWith(interests: {...four, 'i09'}).canAddInterest,
        isFalse,
      );
    });

    test('firstName: adın ilk sözcüğü (TST-05)', () {
      expect(a.firstName, isEmpty);
      expect(a.copyWith(name: 'Ayşe').firstName, 'Ayşe');
      expect(a.copyWith(name: 'Ayşe Nur Yılmaz').firstName, 'Ayşe');
      expect(a.copyWith(name: '  Deneme   Kullanıcı ').firstName, 'Deneme');
    });

    test('SetupStep: tasarım sırası, numara ve son adım', () {
      expect(SetupStep.values, [
        SetupStep.photo,
        SetupStep.info,
        SetupStep.interests,
      ]);
      expect([for (final step in SetupStep.values) step.number], [1, 2, 3]);
      expect(SetupStep.photo.isLast, isFalse);
      expect(SetupStep.info.isLast, isFalse);
      expect(SetupStep.interests.isLast, isTrue);
    });
  });
}

// T-14 · FakeImagePickerService sözleşmesi (PLAN §16.3): `nextPick`,
// `permissionDenied`; seçici açmaz.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/service/image_picker_service.dart';

import 'fake_base.dart';
import 'fake_image_picker_service.dart';
import 'register_fakes.dart';

void main() {
  group('T-14 · FakeImagePickerService', () {
    test('ImagePickerService arayüzünü uygular; registerDefaultFakes '
        'kaydeder', () {
      addTearDown(GetIt.I.reset);
      registerDefaultFakes();
      expect(GetIt.I<ImagePickerService>(), isA<FakeImagePickerService>());
    });

    test(
      'varsayılan: her seçim kFakeJpeg döndürür ve kaynağı kaydeder',
      () async {
        final fake = FakeImagePickerService();

        final camera = await fake.pick(MediaSource.camera);
        final gallery = await fake.pick(MediaSource.gallery);

        expect(camera.imageOrNull, same(kFakeJpeg));
        expect(gallery.imageOrNull, same(kFakeJpeg));
        expect(kFakeJpeg.contentType, 'image/jpeg');
        expect(
          StoragePaths.extensionByContentType,
          contains(kFakeJpeg.contentType),
        );
        expect(fake.picks, [MediaSource.camera, MediaSource.gallery]);
        expect(fake.calls, [
          const FakeCall('pick', [MediaSource.camera, Limits.imageMaxBytes]),
          const FakeCall('pick', [MediaSource.gallery, Limits.imageMaxBytes]),
        ]);
      },
    );

    test('nextPick null: kullanıcı vazgeçti (hata değil)', () async {
      final fake = FakeImagePickerService()..nextPick = null;

      final result = await fake.pick(MediaSource.gallery);

      expect(result, isA<ImagePickCancelled>());
      expect(result.imageOrNull, isNull);
    });

    test('permissionDenied: erişim reddi (kalıcı)', () async {
      final fake = FakeImagePickerService()..permissionDenied = true;

      for (var i = 0; i < 2; i++) {
        final result = await fake.pick(MediaSource.camera);
        expect(
          result,
          isA<ImagePickFailure>().having(
            (failure) => failure.error,
            'error',
            ImagePickError.permissionDenied,
          ),
        );
      }
    });

    test(
      'nextError tek seferliktir; failNext platform hatasıdır (failed)',
      () async {
        final fake = FakeImagePickerService()
          ..nextError = ImagePickError.invalidType;

        expect(
          (await fake.pick(MediaSource.gallery) as ImagePickFailure).error,
          ImagePickError.invalidType,
        );
        expect(await fake.pick(MediaSource.gallery), isA<ImagePickSuccess>());

        fake.failNext();
        expect(
          (await fake.pick(MediaSource.gallery) as ImagePickFailure).error,
          ImagePickError.failed,
        );
      },
    );

    test('gerçek servis gibi: görsel maxBytes sınırında ya da üstündeyse '
        'tooLarge', () async {
      final image = PickedImage(
        bytes: Uint8List(8),
        contentType: 'image/jpeg',
        width: 1,
        height: 1,
      );
      final fake = FakeImagePickerService()..nextPick = image;

      expect(
        (await fake.pick(MediaSource.gallery, maxBytes: 8) as ImagePickFailure)
            .error,
        ImagePickError.tooLarge,
      );
      expect(
        (await fake.pick(MediaSource.gallery, maxBytes: 9)).imageOrNull,
        same(image),
      );
    });

    test('resetFake: varsayılanlara döner', () async {
      final fake = FakeImagePickerService()
        ..nextPick = null
        ..permissionDenied = true
        ..nextError = ImagePickError.failed;
      await fake.pick(MediaSource.camera);

      fake.resetFake();

      expect(fake.nextPick, same(kFakeJpeg));
      expect(fake.permissionDenied, isFalse);
      expect(fake.nextError, isNull);
      expect(fake.picks, isEmpty);
      expect(fake.calls, isEmpty);
    });
  });
}

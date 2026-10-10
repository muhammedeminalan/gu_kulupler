// T-10 · FakeStorageService sözleşmesi (PLAN §16.3).
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';

import 'fake_storage_service.dart';
import 'register_fakes.dart';

const String _jpeg = 'image/jpeg';

Matcher _failsWith(StorageError error) =>
    isA<FirebaseFailure<Object?, StorageError>>().having(
      (r) => r.error,
      'error',
      error,
    );

void main() {
  final bytes = Uint8List.fromList([1, 2, 3]);
  final path = StoragePaths.userAvatar(
    'u1',
    '20261008T201501Z_3f9a1c2b7d4e5f60.jpg',
  );

  group('T-10 · FakeStorageService', () {
    test('StorageService arayüzünü uygular; registerDefaultFakes kaydeder', () {
      addTearDown(GetIt.I.reset);
      registerDefaultFakes();
      expect(GetIt.I<StorageService>(), isA<FakeStorageService>());
    });

    test('upload: baytlar uploads haritasına, üst veri metadata sonucuna; '
        'ilerleme tamamlanır', () async {
      final fake = FakeStorageService();
      final progress = <double>[];

      final result = await fake.upload(
        path: path,
        bytes: bytes,
        contentType: _jpeg,
        customMetadata: const {'clubId': 'c01'},
        onProgress: progress.add,
      );

      expect(
        result,
        isA<FirebaseSuccess<String, StorageError>>().having(
          (r) => r.data,
          'data',
          path,
        ),
      );
      expect(fake.uploads, {path: bytes});
      expect(progress, [1.0]);
      expect(
        await fake.metadata(path),
        isA<FirebaseSuccess<StorageFileInfo, StorageError>>().having(
          (r) => r.data,
          'data',
          StorageFileInfo(
            path: path,
            sizeBytes: bytes.length,
            contentType: _jpeg,
            customMetadata: const {'clubId': 'c01'},
          ),
        ),
      );
      expect(
        await fake.downloadUrl(path),
        isA<FirebaseSuccess<String, StorageError>>().having(
          (r) => r.data,
          'data',
          endsWith(path),
        ),
      );
    });

    test('yükleme öncesi denetimler gerçek servisle aynı; '
        'hiçbiri dosya yazmaz', () async {
      final fake = FakeStorageService();

      expect(
        await fake.upload(path: path, bytes: Uint8List(0), contentType: _jpeg),
        _failsWith(StorageError.noFile),
      );
      expect(
        await fake.upload(path: path, bytes: bytes, contentType: 'image/gif'),
        _failsWith(StorageError.invalidType),
      );
      expect(
        await fake.upload(path: path, bytes: bytes, contentType: 'image/png'),
        _failsWith(StorageError.invalidType),
      );
      expect(
        await fake.upload(
          path: path,
          bytes: Uint8List(Limits.imageMaxBytes),
          contentType: _jpeg,
        ),
        _failsWith(StorageError.sizeLimit),
      );
      expect(fake.uploads, isEmpty);
    });

    test(
      'üzerine yazma yok: aynı yola ikinci yükleme reddedilir (D-10)',
      () async {
        final fake = FakeStorageService();
        await fake.upload(path: path, bytes: bytes, contentType: _jpeg);

        expect(
          await fake.upload(
            path: path,
            bytes: Uint8List.fromList([9]),
            contentType: _jpeg,
          ),
          _failsWith(StorageError.unauthorized),
        );
        expect(fake.uploads[path], bytes);
      },
    );

    test('failNext tek seferlik; olmayan yol notFound', () async {
      final fake = FakeStorageService()..failNext(StorageError.quotaExceeded);

      expect(
        await fake.upload(path: path, bytes: bytes, contentType: _jpeg),
        _failsWith(StorageError.quotaExceeded),
      );
      expect(fake.uploads, isEmpty);
      expect(await fake.downloadUrl(path), _failsWith(StorageError.notFound));
      expect(await fake.metadata(path), _failsWith(StorageError.notFound));

      fake.failNext();
      expect(await fake.metadata(path), _failsWith(StorageError.unknown));
      expect(fake.callsTo('metadata'), hasLength(2));
    });
  });
}

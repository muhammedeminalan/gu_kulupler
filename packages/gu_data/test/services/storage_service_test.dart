// T-10 · StorageService: yükleme (yol, üst veri, ilerleme), yükleme öncesi
// denetimler, indirme adresi, üst veri, hata → FirebaseFailure eşlemesi,
// zaman aşımı ve "dosya silme / üzerine yazma yok" sözleşmesi (PLAN
// §10.1–§10.2, §11.5; D-10, D-34, CD-39).
//
// Mutlu yollar `firebase_storage_mocks` ile (Q-06); hata, ilerleme ve zaman
// aşımı yolları el yazımı SDK çiftleriyle
// (`test/fakes/sdk_storage_stubs.dart`).
import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../fakes/sdk_storage_stubs.dart';
import '../helpers/plan_service_table.dart';
import '../helpers/repo_sources.dart';

const String _source = 'packages/gu_data/lib/src/services/storage_service.dart';
const String _file = '20261008T201501Z_3f9a1c2b7d4e5f60.jpg';
final String _path = StoragePaths.postImage('p01', _file);
final Uint8List _bytes = Uint8List.fromList([1, 2, 3, 4]);

void main() {
  late MockFirebaseStorage storage;
  late StorageService service;

  setUp(() {
    storage = MockFirebaseStorage();
    service = FirebaseStorageService(storage);
  });

  group('T-10 · StorageService · upload', () {
    test('baytları yola yükler, tam nesne yolunu döndürür; içerik türü ve '
        'özel üst veri nesneye yazılır', () async {
      final result = await service.upload(
        path: _path,
        bytes: _bytes,
        contentType: 'image/jpeg',
        customMetadata: {'clubId': 'c01'},
      );

      expect(result.dataOrNull, 'posts/p01/$_file');
      expect(storage.storedDataMap.get(_path), _bytes);
      expect(storage.storedSettableMetadataMap[_path], {
        'cacheControl': null,
        'contentDisposition': null,
        'contentEncoding': null,
        'contentLanguage': null,
        'contentType': 'image/jpeg',
        'customMetadata': {'clubId': 'c01'},
      });
    });

    test('üç izinli tür kendi uzantısıyla yüklenir', () async {
      for (final MapEntry(key: contentType, value: extension)
          in StoragePaths.extensionByContentType.entries) {
        final path = StoragePaths.userAvatar(
          'u1',
          _file.replaceFirst('.jpg', '.$extension'),
        );

        final result = await service.upload(
          path: path,
          bytes: _bytes,
          contentType: contentType,
        );

        expect(result.dataOrNull, path, reason: contentType);
      }
    });

    test('ilerleme oranı 0–1 arası bildirilir; toplamı bilinmeyen olay '
        'atlanır; bitince dinleyici bırakılır', () async {
      final stub = StubStorage();
      final fractions = <double>[];
      final pending = FirebaseStorageService(stub).upload(
        path: _path,
        bytes: _bytes,
        contentType: 'image/jpeg',
        onProgress: fractions.add,
      );
      await pumpEventQueue();

      stub
        ..progress(0, 0)
        ..progress(1, 4)
        ..progress(4, 4);
      await pumpEventQueue();
      expect(stub.hasProgressListener, isTrue);
      stub.completeUpload();

      expect((await pending).dataOrNull, _path);
      expect(fractions, [0.25, 1.0]);
      expect(stub.hasProgressListener, isFalse);
    });
  });

  group('T-10 · StorageService · yükleme öncesi denetim', () {
    Future<StorageError?> rejection({
      String? path,
      Uint8List? bytes,
      String contentType = 'image/jpeg',
    }) async {
      final stub = StubStorage();
      final result = await FirebaseStorageService(stub).upload(
        path: path ?? _path,
        bytes: bytes ?? _bytes,
        contentType: contentType,
      );
      expect(stub.references, isEmpty, reason: 'SDK çağrılmamalı');
      return result.errorOrNull;
    }

    test('boş bayt dizisi → noFile', () async {
      expect(await rejection(bytes: Uint8List(0)), StorageError.noFile);
    });

    test('izinli olmayan içerik türü → invalidType', () async {
      for (final contentType in ['image/gif', 'text/plain', 'image/JPEG', '']) {
        expect(
          await rejection(contentType: contentType),
          StorageError.invalidType,
          reason: contentType,
        );
      }
    });

    test('içerik türü yolun uzantısıyla uyuşmuyorsa → invalidType', () async {
      expect(
        await rejection(contentType: 'image/png'),
        StorageError.invalidType,
      );
    });

    test(
      'Limits.imageMaxBytes ve üstü → sizeLimit (Rules: size < sınır)',
      () async {
        expect(
          await rejection(bytes: Uint8List(Limits.imageMaxBytes)),
          StorageError.sizeLimit,
        );
        expect(
          await rejection(bytes: Uint8List(Limits.imageMaxBytes + 1)),
          StorageError.sizeLimit,
        );
      },
    );

    test('sınırın bir bayt altı yüklenir', () async {
      final result = await service.upload(
        path: _path,
        bytes: Uint8List(Limits.imageMaxBytes - 1),
        contentType: 'image/jpeg',
      );

      expect(result.dataOrNull, _path);
    });
  });

  group('T-10 · StorageService · downloadUrl / metadata', () {
    test('downloadUrl: yüklenmiş nesnenin adresini döndürür', () async {
      await service.upload(
        path: _path,
        bytes: _bytes,
        contentType: 'image/jpeg',
      );

      final result = await service.downloadUrl(_path);

      expect(result.dataOrNull, endsWith('/$_path'));
      expect(result.dataOrNull, startsWith('https://'));
    });

    test('downloadUrl: nesne yoksa notFound (fırlatmaz)', () async {
      final result = await service.downloadUrl(_path);

      expect(result.errorOrNull, StorageError.notFound);
    });

    test('metadata: yol, boyut, içerik türü ve özel üst veri', () async {
      await service.upload(
        path: _path,
        bytes: _bytes,
        contentType: 'image/jpeg',
        customMetadata: {'clubId': 'c01'},
      );

      final result = await service.metadata(_path);

      expect(
        result.dataOrNull,
        StorageFileInfo(
          path: _path,
          sizeBytes: _bytes.length,
          contentType: 'image/jpeg',
          customMetadata: const {'clubId': 'c01'},
        ),
      );
    });

    test('metadata: özel üst veri verilmemişse boş eşleme', () async {
      await service.upload(
        path: _path,
        bytes: _bytes,
        contentType: 'image/jpeg',
      );

      final info = (await service.metadata(_path)).dataOrNull!;

      expect(info.customMetadata, isEmpty);
    });
  });

  group('T-10 · StorageService · hata eşlemesi', () {
    const codes = {
      'unauthorized': StorageError.unauthorized,
      'unauthenticated': StorageError.unauthorized,
      'object-not-found': StorageError.notFound,
      'canceled': StorageError.canceled,
      'quota-exceeded': StorageError.quotaExceeded,
      'retry-limit-exceeded': StorageError.retryLimitExceeded,
      'bucket-not-found': StorageError.unknown,
      'bilinmeyen-kod': StorageError.unknown,
    };

    test('upload: SDK kodu StorageError.fromCode ile çevrilir; ham mesaj '
        'taşınır; ilerleme dinleyicisi hatayı sızdırmaz', () async {
      for (final MapEntry(key: code, value: expected) in codes.entries) {
        final stub = StubStorage();
        final pending = FirebaseStorageService(stub).upload(
          path: _path,
          bytes: _bytes,
          contentType: 'image/jpeg',
          onProgress: (_) {},
        );
        await pumpEventQueue();

        stub.failUpload(storageException(code, message: 'ham $code'));
        final result = await pending;

        expect(result.errorOrNull, expected, reason: code);
        expect((result as FirebaseFailure).message, 'ham $code', reason: code);
        expect(stub.hasProgressListener, isFalse, reason: code);
      }
    });

    test(
      'downloadUrl ve metadata SDK hatasını FirebaseFailure olarak verir',
      () async {
        final stubbed = FirebaseStorageService(
          StubStorage(error: storageException('unauthorized')),
        );

        expect(
          (await stubbed.downloadUrl(_path)).errorOrNull,
          StorageError.unauthorized,
        );
        expect(
          (await stubbed.metadata(_path)).errorOrNull,
          StorageError.unauthorized,
        );
      },
    );

    test('SDK dışı istisna → unknown (fırlatılmaz)', () async {
      final stub = StubStorage(error: StateError('x'));
      final stubbed = FirebaseStorageService(stub);
      final pending = stubbed.upload(
        path: _path,
        bytes: _bytes,
        contentType: 'image/jpeg',
      );
      await pumpEventQueue();
      stub.failUpload(const FormatException('bozuk'));

      expect((await pending).errorOrNull, StorageError.unknown);
      expect(
        (await stubbed.downloadUrl(_path)).errorOrNull,
        StorageError.unknown,
      );
    });
  });

  group('T-10 · StorageService · zaman aşımı', () {
    // Gövdelerde `pump` dışında `await` yok (sahte zaman bölgesi).
    testWidgets('yükleme Limits.storageUploadTimeout içinde bitmezse timeout '
        'döner ve görev iptal edilir', (tester) async {
      final stub = StubStorage();
      StorageResult<String>? result;
      unawaited(
        FirebaseStorageService(stub)
            .upload(path: _path, bytes: _bytes, contentType: 'image/jpeg')
            .then((r) => result = r),
      );

      await tester.pump(
        Limits.storageUploadTimeout - const Duration(milliseconds: 1),
      );
      expect(result, isNull);
      expect(stub.uploadCancels, 0);
      await tester.pump(const Duration(milliseconds: 1));

      expect(result!.errorOrNull, StorageError.timeout);
      expect(stub.uploadCancels, 1);
    });

    testWidgets('kısa çağrılar Limits.firestoreTimeout içinde dönmezse '
        'timeout', (tester) async {
      final stubbed = FirebaseStorageService(StubStorage());
      StorageResult<String>? url;
      StorageResult<StorageFileInfo>? info;
      unawaited(stubbed.downloadUrl(_path).then((r) => url = r));
      unawaited(stubbed.metadata(_path).then((r) => info = r));

      await tester.pump(
        Limits.firestoreTimeout - const Duration(milliseconds: 1),
      );
      expect(url, isNull);
      expect(info, isNull);
      await tester.pump(const Duration(milliseconds: 1));

      expect(url!.errorOrNull, StorageError.timeout);
      expect(info!.errorOrNull, StorageError.timeout);
    });
  });

  group('T-10 · StorageService · silme ve üzerine yazma yok (D-10)', () {
    test('servis kaynağında delete ile başlayan hiçbir tanımlayıcı yok', () {
      expect(deleteIdentifiersIn(_source), isEmpty);
    });

    test(
      'PLAN §10.2 "YOK" satırı: arayüzde delete / update üyesi bulunmaz',
      () {
        final source = readRepoFile(_source);

        expect(readPlanAbsentMembers('StorageService'), ['delete / update']);
        expect(source, isNot(contains('updateMetadata')));
        expect(source, isNot(matches(RegExp(r'\bupdate\w*\s*\('))));
      },
    );

    test('PLAN §10.2 tablosundaki her üye arayüzde aynı imzayla var', () {
      final source = normalizeDartSource(readRepoFile(_source));
      final members = readPlanServiceMembers('StorageService');

      expect(members.map((m) => m.member), [
        'upload',
        'downloadUrl',
        'metadata',
      ]);
      for (final member in members) {
        expect(
          source,
          contains('${normalizeDartSource(member.signature)};'),
          reason: member.member,
        );
      }
      expect(
        readPlanServiceImplementation('StorageService'),
        '$FirebaseStorageService',
      );
    });
  });
}

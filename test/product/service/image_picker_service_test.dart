// T-14 · DeviceImagePickerService: seçici + sıkıştırma hattı, tür / boyut
// denetimi ve hata davranışı (CD-08, CD-16, Q-19; PLAN §11.5).
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/service/image_picker_service.dart';
import 'package:image_picker/image_picker.dart' show ImageSource, XFile;

import '../../helpers/design_files.dart';

/// Dosya imzaları + dolgu.
Uint8List _bytes(List<int> magic, {int length = 32}) =>
    Uint8List(length)..setAll(0, magic);

final Uint8List _jpeg = _bytes(const [0xFF, 0xD8, 0xFF, 0xE0]);
final Uint8List _png = _bytes(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
]);
final Uint8List _webp = _bytes(const [
  0x52, 0x49, 0x46, 0x46, 0x10, 0x00, 0x00, 0x00, 0x57, 0x45, 0x42, 0x50, //
]);
final Uint8List _gif = _bytes(const [0x47, 0x49, 0x46, 0x38, 0x39, 0x61]);
final Uint8List _heic = _bytes(const [
  0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x69, 0x63, //
]);

/// `readAsBytes` hata veren dosya.
final class _UnreadableFile extends XFile {
  _UnreadableFile() : super('yok.jpg');

  @override
  Future<Uint8List> readAsBytes() async => throw StateError('okunamadı');
}

void main() {
  setUp(() {
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) {};
    addTearDown(() => debugPrint = original);
  });

  late List<ImageSource> sources;
  late List<Uint8List> compressed;

  /// [picked] dosyasını veren, sıkıştırmada [compress] çalıştıran servis
  /// (varsayılan: her girdiyi JPEG'e çevirir).
  DeviceImagePickerService service({
    Uint8List? picked,
    XFile? file,
    Object? pickError,
    Future<Uint8List> Function(Uint8List bytes)? compress,
  }) => DeviceImagePickerService(
    pickFile: (source) async {
      sources.add(source);
      if (pickError != null) {
        Error.throwWithStackTrace(pickError, StackTrace.current);
      }
      if (file != null) return file;
      return picked == null ? null : XFile.fromData(picked);
    },
    compress: (bytes) {
      compressed.add(bytes);
      return (compress ?? (_) async => _jpeg)(bytes);
    },
  );

  ImagePickError errorOf(ImagePickResult result) =>
      (result as ImagePickFailure).error;

  setUp(() {
    sources = [];
    compressed = [];
  });

  group('T-14 · DeviceImagePickerService · kaynak', () {
    test('kamera ve galeri doğru seçici kaynağına çevrilir', () async {
      await service(picked: _jpeg).pick(MediaSource.camera);
      await service(picked: _jpeg).pick(MediaSource.gallery);

      expect(sources, [ImageSource.camera, ImageSource.gallery]);
    });

    test(
      'kullanıcı vazgeçerse (dosya yok) iptal; sıkıştırma çalışmaz',
      () async {
        final result = await service().pick(MediaSource.gallery);

        expect(result, isA<ImagePickCancelled>());
        expect(result.imageOrNull, isNull);
        expect(compressed, isEmpty);
      },
    );
  });

  group('T-14 · DeviceImagePickerService · hazırlama', () {
    test('seçilen görsel sıkıştırılır ve JPEG olarak döner (özgün PNG olsa '
        'da)', () async {
      final result = await service(picked: _png).pick(MediaSource.gallery);

      final image = result.imageOrNull!;
      expect(image.contentType, 'image/jpeg');
      expect(image.bytes, _jpeg);
      expect(compressed.single, _png);
      expect('$image', 'PickedImage(image/jpeg, ${_jpeg.length} bayt)');
    });

    test("HEIC gibi izinli olmayan özgün dosya JPEG'e çevrilince kabul "
        'edilir', () async {
      final result = await service(picked: _heic).pick(MediaSource.gallery);

      expect(result.imageOrNull!.contentType, 'image/jpeg');
    });

    // Kapalı başarısızlık (T-14 güvenlik incelemesi): EXIF'i (konum…) ayıklayan
    // tek adım yeniden kodlamadır; o adım düşerse özgün dosya YÜKLENMEZ.
    test('yeniden kodlama hata verirse özgün dosya izinli türde olsa da '
        'KULLANILMAZ: failed', () async {
      for (final original in [_jpeg, _png, _webp]) {
        final result = await service(
          picked: original,
          compress: (_) async => throw StateError('kanal yok'),
        ).pick(MediaSource.gallery);

        expect(errorOf(result), ImagePickError.failed);
        expect(result.imageOrNull, isNull);
        expect(compressed.last, original);
      }
    });

    test('yeniden kodlama çıktısı JPEG değilse (boş / bozuk / başka tür) '
        'özgün dosyaya DÖNÜLMEZ: failed', () async {
      for (final output in [Uint8List(0), _gif, _png, _webp]) {
        final result = await service(
          picked: _png,
          compress: (_) async => output,
        ).pick(MediaSource.gallery);

        expect(errorOf(result), ImagePickError.failed);
        expect(result.imageOrNull, isNull);
      }
    });

    test('yeniden kodlanamayan ve izinli türde de olmayan dosya '
        'invalidType (hata ya da JPEG olmayan çıktı)', () async {
      for (final original in [
        _gif,
        _heic,
        _bytes(const [0x25, 0x50, 0x44]),
      ]) {
        final thrown = await service(
          picked: original,
          compress: (_) async => throw StateError('çözülemedi'),
        ).pick(MediaSource.gallery);
        final echoed = await service(
          picked: original,
          compress: (bytes) async => bytes,
        ).pick(MediaSource.gallery);

        expect(errorOf(thrown), ImagePickError.invalidType);
        expect(errorOf(echoed), ImagePickError.invalidType);
      }
    });

    test('başarılı her seçimin baytları yeniden kodlama çıktısıdır; özgün '
        'baytlar (EXIF taşıyabilir) hiçbir sonuçta dönmez', () async {
      // Özgün dosya: JPEG imzası + "EXIF" işaretli dolgu.
      final original = _bytes(const [
        0xFF, 0xD8, 0xFF, 0xE1, 0x45, 0x78, 0x69, 0x66, //
      ], length: 64);

      final ok = await service(picked: original).pick(MediaSource.camera);
      final broken = await service(
        picked: original,
        compress: (_) async => throw StateError('kanal yok'),
      ).pick(MediaSource.camera);

      expect(ok.imageOrNull!.bytes, _jpeg);
      expect(ok.imageOrNull!.bytes, isNot(original));
      expect(ok.imageOrNull!.contentType, 'image/jpeg');
      expect(broken.imageOrNull, isNull);
    });

    test('boyut sınırı: maxBytes − 1 geçer; sınırın kendisi ve üstü '
        'tooLarge (Rules `size < imageMaxBytes`)', () async {
      Future<ImagePickResult> pick(int length, int maxBytes) => service(
        picked: _png,
        compress: (_) async => _bytes(const [0xFF, 0xD8, 0xFF], length: length),
      ).pick(MediaSource.gallery, maxBytes: maxBytes);

      expect((await pick(99, 100)).imageOrNull, isNotNull);
      expect(errorOf(await pick(100, 100)), ImagePickError.tooLarge);
      expect(errorOf(await pick(101, 100)), ImagePickError.tooLarge);
    });

    test('varsayılan sınır Limits.imageMaxBytes', () async {
      Future<ImagePickResult> pick(int length) => service(
        picked: _png,
        compress: (_) async => _bytes(const [0xFF, 0xD8, 0xFF], length: length),
      ).pick(MediaSource.gallery);

      expect((await pick(Limits.imageMaxBytes - 1)).imageOrNull, isNotNull);
      expect(
        errorOf(await pick(Limits.imageMaxBytes)),
        ImagePickError.tooLarge,
      );
    });

    test(
      'her seçim yeni bir PickedImage örneğidir (eşitlik kimlikle)',
      () async {
        final device = service(picked: _jpeg);

        final first = (await device.pick(MediaSource.gallery)).imageOrNull!;
        final second = (await device.pick(MediaSource.gallery)).imageOrNull!;

        expect(first, isNot(second));
        expect(first.bytes, second.bytes);
      },
    );
  });

  group('T-14 · DeviceImagePickerService · hatalar (fırlatmaz)', () {
    test('erişim reddi kodları permissionDenied', () async {
      for (final code in const [
        'camera_access_denied',
        'camera_access_restricted',
        'photo_access_denied',
        'photo_access_restricted',
      ]) {
        final result = await service(
          pickError: PlatformException(code: code),
        ).pick(MediaSource.camera);

        expect(errorOf(result), ImagePickError.permissionDenied, reason: code);
      }
    });

    test('başka platform hatası ve beklenmeyen hata failed', () async {
      for (final error in <Object>[
        PlatformException(code: 'already_active'),
        MissingPluginException('kanal yok'),
        StateError('beklenmeyen'),
      ]) {
        final result = await service(
          pickError: error,
        ).pick(MediaSource.gallery);

        expect(errorOf(result), ImagePickError.failed, reason: '$error');
      }
    });

    test(
      'dosya okunamazsa ya da boşsa unreadable; sıkıştırma çalışmaz',
      () async {
        expect(
          errorOf(
            await service(file: _UnreadableFile()).pick(MediaSource.camera),
          ),
          ImagePickError.unreadable,
        );
        expect(
          errorOf(
            await service(picked: Uint8List(0)).pick(MediaSource.gallery),
          ),
          ImagePickError.unreadable,
        );
        expect(compressed, isEmpty);
      },
    );
  });

  group('T-14 · DeviceImagePickerService · contentTypeOf', () {
    test('dosya imzasından tür: jpeg, png, webp; diğerleri null', () {
      expect(DeviceImagePickerService.contentTypeOf(_jpeg), 'image/jpeg');
      expect(DeviceImagePickerService.contentTypeOf(_png), 'image/png');
      expect(DeviceImagePickerService.contentTypeOf(_webp), 'image/webp');
      for (final other in [
        _gif,
        _heic,
        Uint8List(0),
        Uint8List.fromList(const [0xFF, 0xD8]),
        // RIFF ama WEBP değil (WAV).
        _bytes(const [
          0x52, 0x49, 0x46, 0x46, 0x10, 0x00, 0x00, 0x00, 0x57, 0x41, 0x56,
          0x45, //
        ]),
        // "WEBP" var ama RIFF başlığı yok.
        _bytes(const [0, 0, 0, 0, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50]),
      ]) {
        expect(DeviceImagePickerService.contentTypeOf(other), isNull);
      }
    });

    test('tanınan her tür Storage yükleme türleri tablosundadır', () {
      for (final bytes in [_jpeg, _png, _webp]) {
        expect(
          StoragePaths.extensionByContentType,
          contains(DeviceImagePickerService.contentTypeOf(bytes)),
        );
      }
    });
  });

  group('T-14 · DeviceImagePickerService · platform ayarları', () {
    test('sabitler: uzun kenar 1600 px, JPEG kalitesi 82 (PLAN §11.5)', () {
      expect(DeviceImagePickerService.maxEdgePx, 1600);
      expect(DeviceImagePickerService.jpegQuality, 82);
    });

    test('seçici tam üst veri istemez (fotoğraf izni penceresi açılmaz — '
        'CD-16) ve görseli maxEdgePx kutusuna sığdırır', () {
      final source = readText('lib/product/service/image_picker_service.dart');

      expect(source, contains('requestFullMetadata: false'));
      expect(source, contains('maxWidth: maxEdgePx.toDouble()'));
      expect(source, contains('maxHeight: maxEdgePx.toDouble()'));
      expect(source, contains('quality: jpegQuality'));
    });

    test('yeniden kodlama EXIF taşımaz: `keepExif` açılmaz ve özgün '
        'baytları döndüren bir geri düşüş yoktur', () {
      final source = readText('lib/product/service/image_picker_service.dart');

      expect(source, isNot(contains('keepExif:')));
      expect(source, isNot(contains('return original;')));
    });

    test('varsayılan kurucu const kurulur', () {
      expect(const DeviceImagePickerService(), isA<ImagePickerService>());
    });
  });
}

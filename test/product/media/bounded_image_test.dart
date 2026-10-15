// T-21 güvenlik incelemesi (bulgu 4) · BoundedImage: uzaktan gelen gönderi
// görseli güvenilmeyen içeriktir. Storage Rules piksel boyutunu göremez
// (< 5 MB + beyan edilen tür); birkaç KB'lık ama çok büyük pikselli bir PNG
// sınırsız çözülürse akışı açan her üyenin uygulamasını bellekten düşürür.
// Sınırı aşan görsel ÇÖZÜLMEDEN reddedilir (hücre yer tutucuda kalır), kalanı
// sınırlı boyutta çözülür.
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/media/bounded_image.dart';
import 'package:gu_kulupler/product/media/constants/media_constants.dart';
import 'package:gu_kulupler/product/service/image_picker_service.dart';
import 'package:gu_kulupler/product/widget/post/image_grid.dart';
import 'package:gu_ui/gu_ui.dart';

import '../widget/post/post_test_support.dart';

/// Gerçek kod çözücünün başlığı okuyup reddetmesi için beklenen süre.
const Duration _settle = Duration(milliseconds: 200);

/// [width] × [height] piksellik tek renk PNG (gerçek kodlayıcıyla): dosya
/// birkaç KB'dır, piksel boyutu istenildiği kadar büyük olabilir.
Future<Uint8List> _png(int width, int height) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint(),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

/// [provider] görselini yükler; çözülen boyutu döner ya da hatayı fırlatır.
Future<(int, int)> _decodedSize(ImageProvider provider) {
  final completer = Completer<(int, int)>();
  final stream = provider.resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      completer.complete((info.image.width, info.image.height));
      info.dispose();
      stream.removeListener(listener);
    },
    onError: (error, stackTrace) {
      completer.completeError(error, stackTrace);
      stream.removeListener(listener);
    },
  );
  stream.addListener(listener);
  return completer.future;
}

void main() {
  setUp(() => PaintingBinding.instance.imageCache.clear());

  testWidgets('piksel sayısı sınırı aşan görsel çözülmeden reddedilir; '
      'sınırdaki görsel yüklenir', (tester) async {
    await tester.runAsync(() async {
      final bytes = await _png(40, 30);

      await expectLater(
        _decodedSize(BoundedImage(MemoryImage(bytes), maxSourcePixels: 1199)),
        throwsA(
          isA<ImageTooLargeException>()
              .having((e) => e.width, 'width', 40)
              .having((e) => e.height, 'height', 30),
        ),
      );
      // Ayrı bayt örneği = ayrı önbellek anahtarı (sınır anahtarda yoktur).
      expect(
        await _decodedSize(
          BoundedImage(
            MemoryImage(Uint8List.fromList(bytes)),
            maxSourcePixels: 1200,
          ),
        ),
        (40, 30),
      );
    });
  });

  testWidgets('saldırı: birkaç KB boyutunda ama ≈ 10,4 MP olan PNG varsayılan '
      'sınırlarla reddedilir (sarılmamış sağlayıcı tam boyutta çözerdi)', (
    tester,
  ) async {
    await tester.runAsync(() async {
      const width = 4000;
      const height = 2600;
      final bytes = await _png(width, height);
      // Dosya Storage Rules boyut sınırının (5 MB) çok altında: kural bu
      // yüklemeyi durduramaz.
      expect(bytes.length, lessThan(Limits.imageMaxBytes));
      expect(width * height, greaterThan(MediaConstants.imageSourceMaxPixels));

      await expectLater(
        _decodedSize(BoundedImage(MemoryImage(bytes))),
        throwsA(isA<ImageTooLargeException>()),
      );
    });
  });

  testWidgets('kabul edilen görsel uzun kenarı maxEdge olacak biçimde '
      'küçültülür (oran korunur); küçük görsel büyütülmez', (tester) async {
    await tester.runAsync(() async {
      final wide = await _png(40, 30);
      final tall = await _png(30, 40);

      expect(
        await _decodedSize(BoundedImage(MemoryImage(wide), maxEdge: 20)),
        (20, 15),
      );
      expect(
        await _decodedSize(BoundedImage(MemoryImage(tall), maxEdge: 20)),
        (15, 20),
      );
      expect(
        await _decodedSize(BoundedImage(MemoryImage(wide), maxEdge: 100)),
        (40, 30),
      );
    });
  });

  testWidgets('T-44 · coverEdgePx: kısa kenar kutu kenarına iner (kaplama '
      'germez); uzun kenar maxEdge sınırında; büyütme yok', (tester) async {
    await tester.runAsync(() async {
      Future<(int, int)> decoded(int w, int h) async => _decodedSize(
        BoundedImage(MemoryImage(await _png(w, h)), coverEdgePx: 120),
      );

      expect(await decoded(1600, 1200), (160, 120));
      expect(await decoded(1600, 1600), (120, 120));
      expect(await decoded(100, 100), (100, 100));
      // Dikey: kısa kenar 120, uzun kenar oranla (213,3 → 214).
      expect(await decoded(900, 1600), (120, 214));
    });
  });

  test('T-44 · coverTarget: uzun kenar maxEdge, kısa kenar ≥ kutu', () {
    expect(
      BoundedImage.coverTarget(4000, 1000, coverEdge: 120, maxEdge: 1600),
      isA<ui.TargetImageSize>()
          .having((t) => t.width, 'width', 480)
          .having((t) => t.height, 'height', 120),
    );
    // Kutu maxEdge'den büyükse yalnızca maxEdge sınırı (varsayılan çözüm).
    expect(
      BoundedImage.coverTarget(3200, 1600, coverEdge: 2000, maxEdge: 1600),
      isA<ui.TargetImageSize>()
          .having((t) => t.width, 'width', 1600)
          .having((t) => t.height, 'height', 800),
    );
  });

  testWidgets('T-44 · coverEdgePx verilse de piksel sınırı aşan görsel '
      'çözülmeden reddedilir', (tester) async {
    await tester.runAsync(() async {
      final bytes = await _png(40, 30);
      await expectLater(
        _decodedSize(
          BoundedImage(
            MemoryImage(bytes),
            maxSourcePixels: 1199,
            coverEdgePx: 10,
          ),
        ),
        throwsA(isA<ImageTooLargeException>()),
      );
    });
  });

  test('uygulamanın kendi yüklediği görsel (uzun kenar ≤ seçici sınırı) ne '
      'reddedilir ne küçültülür', () {
    const edge = DeviceImagePickerService.maxEdgePx;

    expect(MediaConstants.imageDecodeMaxEdgePx, greaterThanOrEqualTo(edge));
    expect(
      MediaConstants.imageSourceMaxPixels,
      greaterThanOrEqualTo(edge * edge),
    );
  });

  test('eşitlik sarılan sağlayıcıya ve sınırlara bakar (her çizimde yeniden '
      'kurulan çözücü görseli yeniden yüklemez)', () {
    final bytes = Uint8List(1);
    final image = MemoryImage(bytes);

    expect(BoundedImage(image), BoundedImage(MemoryImage(bytes)));
    expect(BoundedImage(image).hashCode, BoundedImage(image).hashCode);
    expect(BoundedImage(image), isNot(BoundedImage(image, maxEdge: 10)));
    expect(
      BoundedImage(image),
      isNot(BoundedImage(image, maxSourcePixels: 10)),
    );
    expect(BoundedImage(image), isNot(BoundedImage(MemoryImage(Uint8List(1)))));
    // Her gösterim boyutu ayrı kayıttır (T-44).
    expect(
      BoundedImage(image, coverEdgePx: 120),
      BoundedImage(image, coverEdgePx: 120),
    );
    expect(
      BoundedImage(image, coverEdgePx: 120).hashCode,
      BoundedImage(image, coverEdgePx: 120).hashCode,
    );
    expect(BoundedImage(image), isNot(BoundedImage(image, coverEdgePx: 120)));
  });

  testWidgets('reddedilen görselin hücresi yer tutucuda kalır (hata yüzeye '
      'çıkmaz)', (tester) async {
    late final Uint8List bytes;
    await tester.runAsync(() async => bytes = await _png(40, 30));
    final rejected = BoundedImage(MemoryImage(bytes), maxSourcePixels: 1);

    await pumpPost(
      tester,
      ImageGrid(images: imagesOf(1), imageOf: (_) => rejected),
    );
    // Başlık gerçek kod çözücüyle okunur: ret gerçek zamanda gelir.
    await tester.runAsync(() => Future<void>.delayed(_settle));
    await tester.pump();

    expect(tester.takeException(), isNull);
    // Yer tutucu çizili; görselin yerinde `errorBuilder` çıktısı var.
    expect(find.byType(GuCover), findsOneWidget);
    expect(tester.widget<Image>(find.byType(Image)).image, rejected);
    expect(
      find.descendant(
        of: find.byType(Image),
        matching: find.byType(RawImage),
      ),
      findsNothing,
    );
  });
}

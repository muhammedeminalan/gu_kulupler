// T-35 · FakeQrScannerService sözleşmesi: kamera açmaz; okuma `emit` ile,
// yalnızca oturum açıkken akar; fener / kamera yönü / kapatma kaydedilir.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_kulupler/product/service/qr_scanner_service.dart';

import 'fake_base.dart';
import 'fake_qr_scanner_service.dart';
import 'register_fakes.dart';

void main() {
  group('T-35 · FakeQrScannerService', () {
    test('QrScannerService arayüzünü uygular; registerDefaultFakes '
        'kaydeder', () {
      addTearDown(GetIt.I.reset);
      registerDefaultFakes();
      expect(GetIt.I<QrScannerService>(), isA<FakeQrScannerService>());
    });

    test(
      'createController her çağrıda yeni oturum açar; last sonuncusudur',
      () {
        final fake = FakeQrScannerService();
        expect(fake.last, isNull);

        final first = fake.createController();
        final second = fake.createController();

        expect(fake.controllers, [first, second]);
        expect(fake.last, same(second));
        expect(fake.calls, [
          const FakeCall('createController'),
          const FakeCall('createController'),
        ]);
      },
    );

    test('okuma yalnızca start sonrası akar; stop / dispose keser', () async {
      final controller =
          FakeQrScannerService().createController() as FakeQrScannerController;
      final codes = <String>[];
      final subscription = controller.codes.listen(codes.add);
      addTearDown(subscription.cancel);

      expect(controller.emit('önce'), isFalse);
      await controller.start();
      expect(controller.isRunning, isTrue);
      expect(controller.emit('gu:ticket:v1:e17:GU-7KQ2-M9XA'), isTrue);
      await controller.stop();
      expect(controller.emit('durunca'), isFalse);
      await controller.start();
      expect(controller.emit('ikinci'), isTrue);
      await pumpEventQueue();

      expect(codes, ['gu:ticket:v1:e17:GU-7KQ2-M9XA', 'ikinci']);

      await controller.dispose();
      expect(controller.isDisposed, isTrue);
      expect(controller.isRunning, isFalse);
      expect(controller.emit('kapalı'), isFalse);
      await controller.dispose(); // ikinci kapatma etkisiz
      expect(controller.callsTo('dispose'), hasLength(1));
    });

    test('failNext → start kamerayı açmaz (platform hatası)', () async {
      final controller = FakeQrScannerController()..failNext();
      await controller.start();
      expect(controller.isRunning, isFalse);
      await controller.start();
      expect(controller.isRunning, isTrue);
    });

    test('fener ve kamera yönü çevrilir', () async {
      final controller = FakeQrScannerController();
      await controller.toggleTorch();
      await controller.switchCamera();
      expect(controller.torchOn, isTrue);
      expect(controller.frontCamera, isTrue);
      await controller.toggleTorch();
      await controller.switchCamera();
      expect(controller.torchOn, isFalse);
      expect(controller.frontCamera, isFalse);
    });

    testWidgets('önizleme sabit anahtarlı boş kutudur', (tester) async {
      final controller = FakeQrScannerController();
      await tester.pumpWidget(
        Builder(builder: controller.buildPreview),
      );
      expect(find.byKey(FakeQrScannerController.previewKey), findsOneWidget);
      unawaited(controller.dispose());
    });

    test('resetFake oturumları kapatır ve temizler', () async {
      final fake = FakeQrScannerService();
      final controller = fake.createController() as FakeQrScannerController;
      fake.resetFake();
      await pumpEventQueue();
      expect(controller.isDisposed, isTrue);
      expect(fake.controllers, isEmpty);
      expect(fake.calls, isEmpty);
    });
  });
}

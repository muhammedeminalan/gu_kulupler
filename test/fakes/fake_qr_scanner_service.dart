// `QrScannerService` fake'i (T-35, K-16): kamera açmaz; okuma testten
// `emit` ile verilir.
//
//   final scanner = GetIt.I<QrScannerService>() as FakeQrScannerService;
//   await tester.pumpWidget(...);                  // ScanView oturum açar
//   scanner.last!.emit(rsvp.qrPayload);            // sahte QR okuması
//   expect(scanner.last!.isRunning, isTrue);
//   expect(scanner.last!.torchOn, isTrue);         // MGT-07.torch
//
// Önizleme sabit anahtarlı boş bir kutudur ([FakeQrScannerController
// .previewKey]); ekran testleri önizlemenin çizildiğini bununla bulur.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:gu_kulupler/product/service/qr_scanner_service.dart';

import 'fake_base.dart';

final class FakeQrScannerService extends FakeBase implements QrScannerService {
  /// Açılan oturumlar, sırasıyla.
  final List<FakeQrScannerController> controllers = [];

  /// Son açılan oturum; hiç açılmadıysa `null`.
  FakeQrScannerController? get last =>
      controllers.isEmpty ? null : controllers.last;

  @override
  QrScannerController createController() {
    record('createController');
    final controller = FakeQrScannerController();
    controllers.add(controller);
    return controller;
  }

  @override
  void resetFake() {
    super.resetFake();
    for (final controller in controllers) {
      unawaited(controller.dispose());
    }
    controllers.clear();
  }
}

final class FakeQrScannerController extends FakeBase
    implements QrScannerController {
  /// Sahte önizlemenin anahtarı.
  static const Key previewKey = ValueKey<String>('fake-qr-scanner-preview');

  final StreamController<String> _codes = StreamController<String>.broadcast();

  /// Kamera açık mı ([start] → `true`, [stop] / [dispose] → `false`).
  bool isRunning = false;

  /// Fener açık mı ([toggleTorch] çevirir).
  bool torchOn = false;

  /// Ön kamera mı ([switchCamera] çevirir; varsayılan arka).
  bool frontCamera = false;

  /// [dispose] çağrıldı mı.
  bool isDisposed = false;

  /// Sahte QR okuması: [raw] içeriği [codes] akışına yazar. Kamera kapalıyken
  /// (gerçek tarayıcı gibi) okuma yoktur — `false` döner.
  bool emit(String raw) {
    if (!isRunning || isDisposed) return false;
    _codes.add(raw);
    return true;
  }

  @override
  Stream<String> get codes => _codes.stream;

  @override
  Future<void> start() async {
    record('start');
    if (takeFailure() != null) return; // platform hatası: kamera açılmaz
    isRunning = true;
  }

  @override
  Future<void> stop() async {
    record('stop');
    isRunning = false;
  }

  @override
  Future<void> toggleTorch() async {
    record('toggleTorch');
    torchOn = !torchOn;
  }

  @override
  Future<void> switchCamera() async {
    record('switchCamera');
    frontCamera = !frontCamera;
  }

  @override
  Widget buildPreview(BuildContext context) =>
      const SizedBox.expand(key: previewKey);

  @override
  Future<void> dispose() async {
    if (isDisposed) return;
    record('dispose');
    isDisposed = true;
    isRunning = false;
    await _codes.close();
  }
}

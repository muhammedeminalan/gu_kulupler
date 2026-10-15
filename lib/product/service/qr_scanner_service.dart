import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// QR tarayıcı (MGT-07, D-30, K-16): kamera oturumu açar, okunan ham QR
/// içeriklerini akıtır.
///
/// View ve ViewModel `mobile_scanner` paketini doğrudan içe aktarmaz: kamera
/// önizlemesi ve okuma akışı [QrScannerController] arkasındadır; testte
/// kamera yoktur (`FakeQrScannerService` — `emit(raw)` ile sahte okuma).
/// Kamera izni bu serviste **istenmez**: önce `PermissionService
/// .requestCamera()` (DLG-04 / TST-32), izin varsa [QrScannerController
/// .start].
///
/// View erişimi `qrScannerServiceProvider` ile (view'da `GetIt.I` yok —
/// HC13); ekran açılınca [createController], kapanınca
/// [QrScannerController.dispose].
// ignore: one_member_abstracts
abstract interface class QrScannerService {
  /// Yeni bir tarama oturumu (kamera kapalı başlar — [QrScannerController
  /// .start] çağrılana kadar açılmaz).
  QrScannerController createController();
}

/// Tek bir tarama oturumu: önizleme, okuma akışı, fener ve kamera yönü.
///
/// Hiçbir metot fırlatmaz: platform hatası günlüğe yazılır ve yok sayılır
/// (önizleme hata durumunda boş zemin çizer).
abstract interface class QrScannerController {
  /// Okunan QR içerikleri (`rawValue`, boş olmayan), okunduğu sırayla.
  /// Ayrıştırma çağıranın işidir (`TicketScanParser.parseQr`).
  Stream<String> get codes;

  /// Kamerayı açar ve okumaya başlar (izin verilmiş olmalı).
  Future<void> start();

  /// Kamerayı kapatır (SHT-24 açıkken okuma durur; `start` ile sürer).
  Future<void> stop();

  /// Feneri açar / kapatır (`MGT-07.torch`).
  Future<void> toggleTorch();

  /// Ön / arka kamera arasında geçer (`MGT-07.flip`).
  Future<void> switchCamera();

  /// Kamera önizlemesi; tam alanı kaplar (`BoxFit.cover`).
  Widget buildPreview(BuildContext context);

  /// Oturumu kapatır; sonra başka metot çağrılmaz.
  Future<void> dispose();
}

/// [QrScannerService] uygulaması: `mobile_scanner` (ML Kit bundled — K-16;
/// yalnızca QR biçimi, yinelenen okuma süzülür).
final class MobileQrScannerService implements QrScannerService {
  /// Varsayılan örnek.
  const MobileQrScannerService();

  @override
  QrScannerController createController() => MobileQrScannerController(
    MobileScannerController(
      autoStart: false,
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: const [BarcodeFormat.qrCode],
    ),
  );
}

/// [QrScannerController] uygulaması: `MobileScannerController` sarmalayıcısı.
final class MobileQrScannerController implements QrScannerController {
  /// [_controller] oturumunun sarmalayıcısı.
  MobileQrScannerController(this._controller);

  final MobileScannerController _controller;

  @override
  Stream<String> get codes => _controller.barcodes
      .expand((capture) => capture.barcodes)
      .map((barcode) => barcode.rawValue)
      .where((raw) => raw != null && raw.isNotEmpty)
      .cast<String>();

  @override
  Future<void> start() => _guard('start', _controller.start);

  @override
  Future<void> stop() => _guard('stop', _controller.stop);

  @override
  Future<void> toggleTorch() => _guard('toggleTorch', _controller.toggleTorch);

  @override
  Future<void> switchCamera() =>
      _guard('switchCamera', _controller.switchCamera);

  @override
  Widget buildPreview(BuildContext context) =>
      MobileScanner(controller: _controller);

  @override
  Future<void> dispose() => _guard('dispose', _controller.dispose);

  Future<void> _guard(String action, Future<void> Function() call) async {
    try {
      await call();
    } on Object catch (error, stackTrace) {
      AppLogger.warn(
        'QR tarayıcı: $action başarısız',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}

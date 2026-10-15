import 'package:get_it/get_it.dart';
import 'package:gu_kulupler/product/service/qr_scanner_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'qr_scanner_service_provider.g.dart';

/// View katmanının [QrScannerService] köprüsü (`feedbackServiceProvider`
/// kalıbı, CD-93): MGT-07 view'ı / mixin'i
/// `ref.read(qrScannerServiceProvider).createController()` kullanır; view'da
/// `GetIt.I` yoktur (HC13). Testte `registerDefaultFakes`
/// `FakeQrScannerService` kaydeder; ayrıca override gerekmez.
@Riverpod(keepAlive: true)
QrScannerService qrScannerService(Ref ref) => GetIt.I<QrScannerService>();

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/features/management/provider/scan_state.dart';
import 'package:gu_kulupler/features/management/provider/scan_view_model.dart';
import 'package:gu_kulupler/features/management/view/scan_view.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';
import 'package:gu_kulupler/product/service/qr_scanner_service.dart';
import 'package:gu_kulupler/product/service/qr_scanner_service_provider.dart';

/// MGT-07 davranışı: kamera oturumu (`QrScannerController` — açılışta
/// kurulur, kapanışta kapatılır), okunan içeriği ViewModel'e aktarma, kameranın
/// ViewModel durumuna göre açılıp kapanması ([ScanState.isCameraActive]:
/// izin var ve SHT-24 / okutma sürmüyor; uygulama arka plandayken kapalı),
/// fener / kamera çevir, elle kod alanı ve kapat.
mixin ScanViewMixin on ConsumerState<ScanView>, WidgetsBindingObserver {
  /// Kamera oturumu.
  late final QrScannerController scanner = ref
      .read(qrScannerServiceProvider)
      .createController();

  /// Elle kod alanı (`MGT-07.codeInput`); metni ViewModel'den eşlenir.
  final TextEditingController codeController = TextEditingController();

  StreamSubscription<String>? _codes;
  bool _running = false;
  bool _foreground = true;

  /// Ekranın ViewModel sağlayıcısı.
  ScanViewModelProvider get provider =>
      scanViewModelProvider(widget.clubId, widget.eventId);

  /// Ekranın ViewModel'i.
  ScanViewModel get viewModel => ref.read(provider.notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _codes = scanner.codes.listen((raw) {
      if (mounted) unawaited(viewModel.onCode(raw));
    });
    ref.listenManual(provider, (_, next) => _sync(next), fireImmediately: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_codes?.cancel());
    unawaited(scanner.dispose());
    codeController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!mounted) return;
    // Ayarlardan dönüldü: izin verildiyse kamera açılır.
    if (_foreground) unawaited(viewModel.recheckPermission());
    _sync(ref.read(provider));
  }

  /// Kamerayı ve kod alanını durumla eşler.
  void _sync(ScanState state) {
    final run = state.isCameraActive && _foreground;
    if (run != _running) {
      _running = run;
      unawaited(run ? scanner.start() : scanner.stop());
    }
    final code = state.manualCode;
    if (codeController.text != code) {
      codeController.value = TextEditingValue(
        text: code,
        selection: TextSelection.collapsed(offset: code.length),
      );
    }
  }

  /// Kapat (`MGT-07.close`): önceki sayfa; yığın yoksa MGT-06.
  void close() {
    if (context.canPop()) {
      context.pop();
    } else {
      AttendanceRoute(clubId: widget.clubId, eventId: widget.eventId).go(
        context,
      );
    }
  }

  /// Fener (`MGT-07.torch`).
  void toggleTorch() {
    unawaited(scanner.toggleTorch());
    viewModel.toggleTorch();
  }

  /// Kamera çevir (`MGT-07.flip`).
  void flipCamera() {
    unawaited(scanner.switchCamera());
    viewModel.flipCamera();
  }

  /// "Kod gir" (`MGT-07.manualCode`).
  void openManual() => viewModel.openManual();

  /// Kod alanı değişti (`MGT-07.codeInput`).
  void onCodeChanged(String value) => viewModel.setManualCode(value);

  /// "Doğrula" (`MGT-07.verify`) / klavye "bitti".
  void verify() => unawaited(viewModel.verifyManual());

  /// "Ayarlara git" (`MGT-07.permission.retry`).
  void retryPermission() => unawaited(viewModel.retryPermission());
}

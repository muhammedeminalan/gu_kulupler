// T-07 · toast grubu galeri golden'ı (`gu_gallery_toasts__default__*.png`):
// GuToast 3 tür + eylemli + uzun metin. Referans:
// `design/reference-shots/toasts/TST-01__light.webp` (error),
// `TST-41__light.webp` (success), `TST-24__dark.webp` (koyu, iki satır),
// `prototype-pages-desktop/ds_overlays.webp` (info + "Geri al"); eylem
// düğmesinin varlığı registry'den (K-44).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../helpers/golden_helper.dart';

void _noop() {}

class _Gallery extends StatelessWidget {
  const _Gallery();

  @override
  Widget build(BuildContext context) => const SizedBox(
    // 390 dp ekranda `.toast-wrap{left:12px;right:12px}`.
    width: 390 - 2 * GuSizes.toastMarginX,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: GuSpacing.s12,
      children: [
        // TST-05.
        GuToast(
          kind: GuToastKind.success,
          text: 'Değişiklikler kaydedildi.',
          onClose: _noop,
          closeSemanticLabel: 'Kapat',
        ),
        // TST-01.
        GuToast(
          kind: GuToastKind.error,
          text: 'E-posta veya şifre hatalı.',
          onClose: _noop,
          closeSemanticLabel: 'Kapat',
        ),
        GuToast(
          kind: GuToastKind.info,
          text: 'Bağlantı kopyalandı.',
          onClose: _noop,
          closeSemanticLabel: 'Kapat',
        ),
        // TST-27 (ds_overlays: "Geri al").
        GuToast(
          kind: GuToastKind.info,
          text: 'Bildirim silindi.',
          actionLabel: 'Geri al',
          onAction: _noop,
          onClose: _noop,
          closeSemanticLabel: 'Kapat',
        ),
        // TST-41.
        GuToast(
          kind: GuToastKind.success,
          text: 'Kaydın alındı. Biletin hazır.',
          actionLabel: 'Biletini göster',
          onAction: _noop,
          onClose: _noop,
          closeSemanticLabel: 'Kapat',
        ),
        // TST-24: iki satır.
        GuToast(
          kind: GuToastKind.error,
          text: 'Çevrimdışısın. Bu işlem için internet bağlantısı gerekli.',
          onClose: _noop,
          closeSemanticLabel: 'Kapat',
        ),
        // TST-32: uzun metin + eylem.
        GuToast(
          kind: GuToastKind.error,
          text: 'Kamera izni gerekli. QR kodu okutmak için izin ver.',
          actionLabel: 'Ayarlara git',
          onAction: _noop,
          onClose: _noop,
          closeSemanticLabel: 'Kapat',
        ),
      ],
    ),
  );
}

void main() {
  testWidgets('T-07 · toast grubu · galeri golden (açık + koyu)', (
    tester,
  ) async {
    await goldenForWidget(
      tester,
      'gu_gallery_toasts',
      {'default': const _Gallery()},
      size: const Size(420, 620),
    );
  });
}

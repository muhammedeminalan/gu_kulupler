import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/management/provider/scan_state.dart';
import 'package:gu_kulupler/features/management/view/mixin/scan_view_mixin.dart';
import 'package:gu_kulupler/features/management/view/widget/scan_overlay.dart';
import 'package:gu_ui/gu_ui.dart';

/// QR tarayıcı — `ScanRoute`
/// (`/clubs/:clubId/manage/events/:eventId/attendance/scan`); prototip
/// `Scanner` (`screens-manage.js:142–157`). MGT-06 "Tara" açar (guard `M`,
/// router'da). Kamera `QrScannerService` arkasındadır
/// (`qrScannerServiceProvider`); okunan içerik `TicketScanParser` ile
/// çözülür, sonuç SHT-24 (`ScanResultSheet`). Demo tarama düğmeleri yoktur
/// (K-02, K-04); durum çubuğu açık ikonlu (D-20).
///
/// * İzin varken: kamera önizlemesi + `ScanOverlay`.
/// * İzin yokken (DLG-04'te vazgeçildi / sistem reddetti): izin ekranı
///   (`screens-manage.js:149`) — "Kod gir" elle girişe geçer (kamerasız
///   katman), "Ayarlara git" izni yeniden ister ya da ayarları açar.
///
/// Design: MGT-07
class ScanView extends ConsumerStatefulWidget {
  /// [clubId] kulübünün [eventId] etkinliği için tarayıcı.
  const ScanView({required this.clubId, required this.eventId, super.key});

  /// Kulüp kimliği (`ScanRoute.clubId`).
  final String clubId;

  /// Etkinlik kimliği (`ScanRoute.eventId`).
  final String eventId;

  @override
  ConsumerState<ScanView> createState() => _ScanViewState();
}

class _ScanViewState extends ConsumerState<ScanView>
    with WidgetsBindingObserver, ScanViewMixin {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(provider);
    return GuSystemUi(
      style: GuSystemUiStyle.lightIcons,
      child: Scaffold(
        backgroundColor: context.gu.component.scanViewGradientEnd,
        body: state.showPermissionScreen
            ? _PermissionScreen(
                onClose: close,
                onManualCode: openManual,
                onSettings: retryPermission,
              )
            : _scanner(state),
      ),
    );
  }

  Widget _scanner(ScanState state) {
    final l10n = context.l10n;
    return ScanOverlay(
      preview: state.cameraAccess == ScanCameraAccess.granted
          ? scanner.buildPreview(context)
          : const SizedBox.expand(),
      title: state.event?.title ?? '',
      counterLabel: l10n.scanCounter(
        state.attendedCount.toString(),
        state.registeredCount.toString(),
      ),
      hintLabel: l10n.scanHint,
      onClose: close,
      onTorch: toggleTorch,
      onFlip: flipCamera,
      onManualCode: openManual,
      torchOn: state.torchOn,
      frontCamera: state.frontCamera,
      manualOpen: state.manualOpen,
      manualField: _ManualCodeField(
        controller: codeController,
        canVerify: state.canVerify,
        onChanged: onCodeChanged,
        onVerify: verify,
      ),
    );
  }
}

/// Elle kod satırı (`screens-manage.js:154`): "Bilet kodu" alanı
/// (`GU-XXXX-XXXX`) + "Doğrula" (12 karakterden kısa girdide devre dışı).
class _ManualCodeField extends StatelessWidget {
  const _ManualCodeField({
    required this.controller,
    required this.canVerify,
    required this.onChanged,
    required this.onVerify,
  });

  final TextEditingController controller;
  final bool canVerify;
  final ValueChanged<String> onChanged;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      spacing: GuSpacing.s8,
      children: [
        Expanded(
          child: GuInput(
            actionKey: GuKey.action('MGT-07.codeInput'),
            controller: controller,
            label: l10n.scanEnterCode,
            placeholder: l10n.scanCodePlaceholder,
            autofocus: true,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.done,
            onChanged: onChanged,
            onSubmitted: onVerify,
          ),
        ),
        GuButton(
          key: GuKey.action('MGT-07.verify'),
          label: l10n.scanVerify,
          onPressed: onVerify,
          disabled: !canVerify,
        ),
      ],
    );
  }
}

/// İzin yok (`screens-manage.js:149`): kapat + ortada kamera ikonu (64),
/// "Kamera izni gerekli", açıklama, "Kod gir" (outline) ve "Ayarlara git".
class _PermissionScreen extends StatelessWidget {
  const _PermissionScreen({
    required this.onClose,
    required this.onManualCode,
    required this.onSettings,
  });

  final VoidCallback onClose;
  final VoidCallback onManualCode;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final onCover = gu.component.onCoverForeground;
    return ScanBackdrop(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: GuInsets.sym(h: GuSpacing.s8, v: GuSpacing.s4),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: GuIconButton(
                  key: ScanOverlay.closeKey,
                  icon: GuIcons.x,
                  semanticLabel: l10n.a11yClose,
                  onCover: true,
                  onPressed: onClose,
                ),
              ),
            ),
            // `.empty.flex1` (css:300): ortalı, `gap:12px`, `32px 24px`.
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: GuInsets.sym(h: GuSpacing.s24, v: GuSpacing.s32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: GuSizes.emptyGap,
                    children: [
                      GuIcon(
                        GuIcons.camera,
                        size: GuSizes.icon64,
                        color: onCover,
                      ),
                      Text(
                        l10n.scanPermissionTitle,
                        style: gu.text.titleM.copyWith(color: onCover),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        l10n.scanPermissionDesc,
                        style: gu.text.bodyS.copyWith(
                          color: gu.component.scanMutedForeground,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      ScanOutlineButton(
                        key: ScanOverlay.manualCodeKey,
                        label: l10n.scanManualCode,
                        onPressed: onManualCode,
                      ),
                      GuButton(
                        key: GuKey.action('MGT-07.permission.retry'),
                        label: l10n.scanGoSettings,
                        onPressed: onSettings,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

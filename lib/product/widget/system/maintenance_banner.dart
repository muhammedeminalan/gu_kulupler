import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/product/init/app_gate_view_model.dart';
import 'package:gu_kulupler/product/widget/system/system_banner_slot.dart';
import 'package:gu_ui/gu_ui.dart';

/// Bakım mesajı bandı (CD-48, K-27): Remote Config `maintenance_message`
/// doluyken [child]'ın üstünde `GuBanner(kind: info)` çizer.
///
/// Tasarımda karşılığı yoktur (yeni ekran / kimlik açılmaz); `GuApp.builder`
/// zincirinde çevrimdışı bandının **altındadır**. Kapatılamaz, metin Remote
/// Config'ten olduğu gibi gelir (ARB yok); boş metinde çizilmez.
class MaintenanceBanner extends ConsumerWidget {
  /// Bakım bandı; [child] uygulama gövdesidir.
  const MaintenanceBanner({required this.child, super.key});

  /// Bandın altındaki içerik.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = ref.watch(
      appGateViewModelProvider.select((gate) => gate.maintenanceMessage),
    );
    return SystemBannerSlot(
      banner: message.isEmpty ? null : GuBanner(text: message),
      child: child,
    );
  }
}

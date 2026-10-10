import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/core/di/app_provider_mixin.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/widget/system/system_banner_slot.dart';
import 'package:gu_ui/gu_ui.dart';

/// Kök çevrimdışı bandı — SYS-03'ün bant varyantı (prototip `ScreenHost`,
/// `shell.js:14`: `Banner kind="offline"`; Q-12).
///
/// `GuApp.builder` zincirinde [child]'ı (uygulama gövdesi) sarar: cihaz
/// çevrimdışıyken ve [enabled] iken üstte `GuBanner(kind: offline)` çizer.
/// Okuma önbellekten sürer; yazma `WriteGuardMixin` ile engellenir (TST-24).
/// Tam ekran çevrimdışı görünümü bu değil `OfflineView`'dur.
///
/// Design: SYS-03
class OfflineBanner extends ConsumerWidget with AppProviderStateMixin {
  /// [enabled] `false` → çevrimdışıyken de bant çizilmez (uygulama kabuğu
  /// dışındaki ekranlar: açılış, giriş — prototip `nav.mode === 'app'`).
  const OfflineBanner({required this.child, this.enabled = true, super.key});

  /// Bandın altındaki içerik.
  final Widget child;

  /// Bant gösterilebilir mi?
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = isOfflineOf(ref) && enabled;
    return SystemBannerSlot(
      banner: visible
          ? GuBanner(
              kind: GuBannerKind.offline,
              text: context.l10n.sysOfflineBanner,
            )
          : null,
      child: child,
    );
  }
}

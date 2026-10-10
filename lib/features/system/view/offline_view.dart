import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/core/connectivity/connectivity_view_model.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/system/view/widget/system_screen_scaffold.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_ui/gu_ui.dart';

/// Tam ekran çevrimdışı görünümü — prototip `OfflineScreen`
/// (`screens-auth.js:38`) + `OfflineState` (`ui.js:110`): önbellekte
/// gösterilecek veri yokken. Önbellek varken yalnızca kök bant
/// (`OfflineBanner`) görünür.
///
/// "Yeniden dene" bağlantıyı yeniden okur: hâlâ çevrimdışıysa gövde sallanır
/// ve TST-24 gösterilir; bağlantı geldiyse ekrandan çıkılır.
///
/// Design: SYS-03
class OfflineView extends ConsumerWidget {
  /// Tam ekran çevrimdışı görünümü.
  const OfflineView({super.key});

  Future<bool> _retry(BuildContext context, WidgetRef ref) async {
    await ref.read(connectivityViewModelProvider.notifier).recheck();
    if (!context.mounted) return true;
    if (ref.read(connectivityViewModelProvider).isOffline) {
      ref.read(feedbackServiceProvider).showToast(ToastId.tst24);
      return false;
    }
    SystemScreenScaffold.leave(context);
    return true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return SystemScreenScaffold(
      backActionKey: GuKey.action('SYS-03.back'),
      child: GuOfflineState(
        title: l10n.sysOfflineTitle,
        description: l10n.sysOfflineFullDesc,
        retryLabel: l10n.commonRetry,
        retryActionKey: GuKey.action('SYS-03.retry'),
        onRetry: () => _retry(context, ref),
      ),
    );
  }
}

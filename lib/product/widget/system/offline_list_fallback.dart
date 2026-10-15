import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/core/connectivity/connectivity_view_model.dart';
import 'package:gu_kulupler/core/di/app_provider_mixin.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_ui/gu_ui.dart';

/// Liste ekranının boş / hata gövdesinin çevrimdışı karşılığı — SYS-03'ün
/// liste içi varyantı (PLAN §12.1; Q-12; T-44 · A4-03).
///
/// Cihaz çevrimdışıyken ve liste **boş ya da hatalıyken** (önbellekte
/// gösterilecek veri yok) "Henüz … yok" / "Bir şeyler ters gitti" yerine
/// [GuOfflineState] çizilir. Veri varken çevrimdışılık yalnızca kök banttır
/// (`OfflineBanner`; `states/*__offline.webp`) — bu widget kullanılmaz.
///
/// * "Yeniden dene" (`SYS-03.retry`) `OfflineView` ile aynı: bağlantı yeniden
///   okunur; hâlâ çevrimdışıysa TST-24 + gövde sallanır.
/// * Bağlantı geri gelince [onReload] **bir kez** kendiliğinden çağrılır
///   (sessiz yenileme): boş / hatalı kalan ekran elle yenilemeyi beklemez.
///
/// Çevrimiçiyken [child] çizilir (verilmezse boş alan). Liste görünümleri
/// [applies] ile karar verip [sliver]'ı switch'in yerine koyar; kutu
/// bağlamında (`GuListState` kurucuları) [child] ile sarılır.
///
/// Design: SYS-03
class OfflineListFallback extends ConsumerStatefulWidget {
  /// [onReload] ekranın mevcut yenileme / yeniden deneme metodu.
  const OfflineListFallback({required this.onReload, this.child, super.key});

  /// Bağlantı dönünce (ve "Yeniden dene" ile çevrimiçi olunca) listeyi
  /// yeniden okur.
  final Future<void> Function() onReload;

  /// Çevrimiçi gövde (ekranın boş / hata durumu).
  final Widget? child;

  /// Liste [status] durumunda tam liste çevrimdışı gövdesi gösterilmeli mi
  /// (çevrimdışı + boş / hata)? Bağlantı durumu izlenir.
  static bool applies(WidgetRef ref, GuListStatus status) =>
      (status == GuListStatus.empty || status == GuListStatus.error) &&
      ref.watch(connectivityViewModelProvider.select((s) => s.isOffline));

  /// Liste switch'inin yerine geçen sliver.
  static Widget sliver({required Future<void> Function() onReload}) =>
      SliverToBoxAdapter(child: OfflineListFallback(onReload: onReload));

  @override
  ConsumerState<OfflineListFallback> createState() =>
      _OfflineListFallbackState();
}

class _OfflineListFallbackState extends ConsumerState<OfflineListFallback>
    with AppProviderMixin {
  /// `OfflineView._retry` ile aynı: bağlantı yeniden okunur; çevrimiçine
  /// geçiş dinleyiciyi tetikler ([OfflineListFallback.onReload]).
  Future<bool> _retry() async {
    await ref.read(connectivityViewModelProvider.notifier).recheck();
    if (!mounted) return true;
    if (ref.read(connectivityViewModelProvider).isOffline) {
      ref.read(feedbackServiceProvider).showToast(ToastId.tst24);
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(
      connectivityViewModelProvider.select((s) => s.isOffline),
      (previous, next) {
        if (previous ?? false) {
          if (!next) unawaited(widget.onReload());
        }
      },
    );
    if (!isOffline) return widget.child ?? const SizedBox.shrink();
    final l10n = context.l10n;
    return GuOfflineState(
      title: l10n.sysOfflineTitle,
      description: l10n.sysOfflineFullDesc,
      retryLabel: l10n.commonRetry,
      retryActionKey: GuKey.action('SYS-03.retry'),
      onRetry: _retry,
    );
  }
}

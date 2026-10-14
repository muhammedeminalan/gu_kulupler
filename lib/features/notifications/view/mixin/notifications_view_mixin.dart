import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/notifications/provider/notifications_state.dart';
import 'package:gu_kulupler/features/notifications/provider/notifications_view_model.dart';
import 'package:gu_kulupler/features/notifications/view/notifications_view.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';
import 'package:gu_ui/gu_ui.dart';

/// NTF-01 davranışı: başa kaydırma, üst çubuk (tümünü okundu, ayarlar), izin
/// bandı, filtre, satır eylemleri.
///
/// * Etkin sekmeye yeniden dokunma (`scrollTopRequestProvider`, PLAN §13.2)
///   listeyi başa kaydırır; filtre değişince de liste başa döner.
/// * Ekran açılınca izin bandı sistem izninden yenilenir (kabuk DLG-03'ü bu
///   arada cevaplatmış olabilir).
/// * Ayarlar (`NTF-01.settings`) → NTF-02 (`go`; Bildirimler dalı).
/// * Toast'ları ViewModel gösterir (TST-16, TST-18, TST-19, TST-24).
mixin NotificationsViewMixin on ConsumerState<NotificationsView> {
  /// Listenin kaydırma denetleyicisi.
  final ScrollController scrollController = ScrollController();

  ProviderSubscription<int>? _scrollTopSubscription;

  /// Ekranın ViewModel'i.
  NotificationsViewModel get viewModel =>
      ref.read(notificationsViewModelProvider.notifier);

  Duration get _scrollDuration =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : GuMotion.base;

  @override
  void initState() {
    super.initState();
    _scrollTopSubscription = ref.listenManual(
      scrollTopRequestProvider(GuTab.notifications),
      (_, _) => scrollToTop(),
    );
    unawaited(
      Future<void>.microtask(() {
        if (mounted) unawaited(viewModel.checkPermission());
      }),
    );
  }

  @override
  void dispose() {
    _scrollTopSubscription?.close();
    scrollController.dispose();
    super.dispose();
  }

  /// Listeyi başa kaydırır.
  void scrollToTop() {
    if (!scrollController.hasClients) return;
    unawaited(
      scrollController.animateTo(
        0,
        duration: _scrollDuration,
        curve: GuMotion.easeStandard,
      ),
    );
  }

  /// "Tümünü okundu say" (`NTF-01.markAllRead`) → TST-18.
  void markAllRead() => unawaited(viewModel.markAllRead());

  /// Ayarlar (`NTF-01.settings`) → NTF-02.
  void openSettings() {
    if (!mounted) return;
    const NotificationPrefsRoute().go(context);
  }

  /// İzin bandı "Aç" (`NTF-01.enable`) → DLG-03 → sistem izni.
  void enableNotifications() => unawaited(viewModel.requestPermission());

  /// İzin bandı kapat (`NTF-01.dismissBanner`).
  void dismissBanner() => viewModel.dismissPermissionBanner();

  /// Filtre çipi (`NTF-01.filter.<id>`): liste başa döner.
  void selectFilter(NotificationFilter filter) {
    if (scrollController.hasClients) scrollController.jumpTo(0);
    viewModel.setFilter(filter);
  }

  /// Çek-yenile (`NTF-01.refresh`) / "Yeniden dene" (`NTF-01.retry`).
  Future<void> refresh() => viewModel.refresh();

  /// Satır (`NTF-01.item.<id>`) → okundu + hedef.
  void openNotification(NotificationModel notification) =>
      unawaited(viewModel.open(notification));

  /// Sağa kaydırma / menü "Okundu yap".
  void markRead(NotificationModel notification) =>
      unawaited(viewModel.markRead(notification.id));

  /// Sola kaydırma / menü "Sil" → TST-16.
  void remove(NotificationModel notification) =>
      unawaited(viewModel.softDelete(notification.id));

  /// Menü "Bu türü kapat" → TST-19.
  void mute(NotificationModel notification) =>
      unawaited(viewModel.muteType(notification));
}

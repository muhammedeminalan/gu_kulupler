import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/format/app_date_formats.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/notifications/provider/notifications_view_model.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/catalogs/toasts/toast_catalog.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/notification_navigator.dart';
import 'package:gu_kulupler/product/notification/notification_lookups.dart';
import 'package:gu_kulupler/product/widget/notification/notification_texts.dart';

/// Bildirimin TST-55 bandındaki başlığı (satırla aynı metin —
/// `NotificationRow.title`).
typedef NotificationTitleBuilder =
    String Function(BuildContext context, NotificationModel notification);

/// TST-55 ön plan bandı köprüsü ("Yeni bildirim: {başlık}" · Görüntüle;
/// PLAN §15.5): kabuğu ([child]) sarar, uygulama açıkken akışa
/// `createdAt > sessionStartedAt` olan yeni bildirim düşünce
/// (`NotificationsState.incoming`) `FeedbackService` ile TST-55 gösterir
/// (toast kuralı: en çok bir, eylemli 6 sn). NTF-01 açıkken ya da uygulama
/// ön planda değilken gösterilmez. "Görüntüle" → `NotificationNavigator.open`
/// (okundu + hedef). Her gelen bildirim `NotificationsViewModel
/// .consumeIncoming` ile tüketilir (gösterilse de gösterilmese de).
///
/// Kabukta (`AppShellView`) bir kez kurulur.
class ForegroundNotificationBanner extends ConsumerStatefulWidget {
  /// [child] kabuğunu saran dinleyici; [titleOf] bant başlığını üretir
  /// (verilmezse NTF-01 satır başlığı — `NotificationTexts.title`; adı henüz
  /// okunmamış kulüp / etkinlik varsa [fallbackTitle]).
  const ForegroundNotificationBanner({
    required this.child,
    this.titleOf,
    super.key,
  });

  /// Sarılan kabuk.
  final Widget child;

  /// Bant başlığı (NTF-01 satırının başlığıyla aynı); `null` → [titleFor].
  final NotificationTitleBuilder? titleOf;

  /// Ad çözümü gerektirmeyen tür başlığı (`notifType.<type>.title`); kulüp /
  /// etkinlik adı isteyen türlerde (`announcement`, `eventNew`,
  /// `eventReminder`, `system`) tercih grubunun adı.
  static String fallbackTitle(AppLocalizations l10n, NotificationModel n) =>
      switch (n.type) {
        NotificationType.applicationReceived =>
          l10n.notifTypeApplicationReceivedTitle,
        NotificationType.applicationApproved =>
          l10n.notifTypeApplicationApprovedTitle,
        NotificationType.applicationRejected =>
          l10n.notifTypeApplicationRejectedTitle,
        NotificationType.removedFromClub => l10n.notifTypeRemovedFromClubTitle,
        NotificationType.roleChanged => l10n.notifTypeRoleChangedTitle,
        NotificationType.eventCancelled => l10n.notifTypeEventCancelledTitle,
        NotificationType.waitlistPromoted =>
          l10n.notifTypeWaitlistPromotedTitle,
        NotificationType.reportResolved => l10n.notifTypeReportResolvedTitle,
        NotificationType.newReport => l10n.notifTypeNewReportTitle,
        NotificationType.announcement => l10n.notifPrefsAnnouncements,
        NotificationType.eventNew => l10n.notifPrefsNewEvents,
        NotificationType.eventReminder => l10n.notifPrefsEventReminders,
        NotificationType.system ||
        NotificationType.unknown => l10n.notifPrefsSystem,
      };

  /// Varsayılan bant başlığı: NTF-01 satırının başlığı
  /// (`NotificationTexts.title`, [lookups] adlarıyla); başlığın istediği ad
  /// (kulüp / etkinlik) henüz okunmamışsa [fallbackTitle] — "{ad}" boş
  /// kalmaz.
  static String titleFor(
    AppLocalizations l10n,
    AppDateFormats formats,
    NotificationModel n,
    NotificationLookups lookups,
  ) {
    final nameId = switch (n.type) {
      NotificationType.announcement => n.refs.clubId,
      NotificationType.eventNew ||
      NotificationType.eventReminder => n.refs.eventId,
      _ => '',
    };
    if (nameId == null || (nameId.isNotEmpty && !lookups.isResolved(nameId))) {
      return fallbackTitle(l10n, n);
    }
    return NotificationTexts(l10n, formats).title(n, lookups);
  }

  @override
  ConsumerState<ForegroundNotificationBanner> createState() =>
      _ForegroundNotificationBannerState();
}

class _ForegroundNotificationBannerState
    extends ConsumerState<ForegroundNotificationBanner> {
  @override
  Widget build(BuildContext context) {
    ref.listen(
      notificationsViewModelProvider.select((s) => s.incoming),
      (_, next) {
        if (next != null) _onIncoming(next);
      },
    );
    return widget.child;
  }

  void _onIncoming(NotificationModel notification) {
    ref.read(notificationsViewModelProvider.notifier).consumeIncoming();
    if (!mounted || !_isForeground || _isOnInbox) return;
    final title =
        widget.titleOf?.call(context, notification) ??
        ForegroundNotificationBanner.titleFor(
          context.l10n,
          AppDateFormats(
            Localizations.localeOf(context),
            ref.read(appClockProvider),
          ),
          notification,
          ref.read(notificationsViewModelProvider).lookups,
        );
    ref
        .read(feedbackServiceProvider)
        .showToast(
          ToastId.tst55,
          params: ToastParams(title: title),
          onAction: () => _open(notification),
        );
  }

  void _open(NotificationModel notification) {
    if (!mounted) return;
    unawaited(ref.read(notificationNavigatorProvider).open(notification));
  }

  /// Uygulama ön planda mı (yaşam döngüsü bilinmiyorsa evet)?
  static bool get _isForeground {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    return lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  /// NTF-01 (Bildirimler sekme kökü) açık mı?
  bool get _isOnInbox =>
      GoRouter.maybeOf(
        context,
      )?.routerDelegate.currentConfiguration.uri.path ==
      AppPaths.notifications;
}

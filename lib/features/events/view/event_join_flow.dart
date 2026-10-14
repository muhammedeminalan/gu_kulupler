import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/events/provider/event_detail_state.dart';
import 'package:gu_kulupler/features/events/provider/event_detail_view_model.dart';
import 'package:gu_kulupler/features/events/view/widget/rsvp_confirm_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';
import 'package:gu_kulupler/product/widget/event/event_cta.dart';

/// EVT-02 dışındaki etkinlik kartından katılım (CLB-03 `join.<eventId>`;
/// prototip `eventQuickAction`, `cards.js:58–67`): EVT-02 ile **aynı**
/// ViewModel ve sheet / dialog'lar kullanılır, ekran açılmaz.
///
/// * [EventCtaKind.join] → çevrimdışıysa TST-24; SHT-12 (çakışma uyarısıyla)
///   → seçilen hatırlatıcıyla katılım → TST-41 ("Biletini göster" → EVT-03)
///   ya da TST-43.
/// * [EventCtaKind.joinWaitlist] → DLG-15 → katılım (W-81 (a): karar
///   kartta `EventModel.joinsWaitlist` ile verilmiştir).
/// * Diğer türler akış değildir → `false`.
///
/// `true` → kayıt yazıldı (çağıran listeyi yeniden okur). ViewModel akış
/// süresince canlı tutulur, sonra bırakılır. Rota (kompozisyon kökü) bu
/// fonksiyonu `ClubDetailView.eventJoinFlow` olarak verir; `features/clubs`
/// onu içe aktarmaz.
///
/// Design: SHT-12, DLG-15
Future<bool> runEventJoinFlow(
  BuildContext context,
  EventModel event,
  EventCtaKind kind,
) async {
  if (kind != EventCtaKind.join && kind != EventCtaKind.joinWaitlist) {
    return false;
  }
  final container = ProviderScope.containerOf(context, listen: false);
  final provider = eventDetailViewModelProvider(event.id);
  final loaded = Completer<EventDetailState>();
  final subscription = container.listen<EventDetailState>(provider, (_, next) {
    if (!next.isFetching && !loaded.isCompleted) loaded.complete(next);
  }, fireImmediately: true);
  try {
    final state = await loaded.future;
    final current = state.event;
    if (current == null || !context.mounted) return false;
    final viewModel = container.read(provider.notifier);
    final EventJoinOutcome outcome;
    if (kind == EventCtaKind.joinWaitlist) {
      outcome = await viewModel.joinWaitlist();
    } else {
      if (!viewModel.ensureCanJoin()) return false;
      final conflict = await viewModel.hasConflict();
      if (!context.mounted) return false;
      final reminder = await container
          .read(feedbackServiceProvider)
          .showSheet<ReminderOption>(
            SheetId.sht12,
            builder: (_) =>
                RsvpConfirmSheet(event: current, hasConflict: conflict),
          );
      if (reminder == null || !context.mounted) return false;
      outcome = await viewModel.join(
        reminder,
        onTicket: () {
          if (context.mounted) TicketRoute(eventId: event.id).go(context);
        },
      );
    }
    return outcome != EventJoinOutcome.failed;
  } finally {
    subscription.close();
  }
}

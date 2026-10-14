import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/format/app_date_formats.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/events/provider/ticket_state.dart';
import 'package:gu_kulupler/features/events/view/mixin/ticket_view_mixin.dart';
import 'package:gu_kulupler/features/events/view/widget/ticket_card.dart';
import 'package:gu_kulupler/product/widget/event/event_place_label.dart';
import 'package:gu_ui/gu_ui.dart';

/// Bilet — `TicketRoute` (`/events/:eventId/ticket`); prototip `S['EVT-03']`
/// (`screens-events.js:77–87`).
///
/// Çubuk: geri + "Takvime ekle" (SHT-14). Gövde (`col gap16 px16`):
/// `TicketCard` (QR + kod + ad), "Etkinliğe git", geçerli ve bitmemişse
/// "Vazgeç" (DLG-14). Bilet durumu canlıdır (`TicketViewModel`,
/// `rsvpRepository.watchMine`); okutulduğu anda TST-15, QR bulanıklaşır.
///
/// * Durum sırası: hata ("Yeniden dene") → yükleniyor (kart iskeleti) →
///   dolu. Kayıt yoksa EVT-02'ye, etkinlik yoksa SYS-04'e gidilir; geçiş
///   karesinde boş zemin kalır. Çevrimdışı bandı kökte çizilir; bilet ekranda
///   kalır, "Vazgeç" TST-24 verir.
/// * Uygulanmayanlar: `EVT-03.demoScan` (K-02 demo) ve "Ekran parlaklığı
///   artırıldı" rozeti (parlaklık paketi yok; rozet gerçeği söylemez).
///
/// Davranış `TicketViewMixin`'dedir.
///
/// Design: EVT-03
class TicketView extends ConsumerStatefulWidget {
  /// [eventId] etkinliğinin bileti.
  const TicketView({required this.eventId, super.key});

  /// Etkinlik kimliği (`TicketRoute.eventId`).
  final String eventId;

  @override
  ConsumerState<TicketView> createState() => _TicketViewState();
}

class _TicketViewState extends ConsumerState<TicketView> with TicketViewMixin {
  /// Bilet içeriği: kart + düğmeler.
  Widget _content(
    TicketViewState state,
    EventModel event,
    RsvpModel rsvp,
    TicketState status,
  ) {
    final l10n = context.l10n;
    final clock = ref.watch(appClockProvider);
    final formats = AppDateFormats(Localizations.localeOf(context), clock);
    final holder = ref.watch(
      sessionViewModelProvider.select((session) => session.user?.name),
    );
    final scannedAt = rsvp.scannedAt ?? clock.nowUtc();
    return SingleChildScrollView(
      padding: GuInsets.only(
        left: GuSpacing.s16,
        right: GuSpacing.s16,
        bottom:
            MediaQuery.paddingOf(context).bottom +
            GuSizes.screenScrollBottomExtra,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: GuSpacing.s16,
        children: [
          TicketCard(
            event: event,
            rsvp: rsvp,
            state: status,
            clubName: state.club?.name ?? '',
            holderName: holder ?? '',
            placeLabel: EventPlaceLabel.of(context, event),
            dateLabel: formats.dateTime(l10n, event.startsAt),
            scannedAtLabel: l10n.ticketScannedAt(
              formats.dateTime(l10n, scannedAt),
            ),
            qrSemanticLabel: l10n.a11yTicketQr(
              TicketCard.badgeLabelOf(l10n, status),
            ),
          ),
          GuButton(
            key: GuKey.action('EVT-03.openEvent'),
            label: l10n.ticketOpenEvent,
            variant: GuButtonVariant.text,
            full: true,
            onPressed: openEvent,
          ),
          if (state.canLeaveAt(clock.nowUtc()))
            GuButton(
              key: GuKey.action('EVT-03.leave'),
              label: l10n.eventCtaLeave,
              variant: GuButtonVariant.dangerOutline,
              full: true,
              loading: state.isLeaving,
              onPressed: () => unawaited(leave()),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final state = ref.watch(provider);
    watchRedirects();
    final event = state.event;
    final rsvp = state.rsvp;
    final status = state.status;

    // Sıra: hata → yükleniyor → dolu. İçerik varken gelen hata içeriği
    // silmez.
    final Widget body;
    if (event != null && rsvp != null && status != null) {
      body = _content(state, event, rsvp, status);
    } else if (state.isError) {
      body = Center(
        child: SingleChildScrollView(
          child: GuErrorState(
            title: l10n.sysErrorTitle,
            description: l10n.sysErrorDesc,
            retryLabel: l10n.commonRetry,
            retryActionKey: GuKey.action('EVT-03.retry'),
            onRetry: retry,
          ),
        ),
      );
    } else if (state.isNotFound || state.hasNoTicket) {
      // SYS-04 / EVT-02'ye gidilir; geçiş karesinde boş zemin kalır.
      body = const SizedBox.expand();
    } else {
      body = SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: GuSkeletonList(
          semanticLabel: l10n.commonLoading,
          count: 1,
          variant: GuSkeletonVariant.card,
        ),
      );
    }

    return Scaffold(
      backgroundColor: gu.colors.bgCanvas,
      appBar: GuAppBar(
        title: l10n.ticketTitle,
        onBack: goBack,
        backSemanticLabel: l10n.a11yBack,
        backActionKey: GuKey.action('EVT-03.back'),
        actions: [
          GuIconButton(
            key: GuKey.action('EVT-03.addToCalendar'),
            icon: GuIcons.calendarPlus,
            semanticLabel: l10n.eventAddToCalendar,
            disabled: event == null,
            onPressed: () => unawaited(openCalendar()),
          ),
        ],
      ),
      body: body,
    );
  }
}

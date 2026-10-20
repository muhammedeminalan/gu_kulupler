import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/events/provider/event_detail_state.dart';
import 'package:gu_kulupler/features/events/provider/event_detail_view_model.dart';
import 'package:gu_kulupler/features/events/view/mixin/event_detail_view_mixin.dart';
import 'package:gu_kulupler/features/events/view/widget/event_detail_cta_bar.dart';
import 'package:gu_kulupler/features/events/view/widget/event_detail_sections.dart';
import 'package:gu_kulupler/features/events/view/widget/event_header.dart';
import 'package:gu_kulupler/features/events/view/widget/reminder_sheet.dart';
import 'package:gu_kulupler/product/l10n/cancel_reason_labels.dart';
import 'package:gu_kulupler/product/widget/event/event_card_status.dart';
import 'package:gu_kulupler/product/widget/event/event_cta.dart';
import 'package:gu_ui/gu_ui.dart';

/// Etkinlik detayı — `EventDetailRoute` (`/events/:eventId?showCancelled=`);
/// prototip `S['EVT-02']` (`screens-events.js:37–75`).
///
/// Kapaklı paralaks başlık (`EventHeader`: kapak, bantlar, başlık, kulüp,
/// rozetler, tarih / mekân kartı), kontenjan, hatırlatıcı / takvim kartı,
/// açıklama, katılımcı satırı, şikayet (`EventDetailSections`); alt çubuk
/// durumdan türetilir (`EventDetailCtaBar`: `EventCta` + EVT-02'ye özgü
/// vazgeç / bekleme / yönetici çubukları). İptal edilmiş etkinlikte
/// açılışta bir kez DLG-16 ([showCancelled] bildirimden gelir — her
/// zaman gösterilir).
///
/// * Durumlar (sıra: hata → yükleniyor → dolu): etkinlik okunamadıysa başlık
///   çubuğu + "Bir şeyler ters gitti" + "Yeniden dene"; okunurken başlık
///   çubuğu + iskelet; yok / silinmiş → SYS-04; okuma izni yok (üyelere özel
///   etkinlik derin bağlantısı) → TST-X18 + Etkinlikler (CD-57). Boş durumu
///   yoktur. Çevrimdışı bandı kökte çizilir; içerik ekranda kalır, yazan
///   eylemler TST-24 verir.
/// * Kapak durum çubuğunun altına uzanır: durum çubuğu açık ikonludur
///   (D-20); kapak yukarı kayınca tema stiline döner ve üst güvenli alan
///   `bg.canvas` şeridiyle kapanır (`ClubDetailView` ile aynı).
///
/// Davranış `EventDetailViewMixin`'dedir.
///
/// Design: EVT-02
class EventDetailView extends ConsumerStatefulWidget {
  /// [eventId] etkinliğinin detayı.
  const EventDetailView({
    required this.eventId,
    this.showCancelled = false,
    super.key,
  });

  /// Etkinlik kimliği (`EventDetailRoute.eventId`).
  final String eventId;

  /// "Etkinlik iptal edildi" bildiriminden açıldı (`?showCancelled=true`).
  final bool showCancelled;

  @override
  ConsumerState<EventDetailView> createState() => _EventDetailViewState();
}

class _EventDetailViewState extends ConsumerState<EventDetailView>
    with EventDetailViewMixin {
  /// Yükleniyor iskeletindeki kart sayısı.
  static const int _skeletonCards = 3;

  /// Hata ve yükleniyor görünümlerinin kabuğu: başlık çubuğu + gövde.
  Widget _pending({required Widget body}) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: context.gu.colors.bgCanvas,
      appBar: GuAppBar(
        title: l10n.eventTitle,
        onBack: back,
        backSemanticLabel: l10n.a11yBack,
        backActionKey: GuKey.action('EVT-02.back'),
      ),
      body: SafeArea(top: false, child: body),
    );
  }

  Widget _loaded(EventDetailState state) {
    final gu = context.gu;
    final l10n = context.l10n;
    final colors = gu.colors;
    final event = state.event!;
    final club = state.club!;
    final nowUtc = ref.watch(appClockProvider).nowUtc();
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final status = state.statusAt(nowUtc);
    final bar = state.barAt(nowUtc);
    final isPast = state.isPastAt(nowUtc);
    final isCancelled = event.status == EventStatus.cancelled;
    final rsvp = state.activeRsvp;
    final placeLabel = placeLabelOf(event);
    final coverImage = coverImageOf(event);

    final page = Scaffold(
      backgroundColor: colors.bgCanvas,
      body: Column(
        children: [
          Expanded(
            child: GuRefresh(
              onRefresh: refresh,
              noSafe: true,
              child: CustomScrollView(
                controller: scrollController,
                slivers: [
                  // Üst güvenli alan şeridi: kapak görünürken saydam, kapak
                  // çıkınca `bg.canvas`.
                  PinnedHeaderSliver(
                    child: ValueListenableBuilder<double>(
                      valueListenable: parallaxOffset,
                      builder: (context, offset, child) => Opacity(
                        opacity: topStripOpacity(offset, topInset),
                        child: child,
                      ),
                      child: IgnorePointer(
                        child: ColoredBox(
                          color: colors.bgCanvas,
                          child: SizedBox(
                            height: topInset,
                            width: double.infinity,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: ValueListenableBuilder<double>(
                      valueListenable: parallaxOffset,
                      builder: (context, offset, _) => EventHeader(
                        event: event,
                        club: club,
                        status: status,
                        placeLabel: placeLabel,
                        dateLabel: dateLabelOf(event),
                        timeLabel: timeLabelOf(event),
                        coverImage: coverImage,
                        scrollOffset: offset,
                        onBack: back,
                        onShare: openShare,
                        onMenu: openMenu,
                        onClub: openClub,
                        onDirections: openDirections,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: EventDetailSections(
                      event: event,
                      expanded: aboutExpanded,
                      showReminder: !isPast && !isCancelled,
                      reminderLabel: rsvp == null
                          ? null
                          : ReminderSheet.labelOf(l10n, rsvp.reminder),
                      showAttendees: state.seesInside,
                      showReport: !state.canManage && !state.isAdvisor,
                      onReminder: openReminder,
                      onCalendar: openCalendar,
                      onReadMore: readMore,
                      onAttendees: openAttendeesPreview,
                      onReport: openReport,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (bar != null)
            EventDetailCtaBar(
              bar: bar,
              ctaKind: EventCtaKind.of(status: status, event: event),
              attended: status == EventCardStatus.attended,
              waitlistPosition: state.waitlistPosition,
              cancelledText: cancelledTextOf(
                event,
                CancelReasonLabels.of(l10n, event.cancelReason),
              ),
              isActing: state.isActing,
              onJoin: join,
              onClosed: showClosed,
              onJoinWaitlist: joinWaitlist,
              onApplyClub: openClub,
              onTicket: openTicket,
              onLeave: leave,
              onEnded: showEnded,
              onEdit: openEdit,
              onAttendees: openAttendees,
              onScan: openScan,
            ),
        ],
      ),
    );

    return ValueListenableBuilder<bool>(
      valueListenable: coverUnderStatusBar,
      builder: (context, underCover, child) => GuSystemUi(
        style: underCover ? GuSystemUiStyle.lightIcons : GuSystemUiStyle.auto,
        child: child!,
      ),
      child: page,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(eventDetailViewModelProvider(widget.eventId));

    if (state.isError && state.event == null) {
      return _pending(
        body: Center(
          child: SingleChildScrollView(
            child: GuErrorState(
              title: l10n.sysErrorTitle,
              description: l10n.sysErrorDesc,
              retryLabel: l10n.commonRetry,
              retryActionKey: GuKey.action('EVT-02.retry'),
              onRetry: retry,
            ),
          ),
        ),
      );
    }
    if (state.event != null && state.club != null) return _loaded(state);
    // Yok / izin yok → gezinilir; geçiş karesinde boş zemin kalır.
    return _pending(
      body: state.isNotFound || state.isDenied
          ? const SizedBox.expand()
          : SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: GuSkeletonList(
                semanticLabel: l10n.commonLoading,
                count: _skeletonCards,
                variant: GuSkeletonVariant.card,
              ),
            ),
    );
  }
}

import 'package:flutter/widgets.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/widget/event/event_card.dart';
import 'package:gu_kulupler/product/widget/event/event_card_status.dart';
import 'package:gu_kulupler/product/widget/event/event_cta.dart';
import 'package:gu_ui/gu_ui.dart';

/// CLB-03 "Etkinlikler" sekmesinin dilimi (`CLB-03.eventSeg.*`).
enum ClubEventSegment {
  /// Yaklaşan etkinlikler (varsayılan).
  upcoming,

  /// Geçmiş ve iptal edilmiş etkinlikler.
  past,
}

/// CLB-03 "Etkinlikler" sekmesi — prototip `screens-clubs.js:81, 102–104`.
/// Yatay 16, üst 16, alt 24 dolgulu sütun, aralık 12: "Yaklaşan / Geçmiş"
/// dilimi · (kulübün içini görmeyene) "Üyelere özel etkinlikleri görmek için
/// kulübe katıl." bilgi bandı · etkinlik listesi (`GuListState`: hata →
/// 3 kart iskeleti → "Etkinlik yok" → `EventCard(compact, showClub: false)`
/// satırları).
///
/// * Dilim süzgeci [visible]: yaklaşan = bitmemiş ve iptal edilmemiş, en
///   yakın üstte; geçmiş = bitmiş ya da iptal edilmiş, en yeni üstte.
/// * Kart durumu ve hızlı eylemi `EventCardStatus.of` / `EventCtaKind.of`
///   ile [rsvps] kayıtlarından türetilir; dokunmalar çağırana gider
///   ([onEvent], [onQuickAction]).
/// * Anahtarlar çağırandan gelir (D-18): [cardKeyOf] `CLB-03.card.<id>`,
///   [joinKeyOf] `CLB-03.join.<id>`, [segmentKeyOf] `CLB-03.eventSeg.<dilim>`,
///   [retryKey] `CLB-03.eventsRetry`.
class ClubEventsTab extends StatelessWidget {
  /// Etkinlikler sekmesi.
  const ClubEventsTab({
    required this.events,
    required this.segment,
    required this.onSegmentChanged,
    required this.seesInside,
    required this.segmentKeyOf,
    required this.club,
    required this.rsvps,
    required this.nowUtc,
    required this.isFetching,
    required this.isError,
    required this.onRetry,
    required this.onEvent,
    required this.onQuickAction,
    required this.cardKeyOf,
    required this.joinKeyOf,
    required this.retryKey,
    super.key,
  });

  /// Yükleniyor iskeletindeki kart sayısı (`ListState n=3`,
  /// `screens-clubs.js:104`).
  static const int skeletonCount = 3;

  /// Kulübün etkinlikleri (dilimlenmemiş).
  final List<EventModel> events;

  /// Seçili dilim.
  final ClubEventSegment segment;

  /// Dilim değişti.
  final ValueChanged<ClubEventSegment> onSegmentChanged;

  /// Kullanıcı kulübün içini görüyor mu (görmüyorsa bilgi bandı çizilir)?
  final bool seesInside;

  /// Dilim düğmesinin anahtarı (`CLB-03.eventSeg.<dilim>`).
  final Key Function(ClubEventSegment segment) segmentKeyOf;

  /// Düzenleyen kulüp (kart kapağı ikonu; kartta kulüp satırı yok).
  final ClubModel? club;

  /// Kullanıcının katılım kayıtları, etkinlik kimliğine göre.
  final Map<String, RsvpModel> rsvps;

  /// "Şimdi" (`AppClock.nowUtc()`) — dilim ve kart durumu.
  final DateTime nowUtc;

  /// Etkinlikler okunuyor mu?
  final bool isFetching;

  /// Etkinlikler okunamadı mı?
  final bool isError;

  /// Hata görünümündeki "Yeniden dene".
  final Future<void> Function() onRetry;

  /// Karta dokunma (EVT-02).
  final ValueChanged<EventModel> onEvent;

  /// Kart hızlı eylemi (tür kartın durumundan).
  final void Function(EventModel event, EventCtaKind kind) onQuickAction;

  /// Kartın anahtarı.
  final Key Function(String eventId) cardKeyOf;

  /// Hızlı eylem düğmesinin anahtarı.
  final Key Function(String eventId) joinKeyOf;

  /// "Yeniden dene" düğmesinin anahtarı.
  final Key retryKey;

  /// [segment] dilimindeki etkinlikler (`screens-clubs.js:81`): yaklaşan =
  /// `endsAt >= şimdi` ve iptal değil, başlangıca göre artan; geçmiş = bitmiş
  /// ya da iptal, başlangıca göre azalan. Taslak hiç gösterilmez.
  static List<EventModel> visible(
    List<EventModel> events,
    ClubEventSegment segment,
    DateTime nowUtc,
  ) {
    bool isPast(EventModel e) =>
        e.endsAt.isBefore(nowUtc) || e.status == EventStatus.cancelled;
    final list = [
      for (final event in events)
        if (event.status != EventStatus.draft &&
            isPast(event) == (segment == ClubEventSegment.past))
          event,
    ];
    return list..sort(
      (a, b) => segment == ClubEventSegment.upcoming
          ? a.startsAt.compareTo(b.startsAt)
          : b.startsAt.compareTo(a.startsAt),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final shown = visible(events, segment, nowUtc);
    return Padding(
      padding: GuInsets.only(
        left: GuSpacing.s16,
        top: GuSpacing.s16,
        right: GuSpacing.s16,
        bottom: GuSpacing.s24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: GuSpacing.s12,
        children: [
          GuSegmented(
            options: [
              GuSegmentOption(
                id: ClubEventSegment.upcoming.name,
                label: l10n.eventUpcoming,
              ),
              GuSegmentOption(
                id: ClubEventSegment.past.name,
                label: l10n.eventPast,
              ),
            ],
            value: segment.name,
            onChanged: (id) =>
                onSegmentChanged(ClubEventSegment.values.byName(id)),
            optionKeyBuilder: (index) =>
                segmentKeyOf(ClubEventSegment.values[index]),
          ),
          if (!seesInside)
            GuBanner(
              icon: GuIcons.lock,
              text: l10n.clubEventsVisitorNote,
            ),
          GuListState(
            status: GuListStatus.resolve(
              isError: isError && events.isEmpty,
              isLoading: isFetching && events.isEmpty,
              isEmpty: shown.isEmpty,
            ),
            skeletonCount: skeletonCount,
            skeletonVariant: GuSkeletonVariant.card,
            skeletonSemanticLabel: l10n.commonLoading,
            errorBuilder: (_) => GuErrorState(
              title: l10n.sysErrorTitle,
              description: l10n.sysErrorDesc,
              retryLabel: l10n.commonRetry,
              onRetry: onRetry,
              retryActionKey: retryKey,
              inline: true,
            ),
            emptyBuilder: (_) => GuEmptyState(
              illustration: GuIllustrations.emptyEvents,
              title: l10n.eventEmptyTitle,
              compact: true,
            ),
            dataBuilder: (_) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: GuSpacing.s12,
              children: [
                for (final event in shown) _card(event),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(EventModel event) {
    final status = EventCardStatus.of(
      event: event,
      rsvp: rsvps[event.id],
      canSeeInside: seesInside,
      nowUtc: nowUtc,
    );
    final kind = EventCtaKind.of(status: status, event: event);
    return EventCard(
      event: event,
      club: club,
      status: status,
      registeredCount: event.goingCount,
      compact: true,
      showClub: false,
      quickAction: kind == null
          ? null
          : EventQuickAction(
              kind: kind,
              onPressed: () => onQuickAction(event, kind),
              actionKey: joinKeyOf(event.id),
            ),
      actionKey: cardKeyOf(event.id),
      onOpen: () => onEvent(event),
    );
  }
}

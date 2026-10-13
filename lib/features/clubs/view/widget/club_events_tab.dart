import 'package:flutter/widgets.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_ui/gu_ui.dart';

/// CLB-03 "Etkinlikler" sekmesinin dilimi (`CLB-03.eventSeg.*`).
enum ClubEventSegment {
  /// Yaklaşan etkinlikler (varsayılan).
  upcoming,

  /// Geçmiş ve iptal edilmiş etkinlikler.
  past,
}

/// CLB-03 "Etkinlikler" sekmesi — prototip `screens-clubs.js:102–104`. Yatay
/// 16, üst 16, alt 24 dolgulu sütun, aralık 12: "Yaklaşan / Geçmiş" dilimi ·
/// (kulübün içini görmeyene) "Üyelere özel etkinlikleri görmek için kulübe
/// katıl." bilgi bandı · etkinlik listesi.
///
/// Liste gövdesi bu sürümde yalnızca boş durumdur ("Etkinlik yok"):
/// etkinlik verisi ve `EventCard` satırları T-23'te gelir (W-15).
class ClubEventsTab extends StatelessWidget {
  /// Etkinlikler sekmesi.
  const ClubEventsTab({
    required this.events,
    required this.segment,
    required this.onSegmentChanged,
    required this.seesInside,
    required this.segmentKeyOf,
    super.key,
  });

  /// Kulübün etkinlikleri (T-23'e kadar boş).
  final List<EventModel> events;

  /// Seçili dilim.
  final ClubEventSegment segment;

  /// Dilim değişti.
  final ValueChanged<ClubEventSegment> onSegmentChanged;

  /// Kullanıcı kulübün içini görüyor mu (görmüyorsa bilgi bandı çizilir)?
  final bool seesInside;

  /// Dilim düğmesinin anahtarı (`CLB-03.eventSeg.<dilim>`).
  final Key Function(ClubEventSegment segment) segmentKeyOf;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
          // TODO(T-23): etkinlik listesi — `EventCard(compact)` satırları,
          // yükleniyor / hata durumları ve EVT-02'ye geçiş (W-15).
          GuEmptyState(
            illustration: GuIllustrations.emptyEvents,
            title: l10n.eventEmptyTitle,
            compact: true,
          ),
        ],
      ),
    );
  }
}

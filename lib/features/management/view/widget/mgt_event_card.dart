import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/format/app_date_formats.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/widget/event/event_place_label.dart';
import 'package:gu_ui/gu_ui.dart';

/// MGT-01 "Yaklaşan etkinlikler" kartı — prototip `screens-manage.js:28`
/// (`Card tappable` + `.row.gap12` `padding:12px 16px`): tarih rozeti ·
/// başlık (`titleS`, tek satır) / saat · mekân (`caption`) / ince kontenjan
/// çubuğu + `N/K` (kontenjansız → `N`) · `chevron-right` 20 soluk.
///
/// `EventCard`'dan ayrıdır: kulüp satırı, durum rozeti, kapak ve hızlı eylem
/// yoktur; dolgu 12 / 16, metinler `caption`. Kayıtlı sayısı
/// `event.goingCount` sayacıdır. Anahtarı çağıran verir (`MGT-01.event.<id>`).
class MgtEventCard extends ConsumerWidget {
  /// [event] etkinliğinin kartı.
  const MgtEventCard({
    required this.event,
    required this.onTap,
    required this.actionKey,
    super.key,
  });

  /// Etkinlik.
  final EventModel event;

  /// Karta dokunma (MGT-06).
  final VoidCallback onTap;

  /// Kartın aksiyon anahtarı.
  final Key actionKey;

  /// Saat ile mekân arasındaki ayraç (`screens-manage.js:28` `' · '`).
  static const String _separator = ' · ';

  /// `.tnum`.
  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gu = context.gu;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final formats = AppDateFormats(locale, ref.watch(appClockProvider));
    final capacity = event.capacity;
    final registered = event.goingCount;
    final count = capacity == null ? '$registered' : '$registered/$capacity';
    return GuCard(
      key: actionKey,
      onTap: onTap,
      semanticLabel: event.title,
      padding: GuInsets.sym(h: GuSpacing.s16, v: GuSpacing.s12),
      child: Row(
        spacing: GuSpacing.s12,
        children: [
          GuDateBadge(
            day: AppDateFormats.toIstanbul(event.startsAt).day,
            monthShort: formats.monthShort(event.startsAt).upperFor(locale),
            semanticLabel: formats.date(event.startsAt),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: GuSpacing.s2,
              children: [
                Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: gu.text.titleS,
                ),
                Text(
                  '${formats.time(event.startsAt)}$_separator'
                  '${EventPlaceLabel.of(context, event)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: gu.text.caption.copyWith(fontFeatures: _tabular),
                ),
                Row(
                  spacing: GuSpacing.s8,
                  children: [
                    Expanded(
                      child: GuProgress(
                        value: registered.toDouble(),
                        max: (capacity ?? 1).toDouble(),
                        thin: true,
                        semanticLabel: l10n.eventCapacity,
                      ),
                    ),
                    Text(
                      count,
                      style: gu.text.caption.copyWith(fontFeatures: _tabular),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GuIcon(
            GuIcons.chevronRight,
            size: GuSizes.icon20,
            color: gu.colors.textMuted,
          ),
        ],
      ),
    );
  }
}

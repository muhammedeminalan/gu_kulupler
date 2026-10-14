import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/format/app_date_formats.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/widget/event/event_card.dart';
import 'package:gu_kulupler/product/widget/event/event_card_status.dart';
import 'package:gu_ui/gu_ui.dart';

/// EVT-04 satırı — prototip `Tile` (`screens-events.js:94`): tarih rozeti ·
/// başlık / "kulüp · saat" / durum rozeti · sağda bilet ve vazgeç düğmeleri.
///
/// * [status] `EventCardStatus.of` ile türetilir (`null` → rozet yok).
/// * [onTicket] verilirse "Biletini göster" (`ticket`, marka rengi); [onLeave]
///   verilirse "Vazgeç" / "Ayrıl" (`x`; etiketi [leaveLabel]). İkisi
///   arasında 4 dp (css:212 `.trailing gap:4px`).
/// * Anahtarları çağıran verir (D-18): [actionKey], [ticketKey], [leaveKey].
class MyEventTile extends ConsumerWidget {
  /// [event] etkinliğinin satırı.
  const MyEventTile({
    required this.event,
    required this.status,
    required this.onOpen,
    this.clubName,
    this.onTicket,
    this.onLeave,
    this.leaveLabel,
    this.actionKey,
    this.ticketKey,
    this.leaveKey,
    super.key,
  }) : assert(
         onLeave == null || leaveLabel != null,
         'onLeave verildiyse leaveLabel de verilmeli',
       );

  /// Etkinlik.
  final EventModel event;

  /// Durum rozeti; `null` → rozet yok.
  final EventCardStatus? status;

  /// Kulüp adı; `null` → alt satırda yalnızca saat.
  final String? clubName;

  /// Satıra dokunma (EVT-02).
  final VoidCallback onOpen;

  /// "Biletini göster" (EVT-03); `null` → düğme yok.
  final VoidCallback? onTicket;

  /// "Vazgeç" / "Ayrıl" (DLG-14); `null` → düğme yok.
  final VoidCallback? onLeave;

  /// Vazgeç düğmesinin erişilebilirlik etiketi.
  final String? leaveLabel;

  /// Satırın anahtarı (`EVT-04.event.<eventId>`).
  final Key? actionKey;

  /// Bilet düğmesinin anahtarı (`EVT-04.ticket.<eventId>`).
  final Key? ticketKey;

  /// Vazgeç düğmesinin anahtarı (`EVT-04.leave.<eventId>`).
  final Key? leaveKey;

  /// Alt satır ayracı (`screens-events.js:94` `' · '`).
  static const String _separator = ' · ';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final formats = AppDateFormats(locale, ref.watch(appClockProvider));
    final time = formats.time(event.startsAt);
    final club = clubName;
    final current = status;
    final ticket = onTicket;
    final leave = onLeave;
    return GuTile(
      key: actionKey,
      leading: GuDateBadge(
        day: AppDateFormats.toIstanbul(event.startsAt).day,
        monthShort: formats.monthShort(event.startsAt).upperFor(locale),
      ),
      title: event.title,
      subtitle: club == null ? time : '$club$_separator$time',
      sub2Widget: current == null
          ? null
          : GuStatusBadge(
              kind: EventCard.badgeKindOf(current),
              label: EventCard.badgeLabelOf(l10n, current),
            ),
      trailing: ticket == null && leave == null
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              spacing: GuSpacing.s4,
              children: [
                if (ticket != null)
                  GuIconButton(
                    key: ticketKey,
                    icon: GuIcons.ticket,
                    semanticLabel: l10n.eventCtaTicket,
                    tone: GuIconButtonTone.brand,
                    onPressed: ticket,
                  ),
                if (leave != null)
                  GuIconButton(
                    key: leaveKey,
                    icon: GuIcons.x,
                    semanticLabel: leaveLabel ?? l10n.eventCtaLeave,
                    onPressed: leave,
                  ),
              ],
            ),
      onTap: onOpen,
    );
  }
}

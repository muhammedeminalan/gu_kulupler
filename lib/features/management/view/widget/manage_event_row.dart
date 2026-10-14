import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/format/app_date_formats.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_ui/gu_ui.dart';

/// MGT-04 etkinlik satırı — prototip `Tile` (`screens-manage.js:82`):
/// tarih rozeti · başlık / "{gün ay hafta günü}, {saat} · {kayıtlı}/{kontenjan}"
/// (kontenjansız → "Sınırsız") / rozetler · "⋮" (`more-vertical`).
///
/// Rozetler `.row.gap6`: yalnızca üyelere açık etkinlikte önce "Sadece
/// üyeler" (`lock`), ardından durum rozeti (taslak / yayında / iptal —
/// `e.status`; geçmiş sekmesindeki yayındaki etkinlik de "Yayında"). Dar
/// ekranda alt satıra kayar (`Wrap`).
///
/// Kayıtlı sayısı `event.goingCount` sayacıdır. Anahtarlar çağırandan
/// (`MGT-04.event.<id>`, `MGT-04.menu.<id>`).
class ManageEventRow extends ConsumerWidget {
  /// [event] etkinliğinin yönetim satırı.
  const ManageEventRow({
    required this.event,
    required this.actionKey,
    required this.menuKey,
    required this.onTap,
    required this.onMenu,
    super.key,
  });

  /// Etkinlik.
  final EventModel event;

  /// Satırın aksiyon anahtarı (`MGT-04.event.<id>`).
  final Key actionKey;

  /// "⋮" düğmesinin aksiyon anahtarı (`MGT-04.menu.<id>`).
  final Key menuKey;

  /// Satıra dokunma (EVT-02).
  final VoidCallback onTap;

  /// "⋮" (SHT-23).
  final VoidCallback onMenu;

  /// Tarih ile kontenjan arasındaki ayraç (`' · '`).
  static const String _separator = ' · ';

  /// [status] durum rozetinin türü ve metni.
  static (GuStatusBadgeKind, String) statusBadge(
    AppLocalizations l10n,
    EventStatus status,
  ) => switch (status) {
    EventStatus.draft => (GuStatusBadgeKind.draft, l10n.statusDraft),
    EventStatus.published => (
      GuStatusBadgeKind.published,
      l10n.statusPublished,
    ),
    EventStatus.cancelled => (
      GuStatusBadgeKind.cancelled,
      l10n.statusCancelled,
    ),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final formats = AppDateFormats(locale, ref.watch(appClockProvider));
    final capacity = event.capacity;
    final count = capacity == null
        ? l10n.eventUnlimited
        : '${event.goingCount}/$capacity';
    final (kind, label) = statusBadge(l10n, event.status);
    return GuTile(
      key: actionKey,
      title: event.title,
      subtitle: '${formats.dateTime(l10n, event.startsAt)}$_separator$count',
      sub2Widget: Wrap(
        spacing: GuSpacing.s6,
        runSpacing: GuSpacing.s6,
        children: [
          if (event.visibility == EventVisibility.membersOnly)
            GuStatusBadge(
              kind: GuStatusBadgeKind.members,
              label: l10n.eventVisibilityMembers,
            ),
          GuStatusBadge(kind: kind, label: label),
        ],
      ),
      leading: GuDateBadge(
        day: AppDateFormats.toIstanbul(event.startsAt).day,
        monthShort: formats.monthShort(event.startsAt).upperFor(locale),
        semanticLabel: formats.date(event.startsAt),
      ),
      trailing: GuIconButton(
        key: menuKey,
        icon: GuIcons.moreVertical,
        semanticLabel: l10n.a11yMore,
        onPressed: onMenu,
      ),
      onTap: onTap,
    );
  }
}

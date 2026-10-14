import 'package:flutter/widgets.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/profile/provider/profile_state.dart';
import 'package:gu_ui/gu_ui.dart';

/// PRF-01 istatistik kartları — prototip `.grid3` içinde üç
/// `.card.kpi.pressable` (`screens-profile.js:12`): "Kulüp" · "Katıldığım
/// etkinlik" · "Bekleyen başvuru". Kartlar `GuKpi(compact)` (önce değer,
/// sonra etiket; dolgu 12), eşit genişlikte, aralık 12; aynı satırdaki
/// kartlar en uzun etiketin boyuna gerilir.
///
/// Sayılar çağıranda yerel ayara göre biçimlenir ([formatCount]); anahtarları
/// çağıran verir (`PRF-01.stat.clubs`, `.events`, `.pending`; D-18).
class ProfileStatsRow extends StatelessWidget {
  /// [stats] sayılarının kartları.
  const ProfileStatsRow({
    required this.stats,
    required this.formatCount,
    required this.onClubs,
    required this.onEvents,
    required this.onPending,
    required this.clubsKey,
    required this.eventsKey,
    required this.pendingKey,
    super.key,
  });

  /// Sayımlar.
  final ProfileStats stats;

  /// Sayı biçimi (`AppDateFormats.number`).
  final String Function(int value) formatCount;

  /// "Kulüp" kartı (PRF-03).
  final VoidCallback onClubs;

  /// "Katıldığım etkinlik" kartı (EVT-04).
  final VoidCallback onEvents;

  /// "Bekleyen başvuru" kartı (PRF-03 bekleyenler).
  final VoidCallback onPending;

  /// "Kulüp" kartının anahtarı.
  final Key clubsKey;

  /// "Katıldığım etkinlik" kartının anahtarı.
  final Key eventsKey;

  /// "Bekleyen başvuru" kartının anahtarı.
  final Key pendingKey;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget card(Key key, String label, int value, VoidCallback onTap) =>
        Expanded(
          child: GuKpi(
            key: key,
            label: label,
            value: formatCount(value),
            onTap: onTap,
            layout: GuKpiLayout.compact,
          ),
        );
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: GuSpacing.s12,
        children: [
          card(clubsKey, l10n.profileStatClubs, stats.clubCount, onClubs),
          card(eventsKey, l10n.profileStatEvents, stats.eventCount, onEvents),
          card(
            pendingKey,
            l10n.profileStatPending,
            stats.pendingCount,
            onPending,
          ),
        ],
      ),
    );
  }
}

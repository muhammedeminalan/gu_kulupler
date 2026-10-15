import 'package:flutter/widgets.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_ui/gu_ui.dart';

/// Admin ekranları arası bölmeli geçiş — prototip `AdminNav`
/// (`screens-admin.js:5–6`): `.px16.pb16` içinde dört seçenekli `Segmented`
/// (Genel ADM-01 · Kulüpler ADM-02 · Şikayetler ADM-04 · Kullanıcılar
/// ADM-05; PLAN §12 ortak `AdminSegmentBar`). Seçenek anahtarını çağıran
/// ekran literal önekle üretir ([keyOf], ör. `ADM-01.seg.<hedef>` — tasarım
/// kapsamı denetimi öneki kaynakta arar); seçim `onSelect(hedef ekran
/// kimliği)` ile çağırana döner (prototip `nav.replace`).
class AdminSegmentBar extends StatelessWidget {
  /// [current] ekranının bölmeli geçişi.
  const AdminSegmentBar({
    required this.current,
    required this.onSelect,
    required this.keyOf,
    super.key,
  });

  /// Genel bakış (ADM-01).
  static const String overview = 'ADM-01';

  /// Kulüpler (ADM-02).
  static const String clubs = 'ADM-02';

  /// Şikayetler (ADM-04).
  static const String reports = 'ADM-04';

  /// Kullanıcılar (ADM-05).
  static const String users = 'ADM-05';

  /// Seçenek sırası (`ADMIN_SCREENS`).
  static const List<String> screens = [overview, clubs, reports, users];

  /// Bu çubuğu çizen ekranın kimliği (seçili seçenek).
  final String current;

  /// Hedef ekran kimliğinden seçenek anahtarı (`<current>.seg.<hedef>`).
  final Key Function(String screenId) keyOf;

  /// Seçilen hedef ekran kimliği (seçili olana dokunmada da çağrılır).
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final labels = {
      overview: l10n.adminSegOverview,
      clubs: l10n.adminSegClubs,
      reports: l10n.adminSegReports,
      users: l10n.adminSegUsers,
    };
    return Padding(
      padding: GuInsets.only(
        left: GuSpacing.s16,
        right: GuSpacing.s16,
        bottom: GuSpacing.s16,
      ),
      child: GuSegmented(
        options: [
          for (final id in screens) GuSegmentOption(id: id, label: labels[id]!),
        ],
        value: current,
        onChanged: onSelect,
        optionKeyBuilder: (i) => keyOf(screens[i]),
      ),
    );
  }
}

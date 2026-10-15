import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/admin/provider/report_group.dart';
import 'package:gu_kulupler/features/admin/provider/report_target_preview.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/report_reason_sheet.dart';
import 'package:gu_kulupler/product/format/relative_time_formatter.dart';
import 'package:gu_ui/gu_ui.dart';

/// ADM-04 şikayet grubu satırı — prototip `Tile` (`screens-admin.js:66`):
/// hedef türü ikonu (açık `warning`, çözülen `success`) · tek satır hedef
/// önizlemesi ([title]) · alt satır: ilk neden rozeti (`danger`), birden
/// çok şikayette "{n} şikayet" rozeti (`pending`, bayrak), son şikayetin
/// göreli zamanı · chevron. Dokunuş [onTap] (SHT-26).
class ReportGroupRow extends ConsumerWidget {
  /// [group] satırı; [title] hedef önizleme metni (çağıran çözer: gönderi
  /// başlığı / metni, yorum metni, kullanıcı / kulüp adı, etkinlik başlığı,
  /// hedef yoksa "Bu içerik kaldırılmış").
  const ReportGroupRow({
    required this.group,
    required this.title,
    required this.actionKey,
    required this.onTap,
    super.key,
  });

  /// Satırın grubu.
  final ReportGroup group;

  /// Hedef önizleme metni (tek satır, taşma `…`).
  final String title;

  /// Satırın aksiyon anahtarı (`ADM-04.row.<group.key>`).
  final Key actionKey;

  /// Dokunuş → SHT-26.
  final VoidCallback onTap;

  /// Hedef türünün ikonu (prototip ikon eşlemesi).
  static GuIcons iconOf(ReportTargetType type) => switch (type) {
    ReportTargetType.post => GuIcons.fileText,
    ReportTargetType.comment => GuIcons.messageCircle,
    ReportTargetType.user => GuIcons.user,
    ReportTargetType.club => GuIcons.usersRound,
    ReportTargetType.event => GuIcons.calendar,
  };

  /// Hedef türünün adı (`reports.target.<tür>`; süzgeç çipi, SHT-26 rozeti).
  static String typeLabel(AppLocalizations l10n, ReportTargetType type) =>
      switch (type) {
        ReportTargetType.post => l10n.reportsTargetPost,
        ReportTargetType.comment => l10n.reportsTargetComment,
        ReportTargetType.user => l10n.reportsTargetUser,
        ReportTargetType.club => l10n.reportsTargetClub,
        ReportTargetType.event => l10n.reportsTargetEvent,
      };

  /// Satır başlığı (prototip `preview(r)`, `screens-admin.js:64`): gönderi
  /// başlığı ya da metni · yorum metni · kullanıcı adı · kulüp adı ·
  /// etkinlik başlığı; hedef silinmişse "İçerik kaldırıldı"
  /// (`saved.removed`). Önizleme okunamadıysa ([preview] `null`) hedef
  /// türünün adı.
  static String titleOf(
    AppLocalizations l10n,
    ReportGroup group,
    ReportTargetPreview? preview,
  ) {
    if (preview == null) return typeLabel(l10n, group.targetType);
    if (preview.isMissing) return l10n.savedRemoved;
    final post = preview.post;
    if (post != null) {
      final title = post.title?.trim() ?? '';
      return title.isNotEmpty ? title : post.text;
    }
    final user = preview.user;
    if (user != null) {
      return user.isDeleted ? l10n.commonDeletedUser : user.name;
    }
    return preview.comment?.text ??
        preview.club?.name ??
        preview.event?.title ??
        l10n.savedRemoved;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = context.gu.text;
    final lastAt = group.lastAt;
    final time = lastAt == null
        ? null
        : RelativeTimeFormatter(l10n, ref.watch(appClockProvider)).format(
            lastAt,
          );
    return GuTile(
      key: actionKey,
      title: title,
      titleWidget: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      leading: GuIconBox(
        icon: iconOf(group.targetType),
        tone: group.isOpen ? GuIconBoxTone.warning : GuIconBoxTone.success,
        iconSize: GuSizes.icon18,
      ),
      // `.row.gap6.wrap` (`screens-admin.js:66`).
      sub2Widget: Wrap(
        spacing: GuSpacing.s6,
        runSpacing: GuSpacing.s4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          GuBadge(
            kind: GuBadgeKind.danger,
            label: ReportReasonSheet.reasonLabel(l10n, group.primaryReason),
          ),
          if (group.count > 1)
            GuBadge(
              kind: GuBadgeKind.pending,
              icon: GuIcons.flag,
              label: l10n.contentReports(group.count),
            ),
          if (time != null) Text(time, style: text.caption),
        ],
      ),
      chevron: true,
      onTap: onTap,
    );
  }
}

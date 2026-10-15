import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/format/app_date_formats.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/admin/provider/report_group.dart';
import 'package:gu_kulupler/features/admin/provider/report_target_preview.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/report_reason_sheet.dart';
import 'package:gu_kulupler/product/format/relative_time_formatter.dart';
import 'package:gu_kulupler/product/media/post_image_resolver.dart';
import 'package:gu_kulupler/product/media/user_avatar_image.dart';
import 'package:gu_kulupler/product/widget/club/club_card.dart';
import 'package:gu_kulupler/product/widget/club/cover_mapper.dart';
import 'package:gu_kulupler/product/widget/member/member_row.dart';
import 'package:gu_kulupler/product/widget/member/user_row.dart';
import 'package:gu_kulupler/product/widget/post/post_card.dart';
import 'package:gu_ui/gu_ui.dart';

/// SHT-26 alt bilgi eylemleri (prototip `sheets.js:126`; yalnızca açık
/// grupta). Kalıcı `reports.action` değeri `ReportAction`'dır (gu_data);
/// bu enum sheet'in çağırana döndürdüğü seçimdir.
enum ReportDetailAction {
  /// "Şikayeti kapat" (`SHT-26.closeReport`) → ihlal yok:
  /// `resolveReports(dismissed)` → TST-56.
  dismiss,

  /// "Kullanıcıyı askıya al" (`SHT-26.suspendUser`; gönderi / yorum yazarı
  /// ya da kullanıcı hedefi) → DLG-30 → `suspendUser` +
  /// `resolveReports(suspended)` → TST-52.
  suspendUser,

  /// "İçeriği kaldır" (`SHT-26.removeContent`; gönderi / yorum) → DLG-29 →
  /// `resolveReports(removed)` → TST-51.
  removeContent,

  /// "Askıya al" (`SHT-26.suspendClub`; kulüp hedefi) → DLG-28 →
  /// `suspendClub` + `resolveReports(suspended)` → TST-50.
  suspendClub,
}

/// SHT-26 "Şikayet detayı" — tam yükseklik sheet (prototip `sheets.js:
/// 120–128`; referans `design/reference-shots/sheets/SHT-26__*.webp`).
///
/// Gövde (`col gap16 pb16`):
///
/// * **Rozetler** (`row gap6 wrap`): hedef türü (`neutral`), durum
///   (`GuStatusBadge` açık / çözüldü) ve çözülmüşse işlem (`info`).
/// * **Hedef önizlemesi** ([preview]; `null` → tek satırlık iskelet):
///   gönderi `PostCard` (eylemsiz, `showClub`; görseller ve yazar), yorum
///   soluk kartta yazar avatarı 32 + ad + metin, kullanıcı soluk kartta
///   `UserRow` ("bölüm · sınıf"), kulüp / etkinlik soluk kartta küçük amblem
///   + ad / başlık. Hedef belgesi yoksa "İçerik kaldırıldı" (`saved.removed`,
///   `bodyS` soluk).
/// * **"{n} şikayet"** (`titleS`) + şikayet satırları, en eski üstte
///   (prototip `r.reasons` sırası): şikayetçi avatarı 32 · ad (`labelL`
///   `text.heading`) + neden rozeti (`danger`) + göreli zaman (`caption`),
///   altında varsa not (`bodyS` ikincil). Şikayetçi kimliği yalnız süper
///   admine görünür (sheet ADM-04'ün içindedir; [reporters]).
/// * **Çözüm bandı** (çözülmüş grupta; `success`, kart): "{tarih}
///   tarihinde çözüldü: {işlem}".
///
/// Alt bilgi yalnızca açık grupta, prototip sırasıyla: "Şikayeti kapat"
/// (`outline`), askıya alınabilir kullanıcı varsa ([ReportTargetPreview.
/// suspendableUserId]) "Kullanıcıyı askıya al" (`dangerOutline`), gönderi /
/// yorumda "İçeriği kaldır" (`danger`), kulüpte "Askıya al" (`danger`).
/// Prototipte üç düğme satırdan taşar (`.btn{white-space:nowrap}` +
/// `.sheet-foot .btn{flex:1}` — üçüncü düğme ekran dışında kalır); burada
/// doğal genişlikleri satıra sığıyorsa yan yana (CSS `flex:1` dağıtımı),
/// yoksa alt alta tam genişlik dizilir (taşma ve metin kesilmesi yok).
///
/// Sahibi `AdminReportsViewModel`'dir (PLAN §4.5.2: kendi async durumu olan
/// sheet); seçim [onAction] ile çağırana döner, yazım ViewModel'dedir.
/// [pendingAction] o düğmeyi `loading` çizer; sürerken başka seçim
/// gönderilmez.
///
/// Design: SHT-26
class ReportDetailSheet extends ConsumerWidget {
  /// [group] grubunun detayı; [preview] hedef önizlemesi (`null` →
  /// yükleniyor).
  const ReportDetailSheet({
    required this.group,
    required this.preview,
    required this.onAction,
    this.reporters = const {},
    this.pendingAction,
    super.key,
  });

  /// Gösterilen şikayet grubu.
  final ReportGroup group;

  /// Hedef önizlemesi; `null` → okunuyor (iskelet).
  final ReportTargetPreview? preview;

  /// Şikayetçi profilleri (uid → kullanıcı; eksik olan "Silinmiş
  /// kullanıcı").
  final Map<String, UserModel> reporters;

  /// Sürmekte olan eylem (düğmesi `loading`); `null` → yok.
  final ReportDetailAction? pendingAction;

  /// Alt bilgi eylemi seçildi.
  final ValueChanged<ReportDetailAction> onAction;

  /// Kapatma düğmesinin anahtarı (`SHT-26.close`).
  static final Key closeKey = GuKey.action('SHT-26.close');

  /// "Şikayeti kapat" düğmesinin anahtarı (`SHT-26.closeReport`).
  static final Key closeReportKey = GuKey.action('SHT-26.closeReport');

  /// "Kullanıcıyı askıya al" düğmesinin anahtarı (`SHT-26.suspendUser`).
  static final Key suspendUserKey = GuKey.action('SHT-26.suspendUser');

  /// "İçeriği kaldır" düğmesinin anahtarı (`SHT-26.removeContent`).
  static final Key removeContentKey = GuKey.action('SHT-26.removeContent');

  /// "Askıya al" (kulüp) düğmesinin anahtarı (`SHT-26.suspendClub`).
  static final Key suspendClubKey = GuKey.action('SHT-26.suspendClub');

  /// [action] düğmesinin anahtarı.
  static Key actionKey(ReportDetailAction action) => switch (action) {
    ReportDetailAction.dismiss => closeReportKey,
    ReportDetailAction.suspendUser => suspendUserKey,
    ReportDetailAction.removeContent => removeContentKey,
    ReportDetailAction.suspendClub => suspendClubKey,
  };

  /// Hedef türünün görünen adı (`reports.target.<tür>`).
  static String targetLabel(AppLocalizations l10n, ReportTargetType type) =>
      switch (type) {
        ReportTargetType.post => l10n.reportsTargetPost,
        ReportTargetType.comment => l10n.reportsTargetComment,
        ReportTargetType.user => l10n.reportsTargetUser,
        ReportTargetType.club => l10n.reportsTargetClub,
        ReportTargetType.event => l10n.reportsTargetEvent,
      };

  /// Çözüm işleminin görünen adı (`reportAction.<işlem>`).
  static String actionLabel(AppLocalizations l10n, ReportAction action) =>
      switch (action) {
        ReportAction.removed => l10n.reportActionRemoved,
        ReportAction.dismissed => l10n.reportActionDismissed,
        ReportAction.suspended => l10n.reportActionSuspended,
      };

  /// Açık grubun alt bilgi eylemleri, prototip sırasıyla (`sheets.js:126`);
  /// çözülmüş grupta boş.
  static List<ReportDetailAction> actionsFor(
    ReportGroup group,
    ReportTargetPreview? preview,
  ) {
    if (!group.isOpen) return const [];
    return [
      ReportDetailAction.dismiss,
      if (preview?.suspendableUserId != null) ReportDetailAction.suspendUser,
      if (group.targetType == ReportTargetType.post ||
          group.targetType == ReportTargetType.comment)
        ReportDetailAction.removeContent
      else if (group.targetType == ReportTargetType.club)
        ReportDetailAction.suspendClub,
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final actions = actionsFor(group, preview);
    return GuSheetFrame(
      title: l10n.sht26Title,
      closeSemanticLabel: l10n.a11yClose,
      closeKey: closeKey,
      full: true,
      footer: actions.isEmpty
          ? null
          : [
              Expanded(
                child: _ReportFooter(
                  buttons: [
                    for (final action in actions) _button(l10n, action),
                  ],
                ),
              ),
            ],
      body: Padding(
        padding: GuInsets.only(bottom: GuSpacing.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: GuSpacing.s16,
          children: [
            _badges(l10n),
            _preview(context, ref),
            _reports(context, ref),
            ?_resolvedBanner(context, ref),
          ],
        ),
      ),
    );
  }

  GuButton _button(AppLocalizations l10n, ReportDetailAction action) {
    final (label, variant) = switch (action) {
      ReportDetailAction.dismiss => (l10n.sht26Close, GuButtonVariant.outline),
      ReportDetailAction.suspendUser => (
        l10n.sht26SuspendUser,
        GuButtonVariant.dangerOutline,
      ),
      ReportDetailAction.removeContent => (
        l10n.sht26Remove,
        GuButtonVariant.danger,
      ),
      ReportDetailAction.suspendClub => (
        l10n.adminClubsSuspend,
        GuButtonVariant.danger,
      ),
    };
    return GuButton(
      key: actionKey(action),
      label: label,
      variant: variant,
      loading: pendingAction == action,
      onPressed: () {
        if (pendingAction == null) onAction(action);
      },
    );
  }

  /// `row gap6 wrap`: tür · durum · (işlem).
  Widget _badges(AppLocalizations l10n) {
    final action = group.action;
    return Wrap(
      spacing: GuSpacing.s6,
      runSpacing: GuSpacing.s6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        GuBadge(label: targetLabel(l10n, group.targetType)),
        if (group.isOpen)
          GuStatusBadge(kind: GuStatusBadgeKind.open, label: l10n.statusOpen)
        else
          GuStatusBadge(
            kind: GuStatusBadgeKind.resolved,
            label: l10n.statusResolved,
          ),
        if (!group.isOpen && action != null)
          GuBadge(label: actionLabel(l10n, action), kind: GuBadgeKind.info),
      ],
    );
  }

  /// Prototip `preview()` (`sheets.js:124`).
  Widget _preview(BuildContext context, WidgetRef ref) {
    final gu = context.gu;
    final l10n = context.l10n;
    final preview = this.preview;
    if (preview == null) {
      return GuCard(
        muted: true,
        child: GuSkeletonList(semanticLabel: l10n.commonLoading, count: 1),
      );
    }
    final removed = Text(
      l10n.savedRemoved,
      style: gu.text.bodyS.copyWith(color: gu.colors.textMuted),
    );
    switch (group.targetType) {
      case ReportTargetType.post:
        final post = preview.post;
        if (post == null) return removed;
        final author = preview.author;
        return PostCard(
          post: post,
          author: author,
          authorAvatar: ref.userAvatarImage(
            author,
            displaySize: GuSizes.postAvatar,
          ),
          club: preview.club,
          showClub: true,
          hideActions: true,
          imageOf: ref.postImagesOf(post.images),
        );
      case ReportTargetType.comment:
        final comment = preview.comment;
        if (comment == null) return removed;
        return _CommentPreview(
          comment: comment,
          author: preview.author,
          avatar: ref.userAvatarImage(
            preview.author,
            displaySize: GuSizes.commentAvatar,
          ),
        );
      case ReportTargetType.user:
        final user = preview.user;
        if (user == null) return removed;
        return GuCard(
          muted: true,
          child: UserRow(
            user: user,
            sub: MemberRow.departmentAndYear(
              context,
              department: user.department,
              year: user.year,
            ),
            inCard: true,
            avatarImage: ref.userAvatarImage(
              user,
              displaySize: GuSizes.avatar,
            ),
          ),
        );
      case ReportTargetType.club:
        final club = preview.club;
        if (club == null) return removed;
        return _EmblemPreview(
          icon: CoverMapper.icon(club.iconName) ?? ClubCard.fallbackIcon,
          title: club.name,
        );
      case ReportTargetType.event:
        final event = preview.event;
        if (event == null) return removed;
        return _EmblemPreview(icon: GuIcons.calendar, title: event.title);
    }
  }

  /// `col gap8`: "{n} şikayet" + şikayet satırları (en eski üstte).
  Widget _reports(BuildContext context, WidgetRef ref) {
    final gu = context.gu;
    final l10n = context.l10n;
    final relative = RelativeTimeFormatter(l10n, ref.watch(appClockProvider));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: GuSpacing.s8,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.contentReports(group.count), style: gu.text.titleS),
        ),
        for (final report in group.reports.reversed)
          _ReporterRow(
            report: report,
            reporter: reporters[report.reporterId],
            avatar: ref.userAvatarImage(
              reporters[report.reporterId],
              displaySize: GuSizes.commentAvatar,
            ),
            time: switch (report.createdAt) {
              final at? => relative.format(at),
              null => l10n.timeJustNow,
            },
          ),
      ],
    );
  }

  /// Çözülmüş grupta "{tarih} tarihinde çözüldü: {işlem}".
  Widget? _resolvedBanner(BuildContext context, WidgetRef ref) {
    final action = group.action;
    final resolvedAt = group.resolvedAt;
    if (group.isOpen || action == null || resolvedAt == null) return null;
    final l10n = context.l10n;
    final formats = AppDateFormats(
      Locale(l10n.localeName),
      ref.watch(appClockProvider),
    );
    return GuBanner(
      kind: GuBannerKind.success,
      text: l10n.sht26ResolvedAt(
        formats.dateTime(l10n, resolvedAt),
        actionLabel(l10n, action),
      ),
      card: true,
    );
  }
}

/// Yorum önizlemesi — `Card muted card-body row gap10 start`: avatar 32 ·
/// ad (`labelL` `text.heading`) + metin (`bodyM`), `col gap2`.
class _CommentPreview extends StatelessWidget {
  const _CommentPreview({
    required this.comment,
    required this.author,
    required this.avatar,
  });

  final CommentModel comment;
  final UserModel? author;
  final ImageProvider? avatar;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final author = this.author;
    final name = author?.name ?? context.l10n.commonDeletedUser;
    return GuCard(
      muted: true,
      padding: GuCard.bodyPadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        // K-42: `gap10` tanımsız → `.row` 8.
        spacing: GuSpacing.s8,
        children: [
          _avatar(author, name, avatar),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: GuSpacing.s2,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: gu.text.labelL.copyWith(color: gu.colors.textHeading),
                ),
                Text(comment.text, style: gu.text.bodyM),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Kulüp / etkinlik önizlemesi — `Card muted card-body row gap12`: küçük
/// amblem (44, ikon 20) + ad / başlık (`titleS`).
class _EmblemPreview extends StatelessWidget {
  const _EmblemPreview({required this.icon, required this.title});

  final GuIcons icon;
  final String title;

  @override
  Widget build(BuildContext context) => GuCard(
    muted: true,
    padding: GuCard.bodyPadding,
    child: Row(
      spacing: GuSpacing.s12,
      children: [
        GuEmblem(icon: icon),
        Expanded(child: Text(title, style: context.gu.text.titleS)),
      ],
    ),
  );
}

/// Şikayet satırı — `row gap10 start`: avatar 32 · `col gap2 flex1`
/// [`row gap6 wrap`: ad + neden rozeti + göreli zaman] + not.
class _ReporterRow extends StatelessWidget {
  const _ReporterRow({
    required this.report,
    required this.reporter,
    required this.avatar,
    required this.time,
  });

  final ReportModel report;
  final UserModel? reporter;
  final ImageProvider? avatar;
  final String time;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final reporter = this.reporter;
    final name = reporter?.name ?? l10n.commonDeletedUser;
    final note = report.note.trim();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      // K-42: `gap10` tanımsız → `.row` 8.
      spacing: GuSpacing.s8,
      children: [
        _avatar(reporter, name, avatar),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: GuSpacing.s2,
            children: [
              Wrap(
                spacing: GuSpacing.s6,
                runSpacing: GuSpacing.s2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    name,
                    style: gu.text.labelL.copyWith(
                      color: gu.colors.textHeading,
                    ),
                  ),
                  GuBadge(
                    label: ReportReasonSheet.reasonLabel(l10n, report.reason),
                    kind: GuBadgeKind.danger,
                  ),
                  Text(time, style: gu.text.caption),
                ],
              ),
              if (note.isNotEmpty)
                Text(
                  note,
                  style: gu.text.bodyS.copyWith(color: gu.colors.textSecondary),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Avatar 32 (`sheets.js:124–125` `Avatar size=${32}`); kullanıcı yoksa `?`.
Widget _avatar(UserModel? user, String name, ImageProvider? image) {
  final String seed;
  if (user == null) {
    seed = name;
  } else {
    seed = user.avatarSeed.isEmpty ? user.uid : user.avatarSeed;
  }
  return GuAvatar(
    initials: name.initials,
    seed: seed,
    size: GuSizes.commentAvatar,
    image: user == null ? null : image,
  );
}

/// Alt bilgi düğmeleri — `.sheet-foot` (aralık 12) + `.sheet-foot
/// .btn{flex:1}` CSS dağıtımı: düğmeler eşit pay alır, payı doğal
/// genişliğinden dar kalan düğme doğal genişliğinde kalır, kalan alan
/// diğerlerine bölünür. Doğal genişliklerin toplamı satıra sığmıyorsa
/// (prototipte yatay taşma) düğmeler alt alta tam genişlik dizilir.
class _ReportFooter extends StatelessWidget {
  const _ReportFooter({required this.buttons});

  final List<GuButton> buttons;

  /// `Expanded.flex` çözünürlüğü (dp başına).
  static const int _flexPerDp = 100;

  /// `GuButtonSize.md` düğmesinin [label] için doğal genişliği.
  static double _naturalWidth(BuildContext context, String label) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: context.gu.text.button),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width + (GuButtonSize.md.paddingX + GuSizes.buttonBorder) * 2;
  }

  /// CSS `flex:1` (taban 0, en az doğal genişlik) dağıtımı; toplam
  /// [available]'ı aşıyorsa `null` (alt alta).
  static List<double>? _distribute(List<double> natural, double available) {
    final total = natural.fold<double>(0, (sum, w) => sum + w);
    if (total > available) return null;
    final widths = List<double?>.filled(natural.length, null);
    var remaining = available;
    var open = natural.length;
    var frozen = true;
    while (frozen && open > 0) {
      frozen = false;
      final share = remaining / open;
      for (var i = 0; i < natural.length; i++) {
        if (widths[i] == null && natural[i] > share) {
          widths[i] = natural[i];
          remaining -= natural[i];
          open--;
          frozen = true;
        }
      }
    }
    final share = open == 0 ? 0.0 : remaining / open;
    return [for (final w in widths) w ?? share];
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final gaps = GuSizes.sheetFootGap * (buttons.length - 1);
      final widths = _distribute([
        for (final button in buttons) _naturalWidth(context, button.label),
      ], constraints.maxWidth - gaps);
      if (widths == null) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: GuSizes.sheetFootGap,
          children: buttons,
        );
      }
      return Row(
        spacing: GuSizes.sheetFootGap,
        children: [
          for (var i = 0; i < buttons.length; i++)
            Expanded(
              flex: math.max(1, (widths[i] * _flexPerDp).round()),
              child: buttons[i],
            ),
        ],
      );
    },
  );
}

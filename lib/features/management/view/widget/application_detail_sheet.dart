import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/format/app_date_formats.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/l10n/reject_reason_labels.dart';
import 'package:gu_kulupler/product/widget/member/application_row.dart';
import 'package:gu_kulupler/product/widget/member/member_row.dart';
import 'package:gu_ui/gu_ui.dart';

/// SHT-19'da seçilen eylem — sayfanın `pop` değeri (X / scrim / sürükleme /
/// geri → `null`). Sayfa kendisi hiçbir şey yürütmez; eylemi çağıran
/// (`ManageApplicationsView`) başlatır.
enum ApplicationDetailAction {
  /// "Onayla" (`SHT-19.approve`) → `ManageApplicationsViewModel.approve`
  /// (TST-27; çakışma → DLG-18).
  approve,

  /// "Reddet" (`SHT-19.reject`) → SHT-20 ret nedeni.
  reject,

  /// "Geri al" (`SHT-19.undo`; karar verilmiş başvuru, geri al
  /// penceresinde) → `ManageApplicationsViewModel.undoDecision` (TST-X17).
  undo,

  /// "Profili gör" (`SHT-19.profile`) → CLB-07.
  profile,
}

/// SHT-19 "Başvuru detayı" — MGT-02 satırı ve `application_received`
/// bildirimi (W-28) açar (prototip `SHEETS['SHT-19']`, `sheets.js:89–97`).
///
/// * Gövde (`col gap16 pb16`): avatar (56) + ad (`titleS`) + bölüm · sınıf +
///   `Gönderildi: <tarih>`; karar verilmişse durum bandı (onaylandı /
///   reddedildi · neden, kart); başvuru notu kartı ([contact] `note`,
///   CD-137; boş → "Not yok"); "Daha önce bu kulübe başvurdu" Evet / Hayır +
///   ortak kulüpler ([commonClubNames], rozet); [contact] e-postası doluysa
///   e-posta satırı (D-29 — yalnızca yönetim okur; [onCopyEmail] verilirse
///   kopyala düğmesi → çağıran panoya yazar, TST-08); "Profili gör".
/// * Alt çubuk: beklemede → "Reddet" (outline) + "Onayla"; [readOnly]
///   (danışman) → ikisi devre dışı, dokunuş [onReadOnlyTap] (TST-26). Karar
///   verilmişse ve [canUndo] (geri al penceresi çağıranın hesabıdır —
///   domain-model §5 M12: 30 sn) → yalnızca "Geri al"; değilse alt çubuk
///   yok.
/// * [application] `null` (başvuru artık yok) ya da başvuranın hesabı
///   silinmiş (W-92, `ApplicationRow.isDeletedApplicant`) → yalnızca "Bu
///   başvuru artık yok." metni.
/// * Anahtarlar `SHT-19.approve`, `.reject`, `.undo`, `.profile`,
///   `.copyEmail`, `SHT-19.close` (+ `SHT-19.scrim`, `FeedbackService`).
///
/// ```dart
/// final action = await feedback.showSheet<ApplicationDetailAction>(
///   SheetId.sht19,
///   builder: (_) => ApplicationDetailSheet(
///     application: m,
///     contact: state.contacts[m.userId],
///   ),
/// );
/// ```
///
/// Design: SHT-19
class ApplicationDetailSheet extends ConsumerWidget {
  /// [application] başvurusunun detayı.
  const ApplicationDetailSheet({
    required this.application,
    this.contact,
    this.user,
    this.avatarImage,
    this.commonClubNames = const [],
    this.readOnly = false,
    this.canUndo = false,
    this.onReadOnlyTap,
    this.onCopyEmail,
    super.key,
  });

  /// Başvuru; `null` → başvuru artık yok ("gone" gövdesi).
  final MembershipModel? application;

  /// Başvuranın özel iletişim kaydı (e-posta + başvuru notu; yalnızca
  /// yöneticiye okunur — D-29, CD-137); `null` → "Not yok", e-posta satırı
  /// yok.
  final MembershipContactModel? contact;

  /// Güncel kullanıcı belgesi; `null` → `applicant` anlık görüntüsü.
  final UserModel? user;

  /// Profil fotoğrafı; `null` → baş harfler.
  final ImageProvider? avatarImage;

  /// Görüntüleyenle ortak kulüplerin kısa adları (bu kulüp hariç).
  final List<String> commonClubNames;

  /// Salt okunur (danışman, Q-09): onay / ret devre dışı, "Geri al" yok.
  final bool readOnly;

  /// Karar verilmiş başvuruda "Geri al" görünür mü (pencere içinde,
  /// yönetici).
  final bool canUndo;

  /// Salt okunurken düğme dokunuşu (TST-26).
  final VoidCallback? onReadOnlyTap;

  /// E-postanın kopyala düğmesi (`SHT-19.copyEmail`); sayfa açık kalır.
  /// `null` → düğme çizilmez.
  final VoidCallback? onCopyEmail;

  /// [action] düğmesinin anahtarı (`SHT-19.<action>`).
  static Key keyOf(String action) => GuKey.action('SHT-19.$action');

  /// Avatar çapı (`sheets.js:92` `size=${56}`) — `GuSizes.avatarSizes`
  /// içindeki 56.
  static final double avatarSize = GuSizes.avatarSizes[6];

  /// Durum bandı ayracı (`sheets.js:93` `' · '`).
  static const String _separator = ' · ';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final application = this.application;
    final gone =
        application == null ||
        ApplicationRow.isDeletedApplicant(application, user);
    final decided = !gone && application.status != MembershipStatus.pending;
    return GuSheetFrame(
      title: l10n.sht19Title,
      closeSemanticLabel: l10n.a11yClose,
      closeKey: keyOf('close'),
      footer: gone
          ? null
          : decided
          ? [
              if (canUndo && !readOnly)
                GuButton(
                  key: keyOf('undo'),
                  label: l10n.commonUndo,
                  variant: GuButtonVariant.outline,
                  onPressed: () => context.pop(ApplicationDetailAction.undo),
                ),
            ]
          : [
              GuButton(
                key: keyOf('reject'),
                label: l10n.applicationsReject,
                variant: GuButtonVariant.outline,
                disabled: readOnly,
                onDisabledPressed: onReadOnlyTap,
                onPressed: () => context.pop(ApplicationDetailAction.reject),
              ),
              GuButton(
                key: keyOf('approve'),
                label: l10n.applicationsApprove,
                disabled: readOnly,
                onDisabledPressed: onReadOnlyTap,
                onPressed: () => context.pop(ApplicationDetailAction.approve),
              ),
            ],
      body: gone
          ? Padding(
              // `t-body-s c-muted p16` (sheets.js:90).
              padding: GuInsets.all16,
              child: Text(
                l10n.sht19Gone,
                style: context.gu.text.bodyS.copyWith(
                  color: context.gu.colors.textMuted,
                ),
              ),
            )
          : _body(context, ref, l10n, application),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    MembershipModel application,
  ) {
    final gu = context.gu;
    final locale = Localizations.localeOf(context);
    final formats = AppDateFormats(locale, ref.watch(appClockProvider));
    final user = this.user;
    final applicant = application.applicant;
    final name = user?.name ?? applicant.name;
    final seed = user?.avatarSeed ?? applicant.avatarSeed;
    final sub = MemberRow.departmentAndYear(
      context,
      department: user == null ? applicant.department : user.department,
      year: user == null ? applicant.year : user.year,
    );
    final appliedAt = application.appliedAt;
    final note = contact?.note.trim() ?? '';
    final email = contact?.email.trim() ?? '';
    final banner = _decisionBanner(l10n, application);
    final muted = gu.text.bodyS.copyWith(color: gu.colors.textMuted);
    final heading = gu.text.bodyS.copyWith(color: gu.colors.textHeading);
    final onCopyEmail = this.onCopyEmail;
    return Padding(
      padding: GuInsets.only(bottom: GuSpacing.s16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: GuSpacing.s16,
        children: [
          Row(
            spacing: GuSpacing.s12,
            children: [
              GuAvatar(
                initials: name.initials,
                seed: seed.isEmpty ? application.userId : seed,
                size: avatarSize,
                image: avatarImage,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: GuSpacing.s2,
                  children: [
                    Text(name, style: gu.text.titleS),
                    if (sub.isNotEmpty)
                      Text(
                        sub,
                        style: gu.text.bodyS.copyWith(
                          color: gu.colors.textSecondary,
                        ),
                      ),
                    if (appliedAt != null)
                      Text(
                        l10n.appliedSentAt(formats.dateTime(l10n, appliedAt)),
                        style: gu.text.caption,
                      ),
                  ],
                ),
              ),
            ],
          ),
          ?banner,
          GuCard(
            muted: true,
            padding: GuCard.bodyPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: GuSpacing.s4,
              children: [
                Text(l10n.sht19Note.upperFor(locale), style: gu.text.overline),
                Text(note.isEmpty ? l10n.applicationsNoNote : note),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: GuSpacing.s6,
            children: [
              Row(
                spacing: GuSpacing.s8,
                children: [
                  Expanded(child: Text(l10n.sht19Prior, style: muted)),
                  Text(
                    application.priorCount > 0 ? l10n.commonYes : l10n.commonNo,
                    style: heading,
                  ),
                ],
              ),
              if (commonClubNames.isNotEmpty)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: GuSpacing.s8,
                  children: [
                    Expanded(
                      flex: _labelFlex,
                      child: Text(l10n.userprofileCommonClubs, style: muted),
                    ),
                    Expanded(
                      // `max-width:60%` rozet sütunu, sağa yaslı.
                      flex: _badgesFlex,
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: GuSpacing.s4,
                        runSpacing: GuSpacing.s4,
                        children: [
                          for (final club in commonClubNames)
                            GuBadge(label: club),
                        ],
                      ),
                    ),
                  ],
                ),
              if (email.isNotEmpty)
                Row(
                  spacing: GuSpacing.s8,
                  children: [
                    Text(l10n.authEmail, style: muted),
                    Expanded(
                      child: Text(
                        email,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: heading,
                      ),
                    ),
                    if (onCopyEmail != null)
                      GuIconButton(
                        key: keyOf('copyEmail'),
                        icon: GuIcons.copy,
                        size: GuIconButtonSize.xs,
                        iconSize: GuSizes.icon16,
                        semanticLabel: l10n.commonCopy,
                        onPressed: onCopyEmail,
                      ),
                  ],
                ),
            ],
          ),
          GuButton(
            key: keyOf('profile'),
            label: l10n.userprofileView,
            icon: GuIcons.user,
            variant: GuButtonVariant.text,
            full: true,
            onPressed: () => context.pop(ApplicationDetailAction.profile),
          ),
        ],
      ),
    );
  }

  /// Ortak kulüpler satırı: etiket %40, rozetler %60 (`sheets.js:94`).
  static const int _labelFlex = 2;
  static const int _badgesFlex = 3;

  /// Karar bandı (`sheets.js:93`): onaylandı → başarı; reddedildi → tehlike
  /// (+ ` · neden`). Diğer durumlarda yok.
  Widget? _decisionBanner(
    AppLocalizations l10n,
    MembershipModel application,
  ) {
    switch (application.status) {
      case MembershipStatus.active:
        return GuBanner(
          kind: GuBannerKind.success,
          text: l10n.statusApproved,
          card: true,
        );
      case MembershipStatus.rejected:
        final reason = application.rejectReason;
        return GuBanner(
          kind: GuBannerKind.danger,
          text: [
            l10n.statusRejected,
            if (reason != null) RejectReasonLabels.of(l10n, reason),
          ].join(_separator),
          card: true,
        );
      case MembershipStatus.pending ||
          MembershipStatus.removed ||
          MembershipStatus.left ||
          MembershipStatus.cancelled:
        return null;
    }
  }
}

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_ui/gu_ui.dart';

/// SHT-21'de dokunulan satır — sayfanın `pop` değeri. Sıra tasarımdaki satır
/// sırasıdır (`sheets.js:104`).
enum MemberAction {
  /// "Profili gör" (`SHT-21.profile`) → CLB-07.
  viewProfile('profile', GuIcons.user),

  /// "Rolü değiştir" (`SHT-21.changeRole`) → SHT-22 → DLG-20.
  changeRole('changeRole', GuIcons.userCog),

  /// "Üyelikten çıkar" (`SHT-21.remove`, yıkıcı) → DLG-19.
  remove('remove', GuIcons.userX);

  const MemberAction(this.action, this.icon);

  /// Aksiyon adı (`SHT-21.<action>`).
  final String action;

  /// Satırın ikonu.
  final GuIcons icon;

  /// Yıkıcı satır mı (kırmızı ikon + metin): yalnızca "Üyelikten çıkar".
  bool get isDanger => this == remove;
}

/// SHT-21'in bir satırı: eylem + etkin mi. Devre dışı satır soluk çizilir,
/// altında nedeni yazar (`sht21PresidentOnly` / `sht21Hierarchy`) ve
/// dokunuşu TST-X18 gösterir (`sheets.js:104`).
final class MemberActionOption extends Equatable {
  /// [action] satırı; [enabled] `false` → devre dışı.
  const MemberActionOption(this.action, {this.enabled = true});

  /// Satırın eylemi.
  final MemberAction action;

  /// Aktör bu eylemi bu hedefe uygulayabilir mi.
  final bool enabled;

  @override
  List<Object?> get props => [action, enabled];
}

/// SHT-21 "Üye işlemleri" — bir üyenin yönetici menüsü (prototip
/// `SHEETS['SHT-21']`, `sheets.js:102–104`). MGT-03 satır menüsü
/// (`MGT-03.menu.<uid>`) ve CLB-06 yönetici menüsü (W-20) açar; feature'da
/// kopyası yoktur (PLAN §4.5.2).
///
/// * Başlık üyenin adıdır ([userName]); verilmezse "Üye işlemleri".
/// * Satırlar (`GuTile`, ikon 22): "Profili gör" · "Rolü değiştir" ·
///   "Üyelikten çıkar" (yıkıcı). Hangisinin etkin olduğuna **yalnızca**
///   [actionsFor] karar verir (hiyerarşi tek yer; `RolePolicy` üzerine).
/// * Devre dışı satır kapanmaz: TST-X18 gösterir.
/// * Sayfa hiçbir şey yürütmez: etkin satır [MemberAction] olarak döner
///   (`pop`), eylemi çağıran başlatır. X / scrim / sürükleme / geri → `null`.
/// * Anahtarlar `SHT-21.profile`, `.changeRole`, `.remove`, `SHT-21.close`
///   (+ `SHT-21.scrim`, `FeedbackService`).
///
/// ```dart
/// final action = await feedback.showSheet<MemberAction>(
///   SheetId.sht21,
///   builder: (_) => MemberActionsSheet(
///     membership: m,
///     actorRole: state.myRole,
///     userName: m.applicant.name,
///   ),
/// );
/// ```
///
/// Design: SHT-21
class MemberActionsSheet extends ConsumerWidget {
  /// [membership] üyeliği için [actorRole] rolündeki aktörün menüsü.
  const MemberActionsSheet({
    required this.membership,
    required this.actorRole,
    this.isSuperAdmin = false,
    this.isSelf = false,
    this.userName,
    super.key,
  });

  /// Hedef üyelik (`status == active`).
  final MembershipModel membership;

  /// Aktörün bu kulüpteki aktif rolü (`RolePolicy.activeRole`); yoksa
  /// `null`.
  final ClubRole? actorRole;

  /// Aktör süper admin mi (global claim).
  final bool isSuperAdmin;

  /// Hedef aktörün kendisi mi (kendine işlem yok).
  final bool isSelf;

  /// Başlıktaki ad; verilmezse genel başlık ("Üye işlemleri").
  final String? userName;

  /// [action] satırının anahtarı (`SHT-21.<action>`).
  static Key keyOf(MemberAction action) => switch (action) {
    MemberAction.viewProfile => GuKey.action('SHT-21.profile'),
    MemberAction.changeRole => GuKey.action('SHT-21.changeRole'),
    MemberAction.remove => GuKey.action('SHT-21.remove'),
  };

  /// Menü bu hedef için açılabilir mi — çağıran satırdaki menü düğmesini
  /// buna göre çizer (`screens-manage.js:71`, `screens-clubs.js:147`):
  /// aktör yönetici (yönetim kurulu / başkan) ya da süper admin olmalı;
  /// başkan ve danışman satırında menü yoktur.
  static bool canOpen({
    required ClubRole? actorRole,
    required ClubRole targetRole,
    bool isSuperAdmin = false,
  }) =>
      RolePolicy.can(
        ClubPermission.removeMember,
        actorRole,
        isSuper: isSuperAdmin,
      ) &&
      (targetRole == ClubRole.member || targetRole == ClubRole.board);

  /// Görünen satırlar, tasarım sırasıyla — hiyerarşinin **tek yeri**
  /// (domain-model §5; `RolePolicy.canRemove` / `canAssignRole`):
  ///
  /// | aktör \ hedef | member | board | president / advisor |
  /// |---|---|---|---|
  /// | president / süper | rol ✓ · çıkar ✓ | rol ✓ · çıkar ✓ | menü yok |
  /// | board | rol ✗ · çıkar ✓ | rol ✗ · çıkar ✗ | menü yok |
  /// | advisor / member / yok | menü yok | menü yok | menü yok |
  ///
  /// "Profili gör" menü açıldığında hep etkindir; [isSelf] iken rol ve
  /// çıkarma devre dışıdır. [canOpen] `false` → boş liste.
  static List<MemberActionOption> actionsFor({
    required ClubRole? actorRole,
    required ClubRole targetRole,
    required bool isSelf,
    bool isSuperAdmin = false,
  }) {
    if (!canOpen(
      actorRole: actorRole,
      targetRole: targetRole,
      isSuperAdmin: isSuperAdmin,
    )) {
      return const [];
    }
    final otherRole = targetRole == ClubRole.member
        ? ClubRole.board
        : ClubRole.member;
    return [
      const MemberActionOption(MemberAction.viewProfile),
      MemberActionOption(
        MemberAction.changeRole,
        enabled:
            !isSelf &&
            RolePolicy.canAssignRole(
              actorRole,
              targetRole,
              otherRole,
              isSuper: isSuperAdmin,
            ),
      ),
      MemberActionOption(
        MemberAction.remove,
        enabled:
            !isSelf &&
            RolePolicy.canRemove(actorRole, targetRole, isSuper: isSuperAdmin),
      ),
    ];
  }

  /// [action] satırının görünen adı.
  static String labelOf(AppLocalizations l10n, MemberAction action) =>
      switch (action) {
        MemberAction.viewProfile => l10n.userprofileView,
        MemberAction.changeRole => l10n.userprofileChangeRole,
        MemberAction.remove => l10n.userprofileRemove,
      };

  /// Devre dışı [action] satırının alt yazısı (`sheets.js:104`).
  static String? disabledHintOf(AppLocalizations l10n, MemberAction action) =>
      switch (action) {
        MemberAction.viewProfile => null,
        MemberAction.changeRole => l10n.sht21PresidentOnly,
        MemberAction.remove => l10n.sht21Hierarchy,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.gu.colors;
    final options = actionsFor(
      actorRole: actorRole,
      targetRole: membership.role,
      isSelf: isSelf,
      isSuperAdmin: isSuperAdmin,
    );
    return GuSheetFrame(
      title: userName ?? l10n.sht21Title,
      closeSemanticLabel: l10n.a11yClose,
      closeKey: GuKey.action('SHT-21.close'),
      menu: true,
      flush: true,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final option in options)
            GestureDetector(
              key: option.enabled ? null : keyOf(option.action),
              behavior: HitTestBehavior.opaque,
              onTap: option.enabled
                  ? null
                  : () => ref
                        .read(feedbackServiceProvider)
                        .showToast(ToastId.tstX18),
              child: GuTile(
                key: option.enabled ? keyOf(option.action) : null,
                title: labelOf(l10n, option.action),
                subtitle: option.enabled
                    ? null
                    : disabledHintOf(l10n, option.action),
                danger: option.action.isDanger,
                disabled: !option.enabled,
                leading: GuIcon(
                  option.action.icon,
                  size: GuSizes.icon22,
                  color: option.action.isDanger
                      ? colors.stateDanger
                      : colors.textHeading,
                ),
                onTap: () => Navigator.of(context).pop(option.action),
              ),
            ),
        ],
      ),
    );
  }
}

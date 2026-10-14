import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/widget/member/member_row.dart';
import 'package:gu_ui/gu_ui.dart';

/// SHT-22 "Rol seç" — SHT-21 "Rolü değiştir" (MGT-03, CLB-06) ve CLB-07
/// yönetici kartı "Rolü değiştir" (W-69) açar (prototip `SHEETS['SHT-22']`,
/// `sheets.js:105–107`). İki feature'dan açıldığı için product'tadır (B05;
/// `ManageMemberActionsMixin.changeMemberRole`).
///
/// * Gövde (`col gap8 pb16`): [options] sırasıyla seçenek kartları (radyo +
///   rol rozeti + açıklama); başlangıçta [currentRole] seçilidir. Altta not:
///   "Başkanlık devri Üye Yönetimi ekranından yapılır."
/// * Alt çubuk: "Kaydet" — seçim [currentRole] ile aynıyken devre dışı
///   (dokunuş TST-X9); seçilen rol ile `pop`. X / scrim / sürükleme / geri →
///   `null`. Onay (DLG-20) ve yazma çağırandadır
///   (`ManageMemberActionsMixin.changeMemberRole`, TST-46).
/// * Anahtarlar `SHT-22.role.member`, `SHT-22.role.board`, `SHT-22.save`,
///   `SHT-22.close` (+ `SHT-22.scrim`).
///
/// ```dart
/// final role = await feedback.showSheet<ClubRole>(
///   SheetId.sht22,
///   builder: (_) => RolePickerSheet(currentRole: m.role),
/// );
/// ```
///
/// Design: SHT-22
class RolePickerSheet extends ConsumerStatefulWidget {
  /// [currentRole] rolündeki üyenin yeni rolünü seçtirir.
  const RolePickerSheet({required this.currentRole, super.key});

  /// Üyenin şimdiki rolü (`member` ya da `board`).
  final ClubRole currentRole;

  /// Seçilebilen roller, tasarım sırasıyla (`['member', 'board']`).
  static const List<ClubRole> options = [ClubRole.member, ClubRole.board];

  /// [role] seçenek kartının anahtarı (`SHT-22.role.<rol>`).
  static Key roleKey(ClubRole role) => switch (role) {
    ClubRole.board => GuKey.action('SHT-22.role.board'),
    _ => GuKey.action('SHT-22.role.member'),
  };

  /// "Kaydet" düğmesinin anahtarı (`SHT-22.save`).
  static final Key saveKey = GuKey.action('SHT-22.save');

  /// [role] seçeneğinin açıklaması.
  static String descriptionOf(AppLocalizations l10n, ClubRole role) =>
      role == ClubRole.board ? l10n.sht22Board : l10n.sht22Member;

  @override
  ConsumerState<RolePickerSheet> createState() => _RolePickerSheetState();
}

class _RolePickerSheetState extends ConsumerState<RolePickerSheet> {
  late ClubRole _role = widget.currentRole;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    return GuSheetFrame(
      title: l10n.sht22Title,
      closeSemanticLabel: l10n.a11yClose,
      closeKey: GuKey.action('SHT-22.close'),
      footer: [
        GuButton(
          key: RolePickerSheet.saveKey,
          label: l10n.commonSave,
          disabled: _role == widget.currentRole,
          onDisabledPressed: () =>
              ref.read(feedbackServiceProvider).showToast(ToastId.tstX9),
          onPressed: () => Navigator.of(context).pop<ClubRole>(_role),
        ),
      ],
      body: Padding(
        padding: GuInsets.only(bottom: GuSpacing.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: GuSpacing.s8,
          children: [
            for (final role in RolePickerSheet.options)
              GuOptionCard(
                key: RolePickerSheet.roleKey(role),
                selected: _role == role,
                onTap: () => setState(() => _role = role),
                leading: ExcludeSemantics(
                  child: GuRadio(
                    selected: _role == role,
                    onSelected: () => setState(() => _role = role),
                    semanticLabel: MemberRow.roleBadge(l10n, role).label,
                  ),
                ),
                // `.flex1.col` (align-items varsayılanı stretch): rozet
                // satır genişliğinde uzar (referans SHT-22).
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: GuSpacing.s4,
                  children: [
                    MemberRow.roleBadge(l10n, role),
                    Text(
                      RolePickerSheet.descriptionOf(l10n, role),
                      style: gu.text.bodyS.copyWith(
                        color: gu.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            Text(l10n.sht22TransferNote, style: gu.text.caption),
          ],
        ),
      ),
    );
  }
}

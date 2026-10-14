import 'package:flutter/widgets.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/widget/member/member_row.dart';
import 'package:gu_ui/gu_ui.dart';

/// Yönetim ekranlarının başlık çubuğu — prototip `MgtHeader`
/// (`screens-manage.js:7–10`): geri · iki satırlı başlık (üstte ekran adı
/// `caption`, altta kulüp adı `titleS`) · rol rozeti · ek eylemler.
///
/// * Kullanıcı birden çok kulüp yönetiyorsa ([onSwitchClub] verilir) kulüp
///   adı `chevron-down`'lı düğmedir (SHT-18 `ManagedClubPickerSheet`; sheet'i
///   çağıran açar). Ad en çok `manageHeaderClubMaxWidth` (190) geniş, sonra
///   üç nokta.
/// * Rol rozeti [role]'dür; süper admin bakışında [isSuperAdmin]. İkisi de
///   yoksa (kulüp henüz okunmadı) rozet çizilmez.
/// * Danışmanın salt okunur bandı (prototip `ROBanner`,
///   `screens-manage.js:12`) çubuğun parçası değildir: ekran gövdesinin en
///   üstünde, kaydırma alanının dışında `GuBanner(kind: readonly)` çizer
///   (büyük metin ölçeğinde `preferredSize` sınırını aşmasın diye).
/// * Anahtarları çağıran verir (D-18): [backKey] (`<ID>.back`),
///   [switchClubKey] (`<ID>.switchClub`).
///
/// Tasarımda amblem yoktur (`screens/MGT-01__light__tr.webp`); yalnızca ad.
/// Tek ad `ManageHeader`'dır (widget-catalog P19); feature altında
/// `mgt_header.dart` yazılmaz.
class ManageHeader extends StatelessWidget implements PreferredSizeWidget {
  /// [club] kulübünün [title] ekranı için başlık çubuğu.
  const ManageHeader({
    required this.club,
    required this.title,
    required this.onBack,
    required this.backKey,
    this.role,
    this.isSuperAdmin = false,
    this.onSwitchClub,
    this.switchClubKey,
    this.actions = const [],
    super.key,
  });

  /// Yönetilen kulüp; `null` → henüz okunmadı (ad boş).
  final ClubModel? club;

  /// Ekran adı (üst satır, `caption`).
  final String title;

  /// Geri düğmesi.
  final VoidCallback onBack;

  /// Geri düğmesinin aksiyon anahtarı.
  final Key backKey;

  /// Kullanıcının bu kulüpteki rolü (rozet).
  final ClubRole? role;

  /// Süper admin rozeti ([role] yoksa).
  final bool isSuperAdmin;

  /// Kulüp değiştirme (SHT-18); `null` → tek kulüp, ad düz metin.
  final VoidCallback? onSwitchClub;

  /// Kulüp değiştirme düğmesinin aksiyon anahtarı.
  final Key? switchClubKey;

  /// Rozetten sonraki eylemler (`GuIconButton`).
  final List<Widget> actions;

  @override
  Size get preferredSize => const GuAppBar().preferredSize;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final role = this.role;
    final badge = role != null
        ? MemberRow.roleBadge(l10n, role)
        : isSuperAdmin
        ? GuRoleBadge(
            kind: GuRoleBadgeKind.superadmin,
            label: l10n.roleSuperadmin,
          )
        : null;
    return GuAppBar(
      titleWidget: _title(context),
      onBack: onBack,
      backSemanticLabel: l10n.a11yBack,
      backActionKey: backKey,
      actions: [?badge, ...actions],
    );
  }

  Widget _title(BuildContext context) {
    final gu = context.gu;
    final name = club?.name ?? '';
    final switchClub = onSwitchClub;
    final nameText = Text(
      name,
      style: gu.text.titleS,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: gu.text.caption,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        ),
        if (switchClub == null)
          Semantics(header: true, child: nameText)
        else
          Semantics(
            header: true,
            hint: context.l10n.sht18Title,
            child: GuTapTarget(
              key: switchClubKey,
              onTap: switchClub,
              semanticLabel: name,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: GuSpacing.s4,
                children: [
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: GuSizes.manageHeaderClubMaxWidth,
                      ),
                      child: nameText,
                    ),
                  ),
                  GuIcon(
                    GuIcons.chevronDown,
                    size: GuSizes.icon16,
                    color: gu.colors.textHeading,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/format/app_date_formats.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/l10n/static_labels.dart';
import 'package:gu_kulupler/product/widget/member/user_row.dart';
import 'package:gu_ui/gu_ui.dart';

/// Üye satırı — prototip `MemberRow` (`cards.js:165–169`): `UserRow` + rol
/// rozeti (+ katılım oranı çubuğu) + isteğe bağlı "⋮" menüsü (CD-27). CLB-03
/// üye önizlemesi, CLB-06, MGT-03 kullanır.
///
/// * Ad, bölüm · sınıf ve avatar [membership]'in `applicant` anlık
///   görüntüsünden gelir (D-29); [user] verilirse (güncel belge) o kullanılır.
/// * Rol rozeti her rolde çizilir (üye dahil — `ui.js:67`).
/// * [sub] verilmezse alt satır bölüm · sınıftır. [trailing] verilirse menü
///   düğmesinin yerini alır; verilmezse ve [onMenu] varsa "⋮" çizilir
///   (`more-vertical`, "Daha fazla").
/// * [rate] (0–100) yalnızca [showRate] `true` iken çizilir (MGT-03): ince
///   başarı çubuğu + yüzde (`caption`, tablo rakamı).
/// * [inCard] + [chevron] kart içi biçimdir (CLB-03 yönetim kurulu:
///   `UserRow inCard chevron`, `screens-clubs.js:98`).
/// * Anahtarları çağıran verir (D-18, CD-86): [actionKey]
///   `<ID>.member.<userId>`, [menuActionKey] `<ID>.menu.<userId>`.
/// * Erişilebilirlik: satır ad + rol + alt satır (+ oran çubuğu etiketi ve
///   yüzde) ile okunan tek düğmedir; menü ayrı düğmedir.
///
/// ```dart
/// MemberRow(
///   membership: member,
///   actionKey: GuKey.action('CLB-06.member.${member.userId}'),
///   onTap: () => openProfile(member.userId),
/// )
/// ```
class MemberRow extends ConsumerWidget {
  /// [membership] üyeliğinin satırı.
  const MemberRow({
    required this.membership,
    this.user,
    this.onMenu,
    this.menuActionKey,
    this.sub,
    this.trailing,
    this.showRate = false,
    this.rate,
    this.onTap,
    this.actionKey,
    this.inCard = false,
    this.chevron = false,
    this.avatarImage,
    super.key,
  });

  /// Üyelik (rol + `applicant` anlık görüntüsü).
  final MembershipModel membership;

  /// Güncel kullanıcı belgesi; `null` → `applicant` anlık görüntüsü.
  final UserModel? user;

  /// Profil fotoğrafı ([user]'ın `avatarPath`'i; çağıran
  /// `ref.userAvatarImage(user)` ile çözer). `null` → baş harfler.
  final ImageProvider? avatarImage;

  /// "⋮" menüsü; `null` → düğme çizilmez.
  final VoidCallback? onMenu;

  /// Menü düğmesinin aksiyon anahtarı; çağıran verir.
  final Key? menuActionKey;

  /// Alt satır; `null` → bölüm · sınıf.
  final String? sub;

  /// Satır sonundaki öğe; verilirse menü düğmesinin yerini alır.
  final Widget? trailing;

  /// Katılım oranı çubuğu çizilsin mi (MGT-03).
  final bool showRate;

  /// Katılım oranı (0–100); [showRate] `true` iken çizilir.
  final int? rate;

  /// Satıra dokunma (CLB-07); `null` → düz satır.
  final VoidCallback? onTap;

  /// Satırın aksiyon anahtarı (`GuKey.action`); çağıran verir.
  final Key? actionKey;

  /// Kart içi satır (`.tile.in-card`) — CLB-03 yönetim kurulu kartı.
  final bool inCard;

  /// Sonda `chevron-right` (CLB-03 yönetim kurulu kartı).
  final bool chevron;

  /// Alt satır ayracı (`cards.js:8` `' · '`).
  static const String _separator = ' · ';

  /// [role] rolünün rozeti — prototip `RoleBadge` (`ui.js:67`): başkan
  /// `crown`, yönetim kurulu `shield-check`, danışman `graduation-cap`, üye
  /// `user-check`.
  static GuRoleBadge roleBadge(AppLocalizations l10n, ClubRole role) =>
      switch (role) {
        ClubRole.president => GuRoleBadge(
          kind: GuRoleBadgeKind.president,
          label: l10n.rolePresident,
        ),
        ClubRole.board => GuRoleBadge(
          kind: GuRoleBadgeKind.board,
          label: l10n.roleBoard,
        ),
        ClubRole.advisor => GuRoleBadge(
          kind: GuRoleBadgeKind.advisor,
          label: l10n.roleAdvisor,
        ),
        ClubRole.member => GuRoleBadge(
          kind: GuRoleBadgeKind.member,
          label: l10n.roleMember,
        ),
      };

  /// "Bölüm · N. sınıf" (`cards.js:8` `deptYear`); ikisi de yoksa boş.
  static String departmentAndYear(
    BuildContext context, {
    required String? department,
    required YearLevel? year,
  }) => [
    if (department != null) StaticLabels.department(context, department),
    if (year != null) StaticLabels.year(context, year),
  ].join(_separator);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final user = this.user;
    final applicant = membership.applicant;
    final name = user?.name ?? applicant.name;
    final seed = user?.avatarSeed ?? applicant.avatarSeed;
    final badge = roleBadge(l10n, membership.role);
    final subtitle =
        sub ??
        departmentAndYear(
          context,
          department: user == null ? applicant.department : user.department,
          year: user == null ? applicant.year : user.year,
        );
    final shownRate = showRate ? rate : null;
    // Yüzde yerel ayara göre yazılır (`%62` / `62%` — CD-101).
    final percent = shownRate == null
        ? null
        : AppDateFormats(
            Localizations.localeOf(context),
            ref.watch(appClockProvider),
          ).percent(shownRate);
    final onMenu = this.onMenu;

    return UserRow.named(
      name: name,
      avatarSeed: seed.isEmpty ? membership.userId : seed,
      sub: subtitle,
      badge: badge,
      sub2: shownRate == null || percent == null
          ? null
          : _RateLine(rate: shownRate, label: percent),
      trailing:
          trailing ??
          (onMenu == null
              ? null
              : GuIconButton(
                  key: menuActionKey,
                  icon: GuIcons.moreVertical,
                  semanticLabel: l10n.a11yMore,
                  onPressed: onMenu,
                )),
      inCard: inCard,
      chevron: chevron,
      onTap: onTap,
      actionKey: actionKey,
      avatarImage: avatarImage,
    );
  }
}

/// Katılım oranı satırı (`cards.js:167` `sub2`): ince başarı çubuğu (kalan
/// genişlik) + yüzde (`caption`, tablo rakamı), aralık 6.
class _RateLine extends StatelessWidget {
  const _RateLine({required this.rate, required this.label});

  /// Oran (0–100).
  final int rate;

  /// Yüzde metni (`%62`).
  final String label;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    return Row(
      spacing: GuSpacing.s6,
      children: [
        Expanded(
          child: GuProgress(
            value: rate.toDouble(),
            semanticLabel: context.l10n.mgtMembersRate,
            kind: GuProgressKind.success,
            thin: true,
          ),
        ),
        Text(
          label,
          style: gu.text.caption.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/clubs/provider/user_profile_state.dart';
import 'package:gu_kulupler/features/clubs/view/mixin/user_profile_view_mixin.dart';
import 'package:gu_kulupler/features/clubs/view/widget/user_profile_header.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/media/user_avatar_image.dart';
import 'package:gu_kulupler/product/widget/club/cover_mapper.dart';
import 'package:gu_kulupler/product/widget/member/member_row.dart';
import 'package:gu_ui/gu_ui.dart';

/// Kullanıcı profili — paylaşılan yaprak ekran (PLAN §13.9): beş rota aynı
/// view'ı açar — `ClubUserProfileRoute` (`/clubs/user/:userId?clubId=`),
/// kulüp bağlamlı `ClubDetailUserProfileRoute` (`/clubs/:clubId/user/:userId`)
/// ve `ClubMembersUserProfileRoute` (`/clubs/:clubId/members/:userId`; geri →
/// geldiği kulüp, K-69), `BlockedUserProfileRoute` (T-28),
/// `AdminUserProfileRoute` (T-41). Prototip `UserProfile`
/// (`screens-clubs.js:151–162`).
///
/// Çubuk: geri + "Profil" + "⋮" (SHT-27; kendi profilinde ve silinmiş
/// kullanıcıda çizilmez). Gövde, yukarıdan aşağı:
///
/// * **Engel bandı** (yalnızca kullanıcı engelliyken): "Bu kullanıcıyı
///   engelledin." + "Engeli kaldır" (TST-09).
/// * **Başlık** (`UserProfileHeader`): avatar 96, ad, bölüm · sınıf, rol
///   rozetleri, biyografi.
/// * **Gizli profil** (ortak kulüp yok — D-29, S-1): kilit illüstrasyonu +
///   "Bu profil yalnızca ortak kulüp üyelerine açık."; bölüm / sınıf ve
///   biyografi de çizilmez.
/// * **Ortak kulüpler** (profil görünürken ve varsa): başlık + kulüp çipleri
///   (→ CLB-03).
/// * **Süper admin bakışı** (T-41, `AdminUserProfileRoute`; kulüp bağlamı
///   olmadan da): kart yalnızca e-posta + "Kopyala" (TST-08) satırıyla
///   çizilir — e-posta `users/{uid}/private/account` (D-29).
/// * **Yönetici bağlamı kartı** (açılış kulübünün yöneticisi / süper admini
///   ve kullanıcı o kulübün aktif üyesiyken; W-69, `screens-clubs.js:160–161`):
///   e-posta + "Kopyala" (TST-08), kulüpteki rol, üyelik tarihi; altında
///   "Rolü değiştir" (yalnızca başkan / süper admin → SHT-22) ve "Üyelikten
///   çıkar" (DLG-19) — hedef başkan ya da danışmansa düğme yok.
///
/// [clubId] yalnızca kulüp bağlamından açılışta doludur (üyelik bağlamı).
/// Durumlar: okunamadı → hata + "Yeniden dene"; okunuyor → iskelet; kullanıcı
/// yok → SYS-04; silinmiş kullanıcı → yalnızca "Silinmiş kullanıcı" başlığı.
/// Alt boşluk gerçek güvenli alan + 8'dir (K-07). Davranış
/// `UserProfileViewMixin`'dedir.
///
/// Design: CLB-07
class UserProfileView extends ConsumerStatefulWidget {
  /// [userId] kullanıcısının profili; [clubId] açıldığı kulüp bağlamıdır.
  const UserProfileView({required this.userId, this.clubId, super.key});

  /// Profili açılan kullanıcının kimliği (yol parametresi).
  final String userId;

  /// Açıldığı kulüp (yol `:clubId` ya da `?clubId=`); kulüp bağlamı yoksa
  /// `null`.
  final String? clubId;

  @override
  ConsumerState<UserProfileView> createState() => _UserProfileViewState();
}

class _UserProfileViewState extends ConsumerState<UserProfileView>
    with UserProfileViewMixin {
  /// Gizli profil bloğu — ham `.empty` (dolgu 32 / 24, aralık 12) + kilit
  /// illüstrasyonu 96 (`screens-clubs.js:158`).
  Widget _private(AppLocalizations l10n) {
    final gu = context.gu;
    return Padding(
      padding: GuInsets.sym(
        h: GuSizes.emptyPaddingX,
        v: GuSizes.emptyPaddingY,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: GuSizes.emptyGap,
        children: [
          const GuIllustration(
            GuIllustrations.locked,
            size: GuSizes.illustrationCompact,
          ),
          Text(
            l10n.userprofilePrivate,
            style: gu.text.bodyS.copyWith(color: gu.colors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// "Ortak kulüpler": başlık + kulüp çipleri (aralık 8, sarar;
  /// `screens-clubs.js:159`). Prototipteki `pt24` CSS'te tanımsızdır: üst
  /// dolgu yoktur (CD-99, K-42).
  Widget _commonClubs(List<ClubModel> clubs, AppLocalizations l10n) => Padding(
    padding: GuInsets.h16,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: GuSpacing.s8,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.userprofileCommonClubs,
            style: context.gu.text.titleS,
          ),
        ),
        Wrap(
          spacing: GuSpacing.s8,
          runSpacing: GuSpacing.s8,
          children: [
            for (final club in clubs)
              GuChip(
                key: GuKey.action('CLB-07.club.${club.id}'),
                label: club.name,
                icon: CoverMapper.icon(club.iconName),
                onTap: () => openClub(club.id),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _content(
    UserProfileState state,
    UserModel user,
    AppLocalizations l10n,
  ) => SingleChildScrollView(
    padding: GuInsets.only(
      bottom:
          MediaQuery.paddingOf(context).bottom +
          GuSizes.screenScrollBottomExtra,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.isBlocked)
          GuBanner(
            kind: GuBannerKind.warning,
            icon: GuIcons.ban,
            text: l10n.userprofileBlockedBanner,
            actionLabel: l10n.userprofileUnblock,
            actionKey: GuKey.action('CLB-07.unblock'),
            onAction: unblock,
          ),
        UserProfileHeader(
          user: user,
          showDetails: state.showsDetails,
          isSuperAdmin: state.isSuperAdmin,
          roles: state.roles,
          avatarImage: ref.userAvatarImage(user),
        ),
        if (state.isHiddenByPrivacy)
          _private(l10n)
        else if (state.showsDetails && state.sharedClubs.isNotEmpty)
          _commonClubs(state.sharedClubs, l10n),
        if (state.showsContactCard) ...[
          // `.col.gap20`: ortak kulüplerden sonra 20.
          if (state.showsDetails && state.sharedClubs.isNotEmpty) GuGap.v20,
          _managerCard(state, l10n),
        ],
      ],
    ),
  );

  /// E-posta / yönetici bağlamı kartı (`screens-clubs.js:160–161`): e-posta,
  /// rol ve üyelik tarihi satırları; altında rol / çıkarma düğmeleri. Kulüp
  /// bağlamı olmayan süper admin bakışında yalnızca e-posta satırı (T-41).
  Widget _managerCard(UserProfileState state, AppLocalizations l10n) {
    final gu = context.gu;
    final membership = state.showsManagerCard ? state.contextMembership : null;
    final email = state.contactEmail;
    final decidedAt = membership?.decidedAt;
    Widget icon(GuIcons name) =>
        GuIcon(name, size: GuSizes.icon20, color: gu.colors.textMuted);
    return Padding(
      padding: GuInsets.h16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: GuSpacing.s20,
        children: [
          GuCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (email != null) ...[
                  GuTile(
                    title: email,
                    subtitle: l10n.authEmail,
                    padding: GuTilePadding.inCard,
                    leading: icon(GuIcons.mail),
                    trailing: GuButton(
                      key: GuKey.action('CLB-07.copyEmail'),
                      label: l10n.commonCopy,
                      icon: GuIcons.copy,
                      size: GuButtonSize.sm,
                      variant: GuButtonVariant.text,
                      onPressed: copyEmail,
                    ),
                  ),
                  if (membership != null) const GuDivider(),
                ],
                if (membership != null) ...[
                  GuTile(
                    title: MemberRow.roleBadge(l10n, membership.role).label,
                    subtitle: l10n.userprofileRoleIn(
                      state.contextClubName ?? '',
                    ),
                    padding: GuTilePadding.inCard,
                    leading: icon(GuIcons.shieldCheck),
                  ),
                  const GuDivider(),
                  GuTile(
                    title: decidedAt == null ? '—' : formatDate(decidedAt),
                    subtitle: l10n.userprofileMemberSince,
                    padding: GuTilePadding.inCard,
                    leading: icon(GuIcons.calendarCheck),
                  ),
                ],
              ],
            ),
          ),
          if (state.showsManagerActions)
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: GuSpacing.s8,
              children: [
                if (state.canAssignRoles)
                  GuButton(
                    key: GuKey.action('CLB-07.changeRole'),
                    label: l10n.userprofileChangeRole,
                    icon: GuIcons.userCog,
                    variant: GuButtonVariant.outline,
                    onPressed: changeRole,
                  ),
                GuButton(
                  key: GuKey.action('CLB-07.remove'),
                  label: l10n.userprofileRemove,
                  icon: GuIcons.userX,
                  variant: GuButtonVariant.dangerOutline,
                  onPressed: remove,
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// Okunuyor: başlığın iskeleti (avatar 96 + iki satır, ortalı).
  Widget _skeleton(AppLocalizations l10n) => Semantics(
    container: true,
    liveRegion: true,
    label: l10n.commonLoading,
    child: ExcludeSemantics(
      child: Padding(
        padding: GuInsets.only(
          left: GuSpacing.s16,
          top: GuSpacing.s16,
          right: GuSpacing.s16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: GuSpacing.s12,
          children: [
            GuSkeleton(
              width: UserProfileHeader.avatarSize,
              height: UserProfileHeader.avatarSize,
              circle: true,
            ),
            GuSkeleton(
              widthFactor: GuSizes.skeletonWidthRatios[0],
              height: GuSizes.skeletonTitleHeight,
            ),
            GuSkeleton(
              widthFactor: GuSizes.skeletonWidthRatios[2],
              height: GuSizes.skeletonSubHeight,
            ),
          ],
        ),
      ),
    ),
  );

  /// Okunamadı: hata durumu, kalan alanda dikeyde ortalı; sığmazsa kayar.
  Widget _error(AppLocalizations l10n) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      padding: GuInsets.only(
        bottom:
            MediaQuery.paddingOf(context).bottom +
            GuSizes.screenScrollBottomExtra,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Center(
          child: GuErrorState(
            title: l10n.sysErrorTitle,
            description: l10n.sysErrorDesc,
            retryLabel: l10n.commonRetry,
            onRetry: retry,
            retryActionKey: GuKey.action('CLB-07.retry'),
          ),
        ),
      ),
    ),
  );

  /// Koşullu gövde: kullanıcı yok → boş (SYS-04'e gidiliyor); hata; iskelet;
  /// içerik.
  Widget _body(UserProfileState state, AppLocalizations l10n) {
    if (state.isNotFound) return const SizedBox.shrink();
    if (state.isError) return _error(l10n);
    final user = state.user;
    if (user == null || state.isFetching) return _skeleton(l10n);
    return _content(state, user, l10n);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(provider);
    watchNotFound();

    return Scaffold(
      backgroundColor: context.gu.colors.bgCanvas,
      appBar: GuAppBar(
        title: l10n.userprofileTitle,
        onBack: goBack,
        backSemanticLabel: l10n.a11yBack,
        backActionKey: GuKey.action('CLB-07.back'),
        actions: [
          if (state.canOpenMenu)
            GuIconButton(
              key: GuKey.action('CLB-07.menu'),
              icon: GuIcons.moreVertical,
              semanticLabel: l10n.a11yMore,
              onPressed: () => unawaited(openMenu()),
            ),
        ],
      ),
      body: _body(state, l10n),
    );
  }
}

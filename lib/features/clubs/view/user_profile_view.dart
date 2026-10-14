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
import 'package:gu_ui/gu_ui.dart';

/// Kullanıcı profili — paylaşılan yaprak ekran (PLAN §13.9): üç rota aynı
/// view'ı açar — `ClubUserProfileRoute` (`/clubs/user/:userId?clubId=`),
/// `BlockedUserProfileRoute` (T-28), `AdminUserProfileRoute` (T-41). Prototip
/// `UserProfile` (`screens-clubs.js:151–162`).
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
/// * Yönetici bağlamı kartı (e-posta, kulüpteki rol, üyelik tarihi, rol
///   değiştir / çıkar) üye yönetimiyle gelir (T-33, bağlama borcu W-69).
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

  /// Açıldığı kulüp (`?clubId=`); kulüp bağlamı yoksa `null`.
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
        // TODO(T-33): yönetici bağlamı kartı — e-posta + "Kopyala", kulüpteki
        // rol, üyelik tarihi, "Rolü değiştir" (SHT-22), "Kulüpten çıkar"
        // (DLG-19); `state.contextMembership` hazır (W-69,
        // `screens-clubs.js:160–161`).
      ],
    ),
  );

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

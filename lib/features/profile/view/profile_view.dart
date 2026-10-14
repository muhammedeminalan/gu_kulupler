import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/format/app_date_formats.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/profile/provider/profile_state.dart';
import 'package:gu_kulupler/features/profile/provider/profile_view_model.dart';
import 'package:gu_kulupler/features/profile/view/mixin/profile_view_mixin.dart';
import 'package:gu_kulupler/features/profile/view/widget/profile_header.dart';
import 'package:gu_kulupler/features/profile/view/widget/profile_stats_row.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/l10n/static_labels.dart';
import 'package:gu_kulupler/product/media/user_avatar_image.dart';
import 'package:gu_kulupler/product/widget/club/adaptive_pair.dart';
import 'package:gu_kulupler/product/widget/club/my_club_row.dart';
import 'package:gu_ui/gu_ui.dart';

/// "Profil" ekranı — Profil sekmesinin kökü, `ProfileRoute` (`/profile`);
/// prototip `Profile` (`screens-profile.js:6–15`).
///
/// Yukarıdan aşağıya: büyük başlık ("Profil" · ayarlar) · kaydırma alanı
/// (çek-yenile; `.col.gap20.px16.pb24`):
///
/// 1. `ProfileHeader` — avatar (SHT-16) · ad · bölüm · sınıf · süper admin
///    rozeti · "Profili düzenle".
/// 2. `ProfileStatsRow` — Kulüp · Katıldığım etkinlik · Bekleyen başvuru.
/// 3. "Yönettiğim kulüpler" kartı (yalnızca yönetilen kulüp varken): satırlar
///    (MGT-01) + "Yönetim paneli" (tonal, tam genişlik).
/// 4. "Kulüplerim" (+ "Tümü"): ilk 3 kulüp satırı (CLB-03); kulüp yoksa
///    soluk kart (illüstrasyon 56 · "Henüz kulübün yok." · "Etkinlikleri
///    keşfet").
/// 5. Kısayol kartı: Biletlerim (EVT-04) · Kaydedilenler (PRF-04) · Ayarlar
///    (SET-01).
/// 6. "İlgi alanları" çipleri (varsa; CLB-01).
///
/// Durumlar: hata ("Bir şeyler ters gitti" + "Yeniden dene", başlığın
/// altında) → yükleniyor (başlık oturumdan çizilir, altında satır iskeleti) →
/// dolu. Boş durum yoktur (kulüpsüz kullanıcıda 4. bölüm boş kartı çizer).
/// Çevrimdışı bandı kökte çizilir; içerik önbellekle kalır, fotoğraf
/// değiştirme TST-24 verir.
///
/// Davranış `ProfileViewModel` ve `ProfileViewMixin`'dedir.
///
/// Design: PRF-01
class ProfileView extends ConsumerStatefulWidget {
  /// Oturumdaki kullanıcının profili.
  const ProfileView({super.key});

  @override
  ConsumerState<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<ProfileView>
    with ProfileViewMixin {
  /// "Kulüplerim" kartındaki en çok satır (`clubs.slice(0, 3)`).
  static const int _clubPreviewCount = 3;

  /// Kulüpsüz kartın illüstrasyonu (`Illustration size=56`; K-48).
  static final double _emptyIllustrationSize = GuSizes.illustrationSizes[0];

  /// Kart üst bilgisi (`padding:12px 16px 4px`).
  static final EdgeInsets _managedTitlePadding = GuInsets.only(
    left: GuSpacing.s16,
    top: GuSpacing.s12,
    right: GuSpacing.s16,
    bottom: GuSpacing.s4,
  );

  /// "Yönetim paneli" düğmesinin dolgusu (`.p16` + `padding-top:4px`).
  static final EdgeInsets _managedActionPadding = GuInsets.only(
    left: GuSpacing.s16,
    top: GuSpacing.s4,
    right: GuSpacing.s16,
    bottom: GuSpacing.s16,
  );

  Widget _heading(String text) => Semantics(
    header: true,
    child: Text(text, style: context.gu.text.titleS),
  );

  Widget _clubRow(ProfileClub entry, Key key, VoidCallback onTap) => MyClubRow(
    key: ValueKey<String>(entry.club.id),
    club: entry.club,
    role: entry.role,
    inCard: true,
    actionKey: key,
    onTap: onTap,
  );

  Widget _managedCard(List<ProfileClub> managed, AppLocalizations l10n) =>
      GuCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: _managedTitlePadding,
              child: Text(l10n.profileManaged, style: context.gu.text.overline),
            ),
            for (final entry in managed)
              _clubRow(
                entry,
                GuKey.action('PRF-01.managed.${entry.club.id}'),
                () => openManaged(entry.club.id),
              ),
            Padding(
              padding: _managedActionPadding,
              child: GuButton(
                key: GuKey.action('PRF-01.managedAll'),
                label: l10n.profileManagePanel,
                icon: GuIcons.layoutGrid,
                variant: GuButtonVariant.tonal,
                full: true,
                onPressed: openManagePanel,
              ),
            ),
          ],
        ),
      );

  Widget _myClubs(List<ProfileClub> clubs, AppLocalizations l10n) {
    final gu = context.gu;
    final preview = clubs.take(_clubPreviewCount).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: GuSpacing.s8,
      children: [
        Row(
          spacing: GuSpacing.s8,
          children: [
            Expanded(child: _heading(l10n.clubsMyTitle)),
            if (clubs.isNotEmpty)
              GuButton(
                key: GuKey.action('PRF-01.allClubs'),
                label: l10n.commonAll,
                variant: GuButtonVariant.text,
                size: GuButtonSize.sm,
                onPressed: openMyClubs,
              ),
          ],
        ),
        if (clubs.isNotEmpty)
          GuCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (index, entry) in preview.indexed) ...[
                  if (index > 0) const GuDivider(),
                  _clubRow(
                    entry,
                    GuKey.action('PRF-01.club.${entry.club.id}'),
                    () => openClub(entry.club.id),
                  ),
                ],
              ],
            ),
          )
        else
          GuCard(
            muted: true,
            padding: GuCard.bodyPadding,
            child: Row(
              spacing: GuSpacing.s12,
              children: [
                GuIllustration(
                  GuIllustrations.emptyClubs,
                  size: _emptyIllustrationSize,
                ),
                // Dar ekran × büyük metin ölçeğinde düğme metnin altına iner.
                Expanded(
                  child: AdaptivePair(
                    gap: GuSpacing.s12,
                    leading: Text(
                      l10n.profileNoClubs,
                      style: gu.text.bodyS.copyWith(
                        color: gu.colors.textSecondary,
                      ),
                    ),
                    trailing: GuButton(
                      key: GuKey.action('PRF-01.discover'),
                      label: l10n.eventsDiscover,
                      variant: GuButtonVariant.tonal,
                      size: GuButtonSize.sm,
                      onPressed: discoverClubs,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _shortcuts(AppLocalizations l10n) {
    final brand = context.gu.colors.brandPrimaryText;
    Widget tile(
      GuIcons icon,
      String title,
      Key key,
      VoidCallback onTap,
    ) => GuTile(
      key: key,
      title: title,
      padding: GuTilePadding.inCard,
      leading: GuIcon(icon, size: GuSizes.icon20, color: brand),
      chevron: true,
      onTap: onTap,
    );
    return GuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          tile(
            GuIcons.ticket,
            l10n.eventsTickets,
            GuKey.action('PRF-01.tickets'),
            openMyEvents,
          ),
          const GuDivider(),
          tile(
            GuIcons.bookmark,
            l10n.savedTitle,
            GuKey.action('PRF-01.saved'),
            openSaved,
          ),
          const GuDivider(),
          tile(
            GuIcons.settings,
            l10n.settingsTitle,
            GuKey.action('PRF-01.settingsRow'),
            openSettings,
          ),
        ],
      ),
    );
  }

  Widget _interests(UserModel user, AppLocalizations l10n) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: GuSpacing.s8,
    children: [
      _heading(l10n.profileInterests),
      Wrap(
        spacing: GuSpacing.s8,
        runSpacing: GuSpacing.s8,
        children: [
          for (final id in user.interests)
            GuChip(
              key: GuKey.action('PRF-01.interest.$id'),
              label: StaticLabels.interest(context, id),
              onTap: () => openInterest(id),
            ),
        ],
      ),
    ],
  );

  /// Başlığın altındaki bölümler — koşullu sıra: hata → iskelet → dolu.
  List<Widget> _sections(ProfileState state, AppLocalizations l10n) {
    if (state.isError) {
      return [
        GuErrorState(
          title: l10n.sysErrorTitle,
          description: l10n.sysErrorDesc,
          retryLabel: l10n.commonRetry,
          retryActionKey: GuKey.action('PRF-01.retry'),
          inline: true,
          onRetry: retry,
        ),
      ];
    }
    if (state.isFetching) {
      return [
        GuSkeletonList(semanticLabel: l10n.commonLoading),
      ];
    }
    final user = state.user;
    final formats = AppDateFormats(
      Localizations.localeOf(context),
      ref.watch(appClockProvider),
    );
    final managed = state.managedClubs;
    return [
      ProfileStatsRow(
        stats: state.stats,
        formatCount: formats.number,
        onClubs: openMyClubs,
        onEvents: openPastEvents,
        onPending: openPending,
        clubsKey: GuKey.action('PRF-01.stat.clubs'),
        eventsKey: GuKey.action('PRF-01.stat.events'),
        pendingKey: GuKey.action('PRF-01.stat.pending'),
      ),
      if (managed.isNotEmpty) _managedCard(managed, l10n),
      _myClubs(state.myClubs, l10n),
      _shortcuts(l10n),
      if (user != null && user.interests.isNotEmpty) _interests(user, l10n),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final state = ref.watch(profileViewModelProvider);
    final user = state.user;
    final preview = state.avatarPreview;

    return Scaffold(
      backgroundColor: gu.colors.bgCanvas,
      appBar: GuAppBar(
        title: l10n.navProfile,
        large: true,
        actions: [
          GuIconButton(
            key: GuKey.action('PRF-01.settings'),
            icon: GuIcons.settings,
            semanticLabel: l10n.settingsTitle,
            onPressed: openSettings,
          ),
        ],
      ),
      body: GuRefresh(
        onRefresh: refresh,
        child: CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverPadding(
              padding: GuInsets.only(
                left: GuSpacing.s16,
                right: GuSpacing.s16,
                bottom: GuSpacing.s24,
              ),
              sliver: SliverList.list(
                children: [
                  for (final (index, section) in [
                    if (user != null)
                      ProfileHeader(
                        user: user,
                        avatarImage: preview != null
                            ? MemoryImage(preview)
                            : ref.userAvatarImage(user),
                        isSuperAdmin: state.isSuperAdmin,
                        onAvatar: changePhoto,
                        onEdit: openEdit,
                        avatarKey: GuKey.action('PRF-01.avatar'),
                        editKey: GuKey.action('PRF-01.edit'),
                      ),
                    ..._sections(state, l10n),
                  ].indexed) ...[
                    if (index > 0) GuGap.v20,
                    section,
                  ],
                ],
              ),
            ),
            const SliverSafeArea(
              top: false,
              sliver: SliverToBoxAdapter(child: SizedBox.shrink()),
            ),
          ],
        ),
      ),
    );
  }
}

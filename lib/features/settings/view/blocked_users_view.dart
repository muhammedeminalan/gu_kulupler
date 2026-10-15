import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/settings/provider/blocked_users_state.dart';
import 'package:gu_kulupler/features/settings/provider/blocked_users_view_model.dart';
import 'package:gu_kulupler/product/media/user_avatar_image.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';
import 'package:gu_kulupler/product/widget/member/member_row.dart';
import 'package:gu_kulupler/product/widget/member/user_row.dart';
import 'package:gu_kulupler/product/widget/system/offline_list_fallback.dart';
import 'package:gu_ui/gu_ui.dart';

/// SET-02 "Engellenen kullanıcılar" — `BlockedRoute`
/// (`/profile/settings/blocked`); prototip `Blocked`
/// (`screens-profile.js:73–76`).
///
/// Yukarıdan aşağıya: başlık çubuğu (geri · "Engellenen kullanıcılar") ·
/// kaydırma alanı (çek-yenile): açıklama paragrafı (bodyS, ikincil; yatay
/// 16, alt 16) + `UserRow` satırları ("Bölüm · N. sınıf"; sonda "Engeli
/// kaldır" — küçük, çerçeveli).
///
/// * Satır → CLB-07 (`BlockedUserProfileRoute`). "Engeli kaldır" → satır
///   düşer + TST-09 "Geri al" (onay sorulmaz — prototip).
/// * Durumlar (hata → yükleniyor → boş → dolu; açıklama hep üstte): hata
///   "Bir şeyler ters gitti" + "Yeniden dene"; yükleniyor 3 satır iskeleti;
///   boş "Kimseyi engellemedin." (illüstrasyon, sıkışık). Çevrimdışı bandı
///   kökte; "Engeli kaldır" TST-24.
///
/// Design: SET-02
class BlockedUsersView extends ConsumerWidget {
  /// Engellenen kullanıcılar.
  const BlockedUsersView({super.key});

  /// Yükleniyor iskeletindeki satır sayısı.
  static const int _skeletonRows = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gu = context.gu;
    final l10n = context.l10n;
    final state = ref.watch(blockedUsersViewModelProvider);
    final viewModel = ref.read(blockedUsersViewModelProvider.notifier);
    final visible = state.visible;
    final status = GuListStatus.resolve(
      isError: state.isError,
      isLoading: state.isFetching,
      isEmpty: visible.isEmpty,
    );

    Widget row(BlockedEntry entry) {
      final (block, user) = entry;
      final userId = block.blockedId;
      final isGone = user == null || user.isDeleted || user.isAnonymized;
      final name = isGone ? l10n.commonDeletedUser : user.name;
      return UserRow(
        key: ValueKey<String>(userId),
        user: user,
        sub: isGone
            ? null
            : MemberRow.departmentAndYear(
                context,
                department: user.department,
                year: user.year,
              ),
        avatarImage: ref.userAvatarImage(user, displaySize: GuSizes.avatar),
        actionKey: GuKey.action('SET-02.user.$userId'),
        onTap: () => BlockedUserProfileRoute(userId: userId).go(context),
        trailing: GuButton(
          key: GuKey.action('SET-02.unblock.$userId'),
          label: l10n.userprofileUnblock,
          variant: GuButtonVariant.outline,
          size: GuButtonSize.sm,
          onPressed: () => unawaited(viewModel.unblock(userId, name: name)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: gu.colors.bgCanvas,
      appBar: GuAppBar(
        title: l10n.blockedTitle,
        onBack: () => context.canPop()
            ? context.pop()
            : const SettingsRoute().go(context),
        backSemanticLabel: l10n.a11yBack,
        backActionKey: GuKey.action('SET-02.back'),
      ),
      body: GuRefresh(
        onRefresh: viewModel.refresh,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: GuInsets.only(
                left: GuSpacing.s16,
                right: GuSpacing.s16,
                bottom: GuSpacing.s16,
              ),
              sliver: SliverToBoxAdapter(
                child: Text(
                  l10n.blockedDesc,
                  style: gu.text.bodyS.copyWith(
                    color: gu.colors.textSecondary,
                  ),
                ),
              ),
            ),
            ...switch (status) {
              _ when OfflineListFallback.applies(ref, status) => [
                OfflineListFallback.sliver(onReload: viewModel.fetch),
              ],
              GuListStatus.error => [
                SliverToBoxAdapter(
                  child: GuErrorState(
                    title: l10n.sysErrorTitle,
                    description: l10n.sysErrorDesc,
                    retryLabel: l10n.commonRetry,
                    retryActionKey: GuKey.action('SET-02.retry'),
                    inline: true,
                    onRetry: viewModel.fetch,
                  ),
                ),
              ],
              GuListStatus.loading => [
                SliverToBoxAdapter(
                  child: GuSkeletonList(
                    semanticLabel: l10n.commonLoading,
                    count: _skeletonRows,
                  ),
                ),
              ],
              GuListStatus.empty => [
                SliverToBoxAdapter(
                  child: GuEmptyState(
                    illustration: GuIllustrations.emptyClubs,
                    title: l10n.blockedEmpty,
                    compact: true,
                  ),
                ),
              ],
              GuListStatus.data => [
                SliverList.builder(
                  itemCount: visible.length,
                  itemBuilder: (_, index) => row(visible[index]),
                ),
              ],
            },
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

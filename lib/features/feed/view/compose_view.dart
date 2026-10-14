import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/feed/provider/compose_state.dart';
import 'package:gu_kulupler/features/feed/view/mixin/compose_view_mixin.dart';
import 'package:gu_kulupler/features/feed/view/widget/compose_form.dart';
import 'package:gu_kulupler/features/feed/view/widget/compose_parts.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/managed_club_picker_sheet.dart';
import 'package:gu_kulupler/product/media/post_image_resolver.dart';
import 'package:gu_kulupler/product/mixin/unsaved_changes_mixin.dart';
import 'package:gu_kulupler/product/widget/post/post_card.dart';
import 'package:gu_ui/gu_ui.dart';

/// FED-03 "Yeni gönderi" / "Gönderiyi düzenle" — gönderi, duyuru ve anket
/// oluşturma (prototip `S['FED-03']`, `screens-clubs.js:181–215`).
/// `ComposeRoute` açar (`/clubs/:clubId/compose?edit=`, guard yönetici —
/// router'da).
///
/// Yukarıdan aşağıya: başlık çubuğu (kapat · başlık · "⋮" · "Yayınla" —
/// düzenlemede "Kaydet") · kaydırma alanı (`col gap16 px16 pt8 pb24`):
/// `ComposeForm`; önizleme kipinde bilgi bandı ("Düzenlemeye dön") + gönderi
/// kartı.
///
/// * [editPostId] verilirse düzenleme kipidir (`?edit=`; SHT-08 "Düzenle").
///   Durum sırası: hata ("Yeniden dene") → yükleniyor (iskelet) → form.
///   Yeni gönderide okuma beklenmez: form hemen çizilir (cihazdaki taslakla).
/// * "Yayınla" form geçersizken soluktur; dokunuş eksik alanların hatasını
///   gösterir. Gönderim sürerken döner.
/// * Kulübün yöneticisi (başkan / yönetim kurulu) olmayan kullanıcı formu
///   görmez: kilit çizimi + "Gönderi oluşturma yetkin yok." (rota guard'ı
///   normalde buraya düşürmez; oturum ekran açıkken değişirse görünür).
///   Kulüpte rolü olmayan süper admin de yazamaz (`RolePolicy`: `createPost`).
/// * Çevrimdışı bandı kökte çizilir; form ekranda kalır, yayın TST-24 verir.
/// * Klavye açıkken içerik kayar (`resizeToAvoidBottomInset` + kaydırma).
///
/// Davranış `ComposeViewMixin`'dedir.
///
/// Design: FED-03
class ComposeView extends ConsumerStatefulWidget {
  /// [clubId] kulübünde yeni gönderi; [editPostId] verilirse o gönderinin
  /// düzenlemesi.
  const ComposeView({required this.clubId, this.editPostId, super.key});

  /// Kulüp kimliği (`ComposeRoute.clubId`).
  final String clubId;

  /// Düzenlenen gönderinin kimliği (`ComposeRoute.edit`); yeni gönderide
  /// `null`.
  final String? editPostId;

  @override
  ConsumerState<ComposeView> createState() => _ComposeViewState();
}

class _ComposeViewState extends ConsumerState<ComposeView>
    with UnsavedChangesMixin<ComposeView>, ComposeViewMixin {
  /// Düzenlenecek gönderi okunurken: kart iskeleti.
  Widget _skeleton() => SingleChildScrollView(
    physics: const NeverScrollableScrollPhysics(),
    child: GuSkeletonList(
      semanticLabel: context.l10n.commonLoading,
      count: 1,
      variant: GuSkeletonVariant.card,
    ),
  );

  /// Önizleme kipi (`screens-clubs.js:200`): bilgi bandı + gönderi kartı
  /// (eylemsiz).
  List<Widget> _preview(ComposeState state, PostModel post) {
    final l10n = context.l10n;
    final session = ref.read(sessionViewModelProvider);
    return [
      GuBanner(
        icon: GuIcons.eye,
        text: l10n.composePreviewNote,
        actionLabel: l10n.composeEdit,
        actionKey: GuKey.action('FED-03.preview'),
        onAction: viewModel.togglePreview,
      ),
      PostCard(
        post: post,
        author: session.user,
        role: session.roleIn(widget.clubId),
        club: state.club,
        hideActions: true,
        imageOf: composeImageResolver(
          state.images,
          ref.watch(postImageResolverProvider),
        ),
      ),
    ];
  }

  Widget _content(ComposeState state, {required bool canSwitchClub}) {
    final preview = state.preview;
    return SingleChildScrollView(
      padding: GuInsets.only(
        left: GuSpacing.s16,
        right: GuSpacing.s16,
        top: GuSpacing.s8,
        bottom: GuSpacing.s24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: GuSpacing.s16,
        children: preview != null
            ? _preview(state, preview)
            : [
                ComposeForm(
                  clubId: widget.clubId,
                  editPostId: widget.editPostId,
                  onAddImage: () => unawaited(addImage()),
                  onSwitchClub: canSwitchClub
                      ? () => unawaited(switchClub())
                      : null,
                ),
              ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final state = ref.watch(provider);
    // Rota guard'ı, FED-01 girişi ve Rules ile aynı koşul: yalnızca kulübün
    // başkanı / yönetim kurulu üyesi yazar (kulüpte rolü olmayan süper admin
    // yazamaz — Firestore ve Storage kuralları reddeder).
    final canWrite = ref.watch(
      sessionViewModelProvider.select(
        (session) => RolePolicy.can(
          ClubPermission.createPost,
          session.roleIn(widget.clubId),
          isSuper: session.isSuperAdmin,
        ),
      ),
    );
    final canSwitchClub = ref.watch(
      sessionViewModelProvider.select(
        (session) => ManagedClubPickerSheet.managedOf(session).length > 1,
      ),
    );

    if (!canWrite) {
      return Scaffold(
        backgroundColor: gu.colors.bgCanvas,
        appBar: GuAppBar(
          title: l10n.composeTitle,
          onBack: leaveScreen,
          backSemanticLabel: l10n.a11yBack,
          backActionKey: GuKey.action('FED-03.back'),
        ),
        body: Center(
          child: SingleChildScrollView(
            child: GuEmptyState(
              illustration: GuIllustrations.locked,
              description: l10n.composeNoAccess,
            ),
          ),
        ),
      );
    }

    // Sıra: hata → yükleniyor → form (boş durum yoktur).
    final Widget body;
    final hasForm = !state.isError && !state.isLoadingEdit;
    if (state.isError) {
      body = Center(
        child: SingleChildScrollView(
          child: GuErrorState(
            title: l10n.sysErrorTitle,
            description: l10n.sysErrorDesc,
            retryLabel: l10n.commonRetry,
            retryActionKey: GuKey.action('FED-03.retry'),
            onRetry: retry,
          ),
        ),
      );
    } else if (state.isLoadingEdit) {
      body = _skeleton();
    } else {
      body = _content(state, canSwitchClub: canSwitchClub);
    }

    return buildUnsavedGuard(
      child: Scaffold(
        backgroundColor: gu.colors.bgCanvas,
        appBar: GuAppBar(
          title: isEditing ? l10n.composeEditTitle : l10n.composeTitle,
          onBack: onClose,
          closeIcon: true,
          backSemanticLabel: l10n.a11yClose,
          backActionKey: GuKey.action('FED-03.close'),
          actions: [
            if (hasForm) ...[
              GuIconButton(
                key: GuKey.action('FED-03.menu'),
                icon: GuIcons.moreVertical,
                semanticLabel: l10n.a11yMore,
                onPressed: () => unawaited(openMenu()),
              ),
              GuButton(
                key: GuKey.action('FED-03.publish'),
                label: isEditing ? l10n.commonSave : l10n.composePublish,
                size: GuButtonSize.sm,
                loading: state.isSubmitting,
                disabled: !state.isValid,
                onPressed: () => unawaited(publish()),
                onDisabledPressed: showErrors,
              ),
            ],
          ],
        ),
        body: body,
      ),
    );
  }
}

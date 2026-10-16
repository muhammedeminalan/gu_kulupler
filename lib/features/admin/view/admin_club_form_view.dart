import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/admin/provider/admin_club_form_state.dart';
import 'package:gu_kulupler/features/admin/view/mixin/admin_club_form_view_mixin.dart';
import 'package:gu_kulupler/features/admin/view/widget/admin_club_form_body.dart';
import 'package:gu_kulupler/product/mixin/unsaved_changes_mixin.dart';
import 'package:gu_ui/gu_ui.dart';

/// Admin kulüp oluştur / düzenle — `AdminClubFormRoute`
/// (`/admin/clubs/new`) ve `AdminClubEditRoute` (`/admin/clubs/:clubId/edit`)
/// aynı ekranı açar (iki rota sınıfı, tek view — CD-54; guard `S`).
/// Prototip `S['ADM-03']` (`screens-admin.js:39–56`).
///
/// Yukarıdan aşağıya: uygulama çubuğu (X `ADM-03.close` · "Kulüp oluştur" /
/// "Kulübü düzenle") · kaydırma alanı (`col gap16 px16 pt8 pb24`,
/// `AdminClubFormBody`) · alt çubuk "Oluştur" / "Kaydet" (`ADM-03.save`,
/// kaydederken döner).
///
/// * Durum sırası (düzenleme): hata ("Yeniden dene", `ADM-03.retry`) →
///   yükleniyor (iskelet) → form. Boş durum yoktur (form). Çevrimdışı bandı
///   kökte çizilir; form ekranda kalır, kaydet TST-24 verir.
/// * Kaydedilmemiş değişiklikte kapat / geri → DLG-25
///   (`UnsavedChangesMixin`, "Kaydet"siz — prototip).
/// * Klavye açıkken içerik kayar (`resizeToAvoidBottomInset` + kaydırma).
///
/// Davranış `AdminClubFormViewModel` ve `AdminClubFormViewMixin`'dedir.
///
/// Design: ADM-03
class AdminClubFormView extends ConsumerStatefulWidget {
  /// Yeni kulüp; [clubId] verilirse o kulübün düzenlemesi.
  const AdminClubFormView({this.clubId, super.key});

  /// Düzenlenen kulüp (`AdminClubEditRoute.clubId`); yeni kulüpte `null`.
  final String? clubId;

  /// Düzenleme kipi mi.
  bool get isEdit => clubId != null;

  @override
  ConsumerState<AdminClubFormView> createState() => _AdminClubFormViewState();
}

class _AdminClubFormViewState extends ConsumerState<AdminClubFormView>
    with UnsavedChangesMixin<AdminClubFormView>, AdminClubFormViewMixin {
  Widget _cta(AdminClubFormState state) => GuStickyCta(
    children: [
      GuButton(
        key: GuKey.action('ADM-03.save'),
        label: widget.isEdit
            ? context.l10n.commonSave
            : context.l10n.clubFormCreate,
        loading: state.isSubmitting,
        full: true,
        onPressed: () => unawaited(save()),
      ),
    ],
  );

  Widget _form(AdminClubFormState state) => GuFormScrollView(
    padding: GuInsets.only(
      left: GuSpacing.s16,
      right: GuSpacing.s16,
      top: GuSpacing.s8,
      bottom: GuSpacing.s24,
    ),
    child: AdminClubFormBody(
      state: state,
      onNameChanged: viewModel.setName,
      onCategoryTap: () => unawaited(openCategory()),
      onSummaryChanged: viewModel.setSummary,
      onAboutChanged: viewModel.setAbout,
      onLogoTap: () => unawaited(openLogo()),
      onCoverTap: () => unawaited(openCover()),
      onAssignPresident: () => unawaited(assignPresident()),
      onRemovePresident: viewModel.removePresident,
      onAdvisorTitleChanged: viewModel.setAdvisorTitle,
      onAdvisorNameChanged: viewModel.setAdvisorName,
      onUnlinkAdvisor: viewModel.unlinkAdvisor,
      onApplicationsOpenChanged: (value) =>
          viewModel.setApplicationsOpen(value: value),
      onApprovalRequiredChanged: (value) =>
          viewModel.setApprovalRequired(value: value),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final state = ref.watch(provider);

    // Sıra: hata → yükleniyor → form (boş durum yoktur).
    final hasForm = !state.isError && !state.isLoading;
    final Widget body;
    if (state.isError) {
      body = Center(
        child: SingleChildScrollView(
          child: GuErrorState(
            title: l10n.sysErrorTitle,
            description: l10n.sysErrorDesc,
            retryLabel: l10n.commonRetry,
            retryActionKey: GuKey.action('ADM-03.retry'),
            onRetry: retry,
          ),
        ),
      );
    } else if (state.isLoading) {
      body = SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: GuSkeletonList(
          semanticLabel: l10n.commonLoading,
          count: 1,
          variant: GuSkeletonVariant.card,
        ),
      );
    } else {
      body = _form(state);
    }

    return buildUnsavedGuard(
      child: Scaffold(
        backgroundColor: gu.colors.bgCanvas,
        appBar: GuAppBar(
          title: widget.isEdit ? l10n.clubFormEditTitle : l10n.clubFormTitle,
          closeIcon: true,
          onBack: onClose,
          backSemanticLabel: l10n.a11yClose,
          backActionKey: GuKey.action('ADM-03.close'),
        ),
        bottomNavigationBar: hasForm ? _cta(state) : null,
        body: body,
      ),
    );
  }
}
